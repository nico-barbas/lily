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
	builtin_types:       [BUILT_IN_ID_COUNT]Type_Info,
	type_id_ptr:         Type_ID,
}

UNTYPED_SYMBOL :: 0
NUMBER_SYMBOL :: 1
BOOLEAN_SYMBOL :: 2
STRING_SYMBOL :: 3
ARRAY_SYMBOL :: 4

init_checker :: proc(c: ^Checker) {
	c.builtin_symbols = {
		Symbol{name = "untyped", kind = .Name, type_info = UNTYPED_INFO, module_id = -1},
		Symbol{name = "number", kind = .Name, type_info = NUMBER_INFO, module_id = -1},
		Symbol{name = "bool", kind = .Name, type_info = BOOL_INFO, module_id = -1},
		Symbol{name = "string", kind = .Name, type_info = STRING_INFO, module_id = -1},
		Symbol{
			name = "array",
			kind = .Name,
			type_info = ARRAY_INFO,
			module_id = -1,
			generic_info = {is_generic = true},
		},
	}
	c.type_id_ptr = BUILT_IN_ID_COUNT
	c.builtin_types[UNTYPED_ID] = UNTYPED_INFO
	c.builtin_types[UNTYPED_NUMBER_ID] = UNTYPED_NUMBER_INFO
	c.builtin_types[UNTYPED_BOOL_ID] = UNTYPED_BOOL_INFO
	c.builtin_types[UNTYPED_STRING_ID] = STRING_INFO
	c.builtin_types[NUMBER_ID] = NUMBER_INFO
	c.builtin_types[BOOL_ID] = BOOL_INFO
	c.builtin_types[STRING_ID] = STRING_INFO
	c.builtin_types[FN_ID] = FN_INFO
	c.builtin_types[ARRAY_ID] = ARRAY_INFO
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

// add_type_alias :: proc(c: ^Checker, name: Token, parent_type: Type_ID) {
// 	c.current.type_lookup[name.text] = Type_Info {
// 		name = name.text,
// 		type_id = gen_type_id(c),
// 		type_kind = .Type_Alias,
// 		type_id_data = Type_Alias_Info{underlying_type_id = parent_type},
// 	}
// 	c.current.type_count += 1
// }

// update_type_alias :: proc(c: ^Checker, name: Token, parent_type: Type_ID) {
// 	t := c.current.type_lookup[name.text]
// 	t.type_id_data = Type_Alias_Info {
// 		underlying_type_id = parent_type,
// 	}
// 	c.current.type_lookup[name.text] = t
// }


// add_class_type :: proc(c: ^Checker, decl: ^Parsed_Type_Declaration) {
// 	checked_class := new_clone(
// 		Checked_Class_Declaration{token = decl.token, is_token = decl.is_token, identifier = decl.identifier},
// 	)
// 	append(&c.current.classes, checked_class)
// 	class_info := Type_Info {
// 		name      = decl.identifier.text,
// 		type_id   = gen_type_id(c),
// 		type_kind = .Class_Type,
// 	}
// 	c.current.type_lookup[decl.identifier.text] = class_info
// 	updated_lookup := c.current.class_lookup[decl.identifier.text]
// 	updated_lookup.class_id = len(c.current.classes) - 1
// 	c.current.class_lookup[decl.identifier.text] = updated_lookup
// 	checked_class.type_info = class_info
// 	c.current.type_count += 1
// }


// FIXME: Needs a code review. Does not check all the available modules


// get_type :: proc(c: ^Checker, name: string) -> (result: Type_Info, exist: bool) {
// 	for info in c.builtin_types {
// 		if info.name == name {
// 			result = info
// 			exist = true
// 			return
// 		}
// 	}
// 	result, exist = c.current.type_lookup[name]
// 	return
// }

// // FIXME: Doesn't support multiple modules
// get_type_from_id :: proc(c: ^Checker, id: Type_ID) -> (result: Type_Info) {
// 	switch {
// 	case id < BUILT_IN_ID_COUNT:
// 		result = c.builtin_types[id]
// 	case:
// 		ptr: int = BUILT_IN_ID_COUNT
// 		for module in c.modules {
// 			rel_id := int(id) - ptr
// 			if rel_id <= module.type_count {
// 				for _, info in module.type_lookup {
// 					if info.type_id == id {
// 						result = info
// 						break
// 					}
// 				}
// 				break
// 			}
// 		}
// 	}
// 	return
// }

// get_type_from_identifier :: proc(c: ^Checker, i: Token) -> (result: Type_Info) {
// 	if t, t_exist := get_type(c, i.text); t_exist {
// 		result = t
// 	} else if fn_type, fn_exist := get_fn_type(c, i.text); fn_exist {
// 		result = fn_type
// 	} else {
// 		result, _ = get_variable_type(c, i.text)
// 	}
// 	return
// }

// get_variable_type :: proc(c: ^Checker, name: string, loc := #caller_location) -> (
// 	result: Type_Info,
// 	exist: bool,
// ) {
// 	current := c.current.scope
// 	for current != nil {
// 		if index, contains := current.var_symbol_lookup[name]; contains {
// 			symbol := current.symbols[index]
// 			// FIXME: Put this behind a compile time conditional
// 			if symbol.kind != .Var_Symbol {
// 				fmt.println(loc, name)
// 				assert(false)
// 			}
// 			result = symbol.type_info
// 			contains = true
// 			break
// 		}
// 		current = current.parent
// 	}
// 	return
// }

// get_fn_type :: proc(c: ^Checker, name: string) -> (result: Type_Info, exist: bool) {
// 	for fn in c.current.functions {
// 		function := fn.(^Checked_Fn_Declaration)
// 		if function.identifier.text == name {
// 			result = function.type_info
// 			exist = true
// 			break
// 		}
// 	}
// 	return
// }

gen_type_id :: proc(c: ^Checker) -> Type_ID {
	c.type_id_ptr += 1
	return c.type_id_ptr - 1
}

build_checked_program :: proc(c: ^Checker, module_name: string, entry_point: string) -> (
	result: []^Checked_Module,
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
		check_module_decl_symbols(c, index) or_return
	}
	for module in c.parsed_results {
		index := c.import_names_lookup[module.name]
		check_module_signatures_symbols(c, index) or_return
	}
	for module in c.parsed_results {
		index := c.import_names_lookup[module.name]
		check_module_inner_symbols(c, index) or_return
	}


	// for module in c.parsed_results {
	// 	index := c.import_names_lookup[module.name]
	// 	add_module_type_decl(c, index) or_return
	// }
	// for module in c.parsed_results {
	// 	index := c.import_names_lookup[module.name]
	// 	check_module_types_inner(c, index) or_return
	// }
	// for module in c.parsed_results {
	// 	index := c.import_names_lookup[module.name]
	// 	check_module_fn_types(c, index) or_return
	// }
	// for module in c.parsed_results {
	// 	index := c.import_names_lookup[module.name]
	// 	check_module_body_types(c, index) or_return
	// }

	result = c.modules
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

check_module_decl_symbols :: proc(c: ^Checker, module_id: int) -> (err: Error) {
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
					//odinfmt: disable
			result_symbol := add_symbol_to_scope(
				c.current.scope,
				Symbol{name = "result", kind = .Var_Symbol, module_id = c.current.id, scope_id = c.current.scope.id},
				true,
			) or_return
			//odinfmt: enable
			result_symbol.var_info.symbol = fn_symbol.fn_info.return_symbol
			result_symbol.var_info.is_ref = is_ref_symbol(result_symbol.var_info.symbol)
			result_symbol.var_info.immutable = false
		}
		for param in fn_decl.parameters {
			type_symbol := symbol_from_type_expr(c, param.type_expr) or_return
			param_symbol := Symbol {
				name = param.name.text,
				kind = .Var_Symbol,
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
		if right_symbol.kind == .Class_Symbol || right_symbol.kind == .Module_Symbol || right_symbol.kind == .Alias_Symbol {
			err = Semantic_Error {
				kind    = .Invalid_Symbol,
				token   = n.token,
				details = fmt.tprintf("%s is not a value symbol", right_symbol.name),
			}
			return
		}
		if right_symbol.kind == .Fn_Symbol && !right_symbol.fn_info.has_return {
			fmt.println(right_symbol)
			err = Semantic_Error {
				kind    = .Invalid_Symbol,
				token   = n.token,
				details = fmt.tprintf(
					"Function %s does not return any symbol and cannot be used a value",
					right_symbol.name,
				),
			}
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
			check_expr_symbols(c, n.expr) or_return
		}

		if type_symbol.kind == .Class_Symbol || type_symbol.kind == .Module_Symbol || type_symbol.kind == .Alias_Symbol {
			err = Semantic_Error {
				kind    = .Invalid_Symbol,
				token   = n.token,
				details = fmt.tprintf("%s is not a value symbol", type_symbol.name),
			}
			return
		}
		if type_symbol.kind == .Fn_Symbol {
			if type_symbol.fn_info.has_return {
				type_symbol = type_symbol.fn_info.return_symbol
			} else {
				err = Semantic_Error {
					kind    = .Invalid_Symbol,
					token   = n.token,
					details = fmt.tprintf(
						"Function %s does not return any symbol and cannot be used a value",
						type_symbol.name,
					),
				}
				return
			}
		}

		var_symbol: ^Symbol
		if c.current.scope_depth > 0 {
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
		} else {
			var_symbol = get_scoped_var_symbol(c.current.root, n.identifier) or_return
		}
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
		result, err = symbol_from_expr(c, e.left)

	case ^Parsed_Identifier_Expression:
		result, err = get_symbol(c, e.name)

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
		result, err = get_symbol(c, identifier.name)

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
			result = get_scoped_symbol(left_scope, selector.name) or_return
			err = check_dot_expr_rules(dot_expr.token, left_symbol, result)
			break chain
		case ^Parsed_Call_Expression:
			if identifier, ok := selector.func.(^Parsed_Identifier_Expression); ok {
				result = get_scoped_symbol(left_scope, identifier.name) or_return
				err = check_dot_expr_rules(dot_expr.token, left_symbol, result)
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
			check_dot_expr_rules(dot_expr.token, left_symbol, selector_symbol) or_return
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

check_dot_expr_rules :: proc(token: Token, left, selector: ^Symbol) -> (err: Error) {
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
	#partial switch left.kind {
	case .Alias_Symbol:
		err = check_dot_expr_rules(token, left.alias_info.symbol, selector)
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
		err = check_dot_expr_rules(token, left.fn_info.return_symbol, selector)
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

// add_module_type_decl :: proc(c: ^Checker, module_id: int) -> (err: Error) {
// 	c.current = c.modules[module_id]
// 	c.current_parsed = c.parsed_results[module_id]

// 	for node in c.current_parsed.types {
// 		#partial switch n in node {
// 		case ^Parsed_Type_Declaration:
// 			switch n.type_kind {
// 			case .Alias:
// 				add_type_alias(c, n.identifier, UNTYPED_ID)
// 			case .Class:
// 				add_class_type(c, n)
// 			}
// 		}
// 	}
// 	return
// }

// check_module_types_inner :: proc(c: ^Checker, module_id: int) -> (err: Error) {
// 	c.current = c.modules[module_id]
// 	c.current_parsed = c.parsed_results[module_id]

// 	for node in c.current_parsed.types {
// 		#partial switch n in node {
// 		case ^Parsed_Type_Declaration:
// 			switch n.type_kind {
// 			case .Alias:
// 				parent_expr, parent_info := check_expr_types(c, n.type_expr) or_return
// 				update_type_alias(c, n.identifier, parent_info.type_id)
// 				free_checked_expression(parent_expr)

// 			case .Class:
// 				name := n.identifier.text
// 				cl := c.current.class_lookup[name]
// 				class_decl := c.current.classes[cl.class_id].(^Checked_Class_Declaration)
// 				class_symbol := c.current.root.symbols[cl.root_index]

// 				// FIXME: Check if class has methods, constructors and fields before allocating
// 				// Check all the expression of the class's field
// 				class_decl.field_names = make([]Token, len(n.fields))
// 				class_decl.constructors = make([]^Checked_Fn_Declaration, len(n.constructors))
// 				class_decl.methods = make([]^Checked_Fn_Declaration, len(n.methods))
// 				class_info := Class_Definition_Info {
// 					fields       = make([]Type_Info, len(n.fields)),
// 					constructors = make([]Type_Info, len(n.constructors)),
// 					methods      = make([]Type_Info, len(n.methods)),
// 				}
// 				enter_class_scope(c.current, n.identifier) or_return
// 				defer pop_scope(c.current)
// 				for field, i in n.fields {
// 					field_expr, field_info := check_expr_types(c, field.type_expr) or_return
// 					class_info.fields[i] = field_info
// 					// FIXME: better to store the symbol of the field
// 					class_decl.field_names[i] = field.name
// 					set_variable_type(c.current.scope, field.name.text, field_info)
// 					free_checked_expression(field_expr)
// 				}
// 				for constructor, i in n.constructors {
// 					constr_decl := new_clone(
// 						Checked_Fn_Declaration{
// 							token = constructor.token,
// 							identifier = constructor.identifier,
// 							type_info = Type_Info{name = "constructor", type_id = FN_ID, type_kind = .Fn_Type},
// 							param_names = make([]Token, len(constructor.parameters)),
// 						},
// 					)
// 					constr_signature := make_fn_signature_info(len(constructor.parameters))
// 					constr_symbol, _, exist := get_scoped_symbol(c.current.scope, constructor.identifier.text)
// 					if !exist {
// 						assert(false)
// 					}

// 					enter_child_scope_by_id(c.current, constr_symbol.fn_scope_id) or_return
// 					defer pop_scope(c.current)
// 					for param, i in constructor.parameters {
// 						constr_decl.param_names[i] = param.name
// 						param_expr, param_info := check_expr_types(c, param.type_expr) or_return
// 						constr_signature.parameters[i] = param_info
// 						set_variable_type(c.current.scope, param.name.text, param_info)
// 						free_checked_expression(param_expr)
// 					}
// 					constr_decl.type_info.type_id_data = constr_signature
// 					class_decl.constructors[i] = constr_decl
// 					class_info.constructors[i] = constr_decl.type_info
// 				}
// 				for method, i in n.methods {
// 					method_decl := new_clone(
// 						Checked_Fn_Declaration{
// 							token = method.token,
// 							identifier = method.identifier,
// 							type_info = Type_Info{name = "constructor", type_id = FN_ID, type_kind = .Fn_Type},
// 							param_names = make([]Token, len(method.parameters)),
// 						},
// 					)
// 					method_signature := make_fn_signature_info(len(method.parameters))
// 					method_symbol, _, exist := get_scoped_symbol(c.current.scope, method.identifier.text)
// 					if !exist {
// 						assert(false)
// 					}

// 					if method.return_type_expr != nil {
// 						return_expr, return_info := check_expr_types(c, method.return_type_expr) or_return
// 						defer free_checked_expression(return_expr)
// 						set_fn_return_type_info(&method_signature, return_info)
// 						set_variable_type(c.current.scope, "result", return_info)
// 					} else {
// 						set_fn_return_type_info(&method_signature, UNTYPED_INFO)
// 					}

// 					// print_semantic_scope_standalone(c, c.current.scope)
// 					// fmt.println(method_symbol)
// 					enter_child_scope_by_id(c.current, method_symbol.fn_scope_id) or_return
// 					defer pop_scope(c.current)

// 					for param, i in method.parameters {
// 						method_decl.param_names[i] = param.name
// 						param_expr, param_info := check_expr_types(c, param.type_expr) or_return
// 						method_signature.parameters[i] = param_info
// 						set_variable_type(c.current.scope, param.name.text, param_info)
// 						free_checked_expression(param_expr)
// 					}
// 					// method_decl.body = check_node_types(c, method.body) or_return
// 					method_decl.type_info.type_id_data = method_signature
// 					class_decl.methods[i] = method_decl
// 				}
// 				// Check all the methods

// 				// Update the class Type_Info
// 				t := c.current.type_lookup[name]
// 				t.type_id_data = class_info
// 				class_decl.type_info = t
// 				c.current.type_lookup[name] = t

// 				// set_variable_type(c, "self", t)
// 				for constructor, i in n.constructors {
// 					// Update the constructor signature
// 					constr_signature := class_info.constructors[i].type_id_data.(Fn_Signature_Info)
// 					set_fn_return_type_info(&constr_signature, class_decl.type_info)
// 					class_info.constructors[i].type_id_data = constr_signature
// 					class_decl.constructors[i].type_info.type_id_data = constr_signature

// 					constr_symbol, _, exist := get_scoped_symbol(c.current.scope, constructor.identifier.text)
// 					if !exist {
// 						assert(false)
// 					}

// 					enter_child_scope_by_id(c.current, constr_symbol.fn_scope_id) or_return
// 					defer pop_scope(c.current)
// 					class_decl.constructors[i].body = check_node_types(c, constructor.body) or_return
// 				}
// 				for method, i in n.methods {
// 					method_symbol, _, exist := get_scoped_symbol(c.current.scope, method.identifier.text)
// 					if !exist {
// 						assert(false)
// 					}
// 					enter_child_scope_by_id(c.current, method_symbol.fn_scope_id) or_return
// 					defer pop_scope(c.current)
// 					class_decl.methods[i].body = check_node_types(c, method.body) or_return
// 				}
// 			}
// 		}
// 	}
// 	return
// }

// check_module_fn_types :: proc(c: ^Checker, module_id: int) -> (err: Error) {
// 	c.current = c.modules[module_id]
// 	c.current_parsed = c.parsed_results[module_id]

// 	for node in c.current_parsed.functions {
// 		#partial switch n in node {
// 		case ^Parsed_Fn_Declaration:
// 			fn_decl := new_clone(
// 				Checked_Fn_Declaration{
// 					token = n.token,
// 					identifier = n.identifier,
// 					type_info = Type_Info{name = "fn", type_id = FN_ID, type_kind = .Fn_Type},
// 					param_names = make([]Token, len(n.parameters)),
// 				},
// 			)
// 			fn_signature := make_fn_signature_info(len(n.parameters))
// 			fn_symbol, _, exist := get_scoped_symbol(c.current.root, n.identifier.text)
// 			if !exist {
// 				assert(false)
// 			}


// 			enter_child_scope_by_id(c.current, fn_symbol.fn_scope_id) or_return
// 			defer pop_scope(c.current)

// 			if n.return_type_expr != nil {
// 				return_expr, return_info := check_expr_types(c, n.return_type_expr) or_return
// 				defer free_checked_expression(return_expr)
// 				set_fn_return_type_info(&fn_signature, return_info)
// 				set_variable_type(c.current.scope, "result", return_info)
// 			} else {
// 				set_fn_return_type_info(&fn_signature, UNTYPED_INFO)
// 			}

// 			for param, i in n.parameters {
// 				fn_decl.param_names[i] = param.name
// 				param_expr, param_info := check_expr_types(c, param.type_expr) or_return
// 				defer free_checked_expression(param_expr)

// 				fn_signature.parameters[i] = param_info
// 				set_variable_type(c.current.scope, param.name.text, param_info)
// 			}
// 			fn_decl.body = check_node_types(c, n.body) or_return
// 			fn_decl.type_info.type_id_data = fn_signature

// 			append(&c.current.functions, fn_decl)
// 		}
// 	}
// 	return
// }

// check_module_body_types :: proc(c: ^Checker, module_id: int) -> (err: Error) {
// 	c.current = c.modules[module_id]
// 	c.current_parsed = c.parsed_results[module_id]


// 	for node in c.current_parsed.variables {
// 		checked_var := check_node_types(c, node) or_return
// 		append(&c.current.variables, checked_var)
// 	}
// 	for node in c.current_parsed.nodes {
// 		checked_node := check_node_types(c, node) or_return
// 		append(&c.current.nodes, checked_node)
// 	}
// 	return
// }


// check_dot_chain_symbols :: proc(
// 	c: ^Checker,
// 	scope: ^Semantic_Scope,
// 	dot_expr: ^Parsed_Dot_Expression,
// ) -> (
// 	result: Symbol,
// 	err: Error,
// ) {
// 	left_identifier := dot_expr.left.(^Parsed_Identifier_Expression)
// 	symbol, _, exist := get_scoped_symbol(scope, left_identifier.name.text)
// 	if !exist {
// 		print_semantic_scope_standalone(c, scope)
// 		err = Semantic_Error {
// 			kind    = .Unknown_Symbol,
// 			token   = left_identifier.name,
// 			details = fmt.tprintf("Unknown symbol: %s", left_identifier.name.text),
// 		}
// 		return
// 	}

// 	inner_scope: ^Semantic_Scope
// 	switch symbol.kind {
// 	case .Name:
// 		assert(false)
// 	// FIXME: THis will cause bugs when a variable doesn't refer to a scope
// 	// i.e.: var a = 10
// 	case .Class_Ref_Symbol, .Var_Symbol:
// 		for child_scope in scope.children {
// 			if child_scope.id == symbol.ref_scope_id {
// 				inner_scope = child_scope
// 				break
// 			}
// 		}

// 	case .Module_Symbol:
// 		inner_scope = c.modules[symbol.module_id].root

// 	case .Fn_Symbol:
// 		// check the return symbol
// 		assert(false, "dot chaining not supported yet")
// 	}

// 	#partial switch selector in dot_expr.selector {
// 	case ^Parsed_Identifier_Expression:
// 		// first way to exit
// 		exist: bool
// 		result, _, exist = get_scoped_symbol(inner_scope, selector.name.text)
// 		if !exist {
// 			err = Semantic_Error {
// 				kind    = .Unknown_Symbol,
// 				token   = left_identifier.name,
// 				details = fmt.tprintf("Unknown symbol: %s", selector.name.text),
// 			}
// 		}

// 	case ^Parsed_Call_Expression:
// 		// second way to exit
// 		call_identifier := selector.func.(^Parsed_Identifier_Expression)
// 		exist: bool
// 		result, _, exist = get_scoped_symbol(inner_scope, call_identifier.name.text)
// 		if !exist {
// 			err = Semantic_Error {
// 				kind    = .Unknown_Symbol,
// 				token   = left_identifier.name,
// 				details = fmt.tprintf("Unknown symbol: %s", call_identifier.name.text),
// 			}
// 		}

// 	case ^Parsed_Dot_Expression:
// 		// We want to recurse until we find an exit while checking the symbols everytime
// 		result = check_dot_chain_symbols(c, inner_scope, selector) or_return
// 	}
// 	return
// }

// // Checked nodes take ownership of the Parsed Expressions and produce a Checked_Node
// check_node_types :: proc(c: ^Checker, node: Parsed_Node) -> (result: Checked_Node, err: Error) {
// 	switch n in node {
// 	case ^Parsed_Expression_Statement:
// 		expr, _ := check_expr_types(c, n.expr) or_return
// 		result = new_clone(Checked_Expression_Statement{expr = expr})

// 	case ^Parsed_Block_Statement:
// 		block_stmt := new_clone(Checked_Block_Statement{nodes = make([dynamic]Checked_Node)})
// 		for block_node in n.nodes {
// 			node := check_node_types(c, block_node) or_return
// 			append(&block_stmt.nodes, node)
// 		}
// 		result = block_stmt

// 	case ^Parsed_Assignment_Statement:
// 		left, left_info := check_expr_types(c, n.left) or_return
// 		right, right_info := check_expr_types(c, n.right) or_return
// 		if !type_equal(c, left_info, right_info) {
// 			err = Semantic_Error {
// 				kind    = .Mismatched_Types,
// 				token   = n.token,
// 				details = fmt.tprintf(
// 					"Left expression of type %s, right expression of type %s",
// 					left_info.name,
// 					right_info.name,
// 				),
// 			}
// 		}
// 		// The type info should always exist at this point,
// 		// but we will keep this as a sanity check for now

// 		result = new_clone(Checked_Assigment_Statement{token = n.token, left = left, right = right})


// 	case ^Parsed_If_Statement:
// 		condition_expr, condition_info := check_expr_types(c, n.condition) or_return
// 		if !is_truthy_type(condition_info) {
// 			err = Semantic_Error {
// 				kind    = .Mismatched_Types,
// 				token   = n.token,
// 				details = fmt.tprintf("Expected %s, got %s", c.builtin_types[BOOL_ID].name, condition_info.name),
// 			}
// 		}
// 		// push a new scope here
// 		body_node := check_node_types(c, n.body) or_return
// 		if_stmt := new_clone(
// 			Checked_If_Statement{token = n.token, condition = condition_expr, body = body_node},
// 		)
// 		if n.next_branch != nil {
// 			next_node := check_node_types(c, n.next_branch) or_return
// 			if_stmt.next_branch = next_node
// 		}
// 		result = if_stmt

// 	case ^Parsed_Range_Statement:
// 		//push scope
// 		low_expr, low_info := check_expr_types(c, n.low) or_return
// 		high_expr, high_info := check_expr_types(c, n.high) or_return
// 		if !type_equal(c, low_info, high_info) {
// 			err = Semantic_Error {
// 				kind    = .Mismatched_Types,
// 				token   = n.token,
// 				details = fmt.tprintf(
// 					"Low expression of type %s, High expression of type %s",
// 					low_info.name,
// 					high_info.name,
// 				),
// 			}
// 		}
// 		if !is_numerical_type(low_info) {
// 			err = Semantic_Error {
// 				kind    = .Mismatched_Types,
// 				token   = n.token,
// 				details = fmt.tprintf("Expected %s, got %s", c.builtin_types[NUMBER_ID].name, low_info.name),
// 			}
// 		}

// 		// add the newly created iterator to the scope
// 		body_node := check_node_types(c, n.body) or_return
// 		result = new_clone(
// 			Checked_Range_Statement{
// 				token = n.token,
// 				iterator_name = n.iterator_name,
// 				iterator_type_info = low_info,
// 				low = low_expr,
// 				high = high_expr,
// 				reverse = n.reverse,
// 				op = n.op,
// 				body = body_node,
// 			},
// 		)

// 	case ^Parsed_Import_Statement:
// 		assert(false, "Module not implemented yet")

// 	case ^Parsed_Var_Declaration:
// 		var_expr, var_info := check_expr_types(c, n.type_expr) or_return
// 		value_expr, value_info := check_expr_types(c, n.expr) or_return
// 		defer free_checked_expression(var_expr)

// 		// we check if the type needs to be infered
// 		if type_equal(c, var_info, c.builtin_types[UNTYPED_ID]) {
// 			// add the var to the environment's scope
// 			switch {
// 			case type_equal(c, value_info, c.builtin_types[UNTYPED_NUMBER_ID]):
// 				var_info = c.builtin_types[NUMBER_ID]
// 			case type_equal(c, value_info, c.builtin_types[UNTYPED_BOOL_ID]):
// 				var_info = c.builtin_types[BOOL_ID]
// 			case type_equal(c, value_info, c.builtin_types[UNTYPED_STRING_ID]):
// 				var_info = c.builtin_types[STRING_ID]
// 			case:
// 				var_info = value_info
// 			}
// 		} else {
// 			if !type_equal(c, var_info, value_info) {
// 				err = Semantic_Error {
// 					kind    = .Mismatched_Types,
// 					token   = n.token,
// 					details = fmt.tprintf("Expected %s, got %s", var_info.name, value_info.name),
// 				}
// 				return
// 			}
// 		}
// 		set_variable_type(c.current.scope, n.identifier.text, var_info)
// 		result = new_clone(
// 			Checked_Var_Declaration{
// 				token = n.token,
// 				identifier = n.identifier,
// 				type_info = var_info,
// 				expr = value_expr,
// 				initialized = n.initialized,
// 			},
// 		)


// 	case ^Parsed_Fn_Declaration:

// 	case ^Parsed_Type_Declaration:
// 	}
// 	return
// }

// check_expr_types :: proc(c: ^Checker, expr: Parsed_Expression) -> (
// 	result: Checked_Expression,
// 	info: Type_Info,
// 	err: Error,
// ) {
// 	switch e in expr {
// 	case ^Parsed_Literal_Expression:
// 		#partial switch e.value.kind {
// 		case .Number:
// 			info = c.builtin_types[UNTYPED_NUMBER_ID]
// 		case .Boolean:
// 			info = c.builtin_types[UNTYPED_BOOL_ID]
// 		case:
// 			assert(false, "Probably erroneous path for Parsed_Literal_Expression in  check_expr_types procedure")
// 		}
// 		result = new_clone(Checked_Literal_Expression{type_info = info, value = e.value})

// 	case ^Parsed_String_Literal_Expression:
// 		info = c.builtin_types[UNTYPED_STRING_ID]
// 		result = new_clone(Checked_String_Literal_Expression{type_info = info, value = e.value})

// 	case ^Parsed_Array_Literal_Expression:
// 		// NOTE: no need to free anything here since checking Array_Type_Expression 
// 		// does not return an expression
// 		_, lit_type := check_expr_types(c, e.type_expr) or_return
// 		inner_type := lit_type.type_id_data.(Generic_Type_Info)[0]
// 		info = lit_type

// 		checked_arr := new_clone(
// 			Checked_Array_Literal_Expression{
// 				token = e.token,
// 				type_info = info,
// 				values = make([]Checked_Expression, len(e.values)),
// 			},
// 		)
// 		for element, i in e.values {
// 			elem_expr, elem_type := check_expr_types(c, element) or_return
// 			if !type_equal(c, inner_type, elem_type) {
// 				err = Semantic_Error {
// 					kind    = .Mismatched_Types,
// 					token   = e.token,
// 					details = fmt.tprintf("Expected %s, got %s", inner_type.name, elem_type.name),
// 				}
// 			}
// 			checked_arr.values[i] = elem_expr
// 		}
// 		result = checked_arr

// 	case ^Parsed_Unary_Expression:
// 		checked_unary := new_clone(Checked_Unary_Expression{token = e.token, op = e.op})
// 		checked_unary.expr, info = check_expr_types(c, e.expr) or_return
// 		checked_unary.type_info = info
// 		#partial switch e.op {
// 		// Parsed_Expression must be of "truthy" type
// 		case .Not_Op:
// 			if !is_truthy_type(info) {
// 				err = Semantic_Error {
// 					kind    = .Mismatched_Types,
// 					token   = e.token,
// 					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[BOOL_ID].name, info.name),
// 				}
// 			}

// 		// Parsed_Expression must be of numerical type
// 		case .Minus_Op:
// 			if !is_numerical_type(info) {
// 				err = Semantic_Error {
// 					kind    = .Mismatched_Types,
// 					token   = e.token,
// 					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[NUMBER_ID].name, info.name),
// 				}
// 			}
// 		case:
// 			assert(false)
// 		}
// 		result = checked_unary

// 	case ^Parsed_Binary_Expression:
// 		checked_binary := new_clone(Checked_Binary_Expression{token = e.token, op = e.op})
// 		left, left_info := check_expr_types(c, e.left) or_return
// 		right, right_info := check_expr_types(c, e.right) or_return
// 		if !type_equal(c, left_info, right_info) {
// 			err = Semantic_Error {
// 				kind    = .Mismatched_Types,
// 				token   = e.token,
// 				details = fmt.tprintf(
// 					"Left expression of type %s, right expression of type %s",
// 					left_info.name,
// 					right_info.name,
// 				),
// 			}
// 			return
// 		}

// 		#partial switch e.op {
// 		case .Minus_Op, .Plus_Op, .Mult_Op, .Div_Op, .Rem_Op:
// 			if !is_numerical_type(left_info) {
// 				err = Semantic_Error {
// 					kind    = .Mismatched_Types,
// 					token   = e.token,
// 					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[NUMBER_ID].name, left_info.name),
// 				}
// 			}
// 			info = left_info

// 		case .Equal_Op, .Greater_Op, .Greater_Eq_Op, .Lesser_Op, .Lesser_Eq_Op:
// 			if !is_numerical_type(left_info) {
// 				err = Semantic_Error {
// 					kind    = .Mismatched_Types,
// 					token   = e.token,
// 					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[NUMBER_ID].name, left_info.name),
// 				}
// 			}
// 			info = c.builtin_types[UNTYPED_BOOL_ID]

// 		case .Or_Op, .And_Op:
// 			if !is_truthy_type(left_info) {
// 				err = Semantic_Error {
// 					kind    = .Mismatched_Types,
// 					token   = e.token,
// 					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[BOOL_ID].name, left_info.name),
// 				}
// 			}
// 			info = left_info
// 		}
// 		checked_binary.left = left
// 		checked_binary.right = right
// 		checked_binary.type_info = info
// 		result = checked_binary

// 	case ^Parsed_Identifier_Expression:
// 		identifier_symbol := get_symbol(c, e.name) or_return
// 		info = identifier_symbol.type_info
// 		result = new_clone(Checked_Identifier_Expression{name = e.name, type_info = info})

// 	case ^Parsed_Index_Expression:
// 		checked_index := new_clone(Checked_Index_Expression{token = e.token})
// 		left, left_info := check_expr_types(c, e.left) or_return
// 		defer free_checked_expression(left)

// 		if left_info.type_id == ARRAY_ID {
// 			left_indentfier := left.(^Checked_Identifier_Expression)
// 			checked_index.left = left_indentfier.name
// 			checked_index.kind = .Array
// 			index, index_info := check_expr_types(c, e.index) or_return
// 			if !is_numerical_type(index_info) {
// 				err = Semantic_Error {
// 					kind    = .Mismatched_Types,
// 					token   = e.token,
// 					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[NUMBER_ID].name, index_info.name),
// 				}
// 				return
// 			}
// 			// Retrieve the Type_Info from the the element Type_ID
// 			info = left_info.type_id_data.(Generic_Type_Info)[0]
// 			checked_index.index = index
// 			checked_index.type_info = info
// 			result = checked_index
// 		} else {
// 			identifier := e.left.(^Parsed_Identifier_Expression)
// 			err = Semantic_Error {
// 				kind    = .Mismatched_Types,
// 				token   = e.token,
// 				details = fmt.tprintf("Cannot index %s of type %s", identifier.name.text, left_info.name),
// 			}
// 		}

// 	case ^Parsed_Dot_Expression:
// 		left_identifier := e.left.(^Parsed_Identifier_Expression)
// 		left_symbol := get_symbol(c, left_identifier.name) or_return
// 		checked_dot := new_clone(
// 			Checked_Dot_Expression{token = e.token, left = left_identifier.name, left_symbol = left_symbol},
// 		)

// 		// RULES:
// 		// 1. accessing fields on Class not allowed
// 		// 2. calling constructors from instance not allowed

// 		left_info: Type_Info
// 		name := left_identifier.name.text
// 		is_instance := false
// 		switch {
// 		case name == "self":
// 			is_instance = true
// 			symbol := get_symbol(c, left_identifier.name) or_return
// 			for class_name, class_lookup in c.current.class_lookup {
// 				if symbol.scope_id == class_lookup.scope_id {
// 					left_info = c.current.type_lookup[class_name]
// 					break
// 				}
// 			}

// 		case:
// 			if index, module_exist := c.import_names_lookup[name]; module_exist {
// 				module := c.modules[index]
// 				previous := c.current
// 				c.current = module
// 				nested_dot, nested_info := check_expr_types(c, e.selector) or_return
// 				c.current = previous
// 				checked_dot.selector = nested_dot
// 				checked_dot.type_info = nested_info
// 				checked_dot.kind = .Module
// 				checked_dot.left_id = index
// 				result = checked_dot
// 				info = nested_info
// 				return
// 			} else if t, exist := c.current.type_lookup[name]; exist {
// 				checked_dot.left_id = c.current.class_lookup[name].class_id
// 				left_info = t
// 			} else {
// 				is_instance = true
// 				left_info, _ = get_variable_type(c, name)
// 			}
// 		}

// 		#partial switch left_info.type_kind {
// 		case .Class_Type:
// 			class_def := left_info.type_id_data.(Class_Definition_Info)
// 			class_decl := get_class_decl(c.current, left_info.type_id)
// 			if left_identifier.name.text == "a" {
// 				symbol, _, _ := get_scoped_symbol(c.current.scope, "a")
// 				fmt.println("2nd boop:", class_decl)
// 				fmt.println(symbol)
// 			}

// 			#partial switch selector in e.selector {
// 			case ^Parsed_Identifier_Expression:
// 				// Rule 1 check
// 				if is_instance {
// 					checked_dot.kind = .Instance_Field
// 					for field, i in class_decl.field_names {
// 						if field.text == selector.name.text {
// 							info = class_def.fields[i]
// 							checked_dot.selector_id = i
// 							break
// 						}
// 					}
// 					checked_dot.selector = new_clone(
// 						Checked_Identifier_Expression{name = selector.name, type_info = info},
// 					)
// 				} else {
// 					err = Semantic_Error {
// 						kind    = .Invalid_Class_Field_Access,
// 						token   = e.token,
// 						details = fmt.tprintf(
// 							"Cannot access fields of %s. %s is a class and not an instance of class",
// 							name,
// 							name,
// 						),
// 					}
// 					return
// 				}


// 			case ^Parsed_Call_Expression:
// 				call_identifier := selector.func.(^Parsed_Identifier_Expression)
// 				fn_decl, fn_id, is_constructor := find_checked_constructor(class_decl, call_identifier.name)
// 				if !is_constructor {
// 					fn_decl, fn_id, _ = find_checked_method(class_decl, call_identifier.name)
// 				}

// 				// Rule 2 check
// 				if is_instance {
// 					checked_dot.kind = .Instance_Call
// 					if is_constructor {
// 						err = Semantic_Error {
// 							kind    = .Invalid_Class_Constructor_Usage,
// 							token   = e.token,
// 							details = fmt.tprintf("%s is an instance of Class %s", name, left_info.name),
// 						}
// 						return
// 					}
// 				} else {
// 					checked_dot.kind = .Class
// 				}


// 				signature_info := fn_decl.type_info.type_id_data.(Fn_Signature_Info)
// 				info = signature_info.return_type_info^

// 				checked_call := new_clone(
// 					Checked_Call_Expression{
// 						token = selector.token,
// 						type_info = info,
// 						func = new_clone(
// 							Checked_Identifier_Expression{name = call_identifier.name, type_info = fn_decl.type_info},
// 						),
// 						args = make([]Checked_Expression, len(selector.args)),
// 					},
// 				)

// 				if len(signature_info.parameters) != len(selector.args) {
// 					err = Semantic_Error {
// 						kind    = .Invalid_Arg_Count,
// 						token   = e.token,
// 						details = fmt.tprintf(
// 							"Invalid Argument count, expected %i, got %i",
// 							len(signature_info.parameters),
// 							len(selector.args),
// 						),
// 					}
// 					return
// 				}
// 				for arg, i in selector.args {
// 					arg_expr, arg_info := check_expr_types(c, arg) or_return
// 					if !type_equal(c, arg_info, signature_info.parameters[i]) {
// 						err = Semantic_Error {
// 							kind    = .Mismatched_Types,
// 							token   = e.token,
// 							details = fmt.tprintf("Expected %s, got %s", arg_info.name, signature_info.parameters[i].name),
// 						}
// 						return
// 					}
// 					checked_call.args[i] = arg_expr
// 				}

// 				checked_dot.selector = checked_call
// 				checked_dot.type_info = info
// 				checked_dot.selector_id = fn_id
// 			}


// 		case .Generic_Type:
// 			if left_info.type_id == ARRAY_ID {
// 				checked_dot.selector, info = check_array_dot_expression_types(c, left_info, e.selector) or_return
// 				#partial switch s in checked_dot.selector {
// 				case ^Checked_Identifier_Expression:
// 					checked_dot.kind = .Array_Len
// 				case ^Checked_Call_Expression:
// 					checked_dot.kind = .Array_Append
// 				}
// 			} else {
// 				err = Semantic_Error {
// 					kind    = .Invalid_Dot_Operand,
// 					token   = left_identifier.name,
// 					details = fmt.tprintf("Left operand %s is not of valid type: %s", name, left_info.name),
// 				}
// 			}

// 		case:
// 			err = Semantic_Error {
// 				kind    = .Invalid_Dot_Operand,
// 				token   = left_identifier.name,
// 				details = fmt.tprintf("Left operand %s is not of valid type: %s", name, left_info.name),
// 			}
// 		}

// 		result = checked_dot


// 	case ^Parsed_Call_Expression:
// 		checked_call := new_clone(
// 			Checked_Call_Expression{token = e.token, args = make([]Checked_Expression, len(e.args))},
// 		)

// 		// Get the signature from the environment
// 		fn_expr, fn_info := check_expr_types(c, e.func) or_return
// 		if fn_info.type_id == FN_ID && fn_info.type_kind == .Fn_Type {
// 			signature_info := fn_info.type_id_data.(Fn_Signature_Info)
// 			// Check that the call expression has the exact same amount of arguments
// 			// as the fn signature
// 			if len(signature_info.parameters) != len(e.args) {
// 				err = Semantic_Error {
// 					kind    = .Invalid_Arg_Count,
// 					token   = e.token,
// 					details = fmt.tprintf(
// 						"Invalid Argument count, expected %i, got %i",
// 						len(signature_info.parameters),
// 						len(e.args),
// 					),
// 				}
// 				return
// 			}
// 			for arg, i in e.args {
// 				arg_expr, arg_info := check_expr_types(c, arg) or_return
// 				if !type_equal(c, arg_info, signature_info.parameters[i]) {
// 					err = Semantic_Error {
// 						kind    = .Mismatched_Types,
// 						token   = e.token,
// 						details = fmt.tprintf("Expected %s, got %s", arg_info.name, signature_info.parameters[i].name),
// 					}
// 					return
// 				}
// 				checked_call.args[i] = arg_expr
// 			}
// 			info = signature_info.return_type_info^

// 			checked_call.type_info = info
// 			checked_call.func = fn_expr
// 			result = checked_call
// 		} else {
// 			// FIXME: return an error
// 			return
// 		}

// 	case ^Parsed_Array_Type_Expression:
// 		// FIXME: Probably does not support multi-dimensional arrays
// 		inner_expr, inner_info := check_expr_types(c, e.elem_type) or_return
// 		if inner_expr != nil {
// 			free_checked_expression(inner_expr)
// 		}
// 		info = Type_Info {
// 			name = "array",
// 			type_id = ARRAY_ID,
// 			type_kind = .Generic_Type,
// 			type_id_data = Generic_Type_Info{spec_type_id = inner_info.type_id},
// 		}
// 	}
// 	return
// }

// check_array_dot_expression_types :: proc(
// 	c: ^Checker,
// 	array_info: Type_Info,
// 	selector: Parsed_Expression,
// ) -> (
// 	result: Checked_Expression,
// 	info: Type_Info,
// 	err: Error,
// ) {
// 	#partial switch s in selector {
// 	case ^Parsed_Identifier_Expression:
// 		if s.name.text == "len" {
// 			result = new_clone(Checked_Identifier_Expression{name = s.name, type_info = UNTYPED_NUMBER_INFO})
// 			info = UNTYPED_NUMBER_INFO
// 		}

// 	case ^Parsed_Call_Expression:
// 		identifier := s.func.(^Parsed_Identifier_Expression)
// 		if identifier.name.text == "append" {
// 			if len(s.args) != 1 {
// 				err = Semantic_Error {
// 					kind    = .Invalid_Arg_Count,
// 					token   = s.token,
// 					details = fmt.tprintf("append expect 1 argument, got %d", len(s.args)),
// 				}
// 			}

// 			item, item_info := check_expr_types(c, s.args[0]) or_return
// 			array_elem_info := array_info.type_id_data.(Generic_Type_Info)
// 			if !type_equal(c, item_info, get_type_from_id(c, array_elem_info.spec_type_id)) {
// 				err = Semantic_Error {
// 					kind    = .Mismatched_Types,
// 					token   = s.token,
// 					details = fmt.tprintf(
// 						"Cannot append element of type %s to array of type %s",
// 						item_info.name,
// 						get_type_from_id(c, array_elem_info.spec_type_id),
// 					),
// 				}
// 				return
// 			}

// 			args := make([]Checked_Expression, 1)
// 			args[0] = item
// 			result = new_clone(
// 				Checked_Call_Expression{
// 					token = identifier.name,
// 					type_info = UNTYPED_INFO,
// 					func = new_clone(Checked_Identifier_Expression{name = identifier.name}),
// 					args = args,
// 				},
// 			)
// 			info = UNTYPED_INFO
// 		}
// 	case:
// 		// FIXME: do better
// 		assert(false)
// 	}
// 	return
// }
