package lily

import "core:fmt"

// Type_ID :: distinct int
// // INVALID_TYPE_ID :: -1
// // NUMER_TYPE_ID :: 1
// // NUMER_TYPE_ID :: 0
// // NUMER_TYPE_ID :: 0
// Builtin_Type_ID :: enum Type_ID {
// 	Invalid,
// 	Untyped,
// 	Number,
// 	Bool,
// 	String,
// }

// // A fat struct
// Symbol :: struct {
// 	name:    string,
// 	kind:    Symbol_Kind,
// 	type_id: Type_ID,
// 	fn_spec: struct {
// 		parameters: [dynamic]Type_ID,
// 	},
// }

// Symbol_Kind :: enum {
// 	Basic, // number, bool, string
// 	Array,
// 	Fn,
// 	Alias,
// 	Class,
// }

// Semantic_Scope :: struct {
// 	symbols: map[string]Symbol,
// 	parent:  ^Semantic_Scope,
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


// Checker :: struct {
// 	builtins:     map[string]Symbol,
// 	scope:        ^Semantic_Scope,
// 	scope_depth:  int,
// 	next_type_id: int,
// }

// new_checker :: proc() -> (checker: ^Checker) {
// 	checker = new(Checker)
// 	checker.scope = new_scope()
// 	checker.builtins["untyped"] = Symbol {
// 		kind    = .Basic,
// 		type_id = Type_ID(Builtin_Type_ID.Untyped),
// 	}
// 	checker.builtins["number"] = Symbol {
// 		kind    = .Basic,
// 		type_id = Type_ID(Builtin_Type_ID.Number),
// 	}
// 	checker.builtins["bool"] = Symbol {
// 		kind    = .Basic,
// 		type_id = Type_ID(Builtin_Type_ID.Bool),
// 	}
// 	checker.builtins["string"] = Symbol {
// 		kind    = .Basic,
// 		type_id = Type_ID(Builtin_Type_ID.String),
// 	}

// 	checker.next_type_id = len(Builtin_Type_ID)
// 	return
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

// find_symbol :: proc(c: ^Checker, name: string) -> (result: Symbol, err: Error) {
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
// 	err = Semantic_Error {
// 		kind    = .Unknown_Symbol,
// 		details = fmt.tprintf("Unknown symbol: %s", name),
// 	}
// 	return
// }

// contain_symbol :: proc(c: ^Checker, name: string) -> bool {
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
// 	if !contain_symbol(c, symbol.name) {
// 		c.scope.symbols[symbol.name] = symbol
// 	} else {
// 		err = Semantic_Error {
// 			kind    = .Redeclared_Symbol,
// 			details = fmt.tprintf("Redeclaration of '%s'", symbol.name),
// 		}
// 	}
// 	return
// }

// update_symbol :: proc(c: ^Checker, name: string, symbol: Symbol) -> (err: Error) {
// 	if contain_symbol(c, name) {
// 		c.scope.symbols[name] = symbol
// 	} else {
// 		err = Semantic_Error {
// 			kind    = .Redeclared_Symbol,
// 			details = fmt.tprintf("Unkown symbol: %s'", symbol.name),
// 		}
// 	}
// 	return
// }

// gen_type_id :: proc(c: ^Checker) -> Type_ID {
// 	c.next_type_id += 1
// 	return Type_ID(c.next_type_id - 1)
// }

// check_nodes :: proc(c: ^Checker, nodes: []Node) -> (err: Error) {
// 	for node in nodes {
// 		if n, ok := node.(^Type_Declaration); ok {
// 			type_symbol := Symbol {
// 				name    = n.identifier,
// 				kind    = .Alias if n.is_alias else .Class,
// 				type_id = gen_type_id(c),
// 			}
// 			add_symbol(c, type_symbol) or_return
// 		}
// 	}
// 	// Gather all the function definitions
// 	for node in nodes {
// 		if n, ok := node.(^Fn_Declaration); ok {
// 			return_symbol := check_expr_type(c, n.return_type_expr) or_return
// 			fn_symbol := Symbol {
// 				name = n.identifier,
// 				kind = .Fn,
// 				type_id = return_symbol.type_id,
// 				fn_spec = {parameters = make([dynamic]Type_ID)},
// 			}
// 			for i in 0 ..< n.param_count {
// 				param_symbol := check_expr_type(c, n.parameters[i].type_expr) or_return
// 				append(&fn_symbol.fn_spec.parameters, param_symbol.type_id)
// 			}
// 			add_symbol(c, fn_symbol) or_return
// 		}
// 	}
// 	// Update the functions signatures
// 	// for node in nodes {
// 	// 	#partial switch n in node {
// 	// 	case ^Fn_Declaration:
// 	// 		add_symbol(c, Symbol{name = n.identifier}) or_return
// 	// 	}
// 	// }

// 	for node in nodes {
// 		check_node(c, node) or_return
// 	}
// 	return
// }

// check_node :: proc(c: ^Checker, node: Node) -> (err: Error) {
// 	switch n in node {
// 	case ^Expression_Statement:
// 		check_node_symbols(c, n) or_return
// 		check_node_type(c, n) or_return

