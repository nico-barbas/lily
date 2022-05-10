package lily

import "core:strconv"
import "core:strings"
import "core:fmt"

//odinfmt: disable
parser_rules := map[Token_Kind]struct {
	prec:      Precedence,
	prefix_fn: proc(p: ^Parser) -> (Expression, Error),
	infix_fn:  proc(p: ^Parser, left: Expression) -> (Expression, Error),
} {
	.Identifier =      {prec = .Lowest,  prefix_fn = parse_identifier, infix_fn = nil},
	.Number_Literal =  {prec = .Lowest,  prefix_fn = parse_number    , infix_fn = nil},
    .String_Literal =  {prec = .Lowest,  prefix_fn = parse_string    , infix_fn = nil},
	.Array =           {prec = .Lowest,  prefix_fn = parse_array     , infix_fn = nil},
	.True =            {prec = .Lowest,  prefix_fn = parse_boolean   , infix_fn = nil},
	.False =           {prec = .Lowest,  prefix_fn = parse_boolean   , infix_fn = nil},
	.Not = 	           {prec = .Unary  ,  prefix_fn = parse_unary     , infix_fn = nil},
	.Plus =            {prec = .Term  ,  prefix_fn = nil             , infix_fn = parse_binary},
	.Minus =           {prec = .Term  ,  prefix_fn = parse_unary     , infix_fn = parse_binary},
	.Star =            {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Slash =           {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Percent =         {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.And =             {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Or =              {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Open_Paren =      {prec = .Highest, prefix_fn = parse_group     , infix_fn = parse_call},
	.Open_Bracket =    {prec = .Highest, prefix_fn = nil             , infix_fn = parse_index},
}
//odinfmt: enable

Parser :: struct {
	lexer:    Lexer,
	current:  Token,
	previous: Token,
}

Precedence :: enum {
	Lowest,
	Asssignment,
	Or,
	And,
	Equality,
	Comparison,
	Term,
	Factor,
	Unary,
	Highest,
}

Program :: struct {
	source: [dynamic]string,
	nodes:  [dynamic]Node,
}

make_program :: proc() -> ^Program {
	return new_clone(Program{source = make([dynamic]string), nodes = make([dynamic]Node)})
}

delete_program :: proc(p: ^Program) {
	for s in p.source {
		delete(s)
	}
	delete(p.source)
	free(p)
}

append_to_program :: proc(i: string, program: ^Program) -> (err: Error) {
	input := strings.clone(i)
	append(&program.source, input)
	parser := Parser {
		lexer = Lexer{},
	}
	set_lexer_input(&parser.lexer, input)
	ast: for {
		node := parse_node(&parser) or_return
		if node != nil {
			append(&program.nodes, node)
		} else if parser.current.kind == .EOF {
			break ast
		}
	}
	return
}

consume_token :: proc(p: ^Parser) -> Token {
	p.previous = p.current
	p.current = scan_token(&p.lexer)
	return p.current
}

peek_next_token :: proc(p: ^Parser) -> (result: Token) {
	start := p.lexer.current
	result = scan_token(&p.lexer)
	p.lexer.current = start
	return
}

match_token_kind :: proc(p: ^Parser, kind: Token_Kind) -> (err: Error) {
	if p.current.kind != kind {
		err = Parsing_Error {
			kind    = .Invalid_Syntax,
			token   = p.current,
			details = fmt.tprintf("Expected %s, got %s", kind, p.current.kind),
		}
	}
	return
}

match_token_kind_next :: proc(p: ^Parser, kind: Token_Kind) -> (err: Error) {
	if consume_token(p).kind != kind {
		err = Parsing_Error {
			kind    = .Invalid_Syntax,
			token   = p.current,
			details = fmt.tprintf("Expected %s, got %s", kind, p.current.kind),
		}
	}
	return
}

parse_node :: proc(p: ^Parser) -> (result: Node, err: Error) {
	token := consume_token(p)
	#partial switch token.kind {
	case .EOF:
		result = nil
	case .Var:
		result, err = parse_var_decl(p)
	case .Fn:
		result, err = parse_fn_decl(p)
	case .Identifier:
		next := peek_next_token(p)
		#partial switch next.kind {
		case .Assign:
			result, err = parse_assign_stmt(p)
		case:
			result, err = parse_expression_stmt(p)
		}
	case .If:
		result, err = parse_if_stmt(p)
	case .For:
		result, err = parse_range_stmt(p)
	case:
		// Expression statement most likely
		result = nil
	}
	return
}

parse_expression_stmt :: proc(p: ^Parser) -> (result: ^Expression_Statement, err: Error) {
	result = new(Expression_Statement)
	result.expr = parse_expr(p, .Lowest) or_return
	return
}

parse_assign_stmt :: proc(p: ^Parser) -> (result: ^Assignment_Statement, err: Error) {
	result = new(Assignment_Statement)
	result.left = parse_expr(p, .Lowest) or_return
	consume_token(p)
	result.right = parse_expr(p, .Lowest) or_return
	return
}

parse_if_stmt :: proc(p: ^Parser) -> (result: ^If_Statement, err: Error) {
	parse_branch :: proc(p: ^Parser, is_end_branch: bool) -> (result: ^If_Statement, err: Error) {
		result = new(If_Statement)
		switch is_end_branch {
		case true:
			result.condition = new_clone(Literal_Expression{value = Value{kind = .Boolean, data = true}})
			result.body = new_clone(Block_Statement{nodes = make([dynamic]Node)})
			else_body: for {
				body_node := parse_node(p) or_return
				if body_node != nil {
					append(&result.body.nodes, body_node)
				}
				if p.current.kind == .End {
					break else_body
				}
			}
		case false:
			consume_token(p)
			result.condition = parse_expr(p, .Lowest) or_return
			match_token_kind_next(p, .Colon) or_return
			result.body = new_clone(Block_Statement{nodes = make([dynamic]Node)})
			else_if_body: for {
				body_node := parse_node(p) or_return
				if body_node != nil {
					append(&result.body.nodes, body_node)
				}
				#partial switch p.current.kind {
				case .End:
					break else_if_body
				case .Else:
					#partial switch consume_token(p).kind {
					case .If:
						result.next_branch = parse_branch(p, false) or_return
					case .Colon:
						result.next_branch = parse_branch(p, true) or_return
					case:
						err = Parsing_Error {
							kind    = .Invalid_Syntax,
							token   = p.current,
							details = fmt.tprintf(
								"Expected one of: %s, %s, got %s",
								Token_Kind.If,
								Token_Kind.Colon,
								p.current.kind,
							),
						}
					}
				}
			}
		}
		return
	}

	result = new(If_Statement)
	consume_token(p)
	result.condition = parse_expr(p, .Lowest) or_return
	match_token_kind(p, .Colon) or_return

	result.body = new_clone(Block_Statement{nodes = make([dynamic]Node)})
	body: for {
		body_node := parse_node(p) or_return
		if body_node != nil {
			append(&result.body.nodes, body_node)
		}
		#partial switch p.current.kind {
		case .End:
			break body
		case .Else:
			#partial switch consume_token(p).kind {
			case .If:
				result.next_branch = parse_branch(p, false) or_return
				break body
			case .Colon:
				result.next_branch = parse_branch(p, true) or_return
				break body
			case:
				err = Parsing_Error {
					kind    = .Invalid_Syntax,
					token   = p.current,
					details = fmt.tprintf(
						"Expected one of: %s, %s, got %s",
						Token_Kind.If,
						Token_Kind.Colon,
						p.current.kind,
					),
				}
			}
		}
	}
	return
}

