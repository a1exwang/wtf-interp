require_relative 'ast/nodes'

module Wtf
  class VM
    class Err
      class VarNotFound < Exception; end
    end
    attr_reader :global_bindings
    class Bindings
      attr_reader :fn
      def initialize(fn, lexical_parent = VM.instance.global_bindings)
        @fn = fn
        @bindings = {}
        @lexical_parent = lexical_parent
      end

      def wtf_def_var(name, val)
        if @bindings.key? name
          err_str = "Duplicate definition for #{name} error\n" +
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

      def location_str
        @fn ?
            @fn.location_str :
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
        @instance.send :init_libs
      end
      @instance ||= VM.new
    end

    private
    def initialize
      @global_bindings = Bindings.new(nil, nil)
    end
    def init_libs
      g_puts = NativeFnDefNode.new([IdNode.new('str')], lambda do |params|
            raise "wrong number of args: #{params.size}" unless params.size == 1
            puts params.first
      end)
      g_puts.assign_to_var('puts')
      @global_bindings.wtf_def_var(
          'puts', g_puts
      )
    end

    public
    def fn_call(node, current_binding)
      params = []
      node.params.each do |p|
        params << execute(p, current_binding)
      end

      fn_node = current_binding.wtf_get_var(node.identifier.name)
      ret = nil
      if fn_node.native?
        fn_node.call(params)
      else
        # params not used
        fn_node.bind_params(params)
        fn_node.body.code_list.each do |code|
          ret = execute(code, fn_node.bindings)
        end
        ret
      end
    end

    def execute_fn(name, current_bindings = nil)
      current_bindings ||= @global_bindings
      fn_call(FnCallNode.new(IdNode.new(name), []), current_bindings)
    end

    def execute(node, current_binding = nil)
      current_binding ||= @global_bindings
      case node
      when IdNode
        return node
      when LiteralNode
        return node.value
      when VarRefNode
        return current_binding.wtf_get_var(node.identifier.name)
      when AssignNode
        val = execute(node.exp, current_binding)
        current_binding.wtf_def_var(node.identifier.name, val)
        return val
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
      else
        puts node
        raise 'unknown node'
      end
    end
  end
end
