package lily

Parsed_Module :: struct {
	source:       string,
	name:         string,
	import_nodes: [dynamic]Parsed_Node,
	types:        [dynamic]Parsed_Node,
	functions:    [dynamic]Parsed_Node,
	variables:    [dynamic]Parsed_Node,
	nodes:        [dynamic]Parsed_Node,
}

make_parsed_module :: proc(name: string) -> ^Parsed_Module {
	return new_clone(
		Parsed_Module{
			name = name,
			import_nodes = make([dynamic]Parsed_Node),
			types = make([dynamic]Parsed_Node),
			functions = make([dynamic]Parsed_Node),
			nodes = make([dynamic]Parsed_Node),
		},
	)
}

delete_parsed_module :: proc(p: ^Parsed_Module) {
	for node in p.import_nodes {
		free_parsed_node(node)
	}
	delete(p.import_nodes)
	for node in p.types {
		free_parsed_node(node)
	}
	delete(p.types)
	for node in p.functions {
		free_parsed_node(node)
	}
	delete(p.functions)
	for node in p.nodes {
		free_parsed_node(node)
	}
	delete(p.nodes)
	free(p)
}


Typed_Identifier :: struct {
	name:      Token,
	type_expr: Parsed_Expression,
}

Parsed_Expression :: union {
	// Value Expressions
	^Parsed_Literal_Expression,
	^Parsed_String_Literal_Expression,
	^Parsed_Array_Literal_Expression,
	^Parsed_Map_Literal_Expression,
	^Parsed_Unary_Expression,
	^Parsed_Binary_Expression,
	^Parsed_Identifier_Expression,
	^Parsed_Index_Expression,
	^Parsed_Dot_Expression,
	^Parsed_Call_Expression,

	// Type Expressions
	^Parsed_Array_Type_Expression,
	^Parsed_Map_Type_Expression,
}

Parsed_Literal_Expression :: struct {
	token: Token,
	value: Value,
}

// We separate this from the other fixed sized native value types
// since strings are reference types in Lily
Parsed_String_Literal_Expression :: struct {
	token: Token,
	value: string,
}

Parsed_Array_Literal_Expression :: struct {
	token:     Token, // the "array" token
	// either a Identifier (for builtin types and user defined types), or nested types
	type_expr: Parsed_Expression,
	values:    [dynamic]Parsed_Expression,
}

Parsed_Map_Literal_Expression :: struct {
	token:     Token,
	type_expr: Parsed_Expression,
	elements:  [dynamic]Parsed_Map_Element,
}

Parsed_Map_Element :: struct {
	key:   Parsed_Expression,
	value: Parsed_Expression,
}

Parsed_Unary_Expression :: struct {
	token: Token,
	expr:  Parsed_Expression,
	op:    Operator,
}

Parsed_Binary_Expression :: struct {
	token: Token,
	left:  Parsed_Expression,
	right: Parsed_Expression,
	op:    Operator,
}

Parsed_Identifier_Expression :: struct {
	name: Token,
}
unresolved_identifier := Parsed_Identifier_Expression {
	name = Token{text = "untyped"},
}

Parsed_Index_Expression :: struct {
	token: Token, // the '[' token
	left:  Parsed_Expression, // The identifier most likely
	index: Parsed_Expression, // The expression inside the brackets
}

Parsed_Dot_Expression :: struct {
	token:    Token, // the '.' token
	left:     Parsed_Expression,
	selector: Parsed_Expression,
}

Parsed_Call_Expression :: struct {
	token: Token, // the '(' token
	func:  Parsed_Expression,
	args:  [dynamic]Parsed_Expression,
}


Parsed_Array_Type_Expression :: struct {
	token:     Token, // The "array" token
	of_token:  Token, //The "of" token
	elem_type: Parsed_Expression, // Either Identifier or another Type Parsed_Expression. Allows for multi-arrays
}

