package lily
// - Disallow function declaration inside functions scope 

// Stategy:
// - Add all the file scope name declarations
// - Check the inner expressions and scopes

NIL_SYMBOL: Type_Symbol : "nil"
NUMBER_SYMBOL: Type_Symbol : "number"
BOOL_SYMBOL: Type_Symbol : "bool"
STRING_SYMBOL: Type_Symbol : "string"

reserved_keywords :: [?]string{"result"}

Symbol :: union {
	Type_Symbol,
	Identifier_Symbol,
	Fn_Symbol,
}

Type_Symbol :: distinct string

Identifier_Symbol :: struct {
	name:        string,
	type_symbol: Type_Symbol,
}

Fn_Symbol :: struct {
	name:          string,
	param_symbols: [5]Identifier_Symbol,
	param_count:   int,
	return_symbol: Type_Symbol,
}

Semantic_Scope :: struct {
	symbols: map[string]Symbol,
	parent:  ^Semantic_Scope,
}

Checker :: struct {
	builtins:    map[string]Symbol,
	scope:       ^Semantic_Scope,
	scope_depth: int,
}

new_checker :: proc() -> (checker: ^Checker) {
	checker = new(Checker)
	checker.builtins = make(map[string]Symbol)
	checker.builtins["nil"] = NIL_SYMBOL
	checker.builtins["number"] = NUMBER_SYMBOL
	checker.builtins["bool"] = BOOL_SYMBOL
	checker.builtins["string"] = STRING_SYMBOL
	checker.scope = new_scope()
	return
}

delete_checker :: proc(c: ^Checker) {
	recurse_delete_scope :: proc(s: ^Semantic_Scope) {
		if s.parent != nil {
			recurse_delete_scope(s.parent)
		}
		delete_scope(s)
	}
	delete(c.builtins)
	recurse_delete_scope(c.scope)
	free(c)
}

check_program :: proc(c: ^Checker, program: []Node) -> Error {
	// Check the file scope
	for node in program {
		#partial switch n in node {
		case ^Var_Declaration:
			id_symbol := Identifier_Symbol {
				name        = n.identifier,
				type_symbol = Type_Symbol(n.type_name),
			}
			add_symbol(c, id_symbol) or_return
		case ^Fn_Declaration:
			fn_symbol := Fn_Symbol {
				name          = n.identifier,
				param_count   = n.param_count,
				return_symbol = Type_Symbol(n.return_type_name),
			}
			for i in 0 ..< n.param_count {
				fn_symbol.param_symbols[i] = Identifier_Symbol {
					name        = n.parameters[i].name,
					type_symbol = Type_Symbol(n.parameters[i].type_name),
				}
			}
			add_symbol(c, fn_symbol) or_return
		}
	}

	for node in program {
		check_node(c, node) or_return
	}
	return nil
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

new_scope :: proc() -> ^Semantic_Scope {
	scope := new(Semantic_Scope)
	scope.symbols = make(map[string]Symbol)
	return scope
}

delete_scope :: proc(s: ^Semantic_Scope) {
	delete(s.symbols)
	free(s)
}

is_reserved_keyword :: proc(name: string) -> (reserved: bool) {
	for word in reserved_keywords {
		if word == name {
			reserved = true
			break
		}
	}
	return
}

find_symbol :: proc(c: ^Checker, name: string) -> (result: Symbol, err: Error) {
	err = nil
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
	err = Semantic_Error.Unknown_Symbol
	return
}

contain_symbol_by_name :: proc(c: ^Checker, name: string) -> bool {
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
	err = nil
	name: string
	switch s in symbol {
	case Type_Symbol:
		name = string(s)
	case Identifier_Symbol:
		name = s.name
	case Fn_Symbol:
		name = s.name
	}
	if !contain_symbol_by_name(c, name) {
		c.scope.symbols[name] = symbol
	} else {
		err = Semantic_Error.Redeclared_Symbol
	}
	return
}

swap_symbol :: proc(c: ^Checker, symbol: Symbol) -> (err: Error) {
	err = nil
	name: string
	switch s in symbol {
	case Type_Symbol:
		name = string(s)
	case Identifier_Symbol:
		name = s.name
	case Fn_Symbol:
		name = s.name
	}
	if contain_symbol_by_name(c, name) {
		c.scope.symbols[name] = symbol
	} else {
		err = Semantic_Error.Unknown_Symbol
	}
	return
}

check_expr :: proc(c: ^Checker, expr: Expression) -> (result: Symbol, err: Error) {
	// Has to check that all the operand are of the same type
	// and do it recursively
	err = nil
	switch e in expr {
	case ^Literal_Expression:
		switch e.value.kind {
		case .Nil:
			result = c.builtins["nil"]
		case .Number:
			result = c.builtins["number"]
		case .Boolean:
			result = c.builtins["bool"]
		case .Object_Ref:
			assert(false, "Object not implemented yet")
		}

	case ^String_Literal_Expression:
		result = c.builtins["string"]

	case ^Array_Literal_Expression:
		assert(false, "Array checking not implemented")

	case ^Unary_Expression:
		// check that minus goes with number literal and not goes with bool
		expr_symbol := check_expr(c, e.expr) or_return
		if t, ok := expr_symbol.(Type_Symbol); ok {
			result = t
		} else {
			err = Semantic_Error.Invalid_Symbol
		}

	case ^Binary_Expression:
		result, err = check_binary_expr(c, e)

	case ^Identifier_Expression:
		symbol := find_symbol(c, e.name) or_return
		result = symbol.(Identifier_Symbol).type_symbol

	case ^Fn_Literal_Expression:

	case ^Call_Expression:
		result, err = check_call_expr(c, e)

	}
	return
}

