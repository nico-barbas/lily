package lily

import "core:fmt"
import "core:hash"
import "core:strings"

// In Lily, type and function declaration is only 
// allowed at the file scope. This means that all the
// type infos can be kept at one place,
Checked_Module :: struct {
	name:        string,
	id:          int,
	// This is all the nodes at the file level
	// nodes:        [dynamic]Checked_Node,
	// variables:    [dynamic]Checked_Node,
	// functions:    [dynamic]Checked_Node,
	// classes:      [dynamic]Checked_Node,
	// type_lookup:  map[string]Type_Info,
	// type_count:   int,

	// symbols
	// class_lookup: map[string]struct {
	// 	name:       string,
	// 	class_id:   int,
	// 	scope_id:   Scope_ID,
	// 	root_index: int,
	// },
	scope:       ^Semantic_Scope,
	root:        ^Semantic_Scope,
	scope_depth: int,
}

make_checked_module :: proc(name: string, id: int) -> ^Checked_Module {
	// Checked_Module{
	// 	name = name,
	// 	id = id,
	// 	nodes = make([dynamic]Checked_Node),
	// 	functions = make([dynamic]Checked_Node),
	// 	classes = make([dynamic]Checked_Node),
	// 	type_lookup = make(map[string]Type_Info),
	// },
	m := new_clone(Checked_Module{name = name, id = id})
	// m.class_lookup = make(map[string]struct {
	// 		name:       string,
	// 		class_id:   int,
	// 		scope_id:   Scope_ID,
	// 		root_index: int,
	// 	})
	m.scope = new_scope()
	m.root = m.scope
	m.root.class_lookup = make(map[string]struct {
			symbol_index: int,
			scope_index:  int,
		})
	m.scope_depth = 0
	return m
}

format_scope_name :: proc(c: ^Checked_Module, name: Token) -> (result: string) {
	result = strings.concatenate(
		{c.name, name.text, fmt.tprint(name.line, name.start)},
		context.temp_allocator,
	)
	return
}

hash_scope_id :: proc(c: ^Checked_Module, name: Token) -> Scope_ID {
	scope_name := format_scope_name(c, name)
	return Scope_ID(hash.fnv32(transmute([]u8)scope_name))
}

push_scope :: proc(c: ^Checked_Module, name: Token) -> Scope_ID {
	scope := new_scope()
	scope.id = hash_scope_id(c, name)
	append(&c.scope.children, scope)
	scope.parent = c.scope
	c.scope = scope
	c.scope_depth += 1
	return scope.id
}

pop_scope :: proc(c: ^Checked_Module) {
	scope := c.scope
	c.scope = scope.parent
	c.scope_depth -= 1
}

push_class_scope :: proc(c: ^Checked_Module, name: Token) -> (err: Error) {
	assert(c.scope.id == c.root.id, "Can only declare Class at the root of a module")
	class_scope := new_scope()
	class_scope.id = hash_scope_id(c, name)
	class_scope.parent = c.scope
	class_symbol, e := add_symbol_to_scope(
		c.scope,
		Symbol{
			name = name.text,
			kind = .Class_Symbol,
			module_id = c.id,
			scope_id = c.scope.id,
			class_info = {class_scope_id = class_scope.id},
		},
	)
	if e != nil {
		err = e
		return
	}
	class_symbol_index := len(c.scope.symbols) - 1


	add_symbol_to_scope(
		class_scope,
		Symbol{
			name = "self",
			kind = .Var_Symbol,
			module_id = c.id,
			scope_id = class_scope.id,
			var_info = {symbol = class_symbol, is_ref = true, immutable = false},
		},
	) or_return
	append(&c.scope.children, class_scope)
	c.scope.class_lookup[name.text] = {
		symbol_index = class_symbol_index,
		scope_index  = len(c.scope.children) - 1,
	}
	// c.class_lookup[name.text] = {
	// 	name       = name.text,
	// 	scope_id   = class_scope.id,
	// 	root_index = len(c.scope.children) - 1,
	// }
	c.scope = class_scope
	c.scope_depth += 1
	return
}

enter_class_scope :: proc(c: ^Checked_Module, name: Token) -> (err: Error) {
	class_index := c.root.class_lookup[name.text].scope_index
	c.scope = c.root.children[class_index]
	c.scope_depth = 1
	return
}

enter_class_scope_by_id :: proc(c: ^Checked_Module, scope_id: Scope_ID, loc := #caller_location) -> (
	err: Error,
) {
	for _, lookup in c.root.class_lookup {
		symbol := &c.root.symbols[lookup.symbol_index]
		if symbol.class_info.class_scope_id == scope_id {
			c.scope = c.root.children[lookup.scope_index]
			c.scope_depth = 1
			return
		}
	}
	err = Internal_Error {
		kind         = .Unknown_Scope_Name,
		details      = fmt.tprintf("Scope #%i not known", scope_id),
		compiler_loc = loc,
	}
	return
}