Parsed_Map_Type_Expression :: struct {
	token:      Token,
	of_token:   Token,
	key_type:   Parsed_Expression,
	value_type: Parsed_Expression,
}

token_from_parsed_expression :: proc(expr: Parsed_Expression) -> (result: Token) {
	switch e in expr {
	case ^Parsed_Literal_Expression:
		result = e.token

	case ^Parsed_String_Literal_Expression:
		result = e.token

	case ^Parsed_Array_Literal_Expression:
		result = e.token

	case ^Parsed_Map_Literal_Expression:
		result = e.token

	case ^Parsed_Unary_Expression:
		result = e.token

	case ^Parsed_Binary_Expression:
		result = e.token

	case ^Parsed_Identifier_Expression:
		result = e.name

	case ^Parsed_Index_Expression:
		result = e.token

	case ^Parsed_Dot_Expression:
		result = e.token

	case ^Parsed_Call_Expression:
		result = e.token

	case ^Parsed_Array_Type_Expression:
		result = e.token

	case ^Parsed_Map_Type_Expression:
		result = e.token
	}
	return
}

free_parsed_expression :: proc(expr: Parsed_Expression) {
	switch e in expr {
	case ^Parsed_Literal_Expression:
		free(e)

	case ^Parsed_String_Literal_Expression:
		free(e)

	case ^Parsed_Array_Literal_Expression:
		free_parsed_expression(e.type_expr)
		for value in e.values {
			free_parsed_expression(value)
		}
		delete(e.values)
		free(e)

	case ^Parsed_Map_Literal_Expression:
		free_parsed_expression(e.type_expr)
		for element in e.elements {
			free_parsed_expression(element.key)
			free_parsed_expression(element.value)
		}
		delete(e.elements)
		free(e)

	case ^Parsed_Unary_Expression:
		free_parsed_expression(e.expr)
		free(e)

	case ^Parsed_Binary_Expression:
		free_parsed_expression(e.left)
		free_parsed_expression(e.right)
		free(e)

	case ^Parsed_Identifier_Expression:
		free(e)

	case ^Parsed_Index_Expression:
		free_parsed_expression(e.left)
		free_parsed_expression(e.index)
		free(e)

	case ^Parsed_Dot_Expression:
		free_parsed_expression(e.left)
		free_parsed_expression(e.selector)
		free(e)

	case ^Parsed_Call_Expression:
		free_parsed_expression(e.func)
		for arg in e.args {
			free_parsed_expression(arg)
		}
		delete(e.args)
		free(e)

	case ^Parsed_Array_Type_Expression:
		free_parsed_expression(e.elem_type)
		free(e)

	case ^Parsed_Map_Type_Expression:
		free_parsed_expression(e.key_type)
		free_parsed_expression(e.value_type)
		free(e)
	}
}

//////

Parsed_Node :: union {
	// Statements
	^Parsed_Expression_Statement,
	^Parsed_Block_Statement,
	^Parsed_Assignment_Statement,
	^Parsed_If_Statement,
	^Parsed_Match_Statement,
	^Parsed_Flow_Statement,
	^Parsed_Range_Statement,
	^Parsed_Import_Statement,

	// Declarations
	^Parsed_Var_Declaration,
	^Parsed_Fn_Declaration,
	^Parsed_Type_Declaration,
}

Parsed_Expression_Statement :: struct {
	token: Token,
	expr:  Parsed_Expression,
}

Parsed_Block_Statement :: struct {
	token: Token,
	nodes: [dynamic]Parsed_Node,
}

Parsed_Assignment_Statement :: struct {
	token: Token, // the '=' token
	left:  Parsed_Expression,
	right: Parsed_Expression,
}

Parsed_If_Statement :: struct {
	token:       Token, // the "if" token
	condition:   Parsed_Expression,
	body:        ^Parsed_Block_Statement,
	next_branch: ^Parsed_If_Statement,
}

