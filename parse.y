class Wtf::Parser
prechigh
	nonassoc UMINUS
	left STAR SLASH # * /
	left PLUS HYPHEN # + -
	right EQ
preclow
start root
rule
	# simple items
	identifier: IDENTIFIER {
		    result = IdNode.new(val[0][:str], l: val[0][:line], c: val[0][:col])
		}
	integer: INTEGER {
		    result = IntNode.new(val[0][:value], l: val[0][:line], c: val[0][:col])
		}
	string: STRING {
	        result = StrNode.new(val[0][:value], l: val[0][:line], c: val[0][:col])
	    }

	# root node
  root: exp { 
		result = val[0]
	}

	exp: exp PLUS exp { result = Op2Node.new(:plus, val[0], val[2], l: val[1][:line], c: val[1][:col]) }
     | exp HYPHEN exp { result = Op2Node.new(:minus, val[0], val[2], l: val[1][:line], c: val[1][:col]) }
     | exp STAR exp { result = Op2Node.new(:mul, val[0], val[2], l: val[1][:line], c: val[1][:col]) }
     | exp SLASH exp { result = Op2Node.new(:div, val[0], val[2], l: val[1][:line], c: val[1][:col]) }
     | HYPHEN exp =UMINUS { result = Op1Node.new(:minus, val[1], l: val[0][:line], c: val[0][:col]) }
     | LPAR exp RPAR { result = val[1] }
     | identifier { result = VarRefNode.new(val[0], l: val[0].line, c: val[0].col) }
     | integer { result = val[0] }
     | string { result = val[0] }
     | assignment { result = val[0] }
     | fn_def { result = val[0] }
     | fn_call { result = val[0] }

	# assignment exp
	assignment: identifier EQ exp {
			result = AssignNode.new(val[0], val[2], l: val[1][:line], c: val[1][:col])
		}

	# function def
	fn_def: FN_BEGIN_AND_LPAR fn_arg_list fn_body FN_END {
			result = FnDefNode.new(val[1], val[2], l: val[0][:line], c: val[0][:col])
		}	
		| FN_BEGIN fn_body FN_END {
			result = FnDefNode.new([], val[1], l: val[0][:line], c: val[0][:col])
		}
	fn_arg_list: fn_arg_list_real RPAR { result = val[0] }
	fn_arg_list_real_item: identifier { result = val[0] }
	fn_arg_list_real: fn_arg_list_real_item COMMA fn_arg_list_real { 
			result = [val[0], *val[2]] 
		}
		| fn_arg_list_real_item { result = [val[0]] }
		| { result = []	}
	fn_body: code_list { result = CodeListNode.new(val[0], l: val[0].first&.line, c: val[0].first&.col) }
	code_list: { result = [] }
		| exp SEMICOLON code_list {
			result = [val[0], *val[2]]
		}

	# function call
	fn_call: identifier LPAR fn_call_params_list RPAR {
			result = FnCallNode.new(val[0], val[2], l: val[0].line, c: val[0].col)
		}
	fn_call_params_list: exp COMMA fn_call_params_list {
			result = [val[0], *val[2]]
		}
		| exp { result = [val[0]] }
		| { result = [] }



---- header
	require_relative 'ast/nodes'

---- inner
	def parse(lexer)
    @lexer = lexer
		do_parse
	end

	def next_token
		@lexer.next_token
	end

---- footer
