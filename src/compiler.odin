package lily

//odinfmt: disable
Op_Code :: enum byte {
	Op_Begin, // Mark the begining of a stack scope, used for book keeping in the Vm
	Op_End,   // Mark the end of a stack scope, used for book keeping in the Vm
	Op_Pop,   // Get the last element from the stack and decrement its counter
	Op_Const, // Take the constant from the associated constant pool and load it on to stack
	Op_Set,   // Bind the variable name to a stack ID
	Op_Get,   // Get the variable value from the the variable pool and load it on the stack
	Op_Neg,   // Get the last element, negate it and push it back on the stack
	Op_Not,
	Op_Add,   // Get the last 2 elements, add them and push the result back on the stack
	Op_Mul,   // Get the last 2 elements, multiply them and push the result back on the stack
	Op_Div,
	Op_Rem,
	Op_And,
	Op_Or,
	Op_Jump,
	Op_Jump_False,
}
//odinfmt: enable

Compiler :: struct {
	cursor:          int,
	write_at_cursor: bool,
	bytecode:        [dynamic]byte,
	constants:       [dynamic]Value,
	variables:       [dynamic]Variable,
	const_count:     i16,
	var_count:       i16,
	scope_depth:     int,
}

Chunk :: struct {
	bytecode:  []byte,
	constants: []Value,
	variables: []Variable,
}

Variable :: struct {
	name:        string,
	scope_depth: int,
	stack_id:    int,
}

add_constant :: proc(c: ^Compiler, constant: Value) -> (ptr: i16) {
	append(&c.constants, constant)
	c.const_count += 1
	return c.const_count - 1
}

add_variable :: proc(c: ^Compiler, name: string) -> (ptr: i16) {
	// TODO: keep track of the scope depth
	append(&c.variables, Variable{name = name, scope_depth = c.scope_depth, stack_id = -1})
	c.var_count += 1
	return c.var_count - 1
}

get_variable_addr :: proc(c: ^Compiler, name: string) -> (ptr: i16) {
	for var, i in c.variables {
		if var.name == name {
			return i16(i)
		}
	}
	return -1
}

set_cursor :: proc(c: ^Compiler) {
	c.cursor = len(c.bytecode)
}

write_at_cursor :: proc(c: ^Compiler) {
	c.write_at_cursor = true
}

remove_cursor :: proc(c: ^Compiler) {
	c.write_at_cursor = false
	c.cursor = -1
}

current_byte_offset :: proc(c: ^Compiler) -> int {
	return len(c.bytecode)
}

push_byte :: proc(c: ^Compiler, b: byte) {
	if c.write_at_cursor {
		c.bytecode[c.cursor] = b
		c.cursor += 1
	} else {
		append(&c.bytecode, b)
	}
}

push_op_code :: #force_inline proc(c: ^Compiler, op: Op_Code) {
	push_byte(c, byte(op))
}

push_op_const_code :: proc(c: ^Compiler, addr: i16) {
	push_byte(c, byte(Op_Code.Op_Const))
	lower_addr := byte(addr)
	upper_addr := byte(addr >> 8)
	push_byte(c, lower_addr)
	push_byte(c, upper_addr)
}

push_op_set_code :: proc(c: ^Compiler, addr: i16) {
	push_byte(c, byte(Op_Code.Op_Set))
	lower_addr := byte(addr)
	upper_addr := byte(addr >> 8)
	push_byte(c, lower_addr)
	push_byte(c, upper_addr)
}

push_op_get_code :: proc(c: ^Compiler, addr: i16) {
	push_byte(c, byte(Op_Code.Op_Get))
	lower_addr := byte(addr)
	upper_addr := byte(addr >> 8)
	push_byte(c, lower_addr)
	push_byte(c, upper_addr)
}

