package lily

import "core:fmt"

Checker :: struct {
	import_names_lookup: map[string]int,
	modules:             []^Checked_Module,
	current:             ^Checked_Module,

	// A place to store the parsed modules and keep track of which one is currently being worked on
	parsed_results:      [dynamic]^Parsed_Module,
	current_parsed:      ^Parsed_Module,
	// Builtin types and internal states
	builtin_symbols:     [5]Symbol,
	types:               [dynamic]Type_ID,
	type_id_ptr:         Type_ID,
}

UNTYPED_SYMBOL :: 0
NUMBER_SYMBOL :: 1
BOOLEAN_SYMBOL :: 2
STRING_SYMBOL :: 3
ARRAY_SYMBOL :: 4

Type_ID :: distinct int

BUILT_IN_ID_COUNT :: ARRAY_ID + 1

UNTYPED_ID :: 0
NUMBER_ID :: 1
BOOL_ID :: 2
STRING_ID :: 3
ARRAY_ID :: 4

init_checker :: proc(c: ^Checker) {
	c.builtin_symbols = {
		Symbol{name = "untyped", kind = .Name, type_id = UNTYPED_ID, module_id = -1},
		Symbol{name = "number", kind = .Name, type_id = NUMBER_ID, module_id = -1},
		Symbol{name = "bool", kind = .Name, type_id = BOOL_ID, module_id = -1},
		Symbol{name = "string", kind = .Name, type_id = STRING_ID, module_id = -1},
		Symbol{name = "array", kind = .Name, module_id = -1, generic_info = {is_generic = true}},
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
}

free_checker :: proc(c: ^Checker) {
	delete(c.modules)
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

get_symbol :: proc(c: ^Checker, token: Token) -> (result: ^Symbol, err: Error) {
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
	err = Semantic_Error {
		kind    = .Unknown_Symbol,
		token   = token,
		details = fmt.tprintf("Unknown symbol: %s", token.text),
	}
	return
}

types_equal :: proc(c: ^Checker, s1, s2: ^Symbol) -> bool {
	return s1.type_id == s2.type_id
}

gen_type_id :: proc(c: ^Checker) -> Type_ID {
	c.type_id_ptr += 1
	return c.type_id_ptr - 1
}


build_checked_program :: proc(c: ^Checker, module_name: string, entry_point: string) -> (
	result: Checked_Output,
	err: Error,
) {
	c.import_names_lookup = make(map[string]int)
	entry_module := make_parsed_module(module_name)
	parse_module(entry_point, entry_module) or_return
	append(&c.parsed_results, entry_module)
	c.import_names_lookup[entry_module.name] = 0
	c.current_parsed = entry_module

	parse_dependencies(&c.parsed_results, &c.import_names_lookup, c.current_parsed) or_return
	c.modules = make([]^Checked_Module, len(c.parsed_results))

	// Build all the symbols and then check them
	for module, i in c.parsed_results {
		index := c.import_names_lookup[module.name]
		c.modules[index] = make_checked_module(module.name, i)
		add_module_import_symbols(c, index) or_return
		add_module_decl_symbols(c, index) or_return
		add_module_type_decl(c, index) or_return
	}
	for module in c.parsed_results {
		index := c.import_names_lookup[module.name]
		check_module_signatures_symbols(c, index) or_return
	}
	for module in c.parsed_results {
		index := c.import_names_lookup[module.name]
		check_module_inner_symbols(c, index) or_return
	}
	for module in c.parsed_results {
		index := c.import_names_lookup[module.name]
		build_checked_ast(c, index) or_return
	}

	result = Checked_Output {
		import_names = c.import_names_lookup,
		modules      = c.modules,
	}
	return
}

add_module_import_symbols :: proc(c: ^Checker, module_id: int) -> (err: Error) {
	c.current = c.modules[module_id]
	c.current_parsed = c.parsed_results[module_id]

	for import_node in c.current_parsed.import_nodes {
		import_stmt := import_node.(^Parsed_Import_Statement)
		import_index := c.import_names_lookup[import_stmt.identifier.text]
		add_symbol_to_scope(
			c.current.root,
			Symbol{
				name = import_stmt.identifier.text,
				kind = .Module_Symbol,
				module_id = module_id,
				scope_id = c.current.root.id,
				module_info = {ref_module_id = import_index},
			},
		) or_return
	}
	return
}

add_module_decl_symbols :: proc(c: ^Checker, module_id: int) -> (err: Error) {
	c.current = c.modules[module_id]
	c.current_parsed = c.parsed_results[module_id]
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
			case .Class:
				push_class_scope(c.current, n.identifier) or_return
				defer pop_scope(c.current)
				for field in n.fields {
					add_symbol_to_scope(
						c.current.scope,
						Symbol{
							name = field.name.text,
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
							fn_info = {scope_id = constr_scope_id, has_return = true},
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
							fn_info = {scope_id = method_scope_id},
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
					fn_info = {scope_id = fn_scope_id},
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
				},
			) or_return
		}
	}
	return
}

check_module_signatures_symbols :: proc(c: ^Checker, module_id: int) -> (err: Error) {
	c.current = c.modules[module_id]
	c.current_parsed = c.parsed_results[module_id]

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
			type_symbol := symbol_from_type_expr(c, field.type_expr) or_return
			field_symbol, _ := get_scoped_symbol(c.current.scope, field.name)
			field_symbol.var_info.symbol = type_symbol
			field_symbol.type_id = type_symbol.type_id
			if type_symbol.kind == .Class_Symbol {
				field_symbol.var_info.is_ref = true
			}
		}

		for constructor in n.constructors {
			check_fn_signature_symbols(c, constructor, true) or_return
		}

		for method in n.methods {
			check_fn_signature_symbols(c, method, false) or_return
		}
	}


	// functions
	for node in c.current_parsed.functions {
		n := node.(^Parsed_Fn_Declaration)
		check_fn_signature_symbols(c, n, false) or_return
	}
	return
}

