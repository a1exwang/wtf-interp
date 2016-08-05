class Wtf::Parser
prechigh
    nonassoc LPAR
    right DOT COLON2
	nonassoc LBRACK
	nonassoc UMINUS
	left STAR SLASH # * /
	left PLUS HYPHEN # + -
	right EQ
	right FN_BEGIN FN_BEGIN_AND_LPAR
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
	exp_comma_list: exp COMMA exp_comma_list {
			result = [val[0], *val[2]]
		}
		| exp { result = [val[0]] }
		| { result = [] }

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
     | list_def { result = val[0] }
     | list_ref { result = val[0] }
     | mod_def { result = val[0] }
     | mod_scope { result = val[0] }
     | condition { result = val[0] }

	# assignment exp
	assignment: identifier EQ exp {
			result = AssignNode.new(val[0], val[2], l: val[1][:line], c: val[1][:col])
		}

	# function def
	fn_def: FN_BEGIN_AND_LPAR fn_arg_list_rpar LBRAC fn_body RBRAC {
			result = FnDefNode.new(val[1], val[3], l: val[0][:line], c: val[0][:col])
		}
		| FN_BEGIN LBRAC fn_body RBRAC {
			result = FnDefNode.new([], val[2], l: val[0][:line], c: val[0][:col])
		}
		| FN_BEGIN_AND_LPAR fn_arg_list_rpar exp {
		    result = FnDefNode.new(val[1], [val[2]], l: val[0][:line], c: val[0][:col])
		}
		| FN_BEGIN exp {
		    result = FnDefNode.new([], [val[1]], l: val[0][:line], c: val[0][:col])
		}

	fn_arg_list_rpar: fn_arg_list_real RPAR { result = val[0] }
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
	fn_call: exp LPAR exp_comma_list RPAR {
			result = FnCallNode.new(val[0], val[2], l: val[0].line, c: val[0].col)
		}

    # list def
    list_def: LBRACK exp_comma_list RBRACK {
            result = LstNode.new(val[1], l: val[0][:line], c: val[0][:col])
        }
    # list ref
    list_ref: exp LBRACK exp_comma_list RBRACK {
            result = FnCallNode.new(VarRefNode.new(IdNode.new("[]")), [val[0]] + val[2], l: val[1][:line], c: val[1][:col])
        }

    # conditional expression
    condition: IF exp LBRAC code_list RBRAC ELSE LBRAC code_list RBRAC {
            result = IfNode.new(val[1], val[3], val[7], l: val[0][:line], c: val[0][:col])
        }

    # module definition
    mod_def: MODULE LBRAC code_list RBRAC {
            result = ModNode.new(val[2], l: val[0][:line], c: val[0][:col])
        }
    mod_scope: mod_scope_real {
            result = ModRefNode.new(val[0], l: val[0].first&.line, c: val[0].first&.col)
        }
    mod_scope_real: identifier COLON2 mod_scope_real {
            result = [val[0], *val[2]]
        }
        | identifier COLON2 identifier {
            result = [val[0], val[2]]
        }

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