// 	case ^Block_Statement:
// 		check_node_symbols(c, n) or_return
// 		check_node_type(c, n) or_return

// 	case ^Assignment_Statement:
// 		check_node_symbols(c, n) or_return
// 		check_node_type(c, n) or_return

// 	case ^If_Statement:
// 		push_scope(c)
// 		defer pop_scope(c)
// 		check_node_symbols(c, n) or_return
// 		check_node_type(c, n) or_return

// 	case ^Range_Statement:
// 		push_scope(c)
// 		defer pop_scope(c)
// 		check_node_symbols(c, n) or_return
// 		check_node_type(c, n) or_return

// 	case ^Var_Declaration:
// 		check_node_symbols(c, n) or_return
// 		check_node_type(c, n) or_return

// 	case ^Fn_Declaration:
// 		push_scope(c)
// 		defer pop_scope(c)
// 		check_node_symbols(c, n) or_return
// 		check_node_type(c, n) or_return

// 	case ^Type_Declaration:
// 		check_node_symbols(c, n) or_return
// 	}
// 	return
// }

// // Check for symbol error and add the newly declared symbols to the checker
// check_node_symbols :: proc(c: ^Checker, node: Node) -> (err: Error) {
// 	switch n in node {
// 	case ^Expression_Statement:
// 		check_expr_symbols(c, n.expr) or_return

// 	case ^Block_Statement:
// 		for block_node in n.nodes {
// 			check_node_symbols(c, block_node) or_return
// 		}

// 	case ^Assignment_Statement:
// 		check_expr_symbols(c, n.left) or_return
// 		check_expr_symbols(c, n.right) or_return

// 	case ^If_Statement:
// 		check_expr_symbols(c, n.condition) or_return
// 		check_node_symbols(c, n.body) or_return
// 		if n.next_branch != nil {
// 			check_node_symbols(c, n.next_branch) or_return
// 		}

// 	case ^Range_Statement:
// 		if contain_symbol(c, n.iterator_name) {
// 			err = Semantic_Error {
// 				kind    = .Redeclared_Symbol,
// 				token   = n.token,
// 				details = fmt.tprintf("Redeclaration of '%s'", n.iterator_name),
// 			}
// 			return
// 		}
// 		check_expr_symbols(c, n.low) or_return
// 		check_expr_symbols(c, n.high) or_return
// 		check_node_symbols(c, n.body) or_return

// 	case ^Var_Declaration:
// 		if contain_symbol(c, n.identifier) {
// 			err = Semantic_Error {
// 				kind    = .Redeclared_Symbol,
// 				token   = n.token,
// 				details = fmt.tprintf("Redeclaration of '%s'", n.identifier),
// 			}
// 			return
// 		}
// 		check_expr_symbols(c, n.type_expr) or_return
// 		check_expr_symbols(c, n.expr) or_return
// 		add_symbol(c, Symbol{name = n.identifier}) or_return

// 	case ^Fn_Declaration:
// 		// No need to check for function symbol declaration since 
// 		// functions can only be declared at the file scope
// 		add_symbol(c, Symbol{name = "result"})
// 		for param in n.parameters[:n.param_count] {
// 			if contain_symbol(c, param.name) {
// 				err = Semantic_Error {
// 					kind    = .Redeclared_Symbol,
// 					// token   = n.token,
// 					details = fmt.tprintf("Redeclaration of '%s'", param.name),
// 				}
// 				return
// 			} else {
// 				add_symbol(c, Symbol{name = param.name})
// 			}
// 			check_expr_symbols(c, param.type_expr) or_return
// 		}
// 		check_node_symbols(c, n.body) or_return
// 		check_expr_symbols(c, n.return_type_expr) or_return

// 	case ^Type_Declaration:
// 		if n.is_alias {
// 			check_expr_symbols(c, n.type_expr) or_return
// 		} else {
// 			// Branch for class declaration
// 		}
// 	}
// 	return
// }

// check_node_type :: proc(c: ^Checker, node: Node) -> (err: Error) {
// 	switch n in node {
// 	case ^Expression_Statement:
// 		check_expr_type(c, n.expr) or_return

// 	case ^Block_Statement:
// 		for block_node in n.nodes {
// 			check_node_type(c, block_node) or_return
// 		}

// 	case ^Assignment_Statement:
// 		left_symbol := check_expr_type(c, n.left) or_return
// 		right_symbol := check_expr_type(c, n.right) or_return
// 		if left_symbol.type_id != right_symbol.type_id {
// 			err = Semantic_Error {
// 				kind    = .Mismatched_Types,
// 				token   = n.token,
// 				details = fmt.tprintf("Unable to assign %i to %i", left_symbol.type_id, right_symbol.type_id),
// 			}
// 		}

// 	case ^If_Statement:
// 		condition_symbol := check_expr_type(c, n.condition) or_return
// 		if condition_symbol.type_id != Type_ID(Builtin_Type_ID.Bool) {
// 			err = Semantic_Error {
// 				kind    = .Mismatched_Types,
// 				token   = n.token,
// 				details = fmt.tprintf("If statement condition isn't of type %i", Type_ID(Builtin_Type_ID.Bool)),
// 			}
// 		}
// 		check_node_type(c, n.body) or_return
// 		if n.next_branch != nil {
// 			check_node_type(c, n.next_branch) or_return
// 		}