check_fn_signature_symbols :: proc(c: ^Checker, fn_decl: ^Parsed_Fn_Declaration, constr: bool) -> (
	err: Error,
) {
	fn_symbol, _ := get_scoped_symbol(c.current.scope, fn_decl.identifier)
	if fn_decl.return_type_expr != nil {
		fn_symbol.fn_info.return_symbol = symbol_from_type_expr(c, fn_decl.return_type_expr) or_return
		fn_symbol.fn_info.has_return = true
		fn_symbol.fn_info.constructor = constr
	}

	enter_child_scope_by_id(c.current, fn_symbol.fn_info.scope_id) or_return
	{
		if !constr && fn_symbol.fn_info.has_return {
			add_symbol_to_scope(
				c.current.scope,
				Symbol{
					name = "result",
					kind = .Var_Symbol,
					type_id = fn_symbol.fn_info.return_symbol.type_id,
					module_id = c.current.id,
					scope_id = c.current.scope.id,
					var_info = {
						symbol = fn_symbol.fn_info.return_symbol,
						is_ref = is_ref_symbol(fn_symbol.fn_info.return_symbol),
						immutable = false,
					},
				},
				true,
			) or_return
		}
		for param in fn_decl.parameters {
			type_symbol := symbol_from_type_expr(c, param.type_expr) or_return
			param_symbol := Symbol {
				name = param.name.text,
				kind = .Var_Symbol,
				type_id = type_symbol.type_id,
				module_id = c.current.id,
				scope_id = c.current.scope.id,
				var_info = {symbol = type_symbol, is_ref = type_symbol.kind == .Class_Symbol, immutable = true},
			}
			add_symbol_to_scope(c.current.scope, param_symbol, true) or_return
		}
	}
	pop_scope(c.current)
	return
}

check_module_inner_symbols :: proc(c: ^Checker, module_id: int) -> (err: Error) {
	c.current = c.modules[module_id]
	c.current_parsed = c.parsed_results[module_id]

	for node in c.current_parsed.types {
		check_node_symbols(c, node) or_return
	}

	for node in c.current_parsed.functions {
		check_node_symbols(c, node) or_return
	}
	for node in c.current_parsed.variables {
		check_node_symbols(c, node) or_return
	}
	for node in c.current_parsed.nodes {
		check_node_symbols(c, node) or_return
	}
	return
}

