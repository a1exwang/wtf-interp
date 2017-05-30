require_relative 'ast/nodes'
require_relative 'stdlib/kernel'

module Wtf
  class VM
    STDLIB_ROOT = File.join(File.dirname(__FILE__), 'stdlib', 'wtf')
    attr_reader :global_bindings
    class Bindings
      attr_reader :entity, :lexical_parent
      def initialize(entity, lexical_parent = VM.instance.global_bindings)
        @bindings = {}
        @lexical_parent = lexical_parent
        @entity = entity
        if @entity.nil?
          # global binding
        elsif entity.is_a?(Wtf::ModNode)
          @current_module = nil
          @current_module_proc = lambda { entity.module_type }
        else
          @current_module_proc = lambda { lexical_parent.current_module }
        end
      end

      def current_module
        if @current_module
          @current_module
        elsif @current_module_proc
          @current_module = @current_module_proc.call
          @entity ||= @current_module
          @current_module
        else
          nil
        end
      end

      def wtf_def_var(name, val)
        if @bindings.key? name
          err_str = "Duplicate definition of \"#{name}\" error\n" +
                    "at binding #{self.location_str}"
          raise Lang::Exception::VarRedefinition.new(err_str, self.location_str)
        end
        @bindings[name] = val
      end
      def wtf_get_var(name, loc_str)
        return @bindings[name] if @bindings[name]
        begin
          if @lexical_parent && (v = @lexical_parent.wtf_get_var(name, loc_str))
            return v
          else
            raise Lang::Exception::VarNotFound.new("Variable '#{name}' not found", loc_str)
          end
        rescue Lang::Exception::VarNotFound
          err_str = "\tDefinition of '#{name}' not found\n" +
              "\tat binding #{loc_str}"
          raise Wtf::Lang::Exception::VarNotFound.new(err_str, loc_str) unless @bindings.key? name
        end
      end
      def wtf_find_var(name, loc_str)
        scopes = name.split('::')
        b = self
        scopes.each do |scope_name|
          b = b.wtf_get_var(scope_name, loc_str)
        end
        b
      end
      def wtf_local_var_names
        Wtf::Lang::ListType.new(@bindings.keys.map { |x| Wtf::Lang::StringType.new(x) })
      end

      def wtf_undef_all
        @bindings = {}
      end

      def location_str
        @entity ?
            @entity.location_str :
            '@global'
      end

      def backtrace_info
        p = self
        ancestors = []
        while p
          ancestors << p
        end
        ancestors.reverse.map { |x| x.location_str }.join("\n")
      end
    end

    def self.instance
      if @instance
        @instance
      else
        @instance = VM.new
        # init_libs is private method
      end
      @instance ||= VM.new
    end

    def set_program_args(args)
      my_argv = args.map { |x| Wtf::Lang::StringType.new(x) }
      @program_args = Wtf::Lang::ListType.new(my_argv)
    end
    def load_stdlib
      init_libs
      load_stdlib_files
    end

    def construct_env(callee_node, callers_bindings)
      {
          node: callee_node,
          callers_bindings: callers_bindings,
          caller: callers_bindings.entity,
          vm: self
      }
    end

    private
    def initialize
      @global_bindings = Bindings.new(nil, nil)
      init_thread(Thread.current)
    end
    include Wtf::KernelFnDefs
    def init_libs
      def_globals
    end

    def init_thread(thread)
      thread[:stack] = []
      thread[:exception_handler_stack] = []
    end

    def get_top_fn
      if @top_fn
        @top_fn
      else
        @top_fn = NativeFnDefNode.new([], lambda do |env, params|
          unless params.size == 0
            raise Lang::Exception::WrongArgument,
                  "wrong number of args in function #{env[:node].name}: \n" +
                      "#{params.size} given but #{args.size} needed"
          end
          execute_fn('main', get_top_fn)
        end, { file: '<top level>'})
      end
    end
    def load_stdlib_files
      Dir.entries(VM::STDLIB_ROOT).each do |filename|
        if filename =~ /\.wtf$/
          path = File.join(VM::STDLIB_ROOT, filename)
          io = open(path, 'r')
          Wtf.wtf_require_file(io, path, @global_bindings)
        end
      end
    end

    public
    def execute_top_fn
      execute_fn('main', get_top_fn)
    end
    def import_file(io, file_path, current_bindings = nil)
      current_bindings ||= @global_bindings
      # Wtf.wtf_require_file(io, file_path, current_bindings)
      Wtf.wtf_import_file(io, file_path, current_bindings)
    end

    def fn_obj_call(fn, params, current_bindings, _caller)
      ret = Wtf::Lang::NilType.new
      node = fn.node
      if node.native?
        # caller's binding
        Thread.current[:stack] << node
        ret = node.call(current_bindings, params.val, self)
        Thread.current[:stack].pop
        ret
      else
        # params not used
        # node.bind_params(params)
        if params.val.size == 1
          unless node.args.is_a? Wtf::IdNode
            raise Wtf::Lang::NotMatched, 'Function parameter not matched'
          end
          node.bindings.wtf_def_var(node.args.name, params.val[0])
        else
          execute_pm(node.args, params, node.bindings)
        end
        Thread.current[:stack] << node
        node.body.stmt_list.each do |code|
          ret = execute(code, node.bindings)
        end
        node.unbind_params
        Thread.current[:stack].pop
        ret
      end
    end

    def execute_fn(name, caller, params = nil, current_bindings = nil)
      if params.is_a?(Array)
        raise 'this bug again, this should be a Wtf::Lang::ListType'
      end
      params ||= Wtf::Lang::ListType.new([])
      current_bindings ||= @global_bindings
      fn_def_node = current_bindings.wtf_get_var(name, current_bindings.location_str)
      fn_obj_call(fn_def_node, params, current_bindings, caller)
      #fn_call(FnCallNode.new(IdNode.new(name), params), current_bindings)
    end

    # thread[:stack] is an array(stack) containing called functions,
    # older functions are pushed back
    def execute(node, current_binding = nil)
      current_binding ||= @global_bindings
      case node
      when IdNode
        raise "IdNode executed at #{node.inspect}"
      when LiteralNode
        return node.wtf_value
      when VarRefNode
        return current_binding.wtf_get_var(node.identifier.name, node.location_str)
      when AssignNode
        val = execute(node.exp, current_binding)
        current_binding.wtf_def_var(node.identifier.name, val)
        return val
      when LstNode
        values = []
        node.list.each do |item|
          values << execute(item, current_binding)
        end
        Wtf::Lang::ListType.new(values)
      when MapNode
        values = {}
        node.list.each do |item|
          key_node = item[:key]
          value_node = item[:value]
          values[key_node.name] = execute(value_node, current_binding)
        end
        Wtf::Lang::MapType.new(values)
      when ModNode
        return module_def(node, current_binding)
      when ModRefNode
        return scope_ref(node, current_binding)
      when FnDefNode
        return Wtf::Lang::FunctionType.new(node)
      when FnCallNode
        return fn_cal_node_call(node, current_binding)
      when ExceptNode
        begin
          execute_stmt_list(node.stmt_list, node.bindings)
        rescue Lang::Exception::WtfError => e
          execute_pm(node.pm, e.to_wtf_map, node.bindings)
          execute_stmt_list(node.rescue_list, node.bindings)
        ensure
          node.unbind_all
        end
      when Op1Node
        case node.op
          when :plus
            return self.execute(node.p1, current_binding)
          when :minus
            return self.execute(node.p1, current_binding).wtf_uminus(self.construct_env(node, current_binding))
        else
          raise 'unknown op1: ' + node.op
        end
      when Op2Node
        p1 = self.execute(node.p1, current_binding)
        p2 = self.execute(node.p2, current_binding)

        # TODO: construct a env object
        env = self.construct_env(node, current_binding)
        case node.op
        when :plus
          return p1.wtf_plus(env, p2)
        when :minus
          return p1.wtf_minus(env, p2)
        when :mul
          return p1.wtf_mul(env, p2)
        when :div
          return p1.wtf_div(env, p2)
        when :eqeq
          return p1.wtf_eqeq(env, p2)
        when :neq
          return p1.wtf_neq(env, p2)
        when :lt
          return p1.wtf_lt(env, p2)
        when :gt
          return p1.wtf_gt(env, p2)
        when :lte
          return p1.wtf_lte(env, p2)
        when :gte
          return p1.wtf_gte(env, p2)
        else
          raise 'unknown operator: ' + node.op
        end
      when IfNode
        val = self.execute(node.exp, current_binding)
        if self.execute_fn(
            'true?',
            current_binding.entity,
            Wtf::Lang::ListType.new([val]),
            current_binding).val
          execute_stmt_list(node.true_list, current_binding)
        else
          execute_stmt_list(node.false_list, current_binding)
        end
      when CaseWhenNode
        val = self.execute(node.exp, current_binding)
        result = nil
        node.when_list.each do |when_item|
          pm = when_item[:pm_node]
          stmt_list = when_item[:stmt_list]

          success = true
          begin
            execute_pm(pm, val, when_item[:bindings])
          rescue Lang::Exception::NotMatched
            success = false
          end

          if success
            result = execute_stmt_list(stmt_list.stmt_list, when_item[:bindings])
            break
          end
        end

        if result.nil?
          if node.else_list
            result = execute_stmt_list(node.else_list.stmt_list, node.else_bindings)
          else
            env = self.construct_env(node, current_binding)
            raise_rt_err(
                Lang::Exception::NotMatched,
                node.location_str,
                "none of the case statements matched for expression #{val.wtf_to_s(env).val}"
            )
          end
        end

        result = Wtf::Lang::NilType.nil_val if result.nil?
        result
      when PMNode
        execute_pm_node(node, current_binding)
      when Wtf::Lang::LiteralType, Wtf::Lang::SimpleType
        return node
      when StmtListNode
        execute_stmt_list(node.stmt_list, current_binding)
      when Wtf::Lang::WtfType
        node
      else
        raise "unknown node type: '#{node.class}', value: '#{node}'"
      end
    end

    # Raise an exception
    def raise_rt_err(err, location, msg)
      raise err.new(msg, location)
    end

    # Define module
    def defm(name, current_binding)
      node = ModNode.new([])
      mod = module_def(node, current_binding)
      current_binding.wtf_def_var(name, mod)
      mod
    end

    # Create a WtfModule node
    def module_def(node, current_binding)
      mod = Wtf::Lang::ModuleType.new(node, current_binding, node.bindings)
      execute_stmt_list(node.stmt_list, node.bindings)
      mod
    end

    private
    def execute_stmt_list(stmt_list, bindings)
      ret = Wtf::Lang::NilType.new
      stmt_list.each do |c|
        ret = execute(c, bindings)
      end
      ret
    end
    def fn_cal_node_call(node, current_binding)
      param_list = []
      node.params.each do |p|
        param_list << execute(p, current_binding)
      end
      params = Wtf::Lang::ListType.new(param_list)

      fn = execute(node.fn, current_binding)
      fn_obj_call(fn, params, current_binding, node)
    end

    def execute_pm_node(node, current_binding)
      execute_pm(node.left, node.right, current_binding)
    end
    def execute_pm(left, right, current_binding)
      case left
      when PMLstNode
        execute_pm_list(left, right, current_binding)
      when PMMapNode
        execute_pm_map(left, right, current_binding)
      when IdNode
        right_val = execute(right)
        # if right_val.is_a?(Wtf::Lang::ListType)
        #   right_val = right_val.val[0]
        # end
        current_binding.wtf_def_var(left.name, right_val)
      when StrNode, IntNode
        env = construct_env(right, current_binding)
        left_val = execute(left, current_binding)
        right_val = execute(right, current_binding)
        if left_val.wtf_eqeq(env, right_val).val
          Wtf::Lang::LiteralType.true_val
        else
          raise_rt_err(
              Lang::Exception::NotMatched,
              right.wtf_to_s(env).val,
              "#{left_val.wtf_to_s(env).val} != #{right_val}"
          )
        end
      else
        env = construct_env(left, current_binding)
        raise_rt_err(Lang::Exception::NotMatched, right.wtf_to_s(env).val, "unknown left (#{left}) type")
      end
    end
    # +left+ is a PMMapNode
    def execute_pm_map(left, right, current_binding)
      if right.is_a?(MapNode)
        if left.list.size != right.list.size
          raise_rt_err(
              Lang::Exception::NotMatched,
              left.location_str,
              "map size not matched: #{left.list.size} and #{right.list.size}"
          )
        end
        right_obj = execute(right, current_binding)
      else
        right_obj = right
      end

      if right_obj.is_a?(Wtf::Lang::MapType)
        if left.list.size != right_obj.size
          raise_rt_err(
              Lang::Exception::NotMatched,
              left.location_str,
              "map size not matched: #{left.list.size} and #{right_obj.size}"
          )
        end
        left.list.each do |item|
          key, val = item[:key], item[:value]
          val_node  = right_obj.get_item(key.name)
          if val_node
            execute_pm(val, val_node, current_binding)
          else
            raise_rt_err(
                Lang::Exception::NotMatched,
                left.location_str,
                "key '#{key.name}' in left not found in right"
            )
          end
        end
        right_obj
      else
        raise_rt_err(
            Lang::Exception::NotMatched,
            left.location_str,
            "left is map, but right is #{right}"
        )
      end
    end
    # +left+ is a PMLstNode
    def execute_pm_list(left, right, current_binding)
      right_obj = execute(right, current_binding)

      if right_obj.is_a?(Wtf::Lang::ListType)
        if left.list.size > right_obj.val.size
          raise_rt_err(
              Lang::Exception::NotMatched,
              left.location_str,
              "list size not matched: #{left.list.size} and #{right_obj.val.size}"
          )
        end
        left.list.size.times do |i|
          left_node = left.list[i]
          if left_node.is_a?(PMModIdNode)
            case left_node.mod
            when PMModIdNode::ModRestMatch
              # rest match must be the last argument
              if i == left.list.size - 1
                vals = []
                right_obj.val[i..-1].each do |right_item|
                  vals << execute(right_item)
                end
                execute_pm(left_node.identifier, Wtf::Lang::ListType.new(vals), current_binding)
              else
                raise_rt_err(Lang::Exception::SemanticsError,
                             left_node.location_str,
                             "rest match must be the last item(#{left.list.size-1}), but at #{i}")
              end
            else
              raise "PMModIdNode mod type: #{left.list[i].mod}"
            end
          else
            execute_pm(left.list[i], right_obj.val[i], current_binding)
          end
        end
        right_obj
      else
        raise_rt_err(
            Lang::Exception::NotMatched,
            left.location_str,
            "left is list, but right is #{right}"
        )
      end
    end

    def scope_ref(node, current_binding)
      b = current_binding
      mod = nil
      node.id_list.each do |id|
        mod = b.wtf_get_var(id.name, id.location_str)
        # A::B::C, A and B must be modules, C could be a module or a variable
        b = mod.bindings if mod.is_a?(Lang::ModuleType)
      end
      if mod
        mod
      else
        raise Wtf::Lang::Exception::ModuleNotFound
      end
    end
  end
end