// 	case ^Range_Statement:
// 		l_symbol := check_expr_type(c, n.low) or_return
// 		h_symbol := check_expr_type(c, n.high) or_return
// 		n_id := Type_ID(Builtin_Type_ID.Number)
// 		if l_symbol.type_id != n_id || h_symbol.type_id != n_id {
// 			err = Semantic_Error {
// 				kind    = .Mismatched_Types,
// 				token   = n.token,
// 				details = fmt.tprintf(
// 					"Range expression components need to be of type %i",
// 					Type_ID(Builtin_Type_ID.Bool),
// 				),
// 			}
// 		}

// 	case ^Var_Declaration:
// 		type_symbol := check_expr_type(c, n.type_expr) or_return
// 		if type_symbol.type_id == Type_ID(Builtin_Type_ID.Untyped) {
// 			type_symbol = check_expr_type(c, n.expr) or_return
// 			update_symbol(c, n.identifier, type_symbol) or_return
// 		} else {
// 			expr_symbol := check_expr_type(c, n.expr) or_return
// 			if type_symbol.type_id != expr_symbol.type_id {
// 				err = Semantic_Error {
// 					kind    = .Mismatched_Types,
// 					token   = n.token,
// 					details = fmt.tprintf("Expected %i, got %i", type_symbol.type_id, expr_symbol.type_id),
// 				}
// 			}
// 		}

// 	case ^Fn_Declaration:
// 	case ^Type_Declaration:
// 	// assert(false, "Type declaration not supported yet")
// 	}
// 	return
// }

// check_expr_symbols :: proc(c: ^Checker, expr: Expression) -> (err: Error) {
// 	switch e in expr {
// 	case ^Literal_Expression:
// 	// No symbols to check

// 	case ^String_Literal_Expression:
// 	// No symbols to check

// 	case ^Array_Literal_Expression:
// 		check_expr_symbols(c, e.type_expr) or_return
// 		for value in e.values {
// 			check_expr_symbols(c, value) or_return
// 		}

// 	case ^Unary_Expression:
// 		check_expr_symbols(c, e.expr) or_return

// 	case ^Binary_Expression:
// 		check_expr_symbols(c, e.left) or_return
// 		check_expr_symbols(c, e.right) or_return

// 	case ^Identifier_Expression:
// 		if !contain_symbol(c, e.name) {
// 			err = Semantic_Error {
// 				kind    = .Unknown_Symbol,
// 				details = fmt.tprintf("Unknown symbol: %s", e.name),
// 			}
// 		}

// 	case ^Index_Expression:
// 		check_expr_symbols(c, e.left) or_return
// 		check_expr_symbols(c, e.index) or_return

// 	case ^Call_Expression:
// 		check_expr_symbols(c, e.func) or_return
// 		for i in 0 ..< e.arg_count {
// 			check_expr_symbols(c, e.args[i]) or_return
// 		}

// 	case ^Array_Type_Expression:
// 		check_expr_symbols(c, e.elem_type) or_return

// 	}
// 	return
// }

// check_expr_type :: proc(c: ^Checker, expr: Expression) -> (result: Symbol, err: Error) {
// 	switch e in expr {
// 	case ^Literal_Expression:
// 		switch e.value.kind {
// 		case .Nil:

// 		case .Number:
// 			result = c.builtins["number"]
// 		case .Boolean:
// 			result = c.builtins["bool"]
// 		case .Object_Ref:
// 			assert(false, "Invalid branch")
// 		}

// 	case ^String_Literal_Expression:
// 		result = c.builtins["string"]

// 	case ^Array_Literal_Expression:
// 		elem_symbol := check_expr_type(c, e.type_expr) or_return
// 		result = Symbol {
// 			kind    = .Array,
// 			type_id = elem_symbol.type_id,
// 		}
// 		for element in e.values {
// 			symbol := check_expr_type(c, element) or_return
// 			if result.type_id != symbol.type_id {
// 				err = Semantic_Error {
// 					kind    = .Mismatched_Types,
// 					token   = e.type_expr.(^Array_Type_Expression).token,
// 					details = fmt.tprintf(
// 						"Invalid array element type. Expected %i, got %i",
// 						result.type_id,
// 						symbol.type_id,
// 					),
// 				}
// 				return
// 			}
// 		}

// 	case ^Unary_Expression:
// 		result = check_expr_type(c, e.expr) or_return

