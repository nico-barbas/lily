package lily

import "core:fmt"
import "core:hash"
import "core:strings"

// In Lily, type and function declaration is only 
// allowed at the file scope. This means that all the
// type infos can be kept at one place,
Checked_Module :: struct {
	name:         string,
	// This is all the nodes at the file level
	nodes:        [dynamic]Checked_Node,
	functions:    [dynamic]Checked_Node,
	classes:      [dynamic]Checked_Node,
	// types:       [dynamic]Type_Info,
	type_lookup:  map[string]Type_Info,
	type_count:   int,

	// symbols
	class_scopes: map[string]struct {
		name:       string,
		scope_id:   Scope_ID,
		root_index: int,
	},
	scope:        ^Semantic_Scope,
	root:         ^Semantic_Scope,
	scope_depth:  int,
}

make_checked_module :: proc() -> ^Checked_Module {
	m := new_clone(
		Checked_Module{
			nodes = make([dynamic]Checked_Node),
			functions = make([dynamic]Checked_Node),
			classes = make([dynamic]Checked_Node),
			type_lookup = make(map[string]Type_Info),
		},
	)
	init_symbol_table(m)
	return m
}

delete_checked_module :: proc(m: ^Checked_Module) {
	for class in m.classes {
		free_checked_node(class)
	}
	delete(m.classes)
	for function in m.functions {
		free_checked_node(function)
	}
	delete(m.functions)
	for node in m.nodes {
		free_checked_node(node)
	}
	delete(m.nodes)

	delete(m.type_lookup)
	delete(m.class_scopes)
	free_scope(m.root)
	free(m)
}


get_class_decl :: proc(m: ^Checked_Module, type_id: Type_ID) -> ^Checked_Class_Declaration {
	for class in m.classes {
		c := class.(^Checked_Class_Declaration)
		if c.type_info.type_id == type_id {
			return c
		}
	}
	return nil
}

Checked_Expression :: union {
	^Checked_Literal_Expression,
	^Checked_String_Literal_Expression,
	^Checked_Array_Literal_Expression,
	^Checked_Unary_Expression,
	^Checked_Binary_Expression,
	^Checked_Identifier_Expression,
	^Checked_Index_Expression,
	^Checked_Dot_Expression,
	^Checked_Call_Expression,
}

Checked_Literal_Expression :: struct {
	type_info: Type_Info,
	value:     Value,
}

Checked_String_Literal_Expression :: struct {
	type_info: Type_Info,
	value:     string,
}

Checked_Array_Literal_Expression :: struct {
	token:     Token,
	type_info: Type_Info,
	values:    []Checked_Expression,
}

Checked_Unary_Expression :: struct {
	token:     Token,
	type_info: Type_Info,
	expr:      Checked_Expression,
	op:        Operator,
}

Checked_Binary_Expression :: struct {
	token:     Token,
	type_info: Type_Info,
	left:      Checked_Expression,
	right:     Checked_Expression,
	op:        Operator,
}

Checked_Identifier_Expression :: struct {
	name:      Token,
	type_info: Type_Info,
}

Checked_Index_Expression :: struct {
	token:     Token,
	type_info: Type_Info,
	kind:      enum {
		Array,
		Map,
	},
	left:      Token,
	index:     Checked_Expression,
}

Checked_Dot_Expression :: struct {
	token:     Token,
	type_info: Type_Info,
	kind:      enum {
		Module,
		Class,
		Instance_Field,
		Instance_Call,
	},
	left:      Token,
	selector:  Checked_Expression,
}

Checked_Call_Expression :: struct {
	token:     Token,
	type_info: Type_Info,
	func:      Checked_Expression,
	args:      []Checked_Expression,
}

