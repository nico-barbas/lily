package lily

import "core:fmt"

Checker :: struct {
	modules:         [dynamic]^Checked_Module,
	builtin_symbols: [5]string,
	builtin_types:   [BUILT_IN_ID_COUNT]Type_Info,
	type_id_ptr:     Type_ID,
	current:         ^Checked_Module,
}

new_checker :: proc() -> ^Checker {
	c := new_clone(
		Checker{
			modules = make([dynamic]^Checked_Module),
			builtin_symbols = {"untyped", "number", "string", "bool", "array"},
			type_id_ptr = BUILT_IN_ID_COUNT,
		},
	)
	c.builtin_types[UNTYPED_ID] = UNTYPED_INFO
	c.builtin_types[UNTYPED_NUMBER_ID] = UNTYPED_NUMBER_INFO
	c.builtin_types[UNTYPED_BOOL_ID] = UNTYPED_BOOL_INFO
	c.builtin_types[UNTYPED_STRING_ID] = STRING_INFO
	c.builtin_types[NUMBER_ID] = NUMBER_INFO
	c.builtin_types[BOOL_ID] = BOOL_INFO
	c.builtin_types[STRING_ID] = STRING_INFO
	c.builtin_types[FN_ID] = FN_INFO
	c.builtin_types[ARRAY_ID] = ARRAY_INFO
	return c
}