// 	case ^Binary_Expression:
// 		left := check_expr_type(c, e.left) or_return
// 		right := check_expr_type(c, e.right) or_return
// 		if left.type_id != right.type_id {
// 			err = Semantic_Error {
// 				kind    = .Mismatched_Types,
// 				token   = e.token,
// 				details = fmt.tprintf("Expected %i, got %i", left.type_id, right.type_id),
// 			}
// 			return
// 		}
// 		#partial switch e.op {
// 		case .Minus_Op, .Plus_Op, .Mult_Op, .Div_Op, .Rem_Op:
// 			if left.type_id != Type_ID(Builtin_Type_ID.Number) {
// 				err = Semantic_Error {
// 					kind    = .Invalid_Type_Operation,
// 					token   = e.token,
// 					details = fmt.tprintf("Invalid operation on type %i", left.type_id),
// 				}
// 			}
// 		case .Or_Op, .And_Op:
// 			if left.type_id != Type_ID(Builtin_Type_ID.Bool) {
// 				err = Semantic_Error {
// 					kind    = .Invalid_Type_Operation,
// 					token   = e.token,
// 					details = fmt.tprintf("Invalid operation on type %i", left.type_id),
// 				}
// 			}
// 		}
// 		result = left

// 	case ^Identifier_Expression:
// 		result = find_symbol(c, e.name) or_return

// 	case ^Index_Expression:
// 		result = check_expr_type(c, e.left) or_return
// 		index_symbol := check_expr_type(c, e.index) or_return
// 		if index_symbol.type_id != Type_ID(Builtin_Type_ID.Number) {
// 			err = Semantic_Error {
// 				kind    = .Mismatched_Types,
// 				token   = e.token,
// 				details = fmt.tprintf(
// 					"Expected %i, got %i",
// 					Type_ID(Builtin_Type_ID.Number),
// 					index_symbol.type_id,
// 				),
// 			}
// 		}

// 	case ^Call_Expression:
// 		#partial switch fn in e.func {
// 		case ^Identifier_Expression:
// 			fn_symbol := find_symbol(c, fn.name) or_return
// 			for i in 0 ..< e.arg_count {
// 				arg_symbol := check_expr_type(c, e.args[i]) or_return
// 				if fn_symbol.fn_spec.parameters[i] != arg_symbol.type_id {
// 					err = Semantic_Error {
// 						kind    = .Mismatched_Types,
// 						token   = e.token,
// 						details = fmt.tprintf(
// 							"Expected %i, got %i",
// 							fn_symbol.fn_spec.parameters[i],
// 							arg_symbol.type_id,
// 						),
// 					}
// 				}
// 			}
// 			result = fn_symbol
// 		case:
// 			assert(false)
// 		}

// 	case ^Array_Type_Expression:
// 		result = check_expr_type(c, e.elem_type) or_return

// 	}
// 	return
// }

///////////////
//////////////

Type_ID :: distinct int
UNTYPED_ID :: 0
UNTYPED_NUMBER_ID :: 1
UNTYPED_BOOL_ID :: 2
UNTYPED_STRING_ID :: 3
NUMBER_ID :: 4
BOOL_ID :: 5
STRING_ID :: 6
FN_ID :: 7
ARRAY_ID :: 8
BUILT_IN_ID_COUNT :: ARRAY_ID + 1

Module_ID :: distinct int
BUILTIN_MODULE_ID :: 0

Type_Alias_Info :: struct {
	underlying_type_id: Type_ID,
}

Generic_Type_Info :: struct {
	spec_type_id: Type_ID,
}

Fn_Signature_Info :: struct {
	parameters:     []Type_Info,
	return_type_id: Type_ID,
}

Type_Info :: struct {
	name:         string,
	type_id:      Type_ID,
	type_kind:    enum {
		Builtin,
		Elementary_Type,
		Type_Alias,
		Fn_Type,
		Generic_Type,
	},
	type_id_data: union {
		Type_Alias_Info,
		Generic_Type_Info,
		Fn_Signature_Info,
	},
}

is_untyped_id :: proc(t: Type_Info) -> bool {
	return t.type_id == UNTYPED_NUMBER_ID || t.type_id == UNTYPED_NUMBER_ID || t.type_id == UNTYPED_STRING_ID
}

// In Lily, a truthy type can be of only 2 kind:
// - of Boolean type (BOOL_ID)
// - of a type alias with a parent of type Untyped Bool (UNTYPED_BOOL_ID)
is_truthy_type :: proc(t: Type_Info) -> bool {
	#partial switch t.type_kind {
	case .Builtin:
		if t.type_id == BOOL_ID || t.type_id == UNTYPED_BOOL_ID {
			return true
		}
	case .Type_Alias:
		parent := t.type_id_data.(Type_Alias_Info)
		if parent.underlying_type_id == UNTYPED_BOOL_ID {
			return true
		}
	}
	return false
}

is_numerical_type :: proc(t: Type_Info) -> bool {
	#partial switch t.type_kind {
	case .Builtin:
		if t.type_id == NUMBER_ID || t.type_id == UNTYPED_NUMBER_ID {
			return true
		}
	case .Type_Alias:
		parent := t.type_id_data.(Type_Alias_Info)
		if parent.underlying_type_id == UNTYPED_NUMBER_ID {
			return true
		}
	}
	return false
}