check_node_symbols :: proc(c: ^Checker, node: Parsed_Node) -> (err: Error) {
	switch n in node {
	case ^Parsed_Expression_Statement:
		check_expr_symbols(c, n.expr) or_return

	case ^Parsed_Block_Statement:
		for block_node in n.nodes {
			check_node_symbols(c, block_node) or_return
		}

	case ^Parsed_Assignment_Statement:
		left_symbol := symbol_from_expr(c, n.left) or_return
		right_symbol := symbol_from_expr(c, n.right) or_return

		if left_symbol.kind != .Var_Symbol {
			err = Semantic_Error {
				kind    = .Invalid_Symbol,
				token   = n.token,
				details = fmt.tprintf("Cannot assign to %s", left_symbol.name),
			}
			return
		}
		if right_symbol.kind == .Class_Symbol ||
		   right_symbol.kind == .Module_Symbol ||
		   right_symbol.kind == .Alias_Symbol {
			err = Semantic_Error {
				kind    = .Invalid_Symbol,
				token   = n.token,
				details = fmt.tprintf("%s is not a value symbol", right_symbol.name),
			}
			return
		}
		if !types_equal(c, left_symbol, right_symbol) {
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = n.token,
				details = fmt.tprintf(
					"Cannot assign %s to variable %s of type %s",
					right_symbol.name,
					left_symbol.name,
					left_symbol.var_info.symbol.name,
				),
			}
			return
		}

	case ^Parsed_If_Statement:
		check_expr_symbols(c, n.condition) or_return
		push_scope(c.current, n.token)
		check_node_symbols(c, n.body) or_return
		pop_scope(c.current)
		if n.next_branch != nil {
			check_node_symbols(c, n.next_branch) or_return
		}

	case ^Parsed_Range_Statement:
		check_expr_symbols(c, n.low) or_return
		check_expr_symbols(c, n.high) or_return
		push_scope(c.current, n.token)
		defer pop_scope(c.current)

		add_symbol_to_scope(
			c.current.scope,
			Symbol{
				name = n.iterator_name.text,
				kind = .Var_Symbol,
				module_id = c.current.id,
				scope_id = c.current.scope.id,
				var_info = {symbol = &c.builtin_symbols[NUMBER_SYMBOL], is_ref = false, immutable = true},
			},
			true,
		) or_return
		check_node_symbols(c, n.body) or_return

	case ^Parsed_Import_Statement:

	case ^Parsed_Var_Declaration:
		type_symbol := symbol_from_type_expr(c, n.type_expr) or_return
		if type_symbol.name == "untyped" {
			type_symbol = symbol_from_expr(c, n.expr) or_return
		} else {
			expr_symbol := symbol_from_expr(c, n.expr) or_return
			if !types_equal(c, type_symbol, expr_symbol) {
				type_symbol = expr_symbol
			} else {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = n.identifier,
					details = fmt.tprintf(
						"Cannot assign %s to variable %s of type %s",
						expr_symbol.name,
						n.identifier.text,
						type_symbol.name,
					),
				}
				return
			}
		}

		#partial switch type_symbol.kind {
		case .Module_Symbol:
			err = Semantic_Error {
				kind    = .Invalid_Symbol,
				token   = n.token,
				details = fmt.tprintf("%s is not a value symbol", type_symbol.name),
			}
			return

		case .Var_Symbol:
			type_symbol = type_symbol.var_info.symbol
		}

		var_symbol: ^Symbol
		if c.current.scope_depth > 0 {
					//odinfmt: disable
			var_symbol = add_symbol_to_scope(
					c.current.scope,
					Symbol{
						name = n.identifier.text,
						kind = .Var_Symbol,
						module_id = c.current.id,
						scope_id = c.current.scope.id,
						var_info = {immutable = false},
					},
			) or_return
			//odinfmt: enable
		} else {
			var_symbol = get_scoped_var_symbol(c.current.root, n.identifier) or_return
		}
		var_symbol.type_id = type_symbol.type_id
		var_symbol.var_info.symbol = type_symbol
		var_symbol.var_info.is_ref = type_symbol.kind == .Class_Symbol

	case ^Parsed_Fn_Declaration:
		fn_symbol := get_scoped_symbol(c.current.scope, n.identifier) or_return
		enter_child_scope_by_id(c.current, fn_symbol.fn_info.scope_id) or_return
		{
			check_node_symbols(c, n.body) or_return
		}
		pop_scope(c.current)


	case ^Parsed_Type_Declaration:
		if n.type_kind == .Alias {
			alias_symbol := get_scoped_symbol(c.current.root, n.identifier) or_return
			alias_symbol.alias_info.symbol = symbol_from_type_expr(c, n.type_expr) or_return
		} else {
			enter_class_scope(c.current, n.identifier) or_return
			defer pop_scope(c.current)
			for field in n.fields {
				check_expr_symbols(c, field.type_expr) or_return
			}
			for constructor in n.constructors {
				// FIXME: Probably need to inline the symbol checking to prevent
				// "result" symbol to be added
				check_node_symbols(c, constructor) or_return
			}
			for method in n.methods {
				check_node_symbols(c, method) or_return
			}
		}
	}
	return
}