push_op_jump_code :: proc(c: ^Compiler, to: i16, on_condition := false) {
	op := Op_Code.Op_Jump if !on_condition else Op_Code.Op_Jump_False
	push_byte(c, byte(op))
	lower_to := byte(to)
	upper_to := byte(to >> 8)
	push_byte(c, lower_to)
	push_byte(c, upper_to)
}

new_compiler :: proc() -> ^Compiler {
	return new_clone(
		Compiler{cursor = -1, bytecode = make([dynamic]byte), constants = make([dynamic]Value)},
	)
}

compile_module :: proc(c: ^Compiler, module: ^Checked_Module) -> (result: Chunk) {
	for node in module.nodes {
		compile_node(c, node)
	}

	result = Chunk {
		bytecode  = make([]byte, len(c.bytecode)),
		constants = make([]Value, len(c.constants)),
		variables = make([]Variable, len(c.variables)),
	}
	copy(result.bytecode[:], c.bytecode[:])
	copy(result.constants[:], c.constants[:])
	copy(result.variables[:], c.variables[:])
	return
}

compile_node :: proc(c: ^Compiler, node: Checked_Node) {
	switch n in node {
	case ^Checked_Expression_Statement:
		compile_expr(c, n.expr.expr)

	case ^Checked_Block_Statement:
		for inner in n.nodes {
			compile_node(c, inner)
		}

	case ^Checked_Assigment_Statement:
		compile_expr(c, n.right.expr)
		#partial switch e in n.left.expr {
		case ^Identifier_Expression:
			var_addr := get_variable_addr(c, e.name.text)
			push_op_set_code(c, var_addr)
		}

	case ^Checked_If_Statement:
		push_op_code(c, .Op_Begin)
		compile_expr(c, n.condition.expr)
		set_cursor(c)
		push_op_jump_code(c, -1, true)
		compile_node(c, n.body)
		push_op_code(c, .Op_End)

		write_at_cursor(c)
		push_op_jump_code(c, i16(current_byte_offset(c)), true)
		remove_cursor(c)

		if n.next_branch != nil {
			compile_node(c, n.next_branch)
		}


	case ^Checked_Range_Statement:
		push_op_code(c, .Op_Begin)
		defer push_op_code(c, .Op_End)

	case ^Checked_Var_Declaration:
		// Handle the case of uninitialized variables
		var_addr := add_variable(c, n.identifier.text)
		compile_expr(c, n.expr.expr)
		push_op_set_code(c, var_addr)

	case ^Checked_Fn_Declaration:
	case ^Checked_Type_Declaration:
	case ^Checked_Class_Declaration:
	}
}

compile_expr :: proc(c: ^Compiler, expr: Expression) {
	switch e in expr {
	case ^Literal_Expression:
		const_addr := add_constant(c, e.value)
		push_op_const_code(c, const_addr)

	case ^String_Literal_Expression:
	case ^Array_Literal_Expression:
	case ^Unary_Expression:
		compile_expr(c, e.expr)
		#partial switch e.op {
		case .Minus_Op:
			push_op_code(c, .Op_Neg)
		case .Not_Op:
			push_op_code(c, .Op_Not)
		}

	case ^Binary_Expression:
		compile_expr(c, e.left)
		compile_expr(c, e.right)
		#partial switch e.op {
		case .Plus_Op:
			push_op_code(c, .Op_Add)
		case .Minus_Op:
			push_op_code(c, .Op_Neg)
			push_op_code(c, .Op_Add)
		case .Mult_Op:
			push_op_code(c, .Op_Mul)
		case .Div_Op:
			push_op_code(c, .Op_Div)
		case .Rem_Op:
			push_op_code(c, .Op_Rem)
		case .Or_Op:
			push_op_code(c, .Op_Or)
		case .And_Op:
			push_op_code(c, .Op_And)
		}

	case ^Identifier_Expression:
		var_addr := get_variable_addr(c, e.name.text)
		push_op_get_code(c, var_addr)

	case ^Index_Expression:
	case ^Call_Expression:
	case ^Array_Type_Expression:
	}
}
