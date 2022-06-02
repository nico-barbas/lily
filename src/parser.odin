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
	.Number =          {prec = .Lowest,  prefix_fn = parse_identifier, infix_fn = nil},
	.Boolean =         {prec = .Lowest,  prefix_fn = parse_identifier, infix_fn = nil},
	.String =          {prec = .Lowest,  prefix_fn = parse_identifier, infix_fn = nil},
	.Array =           {prec = .Lowest,  prefix_fn = parse_array_type, infix_fn = nil},
	.Number_Literal =  {prec = .Lowest,  prefix_fn = parse_number    , infix_fn = nil},
    .String_Literal =  {prec = .Lowest,  prefix_fn = parse_string    , infix_fn = nil},
	.True =            {prec = .Lowest,  prefix_fn = parse_boolean   , infix_fn = nil},
	.False =           {prec = .Lowest,  prefix_fn = parse_boolean   , infix_fn = nil},
	.Not = 	           {prec = .Unary  ,  prefix_fn = parse_unary    , infix_fn = nil},
	.Plus =            {prec = .Term  ,  prefix_fn = nil             , infix_fn = parse_binary},
	.Minus =           {prec = .Term  ,  prefix_fn = parse_unary     , infix_fn = parse_binary},
	.Star =            {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Slash =           {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Percent =         {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.And =             {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Or =              {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Greater =         {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Greater_Equal =   {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Lesser =          {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Lesser_Equal =    {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Open_Paren =      {prec = .Call, prefix_fn = parse_group     , infix_fn = parse_call},
	.Open_Bracket =    {prec = .Call, prefix_fn = nil             , infix_fn = parse_infix_open_bracket},
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
	Call,
	Highest,
}

Parsed_Module :: struct {
	source: string,
	nodes:  [dynamic]Node,
}

make_module :: proc() -> ^Parsed_Module {
	return new_clone(Parsed_Module{nodes = make([dynamic]Node)})
}

delete_module :: proc(p: ^Parsed_Module) {
	delete(p.source)
	// FIXME: Free the rest of the ast
	free(p)
}

parse_module :: proc(i: string, mod: ^Parsed_Module) -> (err: Error) {
	mod.source = strings.clone(i)
	parser := Parser {
		lexer = Lexer{},
	}
	set_lexer_input(&parser.lexer, mod.source)
	ast: for {
		node := parse_node(&parser) or_return
		if node != nil {
			append(&mod.nodes, node)
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
	case .EOF, .Newline, .End, .Else:
		result = nil
	case .Var:
		result, err = parse_var_decl(p)
	case .Fn:
		result, err = parse_fn_decl(p)
	case .Type:
		result, err = parse_type_decl(p)
	case .Identifier:
		next := peek_next_token(p)
		#partial switch next.kind {
		case .Assign, .Open_Bracket:
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
		result, err = parse_expression_stmt(p)
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
	result.token = p.current
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
	result.token = p.current
	name_token := consume_token(p)
	if name_token.kind == .Identifier {
		result.iterator_name = name_token
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

// FIXME: Allow for "var a, b := 10, false"
// FIXME: Allow for uninitialized variable declaration: "var a: number"
parse_var_decl :: proc(p: ^Parser) -> (result: ^Var_Declaration, err: Error) {
	result = new(Var_Declaration)
	result.token = p.current
	name_token := consume_token(p)
	if name_token.kind == .Identifier {
		result.identifier = name_token
		next := consume_token(p)
		#partial switch next.kind {
		case .Assign:
			consume_token(p)
			result.type_expr = &unresolved_identifier
			result.expr, err = parse_expr(p, .Lowest)
			result.initialized = true

		case .Colon:
			consume_token(p)
			result.type_expr = parse_expr(p, .Lowest) or_return
			#partial switch p.current.kind {
			case .Assign:
				consume_token(p)
				result.expr, err = parse_expr(p, .Lowest)
				result.initialized = true

			// Uninitialized variable declaration. We mark it as is and let
			// the checker and vm deal with it
			case .Newline:
				result.initialized = false

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
		result.identifier = name_token
		match_token_kind_next(p, .Open_Paren) or_return

		// We check if the function has parameters or not 
		#partial switch peek_next_token(p).kind {
		// If it has, we loop and gather all their relevant data (name and type expression) 
		case .Identifier:
			params: for {
				param: Typed_Identifier
				match_token_kind_next(p, .Identifier) or_return
				param.name = p.current
				match_token_kind_next(p, .Colon) or_return
				consume_token(p)
				param.type_expr = parse_expr(p, .Lowest) or_return
				append(&result.parameters, param)

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

		// Otherwise, we just move on
		case .Close_Paren:
			consume_token(p)

		// Any other token kind is an error
		case:
			err = Parsing_Error {
				kind    = .Invalid_Syntax,
				token   = p.current,
				details = fmt.tprintf(
					"Expected one of: %s, %s, got %s",
					Token_Kind.Identifier,
					Token_Kind.Close_Paren,
					p.current.kind,
				),
			}
		}

		// The after ':' after the parameters parenthesis
		match_token_kind_next(p, .Colon) or_return

		// We check if the function has a return value or if it is void
		// A newline is the delimiter for the function declaration signature 
		if consume_token(p).kind != .Newline {
			result.return_type_expr = parse_expr(p, .Lowest) or_return
			match_token_kind(p, .Newline)
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

// Disallow nested type declaration
parse_type_decl :: proc(p: ^Parser) -> (result: ^Type_Declaration, err: Error) {
	result = new_clone(Type_Declaration{token = p.current})
	name_token := consume_token(p)
	if name_token.kind == .Identifier {
		result.identifier = name_token
		match_token_kind_next(p, .Is) or_return
		result.is_token = p.current
		consume_token(p)
		result.type_expr = parse_expr(p, .Lowest) or_return
		#partial switch p.previous.kind {
		case .Class:
			result.type_kind = .Class
			fields: for {
				t := consume_token(p)
				#partial switch t.kind {
				case .Comment, .Newline:
					continue fields

				case .End:
					break fields

				case .Identifier:
					// Allow for "a, b: number"
					// expect ':' or ','
					// expect expression
					// expect newline?
					field := Typed_Identifier {
						name = t,
					}
					next := consume_token(p)
					#partial switch next.kind {
					case .Comma:
						assert(false, "Multiple field declaration not supported yet")
					case .Colon:
						consume_token(p)
						field.type_expr = parse_expr(p, .Lowest) or_return
						match_token_kind(p, .Newline)
						append(&result.fields, field)
					case:
						err = Parsing_Error {
							kind    = .Invalid_Syntax,
							token   = p.current,
							details = fmt.tprintf("Expected %s, got %s", Token_Kind.Colon, next.kind),
						}
					}


				case:
					err = Parsing_Error {
						kind    = .Invalid_Syntax,
						token   = p.current,
						details = fmt.tprintf("Expected %s, got %s", Token_Kind.Identifier, t.kind),
					}
				}
			}

		case:
			result.type_kind = .Alias
			if !is_type_token(p.previous.kind) {
				err = Parsing_Error {
					kind    = .Invalid_Syntax,
					token   = p.previous,
					details = fmt.tprintf("Expected type, got %s", p.previous.kind),
				}
			}
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
	result = new_clone(Identifier_Expression{name = p.previous})
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


parse_call :: proc(p: ^Parser, left: Expression) -> (result: Expression, err: Error) {
	call := new_clone(Call_Expression{func = left, args = make([dynamic]Expression)})

	// FIXME: Account for parameterless functions
	args: for {
		arg := parse_expr(p, .Lowest) or_return
		append(&call.args, arg)
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

parse_infix_open_bracket :: proc(p: ^Parser, left: Expression) -> (result: Expression, err: Error) {
	#partial switch l in left {
	case ^Array_Type_Expression:
		result = parse_array(p, left) or_return
	case ^Identifier_Expression:
		result = parse_index(p, left) or_return
	}
	return
}

parse_array :: proc(p: ^Parser, left: Expression) -> (result: Expression, err: Error) {
	array := new_clone(Array_Literal_Expression{type_expr = left, values = make([dynamic]Expression)})
	array_elements: for {
		element := parse_expr(p, .Lowest) or_return
		append(&array.values, element)
		consume_token(p)
		#partial switch p.previous.kind {
		case .Close_Bracket:
			break array_elements
		case .Comma:
			continue array_elements
		case:
			err = Parsing_Error {
				kind    = .Invalid_Syntax,
				token   = p.previous,
				details = fmt.tprintf(
					"Expected one of: %s, %s, got %s",
					Token_Kind.Comma,
					Token_Kind.Close_Bracket,
					p.previous.kind,
				),
			}
			return
		}
	}
	result = array
	return
}

parse_array_type :: proc(p: ^Parser) -> (result: Expression, err: Error) {
	array_type := new(Array_Type_Expression)
	array_type.token = p.previous
	match_token_kind(p, .Of) or_return
	array_type.of_token = p.current
	consume_token(p)
	array_type.elem_type = parse_expr(p, .Highest) or_return
	result = array_type
	return
}

parse_index :: proc(p: ^Parser, left: Expression) -> (result: Expression, err: Error) {
	index_expr := new(Index_Expression)
	index_expr.left = left
	// consume_token(p)
	index_expr.index = parse_expr(p, .Lowest) or_return
	match_token_kind(p, .Close_Bracket) or_return
	consume_token(p)
	result = index_expr
	return
}
