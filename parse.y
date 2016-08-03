class Wtf::Parser
prechigh
	left '('
	left '*'
	left '+'
	right EQ
preclow
start target
rule
	# simple items
	identifier: IDENTIFIER {
		result = IdNode.new(val[0][:str], l: val[0][:line], c: val[0][:col])
		}
	integer: INTEGER {
		result = IntNode.new(val[0][:value], l: val[0][:line], c: val[0][:col])
		}

	# root node
	target: exp { 
		result = val[0]
		puts result.inspect
	}

	exp: exp '+' exp
		 | exp '*' exp
		 | LPAR exp RPAR
		 | integer
		 | assignment
		 | fn_def { result = val[0] }
		 | fn_call { result = val[0] } 

	# assignment exp
	assignment: identifier EQ exp {
			result = AssignNode.new(val[0], val[2], l: val[0].line, c: val[0].col)
		}

	# function def
	fn_def: FN_BEGIN fn_arg_list fn_body FN_END {
			result = FnDefNode.new(val[1], val[2], l: val[0][:line], c: val[0][:col])
		}	
		| FN_BEGIN fn_body FN_END {
			result = FnDefNode.new([], val[1], l: val[0][:line], c: val[0][:col])
		}
	fn_arg_list: LPAR fn_arg_list_real RPAR { result = val[1] }
	fn_arg_list_real_item: identifier { result = val[0] }
	fn_arg_list_real: fn_arg_list_real_item COMMA fn_arg_list_real { 
			result = [val[0], *val[2]] 
		}
		| fn_arg_list_real_item { result = [val[0]] }
		| { result = []	}
	fn_body: code_list { result = val[0] }
	code_list:  { result = [] }
		| exp { result = [val[0]] }
		| exp SEMICOLON code_list {
			result = [val[0], *val[2]]
		}

	# function call
	fn_call: identifier LPAR fn_call_params_list RPAR {
			result = FnCallNode.new(val[0], val[2], l: val[0][:line], c: val[0][:col])
		}
	fn_call_params_list: exp COMMA fn_call_params_list {
			result = [val[0], *val[2]]
		}
		| exp { result = [val[0]] }
		| { result = [] }



---- header
	require_relative 'ast/nodes'

---- inner

	def initialize(lexer)
		@lexer = lexer
	end

	def parse
		do_parse
	end

	def next_token
		@lexer.next_token
	end

---- footer
