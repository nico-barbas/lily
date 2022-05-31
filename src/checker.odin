package lily

import "core:fmt"

// TODO: Embed the module ID inside the Type_ID

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

UNTYPED_INFO :: Type_Info {
	name      = "untyped",
	type_id   = UNTYPED_ID,
	type_kind = .Builtin,
}
UNTYPED_NUMBER_INFO :: Type_Info {
	name      = "untyped number",
	type_id   = UNTYPED_NUMBER_ID,
	type_kind = .Builtin,
}
UNTYPED_BOOL_INFO :: Type_Info {
	name      = "untyped bool",
	type_id   = UNTYPED_BOOL_ID,
	type_kind = .Builtin,
}
UNTYPED_STRING_INFO :: Type_Info {
	name      = "untyped string",
	type_id   = UNTYPED_STRING_ID,
	type_kind = .Builtin,
}
NUMBER_INFO :: Type_Info {
	name      = "number",
	type_id   = NUMBER_ID,
	type_kind = .Builtin,
}
BOOL_INFO :: Type_Info {
	name      = "bool",
	type_id   = BOOL_ID,
	type_kind = .Builtin,
}
STRING_INFO :: Type_Info {
	name      = "string",
	type_id   = STRING_ID,
	type_kind = .Builtin,
}
// FIXME: ?? Why do we need this
FN_INFO :: Type_Info {
	name      = "fn",
	type_id   = FN_ID,
	type_kind = .Builtin,
}
ARRAY_INFO :: Type_Info {
	name      = "array",
	type_id   = ARRAY_ID,
	type_kind = .Builtin,
}

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
	return t.type_id == UNTYPED_NUMBER_ID || t.type_id == UNTYPED_BOOL_ID || t.type_id == UNTYPED_STRING_ID
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
// EXAMPLE: Following type alias scenario should eval to true
// type MyNumber is number
// var foo: MyNumber = 10
//
// |- foo: MyNumber and |- 10: untyped number
// Number Literal are of type "untyped number" 
// and coherced to right type upon evaluation
// FIXME: Probably needs a rewrite at some point
type_equal :: proc(c: ^Checker, t0, t1: Type_Info) -> (result: bool) {
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
			parent_type := get_type_from_id(c, alias.underlying_type_id)
			result = type_equal(c, parent_type, other)
		}

	} else if is_untyped_id(t0) || is_untyped_id(t1) {
		untyped_t: Type_Info
		typed_t: Type_Info
		other: Type_Info
		if is_untyped_id(t0) {
			untyped_t = t0
			other = t1
		} else {
			untyped_t = t1
			other = t0
		}
		switch untyped_t.type_id {
		case UNTYPED_NUMBER_ID:
			typed_t = NUMBER_INFO
		case UNTYPED_BOOL_ID:
			typed_t = BOOL_INFO
		case UNTYPED_STRING_ID:
			typed_t = STRING_INFO
		}
		result = type_equal(c, typed_t, other)
	}
	return
}


// Here a scope is only used to gather symbol defintions 

Semantic_Scope :: struct {
	symbols:        [dynamic]string,
	variable_types: map[string]Type_Info,
	parent:         ^Semantic_Scope,
	children:       [dynamic]^Semantic_Scope,
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
	// types:       [dynamic]Type_Info,
	type_lookup: map[string]Type_Info,
	type_count:  int,

	// symbols
	scope:       ^Semantic_Scope,
	scope_depth: int,
}

Checked_Expression :: struct {
	expr:      Expression,
	type_info: Type_Info,
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
	body:        Checked_Node,
	next_branch: Checked_Node,
}

Checked_Range_Statement :: struct {
	token:              Token,
	iterator_name:      Token,
	iterator_type_info: Type_Info,
	low:                Checked_Expression,
	high:               Checked_Expression,
	reverse:            bool,
	op:                 Range_Operator,
	body:               Checked_Node,
}

Checked_Var_Declaration :: struct {
	token:       Token,
	identifier:  Token,
	type_info:   Type_Info,
	expr:        Checked_Expression,
	initialized: bool,
}

Checked_Fn_Declaration :: struct {
	token:      Token,
	identifier: Token,
	body:       Checked_Node,
	type_info:  Type_Info,
}

