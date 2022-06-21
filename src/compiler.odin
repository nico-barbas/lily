package lily

// import "core:mem"
// import "core:fmt"

LILY_DEBUG :: true

// FIXME: Remove all string comparisons from the compiler if possible
// Most of them can be done during the semantic analysis.
// All the functions, classes (methods and constr) lands at the same index from checker to compiler
// Meaning we can just store it during semantic analysis.

//odinfmt: disable
Op_Code :: enum byte {
	Op_Begin,      // Mark the begining of a stack scope, used for book keeping in the Vm
	Op_End,        // Mark the end of a stack scope, used for book keeping in the Vm
	Op_Push,       // Increment the stack counter
	Op_Pop,        // Get the last element from the stack and decrement its counter
	Op_Const,      // Take the constant from the associated constant pool and load it on to stack
	Op_Set_Global,
	Op_Get_Global,
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
	Op_Return_Val,
	Op_Return,

	Op_Push_Module,
	Op_Pop_Module,

	Op_Make_Array,
	Op_Assign_Array,
	Op_Index_Array,
	Op_Append_Array,
	Op_Len_Array,

	Op_Make_Instance, // Allocate a class instance and leave a reference at the top of the stack
    Op_Call_Constr,
	Op_Call_Method,
	Op_Get_Field,
	Op_Set_Field,
}
//odinfmt: enable

instruction_lengths := map[Op_Code]int {
	.Op_Begin         = 1,
	.Op_End           = 1,
	.Op_Push          = 1,
	.Op_Pop           = 1,
	.Op_Const         = 3,
	.Op_Set_Global    = 3,
	.Op_Get_Global    = 3,
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
	.Op_Return_Val    = 3,
	.Op_Return        = 1,
	.Op_Push_Module   = 3,
	.Op_Pop_Module    = 1,
	.Op_Make_Array    = 1,
	.Op_Assign_Array  = 1,
	.Op_Index_Array   = 1,
	.Op_Append_Array  = 1,
	.Op_Len_Array     = 1,
	.Op_Make_Instance = 3,
	.Op_Call_Constr   = 5,
	.Op_Call_Method   = 5,
	.Op_Get_Field     = 3,
	.Op_Set_Field     = 3,
}

RANGE_HIGH_SLOT :: 1

Compiler :: struct {
	cursor:                  int,
	write_at_cursor:         bool,
	fn_names:                [dynamic]string,
	class_info:              [dynamic]^Checked_Class_Declaration,
	bytecode:                [dynamic]byte,
	constants:               [dynamic]Value,
	variables:               [dynamic]Variable,
	module_variables_lookup: map[string]i16,
	const_count:             i16,
	var_count:               i16,
	scope_depth:             int,
}

Compiled_Module :: struct {
	id:                int,
	class_names:       []string,
	classe_prototypes: []Class_Object,
	class_vtables:     []Class_Vtable,
	function_names:    []string,
	functions:         []Fn_Object,
	module_variables:  []Value,
	main:              Chunk,
}

Chunk :: struct {
	bytecode:  []byte,
	constants: []Value,
	variables: []Variable,
}

Variable :: struct {
	name:              string,
	type_info:         Type_Info,
	scope_depth:       int,
	stack_id:          int,
	relative_stack_id: int,
}

add_constant :: proc(c: ^Compiler, constant: Value) -> (ptr: i16) {
	append(&c.constants, constant)
	c.const_count += 1
	return c.const_count - 1
}

add_variable :: proc(c: ^Compiler, name: string, type_info: Type_Info) -> (ptr: i16) {
	var := Variable {
		name        = name,
		type_info   = type_info,
		scope_depth = c.scope_depth,
		stack_id    = -1,
	}
	switch {
	case c.scope_depth == 0:
		// append(&c.module_variables, var)
		// c.module_var_count += 1
		// return c.module_var_count
		return c.module_variables_lookup[name]
	case:
		append(&c.variables, var)
		c.var_count += 1
		return c.var_count - 1
	}
}

get_variable_addr :: proc(c: ^Compiler, name: string) -> (result: i16, global: bool) {
	if addr, exist := c.module_variables_lookup[name]; exist {
		result = addr
		global = true
		return
	}
	for var, i in c.variables {
		if var.name == name {
			result = i16(i)
			global = false
			return
		}
	}
	return -1, false
}

get_fn_addr :: proc(c: ^Compiler, name: string) -> i16 {
	for fn_name, i in c.fn_names {
		if fn_name == name {
			return i16(i)
		}
	}
	return -1
}

