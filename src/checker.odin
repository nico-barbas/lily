package lily

import "core:fmt"

Checker :: struct {
	module_names:        map[string]int,
	modules:             []^Checked_Module,
	current:             ^Checked_Module,

	// A place to store the parsed modules and keep track of which one is currently being worked on
	parsed:              []^Parsed_Module,
	current_parsed:      ^Parsed_Module,
	// Builtin types and internal states
	builtin_symbols:     [MAP_SYMBOL + 1]Symbol,
	builtin_fn:          [MAP_SYMBOL + 1]^Semantic_Scope,
	array_symbols:       [dynamic]Symbol,
	map_symbols:         [dynamic]Symbol,
	types:               [dynamic]Type_ID,
	type_id_ptr:         Type_ID,

	// to keep track of if "break" and "continue" are allowed in the current context
	allow_flow_operator: bool,
	allow_return:        bool,
	allow_new_dot_chain: bool,
	// Temp data for checking dot expressions
	dot_frames:          [25]Dot_Frame,
	dot_frame_count:     int,
	dot:                 ^Dot_Frame,
}

Dot_Frame :: struct {
	depth:          int,
	start_module:   int,
	start_scope:    ^Semantic_Scope,
	current_module: int,
	current_scope:  ^Semantic_Scope,
	previous:       ^Symbol,
	symbol:         ^Symbol,
}

UNTYPED_SYMBOL :: 0
ANY_SYMBOL :: 1
NUMBER_SYMBOL :: 2
BOOL_SYMBOL :: 3
STRING_SYMBOL :: 4
ARRAY_SYMBOL :: 5
MAP_SYMBOL :: 6

Type_ID :: distinct int

BUILT_IN_ID_COUNT :: MAP_ID + 1

UNTYPED_ID :: 0
ANY_ID :: 1
NUMBER_ID :: 2
BOOL_ID :: 3
STRING_ID :: 4
ARRAY_ID :: 5
MAP_ID :: 6

BUILTIN_MODULE_ID :: -1

init_checker :: proc(c: ^Checker) {
    //odinfmt: disable
	c.builtin_symbols = {
		Symbol{name = "untyped", kind = .Name, type_id = UNTYPED_ID, module_id = BUILTIN_MODULE_ID},
		Symbol{name = "any", kind = .Name, type_id = ANY_ID, module_id = BUILTIN_MODULE_ID},
		Symbol{name = "number", kind = .Name, type_id = NUMBER_ID, module_id = BUILTIN_MODULE_ID},
		Symbol{name = "bool", kind = .Name, type_id = BOOL_ID, module_id = BUILTIN_MODULE_ID},
		Symbol{name = "string", kind = .Name, type_id = STRING_ID, module_id = BUILTIN_MODULE_ID},
		Symbol{name = "array", kind = .Generic_Symbol, type_id = ARRAY_ID, module_id = BUILTIN_MODULE_ID},
		Symbol{name = "map", kind = .Generic_Symbol, type_id = MAP_ID, module_id = BUILTIN_MODULE_ID},
	}
    //odinfmt: enable
	c.builtin_fn[ARRAY_SYMBOL] = new_scope()
	{
		add_symbol_to_scope(
			c.builtin_fn[ARRAY_SYMBOL],
			Symbol{
				name = "append",
				kind = .Fn_Symbol,
				module_id = BUILTIN_MODULE_ID,
				info = Fn_Symbol_Info{
					has_return = false,
					kind = .Builtin,
					param_symbols = []^Symbol{&c.builtin_symbols[ANY_SYMBOL]},
				},
			},
		)
		add_symbol_to_scope(
			c.builtin_fn[ARRAY_SYMBOL],
			Symbol{
				name = "length",
				kind = .Fn_Symbol,
				module_id = BUILTIN_MODULE_ID,
				info = Fn_Symbol_Info{
					has_return = true,
					kind = .Builtin,
					return_symbol = &c.builtin_symbols[NUMBER_SYMBOL],
				},
			},
		)
	}

	c.types = make([dynamic]Type_ID)
	{
		append(&c.types, UNTYPED_ID)
		append(&c.types, NUMBER_ID)
		append(&c.types, BOOL_ID)
		append(&c.types, STRING_ID)
		append(&c.types, ARRAY_ID)
	}
	c.type_id_ptr = BUILT_IN_ID_COUNT
	c.allow_new_dot_chain = true
}

free_checker :: proc(c: ^Checker) {
	for scope in c.builtin_fn {
		if scope != nil {
			free_scope(scope)
		}
	}
	for module in c.modules {
		delete_checked_module(module)
	}
	delete(c.modules)
	delete(c.types)
}

contain_symbol :: proc(c: ^Checker, token: Token) -> bool {
	builtins: for symbol in c.builtin_symbols {
		if symbol.name == token.text {
			return true
		}
	}

	scope := c.current.scope
	find: for scope != nil {
		if contain_scoped_symbol(scope, token.text) {
			return true
		}
		scope = scope.parent
	}

	return false
}

get_symbol :: proc(c: ^Checker, token: Token, loc := #caller_location) -> (result: ^Symbol, err: Error) {
	builtins: for symbol, i in c.builtin_symbols {
		if symbol.name == token.text {
			result = &c.builtin_symbols[i]
			return
		}
	}

	scope := c.current.scope
	find: for scope != nil {
		for symbol, i in scope.symbols {
			if symbol.name == token.text {
				result = &scope.symbols[i]
				return
			}
		}
		scope = scope.parent
	}

	// The symbol wasn't found
	err = format_error(
		Semantic_Error{
			kind = .Unknown_Symbol,
			token = token,
			details = fmt.tprintf("Unknown symbol: %s", token.text),
		},
		loc,
	)
	return
}

push_dot_frame :: proc(c: ^Checker) {
	c.dot_frames[c.dot_frame_count] = Dot_Frame {
		start_module = c.current.id,
		start_scope  = c.current.scope,
	}
	c.dot = &c.dot_frames[c.dot_frame_count]
	c.dot_frame_count += 1
}

pop_dot_frame :: proc(c: ^Checker, loc := #caller_location) {
	c.current = c.modules[c.dot.start_module]
	c.current.scope = c.dot.start_scope
	c.dot_frame_count -= 1
	c.dot = &c.dot_frames[c.dot_frame_count]
	c.allow_new_dot_chain = true
}

restore_dot_frame_start :: proc(c: ^Checker) {
	c.current = c.modules[c.dot.start_module]
	c.current.scope = c.dot.start_scope
}

restore_dot_frame_current :: proc(c: ^Checker) {
	c.current = c.modules[c.dot.start_module]
	c.current.scope = c.dot.start_scope
}

types_equal :: proc(c: ^Checker, s1, s2: ^Symbol) -> bool {
	if s1.type_id == ANY_ID || s2.type_id == ANY_ID {
		return true
	} else {
		return s1.type_id == s2.type_id
	}
}