// Rules of type aliasing:
// - Type alias is incompatible with the parent type; a value from the parent type
// cannot be assigned to a variable from the type alias
// - Type alias inherits all the fields and methods of the parent
// - Type alias conserve the same capabilities as their parent (only applicable for native types)
// i.e: an alias of type bool can still be used for conditional (considered "truthy")  
//
// FIXME: Following type alias scenario should eval to true
// type MyNumber is number
// var foo: MyNumber = 10
//
// |- foo: MyNumber and |- 10: untyped number
// Number Literal are of type "untyped number" 
// and coherced to right type upon evaluation
// This is the same for 
type_equal :: proc(t0, t1: Type_Info) -> (result: bool) {
	if t0.type_id == t1.type_id {
		if t0.type_kind == t1.type_kind {
			#partial switch t0.type_kind {
			case .Generic_Type:
				t0_generic_id := t0.type_id_data.(Generic_Type_Info)
				t1_generic_id := t1.type_id_data.(Generic_Type_Info)
				if t0_generic_id.spec_type_id == t1_generic_id.spec_type_id {
					result = true
				}
			case:
				result = true
			}
		} else {
			assert(false, "Invalid type equality branch")
		}
	} else if t0.type_kind == .Type_Alias || t1.type_kind == .Type_Alias {
		alias: Type_Alias_Info
		other: Type_Info
		if t0.type_kind == .Type_Alias {
			alias = t0.type_id_data.(Type_Alias_Info)
			other = t1
		} else {
			alias = t1.type_id_data.(Type_Alias_Info)
			other = t0
		}
		if is_untyped_id(other) {
			result = alias.underlying_type_id == other.type_id
		}
	}
	return
}


// Here a scope is only used to gather symbol defintions 

Semantic_Scope :: struct {
	symbols:        [dynamic]string,
	variable_types: map[string]Type_Info,
	parent:         ^Semantic_Scope,
}

Checker :: struct {
	modules:         [dynamic]^Checked_Module,
	builtin_symbols: [5]string,
	builtin_types:   [BUILT_IN_ID_COUNT]Type_Info,
	type_id_ptr:     Type_ID,
}

// In Lily, type and function declaration is only 
// allowed at the file scope. This means that all the
// type infos can be kept at one place,
Checked_Module :: struct {
	// This is all the nodes at the file level
	nodes:       [dynamic]Checked_Node,
	functions:   [dynamic]Checked_Node,
	classes:     [dynamic]Checked_Node,
	types:       [dynamic]Type_Info,
	type_lookup: map[string]^Type_Info,
	type_count:  int,

	// symbols
	scope:       ^Semantic_Scope,
	scope_depth: int,
}

Checked_Expression :: struct {
	expr:    Expression,
	type_id: Type_ID,
}

Checked_Node :: union {
	^Checked_Expression_Statement,
	^Checked_Block_Statement,
	^Checked_Assigment_Statement,
	^Checked_If_Statement,
	^Checked_Range_Statement,
	^Checked_Var_Declaration,
	^Checked_Fn_Declaration,
	^Checked_Type_Declaration,
	^Checked_Class_Declaration,
}

Checked_Expression_Statement :: struct {
	token: Token,
	expr:  Checked_Expression,
}

Checked_Block_Statement :: struct {
	nodes: [dynamic]Checked_Node,
}

Checked_Assigment_Statement :: struct {
	token: Token,
	left:  Checked_Expression,
	right: Checked_Expression,
}

Checked_If_Statement :: struct {
	token:       Token,
	condition:   Checked_Expression,
	body:        ^Checked_Block_Statement,
	next_branch: ^Checked_If_Statement,
}

Checked_Range_Statement :: struct {
	token:            Token,
	iterator_name:    string,
	iterator_type_id: Type_ID,
	low:              Checked_Expression,
	hight:            Checked_Expression,
	reverse:          bool,
	op:               Range_Operator,
	body:             ^Checked_Block_Statement,
}

Checked_Var_Declaration :: struct {
	token:       Token,
	identifier:  string,
	type_id:     Type_ID,
	expr:        Checked_Expression,
	initialized: bool,
}

Checked_Fn_Declaration :: struct {
	token:          Token,
	identifier:     string,
	parameters:     [dynamic]struct {
		name:    string,
		type_id: Type_ID,
	},
	body:           ^Checked_Block_Statement,
	return_type_id: Type_ID,
}

Checked_Type_Declaration :: struct {
	token:              Token,
	is_token:           Token,
	identifier:         string,
	type_id:            Type_ID,
	underlying_type_id: Type_ID,
}

Checked_Class_Declaration :: struct {
	token:       Token,
	is_token:    Token,
	class_token: Token,
	fields:      [dynamic]struct {
		name:    string,
		type_id: Type_ID,
	},
}

// Procedures

