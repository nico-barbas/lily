package lily

import "core:fmt"
import "core:hash"
import "core:strings"

Checked_Output :: struct {
	import_names: map[string]int,
	modules:      []^Checked_Module,
}

// In Lily, type and function declaration is only 
// allowed at the file scope. This means that all the
// type infos can be kept at one place,
Checked_Module :: struct {
	source:      string,
	name:        string,
	id:          int,
	// This is all the nodes at the file level
	nodes:       [dynamic]Checked_Node,
	variables:   [dynamic]Checked_Node,
	functions:   [dynamic]Checked_Node,
	classes:     [dynamic]Checked_Node,

	// Symbol table
	scope:       ^Semantic_Scope,
	root:        ^Semantic_Scope,
	scope_depth: int,
}

make_checked_module :: proc(name: string, id: int) -> ^Checked_Module {
	m :=
		new_clone(
			Checked_Module{
				name = name,
				id = id,
				nodes = make([dynamic]Checked_Node),
				variables = make([dynamic]Checked_Node),
				functions = make([dynamic]Checked_Node),
				classes = make([dynamic]Checked_Node),
			},
		)
	m.scope = new_scope()
	m.root = m.scope
	m.scope_depth = 0
	return m
}

format_scope_name :: proc(c: ^Checked_Module, name: Token) -> (result: string) {
	result =
		strings.concatenate({c.name, name.text, fmt.tprint(name.line, name.start)}, context.temp_allocator)
	return
}

hash_scope_id :: proc(c: ^Checked_Module, name: Token) -> Scope_ID {
	scope_name := format_scope_name(c, name)
	return Scope_ID(hash.fnv32(transmute([]u8)scope_name))
}

push_scope :: proc(c: ^Checked_Module, name: Token) -> Scope_ID {
	scope := new_scope()
	scope.id = hash_scope_id(c, name)
	c.scope.children[scope.id] = scope
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
	//odinfmt: disable
	class_symbol := add_symbol_to_scope(
		c.scope,
		Symbol{
			name = name.text,
			kind = .Class_Symbol,
			module_id = c.id,
			scope_id = c.scope.id,
			info = Class_Symbol_Info{sub_scope_id = class_scope.id},
		},
	) or_return
	//odinfmt: enable
	// class_symbol_index := len(c.scope.symbols) - 1


	add_symbol_to_scope(
		class_scope,
		Symbol{
			name = "self",
			kind = .Var_Symbol,
			module_id = c.id,
			scope_id = class_scope.id,
			info = Var_Symbol_Info{symbol = class_symbol, mutable = false},
		},
	) or_return
	c.scope.children[class_scope.id] = class_scope
	c.scope = class_scope
	c.scope_depth += 1
	return
}

enter_class_scope :: proc(c: ^Checked_Module, name: Token) -> (err: Error) {
	class_symbol := get_scoped_symbol(c.root, name) or_return
	if class_symbol.kind == .Class_Symbol {
		info := class_symbol.info.(Class_Symbol_Info)
		c.scope = c.root.children[info.sub_scope_id]
		c.scope_depth = 1
	} else {

	}
	return
}

enter_child_scope_by_id :: proc(c: ^Checked_Module, scope_id: Scope_ID, loc := #caller_location) -> (
	err: Error,
) {
	if child, exist := c.scope.children[scope_id]; exist {
		c.scope = child
		c.scope_depth += 1
	} else {
		err = Internal_Error {
			kind         = .Unknown_Scope_Name,
			details      = fmt.tprintf("Scope #%i not known", scope_id),
			compiler_loc = loc,
		}
	}
	return
}

enter_child_scope_by_name :: proc(c: ^Checked_Module, name: Token) -> Error {
	scope_id := hash_scope_id(c, name)
	return enter_child_scope_by_id(c, scope_id)
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
	for node in m.variables {
		free_checked_node(node)
	}
	delete(m.variables)
	for node in m.nodes {
		free_checked_node(node)
	}
	delete(m.nodes)

	free_scope(m.root)
	free(m)
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
	token:  Token,
	symbol: ^Symbol,
	value:  Value,
}

Checked_String_Literal_Expression :: struct {
	token:  Token,
	symbol: ^Symbol,
	value:  string,
}

Checked_Array_Literal_Expression :: struct {
	token:  Token,
	symbol: ^Symbol,
	values: []Checked_Expression,
}

Checked_Unary_Expression :: struct {
	token:  Token,
	symbol: ^Symbol, // The "type" symbol resulting from the operation 
	expr:   Checked_Expression,
	op:     Operator,
}

Checked_Binary_Expression :: struct {
	token:  Token,
	symbol: ^Symbol, // The "type" symbol resulting from the operation 
	left:   Checked_Expression,
	right:  Checked_Expression,
	op:     Operator,
}

Checked_Identifier_Expression :: struct {
	token:  Token,
	symbol: ^Symbol,
}

Checked_Index_Expression :: struct {
	token:  Token,
	symbol: ^Symbol, // The "type" symbol resulting from the operation 
	kind:   enum {
		Array,
		Map,
	},
	left:   Checked_Expression,
	index:  Checked_Expression,
}

Checked_Dot_Expression :: struct {
	token:       Token,
	symbol:      ^Symbol, // The "type" symbol resulting from the operation
	leaf_symbol: ^Symbol,
	left:        Checked_Expression,
	selector:    Checked_Expression,
}

