package lily

import "core:strconv"
import "core:fmt"

//odinfmt: disable
parser_rules := map[Token_Kind]struct {
	prec:      Precedence,
	prefix_fn: proc(p: ^Parser) -> (Parsed_Expression, Error),
	infix_fn:  proc(p: ^Parser, left: Parsed_Expression) -> (Parsed_Expression, Error),
} {
	.Identifier =      {prec = .Lowest,     prefix_fn = parse_identifier, infix_fn = nil},
	.Self=             {prec = .Lowest,     prefix_fn = parse_identifier, infix_fn = nil},
	.Result =          {prec = .Lowest,     prefix_fn = parse_identifier, infix_fn = nil},
	.Any =             {prec = .Lowest,     prefix_fn = parse_identifier, infix_fn = nil},
	.Number =          {prec = .Lowest,     prefix_fn = parse_identifier, infix_fn = nil},
	.Boolean =         {prec = .Lowest,     prefix_fn = parse_identifier, infix_fn = nil},
	.String =          {prec = .Lowest,     prefix_fn = parse_identifier, infix_fn = nil},
	.Array =           {prec = .Lowest,     prefix_fn = parse_array_type, infix_fn = nil},
	.Map =             {prec = .Lowest,     prefix_fn = parse_map_type,   infix_fn = nil},
	.Number_Literal =  {prec = .Lowest,     prefix_fn = parse_number,     infix_fn = nil},
    .String_Literal =  {prec = .Lowest,     prefix_fn = parse_string,     infix_fn = nil},
	.True =            {prec = .Lowest,     prefix_fn = parse_boolean,    infix_fn = nil},
	.False =           {prec = .Lowest,     prefix_fn = parse_boolean,    infix_fn = nil},
	.Nil =             {prec = .Lowest,     prefix_fn = parse_nil,        infix_fn = nil},
	.Not = 	           {prec = .Unary  ,    prefix_fn = parse_unary,      infix_fn = nil},
	.Plus =            {prec = .Term  ,     prefix_fn = nil,              infix_fn = parse_binary},
	.Minus =           {prec = .Term  ,     prefix_fn = parse_unary,      infix_fn = parse_binary},
	.Star =            {prec = .Factor,     prefix_fn = nil,              infix_fn = parse_binary},
	.Slash =           {prec = .Factor,     prefix_fn = nil,              infix_fn = parse_binary},
	.Percent =         {prec = .Factor,     prefix_fn = nil,              infix_fn = parse_binary},
	.And =             {prec = .Comparison, prefix_fn = nil,              infix_fn = parse_binary},
	.Or =              {prec = .Comparison, prefix_fn = nil,              infix_fn = parse_binary},
	.Equal =           {prec = .Equality,   prefix_fn = nil,              infix_fn = parse_binary},
	.Greater =         {prec = .Equality,   prefix_fn = nil,              infix_fn = parse_binary},
	.Greater_Equal =   {prec = .Equality,   prefix_fn = nil,              infix_fn = parse_binary},
	.Lesser =          {prec = .Equality,   prefix_fn = nil,              infix_fn = parse_binary},
	.Lesser_Equal =    {prec = .Equality,   prefix_fn = nil,              infix_fn = parse_binary},
	.Open_Paren =      {prec = .Call,       prefix_fn = parse_group,      infix_fn = parse_call},
	.Open_Bracket =    {prec = .Call,       prefix_fn = nil,              infix_fn = parse_infix_open_bracket},
	.Dot =             {prec = .Call,       prefix_fn = nil,              infix_fn = parse_dot},
}
//odinfmt: enable

Parse_Node_Command :: enum {
	Exit,
	Skip,
	Parse_Node,
	Parse_Comment,
}