parse_range_stmt :: proc(p: ^Parser) -> (result: ^Range_Statement, err: Error) {
	result = new(Range_Statement)
	name_token := consume_token(p)
	if name_token.kind == .Identifier {
		result.iterator_name = name_token.text
		match_token_kind_next(p, .In) or_return
		consume_token(p)
		result.low = parse_expr(p, .Lowest) or_return
		#partial switch p.current.kind {
		case .Double_Dot:
			result.op = .Exclusive
		case .Triple_Dot:
			result.op = .Inclusive
		case:
			err = Parsing_Error {
				kind    = .Invalid_Syntax,
				token   = p.current,
				details = fmt.tprintf(
					"Expected one of: %s, %s, got %s",
					Token_Kind.Double_Dot,
					Token_Kind.Triple_Dot,
					p.current.kind,
				),
			}
			return
		}
		consume_token(p)
		result.high = parse_expr(p, .Lowest) or_return

		result.body = new_clone(Block_Statement{nodes = make([dynamic]Node)})
		body: for {
			body_node := parse_node(p) or_return
			if body_node != nil {
				append(&result.body.nodes, body_node)
			}
			if p.current.kind == .End {
				break body
			}
		}

	} else {
		err = Parsing_Error {
			kind    = .Invalid_Syntax,
			token   = p.current,
			details = fmt.tprintf("Expected %s, got %s", Token_Kind.Identifier, p.current.kind),
		}
	}
	return
}

