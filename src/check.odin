package lily

import "core:fmt"

Type_ID :: distinct int
// INVALID_TYPE_ID :: -1
// NUMER_TYPE_ID :: 1
// NUMER_TYPE_ID :: 0
// NUMER_TYPE_ID :: 0
Builtin_Type_ID :: enum Type_ID {
	Invalid,
	Untyped,
	Number,
	Bool,
	String,
}

// A fat struct
Symbol :: struct {
	name:    string,
	kind:    Symbol_Kind,
	type_id: Type_ID,
	fn_spec: struct {
		parameters: [dynamic]Type_ID,
	},
}

Symbol_Kind :: enum {
	Basic, // number, bool, string
	Array,
	Fn,
}

Semantic_Scope :: struct {
	symbols: map[string]Symbol,
	parent:  ^Semantic_Scope,
}

new_scope :: proc() -> ^Semantic_Scope {
	scope := new(Semantic_Scope)
	scope.symbols = make(map[string]Symbol)
	return scope
}

delete_scope :: proc(s: ^Semantic_Scope) {
	delete(s.symbols)
	free(s)
}


Checker :: struct {
	builtins:     map[string]Symbol,
	scope:        ^Semantic_Scope,
	scope_depth:  int,
	next_type_id: int,
}

new_checker :: proc() -> (checker: ^Checker) {
	checker = new(Checker)
	checker.scope = new_scope()
	checker.builtins["untyped"] = Symbol {
		kind    = .Basic,
		type_id = Type_ID(Builtin_Type_ID.Untyped),
	}
	checker.builtins["number"] = Symbol {
		kind    = .Basic,
		type_id = Type_ID(Builtin_Type_ID.Number),
	}
	checker.builtins["bool"] = Symbol {
		kind    = .Basic,
		type_id = Type_ID(Builtin_Type_ID.Bool),
	}
	checker.builtins["string"] = Symbol {
		kind    = .Basic,
		type_id = Type_ID(Builtin_Type_ID.String),
	}

	checker.next_type_id = len(Builtin_Type_ID)
	return
}

push_scope :: proc(c: ^Checker) {
	scope := new_scope()
	scope.parent = c.scope
	c.scope = scope
	c.scope_depth += 1
}

pop_scope :: proc(c: ^Checker) {
	s := c.scope
	c.scope = s.parent
	delete_scope(s)
	c.scope_depth -= 1
}

find_symbol :: proc(c: ^Checker, name: string) -> (result: Symbol, err: Error) {
	if symbol, exist := c.builtins[name]; exist {
		result = symbol
		return
	}
	current := c.scope
	for current != nil {
		if symbol, exist := current.symbols[name]; exist {
			result = symbol
			return
		} else {
			current = current.parent
			continue
		}
	}
	err = Semantic_Error {
		kind    = .Unknown_Symbol,
		details = fmt.tprintf("Unknown symbol: %s", name),
	}
	return
}

contain_symbol :: proc(c: ^Checker, name: string) -> bool {
	if _, exist := c.builtins[name]; exist {
		return true
	}
	// Check the scope tree for the symbol
	current := c.scope
	for current != nil {
		if _, exist := current.symbols[name]; exist {
			return true
		} else {
			current = current.parent
			continue
		}
	}
	return false
}

add_symbol :: proc(c: ^Checker, symbol: Symbol) -> (err: Error) {
	if !contain_symbol(c, symbol.name) {
		c.scope.symbols[symbol.name] = symbol
	} else {
		err = Semantic_Error {
			kind    = .Redeclared_Symbol,
			details = fmt.tprintf("Redeclaration of '%s'", symbol.name),
		}
	}
	return
}

update_symbol :: proc(c: ^Checker, name: string, symbol: Symbol) -> (err: Error) {
	if contain_symbol(c, name) {
		c.scope.symbols[name] = symbol
	} else {
		err = Semantic_Error {
			kind    = .Redeclared_Symbol,
			details = fmt.tprintf("Unkown symbol: %s'", symbol.name),
		}
	}
	return
}

check_nodes :: proc(c: ^Checker, nodes: []Node) -> (err: Error) {
	// Gather all the function definitions
	for node in nodes {
		#partial switch n in node {
		case ^Fn_Declaration:
			return_symbol := check_expr_type(c, n.return_type_expr) or_return
			fn_symbol := Symbol {
				name = n.identifier,
				kind = .Fn,
				type_id = return_symbol.type_id,
				fn_spec = {parameters = make([dynamic]Type_ID)},
			}
			for i in 0 ..< n.param_count {
				param_symbol := check_expr_type(c, n.parameters[i].type_expr) or_return
				append(&fn_symbol.fn_spec.parameters, param_symbol.type_id)
			}
			add_symbol(c, fn_symbol) or_return
		}
	}
	// Update the functions signatures
	// for node in nodes {
	// 	#partial switch n in node {
	// 	case ^Fn_Declaration:
	// 		add_symbol(c, Symbol{name = n.identifier}) or_return
	// 	}
	// }

	for node in nodes {
		check_node(c, node) or_return
	}
	return
}