expect_type :: proc(
	c: ^Checker,
	expr: Checked_Expression,
	s: ^Symbol,
	loc := #caller_location,
) -> (
	err: Error,
) {
	expr_symbol := checked_expr_symbol(expr)
	if !types_equal(c, expr_symbol, s) {
		expected := s
		if s.kind == .Var_Symbol {
			info := s.info.(Var_Symbol_Info)
			expected = info.symbol
		}
		got := expr_symbol
		if got.kind == .Var_Symbol {
			info := got.info.(Var_Symbol_Info)
			got = info.symbol
		}
		err = format_error(
			Semantic_Error{
				kind = .Mismatched_Types,
				token = checked_expr_token(expr),
				details = fmt.tprintf("Expected type %s, got %s", expected.name, got.name),
			},
			loc,
		)
	}
	return
}

expect_one_of_types :: proc(c: ^Checker, expr: Checked_Expression, l: []^Symbol) -> (err: Error) {
	expr_symbol := checked_expr_symbol(expr)
	for expected in l {
		if types_equal(c, expr_symbol, expected) {
			return
		}
	}
	err = format_error(
		Semantic_Error{
			kind = .Mismatched_Types,
			token = checked_expr_token(expr),
			details = fmt.tprintf("%s is not of a valid type in this context", expr_symbol.name),
		},
	)
	return
}

gen_type_id :: proc(c: ^Checker) -> Type_ID {
	c.type_id_ptr += 1
	return c.type_id_ptr - 1
}


build_checked_program :: proc(
	c: ^Checker,
	n: map[string]int,
	p: []^Parsed_Module,
	order: []int,
) -> (
	result: []^Checked_Module,
	err: Error,
) {
	c.module_names = n
	c.parsed = p

	// Build all the symbols and then check them
	for id in order {
		c.modules[id] = make_checked_module(p[id].name, id)
		add_module_import_symbols(c, id) or_return
		add_module_decl_symbols(c, id) or_return
		add_module_type_decl(c, id) or_return
	}
	for id in order {
		check_module_signatures_symbols(c, id) or_return
	}
	for id in order {
		add_module_inner_symbols(c, id) or_return
	}
	for id in order {
		build_checked_ast(c, id) or_return
	}

	result = c.modules
	return
}

add_module_import_symbols :: proc(c: ^Checker, module_id: int) -> (err: Error) {
	c.current = c.modules[module_id]
	c.current_parsed = c.parsed[module_id]

	for import_node in c.current_parsed.import_nodes {
		import_stmt := import_node.(^Parsed_Import_Statement)
		import_id := c.module_names[import_stmt.identifier.text]
		add_symbol_to_scope(
			c.current.root,
			Symbol{
				name = import_stmt.identifier.text,
				kind = .Module_Symbol,
				module_id = module_id,
				scope_id = c.current.root.id,
				info = Module_Symbol_Info{ref_mod_id = import_id},
			},
		) or_return
	}
	return
}

add_module_decl_symbols :: proc(c: ^Checker, module_id: int) -> (err: Error) {
	c.current = c.modules[module_id]
	c.current_parsed = c.parsed[module_id]
	// The type symbols need to be added first
	for node in c.current_parsed.types {
		if n, ok := node.(^Parsed_Type_Declaration); ok {
			switch n.type_kind {
			case .Alias:
				add_symbol_to_scope(
					c.current.root,
					Symbol{
						name = n.identifier.text,
						kind = .Alias_Symbol,
						module_id = module_id,
						scope_id = c.current.root.id,
					},
				) or_return

			case .Enum:
			case .Class:
				push_class_scope(c.current, n.identifier) or_return
				defer pop_scope(c.current)
				for field in n.fields {
					add_symbol_to_scope(
						c.current.scope,
						Symbol{
							name = field.name.(^Parsed_Identifier_Expression).name.text,
							kind = .Var_Symbol,
							module_id = module_id,
							scope_id = c.current.scope.id,
						},
					) or_return
				}
				for constructor in n.constructors {
					constr_scope_id := push_scope(c.current, constructor.identifier)
					pop_scope(c.current)
					add_symbol_to_scope(
						c.current.scope,
						Symbol{
							name = constructor.identifier.text,
							kind = .Fn_Symbol,
							module_id = module_id,
							scope_id = c.current.scope.id,
							info = Fn_Symbol_Info{
								sub_scope_id = constr_scope_id,
								has_return = true,
								kind = .Constructor,
								param_symbols = make([]^Symbol, len(constructor.parameters)),
							},
						},
					) or_return
				}

				for method in n.methods {
					method_scope_id := push_scope(c.current, method.identifier)
					pop_scope(c.current)
					add_symbol_to_scope(
						c.current.scope,
						Symbol{
							name = method.identifier.text,
							kind = .Fn_Symbol,
							module_id = module_id,
							scope_id = c.current.scope.id,
							info = Fn_Symbol_Info{
								sub_scope_id = method_scope_id,
								kind = .Method,
								param_symbols = make([]^Symbol, len(method.parameters)),
							},
						},
					) or_return
				}

			}
		}
	}

	for node in c.current_parsed.functions {
		if n, ok := node.(^Parsed_Fn_Declaration); ok {
			fn_scope_id := push_scope(c.current, n.identifier)
			pop_scope(c.current)
			add_symbol_to_scope(
				c.current.scope,
				Symbol{
					name = n.identifier.text,
					kind = .Fn_Symbol,
					module_id = module_id,
					scope_id = c.current.scope.id,
					info = Fn_Symbol_Info{
						sub_scope_id = fn_scope_id,
						kind = n.kind,
						param_symbols = make([]^Symbol, len(n.parameters)),
					},
				},
			) or_return
		}
	}

	for node in c.current_parsed.variables {
		if n, ok := node.(^Parsed_Var_Declaration); ok {
			add_symbol_to_scope(
				c.current.scope,
				Symbol{
					name = n.identifier.text,
					kind = .Var_Symbol,
					module_id = module_id,
					scope_id = c.current.scope.id,
					info = Var_Symbol_Info{mutable = true, depth = c.current.scope_depth},
				},
			) or_return
		}
	}
	return
}

add_module_type_decl :: proc(c: ^Checker, module_id: int) -> (err: Error) {
	c.current = c.modules[module_id]
	c.current_parsed = c.parsed[module_id]

	for node in c.current_parsed.types {
		#partial switch n in node {
		case ^Parsed_Type_Declaration:
			switch n.type_kind {
			case .Alias:
				// add_type_alias(c, n.identifier, UNTYPED_ID)
				assert(false)
			case .Enum:
			case .Class:
				add_module_class_type(c, n)
			}
		}
	}
	return
}

