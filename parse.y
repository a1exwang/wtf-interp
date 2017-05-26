class Wtf::Parser
prechigh
    nonassoc LPAR
    right DOT COLON2
	left LPAR
	left LBRAC
	left LBRACK
	nonassoc UMINUS
	left STAR SLASH         # * /
	left PLUS HYPHEN        # + -
	right EQ
	right FN_BEGIN FN_BEGIN_AND_LPAR
	right RPAR RBRAC RBRACK
preclow
start root
rule
	# simple items
	identifier: IDENTIFIER {
		    result = IdNode.new(val[0][:str], loc_of(val[0]))
		}
	integer: INTEGER {
		    result = IntNode.new(val[0][:value], loc_of(val[0]))
		}
	string: STRING {
	        result = StrNode.new(val[0][:value], loc_of(val[0]))
	    }
	exp_comma_list: exp COMMA exp_comma_list {
			result = [val[0], *val[2]]
		}
		| exp { result = [val[0]] }
		| { result = [] }

	# assignment exp
	assignment: identifier EQ exp {
			result = AssignNode.new(val[0], val[2], loc_of(val[0]))
		}

	# root node
	root: exp { result = StmtListNode.new([val[0]], loc_of(val[0])) }
	  | stmt_list {
	    if val[0].size > 0
        result = StmtListNode.new(val[0], loc_of(val[0][0]))
	    else
	      result = StmtListNode.new(val[0])
	    end
	  }
	stmt: exp { result = val[0] }
	  | LET pm EQ exp { result = PMNode.new(val[1], val[3], loc_of(val[0])) }

    # statement list,
	stmt_list: stmt_list_real { result = val[0] }
	stmt_list_real: { result = [] }
		| stmt SEMICOLON stmt_list_real {
			result = [val[0], *val[2]]
		}

	pm: LBRAC pm_map RBRAC { result = PMMapNode.new(val[1], loc_of(val[0])) }
	 | LBRACK pm_list RBRACK { result = PMLstNode.new(val[1], loc_of(val[0])) }
	 | identifier { result = val[0] }
	 | STAR identifier { result = PMModIdNode.new(val[1], PMModIdNode::ModRestMatch, loc_of(val[0])) }
	pm_list: { result = [] }
	 | pm { result = [val[0]] }
	 | pm COMMA pm_list { result = [val[0], *val[2]] }
	pm_map: { result = {} }
	 | identifier COLON pm { result = [{key: val[0], value: val[2]}] }
	 | identifier COLON pm COMMA pm_map {result = [{key: val[0], value: val[2]}, *val[4]]}

	exp: exp PLUS exp { result = Op2Node.new(:plus, val[0], val[2], loc_of(val[0])) }
     | exp HYPHEN exp { result = Op2Node.new(:minus, val[0], val[2], loc_of(val[0])) }
     | exp STAR exp { result = Op2Node.new(:mul, val[0], val[2], loc_of(val[0])) }
     | exp SLASH exp { result = Op2Node.new(:div, val[0], val[2], loc_of(val[0])) }
     | HYPHEN exp =UMINUS { result = Op1Node.new(:minus, val[1], loc_of(val[0])) }
     | LPAR exp RPAR { result = val[1] }
     | identifier { result = VarRefNode.new(val[0], loc_of(val[0])) }
     | integer { result = val[0] }
     | string { result = val[0] }
     | assignment { result = val[0] }
     | fn_def { result = val[0] }
     | fn_call { result = val[0] }
     | list_def { result = val[0] }
     | map_def { result = val[0] }
     | index_operator { result = val[0] }
     | mod_def { result = val[0] }
     | mod_scope { result = val[0] }
     | condition { result = val[0] }
     | exception { result = val[0] }

	# function def
	fn_def: FN_BEGIN_AND_LPAR fn_arg_list_rpar fn_body {
			result = FnDefNode.new(val[1], val[2], loc_of(val[0]))
		}
		| FN_BEGIN fn_body {
			result = FnDefNode.new([], val[1], loc_of(val[0]))
		}
	fn_arg_list_rpar: fn_arg_list_real RPAR { result = val[0] }
	fn_arg_list_real_item: identifier { result = val[0] }
	fn_arg_list_real: fn_arg_list_real_item COMMA fn_arg_list_real { 
			result = [val[0], *val[2]]
		}
		| fn_arg_list_real_item { result = [val[0]] }
		| { result = []	}
	fn_body: LBRAC stmt_list RBRAC {
            result = StmtListNode.new(val[1], loc_of(val[0]));
	    }

	# function call
	fn_call: exp LPAR exp_comma_list RPAR {
			result = FnCallNode.new(val[0], val[2], loc_of(val[0]))
		}

    # list def
    list_def: LBRACK exp_comma_list RBRACK {
            result = LstNode.new(val[1], loc_of(val[0]))
        }

    # a[b]
    index_operator: exp LBRACK exp_comma_list RBRACK {
            result = FnCallNode.new(VarRefNode.new(IdNode.new("[]")), [val[0]] + val[2], loc_of(val[1]))
        }

    # map def
    map_def: LBRAC map_list RBRAC { result = MapNode.new(val[1], loc_of(val[0])) }
    map_list: { result = [] }
        | map_list_item { result = [val[0]] }
        | map_list_item COMMA map_list {
            result = [val[0], *val[2]]
        }
    map_list_item: identifier COLON exp {
            result = { key: val[0], value: val[2] }
        }

    # conditional expression
    condition: IF exp LBRAC stmt_list RBRAC ELSE LBRAC stmt_list RBRAC {
            result = IfNode.new(val[1], val[3], val[7], loc_of(val[0]))
        }

    # module definition
    mod_def: MODULE LBRAC stmt_list RBRAC {
            result = ModNode.new(val[2], loc_of(val[0]))
        }
    mod_scope: mod_scope_real {
            result = ModRefNode.new(val[0], val[0].first ? loc_of(val[0].first) : nil)
        }
    mod_scope_real: identifier COLON2 mod_scope_real {
            result = [val[0], *val[2]]
        }
        | identifier COLON2 identifier {
            result = [val[0], val[2]]
        }

    # exception rescue
    exception: EXCEPTION_BEGIN LBRAC stmt_list RBRAC EXCEPTION_RESCUE pm LBRAC stmt_list RBRAC {
            result = ExceptNode.new(val[2], val[5], val[7], loc_of(val[0]))
        }

---- header
	require_relative 'ast/nodes'

---- inner
    def loc_of(val)
      if val.is_a?(Wtf::AstNode)
        { file: val.file, str: val.str, l: val.line, c: val.col }
      else
        { file: val[:file], str: val[:str], l: val[:line], c: val[:col] }
      end
    end

	def parse(lexer)
    @lexer = lexer
		do_parse
	end

	def next_token
		@lexer.next_token
	end

---- footer