check_node :: proc(c: ^Checker, node: Node) -> (err: Error) {
	switch n in node {
	case ^Expression_Statement:
		check_node_symbols(c, n) or_return
		check_node_type(c, n) or_return

	case ^Block_Statement:
		check_node_symbols(c, n) or_return
		check_node_type(c, n) or_return

	case ^Assignment_Statement:
		check_node_symbols(c, n) or_return
		check_node_type(c, n) or_return

	case ^If_Statement:
		push_scope(c)
		defer pop_scope(c)
		check_node_symbols(c, n) or_return
		check_node_type(c, n) or_return

	case ^Range_Statement:
		push_scope(c)
		defer pop_scope(c)
		check_node_symbols(c, n) or_return
		check_node_type(c, n) or_return

	case ^Var_Declaration:
		check_node_symbols(c, n) or_return
		check_node_type(c, n) or_return

	case ^Fn_Declaration:
		push_scope(c)
		defer pop_scope(c)
		check_node_symbols(c, n) or_return
		check_node_type(c, n) or_return
	}
	return
}

// Check for symbol error and add the newly declared symbols to the checker
check_node_symbols :: proc(c: ^Checker, node: Node) -> (err: Error) {
	switch n in node {
	case ^Expression_Statement:
		check_expr_symbols(c, n.expr) or_return

	case ^Block_Statement:
		for block_node in n.nodes {
			check_node_symbols(c, block_node) or_return
		}

	case ^Assignment_Statement:
		check_expr_symbols(c, n.left) or_return
		check_expr_symbols(c, n.right) or_return

	case ^If_Statement:
		check_expr_symbols(c, n.condition) or_return
		check_node_symbols(c, n.body) or_return
		if n.next_branch != nil {
			check_node_symbols(c, n.next_branch) or_return
		}

	case ^Range_Statement:
		if contain_symbol(c, n.iterator_name) {
			err = Semantic_Error {
				kind    = .Redeclared_Symbol,
				token   = n.token,
				details = fmt.tprintf("Redeclaration of '%s'", n.iterator_name),
			}
			return
		}
		check_expr_symbols(c, n.low) or_return
		check_expr_symbols(c, n.high) or_return
		check_node_symbols(c, n.body) or_return

	case ^Var_Declaration:
		if contain_symbol(c, n.identifier) {
			err = Semantic_Error {
				kind    = .Redeclared_Symbol,
				token   = n.token,
				details = fmt.tprintf("Redeclaration of '%s'", n.identifier),
			}
			return
		}
		check_expr_symbols(c, n.type_expr) or_return
		check_expr_symbols(c, n.expr) or_return
		add_symbol(c, Symbol{name = n.identifier}) or_return

	case ^Fn_Declaration:
		// No need to check for function symbol declaration since 
		// functions can only be declared at the file scope
		add_symbol(c, Symbol{name = "result"})
		for param in n.parameters[:n.param_count] {
			if contain_symbol(c, param.name) {
				err = Semantic_Error {
					kind    = .Redeclared_Symbol,
					// token   = n.token,
					details = fmt.tprintf("Redeclaration of '%s'", param.name),
				}
				return
			} else {
				add_symbol(c, Symbol{name = param.name})
			}
			check_expr_symbols(c, param.type_expr) or_return
		}
		check_node_symbols(c, n.body) or_return
		check_expr_symbols(c, n.return_type_expr) or_return

	}
	return
}