Checked_Type_Declaration :: struct {
	token:      Token,
	is_token:   Token,
	identifier: Token,
	type_info:  Type_Info,
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

new_checked_module :: proc() -> ^Checked_Module {
	return new_clone(
		Checked_Module{
			nodes = make([dynamic]Checked_Node),
			functions = make([dynamic]Checked_Node),
			classes = make([dynamic]Checked_Node),
			type_lookup = make(map[string]Type_Info),
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
	scope.children = make([dynamic]^Semantic_Scope)
	return scope
}

delete_scope :: proc(s: ^Semantic_Scope) {
	delete(s.symbols)
	free(s)
}

push_scope :: proc(m: ^Checked_Module) {
	scope := new_scope()
	append(&m.scope.children, scope)
	scope.parent = m.scope
	m.scope = scope
	m.scope_depth += 1
}

pop_scope :: proc(m: ^Checked_Module) {
	s := m.scope
	m.scope = s.parent
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

set_variable_type :: proc(m: ^Checked_Module, name: string, t: Type_Info) {
	m.scope.variable_types[name] = t
}


add_type_alias :: proc(c: ^Checker, m: ^Checked_Module, name: Token, parent_type: Type_ID) {
	m.type_lookup[name.text] = Type_Info {
		name = name.text,
		type_id = gen_type_id(c),
		type_kind = .Type_Alias,
		type_id_data = Type_Alias_Info{underlying_type_id = parent_type},
	}
	m.type_count += 1
}

update_type_alias :: proc(c: ^Checker, m: ^Checked_Module, name: Token, parent_type: Type_ID) {
	t := m.type_lookup[name.text]
	t.type_id_data = Type_Alias_Info {
		underlying_type_id = parent_type,
	}
	m.type_lookup[name.text] = t
}

// FIXME: Needs a code review. Does not check all the available modules
get_type :: proc(c: ^Checker, m: ^Checked_Module, name: string) -> (
	result: Type_Info,
	exist: bool,
) {
	for info in c.builtin_types {
		if info.name == name {
			result = info
			exist = true
			return
		}
	}
	result, exist = m.type_lookup[name]
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

get_type_from_identifier :: proc(c: ^Checker, m: ^Checked_Module, i: Token) -> (result: Type_Info) {
	if t, t_exist := get_type(c, m, i.text); t_exist {
		result = t
	} else if fn_type, fn_exist := get_fn_type(c, m, i.text); fn_exist {
		result = fn_type
	} else {
		result, _ = get_variable_type(m, i.text)
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
		current = current.parent
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

check_module :: proc(c: ^Checker, m: ^Parsed_Module) -> (module: ^Checked_Module, err: Error) {
	// Create a new module and add all the file level declaration symbols
	module = new_checked_module()
	append(&c.modules, module)
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
				add_type_alias(c, module, n.identifier, UNTYPED_ID)
			} else {
				assert(false, "Class not implemented yet")
			}
		}
	}

	for node in m.nodes {
		#partial switch n in node {
		case ^Type_Declaration:
			if n.is_alias {
				parent_type := check_expr_types(c, module, n.type_expr) or_return
				update_type_alias(c, module, n.identifier, parent_type.type_id)
			} else {
				assert(false, "Class not implemented yet")
			}
		}
	}

	for node in m.nodes {
		checked_node := check_node_types(c, module, node) or_return
		#partial switch node in checked_node {
		case ^Checked_Fn_Declaration:
			append(&module.functions, checked_node)
		case:
			append(&module.nodes, checked_node)
		}
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
		result := new_clone(Checked_Expression_Statement{expr = checked_expresssion(n.expr, t)})

	case ^Block_Statement:
		block_stmt := new_clone(Checked_Block_Statement{nodes = make([dynamic]Checked_Node)})
		for block_node in n.nodes {
			node := check_node_types(c, m, block_node) or_return
			append(&block_stmt.nodes, node)
		}
		result = block_stmt

	case ^Assignment_Statement:
		left := check_expr_types(c, m, n.left) or_return
		right := check_expr_types(c, m, n.right) or_return
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

		result = new_clone(
			Checked_Assigment_Statement{
				token = n.token,
				left = checked_expresssion(n.left, left),
				right = checked_expresssion(n.right, right),
			},
		)


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
		body_node := check_node_types(c, m, n.body) or_return
		if_stmt := new_clone(
			Checked_If_Statement{
				token = n.token,
				condition = checked_expresssion(n.condition, condition_type),
				body = body_node,
			},
		)
		if n.next_branch != nil {
			next_node := check_node_types(c, m, n.next_branch) or_return
			if_stmt.next_branch = next_node
		}
		result = if_stmt

	case ^Range_Statement:
		//push scope
		low := check_expr_types(c, m, n.low) or_return
		high := check_expr_types(c, m, n.high) or_return
		if !type_equal(c, low, high) {
			err = Semantic_Error {
				kind  = .Mismatched_Types,
				token = n.token,
			}
		}
		// add the newly created iterator to the scope
		body_node := check_node_types(c, m, n.body) or_return
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

	case ^Var_Declaration:
		var_type := check_expr_types(c, m, n.type_expr) or_return
		value_type := check_expr_types(c, m, n.expr) or_return

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
			set_variable_type(m, n.identifier.text, var_type)
		} else {
			if !type_equal(c, var_type, value_type) {
				err = Semantic_Error {
					kind    = .Mismatched_Types,
					token   = n.token,
					details = fmt.tprintf("Expected %s, got %s", var_type.name, value_type.name),
				}
			}
		}
		set_variable_type(m, n.identifier.text, var_type)
		result = new_clone(
			Checked_Var_Declaration{
				token = n.token,
				identifier = n.identifier,
				type_info = var_type,
				expr = checked_expresssion(n.expr, value_type),
				initialized = n.initialized,
			},
		)


	case ^Fn_Declaration:
		fn_decl := new_clone(
			Checked_Fn_Declaration{
				token = n.token,
				identifier = n.identifier,
				type_info = Type_Info{name = "fn", type_id = FN_ID, type_kind = .Fn_Type},
			},
		)
		fn_signature := Fn_Signature_Info {
			parameters = make([]Type_Info, len(n.parameters)),
		}
		for param, i in n.parameters {
			param_type := check_expr_types(c, m, param.type_expr) or_return
			fn_signature.parameters[i] = param_type
		}
		fn_decl.body = check_node_types(c, m, n.body) or_return
		return_type := check_expr_types(c, m, n.return_type_expr) or_return
		fn_signature.return_type_id = return_type.type_id
		fn_decl.type_info.type_id_data = fn_signature
		result = fn_decl

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
		lit_type := check_expr_types(c, m, e.type_expr) or_return
		generic_id := lit_type.type_id_data.(Generic_Type_Info)
		inner_type := get_type_from_id(c, generic_id.spec_type_id)
		fmt.println(inner_type)
		result = lit_type
		for element in e.values {
			elem_type := check_expr_types(c, m, element) or_return
			if !type_equal(c, inner_type, elem_type) {
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
		}

	case ^Identifier_Expression:
		result = get_type_from_identifier(c, m, e.name)

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
				if !type_equal(c, arg_type, signature_info.parameters[i]) {
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
