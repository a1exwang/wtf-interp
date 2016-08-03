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
		def initialize(id, params)
			@identifier = id
			@params = params
		end
	end

end