enter_child_scope_by_id :: proc(c: ^Checked_Module, scope_id: Scope_ID, loc := #caller_location) -> (
	err: Error,
) {
	for scope in c.scope.children {
		if scope.id == scope_id {
			c.scope = scope
			c.scope_depth += 1
			return
		}
	}
	err = Internal_Error {
		kind         = .Unknown_Scope_Name,
		details      = fmt.tprintf("Scope #%i not known", scope_id),
		compiler_loc = loc,
	}
	return
}


// delete_checked_module :: proc(m: ^Checked_Module) {
// 	for class in m.classes {
// 		free_checked_node(class)
// 	}
// 	delete(m.classes)
// 	for function in m.functions {
// 		free_checked_node(function)
// 	}
// 	delete(m.functions)
// 	for node in m.nodes {
// 		free_checked_node(node)
// 	}
// 	delete(m.nodes)

// 	delete(m.type_lookup)
// 	delete(m.class_lookup)
// 	free_scope(m.root)
// 	free(m)
// }


// get_class_decl :: proc(m: ^Checked_Module, type_id: Type_ID) -> ^Checked_Class_Declaration {
// 	for class in m.classes {
// 		c := class.(^Checked_Class_Declaration)
// 		if c.type_info.type_id == type_id {
// 			return c
// 		}
// 	}
// 	return nil
// }


// Checked_Expression :: union {
// 	^Checked_Literal_Expression,
// 	^Checked_String_Literal_Expression,
// 	^Checked_Array_Literal_Expression,
// 	^Checked_Unary_Expression,
// 	^Checked_Binary_Expression,
// 	^Checked_Identifier_Expression,
// 	^Checked_Index_Expression,
// 	^Checked_Dot_Expression,
// 	^Checked_Call_Expression,
// }

// Checked_Literal_Expression :: struct {
// 	type_info: Type_Info,
// 	value:     Value,
// }

// Checked_String_Literal_Expression :: struct {
// 	type_info: Type_Info,
// 	value:     string,
// }

// Checked_Array_Literal_Expression :: struct {
// 	token:     Token,
// 	type_info: Type_Info,
// 	values:    []Checked_Expression,
// }

// Checked_Unary_Expression :: struct {
// 	token:     Token,
// 	type_info: Type_Info,
// 	expr:      Checked_Expression,
// 	op:        Operator,
// }

// Checked_Binary_Expression :: struct {
// 	token:     Token,
// 	type_info: Type_Info,
// 	left:      Checked_Expression,
// 	right:     Checked_Expression,
// 	op:        Operator,
// }

// Checked_Identifier_Expression :: struct {
// 	name:      Token,
// 	type_info: Type_Info,
// }

// Checked_Index_Expression :: struct {
// 	token:     Token,
// 	type_info: Type_Info,
// 	kind:      enum {
// 		Array,
// 		Map,
// 	},
// 	left:      Token,
// 	index:     Checked_Expression,
// }

// Checked_Dot_Expression :: struct {
// 	token:           Token,
// 	type_info:       Type_Info,
// 	kind:            enum {
// 		Module,
// 		Class,
// 		Instance_Field,
// 		Instance_Call,
// 		Array_Len,
// 		Array_Append,
// 	},
// 	left:            Token,
// 	left_symbol:     Symbol,
// 	selector:        Checked_Expression,
// 	selector_symbol: Symbol,
// }

// Checked_Call_Expression :: struct {
// 	token:     Token,
// 	type_info: Type_Info,
// 	func:      Checked_Expression,
// 	args:      []Checked_Expression,
// }

// free_checked_expression :: proc(expr: Checked_Expression) {
// 	switch e in expr {
// 	case ^Checked_Literal_Expression:
// 		free(e)

// 	case ^Checked_String_Literal_Expression:
// 		free(e)

// 	case ^Checked_Array_Literal_Expression:
// 		for value in e.values {
// 			free_checked_expression(value)
// 		}
// 		delete(e.values)
// 		free(e)

// 	case ^Checked_Unary_Expression:
// 		free_checked_expression(e.expr)
// 		free(e)

// 	case ^Checked_Binary_Expression:
// 		free_checked_expression(e.left)
// 		free_checked_expression(e.right)
// 		free(e)

// 	case ^Checked_Identifier_Expression:
// 		free(e)

// 	case ^Checked_Index_Expression:
// 		free_checked_expression(e.index)
// 		free(e)

// 	case ^Checked_Dot_Expression:
// 		free_checked_expression(e.selector)
// 		free(e)

// 	case ^Checked_Call_Expression:
// 		free_checked_expression(e.func)
// 		for arg in e.args {
// 			free_checked_expression(arg)
// 		}
// 		delete(e.args)
// 		free(e)

// 	}
// }


// Checked_Node :: union {
// 	^Checked_Expression_Statement,
// 	^Checked_Block_Statement,
// 	^Checked_Assigment_Statement,
// 	^Checked_If_Statement,
// 	^Checked_Range_Statement,
// 	^Checked_Var_Declaration,
// 	^Checked_Fn_Declaration,
// 	^Checked_Type_Declaration,
// 	^Checked_Class_Declaration,
// }

