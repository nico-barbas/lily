package lily

LILY_DEBUG :: true

//odinfmt: disable
Op_Code :: enum byte {
	Op_Begin,      // Mark the begining of a stack scope, used for book keeping in the Vm
	Op_End,        // Mark the end of a stack scope, used for book keeping in the Vm
	Op_Pop,        // Get the last element from the stack and decrement its counter
	Op_Const,      // Take the constant from the associated constant pool and load it on to stack
	Op_Bind,       // Bind the variable name to the given stack id
	Op_Set,        // Bind the variable name to the current top of the stack
	Op_Set_Scoped, //
	Op_Get,        // Get the variable value from the the variable pool and load it on the stack
	Op_Get_Scoped, //
    Op_Inc,        // Get the last element, increment it and push it back on the stack
    Op_Dec,        // Get the last element, decrement it and push it back on the stack
    Op_Neg,        // Get the last element, negate it and push it back on the stack
	Op_Not,        // Get the last element, boolean negate it and push it back on the stack
	Op_Add,        // Get the last 2 elements, add them and push the result back on the stack
	Op_Mul,        // Get the last 2 elements, multiply them and push the result back on the stack
	Op_Div,
	Op_Rem,
	Op_And,
	Op_Or,
    Op_Eq,
    Op_Greater,
    Op_Greater_Eq,
    Op_Lesser,
    Op_Lesser_Eq,
	Op_Jump,
	Op_Jump_False,
	Op_Call,
	Op_Return,

	Op_Make_Array,
	Op_Assign_Array,
	Op_Index_Array,
	Op_Append_Array,

	Op_Make_Instance, // Allocate a class instance and leave a reference at the top of the stack
    Op_Call_Method,
}
//odinfmt: enable

instruction_lengths := map[Op_Code]int {
	.Op_Begin         = 1,
	.Op_End           = 1,
	.Op_Pop           = 1,
	.Op_Const         = 3,
	.Op_Set           = 4,
	.Op_Bind          = 5,
	.Op_Set_Scoped    = 3,
	.Op_Get           = 3,
	.Op_Get_Scoped    = 3,
	.Op_Inc           = 1,
	.Op_Dec           = 1,
	.Op_Neg           = 1,
	.Op_Not           = 1,
	.Op_Add           = 1,
	.Op_Mul           = 1,
	.Op_Div           = 1,
	.Op_Rem           = 1,
	.Op_And           = 1,
	.Op_Or            = 1,
	.Op_Eq            = 1,
	.Op_Greater       = 1,
	.Op_Greater_Eq    = 1,
	.Op_Lesser        = 1,
	.Op_Lesser_Eq     = 1,
	.Op_Jump          = 3,
	.Op_Jump_False    = 3,
	.Op_Call          = 3,
	.Op_Return        = 3,
	.Op_Make_Array    = 1,
	.Op_Assign_Array  = 1,
	.Op_Index_Array   = 1,
	.Op_Append_Array  = 1,
	.Op_Make_Instance = 3,
}

RANGE_HIGH_SLOT :: 1

Compiler :: struct {
	cursor:          int,
	write_at_cursor: bool,
	fn_names:        [dynamic]string,
	class_names:     [dynamic]struct {
		name:              string,
		constructor_names: [dynamic]string,
		method_names:      [dynamic]string,
	},
	bytecode:        [dynamic]byte,
	constants:       [dynamic]Value,
	variables:       [dynamic]Variable,
	const_count:     i16,
	var_count:       i16,
	scope_depth:     int,
}

Compiled_Module :: struct {
	class_names:       []string,
	classe_prototypes: []Class_Object,
	class_vtables:     []Class_Vtable,
	function_names:    []string,
	functions:         [dynamic]Fn_Object,
	main:              Chunk,
}

Chunk :: struct {
	bytecode:  []byte,
	constants: []Value,
	variables: []Variable,
}