add_module_class_type :: proc(c: ^Checker, decl: ^Parsed_Type_Declaration) -> (err: Error) {
	append(&c.types, c.type_id_ptr)
	class_symbol := get_scoped_symbol(c.current.root, decl.identifier) or_return
	class_symbol.type_id = c.type_id_ptr
	c.type_id_ptr += 1

	enter_class_scope(c.current, decl.identifier)
	defer pop_scope(c.current)
	self_symbol := get_scoped_symbol(c.current.scope, Token{text = "self"}) or_return
	self_symbol.type_id = class_symbol.type_id
	return
}

check_module_signatures_symbols :: proc(c: ^Checker, module_id: int) -> (err: Error) {
	c.current = c.modules[module_id]
	c.current.scope = c.current.root
	c.current_parsed = c.parsed[module_id]

	// Signatures to check:
	// class constructors
	for node in c.current_parsed.types {
		n := node.(^Parsed_Type_Declaration)
		if n.type_kind == .Alias {
			continue
		}

		enter_class_scope(c.current, n.identifier)
		defer pop_scope(c.current)

		for field in n.fields {
			if field.type_expr == nil {
				err = format_error(
					Semantic_Error{
						kind = .Invalid_Symbol,
						token = field.token,
						details = "Expected type expression for class's field declaration",
					},
				)
				return
			}
			type_symbol := symbol_from_type_expr(c, field.type_expr.?) or_return
			field_name := field.name.(^Parsed_Identifier_Expression).name
			field_symbol := get_scoped_symbol(c.current.scope, field_name) or_return
			field_symbol_info := Var_Symbol_Info {
				symbol  = type_symbol,
				mutable = true,
				depth   = c.current.scope_depth,
			}
			field_symbol.info = field_symbol_info
			field_symbol.type_id = type_symbol.type_id
		}

		for constructor in n.constructors {
			check_fn_signature_symbols(c, constructor) or_return
		}

		for method in n.methods {
			check_fn_signature_symbols(c, method) or_return
		}
	}


	// functions
	for node in c.current_parsed.functions {
		n := node.(^Parsed_Fn_Declaration)
		check_fn_signature_symbols(c, n) or_return
	}
	return
}

check_fn_signature_symbols :: proc(c: ^Checker, fn_decl: ^Parsed_Fn_Declaration) -> (err: Error) {
	fn_symbol, _ := get_scoped_symbol(c.current.scope, fn_decl.identifier)
	fn_info := fn_symbol.info.(Fn_Symbol_Info)
	if fn_decl.return_type_expr != nil {
		fn_info.return_symbol = symbol_from_type_expr(c, fn_decl.return_type_expr) or_return
		fn_info.has_return = true
	}

	enter_child_scope_by_id(c.current, fn_info.sub_scope_id) or_return
	{
		if fn_info.kind != .Constructor && fn_info.has_return {
			add_symbol_to_scope(
				c.current.scope,
				Symbol{
					name = "result",
					kind = .Var_Symbol,
					type_id = fn_info.return_symbol.type_id,
					module_id = c.current.id,
					scope_id = c.current.scope.id,
					info = Var_Symbol_Info{
						symbol = fn_info.return_symbol,
						mutable = true,
						depth = c.current.scope_depth,
					},
				},
				true,
			) or_return
		}
		for param, i in fn_decl.parameters {
			if param.type_expr == nil {
				err = format_error(
					Semantic_Error{
						kind = .Invalid_Symbol,
						token = param.token,
						details = "Expected type expression in function's parameter declaration",
					},
				)
				return
			}
			type_symbol := symbol_from_type_expr(c, param.type_expr.?) or_return
			param_name := param.name.(^Parsed_Identifier_Expression).name
					//odinfmt: disable
			param_symbol := add_symbol_to_scope(
				c.current.scope, 
				Symbol {
					name = param_name.text,
					kind = .Var_Symbol,
					type_id = type_symbol.type_id,
					module_id = c.current.id,
					scope_id = c.current.scope.id,
					info = Var_Symbol_Info{
						symbol = type_symbol, 
						mutable = false,
						depth = c.current.scope_depth,
					},
				}, 
				true,
			) or_return
			//odinfmt: enable
			fn_info.param_symbols[i] = param_symbol
		}
	}
	fn_symbol.info = fn_info
	pop_scope(c.current)
	return
}

add_module_inner_symbols :: proc(c: ^Checker, module_id: int) -> (err: Error) {
	c.current = c.modules[module_id]
	c.current.scope = c.current.root
	c.current_parsed = c.parsed[module_id]

	for node in c.current_parsed.types {
		add_inner_symbols(c, node) or_return
	}

	for node in c.current_parsed.functions {
		add_inner_symbols(c, node) or_return
	}
	for node in c.current_parsed.nodes {
		add_inner_symbols(c, node) or_return
	}
	return
}

add_inner_symbols :: proc(c: ^Checker, node: Parsed_Node) -> (err: Error) {
	switch n in node {
	case ^Parsed_Expression_Statement:

	case ^Parsed_Block_Statement:
		for inner_node in n.nodes {
			add_inner_symbols(c, inner_node) or_return
		}

	case ^Parsed_Assignment_Statement:

	case ^Parsed_If_Statement:
		push_scope(c.current, n.token)
		add_inner_symbols(c, n.body) or_return
		pop_scope(c.current)

		if n.next_branch != nil {
			add_inner_symbols(c, n.next_branch) or_return
		}

	case ^Parsed_Range_Statement:
		push_scope(c.current, n.token)
		defer pop_scope(c.current)
		add_symbol_to_scope(
			c.current.scope,
			Symbol{
				name = n.iterator_name.text,
				kind = .Var_Symbol,
				type_id = NUMBER_ID,
				module_id = c.current.id,
				scope_id = c.current.scope.id,
				info = Var_Symbol_Info{
					symbol = &c.builtin_symbols[NUMBER_SYMBOL],
					mutable = false,
					depth = c.current.scope_depth,
				},
			},
			true,
		) or_return
		add_inner_symbols(c, n.body) or_return

	case ^Parsed_Match_Statement:
		push_scope(c.current, n.token)
		defer pop_scope(c.current)
		for ca in n.cases {
			push_scope(c.current, ca.token)
			defer pop_scope(c.current)
			add_inner_symbols(c, ca.body) or_return
		}

	case ^Parsed_Flow_Statement:

	case ^Parsed_Return_Statement:

	case ^Parsed_Import_Statement:

	case ^Parsed_Field_Declaration:

	case ^Parsed_Var_Declaration:
		add_symbol_to_scope(
			c.current.scope,
			Symbol{
				name = n.identifier.text,
				kind = .Var_Symbol,
				module_id = c.current.id,
				scope_id = c.current.scope.id,
				info = Var_Symbol_Info{mutable = true, depth = c.current.scope_depth},
			},
		) or_return

	case ^Parsed_Fn_Declaration:
		symbol := get_scoped_symbol(c.current.scope, n.identifier) or_return
		fn_info := symbol.info.(Fn_Symbol_Info)
		enter_child_scope_by_id(c.current, fn_info.sub_scope_id) or_return
		defer pop_scope(c.current)
		if n.kind != .Foreign {
			add_inner_symbols(c, n.body) or_return
		}

	case ^Parsed_Type_Declaration:
		if n.type_kind == .Class {
			enter_class_scope(c.current, n.identifier)
			defer pop_scope(c.current)

			for constructor in n.constructors {
				add_inner_symbols(c, constructor) or_return
			}
			for method in n.methods {
				add_inner_symbols(c, method) or_return
			}
		}
	}
	return
}