new_checker :: proc() -> ^Checker {
	c := new_clone(
		Checker{
			modules = make([dynamic]^Checked_Module),
			builtin_symbols = {"untyped", "number", "string", "bool", "array"},
		},
	)
	c.builtin_types[UNTYPED_ID] = {
		name      = "untyped",
		type_id   = UNTYPED_ID,
		type_kind = .Builtin,
	}
	c.builtin_types[UNTYPED_NUMBER_ID] = {
		name      = "untyped number",
		type_id   = UNTYPED_NUMBER_ID,
		type_kind = .Builtin,
	}
	c.builtin_types[UNTYPED_BOOL_ID] = {
		name      = "untyped bool",
		type_id   = UNTYPED_BOOL_ID,
		type_kind = .Builtin,
	}
	c.builtin_types[UNTYPED_STRING_ID] = {
		name      = "untyped string",
		type_id   = UNTYPED_STRING_ID,
		type_kind = .Builtin,
	}
	c.builtin_types[NUMBER_ID] = {
		name      = "number",
		type_id   = NUMBER_ID,
		type_kind = .Builtin,
	}
	c.builtin_types[BOOL_ID] = {
		name      = "bool",
		type_id   = BOOL_ID,
		type_kind = .Builtin,
	}
	c.builtin_types[STRING_ID] = {
		name      = "string",
		type_id   = STRING_ID,
		type_kind = .Builtin,
	}
	c.builtin_types[FN_ID] = {
		name      = "fn",
		type_id   = FN_ID,
		type_kind = .Builtin,
	}
	c.builtin_types[ARRAY_ID] = {
		name      = "array",
		type_id   = ARRAY_ID,
		type_kind = .Builtin,
	}
	return c
}

new_checked_module :: proc() -> ^Checked_Module {
	return new_clone(
		Checked_Module{
			nodes = make([dynamic]Checked_Node),
			functions = make([dynamic]Checked_Node),
			classes = make([dynamic]Checked_Node),
			types = make([dynamic]Type_Info),
			type_lookup = make(map[string]^Type_Info),
			scope = new_scope(),
		},
	)
}

append_node_to_checked_module :: proc(m: ^Checked_Module, node: Checked_Node) {
	#partial switch n in node {
	case ^Checked_Fn_Declaration:
	case ^Checked_Class_Declaration:
	case:
		append(&m.nodes, n)
	}
}

new_scope :: proc() -> ^Semantic_Scope {
	scope := new(Semantic_Scope)
	scope.symbols = make([dynamic]string)
	scope.variable_types = make(map[string]Type_Info)
	return scope
}

delete_scope :: proc(s: ^Semantic_Scope) {
	delete(s.symbols)
	free(s)
}

push_scope :: proc(m: ^Checked_Module) {
	scope := new_scope()
	scope.parent = m.scope
	m.scope = scope
	m.scope_depth += 1
}

pop_scope :: proc(m: ^Checked_Module) {
	s := m.scope
	m.scope = s.parent
	delete_scope(s)
	m.scope_depth -= 1
}

contain_symbol :: proc(c: ^Checker, m: ^Checked_Module, token: Token) -> bool {
	builtins: for name in c.builtin_symbols {
		if name == token.text {
			return true
		}
	}

	scope := m.scope
	find: for scope != nil {
		for name in scope.symbols {
			if name == token.text {
				return true
			}
		}
		scope = scope.parent
	}

	return false
}

add_symbol :: proc(c: ^Checker, m: ^Checked_Module, token: Token) -> (err: Error) {
	if contain_symbol(c, m, token) {
		return Semantic_Error{
			kind = .Redeclared_Symbol,
			token = token,
			details = fmt.tprintf("Redeclared symbol: %s", token.text),
		}
	}

	append(&m.scope.symbols, token.text)
	return
}

contain_type :: proc(c: ^Checker, m: ^Checked_Module, t: Type_Info) -> bool {
	for type_info in c.builtin_types {
		if t.type_id == type_info.type_id {
			return true
		}
	}

	if type_info, exist := m.type_lookup[t.name]; exist {
		if t.type_id == type_info.type_id {
			return true
		}
	}

	return false
}

add_type :: proc(c: ^Checker, m: ^Checked_Module, t: Type_Info) -> (err: Error) {
	append(&m.types, t)
	m.type_lookup[t.name] = &m.types[len(m.types) - 1]
	return
}

// FIXME: Needs a code review. Does not check all the available modules
get_type :: proc(c: ^Checker, m: ^Checked_Module, name: string) -> (
	result: Type_Info,
	exist: bool,
) {
	for type_info in c.builtin_types {
		if type_info.name == name {
			return type_info, true
		}
	}

	// Super sus code...
	t: ^Type_Info
	t, exist = m.type_lookup[name]
	if t != nil {
		result = t^
	}
	return
}

get_type_from_id :: proc(c: ^Checker, id: Type_ID) -> (result: Type_Info) {
	switch {
	case id < BUILT_IN_ID_COUNT:
		result = c.builtin_types[id]
	case:
		accumulator: int = BUILT_IN_ID_COUNT
		for module in c.modules {
			if int(id) < BUILT_IN_ID_COUNT + module.type_count {
				rel_id := id - Type_ID(accumulator)
				result = module.types[rel_id]
				return
			}
			accumulator += module.type_count
		}
	}
	return
}

get_variable_type :: proc(m: ^Checked_Module, name: string) -> (result: Type_Info, exist: bool) {
	current := m.scope
	for current != nil {
		if info, contains := current.variable_types[name]; contains {
			result = info
			contains = true
			break
		}
	}
	return
}

// TODO: Request a ptr to the checker to see if the identifier is a builtin variable or function
get_fn_type :: proc(c: ^Checker, m: ^Checked_Module, name: string) -> (
	result: Type_Info,
	exist: bool,
) {
	return
}

gen_type_id :: proc(c: ^Checker) -> Type_ID {
	c.type_id_ptr += 1
	return c.type_id_ptr - 1
}

