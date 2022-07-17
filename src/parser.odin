package lily

import "core:os"
import "core:strconv"
import "core:strings"
import "core:fmt"

//odinfmt: disable
parser_rules := map[Token_Kind]struct {
	prec:      Precedence,
	prefix_fn: proc(p: ^Parser) -> (Parsed_Expression, Error),
	infix_fn:  proc(p: ^Parser, left: Parsed_Expression) -> (Parsed_Expression, Error),
} {
	.Identifier =      {prec = .Lowest,  prefix_fn = parse_identifier, infix_fn = nil},
	.Self=             {prec = .Lowest,  prefix_fn = parse_identifier, infix_fn = nil},
	.Result =          {prec = .Lowest,  prefix_fn = parse_identifier, infix_fn = nil},
	.Any =             {prec = .Lowest,  prefix_fn = parse_identifier, infix_fn = nil},
	.Number =          {prec = .Lowest,  prefix_fn = parse_identifier, infix_fn = nil},
	.Boolean =         {prec = .Lowest,  prefix_fn = parse_identifier, infix_fn = nil},
	.String =          {prec = .Lowest,  prefix_fn = parse_identifier, infix_fn = nil},
	.Array =           {prec = .Lowest,  prefix_fn = parse_array_type, infix_fn = nil},
	.Map =             {prec = .Lowest,  prefix_fn = parse_map_type  , infix_fn = nil},
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
	.Equal =           {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Greater =         {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Greater_Equal =   {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Lesser =          {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Lesser_Equal =    {prec = .Factor,  prefix_fn = nil             , infix_fn = parse_binary},
	.Open_Paren =      {prec = .Call, prefix_fn = parse_group     , infix_fn = parse_call},
	.Open_Bracket =    {prec = .Call, prefix_fn = nil             , infix_fn = parse_infix_open_bracket},
	.Dot =             {prec = .Call, prefix_fn = nil             , infix_fn = parse_dot},
}
//odinfmt: enable

Parser :: struct {
	lexer:              Lexer,
	current:            Token,
	previous:           Token,
	expect_punctuation: bool,
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
	Select,
	Call,
	Highest,
}

Expr_Loop_State :: enum {
	Loop,
	Expect_Next,
	End,
}

parse_dependencies :: proc(
	buf: ^[dynamic]^Parsed_Module,
	lookup: ^map[string]int,
	entry_point: ^Parsed_Module,
) -> (
	err: Error,
) {
	if len(entry_point.import_nodes) == 0 {
		return
	}

	start := len(buf) - 1
	for import_node in entry_point.import_nodes {
		import_stmt := import_node.(^Parsed_Import_Statement)
		if _, exist := lookup[import_stmt.identifier.text]; exist {
			continue
		}
		if import_stmt.identifier.text == "std" {
			std_module := make_parsed_module("std")
			parse_module(std_source, std_module) or_return
			append(buf, std_module)
			lookup["std"] = len(buf) - 1
		} else {
			module_path := strings.concatenate(
				{import_stmt.identifier.text, ".lily"},
				context.temp_allocator,
			)
			imported_module := make_parsed_module(import_stmt.identifier.text)
			// FIXME: check for read errros
			imported_source, _ := os.read_entire_file(module_path)
			defer delete(imported_source)
			parse_module(string(imported_source), imported_module) or_return
			append(buf, imported_module)
			lookup[imported_module.name] = len(buf) - 1
		}
	}
	imported_modules := buf[start:len(buf)]
	for module in imported_modules {
		parse_dependencies(buf, lookup, module) or_return
	}
	return
}

parse_module :: proc(input: string, mod: ^Parsed_Module) -> (err: Error) {
	parser := Parser {
		lexer = Lexer{},
	}
	set_lexer_input(&parser.lexer, input)
	ast: for {
		node: Parsed_Node
		node, err = parse_node(&parser)
		if err != nil {
			if node != nil do free_parsed_node(node)
			return
		}
		if node != nil {
			#partial switch n in node {
			case ^Parsed_Import_Statement:
				append(&mod.import_nodes, node)
			case ^Parsed_Var_Declaration:
				append(&mod.variables, node)
			case ^Parsed_Type_Declaration:
				append(&mod.types, node)
			case ^Parsed_Fn_Declaration:
				append(&mod.functions, node)
			case:
				append(&mod.nodes, node)
			}
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

match_token_kind :: proc(p: ^Parser, kind: Token_Kind, loc := #caller_location) -> (err: Error) {
	if p.current.kind != kind {
		err = format_error(
			Parsing_Error{
				kind = .Invalid_Syntax,
				token = p.current,
				details = fmt.tprintf("Expected %s, got %s", kind, p.current.kind),
			},
			loc,
		)
	}
	return
}

match_token_kind_next :: proc(p: ^Parser, kind: Token_Kind, loc := #caller_location) -> (err: Error) {
	if consume_token(p).kind != kind {
		err = format_error(
			Parsing_Error{
				kind = .Invalid_Syntax,
				token = p.current,
				details = fmt.tprintf("Expected %s, got %s", kind, p.current.kind),
			},
			loc,
		)
	}
	return
}

advance_expr_loop :: proc(p: ^Parser, end_token: Token_Kind) -> (s: Expr_Loop_State, err: Error) {
	#partial switch p.current.kind {
	case .EOF:
		err = format_error(
		Parsing_Error{
			kind = .Invalid_Syntax,
			token = p.previous,
			details = fmt.tprintf("Expected %s, got %s", end_token, p.current.kind),
		},
		)
		return
	case .Newline:
		if p.expect_punctuation {
			err = format_error(
			Parsing_Error{
				kind = .Invalid_Syntax,
				token = p.previous,
				details = fmt.tprintf(
					"Expected one of: %s, %s, got %s",
					Token_Kind.Comma,
					end_token,
					p.current.kind,
				),
			},
			)
			return
		} else {
			consume_token(p)
			s = .Loop
		}
	case end_token:
		s = .End
		consume_token(p)
	case .Comma:
		if !p.expect_punctuation {
			err = format_error(
			Parsing_Error{
				kind = .Invalid_Syntax,
				token = p.previous,
				details = fmt.tprintf("Expected expression, got %s", p.current.kind),
			},
			)
			return
		} else {
			s = .Loop
			p.expect_punctuation = false
			consume_token(p)
		}
	case:
		if p.expect_punctuation {
			err = format_error(
			Parsing_Error{
				kind = .Invalid_Syntax,
				token = p.previous,
				details = fmt.tprintf(
					"Expected one of: %s, %s, got %s",
					Token_Kind.Comma,
					end_token,
					p.current.kind,
				),
			},
			)
			return
		} else {
			s = .Expect_Next
		}
	}
	return
}

parse_node :: proc(p: ^Parser) -> (result: Parsed_Node, err: Error) {
	token := consume_token(p)
	#partial switch token.kind {
	case .EOF, .Newline, .End, .Else:
		result = nil
	case .Import:
		result, err = parse_import_stmt(p)
	case .Var:
		result, err = parse_var_decl(p)
	case .Fn, .Foreign:
		result, err = parse_fn_decl(p)
	case .Type:
		result, err = parse_type_decl(p)
	case .Identifier, .Self, .Result:
		lhs := parse_expr(p, .Lowest) or_return
		#partial switch p.current.kind {
		case .Assign:
			result, err = parse_assign_stmt(p, lhs)
		case:
			result = new_clone(Parsed_Expression_Statement{token = token, expr = lhs})
		}
	case .If:
		result, err = parse_if_stmt(p)
	case .For:
		result, err = parse_range_stmt(p)
	case .Match:
		result, err = parse_match_stmt(p)
	case .Break, .Continue:
		result, err = parse_flow_stmt(p)
	case:
		// Parsed_Expression statement most likely
		result, err = parse_expression_stmt(p)
	}
	return
}

parse_expression_stmt :: proc(p: ^Parser) -> (result: ^Parsed_Expression_Statement, err: Error) {
	result = new(Parsed_Expression_Statement)
	result.token = p.current
	result.expr, err = parse_expr(p, .Lowest)
	return
}

parse_assign_stmt :: proc(p: ^Parser, lhs: Parsed_Expression) -> (
	result: ^Parsed_Assignment_Statement,
	err: Error,
) {
	result = new(Parsed_Assignment_Statement)
	result.token = p.current
	result.left = lhs
	consume_token(p)
	result.right = parse_expr(p, .Lowest) or_return
	return
}

parse_if_stmt :: proc(p: ^Parser) -> (result: ^Parsed_If_Statement, err: Error) {
	parse_branch :: proc(p: ^Parser, is_end_branch: bool, loc := #caller_location) -> (
		result: ^Parsed_If_Statement,
		err: Error,
	) {
		result = new(Parsed_If_Statement)
		switch is_end_branch {
		case true:
			result.condition = new_clone(
			Parsed_Literal_Expression{value = Value{kind = .Boolean, data = true}},
			)
			result.body = new_clone(Parsed_Block_Statement{nodes = make([dynamic]Parsed_Node)})
			else_body: for {
				body_node := parse_node(p) or_return
				if body_node != nil {
					append(&result.body.nodes, body_node)
				}
				if p.current.kind == .End {
					consume_token(p)
					break else_body
				}
			}
		case false:
			consume_token(p)
			result.condition = parse_expr(p, .Lowest) or_return
			match_token_kind(p, .Colon) or_return
			consume_token(p)
			result.body = new_clone(Parsed_Block_Statement{nodes = make([dynamic]Parsed_Node)})
			else_if_body: for {
				body_node := parse_node(p) or_return
				if body_node != nil {
					append(&result.body.nodes, body_node)
				}
				#partial switch p.current.kind {
				case .End:
					consume_token(p)
					break else_if_body
				case .Else:
					#partial switch consume_token(p).kind {
					case .If:
						result.next_branch = parse_branch(p, false) or_return
					case .Colon:
						result.next_branch = parse_branch(p, true) or_return
						break else_if_body
					case:
						err = format_error(
							Parsing_Error{
								kind = .Invalid_Syntax,
								token = p.current,
								details = fmt.tprintf(
									"Expected one of: %s, %s, got %s",
									Token_Kind.If,
									Token_Kind.Colon,
									p.current.kind,
								),
							},
							loc,
						)
					}
				}
			}
		}
		return
	}

	result = new(Parsed_If_Statement)
	result.token = p.current
	consume_token(p)
	result.condition = parse_expr(p, .Lowest) or_return
	match_token_kind(p, .Colon) or_return

	result.body = new_clone(Parsed_Block_Statement{nodes = make([dynamic]Parsed_Node)})
	body: for {
		body_node := parse_node(p) or_return
		if body_node != nil {
			append(&result.body.nodes, body_node)
		}
		#partial switch p.current.kind {
		case .End:
			consume_token(p)
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

parse_range_stmt :: proc(p: ^Parser) -> (result: ^Parsed_Range_Statement, err: Error) {
	result = new(Parsed_Range_Statement)
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

		result.body = new_clone(Parsed_Block_Statement{nodes = make([dynamic]Parsed_Node)})
		body: for {
			body_node := parse_node(p) or_return
			if body_node != nil {
				append(&result.body.nodes, body_node)
			}
			if p.current.kind == .End {
				consume_token(p)
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

parse_match_stmt :: proc(p: ^Parser) -> (result: ^Parsed_Match_Statement, err: Error) {
	result = new_clone(Parsed_Match_Statement{token = p.current})
	consume_token(p)
	result.evaluation = parse_expr(p, .Lowest) or_return
	match_token_kind(p, .Colon) or_return
	cases: for {
		#partial switch consume_token(p).kind {
		case .Newline:
			continue
		case .When:
			current := struct {
				token:     Token,
				condition: Parsed_Expression,
				body:      ^Parsed_Block_Statement,
			}{}
			current.token = p.current
			consume_token(p)
			current.condition = parse_expr(p, .Lowest) or_return
			match_token_kind(p, .Colon) or_return
			current.body = new_clone(
			Parsed_Block_Statement{token = p.current, nodes = make([dynamic]Parsed_Node)},
			)
			body: for {
				body_node := parse_node(p) or_return
				if body_node != nil {
					append(&current.body.nodes, body_node)
				}
				if p.current.kind == .End {
					consume_token(p)
					break body
				}
			}
			append(&result.cases, current)

		case .End:
			break cases
		case:
			err = Parsing_Error {
				kind    = .Invalid_Syntax,
				token   = p.current,
				details = fmt.tprintf(
					"Expected either %s or %s, got %s",
					Token_Kind.When,
					Token_Kind.End,
					p.current.kind,
				),
			}
		}
	}

	return
}

parse_flow_stmt :: proc(p: ^Parser) -> (result: ^Parsed_Flow_Statement, err: Error) {
	result = new_clone(
	Parsed_Flow_Statement{token = p.current, kind = .Break if p.current.kind == .Break else .Continue},
	)
	err = match_token_kind_next(p, .Newline)
	return
}

// FIXME: Allow for multiple module name in one Import statement
parse_import_stmt :: proc(p: ^Parser) -> (result: ^Parsed_Import_Statement, err: Error) {
	result = new_clone(Parsed_Import_Statement{token = p.current})
	match_token_kind_next(p, .Identifier) or_return
	result.identifier = p.current
	match_token_kind_next(p, .Newline) or_return
	return
}

// FIXME: Allow for "var a, b := 10, false"
// FIXME: Allow for uninitialized variable declaration: "var a: number"
parse_var_decl :: proc(p: ^Parser) -> (result: ^Parsed_Var_Declaration, err: Error) {
	result = new(Parsed_Var_Declaration)
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

		case .Colon:
			consume_token(p)
			result.type_expr = parse_expr(p, .Lowest) or_return
			#partial switch p.current.kind {
			case .Assign:
				consume_token(p)
				result.expr, err = parse_expr(p, .Lowest)

			// Uninitialized variable declaration. We mark it as is and let
			// the checker and vm deal with it
			case .Newline:

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

parse_fn_decl :: proc(p: ^Parser) -> (result: ^Parsed_Fn_Declaration, err: Error) {
	result = new(Parsed_Fn_Declaration)
	result.token = p.current
	#partial switch p.current.kind {
	case .Fn, .Constructor:
		match_token_kind_next(p, .Identifier) or_return
		result.identifier = p.current
		result.kind = .Function
	case .Foreign:
		match_token_kind_next(p, .Fn) or_return
		match_token_kind_next(p, .Identifier) or_return
		result.identifier = p.current
		result.kind = .Foreign
	case:
		err = Parsing_Error {
			kind    = .Invalid_Syntax,
			token   = p.current,
			details = fmt.tprintf(
				"Expected one of : [%s, %s, %s], got %s",
				Token_Kind.Fn,
				Token_Kind.Constructor,
				Token_Kind.Foreign,
				p.current.kind,
			),
		}
	}
	match_token_kind_next(p, .Open_Paren) or_return
	consume_token(p)

	p.expect_punctuation = false
	params: for {
		state := advance_expr_loop(p, .Close_Paren) or_return
		switch state {
		case .Loop:
			continue params
		case .Expect_Next:
			param: Typed_Identifier
			match_token_kind_next(p, .Identifier) or_return
			param.name = p.current
			match_token_kind_next(p, .Colon) or_return
			consume_token(p)
			param.type_expr = parse_expr(p, .Lowest) or_return
			append(&result.parameters, param)
			p.expect_punctuation = true
		case .End:
			break params
		}
	}

	// The after ':' after the parameters parenthesis
	match_token_kind(p, .Colon) or_return

	// We check if the function has a return value or if it is void
	// A newline is the delimiter for the function declaration signature 
	if consume_token(p).kind != .Newline {
		result.return_type_expr = parse_expr(p, .Lowest) or_return
		match_token_kind(p, .Newline)
	}

	if result.kind == .Function {
		result.body = new_clone(Parsed_Block_Statement{nodes = make([dynamic]Parsed_Node)})
		body: for {
			body_node := parse_node(p) or_return
			if body_node != nil {
				append(&result.body.nodes, body_node)
			}
			if p.current.kind == .End {
				break body
			}
		}
	}
	return
}

// FIXME: Disallow nested type declaration
parse_type_decl :: proc(p: ^Parser) -> (result: ^Parsed_Type_Declaration, err: Error) {
	result = new_clone(Parsed_Type_Declaration{token = p.current})
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

				case .Fn:
					method := parse_fn_decl(p) or_return
					append(&result.methods, method)

				case .Constructor:
					constructor := parse_fn_decl(p) or_return
					constructor.return_type_expr = new_clone(
					Parsed_Identifier_Expression{name = name_token},
					)
					append(&result.constructors, constructor)


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

parse_expr :: proc(p: ^Parser, prec: Precedence) -> (result: Parsed_Expression, err: Error) {
	consume_token(p)
	if rule, exist := parser_rules[p.previous.kind]; exist {
		if rule.prefix_fn == nil {
			err = Parsing_Error {
				kind    = .Invalid_Syntax,
				token   = p.previous,
				details = fmt.tprintf("No expression starts with prefix operator %s", p.previous.text),
			}
			return
		}
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

parse_identifier :: proc(p: ^Parser) -> (result: Parsed_Expression, err: Error) {
	err = nil
	result = new_clone(Parsed_Identifier_Expression{name = p.previous})
	return
}

parse_number :: proc(p: ^Parser) -> (result: Parsed_Expression, err: Error) {
	num, ok := strconv.parse_f64(p.previous.text)
	if ok {
		result = new_clone(
		Parsed_Literal_Expression{token = p.previous, value = Value{kind = .Number, data = num}},
		)
	} else {
		err = Parsing_Error {
			kind  = .Malformed_Number,
			token = p.previous,
		}
	}
	return
}

parse_boolean :: proc(p: ^Parser) -> (result: Parsed_Expression, err: Error) {
	b := false if p.previous.kind == .False else true
	result = new_clone(Parsed_Literal_Expression{value = Value{kind = .Boolean, data = b}})
	return
}

parse_string :: proc(p: ^Parser) -> (result: Parsed_Expression, err: Error) {
	result = new_clone(
	Parsed_String_Literal_Expression{
		token = p.previous,
		value = p.previous.text[1:len(p.previous.text) - 1],
	},
	)
	return
}

parse_unary :: proc(p: ^Parser) -> (result: Parsed_Expression, err: Error) {
	unary := new_clone(Parsed_Unary_Expression{op = token_to_operator(p.previous.kind)})
	unary.expr, err = parse_expr(p, parser_rules[p.previous.kind].prec)
	result = unary
	return
}

parse_binary :: proc(p: ^Parser, left: Parsed_Expression) -> (result: Parsed_Expression, err: Error) {
	binary := new_clone(Parsed_Binary_Expression{left = left, op = token_to_operator(p.previous.kind)})
	binary.right, err = parse_expr(p, parser_rules[p.previous.kind].prec)
	result = binary
	return
}

parse_group :: proc(p: ^Parser) -> (result: Parsed_Expression, err: Error) {
	result = parse_expr(p, .Lowest) or_return
	match_token_kind(p, .Close_Paren) or_return
	consume_token(p)
	return
}


parse_call :: proc(p: ^Parser, left: Parsed_Expression) -> (result: Parsed_Expression, err: Error) {
	call := new_clone(Parsed_Call_Expression{func = left, args = make([dynamic]Parsed_Expression)})

	p.expect_punctuation = false
	args: for {
		state := advance_expr_loop(p, .Close_Paren) or_return
		switch state {
		case .Loop:
			continue args
		case .Expect_Next:
			arg := parse_expr(p, .Lowest) or_return
			append(&call.args, arg)
			p.expect_punctuation = true
		case .End:
			break args
		}
	}
	result = call
	return
}

parse_infix_open_bracket :: proc(p: ^Parser, left: Parsed_Expression) -> (
	result: Parsed_Expression,
	err: Error,
) {
	#partial switch l in left {
	case ^Parsed_Array_Type_Expression:
		result = parse_array(p, left) or_return
	case ^Parsed_Map_Type_Expression:
		result = parse_map(p, left) or_return
	case ^Parsed_Identifier_Expression:
		result = parse_index(p, left) or_return
	}
	return
}

parse_array :: proc(p: ^Parser, left: Parsed_Expression) -> (result: Parsed_Expression, err: Error) {
	array := new_clone(Parsed_Array_Literal_Expression{token = p.previous, type_expr = left})

	p.expect_punctuation = false
	array.values = make([dynamic]Parsed_Expression)
	array_elements: for {
		state := advance_expr_loop(p, .Close_Bracket) or_return
		switch state {
		case .Loop:
			continue array_elements
		case .Expect_Next:
			element := parse_expr(p, .Lowest) or_return
			append(&array.values, element)
			p.expect_punctuation = true
		case .End:
			break array_elements
		}
	}
	result = array
	return
}

parse_map :: proc(p: ^Parser, left: Parsed_Expression) -> (result: Parsed_Expression, err: Error) {
	m := new_clone(
	Parsed_Map_Literal_Expression{
		token = p.previous,
		type_expr = left,
		elements = make([dynamic]Parsed_Map_Element),
	},
	)

	p.expect_punctuation = false
	map_elements: for {
		state := advance_expr_loop(p, .Close_Bracket) or_return
		switch state {
		case .Loop:
			continue map_elements
		case .Expect_Next:
			element := Parsed_Map_Element{}
			element.key = parse_expr(p, .Lowest) or_return
			match_token_kind(p, .Assign) or_return
			consume_token(p)
			element.value = parse_expr(p, .Lowest) or_return
			append(&m.elements, element)
			p.expect_punctuation = true
		case .End:
			break map_elements
		}
	}
	result = m
	return
}

parse_array_type :: proc(p: ^Parser) -> (result: Parsed_Expression, err: Error) {
	array_type := new(Parsed_Array_Type_Expression)
	array_type.token = p.previous
	match_token_kind(p, .Of) or_return
	array_type.of_token = p.current
	consume_token(p)
	array_type.elem_type = parse_expr(p, .Highest) or_return
	result = array_type
	return
}

parse_map_type :: proc(p: ^Parser) -> (result: Parsed_Expression, err: Error) {
	map_type := new_clone(Parsed_Map_Type_Expression{token = p.previous})
	match_token_kind(p, .Of) or_return
	map_type.of_token = p.current
	match_token_kind_next(p, .Open_Paren) or_return
	consume_token(p)
	map_type.key_type = parse_expr(p, .Lowest) or_return
	match_token_kind(p, .Comma) or_return
	consume_token(p)
	map_type.value_type = parse_expr(p, .Lowest) or_return
	match_token_kind(p, .Close_Paren) or_return
	consume_token(p)
	result = map_type
	return
}

parse_index :: proc(p: ^Parser, left: Parsed_Expression) -> (result: Parsed_Expression, err: Error) {
	index_expr := new_clone(Parsed_Index_Expression{token = p.previous, left = left})
	index_expr.index = parse_expr(p, .Lowest) or_return
	match_token_kind(p, .Close_Bracket) or_return
	consume_token(p)
	result = index_expr
	return
}

parse_dot :: proc(p: ^Parser, left: Parsed_Expression) -> (result: Parsed_Expression, err: Error) {
	dot_expr := new_clone(Parsed_Dot_Expression{token = p.previous, left = left})
	dot_expr.selector = parse_expr(p, .Select) or_return
	result = dot_expr
	return
}