build_checked_ast :: proc(c: ^Checker, module_id: int) -> (err: Error) {
	c.current = c.modules[module_id]
	c.current.scope = c.current.root
	c.current_parsed = c.parsed[module_id]

	for node in c.current_parsed.variables {
		var_node := build_checked_node(c, node) or_return
		append(&c.current.variables, var_node)
	}
	for node in c.current_parsed.types {
		class_node := build_checked_node(c, node) or_return
		append(&c.current.classes, class_node)
	}
	for node in c.current_parsed.functions {
		fn_node := build_checked_node(c, node) or_return
		append(&c.current.functions, fn_node)
	}

	for node in c.current_parsed.nodes {
		checked_node := build_checked_node(c, node) or_return
		append(&c.current.nodes, checked_node)
	}
	return
}

build_checked_node :: proc(c: ^Checker, node: Parsed_Node) -> (result: Checked_Node, err: Error) {
	switch n in node {
	case ^Parsed_Expression_Statement:
		expr_stmt := new(Checked_Expression_Statement)
		expr_stmt.token = n.token
		expr_stmt.expr = build_checked_expr(c, n.expr) or_return
		result = expr_stmt

	case ^Parsed_Block_Statement:
		block_stmt := new_clone(
			Checked_Block_Statement{token = n.token, nodes = make([]Checked_Node, len(n.nodes))},
		)
		for inner_node, i in n.nodes {
			checked_node := build_checked_node(c, inner_node) or_return
			block_stmt.nodes[i] = checked_node
		}
		result = block_stmt

	case ^Parsed_Assignment_Statement:
		assign_stmt := new_clone(
			Checked_Assigment_Statement{
				token = n.token,
				left = build_checked_expr(c, n.left) or_return,
				right = build_checked_expr(c, n.right) or_return,
			},
		)
		#partial switch right in assign_stmt.right {
		case ^Checked_Identifier_Expression:
			expr_symbol := checked_expr_symbol(right)
			#partial switch expr_symbol.kind {
			case .Class_Symbol, .Module_Symbol, .Fn_Symbol, .Name:
				err = rhs_assign_semantic_err(expr_symbol, n.token)
				return
			}
		}

		identifier_symbol: ^Symbol
		left_type_symbol: ^Symbol
		#partial switch left in assign_stmt.left {
		case ^Checked_Identifier_Expression:
			identifier_symbol = checked_expr_symbol(left)
			left_type_symbol = identifier_symbol
		case ^Checked_Index_Expression, ^Checked_Dot_Expression:
			identifier_symbol = checked_expr_symbol(left)
			left_type_symbol = checked_expr_symbol(left, false)
		}

		#partial switch identifier_symbol.kind {
		case .Class_Symbol, .Module_Symbol, .Fn_Symbol, .Name:
			err = lhs_assign_semantic_err(left_type_symbol, n.token)
			return
		}
		identifier_info := identifier_symbol.info.(Var_Symbol_Info)
		if !identifier_info.mutable {
			err = mutable_semantic_err(identifier_symbol, n.token)
			return
		}
		expect_type(c, assign_stmt.right, left_type_symbol) or_return
		result = assign_stmt

	case ^Parsed_If_Statement:
		if_stmt := new_clone(Checked_If_Statement{token = n.token, is_alternative = n.is_alternative})
		if !n.is_alternative {
			if_stmt.condition = build_checked_expr(c, n.condition) or_return
			expect_type(c, if_stmt.condition, &c.builtin_symbols[BOOL_SYMBOL]) or_return
		}

		enter_child_scope_by_name(c.current, n.token)
		if_stmt.body = build_checked_node(c, n.body) or_return
		pop_scope(c.current)

		if n.next_branch != nil {
			if_stmt.next_branch = build_checked_node(c, n.next_branch) or_return
		}
		result = if_stmt

	case ^Parsed_Range_Statement:
		range_stmt := new_clone(Checked_Range_Statement{token = n.token})
		c.allow_flow_operator = true
		defer c.allow_flow_operator = false
		enter_child_scope_by_name(c.current, n.token)
		defer pop_scope(c.current)
		range_stmt.iterator = get_scoped_symbol(c.current.scope, n.iterator_name) or_return
		range_stmt.low = build_checked_expr(c, n.low) or_return
		range_stmt.high = build_checked_expr(c, n.high) or_return
		expect_type(c, range_stmt.low, &c.builtin_symbols[NUMBER_SYMBOL]) or_return
		expect_type(c, range_stmt.high, &c.builtin_symbols[NUMBER_SYMBOL]) or_return
		range_stmt.op = n.op
		range_stmt.body = build_checked_node(c, n.body) or_return
		result = range_stmt

	case ^Parsed_Match_Statement:
		match_stmt := new_clone(
			Checked_Match_Statement{
				token = n.token,
				evaluation = build_checked_expr(c, n.evaluation) or_return,
				cases = make([]struct {
						token:     Token,
						condition: Checked_Expression,
						body:      Checked_Node,
					}, len(n.cases)),
			},
		)
		eval_symbol := checked_expr_symbol(match_stmt.evaluation)
		// FIXME: Allow for strings, and later on enumerations and ADTs
		expect_one_of_types(
			c,
			match_stmt.evaluation,
			{&c.builtin_symbols[NUMBER_SYMBOL], &c.builtin_symbols[BOOL_SYMBOL]},
		) or_return
		enter_child_scope_by_name(c.current, n.token)
		defer pop_scope(c.current)

		BOOL_CASE_COUNT :: 2
		switch eval_symbol.type_id {
		case BOOL_ID:
			if len(n.cases) != BOOL_CASE_COUNT {
				err = format_error(
					Semantic_Error{
						kind = .Unhandled_Match_Cases,
						token = n.token,
						details = fmt.tprintf(
							"Unhandled cases for match statement of type %s",
							eval_symbol.name,
						),
					},
				)
				return
			}
		}
		for ca, i in n.cases {
			match_stmt.cases[i].token = ca.token
			match_stmt.cases[i].condition = build_checked_expr(c, ca.condition) or_return
			expect_type(c, match_stmt.cases[i].condition, eval_symbol) or_return
			match_stmt.cases[i].body = build_checked_node(c, ca.body) or_return
		}
		result = match_stmt

	case ^Parsed_Flow_Statement:
		if !c.allow_flow_operator {
			err = format_error(
				Semantic_Error{
					kind = .Invalid_Symbol,
					token = n.token,
					details = fmt.tprintf("%s only allowed in loops", n.token.text),
				},
			)
			return
		}
		result = new_clone(Checked_Flow_Statement{token = n.token, kind = n.kind})

	case ^Parsed_Return_Statement:
		if !c.allow_return {
			err = format_error(
				Semantic_Error{
					kind = .Invalid_Symbol,
					token = n.token,
					details = fmt.tprintf("%s only allowed at function body level", n.token.kind),
				},
			)
			return
		}
		result = new_clone(Checked_Return_Statement{token = n.token})

	case ^Parsed_Import_Statement:
	case ^Parsed_Field_Declaration:

	case ^Parsed_Var_Declaration:
		var_decl := new_clone(
			Checked_Var_Declaration{
				token = n.token,
				identifier = get_scoped_symbol(c.current.scope, n.identifier) or_return,
				expr = build_checked_expr(c, n.expr) or_return,
			},
		)
		expr_symbol := checked_expr_symbol(var_decl.expr)
		#partial switch expr in var_decl.expr {
		case ^Checked_Identifier_Expression:
			#partial switch expr_symbol.kind {
			case .Class_Symbol, .Module_Symbol, .Fn_Symbol, .Name:
				err = rhs_assign_semantic_err(expr_symbol, n.token)
				return
			}
		}
		type_hint := symbol_from_type_expr(c, n.type_expr) or_return
		var_info := var_decl.identifier.info.(Var_Symbol_Info)
		if type_hint.name != "untyped" {
			var_info.symbol = type_hint
			var_decl.identifier.type_id = type_hint.type_id
			expect_type(c, var_decl.expr, type_hint) or_return
		} else {
			var_decl.identifier.type_id = expr_symbol.type_id
			var_info.symbol = expr_symbol
		}
		var_decl.identifier.info = var_info
		result = var_decl

	case ^Parsed_Fn_Declaration:
		fn_decl := new_clone(
			Checked_Fn_Declaration{
				token = n.token,
				kind = n.kind,
				params = make([]^Symbol, len(n.parameters)),
			},
		)
		fn_decl.identifier = get_scoped_symbol(c.current.scope, n.identifier) or_return
		fn_info := fn_decl.identifier.info.(Fn_Symbol_Info)
		enter_child_scope_by_id(c.current, fn_info.sub_scope_id) or_return
		defer pop_scope(c.current)

		for param, i in n.parameters {
			param_name := param.name.(^Parsed_Identifier_Expression).name
			fn_decl.params[i] = get_scoped_symbol(c.current.scope, param_name) or_return
		}
		if n.kind != .Foreign {
			c.allow_return = true
			defer c.allow_return = false
			fn_decl.body = build_checked_node(c, n.body) or_return
		}
		result = fn_decl


	case ^Parsed_Type_Declaration:
		switch n.type_kind {
		case .Alias:
			assert(false)
		case .Enum:
		case .Class:
			class_decl := new_clone(
				Checked_Class_Declaration{
					token = n.token,
					is_token = n.is_token,
					fields = make([]^Symbol, len(n.fields)),
					constructors = make([]^Checked_Fn_Declaration, len(n.constructors)),
					methods = make([]^Checked_Fn_Declaration, len(n.methods)),
				},
			)
			class_decl.identifier, err = get_scoped_symbol(c.current.scope, n.identifier)
			if err != nil {
				print_semantic_scope_standalone(c, c.current.scope)
			}
			enter_class_scope(c.current, n.identifier) or_return
			defer pop_scope(c.current)

			for field, i in n.fields {
				field_name := field.name.(^Parsed_Identifier_Expression).name
				class_decl.fields[i] = get_scoped_symbol(c.current.scope, field_name) or_return
			}

			for constructor, i in n.constructors {
				checked_constructor := build_checked_node(c, constructor) or_return
				class_decl.constructors[i] = checked_constructor.(^Checked_Fn_Declaration)
			}

			for method, i in n.methods {
				checked_method := build_checked_node(c, method) or_return
				class_decl.methods[i] = checked_method.(^Checked_Fn_Declaration)
			}
			result = class_decl
		}

	}

	return
}