parse_var_decl :: proc(p: ^Parser) -> (result: ^Var_Declaration, err: Error) {
	result = new(Var_Declaration)

	name_token := consume_token(p)
	if name_token.kind == .Identifier {
		result.identifier = name_token.text
		next := consume_token(p)
		#partial switch next.kind {
		case .Assign:
			consume_token(p)
			result.type_name = "unresolved"
			result.expr, err = parse_expr(p, .Lowest)

		case .Colon:
			result.type_name = consume_token(p).text
			match_token_kind_next(p, .Assign) or_return
			consume_token(p)
			result.expr, err = parse_expr(p, .Lowest)

		case:
			err = Parsing_Error {
				kind    = .Invalid_Syntax,
				token   = p.current,
				details = fmt.tprintf(
					"Expected one of: %s, %s, got %s",
					Token_Kind.Assign,
					Token_Kind.Colon,
					p.current.kind,
				),
			}
		}
	} else {
		err = Parsing_Error {
			kind    = .Invalid_Syntax,
			token   = p.current,
			details = fmt.tprintf("Expected %s, got %s", Token_Kind.Identifier, p.current.kind),
		}
	}

	return
}

parse_fn_decl :: proc(p: ^Parser) -> (result: ^Fn_Declaration, err: Error) {
	result = new(Fn_Declaration)
	name_token := consume_token(p)
	if name_token.kind == .Identifier {
		result.identifier = name_token.text
		match_token_kind_next(p, .Open_Paren) or_return

		// FIXME: Account for parameterless functions
		params: for {
			match_token_kind_next(p, .Identifier) or_return
			result.parameters[result.param_count].name = p.current.text

			match_token_kind_next(p, .Colon) or_return
			if !is_type_token(consume_token(p).kind) {
				err = Parsing_Error {
					kind    = .Invalid_Syntax,
					token   = p.current,
					details = fmt.tprintf("Expected type token, got %s", p.current.kind),
				}
				return
			}
			result.parameters[result.param_count].type_name = p.current.text
			result.param_count += 1

			consume_token(p)
			#partial switch p.current.kind {
			case .Comma:
				continue params
			case .Close_Paren:
				break params
			case:
				err = Parsing_Error {
					kind    = .Invalid_Syntax,
					token   = p.current,
					details = fmt.tprintf(
						"Expected one of: %s, %s, got %s",
						Token_Kind.Comma,
						Token_Kind.Close_Paren,
						p.current.kind,
					),
				}
				return
			}
		}

		match_token_kind_next(p, .Colon) or_return

		if is_type_token(consume_token(p).kind) {
			result.return_type_name = p.current.text
			consume_token(p)
		}

		// FIXME: Refactor into separate procedure
		result.body = new_clone(Block_Statement{nodes = make([dynamic]Node)})
		body: for {
			body_node := parse_node(p) or_return
			if body_node != nil {
				append(&result.body.nodes, body_node)
			}
			if p.current.kind == .End {
				break body
			}
		}
	} else {
		err = Parsing_Error {
			kind    = .Invalid_Syntax,
			token   = p.current,
			details = fmt.tprintf("Expected %s, got %s", Token_Kind.Identifier, p.current.kind),
		}
	}
	return
}

parse_expr :: proc(p: ^Parser, prec: Precedence) -> (result: Expression, err: Error) {
	consume_token(p)
	if rule, exist := parser_rules[p.previous.kind]; exist {
		result = rule.prefix_fn(p) or_return
	}
	for p.current.kind != .EOF && prec < parser_rules[p.current.kind].prec {
		consume_token(p)
		if rule, exist := parser_rules[p.previous.kind]; exist {
			result = rule.infix_fn(p, result) or_return
		}
	}
	return
}