get_class_addr :: proc(c: ^Compiler, name: string) -> i16 {
	for class, i in c.class_info {
		if class.identifier.text == name {
			return i16(i)
		}
	}
	return -1
}

get_constructor_addr :: proc(c: ^Compiler, class_addr: i16, name: string) -> i16 {
	class := c.class_info[class_addr]
	for constructor, i in class.constructors {
		if constructor.identifier.text == name {
			return i16(i)
		}
	}
	return -1
}

get_field_addr :: proc(c: ^Compiler, instance_addr: i16, name: string) -> i16 {
	instance := c.variables[instance_addr]
	class_addr := get_class_addr(c, instance.type_info.name)
	class := c.class_info[class_addr]
	for field, i in class.field_names {
		if field.text == name {
			return i16(i)
		}
	}
	return -1
}

get_method_addr :: proc(c: ^Compiler, instance_addr: i16, name: string) -> i16 {
	instance := c.variables[instance_addr]
	class_addr := get_class_addr(c, instance.type_info.name)
	class := c.class_info[class_addr]
	for method, i in class.methods {
		if method.identifier.text == name {
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

push_op_set_global_code :: proc(c: ^Compiler, addr: i16) {
	push_byte(c, byte(Op_Code.Op_Set_Global))
	lower_addr := byte(addr)
	upper_addr := byte(addr >> 8)
	push_byte(c, lower_addr)
	push_byte(c, upper_addr)
}

push_op_get_global_code :: proc(c: ^Compiler, addr: i16) {
	push_byte(c, byte(Op_Code.Op_Get_Global))
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
	push_byte(c, byte(Op_Code.Op_Return_Val))
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

push_op_call_constr_code :: proc(c: ^Compiler, class_addr: i16, constr_addr: i16) {
	push_byte(c, byte(Op_Code.Op_Call_Constr))
	lower_addr := byte(class_addr)
	upper_addr := byte(class_addr >> 8)
	push_byte(c, lower_addr)
	push_byte(c, upper_addr)

	lower_addr = byte(constr_addr)
	upper_addr = byte(constr_addr >> 8)
	push_byte(c, lower_addr)
	push_byte(c, upper_addr)
}

push_op_call_method_code :: proc(c: ^Compiler, method_addr: i16) {
	push_byte(c, byte(Op_Code.Op_Call_Method))
	// lower_addr := byte(instance_addr)
	// upper_addr := byte(instance_addr >> 8)
	// push_byte(c, lower_addr)
	// push_byte(c, upper_addr)

	lower_addr := byte(method_addr)
	upper_addr := byte(method_addr >> 8)
	push_byte(c, lower_addr)
	push_byte(c, upper_addr)
}

push_op_get_field_code :: proc(c: ^Compiler, field_addr: i16) {
	push_byte(c, byte(Op_Code.Op_Get_Field))
	// lower_addr := byte(instance_addr)
	// upper_addr := byte(instance_addr >> 8)
	// push_byte(c, lower_addr)
	// push_byte(c, upper_addr)

	lower_addr := byte(field_addr)
	upper_addr := byte(field_addr >> 8)
	push_byte(c, lower_addr)
	push_byte(c, upper_addr)
}

push_op_set_field_code :: proc(c: ^Compiler, field_addr: i16) {
	push_byte(c, byte(Op_Code.Op_Set_Field))
	// lower_addr := byte(instance_addr)
	// upper_addr := byte(instance_addr >> 8)
	// push_byte(c, lower_addr)
	// push_byte(c, upper_addr)

	lower_addr := byte(field_addr)
	upper_addr := byte(field_addr >> 8)
	push_byte(c, lower_addr)
	push_byte(c, upper_addr)
}

make_chunk :: proc(c: ^Compiler) -> (result: Chunk) {
	result = Chunk {
		bytecode  = make([]byte, len(c.bytecode)),
		constants = make([]Value, len(c.constants)),
		variables = make([]Variable, len(c.variables)),
	}
	copy(result.bytecode, c.bytecode[:])
	copy(result.constants, c.constants[:])
	copy(result.variables, c.variables[:])
	reset_compiler(c)
	return
}

delete_chunk :: proc(c: ^Chunk) {
	delete(c.bytecode)
	delete(c.variables)
	delete(c.constants)
}

make_compiled_module :: proc(checked_module: ^Checked_Module) -> ^Compiled_Module {
	return new_clone(
		Compiled_Module{
			id = checked_module.id,
			classe_prototypes = make([]Class_Object, len(checked_module.classes)),
			class_vtables = make([]Class_Vtable, len(checked_module.classes)),
			functions = make([]Fn_Object, len(checked_module.functions)),
			module_variables = make([]Value, len(checked_module.variables)),
		},
	)
}

delete_compiled_module :: proc(m: ^Compiled_Module) {
	delete(m.class_names)
	for prototype in m.classe_prototypes {
		delete(prototype.fields)
	}
	delete(m.classe_prototypes)
	for vtable in m.class_vtables {
		for constructor in vtable.constructors {
			constr_chunk := constructor.chunk
			delete_chunk(&constr_chunk)
		}
		delete(vtable.constructors)
		for method in vtable.methods {
			method_chunk := method.chunk
			delete_chunk(&method_chunk)
		}
		delete(vtable.methods)
	}
	delete(m.class_vtables)
	for fn_object in m.functions {
		fn_chunk := fn_object.chunk
		delete_chunk(&fn_chunk)
	}
	delete(m.function_names)
	delete(m.functions)
	delete_chunk(&m.main)
	free(m)
}

new_compiler :: proc() -> ^Compiler {
	return new_clone(
		Compiler{cursor = -1, bytecode = make([dynamic]byte), constants = make([dynamic]Value)},
	)
}

free_compiler :: proc(c: ^Compiler) {
	delete(c.fn_names)
	delete(c.class_info)
	delete(c.bytecode)
	delete(c.constants)
	delete(c.variables)
	free(c)
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

compile_module :: proc(c: ^Compiler, modules: []^Checked_Module, module_id: int) -> ^Compiled_Module {
	module := modules[module_id]
	m := make_compiled_module(module)

	for v, i in module.variables {
		var_decl := v.(^Checked_Var_Declaration)
		c.module_variables_lookup[var_decl.identifier.text] = i16(i)
	}

	for class, i in module.classes {
		class_decl := class.(^Checked_Class_Declaration)
		append(&c.class_info, class_decl)
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
			constructors = make([]Fn_Object, len(class_decl.constructors)),
			methods      = make([]Fn_Object, len(class_decl.methods)),
		}

		for constructor, i in class_decl.constructors {
			constructor_chunk := compile_class_constructor(c, constructor, i16(i))
			vtable.constructors[i] = Fn_Object {
				base = Object{kind = .Fn},
				chunk = constructor_chunk,
			}
		}

		for method, i in class_decl.methods {
			method_chunk := compile_class_method(c, method, i16(i))
			vtable.methods[i] = Fn_Object {
				base = Object{kind = .Fn},
				chunk = method_chunk,
			}
		}

		m.class_vtables[i] = vtable
		prototype.vtable = &m.class_vtables[i]
		m.classe_prototypes[i] = prototype
	}

	for fn_decl, i in module.functions {
		fn := fn_decl.(^Checked_Fn_Declaration)
		fn_chunk := compile_chunk_node(c, fn_decl)
		m.functions[i] = Fn_Object {
			base = Object{kind = .Fn},
			chunk = fn_chunk,
		}
		append(&c.fn_names, fn.identifier.text)
	}

	compile_chunk(c, module.variables[:], false)
	m.main = compile_chunk(c, module.nodes[:], true)
	when LILY_DEBUG {
		m.class_names = make([]string, len(c.class_info))
		m.function_names = make([]string, len(c.fn_names))
		copy(m.function_names[:], c.fn_names[:])

		for class, i in c.class_info {
			m.class_names[i] = class.identifier.text
		}
	}
	clear(&c.class_info)
	clear(&c.fn_names)
	clear(&c.module_variables_lookup)
	return m
}

compile_chunk :: proc(c: ^Compiler, nodes: []Checked_Node, to_chunk: bool) -> (result: Chunk) {
	for node in nodes {
		compile_node(c, node)
	}
	if to_chunk {
		result = make_chunk(c)
	}
	return
}

compile_chunk_node :: proc(c: ^Compiler, node: Checked_Node) -> (result: Chunk) {
	compile_node(c, node)
	result = make_chunk(c)
	return
}

compile_class_constructor :: proc(c: ^Compiler, constr: ^Checked_Fn_Declaration, class_addr: i16) -> (
	result: Chunk,
) {
	c.scope_depth = 2
	defer c.scope_depth = 0
	compile_constructor: {
		// 1. Allocate a new class instance
		// 2. bind "self" to the new class
		class_info := c.class_info[class_addr].type_info
		constr_signature := constr.type_info.type_id_data.(Fn_Signature_Info)


		for name, i in constr.param_names {
			param_type := constr_signature.parameters[i]
			param_addr := add_variable(c, name.text, param_type)
			push_op_bind_code(c, param_addr, i16(i))
		}
		push_op_make_instance_code(c, class_addr)
		self_addr := add_variable(c, "self", class_info)
		push_op_set_code(c, self_addr, true)

		compile_node(c, constr.body)
		push_op_return_code(c, self_addr)
	}
	result = make_chunk(c)
	return
}

compile_class_method :: proc(c: ^Compiler, method: ^Checked_Fn_Declaration, class_addr: i16) -> (
	result: Chunk,
) {
	c.scope_depth = 2
	defer c.scope_depth = 0
	compile_method: {
		// 1. Allocate a new class instance
		// 2. bind "self" to the new class
		class_info := c.class_info[class_addr].type_info


		self_addr := add_variable(c, "self", class_info)
		push_op_bind_code(c, self_addr, 0)

		param_ptr: i16 = 0
		result_addr: i16
		fn_signature := method.type_info.type_id_data.(Fn_Signature_Info)
		is_void := fn_signature.return_type_info.type_id == UNTYPED_ID
		if !is_void {
			result_addr = add_variable(c, "result", fn_signature.return_type_info^)
			push_op_bind_code(c, result_addr, param_ptr)
			param_ptr += 1
		}

		for name, i in method.param_names {
			param_addr := add_variable(c, name.text, fn_signature.parameters[i])
			push_op_bind_code(c, param_addr, i16(i + 1))
		}

		compile_node(c, method.body)
		if !is_void {
			push_op_return_code(c, result_addr)
		} else {
			push_op_code(c, .Op_Return)
		}
	}
	result = make_chunk(c)
	return
}

compile_node :: proc(c: ^Compiler, node: Checked_Node) {
	switch n in node {
	case ^Checked_Expression_Statement:
		compile_expr(c, n.expr)

	case ^Checked_Block_Statement:
		for inner in n.nodes {
			compile_node(c, inner)
		}

	case ^Checked_Assigment_Statement:
		compile_expr(c, n.right)
		#partial switch e in n.left {
		case ^Checked_Identifier_Expression:
			var_addr, global := get_variable_addr(c, e.name.text)
			if global {
				push_op_set_global_code(c, var_addr)
			} else {
				push_op_set_code(c, var_addr, true)
			}
		case ^Checked_Index_Expression:
			identifier := e.left.text
			var_addr, global := get_variable_addr(c, identifier)
			compile_expr(c, e.index)
			if global {
				push_op_get_global_code(c, var_addr)
			} else {
				push_op_get_code(c, var_addr)
			}
			push_op_code(c, .Op_Assign_Array)
		case ^Checked_Dot_Expression:
			// FIXME: Doesn't support multi modules
			instance_addr, global := get_variable_addr(c, e.left.text)
			if global {
				push_op_get_global_code(c, instance_addr)
			} else {
				push_op_get_code(c, instance_addr)
			}
			// field_identifier := e.selector.(^Checked_Identifier_Expression)
			// field_addr := get_field_addr(c, instance_addr, field_identifier.name.text)
			field_addr := i16(e.selector_id)
			push_op_set_field_code(c, field_addr)
		}

	case ^Checked_If_Statement:
		// TODO: Use the temp allocator
		// FIXME: Remove useless jump at the end of 1 branch ifs
		branch_cursor := 0
		cursors := make([dynamic]int)
		defer delete(cursors)

		current_branch := n
		branch_exist: bool

		if_loop: for {
			// Push a scope and evaluate the conditional expression
			c.scope_depth += 1
			defer c.scope_depth -= 1
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
			current_branch, branch_exist = current_branch.next_branch.(^Checked_If_Statement)


			set_cursor_at_and_write(c, branch_cursor)
			push_op_jump_code(c, i16(current_byte_offset(c)), true)
			remove_cursor(c)
			if branch_exist {
				append(&cursors, len(c.bytecode))
				reserve_bytes(c, instruction_lengths[.Op_Jump])
			} else {
				break if_loop
			}
		}

		for cursor in cursors {
			set_cursor_at_and_write(c, cursor)
			push_op_jump_code(c, i16(current_byte_offset(c)), false)
			remove_cursor(c)
		}


	case ^Checked_Range_Statement:
		c.scope_depth += 1
		defer c.scope_depth -= 1
		push_op_code(c, .Op_Begin)
		defer push_op_code(c, .Op_End)
		iterator_addr := add_variable(c, n.iterator_name.text, n.iterator_type_info)
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
		// FIXME: Handle the case of uninitialized variables
		switch {
		case c.scope_depth == 0:
			var_addr, _ := get_variable_addr(c, n.identifier.text)
			compile_expr(c, n.expr)
			push_op_set_global_code(c, var_addr)
		case:
			var_addr := add_variable(c, n.identifier.text, n.type_info)
			compile_expr(c, n.expr)
			push_op_set_code(c, var_addr, true)
		}

	case ^Checked_Fn_Declaration:
		// Bind all the variable to stack slot
		c.scope_depth += 1
		defer c.scope_depth -= 1
		param_ptr: i16 = 0
		result_addr: i16
		fn_signature := n.type_info.type_id_data.(Fn_Signature_Info)
		is_void := fn_signature.return_type_info.type_id == UNTYPED_ID
		if !is_void {
			result_addr = add_variable(c, "result", fn_signature.return_type_info^)
			push_op_bind_code(c, result_addr, param_ptr)
			param_ptr += 1
		}
		for name, i in n.param_names {
			param_addr := add_variable(c, name.text, fn_signature.parameters[i])
			push_op_bind_code(c, param_addr, param_ptr + i16(i))
		}


		compile_node(c, n.body)
		if !is_void {
			push_op_return_code(c, result_addr)
		} else {
			push_op_code(c, .Op_Return)
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
		case .Equal_Op:
			push_op_code(c, .Op_Eq)
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
		var_addr, global := get_variable_addr(c, e.name.text)
		if global {
			push_op_get_global_code(c, var_addr)
		} else {
			push_op_get_code(c, var_addr)
		}

	case ^Checked_Index_Expression:
		// Compile the index expression and leave it on the stack
		// Put the array on top of the stack

		identifier := e.left.text
		var_addr, global := get_variable_addr(c, identifier)
		compile_expr(c, e.index)
		if global {
			push_op_get_global_code(c, var_addr)
		} else {
			push_op_get_code(c, var_addr)
		}
		push_op_code(c, .Op_Index_Array)

	case ^Checked_Dot_Expression:
		switch e.kind {
		case .Module:


		case .Class:
			call_expr := e.selector.(^Checked_Call_Expression)
			call_identifier := call_expr.func.(^Checked_Identifier_Expression)
			class_addr := i16(e.left_id)
			constr_addr := i16(e.selector_id)


			push_op_code(c, .Op_Begin)
			// push_op_code(c, .Op_Push) // Save a slot for "self" ref
			for arg_expr in call_expr.args {
				compile_expr(c, arg_expr)
			}
			push_op_call_constr_code(c, class_addr, constr_addr)

		case .Instance_Field:
			// 1. Get the instance ref at the top of the stack
			// 2. Extract the field value and push it on the stack

			instance_addr, global := get_variable_addr(c, e.left.text)
			if global {
				push_op_get_global_code(c, instance_addr)
			} else {
				push_op_get_code(c, instance_addr)
			}
			field_addr := i16(e.selector_id)
			push_op_get_field_code(c, field_addr)

		case .Instance_Call:
			call_expr := e.selector.(^Checked_Call_Expression)
			call_identifier := call_expr.func.(^Checked_Identifier_Expression)
			instance_addr, global := get_variable_addr(c, e.left.text)
			method_addr := i16(e.selector_id)

			c.scope_depth += 1
			defer c.scope_depth -= 1
			push_op_code(c, .Op_Begin)
			if global {
				push_op_get_global_code(c, instance_addr)
			} else {
				push_op_get_code(c, instance_addr)
			}

			is_void := call_expr.type_info.type_id == UNTYPED_ID
			if !is_void {
				push_op_code(c, .Op_Push) // 
			}
			for arg_expr in call_expr.args {
				compile_expr(c, arg_expr)
			}
			push_op_call_method_code(c, method_addr)

		case .Array_Len:
			array_addr, global := get_variable_addr(c, e.left.text)
			push_op_get_code(c, array_addr)
			push_op_code(c, .Op_Len_Array)

		case .Array_Append:
			append_call := e.selector.(^Checked_Call_Expression)
			compile_expr(c, append_call.args[0])
			array_addr, global := get_variable_addr(c, e.left.text)
			if global {
				push_op_get_global_code(c, array_addr)
			} else {
				push_op_get_code(c, array_addr)
			}
			push_op_code(c, .Op_Append_Array)
			push_op_code(c, .Op_Pop)
		}

	case ^Checked_Call_Expression:
		c.scope_depth += 1
		defer c.scope_depth -= 1
		push_op_code(c, .Op_Begin)
		push_op_code(c, .Op_Push)
		for arg_expr in e.args {
			compile_expr(c, arg_expr)
		}
		fn_identifier := e.func.(^Checked_Identifier_Expression)
		fn_addr := get_fn_addr(c, fn_identifier.name.text)
		push_op_call_code(c, fn_addr)
	}
}