check_module :: proc(c: ^Checker, m: ^Parsed_Module) -> (result: ^Checked_Module, err: Error) {
	// Create a new module and add all the file level declaration symbols
	module := new_checked_module()
	// The type symbols need to be added first
	for node in m.nodes {
		if n, ok := node.(^Type_Declaration); ok {
			add_symbol(c, module, n.identifier) or_return
		}
	}

	for node in m.nodes {
		#partial switch n in node {
		case ^Var_Declaration:
			add_symbol(c, module, n.identifier) or_return
		case ^Fn_Declaration:
			add_symbol(c, module, n.identifier) or_return
		}
	}

	// After all the declaration have been gathered, 
	// we resolve the rest of the symbols in the inner expressions and scopes.
	for node in m.nodes {
		check_node_symbols(c, module, node) or_return
	}

	// Resolve the types:
	// Gather all the type declaration and generate type info for them.
	// Store those in the module type infos.
	// Then we can start to solve the types in each node and expression.

	for node in m.nodes {
		#partial switch n in node {
		case ^Type_Declaration:
			if n.is_alias {
				add_type(c, module, Type_Info{name = n.identifier.text})
			} else {
				assert(false, "Class not implemented yet")
			}
		}
	}

	for node in m.nodes {
		check_node_types(c, module, node) or_return
	}
	return
}

check_node_symbols :: proc(c: ^Checker, m: ^Checked_Module, node: Node) -> (err: Error) {
	switch n in node {
	case ^Expression_Statement:
		check_expr_symbols(c, m, n.expr) or_return

	case ^Block_Statement:
		for block_node in n.nodes {
			check_node_symbols(c, m, block_node) or_return
		}

	case ^Assignment_Statement:
		check_expr_symbols(c, m, n.left) or_return
		check_expr_symbols(c, m, n.right) or_return

	case ^If_Statement:
		check_expr_symbols(c, m, n.condition) or_return
		push_scope(m)
		check_node_symbols(c, m, n.body) or_return
		pop_scope(m)
		if n.next_branch != nil {
			check_node_symbols(c, m, n.next_branch) or_return
		}

	case ^Range_Statement:
		if contain_symbol(c, m, n.iterator_name) {
			err = Semantic_Error {
				kind    = .Redeclared_Symbol,
				token   = n.token,
				details = fmt.tprintf("Redeclaration of '%s'", n.iterator_name.text),
			}
			return
		}
		check_expr_symbols(c, m, n.low) or_return
		check_expr_symbols(c, m, n.high) or_return
		push_scope(m)
		defer pop_scope(m)
		check_node_symbols(c, m, n.body) or_return

	case ^Var_Declaration:
		if m.scope_depth > 0 {
			if contain_symbol(c, m, n.identifier) {
				err = Semantic_Error {
					kind    = .Redeclared_Symbol,
					token   = n.identifier,
					details = fmt.tprintf("Redeclaration of '%s'", n.identifier.text),
				}
				return
			}
			add_symbol(c, m, n.identifier) or_return
		}
		check_expr_symbols(c, m, n.type_expr) or_return
		check_expr_symbols(c, m, n.expr) or_return

	case ^Fn_Declaration:
		// No need to check for function symbol declaration since 
		// functions can only be declared at the file scope
		push_scope(m)
		defer pop_scope(m)
		add_symbol(c, m, Token{text = "result"}) or_return
		for param in n.parameters {
			if contain_symbol(c, m, param.name) {
				err = Semantic_Error {
					kind    = .Redeclared_Symbol,
					token   = param.name,
					details = fmt.tprintf("Redeclaration of '%s'", param.name.text),
				}
				return
			}
			add_symbol(c, m, param.name) or_return
			check_expr_symbols(c, m, param.type_expr) or_return
		}
		check_expr_symbols(c, m, n.return_type_expr) or_return
		check_node_symbols(c, m, n.body) or_return

	case ^Type_Declaration:
		if n.is_alias {
			check_expr_symbols(c, m, n.type_expr) or_return
		} else {
			// Branch for class declaration
		}
	}
	return
}

check_expr_symbols :: proc(c: ^Checker, m: ^Checked_Module, expr: Expression) -> (err: Error) {
	switch e in expr {
	case ^Literal_Expression:
	// No symbols to check

	case ^String_Literal_Expression:
	// No symbols to check

	case ^Array_Literal_Expression:
		// Check that the array specialization is of a known type
		check_expr_symbols(c, m, e.type_expr) or_return
		// Check all the inlined elements of the array
		for value in e.values {
			check_expr_symbols(c, m, value) or_return
		}

	case ^Unary_Expression:
		check_expr_symbols(c, m, e.expr) or_return

	case ^Binary_Expression:
		check_expr_symbols(c, m, e.left) or_return
		check_expr_symbols(c, m, e.right) or_return

	case ^Identifier_Expression:
		if !contain_symbol(c, m, e.name) {
			err = Semantic_Error {
				kind    = .Unknown_Symbol,
				details = fmt.tprintf("Unknown symbol: %s", e.name),
			}
		}

	case ^Index_Expression:
		check_expr_symbols(c, m, e.left) or_return
		check_expr_symbols(c, m, e.index) or_return

	case ^Call_Expression:
		check_expr_symbols(c, m, e.func) or_return
		for arg in e.args {
			check_expr_symbols(c, m, arg) or_return
		}

	case ^Array_Type_Expression:
		check_expr_symbols(c, m, e.elem_type) or_return

	}
	return
}