Parsed_Range_Statement :: struct {
	token:         Token, // the "for" token
	iterator_name: Token,
	low:           Parsed_Expression,
	high:          Parsed_Expression,
	reverse:       bool,
	op:            Range_Operator,
	body:          ^Parsed_Block_Statement,
}

Parsed_Match_Statement :: struct {
	token:      Token,
	evaluation: Parsed_Expression,
	cases:      [dynamic]struct {
		token:     Token,
		condition: Parsed_Expression,
		body:      ^Parsed_Block_Statement,
	},
}

Parsed_Flow_Statement :: struct {
	token: Token,
	kind:  Control_Flow_Operator,
}

Parsed_Import_Statement :: struct {
	token:      Token,
	identifier: Token,
}

Parsed_Var_Declaration :: struct {
	token:      Token, // the "var" token
	identifier: Token,
	type_expr:  Parsed_Expression,
	expr:       Parsed_Expression,
}

Parsed_Fn_Declaration :: struct {
	token:            Token,
	identifier:       Token,
	kind:             Fn_Kind,
	parameters:       [dynamic]Typed_Identifier,
	body:             ^Parsed_Block_Statement,
	return_type_expr: Parsed_Expression,
}

Parsed_Type_Declaration :: struct {
	token:        Token, // the "type" token
	is_token:     Token,
	identifier:   Token,
	type_expr:    Parsed_Expression,
	type_kind:    enum {
		Alias,
		Class,
	},
	fields:       [dynamic]Typed_Identifier,
	constructors: [dynamic]^Parsed_Fn_Declaration,
	methods:      [dynamic]^Parsed_Fn_Declaration,
}

free_parsed_node :: proc(node: Parsed_Node) {
	switch n in node {
	case ^Parsed_Expression_Statement:
		free_parsed_expression(n.expr)
		free(n)

	case ^Parsed_Block_Statement:
		for block_node in n.nodes {
			free_parsed_node(block_node)
		}
		delete(n.nodes)
		free(n)

	case ^Parsed_Assignment_Statement:
		free_parsed_expression(n.left)
		free_parsed_expression(n.right)
		free(n)

	case ^Parsed_If_Statement:
		free_parsed_expression(n.condition)
		if n.body != nil {
			free_parsed_node(n.body)
		}
		if n.next_branch != nil {
			free_parsed_node(n.next_branch)
		}
		free(n)

	case ^Parsed_Range_Statement:
		free_parsed_expression(n.low)
		free_parsed_expression(n.high)
		if n.body != nil {
			free_parsed_node(n.body)
		}
		free(n)

	case ^Parsed_Match_Statement:
		free_parsed_expression(n.evaluation)
		for c in n.cases {
			free_parsed_expression(c.condition)
			if c.body != nil {
				free_parsed_node(c.body)
			}
		}
		delete(n.cases)
		free(n)

	case ^Parsed_Flow_Statement:
		free(n)

	case ^Parsed_Import_Statement:
		free(n)

	case ^Parsed_Var_Declaration:
		free_parsed_expression(n.type_expr)
		free_parsed_expression(n.expr)
		free(n)

	case ^Parsed_Fn_Declaration:
		for identifier in n.parameters {
			free_parsed_expression(identifier.type_expr)
		}
		delete(n.parameters)
		if n.body != nil {
			free_parsed_node(n.body)
		}
		free_parsed_expression(n.return_type_expr)
		free(n)

	case ^Parsed_Type_Declaration:
		free_parsed_expression(n.type_expr)
		if n.type_kind == .Class {
			for field in n.fields {
				free_parsed_expression(field.type_expr)
			}
			delete(n.fields)
			for constructor in n.constructors {
				free_parsed_node(constructor)
			}
			delete(n.constructors)
			for method in n.methods {
				free_parsed_node(method)
			}
			delete(n.methods)
		}
		free(n)
	}
}
