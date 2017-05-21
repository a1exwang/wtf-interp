require_relative '../eval'
require_relative '../api'
require_relative './api'

module Wtf
  module Lang
    module Exception
      class WtfError < ::Exception
        attr_reader :wtf_location
        def initialize(msg, location)
          super(msg)
          @wtf_message = msg
          @wtf_location = location
        end
        def to_wtf_map
          Wtf::Lang::MapType.new(
              {
                  'type' => Wtf::Lang::StringType.new(self.class.to_s),
                  'message' => Wtf::Lang::StringType.new(self.message)
              }
          )
        end
      end
      class ModuleNotFound < WtfError; end
      class FileNotFound < WtfError; end
      class VarNotFound < WtfError; end
      class VarRedefinition < WtfError; end
      class TypeError < WtfError; end
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

      def wtf_to_s(env)
        StringType.new(@name)
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
    class SimpleType < WtfType
      attr_reader :val
      def initialize(val)
        @val = val
      end
      def wtf_to_s(env)
        StringType.new(@val.to_s)
      end
    end
    class ListType < SimpleType
      def each(&block)
        self.val.each(&block)
      end
      def wtf_to_s(env)
        vals = val.map do |val|
          result = Wtf::VM.instance.execute(val)
          if result.is_a?(StringType)
            StringType.new("\"#{result.val}\"")
          else
            Wtf::VM.instance.execute_fn('to_s', env[:caller], [result], env[:node].bindings)
          end
        end
        StringType.new("[#{vals.map{ |x| x.val }.join(', ')}]")
      end
      def wtf_index_op(env, index)
        if index.is_a?(IntType)
          @val[index.val]
        else
          raise Wtf::Lang::TypeError
        end
      end
    end
    class MapType < WtfType
      attr_reader :hash
      def initialize(h)
        @hash = h
      end
      def size
        @hash.size
      end
      def get_item(str)
        @hash[str]
      end
      def wtf_index_op(env, index)
        if index.is_a?(StringType)
          @hash[index.val]
        else
          raise
        end
      end
    end
    class NumericType < SimpleType
      def wtf_plus(env, other)
        if other.is_a?(NumericType)
          r = @val + other.val
          if r.is_a?(Integer)
            IntType.new(r)
          else
            raise
          end
        else
          raise
        end
      end
      def wtf_minus(env, other)
        if other.is_a?(NumericType)
          r = @val - other.val
          if r.is_a?(Integer)
            IntType.new(r)
          else
            raise
          end
        else
          raise
        end
      end
      def wtf_mul(env, other)
        if other.is_a?(NumericType)
          r = @val * other.val
          if r.is_a?(Integer)
            IntType.new(r)
          else
            raise
          end
        else
          raise
        end
      end
      def wtf_div(env, other)
        if other.is_a?(NumericType)
          r = @val / other.val
          if r.is_a?(Integer)
            IntType.new(r)
          else
            raise
          end
        else
          raise
        end
      end
      def wtf_uminus(env)
        Wtf::Lang::IntType.new(-@val)
      end
    end
    class IntType < NumericType
    end
    class FloatType < NumericType
    end
    class StringType < SimpleType
      def wtf_plus(env, other)
        StringType.new(@val + other.wtf_to_s(env).val)
      end
      def wtf_to_s(env)
        StringType.new(@val)
      end
    end
  end

  module KernelFnDefs
    include Wtf::Api
    def def_globals
      g = global_bindings
      defn('puts', g) do |env, obj|
        str_obj = execute_fn('to_s', env[:caller], [obj], env[:node].bindings)
        puts str_obj.val
        str_obj
      end
      defn('print', g) do |env, obj|
        str_obj = execute_fn('to_s', env[:caller], [obj], env[:node].bindings)
        print str_obj.val
        str_obj
      end
      defn('gets', g) do |_env|
        StringType.new(STDIN.gets)
      end
      defn('[]', g) do |env, obj, index|
        obj.wtf_index_op(env, index)
      end
      defn('each', g) do |env, collection, fn|
        collection.each do |item|
          fn_def_node_call(fn, [item], env[:node].bindings, env[:node])
        end
        collection
      end
      defn('loop', g) do |env, fn|
        loop do
          fn_def_node_call(fn, [], env[:node].bindings, env[:node])
        end
      end
      defn('eval', g) do |env, str_obj|
        Wtf.wtf_eval(str_obj.val, env[:callers_bindings])
      end
      defn('require', g) do |env, str_obj|
        Wtf.wtf_require(str_obj.val, env[:callers_bindings])
      end
      defn('to_s', g) do |env, obj|
        case obj
        when AstNode
          StringType.new(JSON.pretty_generate(JSON.parse(obj.to_json)))
        else
          obj.wtf_to_s(env)
        end
      end
      defn('true?', g) do |env, obj|
        Lang::LiteralType.new(!(obj == Lang::LiteralType.false_val || obj == Lang::LiteralType.nil_val))
      end
      defn('whats', g) do |env, obj|
        str =
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
        Lang::StringType.new(str)
      end

      def_global_vars
      def_stdlib
    end

    private
    def def_stdlib
      require_relative './rb/math'

      Wtf::Api::WtfModuleBaseHelper.instance.define_all(self)
    end
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