// FIXME: Need a way to extract the token from an expression, either at an
// Parser level or at a Checker level
// Checked nodes take ownership of the Parsed Expressions and produce a Checked_Node
check_node_types :: proc(c: ^Checker, m: ^Checked_Module, node: Node) -> (
	result: Checked_Node,
	err: Error,
) {
	switch n in node {
	case ^Expression_Statement:
		t := check_expr_types(c, m, n.expr) or_return
		result := new_clone(Checked_Expression_Statement{})

	case ^Block_Statement:
		block_stmt := new_clone(Checked_Block_Statement{nodes = make([dynamic]Checked_Node)})
		for block_node in n.nodes {
			node := check_node_types(c, m, block_node) or_return
			append(&block_stmt.nodes, node)
		}

	case ^Assignment_Statement:
		left := check_expr_types(c, m, n.left) or_return
		right := check_expr_types(c, m, n.right) or_return


	case ^If_Statement:
		condition_type := check_expr_types(c, m, n.condition) or_return
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
		check_node_types(c, m, n.body) or_return
		if n.next_branch != nil {
			check_node_types(c, m, n.next_branch) or_return
		}

	case ^Range_Statement:
		//push scope
		low := check_expr_types(c, m, n.low) or_return
		high := check_expr_types(c, m, n.high) or_return
		if !type_equal(low, high) {
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = n.token,
				details = fmt.tprintf(
					"Low expression of type %s, high expression of type %s",
					low.name,
					high.name,
				),
			}
		}
		// add the newly created iterator to the scope
		check_node_types(c, m, n.body) or_return

	case ^Var_Declaration:
		var_type := check_expr_types(c, m, n.type_expr) or_return
		value_type := check_expr_types(c, m, n.expr) or_return

		// Need to determine if need to be type inferred
		if var_type.type_id == c.builtin_types[UNTYPED_ID].type_id {
			// add the var to the environment's scope
		} else {
			if !type_equal(var_type, value_type) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = n.token,
					details = fmt.tprintf("Expected %s, got %s", var_type.name, value_type.name),
				}
			}
		}

	case ^Fn_Declaration:
	case ^Type_Declaration:
	}
	return
}

check_expr_types :: proc(c: ^Checker, m: ^Checked_Module, expr: Expression) -> (
	result: Type_Info,
	err: Error,
) {
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
		inner_type := check_expr_types(c, m, e.type_expr) or_return
		result = Type_Info {
			name = "array",
			type_id = ARRAY_ID,
			type_kind = .Generic_Type,
			type_id_data = Generic_Type_Info{spec_type_id = inner_type.type_id},
		}
		for element in e.values {
			elem_type := check_expr_types(c, m, element) or_return
			if !type_equal(inner_type, elem_type) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = e.token,
					details = fmt.tprintf("Expected %s, got %s", inner_type.name, elem_type.name),
				}
			}
		}

	case ^Unary_Expression:
		result = check_expr_types(c, m, e.expr) or_return
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
		left := check_expr_types(c, m, e.left) or_return
		right := check_expr_types(c, m, e.right) or_return
		if !type_equal(left, right) {
			err = Semantic_Error {
				kind    = .Mismatched_Types,
				token   = e.token,
				details = fmt.tprintf(
					"Left expression of type %s, right expression of type %s",
					left.name,
					right.name,
				),
			}
		}

	case ^Identifier_Expression:
		result := get_type_from_identifier(c, m, e.name.text)

	case ^Index_Expression:
		left := check_expr_types(c, m, e.left) or_return
		if left.type_id == ARRAY_ID {
			index := check_expr_types(c, m, e.index) or_return
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

	case ^Call_Expression:
		// Get the signature from the environment
		fn_signature := check_expr_types(c, m, e.func) or_return
		if fn_signature.type_id == FN_ID && fn_signature.type_kind == .Fn_Type {
			signature_info := fn_signature.type_id_data.(Fn_Signature_Info)
			// Check that the call expression has the exact same amount of arguments
			// as the fn signature
			if len(signature_info.parameters) != len(e.args) {
				// FIXME: return an error
				return
			}
			for arg, i in e.args {
				arg_type := check_expr_types(c, m, arg) or_return
				if !type_equal(arg_type, signature_info.parameters[i]) {
					// FIXME: return an error
					break
				}
			}
			result = get_type_from_id(c, signature_info.return_type_id)
		} else {
			// FIXME: return an error
		}

	case ^Array_Type_Expression:
		inner_type := check_expr_types(c, m, e.elem_type) or_return
		result = Type_Info {
			name = "array",
			type_id = ARRAY_ID,
			type_kind = .Generic_Type,
			type_id_data = Generic_Type_Info{spec_type_id = inner_type.type_id},
		}
	}
	return
}
