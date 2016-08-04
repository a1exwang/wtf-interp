require_relative '../eval'

module Wtf
  module Lang
    module Exception
      class ModuleNotFound < ::Exception; end
    end
    class WtfType
    end
    class LiteralType < WtfType
      attr_reader :name
      def self.true_val
        @true_val ||= LiteralType.new('True')
      end
      def self.false_val
        @false_val ||= LiteralType.new('False')
      end
      def self.nil_val
        @nil_val ||= LiteralType.new('Nil')
      end

      def to_s
        @name
      end

      private
      def initialize(name)
        @name = name
      end
    end

    class ModuleType < LiteralType
      attr_reader :parent, :bindings, :name
      def initialize(node, lexical_parent, bindings)
        node.send :set_module_type, self
        @parent = lexical_parent.current_module
        @lexical_parent = lexical_parent
        @bindings = bindings
        @node = node
        @name = node.name
      end
      def to_s
        "module #{full_name}"
      end
      def full_name
        if @parent
          @parent.full_name + "::#{@name}"
        elsif @bindings.lexical_parent
          "function<#{@bindings.lexical_parent.location_str}>::#{@name}"
        else
          "::#{@name}"
        end
      end
    end
  end

  module KernelFnDefs
    def def_globals
      defn('puts') do |env, obj|
        str = execute_fn('to_s', [obj], env.bindings)
        puts str
        str
      end
      defn('[]') do |_env, obj, index|
        obj[index]
      end
      defn('each') do |_env, collection, fn|
        collection.each do |item|
          fn_def_node_call(fn, [item])
        end
        collection
      end
      defn('eval') do |env, str|
        Wtf.eval(str, env.bindings)
      end
      defn('to_s') do |env, obj|
        case obj
        when AstNode
          JSON.pretty_generate(JSON.parse(obj.to_json))
        when Array
          vals = []
          obj.each do |val|
            vals << execute_fn('to_s', [execute(val)], env.bindings)
          end
          "[#{vals.join(', ')}]"
        else
          obj.to_s
        end
      end
      defn('true?') do |env, obj|
        !(obj == Lang::LiteralType.false_val || obj == Lang::LiteralType.nil_val)
      end

      def_global_vars
    end

    private
    def defn(name, &block)
      args = Array.new(block.arity - 1) { |i| IdNode.new("p#{i}") }
      node = NativeFnDefNode.new(args, lambda do |env, params|
        raise "wrong number of args: #{params.size} given but #{args.size} needed" unless params.size == args.size
        block.(env, *params)
      end)
      node.bind_to_var(name)
      @global_bindings.wtf_def_var(name, node)
    end
    def defg(name, val)
      @global_bindings.wtf_def_var(name, val)
    end

    def def_global_vars
      defg('True', Lang::LiteralType.true_val)
      defg('False', Lang::LiteralType.false_val)
      defg('Nil', Lang::LiteralType.nil_val)
    end

  end
end