build_checked_expr :: proc(
	c: ^Checker,
	expr: Parsed_Expression,
) -> (
	result: Checked_Expression,
	err: Error,
) {
	switch e in expr {
	case ^Parsed_Literal_Expression:
		lit := new_clone(Checked_Literal_Expression{token = e.token, value = e.value})
		#partial switch e.value.kind {
		case .Number:
			lit.symbol = &c.builtin_symbols[NUMBER_SYMBOL]
		case .Boolean:
			lit.symbol = &c.builtin_symbols[BOOL_SYMBOL]
		}
		result = lit

	case ^Parsed_String_Literal_Expression:
		result = new_clone(
			Checked_String_Literal_Expression{
				token = e.token,
				symbol = &c.builtin_symbols[STRING_SYMBOL],
				value = e.value,
			},
		)

	case ^Parsed_Array_Literal_Expression:
		array_lit := new_clone(
			Checked_Array_Literal_Expression{
				token = e.token,
				symbol = symbol_from_type_expr(c, e.type_expr) or_return,
				values = make([]Checked_Expression, len(e.values)),
			},
		)
		inner_info := array_lit.symbol.info.(Generic_Symbol_Info)
		for value, i in e.values {
			array_lit.values[i] = build_checked_expr(c, value) or_return
			expect_type(c, array_lit.values[i], inner_info.symbols[0]) or_return
		}
		result = array_lit

	case ^Parsed_Map_Literal_Expression:
		// FIXME: check for duplicate keys in the literal
		map_lit := new_clone(
			Checked_Map_Literal_Expression{
				token = e.token,
				symbol = symbol_from_type_expr(c, e.type_expr) or_return,
				elements = make([]Checked_Map_Element, len(e.elements)),
			},
		)
		inner_info := map_lit.symbol.info.(Generic_Symbol_Info)
		for element, i in e.elements {
			elem := Checked_Map_Element{}
			elem.key = build_checked_expr(c, element.key) or_return
			expect_type(c, elem.key, inner_info.symbols[0]) or_return
			elem.value = build_checked_expr(c, element.value) or_return
			expect_type(c, elem.value, inner_info.symbols[1]) or_return
			map_lit.elements[i] = elem
		}
		result = map_lit

	case ^Parsed_Unary_Expression:
		unary_expr := new_clone(
			Checked_Unary_Expression{
				token = e.token,
				op = e.op,
				expr = build_checked_expr(c, e.expr) or_return,
			},
		)
		unary_expr.symbol = checked_expr_symbol(unary_expr.expr)
		#partial switch e.op {
		case .Minus_Op:
			expect_type(c, unary_expr.expr, &c.builtin_symbols[NUMBER_SYMBOL]) or_return
		case .Not_Op:
			expect_type(c, unary_expr.expr, &c.builtin_symbols[BOOL_SYMBOL]) or_return
		}
		result = unary_expr

	case ^Parsed_Binary_Expression:
		binary_expr := new_clone(
			Checked_Binary_Expression{
				token = e.token,
				op = e.op,
				left = build_checked_expr(c, e.left) or_return,
				right = build_checked_expr(c, e.right) or_return,
			},
		)

		expect_type(c, binary_expr.right, checked_expr_symbol(binary_expr.left)) or_return
		#partial switch e.op {
		case .Minus_Op, .Plus_Op, .Mult_Op, .Div_Op, .Rem_Op:
			expect_type(c, binary_expr.left, &c.builtin_symbols[NUMBER_SYMBOL]) or_return
			expect_type(c, binary_expr.right, &c.builtin_symbols[NUMBER_SYMBOL]) or_return
			binary_expr.symbol = checked_expr_symbol(binary_expr.left)

		case .Or_Op, .And_Op:
			expect_type(c, binary_expr.left, &c.builtin_symbols[BOOL_SYMBOL]) or_return
			expect_type(c, binary_expr.right, &c.builtin_symbols[BOOL_SYMBOL]) or_return
			binary_expr.symbol = &c.builtin_symbols[BOOL_SYMBOL]

		case .Equal_Op, .Greater_Op, .Greater_Eq_Op, .Lesser_Op, .Lesser_Eq_Op:
			expect_type(c, binary_expr.left, &c.builtin_symbols[NUMBER_SYMBOL]) or_return
			expect_type(c, binary_expr.right, &c.builtin_symbols[NUMBER_SYMBOL]) or_return
			binary_expr.symbol = &c.builtin_symbols[BOOL_SYMBOL]

		}

		result = binary_expr

	case ^Parsed_Identifier_Expression:
		identifier_expr := new_clone(
			Checked_Identifier_Expression{token = e.name, symbol = get_symbol(c, e.name) or_return},
		)
		result = identifier_expr

	case ^Parsed_Index_Expression:
		index_expr := new_clone(
			Checked_Index_Expression{
				token = e.token,
				left = build_checked_expr(c, e.left) or_return,
				index = build_checked_expr(c, e.index) or_return,
			},
		)
		left_symbol := checked_expr_symbol(index_expr.left)
		left_info: Generic_Symbol_Info
		if left_symbol.kind == .Var_Symbol {
			info := left_symbol.info.(Var_Symbol_Info)
			if !is_indexable_symbol(info.symbol) {
				err = index_semantic_err(left_symbol, e.token)
				return
			}
			left_info = info.symbol.info.(Generic_Symbol_Info)
		} else {
			err = index_semantic_err(left_symbol, e.token)
			return
		}

		switch left_symbol.type_id {
		case ARRAY_ID:
			index_expr.kind = .Array
			expect_type(c, index_expr.index, &c.builtin_symbols[NUMBER_SYMBOL]) or_return
			index_expr.symbol = left_info.symbols[0]
		case MAP_ID:
			index_expr.kind = .Map
			expect_type(c, index_expr.index, left_info.symbols[0]) or_return
			index_expr.symbol = left_info.symbols[1]
		}
		result = index_expr

	case ^Parsed_Dot_Expression:
		if c.allow_new_dot_chain {
			push_dot_frame(c)
			c.allow_new_dot_chain = false
		}
		c.dot.depth += 1

		dot_expr := new_clone(Checked_Dot_Expression{token = e.token})

		#partial switch left in e.left {
		case ^Parsed_Identifier_Expression:
			l := build_checked_expr(c, left) or_return
			c.dot.symbol = checked_expr_symbol(l)
			#partial switch c.dot.symbol.kind {
			case .Class_Symbol:
				if c.dot.depth > 2 {
					err = dot_operand_semantic_err(c.dot.symbol, e.token)
					return
				}
				enter_class_scope(c.current, Token{text = c.dot.symbol.name}) or_return

			case .Var_Symbol:
				var_info := c.dot.symbol.info.(Var_Symbol_Info)
				#partial switch var_info.symbol.kind {
				case .Class_Symbol:
					c.current = c.modules[var_info.symbol.module_id]
					enter_class_scope(c.current, Token{text = var_info.symbol.name}) or_return
				case .Generic_Symbol:
					if var_info.symbol.type_id == ARRAY_ID || var_info.symbol.type_id == MAP_ID {
						c.dot.symbol = var_info.symbol
					} else {
						err = dot_operand_semantic_err(c.dot.symbol, e.token)
						return
					}
				case:
					err = dot_operand_semantic_err(c.dot.symbol, e.token)
					return
				}

			case .Module_Symbol:
				if c.dot.depth > 1 {
					err = dot_operand_semantic_err(c.dot.symbol, e.token)
					return
				}
				module_info := c.dot.symbol.info.(Module_Symbol_Info)
				c.current = c.modules[module_info.ref_mod_id]
				c.current.scope = c.current.root

			case:
				err = dot_operand_semantic_err(c.dot.symbol, e.token)
				return
			}

			c.dot.current_module = c.current.id
			c.dot.current_scope = c.current.scope
			dot_expr.left = l

		case ^Parsed_Index_Expression:
			index_expr := new_clone(
				Checked_Index_Expression{
					token = left.token,
					left = build_checked_expr(c, left.left) or_return,
				},
			)
			left_symbol := checked_expr_symbol(index_expr.left)
			if left_symbol.kind == .Var_Symbol {
				left_info := left_symbol.info.(Var_Symbol_Info)
				if !is_indexable_symbol(left_info.symbol) {
					err = index_semantic_err(left_symbol, e.token)
					return
				}
				index_expr.symbol = left_info.symbol.info.(Generic_Symbol_Info).symbols[0]
			} else {
				err = index_semantic_err(left_symbol, e.token)
				return
			}

			restore_dot_frame_start(c)
			{
				c.allow_new_dot_chain = true
				defer c.allow_new_dot_chain = false
				// f_count := c.dot_frame_count
				index_expr.index = build_checked_expr(c, left.index) or_return
				switch left_symbol.type_id {
				case ARRAY_ID:
					index_expr.kind = .Array
					expect_type(c, index_expr.index, &c.builtin_symbols[NUMBER_SYMBOL]) or_return
				}
				// if c.dot_frame_count == f_count do pop_dot_frame(c)
			}
			if !is_valid_accessor(index_expr.symbol) {
				err = dot_operand_semantic_err(index_expr.symbol, left.token)
				return
			}
			c.current = c.modules[index_expr.symbol.module_id]
			enter_class_scope(c.current, Token{text = index_expr.symbol.name}) or_return
			c.dot.symbol = index_expr.symbol
			c.dot.current_module = c.current.id
			c.dot.current_scope = c.current.scope

			dot_expr.left = index_expr

		case ^Parsed_Call_Expression:
			call_expr := new_clone(
				Checked_Call_Expression{
					token = left.token,
					args = make([]Checked_Expression, len(left.args)),
				},
			)
			call_expr.func = build_checked_expr(c, left.func) or_return

			fn_symbol := checked_expr_symbol(call_expr.func)
			if fn_symbol.kind != .Fn_Symbol {
				err = call_semantic_err(fn_symbol, left.token)
				return
			}
			fn_info := fn_symbol.info.(Fn_Symbol_Info)
			if !fn_info.has_return {
				err = dot_operand_semantic_err(fn_symbol, left.token)
				return
			}
			call_expr.symbol = fn_info.return_symbol

			restore_dot_frame_start(c)
			for arg, i in left.args {
				c.allow_new_dot_chain = true
				defer c.allow_new_dot_chain = false
				// push_dot_frame(c)
				// f_count := c.dot_frame_count
				call_expr.args[i] = build_checked_expr(c, arg) or_return
				expect_type(c, call_expr.args[i], fn_info.param_symbols[i]) or_return
				// if c.dot_frame_count == f_count do pop_dot_frame(c)
			}
			if !is_valid_accessor(call_expr.symbol) {
				err = dot_operand_semantic_err(call_expr.symbol, left.token)
				return
			}
			c.current = c.modules[call_expr.symbol.module_id]
			enter_class_scope(c.current, Token{text = call_expr.symbol.name}) or_return
			c.dot.symbol = call_expr.symbol
			c.dot.current_module = c.current.id
			c.dot.current_scope = c.current.scope

			dot_expr.left = call_expr
		}

		c.dot.previous = c.dot.symbol
		if c.dot.previous == nil {
			assert(false)
		}

		#partial switch selector in e.selector {
		case ^Parsed_Identifier_Expression:
			s := build_checked_expr(c, selector) or_return
			c.dot.symbol = checked_expr_symbol(s)
			#partial switch c.dot.symbol.kind {
			case .Var_Symbol:
				var_info := c.dot.symbol.info.(Var_Symbol_Info)
				dot_expr.symbol = var_info.symbol
				dot_expr.leaf_symbol = c.dot.symbol
				dot_expr.selector = s
				pop_dot_frame(c)
			case:
				err = dot_operand_semantic_err(c.dot.symbol, e.token)
				return
			}


		case ^Parsed_Index_Expression:
			index_expr := new_clone(
				Checked_Index_Expression{
					token = selector.token,
					left = build_checked_expr(c, selector.left) or_return,
				},
			)
			left_symbol := checked_expr_symbol(index_expr.left)
			if left_symbol.kind == .Var_Symbol {
				left_info := left_symbol.info.(Var_Symbol_Info)
				if left_info.symbol.kind != .Generic_Symbol {
					err = index_semantic_err(left_symbol, selector.token)
					return
				}
				index_expr.symbol = left_info.symbol.info.(Generic_Symbol_Info).symbols[0]
			} else {
				err = index_semantic_err(left_symbol, selector.token)
				return
			}

			restore_dot_frame_start(c)
			{
				c.allow_new_dot_chain = true
				defer c.allow_new_dot_chain = false
				// push_dot_frame(c)
				// f_count := c.dot_frame_count
				index_expr.index = build_checked_expr(c, selector.index) or_return
				switch left_symbol.type_id {
				case ARRAY_ID:
					index_expr.kind = .Array
					expect_type(c, index_expr.index, &c.builtin_symbols[NUMBER_SYMBOL]) or_return
				}
				// if c.dot_frame_count == f_count do pop_dot_frame(c)
			}
			dot_expr.symbol = index_expr.symbol
			dot_expr.leaf_symbol = left_symbol
			dot_expr.selector = index_expr
			pop_dot_frame(c)

		case ^Parsed_Call_Expression:
			call_expr := new_clone(
				Checked_Call_Expression{
					token = selector.token,
					args = make([]Checked_Expression, len(selector.args)),
				},
			)
			if c.dot.previous.kind == .Generic_Symbol {
				if c.dot.previous.type_id == ARRAY_ID {
					build_array_method_call(c, selector, call_expr) or_return
				}
			} else {
				call_expr.func = build_checked_expr(c, selector.func) or_return

				fn_symbol := checked_expr_symbol(call_expr.func)
				if fn_symbol.kind != .Fn_Symbol {
					err = call_semantic_err(fn_symbol, selector.token)
					return
				}
				fn_info := fn_symbol.info.(Fn_Symbol_Info)
				call_expr.symbol = fn_info.return_symbol

				restore_dot_frame_start(c)
				for arg, i in selector.args {
					c.allow_new_dot_chain = true
					defer c.allow_new_dot_chain = false
					call_expr.args[i] = build_checked_expr(c, arg) or_return
					expect_type(c, call_expr.args[i], fn_info.param_symbols[i]) or_return
				}
			}
			dot_expr.symbol = call_expr.symbol
			dot_expr.leaf_symbol = call_expr.symbol
			dot_expr.selector = call_expr
			pop_dot_frame(c)

		case ^Parsed_Dot_Expression:
			dot_expr.selector = build_checked_expr(c, selector) or_return
			inner := dot_expr.selector.(^Checked_Dot_Expression)
			dot_expr.symbol = inner.symbol
			dot_expr.leaf_symbol = inner.leaf_symbol
		}
		result = dot_expr

	case ^Parsed_Call_Expression:
		call_expr := new_clone(
			Checked_Call_Expression{token = e.token, args = make([]Checked_Expression, len(e.args))},
		)
		call_expr.func = build_checked_expr(c, e.func) or_return

		fn_symbol := checked_expr_symbol(call_expr.func)
		if fn_symbol.kind != .Fn_Symbol {
			err = call_semantic_err(fn_symbol, e.token)
			return
		}
		fn_info := fn_symbol.info.(Fn_Symbol_Info)
		call_expr.symbol = fn_info.return_symbol
		for arg, i in e.args {
			call_expr.args[i] = build_checked_expr(c, arg) or_return
			param_info := fn_info.param_symbols[i].info.(Var_Symbol_Info)
			expect_type(c, call_expr.args[i], param_info.symbol) or_return
		}
		result = call_expr

	case ^Parsed_Array_Type_Expression, ^Parsed_Map_Type_Expression:
		assert(false)
	}
	return
}