// Checked_Expression_Statement :: struct {
// 	token: Token,
// 	expr:  Checked_Expression,
// }

// Checked_Block_Statement :: struct {
// 	nodes: [dynamic]Checked_Node,
// }

// Checked_Assigment_Statement :: struct {
// 	token: Token,
// 	left:  Checked_Expression,
// 	right: Checked_Expression,
// }

// Checked_If_Statement :: struct {
// 	token:       Token,
// 	condition:   Checked_Expression,
// 	body:        Checked_Node,
// 	next_branch: Checked_Node,
// }

// Checked_Range_Statement :: struct {
// 	token:              Token,
// 	iterator_name:      Token,
// 	iterator_type_info: Type_Info,
// 	low:                Checked_Expression,
// 	high:               Checked_Expression,
// 	reverse:            bool,
// 	op:                 Range_Operator,
// 	body:               Checked_Node,
// }

// Checked_Var_Declaration :: struct {
// 	token:       Token,
// 	identifier:  Token,
// 	type_info:   Type_Info,
// 	expr:        Checked_Expression,
// 	initialized: bool,
// }

// Checked_Fn_Declaration :: struct {
// 	token:       Token,
// 	identifier:  Token,
// 	body:        Checked_Node,
// 	type_info:   Type_Info,
// 	param_names: []Token,
// }

// Checked_Type_Declaration :: struct {
// 	token:      Token,
// 	is_token:   Token,
// 	identifier: Token,
// 	type_info:  Type_Info,
// }

// Checked_Class_Declaration :: struct {
// 	token:        Token,
// 	is_token:     Token,
// 	identifier:   Token,
// 	type_info:    Type_Info,
// 	field_names:  []Token,
// 	constructors: []^Checked_Fn_Declaration,
// 	methods:      []^Checked_Fn_Declaration,
// }

// find_checked_constructor :: proc(c: ^Checked_Class_Declaration, name: Token) -> (
// 	^Checked_Fn_Declaration,
// 	int,
// 	bool,
// ) {
// 	for constructor, i in c.constructors {
// 		if constructor.identifier.text == name.text {
// 			return constructor, i, true
// 		}
// 	}
// 	return nil, -1, false
// }

// find_checked_method :: proc(c: ^Checked_Class_Declaration, name: Token) -> (
// 	^Checked_Fn_Declaration,
// 	int,
// 	bool,
// ) {
// 	for method, i in c.methods {
// 		if method.identifier.text == name.text {
// 			return method, i, true
// 		}
// 	}
// 	return nil, -1, false
// }

// free_checked_node :: proc(node: Checked_Node) {
// 	switch n in node {
// 	case ^Checked_Expression_Statement:
// 		free_checked_expression(n.expr)
// 		free(n)

// 	case ^Checked_Block_Statement:
// 		for block_node in n.nodes {
// 			free_checked_node(block_node)
// 		}
// 		delete(n.nodes)
// 		free(n)

// 	case ^Checked_Assigment_Statement:
// 		free_checked_expression(n.left)
// 		free_checked_expression(n.right)
// 		free(n)

// 	case ^Checked_If_Statement:
// 		free_checked_expression(n.condition)
// 		free_checked_node(n.body)
// 		free_checked_node(n.next_branch)
// 		free(n)

// 	case ^Checked_Range_Statement:
// 		free_checked_expression(n.low)
// 		free_checked_expression(n.high)
// 		free_checked_node(n.body)
// 		free(n)

// 	case ^Checked_Var_Declaration:
// 		free_checked_expression(n.expr)
// 		free(n)

// 	case ^Checked_Fn_Declaration:
// 		delete(n.param_names)
// 		delete_fn_signature_info(n.type_info)
// 		free_checked_node(n.body)
// 		free(n)

// 	case ^Checked_Type_Declaration:
// 		free(n)

// 	case ^Checked_Class_Declaration:
// 		delete(n.field_names)
// 		for constructor in n.constructors {
// 			free_checked_node(constructor)
// 		}
// 		delete(n.constructors)
// 		for method in n.methods {
// 			free_checked_node(method)
// 		}
// 		delete(n.methods)
// 		delete_class_definition_info(n.type_info)
// 		free(n)

// 	}
// }

// Symbol table stuff

// set_variable_type :: proc(s: ^Semantic_Scope, name: string, t: Type_Info, loc := #caller_location) {
// 	index := s.var_symbol_lookup[name]
// 	symbol := s.symbols[index]
// 	if symbol.kind != .Var_Symbol {
// 		fmt.println("FAIL UP STACK: ", loc, "Current scope id: ", s.id)
// 		fmt.println("CULPRIT: ", name, t)
// 		fmt.println("REAL: ", symbol)
// 		// fmt.println(s)
// 		// print_symbol_table(c, s)
// 		assert(false)
// 	}
// 	symbol.type_info = t
// 	s.symbols[index] = symbol
// }
