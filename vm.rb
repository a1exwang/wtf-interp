require_relative 'ast/nodes'
require_relative 'stdlib/kernel'

module Wtf
  class VM
    class Err
      class VarNotFound < Exception; end
    end
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
      def wtf_get_var(name)
        return @bindings[name] if @bindings[name]
        begin
          if @lexical_parent && (v = @lexical_parent.wtf_get_var(name))
            return v
          end
        rescue VM::Err::VarNotFound
        end

        err_str = "Definition of '#{name}' not found\n" +
            "at binding #{self.location_str}"
        raise Err::VarNotFound, err_str unless @bindings.key? name
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
    end

    private
    def initialize
      @global_bindings = Bindings.new(nil, nil)
    end
    include Wtf::KernelFnDefs
    def init_libs
      def_globals
    end

    public
    def module_def(node, current_binding)
      mod = Wtf::Lang::ModuleType.new(node, current_binding, node.bindings)
      execute_code_list(node.code_list, node.bindings)
      mod
    end
    def scope_ref(node, current_binding)
      b = current_binding
      mod = nil
      node.id_list.each do |id|
        mod = b.wtf_get_var(id.name)
        # A::B::C, A and B must be modules, C could be a module or a variable
        b = mod.bindings if mod.is_a?(Lang::ModuleType)
      end
      if mod
        mod
      else
        raise Wtf::Lang::Exception::ModuleNotFound
      end
    end

    def fn_call(node, current_binding)
      params = []
      node.params.each do |p|
        params << execute(p, current_binding)
      end

      fn_node = execute(node.fn, current_binding)
      fn_def_node_call(fn_node, params, current_binding)
    end
    def fn_def_node_call(node, params, _current_bindings)
      ret = nil
      if node.native?
        node.call(params)
      else
        # params not used
        node.bind_params(params)
        node.body.code_list.each do |code|
          ret = execute(code, node.bindings)
        end
        node.unbind_params
        ret
      end
    end

    def execute_fn(name, params = [], current_bindings = nil)
      current_bindings ||= @global_bindings
      fn_def_node = current_bindings.wtf_get_var(name)
      fn_def_node_call(fn_def_node, params, current_bindings)
      #fn_call(FnCallNode.new(IdNode.new(name), params), current_bindings)
    end

    def execute(node, current_binding = nil)
      current_binding ||= @global_bindings
      case node
      when IdNode
        raise "IdNode executed at #{node.inspect}"
        return node
      when LiteralNode
        return node.value
      when VarRefNode
        return current_binding.wtf_get_var(node.identifier.name)
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
      when ModNode
        return module_def(node, current_binding)
      when ModRefNode
        return scope_ref(node, current_binding)
      when FnDefNode
        return node
      when FnCallNode
        return fn_call(node, current_binding)
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
        if self.execute_fn('true?', [val], current_binding)
          self.execute_code_list(node.true_list, current_binding)
        else
          self.execute_code_list(node.false_list, current_binding)
        end
      when Integer, String, Array, Wtf::Lang::LiteralType, Wtf::Lang::ModuleType
        return node
      else
        raise "unknown node type: '#{node.class}', value: '#{node}'"
      end
    end

    def execute_code_list(code_list, bindings)
      code_list.each do |c|
        execute(c, bindings)
      end
    end
  end
end