check_expr_symbols :: proc(c: ^Checker, expr: Parsed_Expression) -> (err: Error) {
	switch e in expr {
	case ^Parsed_Literal_Expression:

	case ^Parsed_String_Literal_Expression:

	case ^Parsed_Array_Literal_Expression:
		// Check that the array specialization is of a known type
		check_expr_symbols(c, e.type_expr) or_return
		// Check all the inlined elements of the array
		for value in e.values {
			check_expr_symbols(c, value) or_return
		}

	case ^Parsed_Unary_Expression:
		check_expr_symbols(c, e.expr) or_return

	case ^Parsed_Binary_Expression:
		check_expr_symbols(c, e.left) or_return
		check_expr_symbols(c, e.right) or_return

	case ^Parsed_Identifier_Expression:
		get_symbol(c, e.name) or_return

	case ^Parsed_Index_Expression:
		check_expr_symbols(c, e.left) or_return
		check_expr_symbols(c, e.index) or_return

	case ^Parsed_Dot_Expression:
		symbol_from_dot_expr(c, e) or_return

	case ^Parsed_Call_Expression:
		check_expr_symbols(c, e.func) or_return
		for arg in e.args {
			check_expr_symbols(c, arg) or_return
		}

	case ^Parsed_Array_Type_Expression:
		check_expr_symbols(c, e.elem_type) or_return

	}
	return
}

symbol_from_expr :: proc(c: ^Checker, expr: Parsed_Expression) -> (result: ^Symbol, err: Error) {
	switch e in expr {
	case ^Parsed_Literal_Expression:
		#partial switch e.value.kind {
		case .Number:
			result = &c.builtin_symbols[NUMBER_SYMBOL]
		case .Boolean:
			result = &c.builtin_symbols[BOOLEAN_SYMBOL]
		}

	case ^Parsed_String_Literal_Expression:
		result = &c.builtin_symbols[STRING_SYMBOL]

	case ^Parsed_Array_Literal_Expression:
		result, err = symbol_from_type_expr(c, e.type_expr)

	case ^Parsed_Unary_Expression:
		result, err = symbol_from_expr(c, e.expr)

	case ^Parsed_Binary_Expression:
		left_symbol := symbol_from_expr(c, e.left) or_return
		right_symbol := symbol_from_expr(c, e.right) or_return

		if types_equal(c, left_symbol, right_symbol) {
			result = left_symbol
		} else {
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = e.token,
				details = "Cannot perform binary operation on different types",
			}
		}

	case ^Parsed_Identifier_Expression:
		result, err = get_symbol(c, e.name)
		if result.kind == .Class_Symbol {
			err = Semantic_Error {
				kind    = .Invalid_Symbol,
				token   = e.name,
				details = fmt.tprintf("%s is a class and not a value", result.name),
			}
		}

	case ^Parsed_Index_Expression:
		left_symbol := symbol_from_expr(c, e.left) or_return
		if left_symbol.kind != .Var_Symbol {
			err = Semantic_Error {
				kind    = .Invalid_Symbol,
				token   = e.token,
				details = fmt.tprintf("Cannot index symbol %s", left_symbol.name),
			}
			return
		}
		inner_symbol := left_symbol.var_info.symbol
		if inner_symbol.kind == .Name || inner_symbol.generic_info.is_generic {
			err = Semantic_Error {
				kind    = .Invalid_Symbol,
				token   = e.token,
				details = fmt.tprintf("Cannot index symbol %s", left_symbol.name),
			}
			return
		}
		result = inner_symbol.generic_info.symbol

	case ^Parsed_Dot_Expression:
		result = symbol_from_dot_expr(c, e) or_return

	case ^Parsed_Call_Expression:
		identifier := e.func.(^Parsed_Identifier_Expression)
		fn_symbol := get_symbol(c, identifier.name) or_return
		result = fn_symbol.fn_info.return_symbol

	case ^Parsed_Array_Type_Expression:
		assert(false)
	}
	return
}