Variable :: struct {
	name:              string,
	scope_depth:       int,
	stack_id:          int,
	relative_stack_id: int,
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

get_fn_addr :: proc(c: ^Compiler, name: string) -> (ptr: i16) {
	for fn_name, i in c.fn_names {
		if fn_name == name {
			return i16(i)
		}
	}
	return -1
}

get_class_addr :: proc(c: ^Compiler, name: string) -> (ptr: i16) {
	for class_name, i in c.class_names {
		if class_name.name == name {
			return i16(i)
		}
	}
	return -1
}

set_cursor_at_and_write :: proc(c: ^Compiler, pos: int) {
	c.cursor = pos
	c.write_at_cursor = true
}

remove_cursor :: proc(c: ^Compiler) {
	c.write_at_cursor = false
	c.cursor = -1
}

current_byte_offset :: proc(c: ^Compiler) -> int {
	return len(c.bytecode)
}

reserve_bytes :: proc(c: ^Compiler, count: int) {
	for _ in 0 ..< count {
		push_byte(c, 0)
	}
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

push_op_set_code :: proc(c: ^Compiler, addr: i16, pop_last: bool) {
	push_byte(c, byte(Op_Code.Op_Set))
	push_byte(c, byte(pop_last))
	lower_addr := byte(addr)
	upper_addr := byte(addr >> 8)
	push_byte(c, lower_addr)
	push_byte(c, upper_addr)
}

push_op_bind_code :: proc(c: ^Compiler, var_addr: i16, rel_addr: i16) {
	push_byte(c, byte(Op_Code.Op_Bind))
	lower_addr := byte(var_addr)
	upper_addr := byte(var_addr >> 8)
	push_byte(c, lower_addr)
	push_byte(c, upper_addr)

	lower_addr = byte(rel_addr)
	upper_addr = byte(rel_addr >> 8)
	push_byte(c, lower_addr)
	push_byte(c, upper_addr)
}

push_op_set_scoped_code :: proc(c: ^Compiler, rel_addr: i16) {
	push_byte(c, byte(Op_Code.Op_Set_Scoped))
	lower_addr := byte(rel_addr)
	upper_addr := byte(rel_addr >> 8)
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

push_op_get_scoped_code :: proc(c: ^Compiler, rel_addr: i16) {
	push_byte(c, byte(Op_Code.Op_Get_Scoped))
	lower_addr := byte(rel_addr)
	upper_addr := byte(rel_addr >> 8)
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

push_op_call_code :: proc(c: ^Compiler, fn_addr: i16) {
	push_byte(c, byte(Op_Code.Op_Call))
	lower_addr := byte(fn_addr)
	upper_addr := byte(fn_addr >> 8)
	push_byte(c, lower_addr)
	push_byte(c, upper_addr)
}

push_op_return_code :: proc(c: ^Compiler, result_addr: i16) {
	push_byte(c, byte(Op_Code.Op_Return))
	lower_addr := byte(result_addr)
	upper_addr := byte(result_addr >> 8)
	push_byte(c, lower_addr)
	push_byte(c, upper_addr)
}

push_op_make_instance_code :: proc(c: ^Compiler, class_addr: i16) {
	push_byte(c, byte(Op_Code.Op_Make_Instance))
	lower_addr := byte(class_addr)
	upper_addr := byte(class_addr >> 8)
	push_byte(c, lower_addr)
	push_byte(c, upper_addr)
}

new_compiler :: proc() -> ^Compiler {
	return new_clone(
		Compiler{cursor = -1, bytecode = make([dynamic]byte), constants = make([dynamic]Value)},
	)
}

reset_compiler :: proc(c: ^Compiler) {
	clear(&c.bytecode)
	clear(&c.constants)
	clear(&c.variables)
	c.const_count = 0
	c.var_count = 0
	c.cursor = -1
	c.write_at_cursor = false
}

compile_module :: proc(c: ^Compiler, module: ^Checked_Module) -> ^Compiled_Module {
	m := new_clone(
		Compiled_Module{
			classe_prototypes = make([]Class_Object, len(module.classes)),
			class_vtables = make([]Class_Vtable, len(module.classes)),
			functions = make([dynamic]Fn_Object),
		},
	)

	for class, i in module.classes {
		class_decl := class.(^Checked_Class_Declaration)
		prototype := Class_Object {
			base = Object{kind = .Class},
			fields = make([]Class_Field, len(class_decl.field_names)),
		}
		for field, i in class_decl.field_names {
			prototype.fields[i] = Class_Field {
				name = field.text,
				value = Value{},
			}
		}

		vtable := Class_Vtable {
			constructors = make([]Chunk, len(class_decl.constructors)),
			methods      = make([]Chunk, len(class_decl.methods)),
		}

		for constructor, i in class_decl.constructors {
			constructor_chunk := compile_class_constructor(c, constructor, i16(i))
			vtable.constructors[i] = constructor_chunk
			reset_compiler(c)
		}

		for method, i in class_decl.methods {
			method_chunk := compile_class_method(c, method, i16(i))
			vtable.methods[i] = method_chunk
			reset_compiler(c)
		}

		m.class_vtables[i] = vtable
		prototype.vtable = &m.class_vtables[i]
		m.classe_prototypes[i] = prototype
		append(&c.class_names, class_decl.identifier.text)
	}

	for fn_decl, i in module.functions {
		fn := fn_decl.(^Checked_Fn_Declaration)
		fn_chunk := compile_chunk(c, module.functions[i:i + 1])
		append(&m.functions, Fn_Object{base = Object{kind = .Fn}, chunk = fn_chunk})
		append(&c.fn_names, fn.identifier.text)
		reset_compiler(c)
	}

	m.main = compile_chunk(c, module.nodes[:])
	when LILY_DEBUG {
		m.class_names = make([]string, len(c.class_names))
		m.function_names = make([]string, len(c.fn_names))
		copy(m.class_names[:], c.class_names[:])
		copy(m.function_names[:], c.fn_names[:])
	}
	clear(&c.class_names)
	clear(&c.fn_names)
	return m
}

compile_chunk :: proc(c: ^Compiler, nodes: []Checked_Node) -> (result: Chunk) {
	for node in nodes {
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

compile_chunk_node :: proc(c: ^Compiler, node: Checked_Node) -> (result: Chunk) {
	compile_node(c, node)
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

compile_class_constructor :: proc(
	c: ^Compiler,
	constr: ^Checked_Fn_Declaration,
	class_addr: i16,
) -> (
	result: Chunk,
) {

	compile_constructor: {
		// 1. Allocate a new class instance
		// 2. bind "self" to the new class
		push_op_make_instance_code(c, class_addr)
		self_addr := add_variable(c, "self")
		push_op_bind_code(c, self_addr, 0)
		for name, i in constr.param_names {
			param_addr := add_variable(c, name.text)
			push_op_bind_code(c, param_addr, i16(i + 1))
		}
		compile_node(c, constr.body)
		push_op_return_code(c, self_addr)
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

compile_class_method :: proc(c: ^Compiler, method: ^Checked_Fn_Declaration, class_addr: i16) -> (
	result: Chunk,
) {

	compile_method: {
		// 1. Allocate a new class instance
		// 2. bind "self" to the new class
		self_addr := add_variable(c, "self")
		push_op_bind_code(c, self_addr, 0)

		param_ptr: i16 = 0
		result_addr: i16
		fn_signature := method.type_info.type_id_data.(Fn_Signature_Info)
		is_void := fn_signature.return_type_id == UNTYPED_ID
		if !is_void {
			result_addr = add_variable(c, "result")
			push_op_bind_code(c, result_addr, param_ptr)
			param_ptr += 1
		}

		for name, i in method.param_names {
			param_addr := add_variable(c, name.text)
			push_op_bind_code(c, param_addr, i16(i + 1))
		}

		compile_node(c, method.body)
		if !is_void {
			push_op_return_code(c, result_addr)
		}
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
		compile_expr(c, n.expr)
		push_op_code(c, .Op_Pop)

	case ^Checked_Block_Statement:
		for inner in n.nodes {
			compile_node(c, inner)
		}

	case ^Checked_Assigment_Statement:
		compile_expr(c, n.right)
		#partial switch e in n.left {
		case ^Checked_Identifier_Expression:
			var_addr := get_variable_addr(c, e.name.text)
			push_op_set_code(c, var_addr, true)
		case ^Checked_Index_Expression:
			identifier := e.left.text
			var_addr := get_variable_addr(c, identifier)
			compile_expr(c, e.index)
			push_op_get_code(c, var_addr)
			push_op_code(c, .Op_Assign_Array)
		}

	case ^Checked_If_Statement:
		// TODO: Use the temp allocator
		branch_cursor := 0
		cursors := make([dynamic]int)
		defer delete(cursors)

		current_branch := n
		branch_exist: bool

		if_loop: for {
			// Push a scope and evaluate the conditional expression
			push_op_code(c, .Op_Begin)
			compile_expr(c, current_branch.condition)

			// We keep track of this instruction to specify the jump location after 
			// we discover the end of this branch's body
			branch_cursor = len(c.bytecode)
			reserve_bytes(c, instruction_lengths[.Op_Jump_False])

			// Compile the body and pop the scope
			compile_node(c, current_branch.body)
			push_op_code(c, .Op_End)

			// We keep a track of this instruction too 
			// This is the Op_Jump in case the branch evaluate to true,
			// We execute the body and need to get out of the if statement
			append(&cursors, len(c.bytecode))
			reserve_bytes(c, instruction_lengths[.Op_Jump])

			set_cursor_at_and_write(c, branch_cursor)
			push_op_jump_code(c, i16(current_byte_offset(c)), true)
			remove_cursor(c)
			current_branch, branch_exist = current_branch.next_branch.(^Checked_If_Statement)
			if !branch_exist {
				break if_loop
			}
		}

		for cursor in cursors {
			set_cursor_at_and_write(c, cursor)
			push_op_jump_code(c, i16(current_byte_offset(c)), false)
			remove_cursor(c)
		}


	case ^Checked_Range_Statement:
		push_op_code(c, .Op_Begin)
		defer push_op_code(c, .Op_End)
		iterator_addr := add_variable(c, n.iterator_name.text)
		compile_expr(c, n.low)
		push_op_set_code(c, iterator_addr, true)
		compile_expr(c, n.high)
		push_op_set_scoped_code(c, RANGE_HIGH_SLOT)

		loop_start_cursor := current_byte_offset(c)
		push_op_get_code(c, iterator_addr)
		push_op_get_scoped_code(c, RANGE_HIGH_SLOT)
		// push_op_get_code(c, max_addr)
		switch n.op {
		case .Inclusive:
			push_op_code(c, .Op_Lesser_Eq)
		case .Exclusive:
			push_op_code(c, .Op_Lesser)
		}

		loop_break_cursor := current_byte_offset(c)
		reserve_bytes(c, instruction_lengths[.Op_Jump_False])

		compile_node(c, n.body)
		push_op_get_code(c, iterator_addr)
		push_op_code(c, .Op_Inc)
		push_op_set_code(c, iterator_addr, true)
		push_op_jump_code(c, i16(loop_start_cursor), false)

		set_cursor_at_and_write(c, loop_break_cursor)
		push_op_jump_code(c, i16(current_byte_offset(c)), true)
		remove_cursor(c)


	case ^Checked_Var_Declaration:
		// Handle the case of uninitialized variables
		var_addr := add_variable(c, n.identifier.text)
		compile_expr(c, n.expr)
		push_op_set_code(c, var_addr, true)

	case ^Checked_Fn_Declaration:
		// Bind all the variable to stack slot
		param_ptr: i16 = 0
		result_addr: i16
		fn_signature := n.type_info.type_id_data.(Fn_Signature_Info)
		is_void := fn_signature.return_type_id == UNTYPED_ID
		if !is_void {
			result_addr = add_variable(c, "result")
			push_op_bind_code(c, result_addr, param_ptr)
			param_ptr += 1
		}
		for name, i in n.param_names {
			param_addr := add_variable(c, name.text)
			push_op_bind_code(c, param_addr, param_ptr + i16(i))
		}


		compile_node(c, n.body)
		if !is_void {
			push_op_return_code(c, result_addr)
		}

	case ^Checked_Type_Declaration:
	case ^Checked_Class_Declaration:
	}
}

compile_expr :: proc(c: ^Compiler, expr: Checked_Expression) {
	switch e in expr {
	case ^Checked_Literal_Expression:
		const_addr := add_constant(c, e.value)
		push_op_const_code(c, const_addr)

	case ^Checked_String_Literal_Expression:
		// Allocate a new string object and shove the reference in the constant pool
		str := make([]rune, len(e.value))
		for r, i in e.value {
			str[i] = r
		}
		obj := new_clone(String_Object{base = Object{kind = .String}, data = str})
		str_object := Value {
			kind = .Object_Ref,
			data = cast(^Object)obj,
		}
		str_addr := add_constant(c, str_object)
		push_op_const_code(c, str_addr)

	case ^Checked_Array_Literal_Expression:
		array_addr: i16 = 0
		for i := len(e.values) - 1; i >= 0; i -= 1 {
			value_expr := e.values[i]
			compile_expr(c, value_expr)
		}
		push_op_code(c, .Op_Make_Array)

		for i in 0 ..< len(e.values) {
			push_op_code(c, .Op_Append_Array)
		}


	case ^Checked_Unary_Expression:
		compile_expr(c, e.expr)
		#partial switch e.op {
		case .Minus_Op:
			push_op_code(c, .Op_Neg)
		case .Not_Op:
			push_op_code(c, .Op_Not)
		}

	case ^Checked_Binary_Expression:
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
		case .Greater_Op:
			push_op_code(c, .Op_Greater)
		case .Greater_Eq_Op:
			push_op_code(c, .Op_Greater_Eq)
		case .Lesser_Op:
			push_op_code(c, .Op_Lesser)
		case .Lesser_Eq_Op:
			push_op_code(c, .Op_Lesser_Eq)
		}

	case ^Checked_Identifier_Expression:
		var_addr := get_variable_addr(c, e.name.text)
		push_op_get_code(c, var_addr)

	case ^Checked_Index_Expression:
		// Compile the index expression and leave it on the stack
		// Put the array on top of the stack

		identifier := e.left.text
		var_addr := get_variable_addr(c, identifier)
		compile_expr(c, e.index)
		push_op_get_code(c, var_addr)
		push_op_code(c, .Op_Index_Array)

	case ^Checked_Dot_Expression:
		switch e.kind {
		case .Module:
			assert(false, "Module not implemented yet")
		case .Class:
			class_addr := get_class_addr(c, e.left.text)
			class := c
		case .Instance:

		}

	case ^Checked_Call_Expression:
		push_op_code(c, .Op_Begin)
		for arg_expr in e.args {
			compile_expr(c, arg_expr)
		}
		fn_identifier := e.func.(^Checked_Identifier_Expression)
		fn_addr := get_fn_addr(c, fn_identifier.name.text)
		push_op_call_code(c, fn_addr)

	}
}