free_checked_expression :: proc(expr: Checked_Expression) {
	switch e in expr {
	case ^Checked_Literal_Expression:
		free(e)

	case ^Checked_String_Literal_Expression:
		free(e)

	case ^Checked_Array_Literal_Expression:
		for value in e.values {
			free_checked_expression(value)
		}
		delete(e.values)
		free(e)

	case ^Checked_Unary_Expression:
		free_checked_expression(e.expr)
		free(e)

	case ^Checked_Binary_Expression:
		free_checked_expression(e.left)
		free_checked_expression(e.right)
		free(e)

	case ^Checked_Identifier_Expression:
		free(e)

	case ^Checked_Index_Expression:
		free_checked_expression(e.index)
		free(e)

	case ^Checked_Dot_Expression:
		free_checked_expression(e.selector)
		free(e)

	case ^Checked_Call_Expression:
		free_checked_expression(e.func)
		for arg in e.args {
			free_checked_expression(arg)
		}
		delete(e.args)
		free(e)

	}
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
	token:       Token,
	identifier:  Token,
	body:        Checked_Node,
	type_info:   Type_Info,
	param_names: []Token,
}

Checked_Type_Declaration :: struct {
	token:      Token,
	is_token:   Token,
	identifier: Token,
	type_info:  Type_Info,
}

Checked_Class_Declaration :: struct {
	token:        Token,
	is_token:     Token,
	identifier:   Token,
	type_info:    Type_Info,
	field_names:  []Token,
	constructors: []^Checked_Fn_Declaration,
	methods:      []^Checked_Fn_Declaration,
}

find_checked_constructor :: proc(c: ^Checked_Class_Declaration, name: Token) -> (
	^Checked_Fn_Declaration,
	bool,
) {
	for constructor in c.constructors {
		if constructor.identifier.text == name.text {
			return constructor, true
		}
	}
	return nil, false
}

find_checked_method :: proc(c: ^Checked_Class_Declaration, name: Token) -> (
	^Checked_Fn_Declaration,
	bool,
) {
	for method in c.methods {
		if method.identifier.text == name.text {
			return method, true
		}
	}
	return nil, false
}

free_checked_node :: proc(node: Checked_Node) {
	switch n in node {
	case ^Checked_Expression_Statement:
		free_checked_expression(n.expr)
		free(n)

	case ^Checked_Block_Statement:
		for block_node in n.nodes {
			free_checked_node(block_node)
		}
		delete(n.nodes)
		free(n)

	case ^Checked_Assigment_Statement:
		free_checked_expression(n.left)
		free_checked_expression(n.right)
		free(n)

	case ^Checked_If_Statement:
		free_checked_expression(n.condition)
		free_checked_node(n.body)
		free_checked_node(n.next_branch)
		free(n)

	case ^Checked_Range_Statement:
		free_checked_expression(n.low)
		free_checked_expression(n.high)
		free_checked_node(n.body)
		free(n)

	case ^Checked_Var_Declaration:
		free_checked_expression(n.expr)
		free(n)

	case ^Checked_Fn_Declaration:
		delete(n.param_names)
		delete_fn_signature_info(n.type_info)
		free_checked_node(n.body)
		free(n)

	case ^Checked_Type_Declaration:
		free(n)

	case ^Checked_Class_Declaration:
		delete(n.field_names)
		for constructor in n.constructors {
			free_checked_node(constructor)
		}
		delete(n.constructors)
		for method in n.methods {
			free_checked_node(method)
		}
		delete(n.methods)
		delete_class_definition_info(n.type_info)
		free(n)

	}
}

// Symbol table stuff

Semantic_Scope :: struct {
	id:                Scope_ID,
	symbols:           [dynamic]Symbol,
	var_symbol_lookup: map[string]int,
	parent:            ^Semantic_Scope,
	children:          [dynamic]^Semantic_Scope,
}

Symbol :: union {
	string,
	Scope_Ref_Symbol,
	Var_Symbol,
}

// For classes, constructors, methods and functions
Scope_Ref_Symbol :: struct {
	name:     string,
	scope_id: Scope_ID,
}

Var_Symbol :: struct {
	name:      string,
	type_info: Type_Info,
}

new_scope :: proc() -> ^Semantic_Scope {
	scope := new(Semantic_Scope)
	scope.symbols = make([dynamic]Symbol)
	scope.var_symbol_lookup = make(map[string]int)
	scope.children = make([dynamic]^Semantic_Scope)
	return scope
}

free_scope :: proc(s: ^Semantic_Scope) {
	for children in s.children {
		free_scope(children)
	}
	delete(s.symbols)
	delete(s.var_symbol_lookup)
	delete(s.children)
	free(s)
}