parse_identifier :: proc(p: ^Parser) -> (result: Expression, err: Error) {
	err = nil
	result = new_clone(Identifier_Expression{name = p.previous.text})
	return
}

parse_number :: proc(p: ^Parser) -> (result: Expression, err: Error) {
	num, ok := strconv.parse_f64(p.previous.text)
	if ok {
		result = new_clone(Literal_Expression{value = Value{kind = .Number, data = num}})
	} else {
		err = Parsing_Error {
			kind  = .Malformed_Number,
			token = p.previous,
		}
	}
	return
}

parse_boolean :: proc(p: ^Parser) -> (result: Expression, err: Error) {
	b := false if p.previous.kind == .False else true
	result = new_clone(Literal_Expression{value = Value{kind = .Boolean, data = b}})
	return
}

parse_string :: proc(p: ^Parser) -> (result: Expression, err: Error) {
	result = new_clone(String_Literal_Expression{value = p.previous.text[1:len(p.previous.text) - 1]})
	return
}

parse_array :: proc(p: ^Parser) -> (result: Expression, err: Error) {
	// check that the syntax is right: "array of T"
	match_token_kind(p, .Of) or_return
	if is_type_token(consume_token(p).kind) {
		array := new_clone(Array_Literal_Expression{value_type_name = p.current.text})
		match_token_kind_next(p, .Open_Bracket) or_return
		array_elements: for {
			consume_token(p)
			element := parse_expr(p, .Lowest) or_return
			append(&array.values, element)
			#partial switch p.current.kind {
			case .Close_Bracket:
				break array_elements
			case .Comma:
				continue array_elements
			case:
				err = Parsing_Error {
					kind    = .Invalid_Syntax,
					token   = p.current,
					details = fmt.tprintf(
						"Expected one of: %s, %s, got %s",
						Token_Kind.Comma,
						Token_Kind.Close_Bracket,
						p.current.kind,
					),
				}
				return
			}
		}
		result = array
		fmt.println(result)
	} else {
		err = Parsing_Error {
			kind    = .Invalid_Syntax,
			token   = p.current,
			details = fmt.tprintf("Expected %s, got %s", Token_Kind.Identifier, p.current.kind),
		}
	}
	return
}

parse_unary :: proc(p: ^Parser) -> (result: Expression, err: Error) {
	unary := new_clone(Unary_Expression{op = token_to_operator(p.previous.kind)})
	unary.expr, err = parse_expr(p, parser_rules[p.previous.kind].prec)
	result = unary
	return
}

parse_binary :: proc(p: ^Parser, left: Expression) -> (result: Expression, err: Error) {
	binary := new_clone(Binary_Expression{left = left, op = token_to_operator(p.previous.kind)})
	binary.right, err = parse_expr(p, parser_rules[p.previous.kind].prec)
	result = binary
	return
}

parse_group :: proc(p: ^Parser) -> (result: Expression, err: Error) {
	result = parse_expr(p, .Lowest) or_return
	match_token_kind_next(p, .Close_Paren) or_return
	return
}

parse_index :: proc(p: ^Parser, left: Expression) -> (result: Expression, err: Error) {
	index_expr := new(Index_Expression)
	index_expr.left = left
	consume_token(p)
	index_expr.index = parse_expr(p, .Lowest) or_return
	match_token_kind(p, .Close_Bracket) or_return
	result = index_expr
	return
}

parse_call :: proc(p: ^Parser, left: Expression) -> (result: Expression, err: Error) {
	call := new(Call_Expression)
	call.func = left

	// FIXME: Account for parameterless functions
	args: for {
		call.args[call.arg_count] = parse_expr(p, .Lowest) or_return
		call.arg_count += 1
		consume_token(p)
		#partial switch p.previous.kind {
		case .Close_Paren:
			break args
		case .Comma:
			continue args
		case:
			err = Parsing_Error {
				kind    = .Invalid_Syntax,
				token   = p.current,
				details = fmt.tprintf(
					"Expected one of: %s, %s, got %s",
					Token_Kind.Comma,
					Token_Kind.Close_Paren,
					p.previous.kind,
				),
			}
			return
		}

	}

	result = call
	return
}
