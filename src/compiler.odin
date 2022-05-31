package lily

Op_Code :: enum byte {
	Op_Const, // Take the constant from the associated constant pool and load it on to stack 
	Op_Pop,
	Op_Neg,
	Op_Add,
}

Compiler :: struct {
	bytecode:    [dynamic]byte,
	constants:   [dynamic]Value,
	const_count: i16,
}

Chunk :: struct {
	bytecode:  []byte,
	constants: []Value,
}

add_constant :: proc(c: ^Compiler, constant: Value) -> (ptr: i16) {
	append(&c.constants, constant)
	c.const_count += 1
	return c.const_count - 1
}

push_byte :: proc(c: ^Compiler, b: byte) {
	append(&c.bytecode, b)
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

new_compiler :: proc() -> ^Compiler {
	return new_clone(Compiler{bytecode = make([dynamic]byte), constants = make([dynamic]Value)})
}

compile_module :: proc(c: ^Compiler, module: ^Checked_Module) -> (result: Chunk) {
	for node in module.nodes {
		compile_node(c, node)
	}

	result = Chunk {
		bytecode  = make([]byte, len(c.bytecode)),
		constants = make([]Value, len(c.constants)),
	}
	copy(result.bytecode[:], c.bytecode[:])
	copy(result.constants[:], c.constants[:])
	return
}

compile_node :: proc(c: ^Compiler, node: Checked_Node) {
	switch n in node {
	case ^Checked_Expression_Statement:
		compile_expr(c, n.expr.expr)

	case ^Checked_Block_Statement:
	case ^Checked_Assigment_Statement:
	case ^Checked_If_Statement:
	case ^Checked_Range_Statement:
	case ^Checked_Var_Declaration:
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
	case ^Binary_Expression:
		compile_expr(c, e.left)
		compile_expr(c, e.right)
		#partial switch e.op {
		case .Plus_Op:
			push_op_code(c, .Op_Add)
		}

	case ^Identifier_Expression:
	case ^Index_Expression:
	case ^Call_Expression:
	case ^Array_Type_Expression:
	}
}
