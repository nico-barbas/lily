package lily

Typed_Identifier :: struct {
	name:      Token,
	type_expr: Expression,
}

Expression :: union {
	// Value Expressions
	^Literal_Expression,
	^String_Literal_Expression,
	^Array_Literal_Expression,
	^Unary_Expression,
	^Binary_Expression,
	^Identifier_Expression,
	^Index_Expression,
	^Dot_Expression,
	^Call_Expression,

	// Type Expressions
	^Array_Type_Expression,
}

Literal_Expression :: struct {
	value: Value,
}

// We separate this from the other fixed sized native value types
// to avoid having to allocate a Object_Ref during parsing and let
// the vm/interpreter do that at runtime
String_Literal_Expression :: struct {
	value: string,
}

Array_Literal_Expression :: struct {
	token:     Token, // the "array" token
	// This is either a Identifier (for builtin types and user defined types) 
	// or another composite type (array or map)
	type_expr: Expression,
	values:    [dynamic]Expression,
}

Unary_Expression :: struct {
	token: Token,
	expr:  Expression,
	op:    Operator,
}

Binary_Expression :: struct {
	token: Token,
	left:  Expression,
	right: Expression,
	op:    Operator,
}

Identifier_Expression :: struct {
	name: Token,
}
unresolved_identifier := Identifier_Expression {
	name = Token{text = "untyped"},
}

Index_Expression :: struct {
	token: Token, // the '[' token
	left:  Expression, // The identifier most likely
	index: Expression, // The expression inside the brackets
}

Dot_Expression :: struct {
	token:    Token, // the '.' token
	left:     Expression,
	accessor: Expression,
}

Call_Expression :: struct {
	token: Token, // the '(' token
	func:  Expression,
	args:  [dynamic]Expression,
}


Array_Type_Expression :: struct {
	token:     Token, // The "array" token
	of_token:  Token, //The "of" token
	elem_type: Expression, // Either Identifier or another Type Expression. Allows for multi-arrays
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
	expr: Expression,
}

Parsed_Block_Statement :: struct {
	nodes: [dynamic]Parsed_Node,
}

Parsed_Assignment_Statement :: struct {
	token: Token, // the '=' token
	left:  Expression,
	right: Expression,
}

Parsed_If_Statement :: struct {
	token:       Token, // the "if" token
	condition:   Expression,
	body:        ^Parsed_Block_Statement,
	next_branch: ^Parsed_If_Statement,
}

Parsed_Range_Statement :: struct {
	token:         Token, // the "for" token
	iterator_name: Token,
	low:           Expression,
	high:          Expression,
	reverse:       bool,
	op:            Range_Operator,
	body:          ^Parsed_Block_Statement,
}

Parsed_Var_Declaration :: struct {
	token:       Token, // the "var" token
	identifier:  Token,
	type_expr:   Expression,
	expr:        Expression,
	initialized: bool,
}

Parsed_Fn_Declaration :: struct {
	token:            Token,
	identifier:       Token,
	parameters:       [dynamic]Typed_Identifier,
	body:             ^Parsed_Block_Statement,
	return_type_expr: Expression,
}

Parsed_Type_Declaration :: struct {
	token:        Token, // the "type" token
	is_token:     Token,
	identifier:   Token,
	type_expr:    Expression,
	type_kind:    enum {
		Alias,
		Class,
	},
	fields:       [dynamic]Typed_Identifier,
	constructors: [dynamic]^Parsed_Fn_Declaration,
	methods:      [dynamic]^Parsed_Fn_Declaration,
}