check_node_type :: proc(c: ^Checker, node: Node) -> (err: Error) {
	switch n in node {
	case ^Expression_Statement:
		check_expr_type(c, n.expr) or_return

	case ^Block_Statement:
		for block_node in n.nodes {
			check_node_type(c, block_node) or_return
		}

	case ^Assignment_Statement:
		left_symbol := check_expr_type(c, n.left) or_return
		right_symbol := check_expr_type(c, n.right) or_return
		if left_symbol.type_id != right_symbol.type_id {
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = n.token,
				details = fmt.tprintf("Unable to assign %i to %i", left_symbol.type_id, right_symbol.type_id),
			}
		}

	case ^If_Statement:
		condition_symbol := check_expr_type(c, n.condition) or_return
		if condition_symbol.type_id != Type_ID(Builtin_Type_ID.Bool) {
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = n.token,
				details = fmt.tprintf("If statement condition isn't of type %i", Type_ID(Builtin_Type_ID.Bool)),
			}
		}
		check_node_type(c, n.body) or_return
		if n.next_branch != nil {
			check_node_type(c, n.next_branch) or_return
		}

	case ^Range_Statement:
		l_symbol := check_expr_type(c, n.low) or_return
		h_symbol := check_expr_type(c, n.high) or_return
		n_id := Type_ID(Builtin_Type_ID.Number)
		if l_symbol.type_id != n_id || h_symbol.type_id != n_id {
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = n.token,
				details = fmt.tprintf(
					"Range expression components need to be of type %i",
					Type_ID(Builtin_Type_ID.Bool),
				),
			}
		}

	case ^Var_Declaration:
		type_symbol := check_expr_type(c, n.type_expr) or_return
		if type_symbol.type_id == Type_ID(Builtin_Type_ID.Untyped) {
			type_symbol = check_expr_type(c, n.expr) or_return
			update_symbol(c, n.identifier, type_symbol) or_return
		} else {
			expr_symbol := check_expr_type(c, n.expr) or_return
			if type_symbol.type_id != expr_symbol.type_id {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = n.token,
					details = fmt.tprintf("Expected %i, got %i", type_symbol.type_id, expr_symbol.type_id),
				}
			}
		}

	case ^Fn_Declaration:
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
		check_expr_symbols(c, e.type_expr) or_return
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
				details = fmt.tprintf("Unknown symbol: %s", e.name),
			}
		}

	case ^Index_Expression:
		check_expr_symbols(c, e.left) or_return
		check_expr_symbols(c, e.index) or_return

	case ^Call_Expression:
		check_expr_symbols(c, e.func) or_return
		for i in 0 ..< e.arg_count {
			check_expr_symbols(c, e.args[i]) or_return
		}

	case ^Array_Type:
		check_expr_symbols(c, e.elem_type) or_return

	}
	return
}

check_expr_type :: proc(c: ^Checker, expr: Expression) -> (result: Symbol, err: Error) {
	switch e in expr {
	case ^Literal_Expression:
		switch e.value.kind {
		case .Nil:

		case .Number:
			result = c.builtins["number"]
		case .Boolean:
			result = c.builtins["bool"]
		case .Object_Ref:
			assert(false, "Invalid branch")
		}

	case ^String_Literal_Expression:
		result = c.builtins["string"]

	case ^Array_Literal_Expression:
		elem_symbol := check_expr_type(c, e.type_expr) or_return
		result = Symbol {
			kind    = .Array,
			type_id = elem_symbol.type_id,
		}
		for element in e.values {
			symbol := check_expr_type(c, element) or_return
			if result.type_id != symbol.type_id {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = e.type_expr.(^Array_Type).token,
					details = fmt.tprintf(
						"Invalid array element type. Expected %i, got %i",
						result.type_id,
						symbol.type_id,
					),
				}
				return
			}
		}

	case ^Unary_Expression:
		result = check_expr_type(c, e.expr) or_return

	case ^Binary_Expression:
		left := check_expr_type(c, e.left) or_return
		right := check_expr_type(c, e.right) or_return
		if left.type_id != right.type_id {
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = e.token,
				details = fmt.tprintf("Expected %i, got %i", left.type_id, right.type_id),
			}
			return
		}
		#partial switch e.op {
		case .Minus_Op, .Plus_Op, .Mult_Op, .Div_Op, .Rem_Op:
			if left.type_id != Type_ID(Builtin_Type_ID.Number) {
				err = Semantic_Error {
					kind    = .Invalid_Type_Operation,
					token   = e.token,
					details = fmt.tprintf("Invalid operation on type %i", left.type_id),
				}
			}
		case .Or_Op, .And_Op:
			if left.type_id != Type_ID(Builtin_Type_ID.Bool) {
				err = Semantic_Error {
					kind    = .Invalid_Type_Operation,
					token   = e.token,
					details = fmt.tprintf("Invalid operation on type %i", left.type_id),
				}
			}
		}
		result = left

	case ^Identifier_Expression:
		result = find_symbol(c, e.name) or_return

	case ^Index_Expression:
		result = check_expr_type(c, e.left) or_return
		index_symbol := check_expr_type(c, e.index) or_return
		if index_symbol.type_id != Type_ID(Builtin_Type_ID.Number) {
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = e.token,
				details = fmt.tprintf(
					"Expected %i, got %i",
					Type_ID(Builtin_Type_ID.Number),
					index_symbol.type_id,
				),
			}
		}

	case ^Call_Expression:
		#partial switch fn in e.func {
		case ^Identifier_Expression:
			fn_symbol := find_symbol(c, fn.name) or_return
			for i in 0 ..< e.arg_count {
				arg_symbol := check_expr_type(c, e.args[i]) or_return
				if fn_symbol.fn_spec.parameters[i] != arg_symbol.type_id {
					err = Semantic_Error {
						kind    = .Mismatched_Types,
						token   = e.token,
						details = fmt.tprintf(
							"Expected %i, got %i",
							fn_symbol.fn_spec.parameters[i],
							arg_symbol.type_id,
						),
					}
				}
			}
			result = fn_symbol
		case:
			assert(false)
		}

	case ^Array_Type:
		result = check_expr_type(c, e.elem_type) or_return

	}
	return
}