checked_expresssion :: proc(expr: Expression, info: Type_Info) -> Checked_Expression {
	return {expr = expr, type_info = info}
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
				if name == token.text {
					result = name
					return
				}
			case Composite_Symbol:
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

add_symbol :: proc(c: ^Checker, token: Token, shadow := false) -> Error {
	return add_scoped_symbol(c.current.scope, token, shadow)
}

add_composite_symbol :: proc(
	c: ^Checker,
	token: Token,
	scope_id: Scope_ID,
	shadow := false,
) -> Error {
	return add_scoped_composite_symbol(c.current.scope, token, scope_id, shadow)
}

set_variable_type :: proc(c: ^Checker, name: string, t: Type_Info) {
	c.current.scope.variable_types[name] = t
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
		if info, contains := current.variable_types[name]; contains {
			result = info
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
	module = new_checked_module()
	append(&c.modules, module)
	c.current = module
	// The type symbols need to be added first
	for node in m.nodes {
		if n, ok := node.(^Parsed_Type_Declaration); ok {
			switch n.type_kind {
			case .Alias:
				add_symbol(c, n.identifier) or_return
			case .Class:
				scope_id := hash_scope_id(c.current, n.identifier)
				add_composite_symbol(c, n.identifier, scope_id) or_return
				push_scope(c.current, n.identifier)
				defer pop_scope(c.current)
				add_class_scope(c.current, scope_id)
				add_composite_symbol(c, Token{text = "self"}, scope_id, true) or_return
				for field in n.fields {
					add_symbol(c, field.name) or_return
				}
				for constructor in n.constructors {
					add_symbol(c, constructor.identifier) or_return
				}
				for method in n.methods {
					add_symbol(c, method.identifier) or_return
				}
			}
		}
	}

	for node in m.nodes {
		#partial switch n in node {
		case ^Parsed_Var_Declaration:
			add_symbol(c, n.identifier) or_return
		case ^Parsed_Fn_Declaration:
			add_symbol(c, n.identifier) or_return
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
				parent_type := check_expr_types(c, n.type_expr) or_return
				update_type_alias(c, n.identifier, parent_type.type_id)
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
				enter_child_scope(c.current, n.identifier) or_return
				defer pop_scope(c.current)
				for field, i in n.fields {
					field_type := check_expr_types(c, field.type_expr) or_return
					class_info.fields[i] = field_type
					class_decl.field_names[i] = field.name
					set_variable_type(c, field.name.text, field_type)
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
					constr_signature := Fn_Signature_Info {
						parameters     = make([]Type_Info, len(constructor.parameters)),
						return_type_id = class_decl.type_info.type_id,
					}
					enter_child_scope(c.current, constructor.identifier) or_return
					defer pop_scope(c.current)
					for param, i in constructor.parameters {
						constr_decl.param_names[i] = param.name
						param_type := check_expr_types(c, param.type_expr) or_return
						constr_signature.parameters[i] = param_type
						set_variable_type(c, param.name.text, param_type)
					}
					// constr_decl.body = check_node_types(c, constructor.body) or_return
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
					method_signature := Fn_Signature_Info {
						parameters     = make([]Type_Info, len(method.parameters)),
						return_type_id = class_decl.type_info.type_id,
					}
					enter_child_scope(c.current, method.identifier) or_return
					defer pop_scope(c.current)
					for param, i in method.parameters {
						method_decl.param_names[i] = param.name
						param_type := check_expr_types(c, param.type_expr) or_return
						method_signature.parameters[i] = param_type
						set_variable_type(c, param.name.text, param_type)
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

				set_variable_type(c, "self", t)
				for constructor, i in n.constructors {
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
			fn_signature := Fn_Signature_Info {
				parameters = make([]Type_Info, len(n.parameters)),
			}

			enter_child_scope(c.current, n.identifier) or_return
			defer pop_scope(c.current)

			return_type := check_expr_types(c, n.return_type_expr) or_return
			set_variable_type(c, "result", return_type)
			for param, i in n.parameters {
				fn_decl.param_names[i] = param.name
				param_type := check_expr_types(c, param.type_expr) or_return
				fn_signature.parameters[i] = param_type
				set_variable_type(c, param.name.text, param_type)
			}
			fn_decl.body = check_node_types(c, n.body) or_return
			fn_signature.return_type_id = return_type.type_id
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

	case ^Parsed_Var_Declaration:
		if c.current.scope_depth > 0 {
			// if contain_symbol(c, m, n.identifier) {
			// 	err = Semantic_Error {
			// 		kind    = .Redeclared_Symbol,
			// 		token   = n.identifier,
			// 		details = fmt.tprintf("Redeclaration of '%s'", n.identifier.text),
			// 	}
			// 	return
			// }
			add_symbol(c, n.identifier) or_return
		}
		check_expr_symbols(c, n.type_expr) or_return
		check_expr_symbols(c, n.expr) or_return

	case ^Parsed_Fn_Declaration:
		// No need to check for function symbol declaration since 
		// functions can only be declared at the file scope
		push_scope(c.current, n.identifier)
		defer pop_scope(c.current)
		add_symbol(c, Token{text = "result"}) or_return
		for param in n.parameters {
			// if contain_symbol(c, m, param.name) {
			// 	err = Semantic_Error {
			// 		kind    = .Redeclared_Symbol,
			// 		token   = param.name,
			// 		details = fmt.tprintf("Redeclaration of '%s'", param.name.text),
			// 	}
			// 	return
			// }
			add_symbol(c, param.name, true) or_return
			check_expr_symbols(c, param.type_expr) or_return
		}
		check_expr_symbols(c, n.return_type_expr) or_return
		check_node_symbols(c, n.body) or_return

	case ^Parsed_Type_Declaration:
		if n.type_kind == .Alias {
			check_expr_symbols(c, n.type_expr) or_return
		} else {
			enter_child_scope(c.current, n.identifier) or_return
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

check_expr_symbols :: proc(c: ^Checker, expr: Expression) -> (err: Error) {
	switch e in expr {
	case ^Literal_Expression:
	// No symbols to check

	case ^String_Literal_Expression:
	// No symbols to check

	case ^Array_Literal_Expression:
		// Check that the array specialization is of a known type
		check_expr_symbols(c, e.type_expr) or_return
		// Check all the inlined elements of the array
		for value in e.values {
			check_expr_symbols(c, value) or_return
		}

	case ^Unary_Expression:
		check_expr_symbols(c, e.expr) or_return

	case ^Binary_Expression:
		check_expr_symbols(c, e.left) or_return
		check_expr_symbols(c, e.right) or_return

	case ^Identifier_Expression:
		if !contain_symbol(c, e.name) {
			err = Semantic_Error {
				kind    = .Unknown_Symbol,
				token   = e.name,
				details = fmt.tprintf("Unknown symbol: %s", e.name.text),
			}
		}

	case ^Index_Expression:
		check_expr_symbols(c, e.left) or_return
		check_expr_symbols(c, e.index) or_return

	case ^Dot_Expression:
		left_identifier := e.left.(^Identifier_Expression)
		l := get_symbol(c, left_identifier.name) or_return
		left_symbol := l.(Composite_Symbol)
		class_scope := get_class_scope(c.current, left_symbol.scope_ip)

		#partial switch a in e.accessor {
		case ^Identifier_Expression:
			if !contain_scoped_symbol(class_scope, a.name.text) {
				err = Semantic_Error {
					kind    = .Unknown_Symbol,
					token   = a.name,
					details = fmt.tprintf("Unknown Class field: %s", a.name.text),
				}
			}
		case ^Call_Expression:
			// FIXME: Does not support Function literals
			fn_identifier := a.func.(^Identifier_Expression)
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

	case ^Call_Expression:
		check_expr_symbols(c, e.func) or_return
		for arg in e.args {
			check_expr_symbols(c, arg) or_return
		}

	case ^Array_Type_Expression:
		check_expr_symbols(c, e.elem_type) or_return

	}
	return
}


// FIXME: Need a way to extract the token from an expression, either at an
// Parser level or at a Checker level
// Checked nodes take ownership of the Parsed Expressions and produce a Checked_Node
check_node_types :: proc(c: ^Checker, node: Parsed_Node) -> (result: Checked_Node, err: Error) {
	switch n in node {
	case ^Parsed_Expression_Statement:
		t := check_expr_types(c, n.expr) or_return
		result = new_clone(Checked_Expression_Statement{expr = checked_expresssion(n.expr, t)})

	case ^Parsed_Block_Statement:
		block_stmt := new_clone(Checked_Block_Statement{nodes = make([dynamic]Checked_Node)})
		for block_node in n.nodes {
			node := check_node_types(c, block_node) or_return
			append(&block_stmt.nodes, node)
		}
		result = block_stmt

	case ^Parsed_Assignment_Statement:
		left := check_expr_types(c, n.left) or_return
		right := check_expr_types(c, n.right) or_return
		if !type_equal(c, left, right) {
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = n.token,
				details = fmt.tprintf(
					"Left expression of type %s, right expression of type %s",
					left.name,
					right.name,
				),
			}
		}
		// The type info should always exist at this point,
		// but we will keep this as a sanity check for now

		result = new_clone(
			Checked_Assigment_Statement{
				token = n.token,
				left = checked_expresssion(n.left, left),
				right = checked_expresssion(n.right, right),
			},
		)


	case ^Parsed_If_Statement:
		condition_type := check_expr_types(c, n.condition) or_return
		if !is_truthy_type(condition_type) {
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = n.token,
				details = fmt.tprintf(
					"Expected %s, got %s",
					c.builtin_types[BOOL_ID].name,
					condition_type.name,
				),
			}
		}
		// push a new scope here
		body_node := check_node_types(c, n.body) or_return
		if_stmt := new_clone(
			Checked_If_Statement{
				token = n.token,
				condition = checked_expresssion(n.condition, condition_type),
				body = body_node,
			},
		)
		if n.next_branch != nil {
			next_node := check_node_types(c, n.next_branch) or_return
			if_stmt.next_branch = next_node
		}
		result = if_stmt

	case ^Parsed_Range_Statement:
		//push scope
		low := check_expr_types(c, n.low) or_return
		high := check_expr_types(c, n.high) or_return
		if !type_equal(c, low, high) {
			err = Semantic_Error {
				kind  = .Mismatched_Types,
				token = n.token,
			}
		}
		// add the newly created iterator to the scope
		body_node := check_node_types(c, n.body) or_return
		result = new_clone(
			Checked_Range_Statement{
				token = n.token,
				iterator_name = n.iterator_name,
				iterator_type_info = low,
				low = checked_expresssion(n.low, low),
				high = checked_expresssion(n.high, high),
				reverse = n.reverse,
				op = n.op,
				body = body_node,
			},
		)

	case ^Parsed_Var_Declaration:
		var_type := check_expr_types(c, n.type_expr) or_return
		value_type := check_expr_types(c, n.expr) or_return

		// we check if the type needs to be infered
		if type_equal(c, var_type, c.builtin_types[UNTYPED_ID]) {
			// add the var to the environment's scope
			switch {
			case type_equal(c, value_type, c.builtin_types[UNTYPED_NUMBER_ID]):
				var_type = c.builtin_types[NUMBER_ID]
			case type_equal(c, value_type, c.builtin_types[UNTYPED_BOOL_ID]):
				var_type = c.builtin_types[BOOL_ID]
			case type_equal(c, value_type, c.builtin_types[UNTYPED_STRING_ID]):
				var_type = c.builtin_types[STRING_ID]
			case:
				var_type = value_type
			}
			set_variable_type(c, n.identifier.text, var_type)
		} else {
			if !type_equal(c, var_type, value_type) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = n.token,
					details = fmt.tprintf("Expected %s, got %s", var_type.name, value_type.name),
				}
			}
		}
		set_variable_type(c, n.identifier.text, var_type)
		result = new_clone(
			Checked_Var_Declaration{
				token = n.token,
				identifier = n.identifier,
				type_info = var_type,
				expr = checked_expresssion(n.expr, value_type),
				initialized = n.initialized,
			},
		)


	case ^Parsed_Fn_Declaration:

	case ^Parsed_Type_Declaration:
	}
	return
}

check_expr_types :: proc(c: ^Checker, expr: Expression) -> (result: Type_Info, err: Error) {
	switch e in expr {
	case ^Literal_Expression:
		#partial switch e.value.kind {
		case .Number:
			result = c.builtin_types[UNTYPED_NUMBER_ID]
		case .Boolean:
			result = c.builtin_types[UNTYPED_BOOL_ID]
		case:
			assert(false, "Probably erroneous path for Literal_Expression in  check_expr_types procedure")
		}

	case ^String_Literal_Expression:
		result = c.builtin_types[UNTYPED_STRING_ID]

	case ^Array_Literal_Expression:
		lit_type := check_expr_types(c, e.type_expr) or_return
		generic_id := lit_type.type_id_data.(Generic_Type_Info)
		inner_type := get_type_from_id(c, generic_id.spec_type_id)
		fmt.println(inner_type)
		result = lit_type
		for element in e.values {
			elem_type := check_expr_types(c, element) or_return
			if !type_equal(c, inner_type, elem_type) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = e.token,
					details = fmt.tprintf("Expected %s, got %s", inner_type.name, elem_type.name),
				}
			}
		}

	case ^Unary_Expression:
		result = check_expr_types(c, e.expr) or_return
		#partial switch e.op {
		// Expression must be of "truthy" type
		case .Not_Op:
			if !is_truthy_type(result) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = e.token,
					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[BOOL_ID].name, result.name),
				}
			}

		// Expression must be of numerical type
		case .Minus_Op:
			if !is_numerical_type(result) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = e.token,
					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[NUMBER_ID].name, result.name),
				}
			}
		case:
			assert(false)
		}

	case ^Binary_Expression:
		left := check_expr_types(c, e.left) or_return
		right := check_expr_types(c, e.right) or_return
		if !type_equal(c, left, right) {
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = e.token,
				details = fmt.tprintf(
					"Left expression of type %s, right expression of type %s",
					left.name,
					right.name,
				),
			}
			return
		}

		#partial switch e.op {
		case .Minus_Op, .Plus_Op, .Mult_Op, .Div_Op, .Rem_Op:
			if !is_numerical_type(left) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = e.token,
					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[NUMBER_ID].name, result.name),
				}
			}
			result = left

		case .Greater_Op, .Greater_Eq_Op, .Lesser_Op, .Lesser_Eq_Op:
			if !is_numerical_type(left) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = e.token,
					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[NUMBER_ID].name, result.name),
				}
			}
			result = c.builtin_types[UNTYPED_BOOL_ID]

		case .Or_Op, .And_Op:
			if !is_truthy_type(left) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = e.token,
					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[BOOL_ID].name, result.name),
				}
			}
			result = left
		}

	case ^Identifier_Expression:
		result = get_type_from_identifier(c, e.name)

	case ^Index_Expression:
		left := check_expr_types(c, e.left) or_return
		if left.type_id == ARRAY_ID {
			index := check_expr_types(c, e.index) or_return
			if !is_numerical_type(index) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = e.token,
					details = fmt.tprintf("Expected %s, got %s", c.builtin_types[NUMBER_ID].name, result.name),
				}
				return
			}
			elem_type := left.type_id_data.(Generic_Type_Info)
			// Retrieve the Type_Info from the the element Type_ID
			result = get_type_from_id(c, elem_type.spec_type_id)
		} else {
			identifier := e.left.(^Identifier_Expression)
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = e.token,
				details = fmt.tprintf("Cannot index %s of type %s", identifier.name.text, left.name),
			}
		}

	case ^Dot_Expression:
		class_info := check_expr_types(c, e.left) or_return
		class_def := class_info.type_id_data.(Class_Definition_Info)
		class_decl := get_class_decl(c.current, class_info.type_id)
		#partial switch a in e.accessor {
		case ^Identifier_Expression:
			for field, i in class_decl.field_names {
				if field.text == a.name.text {
					result = class_def.fields[i]
					return
				}
			}
		case ^Call_Expression:
			for constructor, i in class_decl.constructors {
				call_name := a.func.(^Identifier_Expression)
				if constructor.identifier.text == call_name.name.text {
					result = class_info
					return
				}
			}
			for method, i in class_decl.methods {
				call_name := a.func.(^Identifier_Expression)
				if method.identifier.text == call_name.name.text {
					result = class_def.methods[i]
					return
				}
			}
		}

	case ^Call_Expression:
		// Get the signature from the environment
		fn_signature := check_expr_types(c, e.func) or_return
		if fn_signature.type_id == FN_ID && fn_signature.type_kind == .Fn_Type {
			signature_info := fn_signature.type_id_data.(Fn_Signature_Info)
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
				arg_type := check_expr_types(c, arg) or_return
				if !type_equal(c, arg_type, signature_info.parameters[i]) {
					err = Semantic_Error {
						kind    = .Mismatched_Types,
						token   = e.token,
						details = fmt.tprintf(
							"Expected %s, got %s",
							arg_type.name,
							signature_info.parameters[i].name,
						),
					}
					return
				}
			}
			result = get_type_from_id(c, signature_info.return_type_id)
		} else {
			// FIXME: return an error
		}

	case ^Array_Type_Expression:
		inner_type := check_expr_types(c, e.elem_type) or_return
		result = Type_Info {
			name = "array",
			type_id = ARRAY_ID,
			type_kind = .Generic_Type,
			type_id_data = Generic_Type_Info{spec_type_id = inner_type.type_id},
		}
	}
	return
}
