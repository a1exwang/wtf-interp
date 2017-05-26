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
      class EOFError < WtfError; end
    end
    class WtfType
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
    class LiteralType < SimpleType
      attr_reader :name
      def self.true_val
        @true_val ||= BoolType.new(true)
      end

      def self.false_val
        @false_val ||= BoolType.new(false)
      end
      def self.nil_val
        @nil_val ||= NilType.new
      end

      def wtf_to_s(env)
        StringType.new(@name)
      end

      private
      def initialize(name)
        @name = name
      end
    end
    class BoolType < LiteralType
      def initialize(val)
        super(val ? 'True' : 'False')
      end
    end
    class NilType < LiteralType
      def initialize
        super('Nil')
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
      def wtf_to_s(env)
        Wtf::Lang::StringType.new("<module #{full_name}>")
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
    class FunctionType < WtfType
      attr_reader :node
      def wtf_call
        puts 123
      end
      def wtf_to_s(_env)
        Wtf::Lang::StringType.new('Function@%016x' % [self.object_id])
      end
      def initialize(node)
        @node = node
      end
    end

    class MetaType < WtfType
      attr_reader :full_name, :cls
      def wtf_to_s(_env)
        Wtf::Lang::StringType.new("<Type: #{self.full_name}>")
      end
    end

    class ListMetaType < MetaType
      include Wtf::Api::WtfModuleBase
      outer_name 'Type'
      module_name 'List'
      defn 'sublist' do |_env, str, start, len|
        Wtf::Lang::ListType.new(str.val[start.val...(start.val + len.val)])
      end
      defn 'is_mine' do |_env, obj|
        Wtf::Lang::BoolType.new(obj.is_a?(ListType))
      end
      def initialize
        @cls = ListType
      end
    end
    class MapMetaType < MetaType
      include Wtf::Api::WtfModuleBase
      outer_name 'Type'
      module_name 'Map'
      defn 'is_mine' do |_env, obj|
        Wtf::Lang::BoolType.new(obj.is_a?(MapType))
      end
      def initialize
        @cls = MapType
      end
    end
    class IntMetaType < MetaType
      include Wtf::Api::WtfModuleBase
      outer_name 'Type'
      module_name 'Int'
      defn 'is_mine' do |env, obj|
        Wtf::Lang::BoolType.new(obj.is_a?(IntType))
      end
      def initialize
        @cls = IntType
      end
    end
    class FloatMetaType < MetaType
      include Wtf::Api::WtfModuleBase
      outer_name 'Type'
      module_name 'Float'
      defn 'is_mine' do |env, obj|
        Wtf::Lang::BoolType.new(obj.is_a?(FloatType))
      end

      def initialize
        @cls = FloatType
      end

    end
    class StringMetaType < MetaType
      include Wtf::Api::WtfModuleBase
      outer_name 'Type'
      module_name 'String'
      defn 'substr' do |_env, str, start, len|
        Wtf::Lang::StringType.new(str.val[start.val...(start.val + len.val)])
      end
      defn 'is_mine' do |_env, obj|
        Wtf::Lang::BoolType.new(obj.is_a?(StringType))
      end

      def initialize
        @cls = StringType
      end
    end
    class FunctionMetaType < MetaType
      include Wtf::Api::WtfModuleBase
      outer_name 'Type'
      module_name 'Function'
      defn 'is_mine' do |_env, obj|
        Wtf::Lang::BoolType.new(obj.is_a?(FunctionType))
      end

      def initialize
        @cls = FunctionType
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
        Wtf::Lang::StringType.new(STDIN.gets)
      end
      defn('[]', g) do |env, obj, index|
        obj.wtf_index_op(env, index)
      end
      defn('each', g) do |env, collection, fn|
        collection.each do |item|
          fn_obj_call(fn, [item], env[:node].bindings, env[:node])
        end
        collection
      end
      defn('loop', g) do |env, fn|
        loop do
          fn_obj_call(fn, [], env[:node].bindings, env[:node])
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
              when Wtf::Lang::StringType
                'String'
              when Wtf::Lang::IntType
                'Int'
              when Wtf::Lang::ListType
                'List'
              when Lang::LiteralType.true_val, Lang::LiteralType.false_val
                'Bool'
              when Lang::LiteralType.nil_val
                'Nil'
              when Wtf::Lang::FunctionType
                'Function'
              else
                raise 'Unknown value type'
            end
        Lang::StringType.new(str)
      end
      defn('include', g) do |env, obj|
        mod_bindings = obj.bindings
        caller_bindings = env[:callers_bindings]
        mod_bindings.wtf_local_var_names.val.each do |wtf_var_name|
          name = wtf_var_name.val
          var = mod_bindings.wtf_get_var(name, '<native>')
          caller_bindings.wtf_def_var(name, var)
        end
        obj
      end
      defn('local_var_names', g) do |env|
        callers_bindings = env[:callers_bindings]
        callers_bindings.wtf_local_var_names
      end
      defn('exit', g) do |env, code = 0|
        exit(code)
      end

      def_global_vars
      def_stdlib
    end

    private
    def def_stdlib
      require_relative './rb/math'
      require_relative './rb/type'

      # This will define all wtf modules written in Ruby
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