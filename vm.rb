require_relative 'ast/nodes'
require_relative 'stdlib/kernel'

module Wtf
  class VM
    STDLIB_ROOT = 'stdlib/wtf'
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
          @entity = nil
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
          raise err_str
        end
        @bindings[name] = val
      end
      def wtf_get_var(name, loc_str)
        return @bindings[name] if @bindings[name]
        begin
          if @lexical_parent && (v = @lexical_parent.wtf_get_var(name, loc_str))
            return v
          else
            raise Lang::Exception::VarNotFound
          end
        rescue Lang::Exception::VarNotFound
          err_str = "\tDefinition of '#{name}' not found\n" +
              "\tat binding #{loc_str}"
          raise Wtf::Lang::Exception::VarNotFound, err_str unless @bindings.key? name
        end
      end
      def wtf_find_var(name)
        scopes = name.split('::')
        b = self
        scopes.each do |scope_name|
          b = b.wtf_get_var(scope_name, '')
        end
        b
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
      @program_args = args
    end
    def load_stdlib
      init_libs
      load_stdlib_files
    end
    def load_stdlib_files
      Dir.entries(VM::STDLIB_ROOT).each do |filename|
        if filename =~ /\.wtf$/
          path = File.join(VM::STDLIB_ROOT, filename)
          open(path, 'r') do |f|
            exec_file(path, f.read)
          end

        end
      end
    end

    def exec_file(path, code, options = {})
      lexer = Wtf::Lexer.new(code, path, 1, 1)
      parser = Wtf::Parser.new

      # Parser
      ast = parser.parse(lexer)
      if options[:stage] == :ast
        puts JSON.pretty_generate(JSON.parse(ast.to_json))
        exit
      end

      # AST traversing 1
      ast.set_lexical_parent(Wtf::VM.instance.global_bindings)
      if options[:stage] == :ast1
        puts JSON.pretty_generate(JSON.parse(ast.to_json))
        exit
      end
      self.execute(ast)
    end

    def top_fn
      if @top_fn
        @top_fn
      else
        @top_fn = NativeFnDefNode.new([], lambda do |env, params|
          unless params.size == 0
            raise Lang::Exception::WrongArgument,
                  "wrong number of args in function #{env[:node].name}: \n" +
                      "#{params.size} given but #{args.size} needed"
          end
          execute_fn('main', VM.instance.top_fn)
        end, { file: '<top level>'})
      end
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

    public
    def execute_top_fn
      execute_fn('main', Wtf::VM.instance.top_fn)
    end

    def fn_def_node_call(node, params, current_bindings, _caller)
      ret = nil
      if node.native?
        # caller's binding
        Thread.current[:stack] << node
        ret = node.call(current_bindings, params)
        Thread.current[:stack].pop
        ret
      else
        # params not used
        node.bind_params(params)
        Thread.current[:stack] << node
        node.body.stmt_list.each do |code|
          ret = execute(code, node.bindings)
        end
        node.unbind_params
        Thread.current[:stack].pop
        ret
      end
    end

    def execute_fn(name, caller, params = [], current_bindings = nil)
      current_bindings ||= @global_bindings
      fn_def_node = current_bindings.wtf_get_var(name, current_bindings.location_str)
      fn_def_node_call(fn_def_node, params, current_bindings, caller)
      #fn_call(FnCallNode.new(IdNode.new(name), params), current_bindings)
    end

    # thread[:stack] is an array(stack) containing called functions,
    # older functions are pushed back
    def execute(node, current_binding = nil)
      current_binding ||= @global_bindings
      case node
      when IdNode
        raise "IdNode executed at #{node.inspect}"
        #return node
      when LiteralNode
        return node.value
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
        return values
      when MapNode
        values = {}
        node.list.each do |item|
          key_node = item[:key]
          value_node = item[:value]
          values[key_node.name] = execute(value_node, current_binding)
        end
        values
      when ModNode
        return module_def(node, current_binding)
      when ModRefNode
        return scope_ref(node, current_binding)
      when FnDefNode
        return node
      when FnCallNode
        return fn_cal_node_call(node, current_binding)
      when ExceptNode
        begin
          execute_stmt_list(node.stmt_list, node.bindings)
        rescue Lang::Exception::WtfError => e
          execute_pm(node.pm, e.to_wtf_map, node.bindings)
          execute_stmt_list(node.rescue_list, node.bindings)
        end
      when Op1Node
        case node.op
        when :plus
          return self.execute(node.p1, current_binding)
        when :minus
          return -self.execute(node.p1, current_binding)
        else
          raise 'unknown op1: ' + node.op
        end
      when Op2Node
        p1 = self.execute(node.p1, current_binding)
        p2 = self.execute(node.p2, current_binding)

        case node.op
        when :plus
          return p1 + p2
        when :minus
          return p1 - p2
        when :mul
          return p1 * p2
        when :div
          return p1 / p2
        else
          raise 'unknown operator: ' + node.op
        end
      when IfNode
        val = self.execute(node.exp)
        if self.execute_fn('true?', current_binding.entity, [val], current_binding)
          execute_stmt_list(node.true_list, current_binding)
        else
          execute_stmt_list(node.false_list, current_binding)
        end
      when PMNode
        execute_pm_node(node, current_binding)
      when Integer, String, Array, Hash, Wtf::Lang::LiteralType, Wtf::Lang::ModuleType
        return node
      else
        raise "unknown node type: '#{node.class}', value: '#{node}'"
      end
    end

    def raise_rt_err(err, location, msg)
      raise err, "at #{location}\n#{msg}"
    end

    def defm(name, current_binding)
      node = ModNode.new([])
      mod = module_def(node, current_binding)
      current_binding.wtf_def_var(name, mod)
      mod
    end

    def module_def(node, current_binding)
      mod = Wtf::Lang::ModuleType.new(node, current_binding, node.bindings)
      execute_stmt_list(node.stmt_list, node.bindings)
      mod
    end

    private
    def execute_stmt_list(stmt_list, bindings)
      stmt_list.each do |c|
        execute(c, bindings)
      end
    end
    def fn_cal_node_call(node, current_binding)
      params = []
      node.params.each do |p|
        params << execute(p, current_binding)
      end

      fn_node = execute(node.fn, current_binding)
      fn_def_node_call(fn_node, params, current_binding, node)
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
        current_binding.wtf_def_var(left.name, execute(right))
      when String, Integer
        right_val = execute(right)
        if left == right_val
          true
        else
          raise_rt_err(Lang::Exception::NotMatched, right.location_str, "#{left} != #{right_val}")
        end
      else
        raise_rt_err(Lang::Exception::NotMatched, right.location_str, "unknown left (#{left}) type")
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
        left.list.each do |item|
          key, val = item[:key], item[:value]
          val_node  = right.get_by_name(key.name)
          if val_node
            execute_pm(val, val_node[:value], current_binding)
          else
            raise_rt_err(
                Lang::Exception::NotMatched,
                left.location_str,
                "key '#{key.name}' in left not found in right"
            )
          end
        end
      elsif right.is_a?(Hash)
        if left.list.size != right.size
          raise_rt_err(
              Lang::Exception::NotMatched,
              left.location_str,
              "map size not matched: #{left.list.size} and #{right.size}"
          )
        end
        left.list.each do |item|
          key, val = item[:key], item[:value]
          val_node  = right[key.name]
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
      if right.is_a?(LstNode)
        if left.list.size > right.list.size
          raise_rt_err(
              Lang::Exception::NotMatched,
              left.location_str,
              "list size not matched: #{left.list.size} and #{right.list.size}"
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
                right.list[i..-1].each do |right_item|
                  vals << execute(right_item)
                end
                execute_pm(left_node.identifier, vals, current_binding)
              else
                raise_rt_err(Lang::Exception::SemanticsError, left_node.location_str, "rest match must be the last item(#{left.list.size-1}), but at #{i}")
              end
            else
              raise "PMModIdNode mod type: #{left.list[i].mod}"
            end
          else
            execute_pm(left.list[i], right.list[i], current_binding)
          end
        end
      elsif right.is_a?(Array)
        if left.list.size > right.size
          raise_rt_err(
              Lang::Exception::NotMatched,
              left.location_str,
              "list size not matched: #{left.list.size} and #{right.size}"
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
                right[i..-1].each do |right_item|
                  vals << execute(right_item)
                end
                execute_pm(left_node.identifier, vals, current_binding)
              else
                raise_rt_err(Lang::Exception::SemanticsError,
                             left_node.location_str,
                             "rest match must be the last item(#{left.list.size-1}), but at #{i}")
              end
            else
              raise "PMModIdNode mod type: #{left.list[i].mod}"
            end
          else
            execute_pm(left.list[i], right[i], current_binding)
          end
        end
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
