module Wtf

	class AstNode
		attr_accessor :attrs
		attr_accessor :line, :col
		def initialize(l: nil, c: nil)
			self.line = l
			self.col = c
		end

	end

	class IdNode < AstNode
		attr_reader :name
		def initialize(name, l: nil, c: nil)
			super(l: l, c: c)
			@name = name
		end
	end

	class IntNode < AstNode
		attr_reader :int_value
		def initialize(val, l: nil, c: nil)
			super(l: l, c: c)
			@int_value = val
		end
	end

	class AssignNode < AstNode
		attr_reader :identifier, :exp
		def initialize(id, exp, l: nil, c: nil)
			@identifier = id
			@exp = exp
		end
	end

	class CodeListNode < AstNode
		attr_reader :code_list
		def initialize(code_list, l: nil, c: nil)
			@code_list = code_list
		end
	end

	class FnDefNode < AstNode
		attr_reader :arg_list, :body
		def initialize(arg_list, body, l: nil, c: nil)
			super(l: l, c: c)
			@arg_list = arg_list
			@body = body
		end
	end

	class FnCallNode < AstNode
		attr_reader :identifier, :params
		def initialize(id, params, l: nil, c: nil)
			super(l: l, c: c)
			@identifier = id
			@params = params
		end
	end

	class Op1Node < AstNode
		attr_reader :op, :p1
		def initialize(op, p1)
			@op = op
			@p1 = p1
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
	end

end
