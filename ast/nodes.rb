require 'json'

module Wtf

	class AstNode
		attr_accessor :attrs
		attr_reader :line, :col
		def initialize(l: nil, c: nil)
			@line = l
			@col = c
		end

		def set_lexical_parent(p)
		end

    def to_json(*args)
      { 
        type: self.class.to_s,
        value: 'fall back to AstNode#to_json'
      }.to_json(*args)
    end

    def location_str
      "file, #{line}, #{col}"
    end
	end

	class IdNode < AstNode
		attr_reader :name
		def initialize(name, l: nil, c: nil)
			super(l: l, c: c)
			@name = name
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
		def initialize(id, exp, l: nil, c: nil)
			super(l: l, c: c)
			@identifier = id
			@exp = exp
			if @exp.is_a?(FnDefNode)
				@exp.send :assign_to_var, id.name
			end
    end
    def set_lexical_parent(p)
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

	class CodeListNode < AstNode
		attr_reader :code_list
		def initialize(code_list, l: nil, c: nil)
			@code_list = code_list
		end
		def set_lexical_parent(p)
			code_list.each do |code_list_item|
				code_list_item.set_lexical_parent(p)
			end
		end
    def to_json(*args)
      {
        type: :code_list,
        list: @code_list,
				location: location_str
      }.to_json(*args)
    end
  end

	class FnDefNode < AstNode
		attr_reader :arg_list, :body, :native, :name, :bindings
		def initialize(arg_list, body, l: nil, c: nil)
			super(l: l, c: c)
			@arg_list = arg_list
			@body = body
			@native = false
			@name = '__unbound__'
    end
    def set_lexical_parent(lexical_parent)
			@lexical_parent = lexical_parent
			@bindings = VM::Bindings.new(self, @lexical_parent)
      @body.set_lexical_parent(@bindings)
		end
    def to_json(*args)
      {
        type: :fn_def,
        arg_list: @arg_list,
        body: body,
				location: location_str
      }.to_json(*args)
		end
		def native?
			@native
		end
		def bind_params(params)
			unless params.size == @arg_list.size
        raise "function at #{self.line}, #{self.col}, wrong number of arguments need #{@arg_list.size} but #{params.size} given"
			end
			@arg_list.size.times do |i|
				@bindings.wtf_def_var(@arg_list[i].name, params[i])
			end
		end
		def assign_to_var(name)
			@name = name
		end
	end

	class NativeFnDefNode < FnDefNode
		def initialize(arg_list, callable)
			super(arg_list, nil)
			@native = true
			@callable = callable
		end

		def call(params)
			@callable.call(params)
		end
	end

	class LiteralNode < AstNode
		attr_reader :value
		def initialize(value, l: nil, c: nil)
			super(l: l, c: c)
			@value = value
		end
		def to_json
			raise NotImplementedError
		end
	end

	class IntNode < LiteralNode
		def initialize(val, l: nil, c: nil)
      super(val, l: l, c: c)
		end

		def to_json(*args)
			{
					type: :int,
					value: @value,
					location: location_str
			}.to_json(*args)
		end
	end

	class StrNode < LiteralNode
		def initialize(val, l: nil, c: nil)
			super(val, l: l, c: c)
		end

		def to_json(*args)
			{
					type: :str,
					value: @value,
					location: location_str
			}.to_json(*args)
		end
	end

	class FnCallNode < AstNode
		attr_reader :identifier, :params
		def initialize(id, params, l: nil, c: nil)
			super(l: l, c: c)
			@identifier = id
			@params = params
		end
    def to_json(*args)
      {
        type: :fn_call,
        id: @identifier, 
        params: @params,
				location: location_str
      }.to_json(*args)
    end
	end

	class VarRefNode < AstNode
		attr_reader :identifier
		def initialize(id, l: nil, c: nil)
			super(l: l, c: c)
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

	class Op1Node < AstNode
		attr_reader :op, :p1
		def initialize(op, p1)
			@op = op
			@p1 = p1
		end
		def set_lexical_parent(p)
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
		def initialize(op, p1, p2, l: nil, c: nil)
			super(l: l, c: c)
			@op = op
			@p1 = p1
			@p2 = p2
		end
		def set_lexical_parent(p)
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
		def initialize(op, p1, p2, p3, l: nil, c: nil)
			super(l: l, c: c)
			@op = op
			@p1 = p1
			@p2 = p2
			@p3 = p3
		end
		def set_lexical_parent(p)
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