//odinfmt: disable
node_parsing_rules := map[Token_Kind]struct {
	command: Parse_Node_Command,
	end:     Token_Kind,
} {
	.EOF            = {.Exit, .Newline},
	.Newline        = {.Skip, .Newline},
	.Comment        = {.Parse_Comment, .Newline},
	.Import         = {.Parse_Node, .Newline},
	.Var            = {.Parse_Node, .Newline},
	.Fn             = {.Parse_Node, .End},
	.Foreign        = {.Parse_Node, .End},
	.Type           = {.Parse_Node, .End},
	.Identifier     = {.Parse_Node, .Newline},
	.Self           = {.Parse_Node, .Newline},
	.Result         = {.Parse_Node, .Newline},
	.Number_Literal = {.Parse_Node, .Newline},
	.True           = {.Parse_Node, .Newline},
	.False          = {.Parse_Node, .Newline},
	.String_Literal = {.Parse_Node, .Newline},
	.Map            = {.Parse_Node, .Newline},
	.Array          = {.Parse_Node, .Newline},
	.If             = {.Parse_Node, .End},
	.For            = {.Parse_Node, .End},
	.Match          = {.Parse_Node, .End},
	.Break          = {.Parse_Node, .Newline},
	.Continue       = {.Parse_Node, .Newline},
	.Return         = {.Parse_Node, .Newline},
}
//odinfmt: enable

consume_token :: proc(p: ^Parser) -> Token {
	p.previous = p.current
	p.current = scan_token(&p.lexer)
	return p.current
}

consume_token_until :: proc(p: ^Parser, end: Token_Kind) {
	loop: for {
		if p.current.kind == .EOF || p.current.kind == end {
			break loop
		} else {
			consume_token(p)
		}
	}
}

peek_next_token :: proc(p: ^Parser) -> (result: Token) {
	start := p.lexer.current
	result = scan_token(&p.lexer)
	p.lexer.current = start
	return
}

match_token_kind_previous :: proc(p: ^Parser, kind: Token_Kind, loc := #caller_location) -> (err: Error) {
	if p.previous.kind != kind {
		err = format_error(
			Parsing_Error{
				kind = .Invalid_Syntax,
				token = p.current,
				details = fmt.tprintf("Expected %s, got %s", kind, p.previous.kind),
			},
			loc,
		)
	}
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

Parser :: struct {
	lexer:              Lexer,
	module:             ^Parsed_Module,
	current:            Token,
	previous:           Token,
	expect_punctuation: bool,
	end_token:          Token_Kind,
}

Precedence :: enum {
	Lowest,
	Asssignment,
	Comparison,
	Equality,
	Term,
	Factor,
	Unary,
	Select,
	Call,
	Highest,
}

Expr_List_Rule :: struct {
	ignored:     Token_Kind_Group,
	punctuation: Token_Kind,
	end:         Token_Kind,
}

Expr_List_State :: enum {
	Loop,
	Expect_Next,
	End,
}

FN_PARAMS_LIST_RULE :: Expr_List_Rule {
	ignored = {.Newline},
	punctuation = .Comma,
	end = .Close_Paren,
}

CONTAINER_ELEM_LIST_RULE :: Expr_List_Rule {
	ignored = {.Newline},
	punctuation = .Comma,
	end = .Close_Bracket,
}

parse_dependencies :: proc(
	s: ^State,
	buf: ^[dynamic]^Parsed_Module,
	lookup: ^map[string]int,
	entry_point: ^Parsed_Module,
	allocator := context.allocator,
) -> (
	ok: bool,
) {
	context.allocator = allocator
	if len(entry_point.import_nodes) == 0 {
		ok = true
		return
	}


	start := len(buf) - 1
	for import_node in entry_point.import_nodes {
		import_stmt := import_node.(^Parsed_Import_Statement)
		if _, exist := lookup[import_stmt.identifier.text]; exist {
			continue
		}
		import_ok: bool
		if import_stmt.identifier.text == "std" {
			std_module := make_parsed_module("std")
			import_ok = parse_module(std_source, std_module)
			append(buf, std_module)
			lookup["std"] = len(buf) - 1
		} else {
			imported_module := make_parsed_module(import_stmt.identifier.text)
			imported_source, err := s->internal_load_module_source(imported_module.name)
			if err != nil {
				import_ok = false
				append(&imported_module.errors, err)
			} else {
				import_ok = parse_module(imported_source, imported_module)
				append(buf, imported_module)
				lookup[imported_module.name] = len(buf) - 1
			}
		}
		ok |= import_ok
	}

	if start == len(buf) - 1 {
		return
	}
	imported_modules := buf[start:len(buf)]
	for module in imported_modules {
		ok |= parse_dependencies(s, buf, lookup, module)
	}
	return
}

parse_module :: proc(input: string, mod: ^Parsed_Module, allocator := context.allocator) -> (ok: bool) {
	context.allocator = allocator
	err_count := len(mod.errors)
	parser := Parser {
		lexer = Lexer{},
		module = mod,
	}
	set_lexer_input(&parser.lexer, input)
	ast: for {
		t := consume_token(&parser)
		if rule, exist := node_parsing_rules[t.kind]; exist {
			parser.end_token = rule.end
			switch rule.command {
			case .Parse_Node:
				node, node_err := parse_node(&parser)
				if node_err != nil {
					consume_token_until(&parser, parser.end_token)
					append(&mod.errors, node_err)
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
				}
			case .Parse_Comment:
				append(&mod.comments, t)
			case .Skip:
				continue ast
			case .Exit:
				break ast
			}
		} else {
			err := format_error(
				Parsing_Error{kind = .Invalid_Syntax, token = t, details = fmt.tprintf("Invalid node")},
			)
			consume_token_until(&parser, .Newline)
			append(&mod.errors, err)
		}
	}
	ok = len(mod.errors) == err_count
	return
}

parse_node :: proc(p: ^Parser) -> (result: Parsed_Node, err: Error) {
	#partial switch p.current.kind {
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
		if is_assign_token(p.current.kind) {
			result, err = parse_assign_stmt(p, lhs)
		} else {
			result = new_clone(Parsed_Expression_Statement{token = p.current, expr = lhs})
		}
	case .If:
		result, err = parse_if_stmt(p)
	case .For:
		result, err = parse_range_stmt(p)
	case .Match:
		result, err = parse_match_stmt(p)
	case .Break, .Continue:
		result, err = parse_flow_stmt(p)
	case .Return:
		result, err = parse_return_stmt(p)
	case:
		// FIXME: do it more elegantly
		// At this point, all that is left are literals
		result, err = parse_expression_stmt(p)
	}
	if err == nil {
		if p.current.kind == .Comment {
			append(&p.module.comments, p.current)
			consume_token(p)
		}
		err = match_token_kind(p, .Newline)
	}
	return
}

