package lily

Expression :: union {
	^Literal_Expression,
	^String_Literal_Expression,
	^Array_Literal_Expression,
	^Unary_Expression,
	^Binary_Expression,
	^Identifier_Expression,
	^Fn_Literal_Expression,
	^Call_Expression,
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
	values:          [dynamic]Expression,
	value_type_name: string,
}

Unary_Expression :: struct {
	expr: Expression,
	op:   Operator,
}

Binary_Expression :: struct {
	left:  Expression,
	right: Expression,
	op:    Operator,
}

Identifier_Expression :: struct {
	name: string,
}

Fn_Literal_Expression :: struct {
	parameters:       [5]struct {
		name:      string,
		type_name: string,
	},
	param_count:      int,
	body:             ^Block_Statement,
	return_type_name: string,
}

Call_Expression :: struct {
	name:      string,
	args:      [5]Expression,
	arg_count: int,
}

//////

Node :: union {
	// Statements
	^Expression_Statement,
	^Block_Statement,
	^Assignment_Statement,
	^If_Statement,
	^Range_Statement,

	// Declarations
	^Var_Declaration,
	^Fn_Declaration,
}

Expression_Statement :: struct {
	expr: Expression,
}

Return_Statement :: struct {
	expr: Expression,
}

Block_Statement :: struct {
	nodes: [dynamic]Node,
}

Assignment_Statement :: struct {
	identifier: string,
	expr:       Expression,
}

If_Statement :: struct {
	condition:   Expression,
	body:        ^Block_Statement,
	next_branch: ^If_Statement,
}

Range_Statement :: struct {
	iterator_name: string,
	low:           Expression,
	high:          Expression,
	reverse:       bool,
	op:            Range_Operator,
	body:          ^Block_Statement,
}

Var_Declaration :: struct {
	identifier: string,
	type_name:  string,
	expr:       Expression,
}

Fn_Declaration :: struct {
	using _:    Fn_Literal_Expression,
	identifier: string,
}
