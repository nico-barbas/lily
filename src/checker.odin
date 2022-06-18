package lily

import "core:fmt"

Checker :: struct {
	// a weak ref to all the checked modules that have already been compiled
	modules:         []^Checked_Module,
	import_callback: import_module_callback,

	// Builtin types and internal states
	builtin_symbols: [5]string,
	builtin_types:   [BUILT_IN_ID_COUNT]Type_Info,
	type_id_ptr:     Type_ID,
	current:         ^Checked_Module,
}

import_module_callback :: proc(module_name: string) -> ^Parsed_Module

init_checker :: proc(c: ^Checker, loaded: []^Checked_Module, cb: import_module_callback) {
	c.modules = loaded
	c.import_callback = cb
	c.builtin_symbols = {"untyped", "number", "string", "bool", "array"}
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
	free(c)
}

contain_symbol :: proc(c: ^Checker, token: Token) -> bool {
	builtins: for name in c.builtin_symbols {
		if name == token.text {
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

get_symbol :: proc(c: ^Checker, token: Token) -> (result: Symbol, err: Error) {
	builtins: for name in c.builtin_symbols {
		if name == token.text {
			result = name
			return
		}
	}

	scope := c.current.scope
	find: for scope != nil {
		for name in scope.symbols {
			switch n in name {
			case string:
				if n == token.text {
					result = name
					return
				}
			case Scope_Ref_Symbol:
				if n.name == token.text {
					result = name
					return
				}

			case Var_Symbol:
				if n.name == token.text {
					result = name
					return
				}
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

add_symbol :: proc {
	add_symbol_to_current_module,
	add_symbol_to_scope,
}

add_symbol_to_current_module :: proc(c: ^Checker, token: Token, shadow := false) -> Error {
	return add_symbol_to_scope(c.current.scope, token, shadow)
}

add_scope_ref_symbol :: proc {
	add_scope_ref_symbol_to_scope,
	add_scope_ref_symbol_to_current_module,
}

add_scope_ref_symbol_to_current_module :: proc(
	c: ^Checker,
	token: Token,
	scope_id: Scope_ID,
	shadow := false,
) -> Error {
	return add_scope_ref_symbol_to_scope(c.current.scope, token, scope_id, shadow)
}

add_var_symbol :: proc {
	add_var_symbol_to_scope,
	add_var_symbol_to_current_module,
}

add_var_symbol_to_current_module :: proc(c: ^Checker, t: Token, shadow := false) -> Error {
	return add_var_symbol_to_scope(c.current.scope, t, shadow)
}

add_type_alias :: proc(c: ^Checker, name: Token, parent_type: Type_ID) {
	c.current.type_lookup[name.text] = Type_Info {
		name = name.text,
		type_id = gen_type_id(c),
		type_kind = .Type_Alias,
		type_id_data = Type_Alias_Info{underlying_type_id = parent_type},
	}
	c.current.type_count += 1
}

update_type_alias :: proc(c: ^Checker, name: Token, parent_type: Type_ID) {
	t := c.current.type_lookup[name.text]
	t.type_id_data = Type_Alias_Info {
		underlying_type_id = parent_type,
	}
	c.current.type_lookup[name.text] = t
}


// Adding a class decl to the type system means adding it to the type checker
// but also adding the Checked_Type_Declaration to the module for later compilation
add_class_type :: proc(c: ^Checker, decl: ^Parsed_Type_Declaration) {
	checked_class := new_clone(
		Checked_Class_Declaration{
			token = decl.token,
			is_token = decl.is_token,
			identifier = decl.identifier,
		},
	)
	append(&c.current.classes, checked_class)
	class_info := Type_Info {
		name      = decl.identifier.text,
		type_id   = gen_type_id(c),
		type_kind = .Class_Type,
	}
	c.current.type_lookup[decl.identifier.text] = class_info
	checked_class.type_info = class_info
	c.current.type_count += 1
}

set_variable_type :: proc(c: ^Checker, name: string, t: Type_Info, loc := #caller_location) {
	index := c.current.scope.var_symbol_lookup[name]
	symbol, ok := c.current.scope.symbols[index].(Var_Symbol)
	if !ok {
		fmt.println("FAIL UP STACK: ", loc, "Current scope id: ", c.current.scope.id)
		fmt.println("culprit: ", name, t)
		fmt.println("real: ", c.current.scope.symbols[index])
		fmt.println(c.current.scope)
		print_symbol_table(c, c.current)
		assert(false)
	}
	symbol.type_info = t
	c.current.scope.symbols[index] = symbol
}


// FIXME: Needs a code review. Does not check all the available modules

get_type :: proc(c: ^Checker, name: string) -> (result: Type_Info, exist: bool) {
	for info in c.builtin_types {
		if info.name == name {
			result = info
			exist = true
			return
		}
	}
	result, exist = c.current.type_lookup[name]
	return
}

// FIXME: Doesn't support multiple modules
get_type_from_id :: proc(c: ^Checker, id: Type_ID) -> (result: Type_Info) {
	switch {
	case id < BUILT_IN_ID_COUNT:
		result = c.builtin_types[id]
	case:
		ptr: int = BUILT_IN_ID_COUNT
		for module in c.modules {
			rel_id := int(id) - ptr
			if rel_id <= module.type_count {
				for _, info in module.type_lookup {
					if info.type_id == id {
						result = info
						break
					}
				}
				break
			}
		}
	}
	return
}

get_type_from_identifier :: proc(c: ^Checker, i: Token) -> (result: Type_Info) {
	if t, t_exist := get_type(c, i.text); t_exist {
		result = t
	} else if fn_type, fn_exist := get_fn_type(c, i.text); fn_exist {
		result = fn_type
	} else {
		result, _ = get_variable_type(c, i.text)
	}
	return
}

get_variable_type :: proc(c: ^Checker, name: string) -> (result: Type_Info, exist: bool) {
	current := c.current.scope
	for current != nil {
		if index, contains := current.var_symbol_lookup[name]; contains {
			var_symbol := current.symbols[index].(Var_Symbol)
			result = var_symbol.type_info
			contains = true
			break
		}
		current = current.parent
	}
	return
}

get_fn_type :: proc(c: ^Checker, name: string) -> (result: Type_Info, exist: bool) {
	for fn in c.current.functions {
		function := fn.(^Checked_Fn_Declaration)
		if function.identifier.text == name {
			result = function.type_info
			exist = true
			break
		}
	}
	return
}

gen_type_id :: proc(c: ^Checker) -> Type_ID {
	c.type_id_ptr += 1
	return c.type_id_ptr - 1
}

check_module :: proc(c: ^Checker, m: ^Parsed_Module) -> (module: ^Checked_Module, err: Error) {
	// Create a new module and add all the file level declaration symbols
	module = make_checked_module()
	c.current = module
	// The type symbols need to be added first
	for node in m.nodes {
		if n, ok := node.(^Parsed_Type_Declaration); ok {
			switch n.type_kind {
			case .Alias:
				add_symbol(c, n.identifier) or_return
			case .Class:
				push_class_scope(c.current, n.identifier)
				defer pop_scope(c.current)
				for field in n.fields {
					add_var_symbol(c, field.name) or_return
				}
				for constructor in n.constructors {
					add_symbol(c, constructor.identifier) or_return
					push_scope(c.current, constructor.identifier)
					defer pop_scope(c.current)
				}
				for method in n.methods {
					add_symbol(c, method.identifier) or_return
					push_scope(c.current, method.identifier)
					defer pop_scope(c.current)
				}
			}
		}
	}

	for node in m.nodes {
		#partial switch n in node {
		case ^Parsed_Var_Declaration:
			add_var_symbol(c, n.identifier) or_return
		case ^Parsed_Fn_Declaration:
			fn_scope_id := push_scope(c.current, n.identifier)
			pop_scope(c.current)
			add_scope_ref_symbol(c, n.identifier, fn_scope_id) or_return
		}
	}

	// After all the declaration have been gathered, 
	// we resolve the rest of the symbols in the inner expressions and scopes.
	for node in m.nodes {
		check_node_symbols(c, node) or_return
	}

	// Resolve the types:
	// Gather all the type declaration and generate type info for them.
	// Store those in the module type infos.
	// Then we can start to solve the types in each node and expression.

	for node in m.nodes {
		#partial switch n in node {
		case ^Parsed_Type_Declaration:
			switch n.type_kind {
			case .Alias:
				add_type_alias(c, n.identifier, UNTYPED_ID)
			case .Class:
				add_class_type(c, n)
			}
		}
	}

	for node in m.nodes {
		#partial switch n in node {
		case ^Parsed_Type_Declaration:
			switch n.type_kind {
			case .Alias:
				parent_expr, parent_info := check_expr_types(c, n.type_expr) or_return
				update_type_alias(c, n.identifier, parent_info.type_id)
				free_checked_expression(parent_expr)

			case .Class:
				name := n.identifier.text
				class_decl: ^Checked_Class_Declaration
				for node in module.classes {
					class := node.(^Checked_Class_Declaration)
					if class.identifier.text == name {
						class_decl = class
					}
				}

				// FIXME: Check if class has methods, constructors and fields before allocating
				// Check all the expression of the class's field
				class_decl.field_names = make([]Token, len(n.fields))
				class_decl.constructors = make([]^Checked_Fn_Declaration, len(n.constructors))
				class_decl.methods = make([]^Checked_Fn_Declaration, len(n.methods))
				class_info := Class_Definition_Info {
					fields       = make([]Type_Info, len(n.fields)),
					constructors = make([]Type_Info, len(n.constructors)),
					methods      = make([]Type_Info, len(n.methods)),
				}
				enter_class_scope(c.current, n.identifier) or_return
				defer pop_scope(c.current)
				for field, i in n.fields {
					field_expr, field_info := check_expr_types(c, field.type_expr) or_return
					class_info.fields[i] = field_info
					class_decl.field_names[i] = field.name
					set_variable_type(c, field.name.text, field_info)
					free_checked_expression(field_expr)
				}
				for constructor, i in n.constructors {
					constr_decl := new_clone(
						Checked_Fn_Declaration{
							token = constructor.token,
							identifier = constructor.identifier,
							type_info = Type_Info{name = "constructor", type_id = FN_ID, type_kind = .Fn_Type},
							param_names = make([]Token, len(constructor.parameters)),
						},
					)
					constr_signature := make_fn_signature_info(len(constructor.parameters))

					enter_child_scope(c.current, constructor.identifier) or_return
					defer pop_scope(c.current)
					for param, i in constructor.parameters {
						constr_decl.param_names[i] = param.name
						param_expr, param_info := check_expr_types(c, param.type_expr) or_return
						constr_signature.parameters[i] = param_info
						set_variable_type(c, param.name.text, param_info)
						free_checked_expression(param_expr)
					}
					constr_decl.type_info.type_id_data = constr_signature
					class_decl.constructors[i] = constr_decl
					class_info.constructors[i] = constr_decl.type_info
				}
				for method, i in n.methods {
					method_decl := new_clone(
						Checked_Fn_Declaration{
							token = method.token,
							identifier = method.identifier,
							type_info = Type_Info{name = "constructor", type_id = FN_ID, type_kind = .Fn_Type},
							param_names = make([]Token, len(method.parameters)),
						},
					)
					method_signature := make_fn_signature_info(len(method.parameters))

					if method.return_type_expr != nil {
						return_expr, return_info := check_expr_types(c, method.return_type_expr) or_return
						defer free_checked_expression(return_expr)
						set_fn_return_type_info(&method_signature, return_info)
						set_variable_type(c, "result", return_info)
					} else {
						set_fn_return_type_info(&method_signature, UNTYPED_INFO)
					}

					enter_child_scope(c.current, method.identifier) or_return
					defer pop_scope(c.current)
					for param, i in method.parameters {
						method_decl.param_names[i] = param.name
						param_expr, param_info := check_expr_types(c, param.type_expr) or_return
						method_signature.parameters[i] = param_info
						set_variable_type(c, param.name.text, param_info)
						free_checked_expression(param_expr)
					}
					// method_decl.body = check_node_types(c, method.body) or_return
					method_decl.type_info.type_id_data = method_signature
					class_decl.methods[i] = method_decl
				}
				// Check all the methods

				// Update the class Type_Info
				t := module.type_lookup[name]
				t.type_id_data = class_info
				class_decl.type_info = t
				module.type_lookup[name] = t

				// set_variable_type(c, "self", t)
				for constructor, i in n.constructors {
					// Update the constructor signature
					constr_signature := class_info.constructors[i].type_id_data.(Fn_Signature_Info)
					set_fn_return_type_info(&constr_signature, class_decl.type_info)
					class_info.constructors[i].type_id_data = constr_signature
					class_decl.constructors[i].type_info.type_id_data = constr_signature

					enter_child_scope(c.current, constructor.identifier) or_return
					defer pop_scope(c.current)
					class_decl.constructors[i].body = check_node_types(c, constructor.body) or_return
				}
				for method, i in n.methods {
					enter_child_scope(c.current, method.identifier) or_return
					defer pop_scope(c.current)
					class_decl.methods[i].body = check_node_types(c, method.body) or_return
				}
			}
		}
	}

	for node in m.nodes {
		#partial switch n in node {
		case ^Parsed_Fn_Declaration:
			fn_decl := new_clone(
				Checked_Fn_Declaration{
					token = n.token,
					identifier = n.identifier,
					type_info = Type_Info{name = "fn", type_id = FN_ID, type_kind = .Fn_Type},
					param_names = make([]Token, len(n.parameters)),
				},
			)
			fn_signature := make_fn_signature_info(len(n.parameters))

			enter_child_scope(c.current, n.identifier) or_return
			defer pop_scope(c.current)

			if n.return_type_expr != nil {
				return_expr, return_info := check_expr_types(c, n.return_type_expr) or_return
				defer free_checked_expression(return_expr)
				set_fn_return_type_info(&fn_signature, return_info)
				set_variable_type(c, "result", return_info)
			} else {
				set_fn_return_type_info(&fn_signature, UNTYPED_INFO)
			}

			for param, i in n.parameters {
				fn_decl.param_names[i] = param.name
				param_expr, param_info := check_expr_types(c, param.type_expr) or_return
				defer free_checked_expression(param_expr)

				fn_signature.parameters[i] = param_info
				set_variable_type(c, param.name.text, param_info)
			}
			fn_decl.body = check_node_types(c, n.body) or_return
			fn_decl.type_info.type_id_data = fn_signature

			append(&module.functions, fn_decl)
		}
	}

	for node in m.nodes {
		checked_node := check_node_types(c, node) or_return
		#partial switch node in checked_node {
		case ^Checked_Fn_Declaration, ^Checked_Type_Declaration:
		case:
			append(&module.nodes, checked_node)
		}
	}

	c.current = nil
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
		check_expr_symbols(c, n.left) or_return
		check_expr_symbols(c, n.right) or_return

	case ^Parsed_If_Statement:
		check_expr_symbols(c, n.condition) or_return
		push_scope(c.current, n.token)
		check_node_symbols(c, n.body) or_return
		pop_scope(c.current)
		if n.next_branch != nil {
			check_node_symbols(c, n.next_branch) or_return
		}

	case ^Parsed_Range_Statement:
		if contain_symbol(c, n.iterator_name) {
			err = Semantic_Error {
				kind    = .Redeclared_Symbol,
				token   = n.token,
				details = fmt.tprintf("Redeclaration of '%s'", n.iterator_name.text),
			}
			return
		}
		check_expr_symbols(c, n.low) or_return
		check_expr_symbols(c, n.high) or_return
		push_scope(c.current, n.token)
		defer pop_scope(c.current)
		check_node_symbols(c, n.body) or_return

	case ^Parsed_Import_Statement:
		assert(false, "Module not implemented yet")

	case ^Parsed_Var_Declaration:
		if c.current.scope_depth > 0 {
			add_var_symbol(c, n.identifier) or_return
		}
		check_expr_symbols(c, n.type_expr) or_return
		check_expr_symbols(c, n.expr) or_return

	case ^Parsed_Fn_Declaration:
		// No need to check for function symbol declaration since 
		// functions can only be declared at the file scope
		enter_child_scope(c.current, n.identifier)
		defer pop_scope(c.current)
		if n.return_type_expr != nil {
			check_expr_symbols(c, n.return_type_expr) or_return
			add_var_symbol(c, Token{text = "result"}) or_return
		}
		for param in n.parameters {
			add_var_symbol(c, param.name, true) or_return
			check_expr_symbols(c, param.type_expr) or_return
		}

		check_node_symbols(c, n.body) or_return

	case ^Parsed_Type_Declaration:
		if n.type_kind == .Alias {
			check_expr_symbols(c, n.type_expr) or_return
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
	// No symbols to check

	case ^Parsed_String_Literal_Expression:
	// No symbols to check

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
		if !contain_symbol(c, e.name) {
			err = Semantic_Error {
				kind    = .Unknown_Symbol,
				token   = e.name,
				details = fmt.tprintf("Unknown symbol: %s", e.name.text),
			}
		}

	case ^Parsed_Index_Expression:
		check_expr_symbols(c, e.left) or_return
		check_expr_symbols(c, e.index) or_return

	case ^Parsed_Dot_Expression:
		left_identifier := e.left.(^Parsed_Identifier_Expression)
		l := get_symbol(c, left_identifier.name) or_return

		class_scope: ^Semantic_Scope
		switch left_symbol in l {
		case string:
			assert(false)
		case Scope_Ref_Symbol:
			class_scope = get_class_scope_from_id(c.current, left_symbol.scope_id)
		case Var_Symbol:
			class_scope = get_class_scope_from_name(c.current, left_symbol.type_info.name)
		}
		// left_symbol := l.(Scope_Ref_Symbol)
		// class_scope := get_class_scope(c.current, left_symbol.scope_id)

		#partial switch a in e.selector {
		case ^Parsed_Identifier_Expression:
			if !contain_scoped_symbol(class_scope, a.name.text) {
				err = Semantic_Error {
					kind    = .Unknown_Symbol,
					token   = a.name,
					details = fmt.tprintf("Unknown Class field: %s", a.name.text),
				}
			}
		case ^Parsed_Call_Expression:
			// FIXME: Does not support Function literals
			fn_identifier := a.func.(^Parsed_Identifier_Expression)
			if !contain_scoped_symbol(class_scope, fn_identifier.name.text) {
				err = Semantic_Error {
					kind    = .Unknown_Symbol,
					token   = fn_identifier.name,
					details = fmt.tprintf("Unknown Class method: %s", fn_identifier.name.text),
				}
			}
			for arg in a.args {
				check_expr_symbols(c, arg) or_return
			}
		}

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

// Checked nodes take ownership of the Parsed Expressions and produce a Checked_Node
check_node_types :: proc(c: ^Checker, node: Parsed_Node) -> (result: Checked_Node, err: Error) {
	switch n in node {
	case ^Parsed_Expression_Statement:
		expr, _ := check_expr_types(c, n.expr) or_return
		result = new_clone(Checked_Expression_Statement{expr = expr})

	case ^Parsed_Block_Statement:
		block_stmt := new_clone(Checked_Block_Statement{nodes = make([dynamic]Checked_Node)})
		for block_node in n.nodes {
			node := check_node_types(c, block_node) or_return
			append(&block_stmt.nodes, node)
		}
		result = block_stmt

	case ^Parsed_Assignment_Statement:
		left, left_info := check_expr_types(c, n.left) or_return
		right, right_info := check_expr_types(c, n.right) or_return
		if !type_equal(c, left_info, right_info) {
			fmt.println(n.left, left_info)
			fmt.println(n.right, right_info)
			fmt.println(c.current.scope.id)
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = n.token,
				details = fmt.tprintf(
					"Left expression of type %s, right expression of type %s",
					left_info.name,
					right_info.name,
				),
			}
		}
		// The type info should always exist at this point,
		// but we will keep this as a sanity check for now

		result = new_clone(Checked_Assigment_Statement{token = n.token, left = left, right = right})


	case ^Parsed_If_Statement:
		condition_expr, condition_info := check_expr_types(c, n.condition) or_return
		if !is_truthy_type(condition_info) {
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = n.token,
				details = fmt.tprintf(
					"Expected %s, got %s",
					c.builtin_types[BOOL_ID].name,
					condition_info.name,
				),
			}
		}
		// push a new scope here
		body_node := check_node_types(c, n.body) or_return
		if_stmt := new_clone(
			Checked_If_Statement{token = n.token, condition = condition_expr, body = body_node},
		)
		if n.next_branch != nil {
			next_node := check_node_types(c, n.next_branch) or_return
			if_stmt.next_branch = next_node
		}
		result = if_stmt

	case ^Parsed_Range_Statement:
		//push scope
		low_expr, low_info := check_expr_types(c, n.low) or_return
		high_expr, high_info := check_expr_types(c, n.high) or_return
		if !type_equal(c, low_info, high_info) {
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = n.token,
				details = fmt.tprintf(
					"Low expression of type %s, High expression of type %s",
					low_info.name,
					high_info.name,
				),
			}
		}
		if !is_numerical_type(low_info) {
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = n.token,
				details = fmt.tprintf("Expected %s, got %s", c.builtin_types[NUMBER_ID].name, low_info.name),
			}
		}

		// add the newly created iterator to the scope
		body_node := check_node_types(c, n.body) or_return
		result = new_clone(
			Checked_Range_Statement{
				token = n.token,
				iterator_name = n.iterator_name,
				iterator_type_info = low_info,
				low = low_expr,
				high = high_expr,
				reverse = n.reverse,
				op = n.op,
				body = body_node,
			},
		)

	case ^Parsed_Import_Statement:
		assert(false, "Module not implemented yet")

	case ^Parsed_Var_Declaration:
		var_expr, var_info := check_expr_types(c, n.type_expr) or_return
		value_expr, value_info := check_expr_types(c, n.expr) or_return
		defer free_checked_expression(var_expr)

		// we check if the type needs to be infered
		if type_equal(c, var_info, c.builtin_types[UNTYPED_ID]) {
			// add the var to the environment's scope
			switch {
			case type_equal(c, value_info, c.builtin_types[UNTYPED_NUMBER_ID]):
				var_info = c.builtin_types[NUMBER_ID]
			case type_equal(c, value_info, c.builtin_types[UNTYPED_BOOL_ID]):
				var_info = c.builtin_types[BOOL_ID]
			case type_equal(c, value_info, c.builtin_types[UNTYPED_STRING_ID]):
				var_info = c.builtin_types[STRING_ID]
			case:
				var_info = value_info
			}
		} else {
			if !type_equal(c, var_info, value_info) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = n.token,
					details = fmt.tprintf("Expected %s, got %s", var_info.name, value_info.name),
				}
				return
			}
		}
		set_variable_type(c, n.identifier.text, var_info)
		result = new_clone(
			Checked_Var_Declaration{
				token = n.token,
				identifier = n.identifier,
				type_info = var_info,
				expr = value_expr,
				initialized = n.initialized,
			},
		)


	case ^Parsed_Fn_Declaration:

	case ^Parsed_Type_Declaration:
	}
	return
}