parse_expression_stmt :: proc(p: ^Parser) -> (result: ^Parsed_Expression_Statement, err: Error) {
	result = new(Parsed_Expression_Statement)
	result.token = p.current
	result.expr, err = parse_expr(p, .Lowest)
	return
}

parse_block_stmt :: proc(p: ^Parser, end := Token_Kind_Group{.End}) -> (result: ^Parsed_Block_Statement) {
	result = new(Parsed_Block_Statement)
	result.nodes = make([dynamic]Parsed_Node)
	block: for {
		consume_token(p)
		if p.current.kind in end {
			consume_token(p)
			break block
		}
		if rule, exist := node_parsing_rules[p.current.kind]; exist {
			switch rule.command {
			case .Parse_Node:
				node, node_err := parse_node(p)
				if node_err != nil {
					consume_token_until(p, rule.end)
					append(&p.module.errors, node_err)
				}
				if node != nil {
					append(&result.nodes, node)
				}
			case .Parse_Comment:
				append(&p.module.comments, p.current)
			case .Skip:
				continue block
			case .Exit:
				break block
			}
		} else {
			err := format_error(
				Parsing_Error{
					kind = .Invalid_Syntax,
					token = p.current,
					details = fmt.tprintf("Invalid node"),
				},
			)
			consume_token_until(p, .Newline)
			append(&p.module.errors, err)
		}
	}
	return
}

parse_assign_stmt :: proc(
	p: ^Parser,
	lhs: Parsed_Expression,
) -> (
	result: ^Parsed_Assignment_Statement,
	err: Error,
) {
	result = new(Parsed_Assignment_Statement)
	result.token = p.current
	result.left = lhs
	consume_token(p)
	rhs := parse_expr(p, .Lowest) or_return
	#partial switch result.token.kind {
	case .Assign:
		result.right = rhs
	case:
		result.right = new_clone(
			Parsed_Binary_Expression{
				token = result.token,
				left = lhs,
				right = rhs,
				op = assign_token_to_operator(result.token.kind),
			},
		)
	}
	return
}

