require 'json'

module Wtf

	class AstNode
		attr_reader :line, :col, :file, :str,
								:lexical_parent
		def initialize(**args)
			@line = args[:l]
			@col = args[:c]
			@file = args[:file]
			@str = args[:str]
		end

		def set_lexical_parent(p)
			@lexical_parent = p
		end

    def to_json(*args)
      { 
        type: self.class.to_s,
        value: 'fall back to AstNode#to_json'
      }.to_json(*args)
    end

    def location_str
			if @line && @col
				[@file, @line, @col].join(', ')
			else
				@file
      end
    end
	end

	class IdNode < AstNode
		attr_reader :name
		def initialize(name, **args)
			super(**args)
			@name = name
		end

		def is_public?
			/\A[A-Z]/ === @name
		end

    def to_json(*args)
      { 
        type: :id,
        value: @name,
				location: location_str
      }.to_json(*args)
    end
	end

	class AssignNode < AstNode
		attr_reader :identifier, :exp
		def initialize(id, exp, **args)
			super(**args)
			@identifier = id
			@exp = exp
			if @exp.is_a?(FnDefNode) || @exp.is_a?(ModNode)
				@exp.send :bind_to_var, id.name
			end
    end
    def set_lexical_parent(p)
      super
			@exp.set_lexical_parent(p)
		end
    def to_json(*args)
      {
        type: :assignment,
        id: @identifier,
        exp: exp,
				location: location_str
      }.to_json(*args)
    end
	end

	class IfNode < AstNode
		attr_reader :exp, :true_list, :false_list
		def initialize(exp, t, f = [], **args)
			super(**args)
			@exp = exp
			@true_list = t
      @false_list = f
		end
		def to_json(*args)
			{
					type: :if,
					exp: @exp,
					true: @true_list,
					false: @false_list
			}.to_json(*args)
		end
		def set_lexical_parent(p)
			super
			@exp.set_lexical_parent(p)
			@true_list.each { |it| it.set_lexical_parent(p) }
			@false_list.each { |it| it.set_lexical_parent(p) }
    end
	end

	class CaseWhenNode < AstNode
		attr_reader :exp, :when_list, :else_list, :else_bindings
		def initialize(exp, when_list, else_stmt_list, **args)
			super(**args)
			@exp = exp
			@when_list = when_list
			@else_list = else_stmt_list
			@else_bindings = nil
		end
		def to_json(*args)
			{
					type: :if,
					exp: @exp,
					when: @when_list,
					else: @else_list
			}.to_json(*args)
		end
		def set_lexical_parent(p)
			super
			@exp.set_lexical_parent(p)
			@when_list.each do |when_item|
				pm_node = when_item[:pm_node]
				stmt_list_node = when_item[:stmt_list]
				when_item[:bindings] = VM::Bindings.new(stmt_list_node, p)
				pm_node.set_lexical_parent(when_item[:bindings])
				stmt_list_node.set_lexical_parent(when_item[:bindings])
      end
      if @else_list
				@else_bindings = VM::Bindings.new(else_list, p)
        @else_list.set_lexical_parent(@else_bindings)
			end
		end
	end

	class StmtListNode < AstNode
		attr_reader :stmt_list
		def initialize(stmt_list, **args)
			super(**args)
			@stmt_list = stmt_list
		end
		def set_lexical_parent(p)
			super
      @line ||= p.entity.line
			@col ||= p.entity.line
			stmt_list.each do |code_list_item|
				code_list_item.set_lexical_parent(p)
			end
		end
    def to_json(*args)
      {
        type: :stmt_list,
        list: @stmt_list,
				location: location_str
      }.to_json(*args)
    end
  end

	class FnDefNode < AstNode
		attr_reader :args, :body, :native, :name, :bindings
		def initialize(pm_node, body, **args)
			super(**args)
			@args = pm_node
			@body = body
			@native = false
			@name = '__unbound__'
    end
    def set_lexical_parent(lexical_parent)
			super
			@bindings = VM::Bindings.new(self, @lexical_parent)
      @body.set_lexical_parent(@bindings)
		end
    def to_json(*args)
      {
          type: :fn_def,
          args: @args,
          body: body,
          location: location_str
      }.to_json(*args)
		end
		def native?
			@native
		end
		def bind_params(params)
			unless params.size == @args.size
        raise "function at #{self.line}, #{self.col}, wrong number of arguments need #{@args.size} but #{params.size} given"
			end
			@args.size.times do |i|
				@bindings.wtf_def_var(@args[i].name, params[i])
			end
		end
		def unbind_params
			@bindings.wtf_undef_all
		end
		def bind_to_var(name)
			@name = name
		end
	end

	class NativeFnDefNode < FnDefNode
		def initialize(arg_list, callable, **args)
			args[:file] ||= '<native>'
			super(arg_list, nil, **args)
			@native = true
			@callable = callable
		end

		def call(callers_bindings, params, vm)
      env = vm.construct_env(self, callers_bindings)
			@callable.(env, params)
		end
		def direct_call(env, params)
			@callable.(env, params)
		end
		def set_lexical_parent(lexical_parent)
      # NOTE: do not call super
			@lexical_parent = lexical_parent
			@bindings = VM::Bindings.new(self, @lexical_parent)
		end
	end

	class ModNode < AstNode
		attr_reader :stmt_list, :bindings, :name, :module_type
		def initialize(stmt_list, **args)
			super(**args)
			@stmt_list = stmt_list
		end
		def to_json(*args)
			{
					type: :module,
					stmt_list: @stmt_list
			}.to_json(*args)
		end
		def set_lexical_parent(p)
			super
			@bindings = VM::Bindings.new(self, p)
			@stmt_list.each { |c| c.set_lexical_parent(@bindings) }
		end
		def bind_to_var(name)
			@name = name unless @name
    end
		private
		def set_module_type(module_type)
			@module_type = module_type
		end
	end

	class ModRefNode < AstNode
		attr_reader :id_list
		def initialize(id_list, **args)
			super(**args)
			@id_list = id_list
		end
		def to_json(*args)
			{
					type: :scope_ref,
					id_list: @id_list
			}.to_json(*args)
		end
  end

	class LiteralNode < AstNode
		attr_reader :value, :wtf_value
		def initialize(value, **args)
			super(**args)
			@value = value
			@wtf_value = nil
		end
		def to_json
			raise NotImplementedError
		end
	end

	class IntNode < LiteralNode
		def initialize(val, **args)
      super(val, **args)
			@wtf_value = Wtf::Lang::IntType.new(val)
		end

		def to_json(*args)
			{
					type: :int,
					value: @value,
					location: location_str
			}.to_json(*args)
		end
		def wtf_value
			Wtf::Lang::IntType.new(@value)
		end
	end

	class StrNode < LiteralNode
		def initialize(val, **args)
			super(val, **args)
			@wtf_value = Wtf::Lang::StringType.new(val)
		end

		def to_json(*args)
			{
					type: :str,
					value: @value,
					location: location_str
			}.to_json(*args)
		end
		def wtf_value
			Wtf::Lang::StringType.new(@value)
		end
	end

	class FnCallNode < AstNode
		attr_reader :fn, :params
		def initialize(fn, params, **args)
			super(**args)
			@fn = fn
			@params = params
		end
    def to_json(*args)
      {
        type: :fn_call,
				fn: @fn,
        params: @params,
				location: location_str
      }.to_json(*args)
		end
		def set_lexical_parent(p)
			super
			@params.each do |param|
				param.set_lexical_parent(p)
			end
		end
	end

	class VarRefNode < AstNode
		attr_reader :identifier
		def initialize(id, **args)
			super(**args)
			@identifier = id
		end
		def to_json(*args)
			{
					type: :var_ref,
					id: @identifier,
					location: location_str
			}.to_json(*args)
		end
	end

	class LstNode < AstNode
		attr_reader :list
		def initialize(list, **args)
			super(**args)
			@list = list
		end
		def to_json(*args)
			{
					type: :list_def,
					list: @list
			}.to_json(*args)
		end
		def set_lexical_parent(p)
			super
			@list.each do |l|
				l.set_lexical_parent(p)
			end
		end
	end
	class MapNode < AstNode
		attr_reader :list
		def initialize(item_list, **args)
			super(**args)
			@list = item_list
		end
		def to_json(*args)
			{
					type: :map,
					list: @list,
					location: location_str
			}.to_json(*args)
		end
		def set_lexical_parent(p)
			super
			@list.each do |item|
				key, value = item[:key], item[:value]
				key.set_lexical_parent(p)
				value.set_lexical_parent(p)
			end
		end
		def get_by_name(name)
			@list.find { |item| item[:key].name == name }
		end
	end

	class PMNode < AstNode
		attr_reader :left, :right
		def initialize(left, right, **args)
			super(**args)
			@left = left
			@right = right
		end
		def set_lexical_parent(p)
			super
			@right.set_lexical_parent(p)
		end
		def to_json(*args)
			{
					type: :pm,
					left: @left,
					right: @right,
					location: location_str
			}.to_json(*args)
		end
	end
	class PMLstNode < AstNode
		attr_reader :list
		def initialize(list, **args)
			super(**args)
			@list = list
    end
    def to_json(*args)
			{
					type: :pm_list,
					list: @list,
					location: location_str
			}.to_json(*args)
		end
	end
	class PMMapNode < AstNode
		attr_reader :list
		def initialize(list, **args)
			super(**args)
			@list = list
    end
    def get_by_name(name)
			@list.find { |node| node[:key].name = name }
		end
		def to_json(*args)
			{
					type: :pm_list,
					list: @list,
					location: location_str
			}.to_json(*args)
		end
	end
	class PMModIdNode < AstNode
		ModRestMatch = :rest
		attr_reader :identifier, :mod
		def initialize(id, mod, **args)
			super(**args)
			@identifier = id
			@mod = mod
		end
		def to_json(*args)
			{
					type: :pm_mod_id,
					id: @identifier,
					mod: @mod,
					location: location_str
			}.to_json(*args)
		end
  end

	class ExceptNode < AstNode
		attr_reader :stmt_list, :pm, :rescue_list, :bindings
		def initialize(stmt_list, pm, rescue_list, **args)
			super(**args)
			@stmt_list = stmt_list
			@pm = pm
			@rescue_list = rescue_list
		end
		def set_lexical_parent(p)
			super
			@bindings = VM::Bindings.new(self, @lexical_parent)
			@pm.set_lexical_parent(@bindings)
		end
		def to_json(*args)
			{
        type: :exception,
				stmt_list: stmt_list,
				pm: @pm,
				rescue_list: @rescue_list
			}.to_json(*args)
    end
    def unbind_all
			@bindings.wtf_undef_all
		end
	end

	class Op1Node < AstNode
		attr_reader :op, :p1
		def initialize(op, p1, **args)
			super(**args)
			@op = op
			@p1 = p1
		end
		def set_lexical_parent(p)
			super
			@p1.set_lexical_parent(p)
		end
    def to_json(*args)
      {
        type: :op1,
        op: @op,
        params: [p1],
				location: location_str
      }.to_json(*args)
    end
	end
	class Op2Node < AstNode
		attr_reader :op, :p1, :p2
		def initialize(op, p1, p2, **args)
			super(**args)
			@op = op
			@p1 = p1
			@p2 = p2
		end
		def set_lexical_parent(p)
			super
			@p1.set_lexical_parent(p)
			@p2.set_lexical_parent(p)
		end
    def to_json(*args)
      {
        type: :op2,
        op: @op,
        params: [p1, p2],
				location: location_str
      }.to_json(*args)
    end
	end
	class Op3Node < AstNode
		attr_reader :op, :p1, :p2, :p3
		def initialize(op, p1, p2, p3, **args)
			super(**args)
			@op = op
			@p1 = p1
			@p2 = p2
			@p3 = p3
		end
		def set_lexical_parent(p)
			super
			@p1.set_lexical_parent(p)
			@p2.set_lexical_parent(p)
			@p3.set_lexical_parent(p)
		end
    def to_json(*args)
      {
        type: :op3,
        op: @op,
        params: [p1, p2, p3],
				location: location_str
      }.to_json(*args)
    end
	end
end