check_expr_types :: proc(c: ^Checker, expr: Parsed_Expression) -> (
	result: Checked_Expression,
	info: Type_Info,
	err: Error,
) {
	switch e in expr {
	case ^Parsed_Literal_Expression:
		#partial switch e.value.kind {
		case .Number:
			info = c.builtin_types[UNTYPED_NUMBER_ID]
		case .Boolean:
			info = c.builtin_types[UNTYPED_BOOL_ID]
		case:
			assert(
				false,
				"Probably erroneous path for Parsed_Literal_Expression in  check_expr_types procedure",
			)
		}
		result = new_clone(Checked_Literal_Expression{type_info = info, value = e.value})

	case ^Parsed_String_Literal_Expression:
		info = c.builtin_types[UNTYPED_STRING_ID]
		result = new_clone(Checked_String_Literal_Expression{type_info = info, value = e.value})

	case ^Parsed_Array_Literal_Expression:
		_, lit_type := check_expr_types(c, e.type_expr) or_return
		generic_id := lit_type.type_id_data.(Generic_Type_Info)
		inner_type := get_type_from_id(c, generic_id.spec_type_id)
		info = lit_type

		checked_arr := new_clone(
			Checked_Array_Literal_Expression{
				token = e.token,
				type_info = info,
				values = make([]Checked_Expression, len(e.values)),
			},
		)
		for element, i in e.values {
			elem_expr, elem_type := check_expr_types(c, element) or_return
			if !type_equal(c, inner_type, elem_type) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = e.token,
					details = fmt.tprintf("Expected %s, got %s", inner_type.name, elem_type.name),
				}
			}
			checked_arr.values[i] = elem_expr
		}
		result = checked_arr

	case ^Parsed_Unary_Expression:
		checked_unary := new_clone(Checked_Unary_Expression{token = e.token, op = e.op})
		checked_unary.expr, info = check_expr_types(c, e.expr) or_return
		checked_unary.type_info = info
		#partial switch e.op {
		// Parsed_Expression must be of "truthy" type
		case .Not_Op:
			if !is_truthy_type(info) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = e.token,
					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[BOOL_ID].name, info.name),
				}
			}

		// Parsed_Expression must be of numerical type
		case .Minus_Op:
			if !is_numerical_type(info) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = e.token,
					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[NUMBER_ID].name, info.name),
				}
			}
		case:
			assert(false)
		}
		result = checked_unary

	case ^Parsed_Binary_Expression:
		checked_binary := new_clone(Checked_Binary_Expression{token = e.token, op = e.op})
		left, left_info := check_expr_types(c, e.left) or_return
		right, right_info := check_expr_types(c, e.right) or_return
		if !type_equal(c, left_info, right_info) {
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = e.token,
				details = fmt.tprintf(
					"Left expression of type %s, right expression of type %s",
					left_info.name,
					right_info.name,
				),
			}
			return
		}

		#partial switch e.op {
		case .Minus_Op, .Plus_Op, .Mult_Op, .Div_Op, .Rem_Op:
			if !is_numerical_type(left_info) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = e.token,
					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[NUMBER_ID].name, left_info.name),
				}
			}
			info = left_info

		case .Greater_Op, .Greater_Eq_Op, .Lesser_Op, .Lesser_Eq_Op:
			if !is_numerical_type(left_info) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = e.token,
					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[NUMBER_ID].name, left_info.name),
				}
			}
			info = c.builtin_types[UNTYPED_BOOL_ID]

		case .Or_Op, .And_Op:
			if !is_truthy_type(left_info) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = e.token,
					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[BOOL_ID].name, left_info.name),
				}
			}
			info = left_info
		}
		checked_binary.left = left
		checked_binary.right = right
		checked_binary.type_info = info
		result = checked_binary

	case ^Parsed_Identifier_Expression:
		info = get_type_from_identifier(c, e.name)
		result = new_clone(Checked_Identifier_Expression{name = e.name, type_info = info})

	case ^Parsed_Index_Expression:
		checked_index := new_clone(Checked_Index_Expression{token = e.token})
		left, left_info := check_expr_types(c, e.left) or_return
		defer free_checked_expression(left)

		if left_info.type_id == ARRAY_ID {
			left_indentfier := left.(^Checked_Identifier_Expression)
			checked_index.left = left_indentfier.name
			checked_index.kind = .Array
			index, index_info := check_expr_types(c, e.index) or_return
			if !is_numerical_type(index_info) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = e.token,
					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[NUMBER_ID].name, index_info.name),
				}
				return
			}
			// Retrieve the Type_Info from the the element Type_ID
			elem_type := left_info.type_id_data.(Generic_Type_Info)
			info = get_type_from_id(c, elem_type.spec_type_id)
			checked_index.index = index
			checked_index.type_info = info
			result = checked_index
		} else {
			identifier := e.left.(^Parsed_Identifier_Expression)
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = e.token,
				details = fmt.tprintf("Cannot index %s of type %s", identifier.name.text, left_info.name),
			}
		}

	case ^Parsed_Dot_Expression:
		left_identifier := e.left.(^Parsed_Identifier_Expression)
		checked_dot := new_clone(Checked_Dot_Expression{token = e.token, left = left_identifier.name})

		// RULES:
		// 1. accessing fields on Class not allowed
		// 2. calling constructors from instance not allowed

		class_info: Type_Info
		name := left_identifier.name.text
		is_instance := false
		switch {
		case name == "self":
			is_instance = true
			symbol := get_symbol(c, left_identifier.name) or_return
			self_symbol := symbol.(Scope_Ref_Symbol)
			for class_name, scope_info in c.current.class_scopes {
				if self_symbol.scope_id == scope_info.scope_id {
					class_info = c.current.type_lookup[class_name]
					break
				}
			}

		case:
			if t, exist := c.current.type_lookup[name]; exist {
				class_info = t
			} else {
				is_instance = true
				class_info, _ = get_variable_type(c, name)
			}
		}

		class_def := class_info.type_id_data.(Class_Definition_Info)
		class_decl := get_class_decl(c.current, class_info.type_id)

		#partial switch selector in e.selector {
		case ^Parsed_Identifier_Expression:
			// Rule 1 check
			if is_instance {
				checked_dot.kind = .Instance_Field
				for field, i in class_decl.field_names {
					if field.text == selector.name.text {
						info = class_def.fields[i]
						break
					}
				}
				checked_dot.selector = new_clone(
					Checked_Identifier_Expression{name = selector.name, type_info = info},
				)
			} else {
				err = Semantic_Error {
					kind    = .Invalid_Class_Field_Access,
					token   = e.token,
					details = fmt.tprintf(
						"Cannot access fields of %s. %s is a class and not an instance of class",
						name,
						name,
					),
				}
				return
			}


		case ^Parsed_Call_Expression:
			call_identifier := selector.func.(^Parsed_Identifier_Expression)
			fn_decl, is_constructor := find_checked_constructor(class_decl, call_identifier.name)
			if !is_constructor {
				fn_decl, _ = find_checked_method(class_decl, call_identifier.name)
			}

			// Rule 2 check
			if is_instance {
				checked_dot.kind = .Instance_Call
				if is_constructor {
					err = Semantic_Error {
						kind    = .Invalid_Class_Constructor_Usage,
						token   = e.token,
						details = fmt.tprintf("%s is an instance of Class %s", name, class_info.name),
					}
					return
				}
			} else {
				checked_dot.kind = .Class
			}


			signature_info := fn_decl.type_info.type_id_data.(Fn_Signature_Info)
			info = signature_info.return_type_info^

			checked_call := new_clone(
				Checked_Call_Expression{
					token = selector.token,
					type_info = info,
					func = new_clone(
						Checked_Identifier_Expression{name = call_identifier.name, type_info = fn_decl.type_info},
					),
					args = make([]Checked_Expression, len(selector.args)),
				},
			)

			if len(signature_info.parameters) != len(selector.args) {
				err = Semantic_Error {
					kind    = .Invalid_Arg_Count,
					token   = e.token,
					details = fmt.tprintf(
						"Invalid Argument count, expected %i, got %i",
						len(signature_info.parameters),
						len(selector.args),
					),
				}
				return
			}
			for arg, i in selector.args {
				arg_expr, arg_info := check_expr_types(c, arg) or_return
				if !type_equal(c, arg_info, signature_info.parameters[i]) {
					err = Semantic_Error {
						kind    = .Mismatched_Types,
						token   = e.token,
						details = fmt.tprintf(
							"Expected %s, got %s",
							arg_info.name,
							signature_info.parameters[i].name,
						),
					}
					return
				}
				checked_call.args[i] = arg_expr
			}

			checked_dot.selector = checked_call
			checked_dot.type_info = info
		}

		result = checked_dot

	case ^Parsed_Call_Expression:
		checked_call := new_clone(
			Checked_Call_Expression{token = e.token, args = make([]Checked_Expression, len(e.args))},
		)

		// Get the signature from the environment
		fn_expr, fn_info := check_expr_types(c, e.func) or_return
		if fn_info.type_id == FN_ID && fn_info.type_kind == .Fn_Type {
			signature_info := fn_info.type_id_data.(Fn_Signature_Info)
			// Check that the call expression has the exact same amount of arguments
			// as the fn signature
			if len(signature_info.parameters) != len(e.args) {
				err = Semantic_Error {
					kind    = .Invalid_Arg_Count,
					token   = e.token,
					details = fmt.tprintf(
						"Invalid Argument count, expected %i, got %i",
						len(signature_info.parameters),
						len(e.args),
					),
				}
				return
			}
			for arg, i in e.args {
				arg_expr, arg_info := check_expr_types(c, arg) or_return
				if !type_equal(c, arg_info, signature_info.parameters[i]) {
					err = Semantic_Error {
						kind    = .Mismatched_Types,
						token   = e.token,
						details = fmt.tprintf(
							"Expected %s, got %s",
							arg_info.name,
							signature_info.parameters[i].name,
						),
					}
					return
				}
				checked_call.args[i] = arg_expr
			}
			info = signature_info.return_type_info^

			checked_call.type_info = info
			checked_call.func = fn_expr
			result = checked_call
		} else {
			// FIXME: return an error
			return
		}

	case ^Parsed_Array_Type_Expression:
		// FIXME: Probably does not support multi-dimensional arrays
		inner_expr, inner_info := check_expr_types(c, e.elem_type) or_return
		if inner_expr != nil {
			free_checked_expression(inner_expr)
		}
		info = Type_Info {
			name = "array",
			type_id = ARRAY_ID,
			type_kind = .Generic_Type,
			type_id_data = Generic_Type_Info{spec_type_id = inner_info.type_id},
		}
	}
	return
}