build_array_method_call :: proc(
	c: ^Checker,
	from: ^Parsed_Call_Expression,
	expr: ^Checked_Call_Expression,
) -> (
	err: Error,
) {
	if func, ok := from.func.(^Parsed_Identifier_Expression); ok {

		builtin_symbol := get_scoped_symbol(c.builtin_fn[ARRAY_SYMBOL], func.name) or_return
		builtin_info := builtin_symbol.info.(Fn_Symbol_Info)
		expr.func = new_clone(Checked_Identifier_Expression{token = func.name, symbol = builtin_symbol})
		expr.symbol = builtin_symbol
		if len(from.args) != len(builtin_info.param_symbols) {
			err = arity_semantic_err(builtin_symbol, func.name, len(from.args))
			return
		}

		restore_dot_frame_start(c)
		elem_symbol := c.dot.previous.info.(Generic_Symbol_Info).symbols[0]
		for arg, i in from.args {
			expr.args[i] = build_checked_expr(c, arg) or_return
			expect_type(c, expr.args[i], elem_symbol) or_return
		}
		restore_dot_frame_current(c)
		c.dot.symbol = nil
	} else {
		assert(false)
	}
	return
}

symbol_from_type_expr :: proc(
	c: ^Checker,
	expr: Parsed_Expression,
	loc := #caller_location,
) -> (
	result: ^Symbol,
	err: Error,
) {
	#partial switch e in expr {
	case ^Parsed_Identifier_Expression:
		result = get_symbol(c, e.name) or_return

	case ^Parsed_Array_Type_Expression:
		inner_symbol := symbol_from_type_expr(c, e.elem_type) or_return
		for symbol, i in c.array_symbols {
			elem_symbol := symbol.info.(Generic_Symbol_Info).symbols[0]
			if elem_symbol.name == inner_symbol.name {
				result = &c.array_symbols[i]
				return
			}
		}
		array_symbol := c.builtin_symbols[ARRAY_SYMBOL]
		array_info := Generic_Symbol_Info {
			symbols = make([]^Symbol, 1),
		}
		array_info.symbols[0] = inner_symbol
		array_symbol.info = array_info
		append(&c.array_symbols, array_symbol)
		result = &c.array_symbols[len(c.array_symbols) - 1]

	case ^Parsed_Map_Type_Expression:
		key_symbol := symbol_from_type_expr(c, e.key_type) or_return
		value_symbol := symbol_from_type_expr(c, e.value_type) or_return
		for symbol, i in c.map_symbols {
			ks := symbol.info.(Generic_Symbol_Info).symbols[0]
			vs := symbol.info.(Generic_Symbol_Info).symbols[1]
			if key_symbol.name == ks.name && value_symbol.name == vs.name {
				result = &c.map_symbols[i]
				return
			}
		}
		map_symbol := c.builtin_symbols[MAP_SYMBOL]
		map_info := Generic_Symbol_Info {
			symbols = make([]^Symbol, 2),
		}
		map_info.symbols[0] = key_symbol
		map_info.symbols[1] = value_symbol
		map_symbol.info = map_info
		append(&c.map_symbols, map_symbol)
		result = &c.map_symbols[len(c.map_symbols) - 1]

	case ^Parsed_Dot_Expression:
		left_symbol := symbol_from_type_expr(c, e.left) or_return
		if left_symbol.kind != .Module_Symbol {
			err = format_error(
				Semantic_Error{
					kind = .Invalid_Symbol,
					token = e.token,
					details = fmt.tprintf("Invalid Dot type expression: %s", left_symbol.name),
				},
			)
			return
		}
		module_info := left_symbol.info.(Module_Symbol_Info)
		module_root := c.modules[module_info.ref_mod_id].root
		if selector, ok := e.selector.(^Parsed_Identifier_Expression); ok {
			inner_symbol, inner_err := get_scoped_symbol(module_root, selector.name)
			if inner_err != nil {
				err = format_error(
					Semantic_Error{
						kind = .Unknown_Symbol,
						token = selector.name,
						details = fmt.tprintf("Unknown selector symbol: %s", selector.name.text),
					},
				)
				return
			}
			if !is_type_symbol(inner_symbol) {
				err = format_error(
					Semantic_Error{
						kind = .Invalid_Symbol,
						token = selector.name,
						details = fmt.tprintf(
							"Invalid Dot type expression: %s is not a Type",
							selector.name.text,
						),
					},
				)
			}
			result = inner_symbol

		} else {
			err = format_error(
				Semantic_Error{
					kind = .Invalid_Symbol,
					token = e.token,
					details = fmt.tprintf("Invalid Dot type expression: %s", left_symbol.name),
				},
			)
			return
		}

	case:
		expr_token := token_from_parsed_expression(e)
		err = format_error(
			Semantic_Error{
				kind = .Invalid_Symbol,
				token = expr_token,
				details = fmt.tprintf("%s is not a valid type expression", expr_token.text),
			},
			loc,
		)
	}
	return
}