check_binary_expr :: proc(c: ^Checker, e: ^Binary_Expression) -> (result: Symbol, err: Error) {
	err = nil
	ls := check_expr(c, e.left) or_return
	rs := check_expr(c, e.right) or_return
	left_symbol := ls.(Type_Symbol)
	right_symbol := rs.(Type_Symbol)
	if left_symbol == right_symbol {
		#partial switch e.op {
		case .And_Op, .Or_Op:
			if left_symbol != BOOL_SYMBOL {
				err = Semantic_Error.Invalid_Type_Operation
			}
		case .Plus_Op, .Minus_Op, .Mult_Op, .Div_Op, .Rem_Op:
			if left_symbol != NUMBER_SYMBOL {
				err = Semantic_Error.Invalid_Type_Operation
			}
		}
		result = left_symbol
	} else {
		err = Semantic_Error.Mismatched_Types
	}
	return
}

check_call_expr :: proc(c: ^Checker, e: ^Call_Expression) -> (result: Symbol, err: Error) {
	symbol := find_symbol(c, e.name) or_return
	if fn_symbol, ok := symbol.(Fn_Symbol); ok {
		if e.arg_count == fn_symbol.param_count {
			// check all the arguments
			for i in 0 ..< e.arg_count {
				expr_symbol := check_expr(c, e.args[i]) or_return
				param_symbol := fn_symbol.param_symbols[i]
				if expr_symbol.(Type_Symbol) == param_symbol.type_symbol {
					result = param_symbol.type_symbol
				} else {
					err = Semantic_Error.Mismatched_Types
				}
			}
			result = fn_symbol.return_symbol
		} else {
			err = Semantic_Error.Invalid_Arg_Count
		}
	} else {
		err = Semantic_Error.Mismatched_Types
	}
	return
}

check_node :: proc(c: ^Checker, node: Node) -> (err: Error) {
	switch n in node {
	case ^Expression_Statement:
		check_expr(c, n.expr) or_return

	case ^Block_Statement:
		for child in n.nodes {
			check_node(c, child) or_return
		}

	case ^Assignment_Statement:
		// check if the symbol exist
		vs := find_symbol(c, n.identifier) or_return
		et := check_expr(c, n.expr) or_return

		var_symbol := vs.(Identifier_Symbol)
		expr_type := et.(Type_Symbol)
		if var_symbol.type_symbol != expr_type {
			err = Semantic_Error.Mismatched_Types
		}
	// check if expression is correct

	case ^If_Statement:
		// check condition expression and if the condition is a boolean
		push_scope(c)
		defer pop_scope(c)
		condition_type := check_expr(c, n.condition) or_return
		if condition_type.(Type_Symbol) == BOOL_SYMBOL {
			check_node(c, n.body) or_return
			if n.next_branch != nil {
				check_node(c, n.next_branch) or_return
			}
		} else {
			err = Semantic_Error.Mismatched_Types
		}

	case ^Range_Statement:
		push_scope(c)
		defer pop_scope(c)
		lt := check_expr(c, n.low) or_return
		ht := check_expr(c, n.high) or_return
		low_type := lt.(Type_Symbol)
		high_type := ht.(Type_Symbol)

		if low_type == NUMBER_SYMBOL && high_type != NUMBER_SYMBOL {
			add_symbol(c, Identifier_Symbol{name = n.iterator_name, type_symbol = NUMBER_SYMBOL}) or_return
			check_node(c, n.body) or_return
		}

	case ^Var_Declaration:
		expr_type := check_expr(c, n.expr) or_return
		expected_type := Type_Symbol(n.type_name)
		if expected_type == "unresolved" {
			n.type_name = string(expr_type.(Type_Symbol))
			expected_type = expr_type.(Type_Symbol)
		}

		if expected_type == expr_type {

			if c.scope_depth > 0 {
				add_symbol(
					c,
					Identifier_Symbol{name = n.identifier, type_symbol = expr_type.(Type_Symbol)},
				) or_return
			} else {
				swap_symbol(
					c,
					Identifier_Symbol{name = n.identifier, type_symbol = expr_type.(Type_Symbol)},
				) or_return
			}
		} else {
			err = Semantic_Error.Mismatched_Types
		}

	case ^Fn_Declaration:
		fn_symbol := Fn_Symbol {
			name          = n.identifier,
			param_count   = n.param_count,
			return_symbol = Type_Symbol(n.return_type_name),
		}
		push_scope(c)
		for i in 0 ..< n.param_count {
			if !contain_symbol_by_name(c, n.parameters[i].type_name) {
				err = Semantic_Error.Unknown_Symbol
				return
			} else {
				fn_symbol.param_symbols[i] = Identifier_Symbol {
					name        = n.parameters[i].name,
					type_symbol = Type_Symbol(n.parameters[i].type_name),
				}
				add_symbol(c, fn_symbol.param_symbols[i])
			}
		}

		add_symbol(c, Identifier_Symbol{name = "result", type_symbol = Type_Symbol(n.return_type_name)})
		check_node(c, n.body) or_return
		pop_scope(c)
		// FIXME: Check that the return statement match the signature
		if c.scope_depth > 0 {
			add_symbol(c, fn_symbol) or_return
		} else {
			swap_symbol(c, fn_symbol)
		}
	}
	return
}
