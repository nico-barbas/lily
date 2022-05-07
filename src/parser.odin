package lily

import "core:strconv"
import "core:strings"

//odinfmt: disable
parser_rules := map[Token_Kind]struct {
	prec:      Precedence,
	prefix_fn: proc(p: ^Parser) -> (Expression, Error),
	infix_fn:  proc(p: ^Parser, left: Expression) -> (Expression, Error),
} {
	.Identifier =      {prec = .Lowest,  prefix_fn = parse_identifier, infix_fn = nil},
	.Number_Literal =  {prec = .Lowest,  prefix_fn = parse_number    , infix_fn = nil},
    .String_Literal =  {prec = .Lowest,  prefix_fn = parse_string    , infix_fn = nil},
	.True =            {prec = .Lowest,  prefix_fn = parse_boolean   , infix_fn = nil},
	.False =           {prec = .Lowest,  prefix_fn = parse_boolean   , infix_fn = nil},
	.Not = 	           {prec = .Term  ,  prefix_fn = parse_unary     , infix_fn = nil},
	.Plus =            {prec = .Term  ,  prefix_fn = nil             , infix_fn = parse_binary},
	.Minus =           {prec = .Term  ,  prefix_fn = parse_unary     , infix_fn = parse_binary},
	.Star =            {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Slash =           {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Percent =         {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.And =             {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Or =              {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Paren_Open =      {prec = .Highest, prefix_fn = parse_group     , infix_fn = parse_call},
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

consume :: proc(p: ^Parser) -> Token {
	p.previous = p.current
	p.current = scan_token(&p.lexer)
	return p.current
}

match :: proc(p: ^Parser, kind: Token_Kind) -> (err: Error) {
	if p.current.kind != kind {
		err = Parsing_Error.Invalid_Syntax
	}
	return
}

match_next :: proc(p: ^Parser, kind: Token_Kind) -> (err: Error) {
	if consume(p).kind != kind {
		err = Parsing_Error.Invalid_Syntax
	}
	return
}

parse_node :: proc(p: ^Parser) -> (result: Node, err: Error) {
	token := consume(p)
	#partial switch token.kind {
	case .EOF:
		result = nil
	case .Var:
		result, err = parse_var_decl(p)
	case .Fn:
		result, err = parse_fn_decl(p)
	case .Identifier:
		next := consume(p)
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
	result.identifier = p.previous.text
	consume(p)
	result.expr = parse_expr(p, .Lowest) or_return
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
			consume(p)
			result.condition = parse_expr(p, .Lowest) or_return
			match_next(p, .Colon) or_return
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
					#partial switch consume(p).kind {
					case .If:
						result.next_branch = parse_branch(p, false) or_return
					case .Colon:
						result.next_branch = parse_branch(p, true) or_return
					case:
						err = Parsing_Error.Invalid_Syntax
					}
				}
			}
		}
		return
	}

	result = new(If_Statement)
	consume(p)
	result.condition = parse_expr(p, .Lowest) or_return
	match(p, .Colon) or_return

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
			#partial switch consume(p).kind {
			case .If:
				result.next_branch = parse_branch(p, false) or_return
				break body
			case .Colon:
				result.next_branch = parse_branch(p, true) or_return
				break body
			case:
				err = Parsing_Error.Invalid_Syntax
			}
		}
	}
	return
}

parse_range_stmt :: proc(p: ^Parser) -> (result: ^Range_Statement, err: Error) {
	result = new(Range_Statement)
	name_token := consume(p)
	if name_token.kind == .Identifier {
		result.iterator_name = name_token.text
		match_next(p, .In) or_return
		consume(p)
		result.low = parse_expr(p, .Lowest) or_return
		#partial switch p.current.kind {
		case .Double_Dot:
			result.op = .Exclusive
		case .Triple_Dot:
			result.op = .Inclusive
		case:
			err = Parsing_Error.Invalid_Syntax
			return
		}
		consume(p)
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
		err = Parsing_Error.Invalid_Syntax
	}
	return
}

parse_var_decl :: proc(p: ^Parser) -> (result: ^Var_Declaration, err: Error) {
	result = new(Var_Declaration)

	name_token := consume(p)
	if name_token.kind == .Identifier {
		result.identifier = name_token.text
		next := consume(p)
		#partial switch next.kind {
		case .Assign:
			consume(p)
			result.type_name = "unresolved"
			result.expr, err = parse_expr(p, .Lowest)

		case .Colon:
			result.type_name = consume(p).text
			match_next(p, .Assign) or_return
			consume(p)
			result.expr, err = parse_expr(p, .Lowest)

		case:
			err = Parsing_Error.Invalid_Syntax
		}
	} else {
		err = Parsing_Error.Invalid_Syntax
	}

	return
}

parse_fn_decl :: proc(p: ^Parser) -> (result: ^Fn_Declaration, err: Error) {
	result = new(Fn_Declaration)
	name_token := consume(p)
	if name_token.kind == .Identifier {
		result.identifier = name_token.text
		match_next(p, .Paren_Open) or_return

		// FIXME: Account for parameterless functions
		params: for {
			match_next(p, .Identifier) or_return
			result.parameters[result.param_count].name = p.current.text

			match_next(p, .Colon) or_return
			if !is_type_token(consume(p).kind) {
				err = Parsing_Error.Invalid_Syntax
				return
			}
			result.parameters[result.param_count].type_name = p.current.text
			result.param_count += 1

			consume(p)
			#partial switch p.current.kind {
			case .Comma:
				continue params
			case .Paren_Close:
				break params
			case:
				err = Parsing_Error.Invalid_Syntax
				return
			}
		}

		match_next(p, .Colon) or_return

		if is_type_token(consume(p).kind) {
			result.return_type_name = p.current.text
			consume(p)
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
		err = Parsing_Error.Invalid_Syntax
	}
	return
}

parse_expr :: proc(p: ^Parser, prec: Precedence) -> (result: Expression, err: Error) {
	consume(p)
	if rule, exist := parser_rules[p.previous.kind]; exist {
		result = rule.prefix_fn(p) or_return
	}
	for p.current.kind != .EOF && prec < parser_rules[p.current.kind].prec {
		consume(p)
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
		err = .Malformed_Number
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
	if consume(p).kind != .Paren_Close {
		err = Parsing_Error.Invalid_Syntax
	}
	return
}

parse_call :: proc(p: ^Parser, left: Expression) -> (result: Expression, err: Error) {
	call := new(Call_Expression)
	call.name = left.(^Identifier_Expression).name
	free(left.(^Identifier_Expression))

	// FIXME: Account for parameterless functions
	args: for {
		call.args[call.arg_count] = parse_expr(p, .Lowest) or_return
		call.arg_count += 1
		consume(p)
		#partial switch p.previous.kind {
		case .Paren_Close:
			break args
		case .Comma:
			continue args
		case:
			err = Parsing_Error.Invalid_Syntax
			return
		}

	}

	result = call
	return
}