check_dependency_graph :: proc(
	modules: []^Parsed_Module,
	lookup: map[string]int,
	e: string,
) -> (
	out: []int,
	err: Error,
) {

	Graph_Data :: struct {
		modules:   []^Parsed_Module,
		lookup:    map[string]int,
		white_set: map[string]int,
		gray_set:  map[string]int,
		output:    []int,
		count:     int,
		current:   ^Parsed_Module,
	}

	check_import_cycle :: proc(data: ^Graph_Data) -> (err: Error) {
		for node in data.current.import_nodes {
			import_node := node.(^Parsed_Import_Statement)
			import_name := import_node.identifier.text
			if id, is_white := data.white_set[import_name]; is_white {
				delete_key(&data.white_set, import_name)
				data.gray_set[import_name] = id
				// append(&data.edges, Graph_Edge{start = data.lookup[data.current.name], end = id})
				previous := data.current
				data.current = data.modules[id]
				check_import_cycle(data) or_return
				data.current = previous

			} else if _, is_gray := data.gray_set[import_name]; is_gray {
				err = format_error(
					Semantic_Error{
						kind = .Dependency_Cycle,
						token = import_node.token,
						details = fmt.tprintf(
							"Cycle detected: %s is a dependency of %s, but %s is also a dependency of %s",
							data.current.name,
							import_name,
							import_name,
							data.current.name,
						),
					},
				)
				return
			}
		}
		delete_key(&data.gray_set, data.current.name)
		data.output[data.count] = data.lookup[data.current.name]
		data.count += 1
		return
	}

	out = make([]int, len(modules))
	data := Graph_Data {
		modules   = modules,
		lookup    = lookup,
		white_set = make(map[string]int, len(modules), context.temp_allocator),
		gray_set  = make(map[string]int, len(modules), context.temp_allocator),
		output    = out,
		current   = modules[lookup[e]],
	}

	for name, id in lookup {
		if name == e {
			data.gray_set[name] = id
		} else {
			data.white_set[name] = id
		}
	}

	for {
		if len(data.white_set) == 0 do break
		check_import_cycle(&data) or_return
	}

	return
}

// Dot expression Rules
/*
	Type Dot expression:
	- module.Class
	- module.Type

	Left-handside Dot expression:
	- instance.field
	- instance.method()
	- instance.field[n]
	- instance, array[n], or function() + any combination of (n number if applicable):
		- .field
		- .field[n]
		- .method()
	- module. + all of the above

	Right-handside Dot expression:
	- Class.constructor() // NOTE: chaining after a constructor is disallowed for complexity reasons 
	- instance.field
	- instance.method()
	- instance.field[n]
	- instance, array[n], or function() + any combination of (n number if applicable):
		- .field
		- .field[n]
		- .method()
	- module. + all of the above
*/