symbol_from_type_expr :: proc(c: ^Checker, expr: Parsed_Expression) -> (result: ^Symbol, err: Error) {
	#partial switch e in expr {
	case ^Parsed_Identifier_Expression:
		result = get_symbol(c, e.name) or_return

	case ^Parsed_Array_Type_Expression:
		inner_symbol := symbol_from_type_expr(c, e.elem_type) or_return
		for symbol, i in c.current.scope.symbols {
			if symbol.name == "array" {
				if symbol.generic_info.symbol.name == inner_symbol.name {
					result = &c.current.scope.symbols[i]
					return
				}
			}
		}
		array_symbol := c.builtin_symbols[ARRAY_SYMBOL]
		array_symbol.generic_info.symbol = inner_symbol
		result, err = add_symbol_to_scope(c.current.scope, array_symbol)

	case ^Parsed_Dot_Expression:
		left_symbol := symbol_from_type_expr(c, e.left) or_return
		if left_symbol.kind != .Module_Symbol {
			err = Semantic_Error {
				kind    = .Invalid_Symbol,
				token   = e.token,
				details = fmt.tprintf("Invalid Dot type expression: %s", left_symbol.name),
			}
			return
		}
		module_root := c.modules[left_symbol.module_info.ref_module_id].root
		if selector, ok := e.selector.(^Parsed_Identifier_Expression); ok {
			inner_symbol, inner_err := get_scoped_symbol(module_root, selector.name)
			if inner_err != nil {
				err = Semantic_Error {
					kind    = .Unknown_Symbol,
					token   = selector.name,
					details = fmt.tprintf("Unknown selector symbol: %s", selector.name.text),
				}
				return
			}
			if !is_type_symbol(inner_symbol) {
				err = Semantic_Error {
					kind    = .Invalid_Symbol,
					token   = selector.name,
					details = fmt.tprintf("Invalid Dot type expression: %s is not a Type", selector.name.text),
				}
			}
			result = inner_symbol

		} else {
			err = Semantic_Error {
				kind    = .Invalid_Symbol,
				token   = e.token,
				details = fmt.tprintf("Invalid Dot type expression: %s", left_symbol.name),
			}
			return
		}

	case:
		expr_token := token_from_parsed_expression(e)
		err = Semantic_Error {
			kind    = .Invalid_Symbol,
			token   = expr_token,
			details = fmt.tprintf("%s is not a valid type expression", expr_token.text),
		}
	}
	return
}

symbol_from_dot_expr :: proc(c: ^Checker, expr: Parsed_Expression) -> (result: ^Symbol, err: Error) {
	// The goal here is to get the ending symbol of the (chained) dot expr
	symbol_from_dot_operand :: proc(c: ^Checker, expr: Parsed_Expression, scope: ^Semantic_Scope) -> (
		symbol: ^Symbol,
		err: Error,
	) {
		#partial switch e in expr {
		case ^Parsed_Identifier_Expression:
			if scope != nil {
				exist: bool
				symbol = get_scoped_symbol(scope, e.name) or_return
			} else {
				symbol = get_symbol(c, e.name) or_return
			}
		case ^Parsed_Call_Expression:
			identifier := e.func.(^Parsed_Identifier_Expression)
			// FIXME: doesn't account for function literals
			fn_symbol: ^Symbol
			if scope != nil {
				fn_symbol = get_scoped_symbol(scope, identifier.name) or_return
			} else {
				fn_symbol = get_symbol(c, identifier.name) or_return
			}
			symbol = fn_symbol.fn_info.return_symbol
		case:
			expr_token := token_from_parsed_expression(expr)
			err = Semantic_Error {
				kind    = .Invalid_Dot_Operand,
				token   = expr_token,
				details = fmt.tprintf("Invalid left dot operand: %s", expr_token.text),
			}
		}
		return
	}
	dot_expr := expr.(^Parsed_Dot_Expression)
	left_symbol := symbol_from_dot_operand(c, dot_expr.left, nil) or_return
	left_scope := scope_from_dot_operand_symbol(c, left_symbol, dot_expr.token) or_return

	chain: for {
		#partial switch selector in dot_expr.selector {
		case ^Parsed_Identifier_Expression:
			// FIXME: only valid outcome is Var_Symbol
			result = get_scoped_symbol(left_scope, selector.name) or_return
			err = check_dot_expr_rules(dot_expr.token, left_symbol, result, true)
			break chain
		case ^Parsed_Call_Expression:
			if identifier, ok := selector.func.(^Parsed_Identifier_Expression); ok {
				fn_symbol := get_scoped_symbol(left_scope, identifier.name) or_return
				check_dot_expr_rules(dot_expr.token, left_symbol, fn_symbol, true) or_return
				result = fn_symbol.fn_info.return_symbol
			} else {
				err = Semantic_Error {
					kind    = .Invalid_Dot_Operand,
					token   = dot_expr.token,
					details = "Function literal are not a valid dot operand",
				}
				return
			}
			break chain
		case ^Parsed_Dot_Expression:
			dot_expr = selector
			selector_symbol := symbol_from_dot_operand(c, dot_expr.left, left_scope) or_return
			check_dot_expr_rules(dot_expr.token, left_symbol, selector_symbol, false) or_return
			left_symbol = selector_symbol
			left_scope = scope_from_dot_operand_symbol(c, left_symbol, dot_expr.token) or_return
		}
	}
	return
}