parse_if_stmt :: proc(p: ^Parser) -> (result: ^Parsed_If_Statement, err: Error) {
	parse_branch :: proc(
		p: ^Parser,
		is_end_branch: bool,
		loc := #caller_location,
	) -> (
		result: ^Parsed_If_Statement,
		err: Error,
	) {
		result = new(Parsed_If_Statement)
		result.token = p.current
		switch is_end_branch {
		case true:
			result.is_alternative = true
			result.body = parse_block_stmt(p)
		case false:
			consume_token(p)
			result.condition = parse_expr(p, .Lowest) or_return
			match_token_kind(p, .Colon) or_return
			consume_token(p)
			result.body = parse_block_stmt(p, {.End, .Else})
			if p.previous.kind == .Else {
				#partial switch p.current.kind {
				case .If, .Colon:
					result.next_branch = parse_branch(p, p.current.kind == .Colon) or_return
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
		return
	}

	result, err = parse_branch(p, false)
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
		result.op_token = p.current
		consume_token(p)
		result.high = parse_expr(p, .Lowest) or_return
		result.body = parse_block_stmt(p)

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
			current.body = parse_block_stmt(p)
			append(&result.cases, current)

		case .End:
			consume_token(p)
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

parse_return_stmt :: proc(p: ^Parser) -> (result: ^Parsed_Return_Statement, err: Error) {
	result = new_clone(Parsed_Return_Statement{token = p.current})
	#partial switch consume_token(p).kind {
	case .Newline, .EOF:
	case:
		err = format_error(
			Parsing_Error{
				kind = .Invalid_Syntax,
				token = p.previous,
				details = fmt.tprintf(
					"Expected %s or %s, got %s",
					Token_Kind.Newline,
					Token_Kind.EOF,
					p.current.kind,
				),
			},
		)
	}
	return
}

// FIXME: Allow for multiple module name in one Import statement
parse_import_stmt :: proc(p: ^Parser) -> (result: ^Parsed_Import_Statement, err: Error) {
	result = new_clone(Parsed_Import_Statement{token = p.current})
	match_token_kind_next(p, .Identifier) or_return
	result.identifier = p.current
	#partial switch consume_token(p).kind {
	case .Newline, .EOF:
	case:
		err = format_error(
			Parsing_Error{
				kind = .Invalid_Syntax,
				token = p.current,
				details = fmt.tprintf(
					"Expected either %s or %s, got %s",
					Token_Kind.Newline,
					Token_Kind.EOF,
					p.current.kind,
				),
			},
		)
	}
	return
}

parse_field_list :: proc(p: ^Parser, fields: ^[dynamic]^Parsed_Field_Declaration) -> (err: Error) {
	start := len(fields)
	list: for {
		match_token_kind(p, .Identifier) or_return
		field := new(Parsed_Field_Declaration)
		field.token = p.current
		field.name = parse_expr(p, .Lowest) or_return
		append(fields, field)
		#partial switch p.current.kind {
		case .Comma:
			consume_token(p)
		case .Colon:
			consume_token(p)
			break list
		case:
			err = format_error(
				Parsing_Error{
					kind = .Invalid_Syntax,
					token = p.current,
					details = fmt.tprintf("Expected %s, got %s", Token_Kind.Colon, p.current.kind),
				},
			)
			return
		}
	}

	type_expr := parse_expr(p, .Lowest) or_return
	match_token_kind_previous(p, .Newline)
	for field in fields[start:] {
		field.type_expr = type_expr
	}
	return
}