Checked_Call_Expression :: struct {
	token:  Token,
	symbol: ^Symbol, // The "type" symbol resulting from the operation 
	func:   Checked_Expression,
	args:   []Checked_Expression,
}

Accessor_Kind :: enum {
	None,
	Module_Access,
	Class_Access,
	Instance_Access,
}

checked_expr_symbol :: proc(expr: Checked_Expression, lhs := true) -> (symbol: ^Symbol) {
	switch e in expr {
	case ^Checked_Literal_Expression:
		symbol = e.symbol

	case ^Checked_String_Literal_Expression:
		symbol = e.symbol

	case ^Checked_Array_Literal_Expression:
		symbol = e.symbol

	case ^Checked_Unary_Expression:
		symbol = e.symbol

	case ^Checked_Binary_Expression:
		symbol = e.symbol

	case ^Checked_Identifier_Expression:
		symbol = e.symbol

	case ^Checked_Index_Expression:
		symbol = e.symbol

	case ^Checked_Dot_Expression:
		if lhs {
			symbol = e.symbol
		} else {
			symbol = e.leaf_symbol
		}

	case ^Checked_Call_Expression:
		symbol = e.symbol

	}
	return
}

checked_expr_token :: proc(expr: Checked_Expression) -> (t: Token) {
	switch e in expr {
	case ^Checked_Literal_Expression:
		t = e.token

	case ^Checked_String_Literal_Expression:
		t = e.token

	case ^Checked_Array_Literal_Expression:
		t = e.token

	case ^Checked_Unary_Expression:
		t = e.token

	case ^Checked_Binary_Expression:
		t = e.token

	case ^Checked_Identifier_Expression:
		t = e.token

	case ^Checked_Index_Expression:
		t = e.token

	case ^Checked_Dot_Expression:
		t = e.token

	case ^Checked_Call_Expression:
		t = e.token

	}
	return
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
	^Checked_Match_Statement,
	^Checked_Flow_Statement,
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
	token: Token,
	nodes: []Checked_Node,
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
	token:    Token,
	iterator: ^Symbol,
	low:      Checked_Expression,
	high:     Checked_Expression,
	reverse:  bool,
	op:       Range_Operator,
	body:     Checked_Node,
}

Checked_Match_Statement :: struct {
	token:      Token,
	evaluation: Checked_Expression,
	cases:      []struct {
		token:     Token,
		condition: Checked_Expression,
		body:      Checked_Node,
	},
}

Checked_Flow_Statement :: struct {
	token: Token,
	kind:  Control_Flow_Operator,
}

Checked_Var_Declaration :: struct {
	token:       Token,
	identifier:  ^Symbol,
	expr:        Checked_Expression,
	initialized: bool,
}

Checked_Fn_Declaration :: struct {
	token:      Token,
	identifier: ^Symbol,
	kind:       Fn_Kind,
	body:       Checked_Node,
	params:     []^Symbol,
}

Checked_Type_Declaration :: struct {
	token:      Token,
	is_token:   Token,
	identifier: ^Symbol,
}

Checked_Class_Declaration :: struct {
	token:        Token,
	is_token:     Token,
	identifier:   ^Symbol,
	fields:       []^Symbol,
	constructors: []^Checked_Fn_Declaration,
	methods:      []^Checked_Fn_Declaration,
}

checked_node_token :: proc(node: Checked_Node) -> Token {
	switch n in node {
	case ^Checked_Expression_Statement:
		return n.token

	case ^Checked_Block_Statement:
		return n.token

	case ^Checked_Assigment_Statement:
		return n.token

	case ^Checked_If_Statement:
		return n.token

	case ^Checked_Range_Statement:
		return n.token

	case ^Checked_Match_Statement:
		return n.token

	case ^Checked_Flow_Statement:
		return n.token

	case ^Checked_Var_Declaration:
		return n.token

	case ^Checked_Fn_Declaration:
		return n.token

	case ^Checked_Type_Declaration:
		return n.token

	case ^Checked_Class_Declaration:
		return n.token
	}
	return {}
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
		if n.body != nil {
			free_checked_node(n.body)
		}
		free_checked_node(n.next_branch)
		free(n)

	case ^Checked_Range_Statement:
		free_checked_expression(n.low)
		free_checked_expression(n.high)
		if n.body != nil {
			free_checked_node(n.body)
		}
		free(n)

	case ^Checked_Match_Statement:
		free_checked_expression(n.evaluation)
		for c in n.cases {
			free_checked_expression(c.condition)
			if c.body != nil {
				free_checked_node(c.body)
			}
		}
		delete(n.cases)
		free(n)

	case ^Checked_Flow_Statement:
		free(n)

	case ^Checked_Var_Declaration:
		free_checked_expression(n.expr)
		free(n)

	case ^Checked_Fn_Declaration:
		delete(n.params)
		if n.body != nil {
			free_checked_node(n.body)
		}
		free(n)

	case ^Checked_Type_Declaration:
		free(n)

	case ^Checked_Class_Declaration:
		delete(n.fields)
		for constructor in n.constructors {
			free_checked_node(constructor)
		}
		delete(n.constructors)
		for method in n.methods {
			free_checked_node(method)
		}
		delete(n.methods)
		free(n)

	}
}
