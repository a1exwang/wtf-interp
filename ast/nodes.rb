require 'json'

module Wtf

	class AstNode
		attr_accessor :attrs
		attr_accessor :line, :col
		def initialize(l: nil, c: nil)
			self.line = l
			self.col = c
		end
    def to_json(*args)
      { 
        type: self.class.to_s,
        value: "fall back to AstNode#to_json"
      }.to_json(*args)
    end

    def location_str
      "file xx, #{@line}, #{col}"
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
        value: @name
      }.to_json(*args)
    end
	end

	class IntNode < AstNode
		attr_reader :int_value
		def initialize(val, l: nil, c: nil)
			super(l: l, c: c)
			@int_value = val
		end

    def to_json(*args)
      {
        type: :int,
        value: @int_value
      }.to_json(*args)
    end
	end

	class AssignNode < AstNode
		attr_reader :identifier, :exp
		def initialize(id, exp, l: nil, c: nil)
			@identifier = id
			@exp = exp
		end
    def to_json(*args)
      {
        type: :assignment,
        id: @identifier,
        exp: exp
      }.to_json(*args)
    end
	end

	class CodeListNode < AstNode
		attr_reader :code_list
		def initialize(code_list, l: nil, c: nil)
			@code_list = code_list
		end
    def to_json(*args)
      {
        type: :code_list,
        list: @code_list
      }.to_json(*args)
    end
	end

	class FnDefNode < AstNode
		attr_reader :arg_list, :body, :native
		def initialize(arg_list, body, l: nil, c: nil)
			super(l: l, c: c)
			@arg_list = arg_list
			@body = body
			@native = false
		end
    def to_json(*args)
      {
        type: :fn_def,
        arg_list: @arg_list,
        body: body
      }.to_json(*args)
		end
		def native?
			@native
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
        params: @params
      }.to_json(*args)
    end
	end

	class Op1Node < AstNode
		attr_reader :op, :p1
		def initialize(op, p1)
			@op = op
			@p1 = p1
		end
    def to_json(*args)
      {
        type: :op1,
        op: @op,
        params: [p1]
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
    def to_json(*args)
      {
        type: :op2,
        op: @op,
        params: [p1, p2]
      }.to_json(*args)
    end
	end
	class Op3Node < AstNode
		attr_reader :op, :p1
		def initialize(op, p1, p2, p3, l: nil, c: nil)
			super(l: l, c: c)
			@op = op
			@p1 = p1
			@p2 = p2
			@p3 = p3
		end
    def to_json(*args)
      {
        type: :op3,
        op: @op,
        params: [p1, p2, p3]
      }.to_json(*args)
    end
	end

end