add_symbol_to_scope :: proc(s: ^Semantic_Scope, token: Token, shadow := false) -> (err: Error) {
	if !shadow && contain_scoped_symbol(s, token.text) {
		return Semantic_Error{
			kind = .Redeclared_Symbol,
			token = token,
			details = fmt.tprintf("Redeclared symbol: %s", token.text),
		}
	}

	append(&s.symbols, token.text)
	return
}

add_scope_ref_symbol_to_scope :: proc(
	s: ^Semantic_Scope,
	token: Token,
	scope_id: Scope_ID,
	shadow := false,
) -> (
	err: Error,
) {
	if !shadow && contain_scoped_symbol(s, token.text) {
		return Semantic_Error{
			kind = .Redeclared_Symbol,
			token = token,
			details = fmt.tprintf("Redeclared symbol: %s", token.text),
		}
	}

	append(&s.symbols, Scope_Ref_Symbol{name = token.text, scope_id = scope_id})
	return
}

add_var_symbol_to_scope :: proc(s: ^Semantic_Scope, t: Token, shadow := false) -> Error {
	if !shadow && contain_scoped_symbol(s, t.text) {
		return Semantic_Error{
			kind = .Redeclared_Symbol,
			token = t,
			details = fmt.tprintf("Redeclared symbol: %s", t.text),
		}
	}
	append(&s.symbols, Var_Symbol{name = t.text})
	s.var_symbol_lookup[t.text] = len(s.symbols) - 1
	return nil
}

contain_scoped_symbol :: proc(s: ^Semantic_Scope, name: string) -> bool {
	for symbol in s.symbols {
		switch smbl in symbol {
		case string:
			if smbl == name {
				return true
			}
		case Scope_Ref_Symbol:
			if smbl.name == name {
				return true
			}
		case Var_Symbol:
			if smbl.name == name {
				return true
			}
		}
	}
	return false
}

init_symbol_table :: proc(c: ^Checked_Module) {
	c.class_scopes = make(map[string]struct {
			name:       string,
			scope_id:   Scope_ID,
			root_index: int,
		})
	c.scope = new_scope()
	c.root = c.scope
	c.scope_depth = 0
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

push_class_scope :: proc(c: ^Checked_Module, name: Token) {
	assert(c.scope.id == c.root.id, "Can only declare Class at the root of a module")
	class_scope := new_scope()
	class_scope.id = hash_scope_id(c, name)
	class_scope.parent = c.scope
	add_scope_ref_symbol(c.scope, name, class_scope.id)
	add_scope_ref_symbol(class_scope, Token{text = "self"}, class_scope.id)
	append(&c.scope.children, class_scope)
	c.class_scopes[name.text] = {
		name       = name.text,
		scope_id   = class_scope.id,
		root_index = len(c.scope.children) - 1,
	}
	c.scope = class_scope
	c.scope_depth += 1
}

enter_child_scope :: proc(c: ^Checked_Module, name: Token, loc := #caller_location) -> (
	err: Error,
) {
	scope_id := hash_scope_id(c, name)
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

enter_class_scope :: proc(c: ^Checked_Module, name: Token) -> (err: Error) {
	scope_info := c.class_scopes[name.text]
	c.scope = c.root.children[scope_info.root_index]
	c.scope_depth = 1
	return
}

enter_class_scope_by_id :: proc(
	c: ^Checked_Module,
	scope_id: Scope_ID,
	loc := #caller_location,
) -> (
	err: Error,
) {
	for _, class_scope in c.class_scopes {
		if class_scope.scope_id == scope_id {
			c.scope = c.root.children[class_scope.root_index]
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

pop_scope :: proc(c: ^Checked_Module) {
	scope := c.scope
	c.scope = scope.parent
	c.scope_depth -= 1
}

get_class_scope_from_name :: proc(c: ^Checked_Module, name: string) -> ^Semantic_Scope {
	scope_info := c.class_scopes[name]
	return c.root.children[scope_info.root_index]
}

get_class_scope_from_id :: proc(c: ^Checked_Module, scope_id: Scope_ID) -> ^Semantic_Scope {
	for _, class_scope in c.class_scopes {
		if class_scope.scope_id == scope_id {
			return c.root.children[class_scope.root_index]
		}
	}
	return nil
}