// FIXME: Allow for "var a, b := 10, false"
// FIXME: Allow for uninitialized variable declaration: "var a: number"
parse_var_decl :: proc(p: ^Parser) -> (result: ^Parsed_Var_Declaration, err: Error) {
	result = new(Parsed_Var_Declaration)
	result.token = p.current
	result.initialized = true
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
			// the checker with it
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

parse_fn_decl :: proc(p: ^Parser) -> (result: ^Parsed_Fn_Declaration, err: Error) {
	result = new(Parsed_Fn_Declaration)
	result.token = p.current
	#partial switch p.current.kind {
	case .Fn, .Constructor:
		match_token_kind_next(p, .Identifier) or_return
		result.identifier = p.current
		result.kind = .Function if p.previous.kind == .Fn else .Constructor
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
		state := advance_expr_list(p, FN_PARAMS_LIST_RULE) or_return
		switch state {
		case .Loop:
			continue params
		case .Expect_Next:
			parse_field_list(p, &result.parameters)
			p.expect_punctuation = true
		case .End:
			break params
		}
	}

	// The after ':' after the parameters parenthesis
	match_token_kind(p, .Colon) or_return
	result.colon = p.current

	// We check if the function has a return value or if it is void
	// A newline is the delimiter for the function declaration signature 
	if consume_token(p).kind != .Newline {
		result.return_type_expr = parse_expr(p, .Lowest) or_return
		match_token_kind(p, .Newline)
	}

	with_body := Fn_Kind_Set{.Function, .Constructor, .Method}
	if result.kind in with_body {
		result.body = parse_block_stmt(p)
		result.end = p.previous
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
				#partial switch consume_token(p).kind {
				case .Comment, .Newline:
					continue fields

				case .End:
					consume_token(p)
					break fields

				case .Identifier:
					parse_field_list(p, &result.fields)
					match_token_kind(p, .Newline)

				case .Fn:
					method := parse_fn_decl(p) or_return
					method.kind = .Method
					append(&result.methods, method)

				case .Constructor:
					constructor := parse_fn_decl(p) or_return
					constructor.return_type_expr = new_clone(Parsed_Identifier_Expression{name = name_token})
					constructor.kind = .Constructor
					append(&result.constructors, constructor)


				case:
					err = format_error(
						Parsing_Error{
							kind = .Invalid_Syntax,
							token = p.current,
							details = fmt.tprintf(
								"Expected on of %s, %s, %s, got %s",
								Token_Kind.Identifier,
								Token_Kind.Fn,
								Token_Kind.Constructor,
								p.current.kind,
							),
						},
					)
					return
				}
			}

		case .Enum:
			result.type_kind = .Enum
			enum_fields: for {
				#partial switch consume_token(p).kind {
				case .Newline, .Comment:
					continue enum_fields

				case .Identifier:
					field := new_clone(
						Parsed_Field_Declaration{
							token = p.previous,
							name = parse_expr(p, .Lowest) or_return,
						},
					)
					append(&result.fields, field)

				case .End:
					consume_token(p)
					break enum_fields

				case:
					err = format_error(
						Parsing_Error{
							kind = .Invalid_Syntax,
							token = p.current,
							details = fmt.tprintf(
								"Expected on of %s, %s, %s, got %s",
								Token_Kind.Identifier,
								Token_Kind.Newline,
								p.current.kind,
							),
						},
					)
					return
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

advance_expr_list :: proc(p: ^Parser, rule: Expr_List_Rule) -> (s: Expr_List_State, err: Error) {
	#partial switch p.current.kind {
	case .EOF:
		err = format_error(
			Parsing_Error{
				kind = .Invalid_Syntax,
				token = p.previous,
				details = fmt.tprintf("Expected %s, got %s", rule.end, p.current.kind),
			},
		)
		return
	case rule.end:
		s = .End
		consume_token(p)
	case rule.punctuation:
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
						rule.punctuation,
						rule.end,
						p.current.kind,
					),
				},
			)
			return
		} else if p.current.kind in rule.ignored {
			s = .Loop
			consume_token(p)
		} else {
			s = .Expect_Next
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
	result = new_clone(
		Parsed_Literal_Expression{token = p.previous, value = Value{kind = .Boolean, data = b}},
	)
	return
}

parse_nil :: proc(p: ^Parser) -> (result: Parsed_Expression, err: Error) {
	result = new_clone(Parsed_Literal_Expression{token = p.previous, value = Value{}})
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
	unary := new_clone(Parsed_Unary_Expression{token = p.previous, op = token_to_operator(p.previous.kind)})
	unary.expr, err = parse_expr(p, parser_rules[p.previous.kind].prec)
	result = unary
	return
}

parse_binary :: proc(p: ^Parser, left: Parsed_Expression) -> (result: Parsed_Expression, err: Error) {
	binary := new_clone(
		Parsed_Binary_Expression{token = p.previous, left = left, op = token_to_operator(p.previous.kind)},
	)
	for p.current.kind == .Newline {
		consume_token(p)
	}
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
		state := advance_expr_list(p, FN_PARAMS_LIST_RULE) or_return
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

parse_infix_open_bracket :: proc(
	p: ^Parser,
	left: Parsed_Expression,
) -> (
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
		state := advance_expr_list(p, CONTAINER_ELEM_LIST_RULE) or_return
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
		state := advance_expr_list(p, CONTAINER_ELEM_LIST_RULE) or_return
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