scope_from_dot_operand_symbol :: proc(c: ^Checker, symbol: ^Symbol, token: Token) -> (
	result: ^Semantic_Scope,
	err: Error,
) {
	#partial switch symbol.kind {
	case .Alias_Symbol:
		if symbol.alias_info.symbol.kind != .Class_Symbol {
			err = Semantic_Error {
				kind    = .Invalid_Dot_Operand,
				token   = token,
				details = fmt.tprintf(
					"Invalid Dot Expression operand: Type alias %s does not refer to an addressable type",
					symbol.name,
				),
			}
			return
		}
		result = scope_from_dot_operand_symbol(c, symbol.alias_info.symbol, token) or_return

	case .Class_Symbol:
		class_module := c.modules[symbol.module_id]
		if info, exist := class_module.root.class_lookup[symbol.name]; exist {
			result = class_module.root.children[info.scope_index]
		} else {
			assert(false)
		}

	case .Module_Symbol:
		result = c.modules[symbol.module_info.ref_module_id].root

	case .Fn_Symbol:
		// get the return symbol and check if ref
		if !symbol.fn_info.has_return {
			err = Semantic_Error {
				kind    = .Invalid_Dot_Operand,
				token   = token,
				details = fmt.tprintf(
					"Invalid Dot Expression operand: function %s does not return an addressable symbol",
					symbol.name,
				),
			}
			return
		}
		return_symbol := symbol.fn_info.return_symbol
		if return_symbol.kind != .Class_Symbol {
			err = Semantic_Error {
				kind    = .Invalid_Dot_Operand,
				token   = token,
				details = fmt.tprintf(
					"Invalid Dot Expression operand: function %s does not return an addressable symbol",
					symbol.name,
				),
			}
			return
		}

		result = scope_from_dot_operand_symbol(c, return_symbol, token) or_return

	case .Var_Symbol:
		// get the var symbol and check if ref
		if !is_ref_symbol(symbol.var_info.symbol) {
			err = Semantic_Error {
				kind    = .Invalid_Dot_Operand,
				token   = token,
				details = fmt.tprintf("Invalid Dot Expression operand: %s is not addressable", symbol.name),
			}
			return
		}
		result = scope_from_dot_operand_symbol(c, symbol.var_info.symbol, token) or_return

	case:
		err = Semantic_Error {
			kind    = .Invalid_Dot_Operand,
			token   = token,
			details = fmt.tprintf(
				"Invalid Dot Expression operand: %s does not refer to an addressable symbol",
				symbol.name,
			),
		}
	}

	return
}

check_dot_expr_rules :: proc(token: Token, left, selector: ^Symbol, is_leaf: bool) -> (err: Error) {
	invalid_left := Semantic_Error {
		kind    = .Invalid_Dot_Operand,
		token   = token,
		details = fmt.tprintf("%s is not a valid dot operand", left.name),
	}
	invalid_selector := Semantic_Error {
		kind    = .Invalid_Dot_Operand,
		token   = token,
		details = fmt.tprintf("%s is not a valid selector", selector.name),
	}
	if is_leaf && selector.kind == .Class_Symbol {
		err = Semantic_Error {
			kind    = .Invalid_Dot_Operand,
			token   = token,
			details = fmt.tprintf("%s is a class and not a value", selector.name),
		}
	}

	#partial switch left.kind {
	case .Alias_Symbol:
		err = check_dot_expr_rules(token, left.alias_info.symbol, selector, is_leaf)
	case .Class_Symbol:
		#partial switch selector.kind {
		case .Fn_Symbol:
			if !selector.fn_info.constructor {
				err = Semantic_Error {
					kind    = .Invalid_Dot_Operand,
					token   = token,
					details = fmt.tprintf("Cannot call method %s. %s is a class", selector.name, left.name),
				}
			}
		case .Var_Symbol:
			err = Semantic_Error {
				kind    = .Invalid_Dot_Operand,
				token   = token,
				details = fmt.tprintf("Cannot access fields %s. %s is a class", selector.name, left.name),
			}
		case:
			err = invalid_selector
		}
	case .Fn_Symbol:
		err = check_dot_expr_rules(token, left.fn_info.return_symbol, selector, is_leaf)
	case .Module_Symbol:
		if selector.kind == .Module_Symbol {
			err = Semantic_Error {
				kind    = .Invalid_Dot_Operand,
				token   = token,
				details = "Cannot access a module symbol from another module symbol",
			}
		}
	case .Var_Symbol:
		#partial switch selector.kind {
		case .Fn_Symbol:
			if selector.fn_info.constructor {
				err = Semantic_Error {
					kind    = .Invalid_Dot_Operand,
					token   = token,
					details = fmt.tprintf("Cannot call constructor %s. %s is an instance", selector.name, left.name),
				}
			}
		case .Var_Symbol:
		case:
			err = invalid_selector
		}

	case:
		err = invalid_left
	}
	return
}

