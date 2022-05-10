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
	// fn_spec
	// array_spec
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
	bultins:      map[string]Symbol,
	scope:        ^Semantic_Scope,
	scope_depth:  int,
	next_type_id: int,
}

new_checker :: proc() -> (checker: ^Checker) {
	checker = new(Checker)
	checker.scope = new_scope()
	checker.bultins["untyped"] = Symbol {
		name    = "untyped",
		kind    = .Basic,
		type_id = Type_ID(Builtin_Type_ID.Untyped),
	}
	checker.bultins["number"] = Symbol {
		name    = "number",
		kind    = .Basic,
		type_id = Type_ID(Builtin_Type_ID.Number),
	}
	checker.bultins["bool"] = Symbol {
		name    = "bool",
		kind    = .Basic,
		type_id = Type_ID(Builtin_Type_ID.Bool),
	}
	checker.bultins["string"] = Symbol {
		name    = "string",
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

contain_symbol :: proc(c: ^Checker, name: string) -> bool {
	if _, exist := c.bultins[name]; exist {
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

check_nodes :: proc(c: ^Checker, nodes: []Node) -> (err: Error) {
	// Gather all the function definitions
	for node in nodes {
		#partial switch n in node {
		case ^Fn_Declaration:
			add_symbol(c, Symbol{name = n.identifier}) or_return
		}
	}

	for node in nodes {
		check_node_symbols(c, node) or_return
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
		push_scope(c)
		defer pop_scope(c)
		check_expr_symbols(c, n.condition) or_return
		check_node_symbols(c, n.body) or_return
		if n.next_branch != nil {
			check_node_symbols(c, n.next_branch) or_return
		}

	case ^Range_Statement:
		push_scope(c)
		defer pop_scope(c)
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
		if c.scope_depth > 0 {
			if contain_symbol(c, n.identifier) {
				err = Semantic_Error {
					kind    = .Redeclared_Symbol,
					token   = n.token,
					details = fmt.tprintf("Redeclaration of '%s'", n.identifier),
				}
				return
			}
		}
		check_expr_symbols(c, n.type_expr) or_return
		check_expr_symbols(c, n.expr) or_return

	case ^Fn_Declaration:
		// No need to check for function symbol declaration since 
		// functions can only be declared at the file scope
		push_scope(c)
		defer pop_scope(c)
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

// import "core:strings"

// // - Disallow function declaration inside functions scope 

// // Stategy:
// // - Add all the file scope name declarations
// // - Check the inner expressions and scopes

// NIL_SYMBOL: Type_Symbol : "nil"
// NUMBER_SYMBOL: Type_Symbol : "number"
// BOOL_SYMBOL: Type_Symbol : "bool"
// STRING_SYMBOL: Type_Symbol : "string"

// reserved_keywords :: [?]string{"result"}

// Symbol :: union {
// 	Type_Symbol,
// 	Identifier_Symbol,
// 	// Array_Symbol,
// 	Fn_Symbol,
// }

// Type_Symbol :: distinct string

// Identifier_Symbol :: struct {
// 	name:        string,
// 	type_symbol: Type_Symbol,
// }

// Array_Symbol :: struct {}

// Fn_Symbol :: struct {
// 	name:          string,
// 	param_symbols: [5]Identifier_Symbol,
// 	param_count:   int,
// 	return_symbol: Type_Symbol,
// }

// Semantic_Scope :: struct {
// 	symbols: map[string]Symbol,
// 	parent:  ^Semantic_Scope,
// }

// Checker :: struct {
// 	builtins:    map[string]Symbol,
// 	scope:       ^Semantic_Scope,
// 	scope_depth: int,
// }

// new_checker :: proc() -> (checker: ^Checker) {
// 	checker = new(Checker)
// 	checker.builtins = make(map[string]Symbol)
// 	checker.builtins["nil"] = NIL_SYMBOL
// 	checker.builtins["number"] = NUMBER_SYMBOL
// 	checker.builtins["bool"] = BOOL_SYMBOL
// 	checker.builtins["string"] = STRING_SYMBOL
// 	checker.scope = new_scope()
// 	return
// }

// delete_checker :: proc(c: ^Checker) {
// 	recurse_delete_scope :: proc(s: ^Semantic_Scope) {
// 		if s.parent != nil {
// 			recurse_delete_scope(s.parent)
// 		}
// 		delete_scope(s)
// 	}
// 	delete(c.builtins)
// 	recurse_delete_scope(c.scope)
// 	free(c)
// }

// check_program :: proc(c: ^Checker, program: []Node) -> Error {
// 	// Check the file scope
// 	for node in program {
// 		#partial switch n in node {
// 		case ^Var_Declaration:
// 			id_symbol := Identifier_Symbol {
// 				name        = n.identifier,
// 				type_symbol = Type_Symbol(n.type_name),
// 			}
// 			add_symbol(c, id_symbol) or_return
// 		case ^Fn_Declaration:
// 			fn_symbol := Fn_Symbol {
// 				name          = n.identifier,
// 				param_count   = n.param_count,
// 				return_symbol = Type_Symbol(n.return_type_name),
// 			}
// 			for i in 0 ..< n.param_count {
// 				fn_symbol.param_symbols[i] = Identifier_Symbol {
// 					name        = n.parameters[i].name,
// 					type_symbol = Type_Symbol(n.parameters[i].type_name),
// 				}
// 			}
// 			add_symbol(c, fn_symbol) or_return
// 		}
// 	}

// 	for node in program {
// 		check_node(c, node) or_return
// 	}
// 	return nil
// }

// push_scope :: proc(c: ^Checker) {
// 	scope := new_scope()
// 	scope.parent = c.scope
// 	c.scope = scope
// 	c.scope_depth += 1
// }

// pop_scope :: proc(c: ^Checker) {
// 	s := c.scope
// 	c.scope = s.parent
// 	delete_scope(s)
// 	c.scope_depth -= 1
// }

// new_scope :: proc() -> ^Semantic_Scope {
// 	scope := new(Semantic_Scope)
// 	scope.symbols = make(map[string]Symbol)
// 	return scope
// }

// delete_scope :: proc(s: ^Semantic_Scope) {
// 	delete(s.symbols)
// 	free(s)
// }

// is_reserved_keyword :: proc(name: string) -> (reserved: bool) {
// 	for word in reserved_keywords {
// 		if word == name {
// 			reserved = true
// 			break
// 		}
// 	}
// 	return
// }

// find_symbol :: proc(c: ^Checker, name: string) -> (result: Symbol, err: Error) {
// 	err = nil
// 	if symbol, exist := c.builtins[name]; exist {
// 		result = symbol
// 		return
// 	}
// 	current := c.scope
// 	for current != nil {
// 		if symbol, exist := current.symbols[name]; exist {
// 			result = symbol
// 			return
// 		} else {
// 			current = current.parent
// 			continue
// 		}
// 	}
// 	err = Semantic_Error.Unknown_Symbol
// 	return
// }

// contain_symbol_by_name :: proc(c: ^Checker, name: string) -> bool {
// 	if _, exist := c.builtins[name]; exist {
// 		return true
// 	}

// 	// Check the scope tree for the symbol
// 	current := c.scope
// 	for current != nil {
// 		if _, exist := current.symbols[name]; exist {
// 			return true
// 		} else {
// 			current = current.parent
// 			continue
// 		}
// 	}
// 	return false
// }

// add_symbol :: proc(c: ^Checker, symbol: Symbol) -> (err: Error) {
// 	err = nil
// 	name: string
// 	switch s in symbol {
// 	case Type_Symbol:
// 		name = string(s)
// 	case Identifier_Symbol:
// 		name = s.name
// 	case Fn_Symbol:
// 		name = s.name
// 	}
// 	if !contain_symbol_by_name(c, name) {
// 		c.scope.symbols[name] = symbol
// 	} else {
// 		err = Semantic_Error.Redeclared_Symbol
// 	}
// 	return
// }

// swap_symbol :: proc(c: ^Checker, symbol: Symbol) -> (err: Error) {
// 	err = nil
// 	name: string
// 	switch s in symbol {
// 	case Type_Symbol:
// 		name = string(s)
// 	case Identifier_Symbol:
// 		name = s.name
// 	case Fn_Symbol:
// 		name = s.name
// 	}
// 	if contain_symbol_by_name(c, name) {
// 		c.scope.symbols[name] = symbol
// 	} else {
// 		err = Semantic_Error.Unknown_Symbol
// 	}
// 	return
// }

// check_expr :: proc(c: ^Checker, expr: Expression) -> (result: Symbol, err: Error) {
// 	// Has to check that all the operand are of the same type
// 	// and do it recursively
// 	err = nil
// 	switch e in expr {
// 	case ^Literal_Expression:
// 		switch e.value.kind {
// 		case .Nil:
// 			result = c.builtins["nil"]
// 		case .Number:
// 			result = c.builtins["number"]
// 		case .Boolean:
// 			result = c.builtins["bool"]
// 		case .Object_Ref:
// 			assert(false, "Object not implemented yet")
// 		}

// 	case ^String_Literal_Expression:
// 		result = c.builtins["string"]

// 	// case ^Array_Literal_Expression:
// 	// 	if contain_symbol_by_name(c, e.value_type_name) {
// 	// 		value_type := find_symbol(c, e.value_type_name) or_return
// 	// 		for element in e.values {
// 	// 			element_type := check_expr(c, element) or_return
// 	// 			if element_type != value_type {
// 	// 				err = Semantic_Error.Mismatched_Types
// 	// 				return
// 	// 			}
// 	// 		}
// 	// 		// FIXME: Pretty bad memory leak
// 	// 		array_type := strings.concatenate({e.value_type_name, "array"})
// 	// 		if !contain_symbol_by_name(c, array_type) {
// 	// 			add_symbol(c, Type_Symbol(array_type)) or_return
// 	// 			result = Type_Symbol(array_type)
// 	// 		} else {
// 	// 			result = find_symbol(c, array_type) or_return
// 	// 			delete(array_type)
// 	// 		}
// 	// 	} else {
// 	// 		err = Semantic_Error.Unknown_Symbol
// 	// 	}

// 	case ^Unary_Expression:
// 		// check that minus goes with number literal and not goes with bool
// 		expr_symbol := check_expr(c, e.expr) or_return
// 		if t, ok := expr_symbol.(Type_Symbol); ok {
// 			result = t
// 		} else {
// 			err = Semantic_Error.Invalid_Symbol
// 		}

// 	case ^Binary_Expression:
// 		result, err = check_binary_expr(c, e)

// 	case ^Identifier_Expression:
// 		symbol := find_symbol(c, e.name) or_return
// 		result = symbol.(Identifier_Symbol).type_symbol

// 	case ^Index_Expression:
// 		i := check_expr(c, e.index) or_return
// 		if index_type, ok := i.(Type_Symbol); ok {
// 			if index_type != NUMBER_SYMBOL {
// 				err = Semantic_Error.Mismatched_Types
// 			}
// 		} else {
// 			err = Semantic_Error.Mismatched_Types
// 		}

// 	case ^Call_Expression:
// 		result, err = check_call_expr(c, e)

// 	}
// 	return
// }

// check_binary_expr :: proc(c: ^Checker, e: ^Binary_Expression) -> (result: Symbol, err: Error) {
// 	err = nil
// 	ls := check_expr(c, e.left) or_return
// 	rs := check_expr(c, e.right) or_return
// 	left_symbol := ls.(Type_Symbol)
// 	right_symbol := rs.(Type_Symbol)
// 	if left_symbol == right_symbol {
// 		#partial switch e.op {
// 		case .And_Op, .Or_Op:
// 			if left_symbol != BOOL_SYMBOL {
// 				err = Semantic_Error.Invalid_Type_Operation
// 			}
// 		case .Plus_Op, .Minus_Op, .Mult_Op, .Div_Op, .Rem_Op:
// 			if left_symbol != NUMBER_SYMBOL {
// 				err = Semantic_Error.Invalid_Type_Operation
// 			}
// 		}
// 		result = left_symbol
// 	} else {
// 		err = Semantic_Error.Mismatched_Types
// 	}
// 	return
// }

// check_call_expr :: proc(c: ^Checker, e: ^Call_Expression) -> (result: Symbol, err: Error) {
// 	fn_symbol: Fn_Symbol
// 	#partial switch fn in e.func {
// 	case ^Identifier_Expression:
// 		s := find_symbol(c, fn.name) or_return
// 		f, ok := s.(Fn_Symbol)
// 		assert(ok)
// 		fn_symbol = f
// 	case ^Fn_Literal_Expression:
// 	case:
// 		assert(false)
// 	}
// 	if e.arg_count == fn_symbol.param_count {
// 		// check all the arguments
// 		for i in 0 ..< e.arg_count {
// 			expr_symbol := check_expr(c, e.args[i]) or_return
// 			param_symbol := fn_symbol.param_symbols[i]
// 			if expr_symbol.(Type_Symbol) == param_symbol.type_symbol {
// 				result = param_symbol.type_symbol
// 			} else {
// 				err = Semantic_Error.Mismatched_Types
// 			}
// 		}
// 		result = fn_symbol.return_symbol
// 	} else {
// 		err = Semantic_Error.Invalid_Arg_Count
// 	}
// 	return
// }

// check_node :: proc(c: ^Checker, node: Node) -> (err: Error) {
// 	switch n in node {
// 	case ^Expression_Statement:
// 		check_expr(c, n.expr) or_return

// 	case ^Block_Statement:
// 		for child in n.nodes {
// 			check_node(c, child) or_return
// 		}

// 	case ^Assignment_Statement:
// 		// check if the symbol exist
// 		l := check_expr(c, n.left) or_return
// 		r := check_expr(c, n.right) or_return

// 		var_symbol := l.(Type_Symbol)
// 		expr_type := r.(Type_Symbol)
// 		if var_symbol != expr_type {
// 			err = Semantic_Error.Mismatched_Types
// 		}
// 	// check if expression is correct

// 	case ^If_Statement:
// 		// check condition expression and if the condition is a boolean
// 		push_scope(c)
// 		defer pop_scope(c)
// 		condition_type := check_expr(c, n.condition) or_return
// 		if condition_type.(Type_Symbol) == BOOL_SYMBOL {
// 			check_node(c, n.body) or_return
// 			if n.next_branch != nil {
// 				check_node(c, n.next_branch) or_return
// 			}
// 		} else {
// 			err = Semantic_Error.Mismatched_Types
// 		}

// 	case ^Range_Statement:
// 		push_scope(c)
// 		defer pop_scope(c)
// 		lt := check_expr(c, n.low) or_return
// 		ht := check_expr(c, n.high) or_return
// 		low_type := lt.(Type_Symbol)
// 		high_type := ht.(Type_Symbol)

// 		if low_type == NUMBER_SYMBOL && high_type != NUMBER_SYMBOL {
// 			add_symbol(c, Identifier_Symbol{name = n.iterator_name, type_symbol = NUMBER_SYMBOL}) or_return
// 			check_node(c, n.body) or_return
// 		}

// 	case ^Var_Declaration:
// 		expr_type := check_expr(c, n.expr) or_return
// 		expected_type := Type_Symbol(n.type_name)
// 		if expected_type == "unresolved" {
// 			n.type_name = string(expr_type.(Type_Symbol))
// 			expected_type = expr_type.(Type_Symbol)
// 		}

// 		if expected_type == expr_type {

// 			if c.scope_depth > 0 {
// 				add_symbol(
// 					c,
// 					Identifier_Symbol{name = n.identifier, type_symbol = expr_type.(Type_Symbol)},
// 				) or_return
// 			} else {
// 				swap_symbol(
// 					c,
// 					Identifier_Symbol{name = n.identifier, type_symbol = expr_type.(Type_Symbol)},
// 				) or_return
// 			}
// 		} else {
// 			err = Semantic_Error.Mismatched_Types
// 		}

// 	case ^Fn_Declaration:
// 		fn_symbol := Fn_Symbol {
// 			name          = n.identifier,
// 			param_count   = n.param_count,
// 			return_symbol = Type_Symbol(n.return_type_name),
// 		}
// 		push_scope(c)
// 		for i in 0 ..< n.param_count {
// 			if !contain_symbol_by_name(c, n.parameters[i].type_name) {
// 				err = Semantic_Error.Unknown_Symbol
// 				return
// 			} else {
// 				fn_symbol.param_symbols[i] = Identifier_Symbol {
// 					name        = n.parameters[i].name,
// 					type_symbol = Type_Symbol(n.parameters[i].type_name),
// 				}
// 				add_symbol(c, fn_symbol.param_symbols[i])
// 			}
// 		}

// 		add_symbol(c, Identifier_Symbol{name = "result", type_symbol = Type_Symbol(n.return_type_name)})
// 		check_node(c, n.body) or_return
// 		pop_scope(c)
// 		// FIXME: Check that the return statement match the signature
// 		if c.scope_depth > 0 {
// 			add_symbol(c, fn_symbol) or_return
// 		} else {
// 			swap_symbol(c, fn_symbol)
// 		}
// 	}
// 	return
// }
