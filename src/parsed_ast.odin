package lily

Typed_Identifier :: struct {
	name:      Token,
	type_expr: Parsed_Expression,
}

Parsed_Expression :: union {
	// Value Expressions
	^Parsed_Literal_Expression,
	^Parsed_String_Literal_Expression,
	^Parsed_Array_Literal_Expression,
	^Parsed_Unary_Expression,
	^Parsed_Binary_Expression,
	^Parsed_Identifier_Expression,
	^Parsed_Index_Expression,
	^Parsed_Dot_Expression,
	^Parsed_Call_Expression,

	// Type Expressions
	^Parsed_Array_Type_Expression,
}

Parsed_Literal_Expression :: struct {
	value: Value,
}

// We separate this from the other fixed sized native value types
// to avoid having to allocate a Object_Ref during parsing and let
// the vm/interpreter do that at runtime
Parsed_String_Literal_Expression :: struct {
	value: string,
}

Parsed_Array_Literal_Expression :: struct {
	token:     Token, // the "array" token
	// This is either a Identifier (for builtin types and user defined types) 
	// or another composite type (array or map)
	type_expr: Parsed_Expression,
	values:    [dynamic]Parsed_Expression,
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

//////

Parsed_Node :: union {
	// Statements
	^Parsed_Expression_Statement,
	^Parsed_Block_Statement,
	^Parsed_Assignment_Statement,
	^Parsed_If_Statement,
	^Parsed_Range_Statement,

	// Declarations
	^Parsed_Var_Declaration,
	^Parsed_Fn_Declaration,
	^Parsed_Type_Declaration,
}

Parsed_Expression_Statement :: struct {
	expr: Parsed_Expression,
}

Parsed_Block_Statement :: struct {
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

Parsed_Var_Declaration :: struct {
	token:       Token, // the "var" token
	identifier:  Token,
	type_expr:   Parsed_Expression,
	expr:        Parsed_Expression,
	initialized: bool,
}

Parsed_Fn_Declaration :: struct {
	token:            Token,
	identifier:       Token,
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