add_module_type_decl :: proc(c: ^Checker, module_id: int) -> (err: Error) {
	c.current = c.modules[module_id]
	c.current_parsed = c.parsed_results[module_id]

	for node in c.current_parsed.types {
		#partial switch n in node {
		case ^Parsed_Type_Declaration:
			switch n.type_kind {
			case .Alias:
				// add_type_alias(c, n.identifier, UNTYPED_ID)
				assert(false)
			case .Class:
				add_module_class_type(c, n)
			}
		}
	}
	return
}

add_module_class_type :: proc(c: ^Checker, decl: ^Parsed_Type_Declaration) -> (err: Error) {
	append(&c.types, c.type_id_ptr)
	class_symbol := get_scoped_class_symbol(c.current.root, decl.identifier) or_return
	class_symbol.type_id = c.type_id_ptr
	c.type_id_ptr += 1

	enter_class_scope(c.current, decl.identifier)
	defer pop_scope(c.current)
	self_symbol := get_scoped_symbol(c.current.scope, Token{text = "self"}) or_return
	self_symbol.type_id = class_symbol.type_id
	return
}

build_checked_ast :: proc(c: ^Checker, module_id: int) -> (err: Error) {
	c.current = c.modules[module_id]
	c.current_parsed = c.parsed_results[module_id]

	for node in c.current_parsed.types {
		class_node := build_checked_node(c, node) or_return
		append(&c.current.classes, class_node)
	}

	for node in c.current_parsed.functions {
		fn_node := build_checked_node(c, node) or_return
		append(&c.current.functions, fn_node)
	}
	for node in c.current_parsed.variables {
		var_node := build_checked_node(c, node) or_return
		append(&c.current.variables, var_node)
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
		block_stmt := new_clone(Checked_Block_Statement{nodes = make([]Checked_Node, len(n.nodes))})
		for inner_node, i in n.nodes {
			checked_node := build_checked_node(c, inner_node) or_return
			block_stmt.nodes[i] = checked_node
		}
		result = block_stmt

	case ^Parsed_Assignment_Statement:
		assign_stmt := new_clone(Checked_Assigment_Statement{token = n.token})
		assign_stmt.left = build_checked_expr(c, n.left) or_return
		assign_stmt.right = build_checked_expr(c, n.right) or_return
		result = assign_stmt

	case ^Parsed_If_Statement:
		if_stmt := new_clone(Checked_If_Statement{token = n.token})
		if_stmt.condition = build_checked_expr(c, n.condition) or_return
		if_stmt.body = build_checked_node(c, n.body) or_return
		if n.next_branch != nil {
			if_stmt.next_branch = build_checked_node(c, n.next_branch) or_return
		}
		result = if_stmt

	case ^Parsed_Range_Statement:
		range_stmt := new_clone(Checked_Range_Statement{token = n.token})
		enter_child_scope_by_name(c.current, n.token)
		defer pop_scope(c.current)
		range_stmt.iterator = get_scoped_symbol(c.current.scope, n.iterator_name) or_return
		range_stmt.low = build_checked_expr(c, n.low) or_return
		range_stmt.high = build_checked_expr(c, n.high) or_return
		range_stmt.op = n.op
		range_stmt.body = build_checked_node(c, n.body) or_return
		result = range_stmt

	case ^Parsed_Import_Statement:

	case ^Parsed_Var_Declaration:
		var_decl := new_clone(Checked_Var_Declaration{token = n.token})
		var_decl.identifier = get_symbol(c, n.identifier) or_return
		var_decl.expr = build_checked_expr(c, n.expr) or_return
		result = var_decl

	case ^Parsed_Fn_Declaration:
		fn_decl :=
			new_clone(Checked_Fn_Declaration{token = n.token, params = make([]^Symbol, len(n.parameters))})
		fn_decl.identifier = get_symbol(c, n.identifier) or_return
		enter_child_scope_by_id(c.current, fn_decl.identifier.fn_info.scope_id) or_return
		defer pop_scope(c.current)

		for param, i in n.parameters {
			fn_decl.params[i] = get_symbol(c, param.name) or_return
		}
		fn_decl.body = build_checked_node(c, n.body) or_return
		result = fn_decl


	case ^Parsed_Type_Declaration:
		switch n.type_kind {
		case .Alias:
			assert(false)
		case .Class:
			class_decl :=
				new_clone(
					Checked_Class_Declaration{
						token = n.token,
						is_token = n.is_token,
						fields = make([]^Symbol, len(n.fields)),
						constructors = make([]^Checked_Fn_Declaration, len(n.constructors)),
						methods = make([]^Checked_Fn_Declaration, len(n.methods)),
					},
				)
			class_decl.identifier = get_scoped_class_symbol(c.current.root, n.identifier) or_return
			enter_class_scope(c.current, n.identifier) or_return
			defer pop_scope(c.current)

			for field, i in n.fields {
				class_decl.fields[i] = get_symbol(c, field.name) or_return
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

build_checked_expr :: proc(c: ^Checker, expr: Parsed_Expression) -> (
	result: Checked_Expression,
	err: Error,
) {
	switch e in expr {
	case ^Parsed_Literal_Expression:
		result = new_clone(Checked_Literal_Expression{token = e.token, value = e.value})

	case ^Parsed_String_Literal_Expression:
		result = new_clone(Checked_String_Literal_Expression{token = e.token, value = e.value})

	case ^Parsed_Array_Literal_Expression:
		array_lit :=
			new_clone(
				Checked_Array_Literal_Expression{
					token = e.token,
					values = make([]Checked_Expression, len(e.values)),
				},
			)
		for value, i in e.values {
			array_lit.values[i] = build_checked_expr(c, value) or_return
		}
		result = array_lit

	case ^Parsed_Unary_Expression:
		unary_expr := new_clone(Checked_Unary_Expression{token = e.token, op = e.op})
		unary_expr.expr = build_checked_expr(c, e.expr) or_return
		result = unary_expr

	case ^Parsed_Binary_Expression:
		binary_expr := new_clone(Checked_Binary_Expression{token = e.token, op = e.op})
		binary_expr.left = build_checked_expr(c, e.left) or_return
		binary_expr.right = build_checked_expr(c, e.right) or_return
		result = binary_expr

	case ^Parsed_Identifier_Expression:
		identifier_expr := new_clone(Checked_Identifier_Expression{token = e.name})
		identifier_expr.symbol = get_symbol(c, e.name) or_return
		result = identifier_expr

	case ^Parsed_Index_Expression:
		index_expr := new_clone(Checked_Index_Expression{token = e.token})
		index_expr.left = build_checked_expr(c, e.left) or_return
		left_symbol := symbol_from_expr(c, e.left) or_return
		switch left_symbol.type_id {
		case ARRAY_ID:
			index_expr.kind = .Array
		// case MAP_ID:
		}
		result = index_expr

	case ^Parsed_Dot_Expression:
		dot_expr := new_clone(Checked_Dot_Expression{token = e.token})
		dot_expr.left = build_checked_expr(c, e.left) or_return
		left_symbol := checked_expr_symbol(dot_expr.left)

		previous_module := c.current.id
		previous_scope := c.current.scope
		#partial switch left_symbol.kind {
		case .Alias_Symbol:
			assert(false)
		case .Class_Symbol:
			enter_class_scope(c.current, Token{text = left_symbol.name}) or_return
		case .Fn_Symbol:
			return_symbol := left_symbol.fn_info.return_symbol
			c.current = c.modules[return_symbol.module_id]
			enter_child_scope_by_id(c.current, return_symbol.scope_id) or_return
		case .Var_Symbol:
			var_symbol := left_symbol.var_info.symbol
			c.current = c.modules[var_symbol.module_id]
			enter_class_scope(c.current, Token{text = var_symbol.name}) or_return

		case .Module_Symbol:
		// c.current = c.modules[left_symbol.module_info.ref_module_id]

		case:
			assert(false)
		}
		dot_expr.selector = build_checked_expr(c, e.selector) or_return

		c.current = c.modules[previous_module]
		c.current.scope = previous_scope
		result = dot_expr

	case ^Parsed_Call_Expression:
		call_expr :=
			new_clone(Checked_Call_Expression{token = e.token, args = make([]Checked_Expression, len(e.args))})
		call_expr.func = build_checked_expr(c, e.func) or_return

		for arg, i in e.args {
			call_expr.args[i] = build_checked_expr(c, arg) or_return
		}
		result = call_expr

	case ^Parsed_Array_Type_Expression:
		assert(false)
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
