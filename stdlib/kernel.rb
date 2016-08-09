require_relative '../eval'
require_relative '../api'

module Wtf
  module Lang
    module Exception
      class WtfError < ::Exception; end
      class ModuleNotFound < WtfError; end
      class FileNotFound < WtfError; end
      class VarNotFound < WtfError; end
      class WrongArgument < WtfError; end
      class NotMatched < WtfError; end
      class SemanticsError < WtfError; end
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
      def location_str
        @node.location_str
      end
    end
  end

  module KernelFnDefs
    include Wtf::Api
    def def_globals
      g = global_bindings
      defn('puts', g) do |env, obj|
        str = execute_fn('to_s', env[:caller], [obj], env[:node].bindings)
        puts str
        str
      end
      defn('gets', g) do |_env|
        gets
      end
      defn('[]', g) do |_env, obj, index|
        obj[index]
      end
      defn('each', g) do |env, collection, fn|
        collection.each do |item|
          fn_def_node_call(fn, [item], env[:node].bindings, env[:node])
        end
        collection
      end
      defn('eval', g) do |env, str|
        Wtf.wtf_eval(str, env[:callers_bindings])
      end
      defn('require', g) do |env, file_path|
        Wtf.wtf_require(file_path, env[:callers_bindings])
      end
      defn('to_s', g) do |env, obj|
        node = env[:node]
        case obj
        when AstNode
          JSON.pretty_generate(JSON.parse(obj.to_json))
        when Array
          vals = []
          obj.each do |val|
            result = execute(val)
            if result.is_a?(String)
              vals << "\"#{result}\""
            else
              vals << execute_fn('to_s', env[:caller], [result], node.bindings)
            end
          end
          "[#{vals.join(', ')}]"
        else
          obj.to_s
        end
      end
      defn('true?', g) do |env, obj|
        !(obj == Lang::LiteralType.false_val || obj == Lang::LiteralType.nil_val)
      end
      defn('whats', g) do |env, obj|
        case obj
        when String
          'String'
        when Integer
          'Integer'
        when Array
          'List'
        when Lang::LiteralType.true_val, Lang::LiteralType.false_val
          'Boolean'
        when Lang::LiteralType.nil_val
          'Nil'
        when Wtf::FnDefNode
          'Function'
        else
          raise 'Unknown value type'
        end
      end

      def_global_vars
    end

    private
    def defg(name, val)
      @global_bindings.wtf_def_var(name, val)
    end

    def def_global_vars
      defg('True', Lang::LiteralType.true_val)
      defg('False', Lang::LiteralType.false_val)
      defg('Nil', Lang::LiteralType.nil_val)
      defg('ARGV', @program_args)
    end

  end
end