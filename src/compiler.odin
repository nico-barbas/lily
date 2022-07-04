package lily

// import "core:mem"
// import "core:fmt"

// LILY_DEBUG :: true

// // FIXME: Remove all string comparisons from the compiler if possible
// // Most of them can be done during the semantic analysis.
// // All the functions, classes (methods and constr) lands at the same index from checker to compiler
// // Meaning we can just store it during semantic analysis.

// instruction_lengths := map[Op_Code]int {
// 	.Op_Begin        = 1,
// 	.Op_End          = 1,
// 	.Op_Push         = 1,
// 	.Op_Pop          = 1,
// 	.Op_Const        = 3,
// 	.Op_Set_Global   = 3,
// 	.Op_Get_Global   = 3,
// 	.Op_Set          = 4,
// 	.Op_Bind         = 5,
// 	.Op_Set_Scoped   = 3,
// 	.Op_Get          = 3,
// 	.Op_Get_Scoped   = 3,
// 	.Op_Inc          = 1,
// 	.Op_Dec          = 1,
// 	.Op_Neg          = 1,
// 	.Op_Not          = 1,
// 	.Op_Add          = 1,
// 	.Op_Mul          = 1,
// 	.Op_Div          = 1,
// 	.Op_Rem          = 1,
// 	.Op_And          = 1,
// 	.Op_Or           = 1,
// 	.Op_Eq           = 1,
// 	.Op_Greater      = 1,
// 	.Op_Greater_Eq   = 1,
// 	.Op_Lesser       = 1,
// 	.Op_Lesser_Eq    = 1,
// 	.Op_Jump         = 3,
// 	.Op_Jump_False   = 3,
// 	.Op_Call         = 3,
// 	.Op_Return_Val   = 3,
// 	.Op_Return       = 1,
// 	.Op_Push_Module  = 3,
// 	.Op_Pop_Module   = 1,
// 	.Op_Make_Array   = 1,
// 	.Op_Assign_Array = 1,
// 	.Op_Index_Array  = 1,
// 	.Op_Append_Array = 1,
// 	.Op_Len_Array    = 1,
// 	.Op_Prototype    = 3,
// 	.Op_Call_Constr  = 5,
// 	.Op_Call_Method  = 5,
// 	.Op_Get_Field    = 3,
// 	.Op_Set_Field    = 3,
// }

// RANGE_HIGH_SLOT :: 1

// Compiler :: struct {
// 	cursor:                  int,
// 	write_at_cursor:         bool,
// 	fn_names:                [dynamic]string,
// 	class_info:              [dynamic]^Checked_Class_Declaration,
// 	bytecode:                [dynamic]byte,
// 	constants:               [dynamic]Value,
// 	variables:               [dynamic]Variable,
// 	module_variables_lookup: map[string]i16,
// 	const_count:             i16,
// 	var_count:               i16,
// 	scope_depth:             int,
// }

// Compiled_Module :: struct {
// 	id:                int,
// 	class_names:       []string,
// 	classe_prototypes: []Class_Object,
// 	class_vtables:     []Class_Vtable,
// 	function_names:    []string,
// 	functions:         []Fn_Object,
// 	module_variables:  []Value,
// 	main:              Chunk,
// }

// Chunk :: struct {
// 	bytecode:  []byte,
// 	constants: []Value,
// 	variables: []Variable,
// }

// Variable :: struct {
// 	name:              string,
// 	// type_info:         Type_Info,
// 	scope_depth:       int,
// 	stack_id:          int,
// 	relative_stack_id: int,
// }

// add_constant :: proc(c: ^Compiler, constant: Value) -> (ptr: i16) {
// 	append(&c.constants, constant)
// 	c.const_count += 1
// 	return c.const_count - 1
// }

// add_variable :: proc(c: ^Compiler, name: string) -> (ptr: i16) {
// 	var := Variable {
// 		name        = name,
// 		// type_info   = type_info,
// 		scope_depth = c.scope_depth,
// 		stack_id    = -1,
// 	}
// 	switch {
// 	case c.scope_depth == 0:
// 		// append(&c.module_variables, var)
// 		// c.module_var_count += 1
// 		// return c.module_var_count
// 		return c.module_variables_lookup[name]
// 	case:
// 		append(&c.variables, var)
// 		c.var_count += 1
// 		return c.var_count - 1
// 	}
// }

// get_variable_addr :: proc(c: ^Compiler, name: string) -> (result: i16, global: bool) {
// 	if addr, exist := c.module_variables_lookup[name]; exist {
// 		result = addr
// 		global = true
// 		return
// 	}
// 	for var, i in c.variables {
// 		if var.name == name {
// 			result = i16(i)
// 			global = false
// 			return
// 		}
// 	}
// 	return -1, false
// }

// get_fn_addr :: proc(c: ^Compiler, name: string) -> i16 {
// 	for fn_name, i in c.fn_names {
// 		if fn_name == name {
// 			return i16(i)
// 		}
// 	}
// 	return -1
// }

// // get_class_addr :: proc(c: ^Compiler, name: string) -> i16 {
// // 	for class, i in c.class_info {
// // 		if class.identifier.text == name {
// // 			return i16(i)
// // 		}
// // 	}
// // 	return -1
// // }

// // get_constructor_addr :: proc(c: ^Compiler, class_addr: i16, name: string) -> i16 {
// // 	class := c.class_info[class_addr]
// // 	for constructor, i in class.constructors {
// // 		if constructor.identifier.text == name {
// // 			return i16(i)
// // 		}
// // 	}
// // 	return -1
// // }

// // get_field_addr :: proc(c: ^Compiler, instance_addr: i16, name: string) -> i16 {
// // 	instance := c.variables[instance_addr]
// // 	class_addr := get_class_addr(c, instance.type_info.name)
// // 	class := c.class_info[class_addr]
// // 	for field, i in class.field_names {
// // 		if field.text == name {
// // 			return i16(i)
// // 		}
// // 	}
// // 	return -1
// // }

// // get_method_addr :: proc(c: ^Compiler, instance_addr: i16, name: string) -> i16 {
// // 	instance := c.variables[instance_addr]
// // 	class_addr := get_class_addr(c, instance.type_info.name)
// // 	class := c.class_info[class_addr]
// // 	for method, i in class.methods {
// // 		if method.identifier.text == name {
// // 			return i16(i)
// // 		}
// // 	}
// // 	return -1
// // }

// set_cursor_at_and_write :: proc(c: ^Compiler, pos: int) {
// 	c.cursor = pos
// 	c.write_at_cursor = true
// }

// remove_cursor :: proc(c: ^Compiler) {
// 	c.write_at_cursor = false
// 	c.cursor = -1
// }

// current_byte_offset :: proc(c: ^Compiler) -> int {
// 	return len(c.bytecode)
// }

// reserve_bytes :: proc(c: ^Compiler, count: int) {
// 	for _ in 0 ..< count {
// 		push_byte(c, 0)
// 	}
// }

// push_byte :: proc(c: ^Compiler, b: byte) {
// 	if c.write_at_cursor {
// 		c.bytecode[c.cursor] = b
// 		c.cursor += 1
// 	} else {
// 		append(&c.bytecode, b)
// 	}
// }

// push_op_code :: #force_inline proc(c: ^Compiler, op: Op_Code) {
// 	push_byte(c, byte(op))
// }

// push_op_const_code :: proc(c: ^Compiler, addr: i16) {
// 	push_byte(c, byte(Op_Code.Op_Const))
// 	lower_addr := byte(addr)
// 	upper_addr := byte(addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)
// }

// push_op_set_global_code :: proc(c: ^Compiler, addr: i16) {
// 	push_byte(c, byte(Op_Code.Op_Set_Global))
// 	lower_addr := byte(addr)
// 	upper_addr := byte(addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)
// }

// push_op_get_global_code :: proc(c: ^Compiler, addr: i16) {
// 	push_byte(c, byte(Op_Code.Op_Get_Global))
// 	lower_addr := byte(addr)
// 	upper_addr := byte(addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)
// }

// push_op_set_code :: proc(c: ^Compiler, addr: i16, pop_last: bool) {
// 	push_byte(c, byte(Op_Code.Op_Set))
// 	push_byte(c, byte(pop_last))
// 	lower_addr := byte(addr)
// 	upper_addr := byte(addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)
// }

// push_op_bind_code :: proc(c: ^Compiler, var_addr: i16, rel_addr: i16) {
// 	push_byte(c, byte(Op_Code.Op_Bind))
// 	lower_addr := byte(var_addr)
// 	upper_addr := byte(var_addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)

// 	lower_addr = byte(rel_addr)
// 	upper_addr = byte(rel_addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)
// }

// push_op_set_scoped_code :: proc(c: ^Compiler, rel_addr: i16) {
// 	push_byte(c, byte(Op_Code.Op_Set_Scoped))
// 	lower_addr := byte(rel_addr)
// 	upper_addr := byte(rel_addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)
// }

// push_op_get_code :: proc(c: ^Compiler, addr: i16) {
// 	push_byte(c, byte(Op_Code.Op_Get))
// 	lower_addr := byte(addr)
// 	upper_addr := byte(addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)
// }

// push_op_get_scoped_code :: proc(c: ^Compiler, rel_addr: i16) {
// 	push_byte(c, byte(Op_Code.Op_Get_Scoped))
// 	lower_addr := byte(rel_addr)
// 	upper_addr := byte(rel_addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)
// }

// push_op_jump_code :: proc(c: ^Compiler, to: i16, on_condition := false) {
// 	op := Op_Code.Op_Jump if !on_condition else Op_Code.Op_Jump_False
// 	push_byte(c, byte(op))
// 	lower_to := byte(to)
// 	upper_to := byte(to >> 8)
// 	push_byte(c, lower_to)
// 	push_byte(c, upper_to)
// }

// push_op_call_code :: proc(c: ^Compiler, fn_addr: i16) {
// 	push_byte(c, byte(Op_Code.Op_Call))
// 	lower_addr := byte(fn_addr)
// 	upper_addr := byte(fn_addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)
// }

// push_op_return_code :: proc(c: ^Compiler, result_addr: i16) {
// 	push_byte(c, byte(Op_Code.Op_Return_Val))
// 	lower_addr := byte(result_addr)
// 	upper_addr := byte(result_addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)
// }

// push_op_prototype_code :: proc(c: ^Compiler, class_addr: i16) {
// 	push_byte(c, byte(Op_Code.Op_Prototype))
// 	lower_addr := byte(class_addr)
// 	upper_addr := byte(class_addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)
// }

// push_op_call_constr_code :: proc(c: ^Compiler, class_addr: i16, constr_addr: i16) {
// 	push_byte(c, byte(Op_Code.Op_Call_Constr))
// 	lower_addr := byte(class_addr)
// 	upper_addr := byte(class_addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)

// 	lower_addr = byte(constr_addr)
// 	upper_addr = byte(constr_addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)
// }

// push_op_call_method_code :: proc(c: ^Compiler, method_addr: i16) {
// 	push_byte(c, byte(Op_Code.Op_Call_Method))
// 	// lower_addr := byte(instance_addr)
// 	// upper_addr := byte(instance_addr >> 8)
// 	// push_byte(c, lower_addr)
// 	// push_byte(c, upper_addr)

// 	lower_addr := byte(method_addr)
// 	upper_addr := byte(method_addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)
// }

// push_op_get_field_code :: proc(c: ^Compiler, field_addr: i16) {
// 	push_byte(c, byte(Op_Code.Op_Get_Field))
// 	// lower_addr := byte(instance_addr)
// 	// upper_addr := byte(instance_addr >> 8)
// 	// push_byte(c, lower_addr)
// 	// push_byte(c, upper_addr)

// 	lower_addr := byte(field_addr)
// 	upper_addr := byte(field_addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)
// }

// push_op_set_field_code :: proc(c: ^Compiler, field_addr: i16) {
// 	push_byte(c, byte(Op_Code.Op_Set_Field))
// 	// lower_addr := byte(instance_addr)
// 	// upper_addr := byte(instance_addr >> 8)
// 	// push_byte(c, lower_addr)
// 	// push_byte(c, upper_addr)

// 	lower_addr := byte(field_addr)
// 	upper_addr := byte(field_addr >> 8)
// 	push_byte(c, lower_addr)
// 	push_byte(c, upper_addr)
// }

// push_op_and_instr :: proc(c: ^Compiler, op: Op_Code, instr: i16) {
// 	push_byte(c, byte(op))
// 	lower := byte(instr)
// 	upper := byte(instr >> 8)
// 	push_byte(c, lower)
// 	push_byte(c, upper)
// }

// make_chunk :: proc(c: ^Compiler) -> (result: Chunk) {
// 	result = Chunk {
// 		bytecode  = make([]byte, len(c.bytecode)),
// 		constants = make([]Value, len(c.constants)),
// 		variables = make([]Variable, len(c.variables)),
// 	}
// 	copy(result.bytecode, c.bytecode[:])
// 	copy(result.constants, c.constants[:])
// 	copy(result.variables, c.variables[:])
// 	reset_compiler(c)
// 	return
// }

// delete_chunk :: proc(c: ^Chunk) {
// 	delete(c.bytecode)
// 	delete(c.variables)
// 	delete(c.constants)
// }

// make_compiled_module :: proc(checked_module: ^Checked_Module) -> ^Compiled_Module {
// 	return new_clone(
// 		Compiled_Module{
// 			id = checked_module.id,
// 			classe_prototypes = make([]Class_Object, len(checked_module.classes)),
// 			class_vtables = make([]Class_Vtable, len(checked_module.classes)),
// 			functions = make([]Fn_Object, len(checked_module.functions)),
// 			module_variables = make([]Value, len(checked_module.variables)),
// 		},
// 	)
// }

// // delete_compiled_module :: proc(m: ^Compiled_Module) {
// // 	delete(m.class_names)
// // 	for prototype in m.classe_prototypes {
// // 		delete(prototype.fields)
// // 	}
// // 	delete(m.classe_prototypes)
// // 	for vtable in m.class_vtables {
// // 		for constructor in vtable.constructors {
// // 			constr_chunk := constructor.chunk
// // 			delete_chunk(&constr_chunk)
// // 		}
// // 		delete(vtable.constructors)
// // 		for method in vtable.methods {
// // 			method_chunk := method.chunk
// // 			delete_chunk(&method_chunk)
// // 		}
// // 		delete(vtable.methods)
// // 	}
// // 	delete(m.class_vtables)
// // 	for fn_object in m.functions {
// // 		fn_chunk := fn_object.chunk
// // 		delete_chunk(&fn_chunk)
// // 	}
// // 	delete(m.function_names)
// // 	delete(m.functions)
// // 	delete_chunk(&m.main)
// // 	free(m)
// // }

// new_compiler :: proc() -> ^Compiler {
// 	return new_clone(
// 		Compiler{cursor = -1, bytecode = make([dynamic]byte), constants = make([dynamic]Value)},
// 	)
// }

// free_compiler :: proc(c: ^Compiler) {
// 	delete(c.fn_names)
// 	delete(c.class_info)
// 	delete(c.bytecode)
// 	delete(c.constants)
// 	delete(c.variables)
// 	free(c)
// }

// reset_compiler :: proc(c: ^Compiler) {
// 	clear(&c.bytecode)
// 	clear(&c.constants)
// 	clear(&c.variables)
// 	c.const_count = 0
// 	c.var_count = 0
// 	c.cursor = -1
// 	c.write_at_cursor = false
// }

// compile_module :: proc(c: ^Compiler, modules: []^Checked_Module, module_id: int) -> ^Compiled_Module {
// 	module := modules[module_id]
// 	m := make_compiled_module(module)

// 	for v, i in module.variables {
// 		var_decl := v.(^Checked_Var_Declaration)
// 		c.module_variables_lookup[var_decl.identifier.name] = i16(i)
// 	}

// 	for class, i in module.classes {
// 		class_decl := class.(^Checked_Class_Declaration)
// 		append(&c.class_info, class_decl)
// 		prototype := Class_Object {
// 			base = Object{kind = .Class},
// 			fields = make([]Class_Field, len(class_decl.fields)),
// 		}
// 		for field, i in class_decl.fields {
// 			prototype.fields[i] = Class_Field {
// 				name = field.name,
// 				value = Value{},
// 			}
// 		}

// 		vtable := Class_Vtable {
// 			constructors = make([]Fn_Object, len(class_decl.constructors)),
// 			methods      = make([]Fn_Object, len(class_decl.methods)),
// 		}

// 		for constructor, i in class_decl.constructors {
// 			constructor_chunk := compile_class_constructor(c, constructor, i16(i))
// 			vtable.constructors[i] = Fn_Object {
// 				base = Object{kind = .Fn},
// 				chunk = constructor_chunk,
// 			}
// 		}

// 		for method, i in class_decl.methods {
// 			method_chunk := compile_class_method(c, method, i16(i))
// 			vtable.methods[i] = Fn_Object {
// 				base = Object{kind = .Fn},
// 				chunk = method_chunk,
// 			}
// 		}

// 		m.class_vtables[i] = vtable
// 		prototype.vtable = &m.class_vtables[i]
// 		m.classe_prototypes[i] = prototype
// 	}

// 	for fn_decl, i in module.functions {
// 		fn := fn_decl.(^Checked_Fn_Declaration)
// 		fn_chunk := compile_chunk_node(c, fn_decl)
// 		m.functions[i] = Fn_Object {
// 			base = Object{kind = .Fn},
// 			chunk = fn_chunk,
// 		}
// 		append(&c.fn_names, fn.identifier.name)
// 	}

// 	compile_chunk(c, module.variables[:], false)
// 	m.main = compile_chunk(c, module.nodes[:], true)
// 	when LILY_DEBUG {
// 		// m.class_names = make([]string, len(c.class_info))
// 		// m.function_names = make([]string, len(c.fn_names))
// 		// copy(m.function_names[:], c.fn_names[:])

// 		// for class, i in c.class_info {
// 		// 	m.class_names[i] = class.identifier.text
// 		// }
// 	}
// 	clear(&c.class_info)
// 	clear(&c.fn_names)
// 	clear(&c.module_variables_lookup)
// 	return m
// }

// compile_chunk :: proc(c: ^Compiler, nodes: []Checked_Node, to_chunk: bool) -> (result: Chunk) {
// 	for node in nodes {
// 		compile_node(c, node)
// 	}
// 	if to_chunk {
// 		result = make_chunk(c)
// 	}
// 	return
// }

// compile_chunk_node :: proc(c: ^Compiler, node: Checked_Node) -> (result: Chunk) {
// 	compile_node(c, node)
// 	result = make_chunk(c)
// 	return
// }

// compile_class_constructor :: proc(c: ^Compiler, constr: ^Checked_Fn_Declaration, class_addr: i16) -> (
// 	result: Chunk,
// ) {
// 	c.scope_depth = 2
// 	defer c.scope_depth = 0
// 	compile_constructor: {
// 		// 1. Allocate a new class instance
// 		// 2. bind "self" to the new class
// 		// class_info := c.class_info[class_addr].identifier
// 		// constr_signature := constr.type_info.type_id_data.(Fn_Signature_Info)


// 		for param_symbol, i in constr.params {
// 			param_addr := add_variable(c, param_symbol.name)
// 			push_op_bind_code(c, param_addr, i16(i))
// 		}
// 		// push_op_make_instance_code(c, class_addr)
// 		self_addr := add_variable(c, "self")
// 		push_op_set_code(c, self_addr, true)

// 		compile_node(c, constr.body)
// 		push_op_return_code(c, self_addr)
// 	}
// 	result = make_chunk(c)
// 	return
// }

// compile_class_method :: proc(c: ^Compiler, method: ^Checked_Fn_Declaration, class_addr: i16) -> (
// 	result: Chunk,
// ) {
// 	c.scope_depth = 2
// 	defer c.scope_depth = 0
// 	compile_method: {
// 		// 1. Allocate a new class instance
// 		// 2. bind "self" to the new class


// 		self_addr := add_variable(c, "self")
// 		push_op_bind_code(c, self_addr, 0)

// 		param_ptr: i16 = 0
// 		result_addr: i16
// 		symbol := method.identifier
// 		if symbol.fn_info.has_return {
// 			result_addr = add_variable(c, "result")
// 			push_op_bind_code(c, result_addr, param_ptr)
// 			param_ptr += 1
// 		}

// 		for param_symbol, i in method.params {
// 			param_addr := add_variable(c, param_symbol.name)
// 			push_op_bind_code(c, param_addr, i16(i + 1))
// 		}

// 		compile_node(c, method.body)
// 		if symbol.fn_info.has_return {
// 			push_op_return_code(c, result_addr)
// 		} else {
// 			push_op_code(c, .Op_Return)
// 		}
// 	}
// 	result = make_chunk(c)
// 	return
// }

// compile_node :: proc(c: ^Compiler, node: Checked_Node) {
// 	switch n in node {
// 	case ^Checked_Expression_Statement:
// 		compile_expr(c, n.expr)

// 	case ^Checked_Block_Statement:
// 		for inner in n.nodes {
// 			compile_node(c, inner)
// 		}

// 	case ^Checked_Assigment_Statement:
// 		compile_expr(c, n.right)
// 		#partial switch e in n.left {
// 		case ^Checked_Identifier_Expression:
// 			var_addr, global := get_variable_addr(c, e.symbol.name)
// 			if global {
// 				push_op_set_global_code(c, var_addr)
// 			} else {
// 				push_op_set_code(c, var_addr, true)
// 			}
// 		case ^Checked_Index_Expression:
// 			identifier := checked_expr_symbol(e.left)
// 			var_addr, global := get_variable_addr(c, identifier.name)
// 			compile_expr(c, e.index)
// 			if global {
// 				push_op_get_global_code(c, var_addr)
// 			} else {
// 				push_op_get_code(c, var_addr)
// 			}
// 			push_op_code(c, .Op_Assign_Array)
// 		case ^Checked_Dot_Expression:
// 		// // FIXME: Doesn't support multi modules
// 		// instance_addr, global := get_variable_addr(c, e.left.text)
// 		// if global {
// 		// 	push_op_get_global_code(c, instance_addr)
// 		// } else {
// 		// 	push_op_get_code(c, instance_addr)
// 		// }
// 		// // field_identifier := e.selector.(^Checked_Identifier_Expression)
// 		// // field_addr := get_field_addr(c, instance_addr, field_identifier.name.text)
// 		// field_addr := i16(e.selector_id)
// 		// push_op_set_field_code(c, field_addr)
// 		}

// 	case ^Checked_If_Statement:
// 		// TODO: Use the temp allocator
// 		// FIXME: Remove useless jump at the end of 1 branch ifs
// 		branch_cursor := 0
// 		cursors := make([dynamic]int)
// 		defer delete(cursors)

// 		current_branch := n
// 		branch_exist: bool

// 		if_loop: for {
// 			// Push a scope and evaluate the conditional expression
// 			c.scope_depth += 1
// 			defer c.scope_depth -= 1
// 			push_op_code(c, .Op_Begin)
// 			compile_expr(c, current_branch.condition)

// 			// We keep track of this instruction to specify the jump location after 
// 			// we discover the end of this branch's body
// 			branch_cursor = len(c.bytecode)
// 			reserve_bytes(c, instruction_lengths[.Op_Jump_False])

// 			// Compile the body and pop the scope
// 			compile_node(c, current_branch.body)
// 			push_op_code(c, .Op_End)

// 			// We keep a track of this instruction too 
// 			// This is the Op_Jump in case the branch evaluate to true,
// 			// We execute the body and need to get out of the if statement
// 			current_branch, branch_exist = current_branch.next_branch.(^Checked_If_Statement)


// 			set_cursor_at_and_write(c, branch_cursor)
// 			push_op_jump_code(c, i16(current_byte_offset(c)), true)
// 			remove_cursor(c)
// 			if branch_exist {
// 				append(&cursors, len(c.bytecode))
// 				reserve_bytes(c, instruction_lengths[.Op_Jump])
// 			} else {
// 				break if_loop
// 			}
// 		}

// 		for cursor in cursors {
// 			set_cursor_at_and_write(c, cursor)
// 			push_op_jump_code(c, i16(current_byte_offset(c)), false)
// 			remove_cursor(c)
// 		}


// 	case ^Checked_Range_Statement:
// 		c.scope_depth += 1
// 		defer c.scope_depth -= 1
// 		push_op_code(c, .Op_Begin)
// 		defer push_op_code(c, .Op_End)
// 		iterator_addr := add_variable(c, n.iterator.name)
// 		compile_expr(c, n.low)
// 		push_op_set_code(c, iterator_addr, true)
// 		compile_expr(c, n.high)
// 		push_op_set_scoped_code(c, RANGE_HIGH_SLOT)

// 		loop_start_cursor := current_byte_offset(c)
// 		push_op_get_code(c, iterator_addr)
// 		push_op_get_scoped_code(c, RANGE_HIGH_SLOT)
// 		// push_op_get_code(c, max_addr)
// 		switch n.op {
// 		case .Inclusive:
// 			push_op_code(c, .Op_Lesser_Eq)
// 		case .Exclusive:
// 			push_op_code(c, .Op_Lesser)
// 		}

// 		loop_break_cursor := current_byte_offset(c)
// 		reserve_bytes(c, instruction_lengths[.Op_Jump_False])

// 		compile_node(c, n.body)
// 		push_op_get_code(c, iterator_addr)
// 		push_op_code(c, .Op_Inc)
// 		push_op_set_code(c, iterator_addr, true)
// 		push_op_jump_code(c, i16(loop_start_cursor), false)

// 		set_cursor_at_and_write(c, loop_break_cursor)
// 		push_op_jump_code(c, i16(current_byte_offset(c)), true)
// 		remove_cursor(c)


// 	case ^Checked_Var_Declaration:
// 		// FIXME: Handle the case of uninitialized variables
// 		switch {
// 		case c.scope_depth == 0:
// 			var_addr, _ := get_variable_addr(c, n.identifier.name)
// 			compile_expr(c, n.expr)
// 			push_op_set_global_code(c, var_addr)
// 		case:
// 			var_addr := add_variable(c, n.identifier.name)
// 			compile_expr(c, n.expr)
// 			push_op_set_code(c, var_addr, true)
// 		}

// 	case ^Checked_Fn_Declaration:
// 		// Bind all the variable to stack slot
// 		c.scope_depth += 1
// 		defer c.scope_depth -= 1
// 		param_ptr: i16 = 0
// 		result_addr: i16
// 		symbol := n.identifier
// 		if symbol.fn_info.has_return {
// 			result_addr = add_variable(c, "result")
// 			push_op_bind_code(c, result_addr, param_ptr)
// 			param_ptr += 1
// 		}
// 		for param_symbol, i in n.params {
// 			param_addr := add_variable(c, param_symbol.name)
// 			push_op_bind_code(c, param_addr, param_ptr + i16(i))
// 		}


// 		compile_node(c, n.body)
// 		if symbol.fn_info.has_return {
// 			push_op_return_code(c, result_addr)
// 		} else {
// 			push_op_code(c, .Op_Return)
// 		}

// 	case ^Checked_Type_Declaration:
// 	case ^Checked_Class_Declaration:
// 	}
// }

// compile_expr :: proc(c: ^Compiler, expr: Checked_Expression) {
// 	switch e in expr {
// 	case ^Checked_Literal_Expression:
// 		const_addr := add_constant(c, e.value)
// 		push_op_const_code(c, const_addr)

// 	case ^Checked_String_Literal_Expression:
// 		// Allocate a new string object and shove the reference in the constant pool
// 		str := make([]rune, len(e.value))
// 		for r, i in e.value {
// 			str[i] = r
// 		}
// 		obj := new_clone(String_Object{base = Object{kind = .String}, data = str})
// 		str_object := Value {
// 			kind = .Object_Ref,
// 			data = cast(^Object)obj,
// 		}
// 		str_addr := add_constant(c, str_object)
// 		push_op_const_code(c, str_addr)

// 	case ^Checked_Array_Literal_Expression:
// 		array_addr: i16 = 0
// 		for i := len(e.values) - 1; i >= 0; i -= 1 {
// 			value_expr := e.values[i]
// 			compile_expr(c, value_expr)
// 		}
// 		push_op_code(c, .Op_Make_Array)

// 		for i in 0 ..< len(e.values) {
// 			push_op_code(c, .Op_Append_Array)
// 		}


// 	case ^Checked_Unary_Expression:
// 		compile_expr(c, e.expr)
// 		#partial switch e.op {
// 		case .Minus_Op:
// 			push_op_code(c, .Op_Neg)
// 		case .Not_Op:
// 			push_op_code(c, .Op_Not)
// 		}

// 	case ^Checked_Binary_Expression:
// 		compile_expr(c, e.left)
// 		compile_expr(c, e.right)
// 		#partial switch e.op {
// 		case .Plus_Op:
// 			push_op_code(c, .Op_Add)
// 		case .Minus_Op:
// 			push_op_code(c, .Op_Neg)
// 			push_op_code(c, .Op_Add)
// 		case .Mult_Op:
// 			push_op_code(c, .Op_Mul)
// 		case .Div_Op:
// 			push_op_code(c, .Op_Div)
// 		case .Rem_Op:
// 			push_op_code(c, .Op_Rem)
// 		case .Or_Op:
// 			push_op_code(c, .Op_Or)
// 		case .And_Op:
// 			push_op_code(c, .Op_And)
// 		case .Equal_Op:
// 			push_op_code(c, .Op_Eq)
// 		case .Greater_Op:
// 			push_op_code(c, .Op_Greater)
// 		case .Greater_Eq_Op:
// 			push_op_code(c, .Op_Greater_Eq)
// 		case .Lesser_Op:
// 			push_op_code(c, .Op_Lesser)
// 		case .Lesser_Eq_Op:
// 			push_op_code(c, .Op_Lesser_Eq)
// 		}

// 	case ^Checked_Identifier_Expression:
// 		#partial switch e.symbol.kind {
// 		case .Class_Symbol:
// 			for class, i in c.class_info {
// 				if e.symbol.name == class.identifier.name {
// 					push_op_prototype_code(c, i16(i))
// 				}
// 			}
// 		case .Var_Symbol:
// 			var_addr, global := get_variable_addr(c, e.symbol.name)
// 			if global {
// 				push_op_get_global_code(c, var_addr)
// 			} else {
// 				push_op_get_code(c, var_addr)
// 			}
// 		}

// 	case ^Checked_Index_Expression:
// 		// Compile the index expression and leave it on the stack
// 		// Put the array on top of the stack

// 		identifier := checked_expr_symbol(e.left)
// 		var_addr, global := get_variable_addr(c, identifier.name)
// 		compile_expr(c, e.index)
// 		if global {
// 			push_op_get_global_code(c, var_addr)
// 		} else {
// 			push_op_get_code(c, var_addr)
// 		}
// 		push_op_code(c, .Op_Index_Array)

// 	case ^Checked_Dot_Expression:
// 		compile_expr(c, e.left)
// 		compile_expr(c, e.selector)

// 	case ^Checked_Call_Expression:
// 		c.scope_depth += 1
// 		defer c.scope_depth -= 1
// 		push_op_code(c, .Op_Begin)
// 		push_op_code(c, .Op_Push)
// 		for arg_expr in e.args {
// 			compile_expr(c, arg_expr)
// 		}
// 		symbol := checked_expr_symbol(e.func)
// 		fn_addr := get_fn_addr(c, symbol.name)
// 		push_op_call_code(c, fn_addr)
// 	}
// }

Compiler :: struct {
	input:           Checked_Output,
	current:         ^Checked_Module,
	modules:         []^Compiled_Module,
	output:          ^Compiled_Module,

	// Data for the current chunk compiling
	chunk:           Chunk,
	chunk_variables: map[string]i16,
	var_count:       i16,
	constants:       ^Const_Pool,
}

Compiled_Module :: struct {
	class_addr:         map[string]i16,
	class_consts:       []Const_Pool,
	class_fields:       []map[string]i16,
	class_constructors: []map[string]i16,
	class_methods:      []map[string]i16,
	protypes:           []Class_Prototype,
	vtables:            []Class_Vtable,
	fn_addr:            map[string]i16,
	functions:          []Fn_Object,
	var_addr:           map[string]i16,
	variables:          []Value,
	main:               Chunk,
}

Class_Prototype :: struct {
	field_count: int,
}

// Allocate the right amount of compiled modules.
// This procedure does not compiled the input!
make_compiled_program :: proc(input: Checked_Output) -> []^Compiled_Module {
	output := make([]^Compiled_Module, len(input.modules))
	for module, i in input.modules {
		current := output[i]
		current =
			new_clone(
				Compiled_Module{
					class_addr = make(map[string]i16),
					class_consts = make([]Const_Pool, len(module.classes)),
					class_fields = make([]map[string]i16, len(module.classes)),
					protypes = make([]Class_Prototype, len(module.classes)),
					vtables = make([]Class_Vtable, len(module.classes)),
					fn_addr = make(map[string]i16),
					functions = make([]Fn_Object, len(module.functions)),
					variables = make([]Value, len(module.variables)),
				},
			)

		for node, j in module.classes {
			n := node.(^Checked_Class_Declaration)
			current.class_addr[n.identifier.name] = i16(j)
			current.vtables[j] = Class_Vtable {
				constructors = make([]Fn_Object, len(n.constructors)),
				methods      = make([]Fn_Object, len(n.methods)),
			}
			current.class_fields[j] = make(map[string]i16)
			for field, h in n.fields {
				current.class_fields[j][field.name] = i16(h)
			}

			current.class_constructors[j] = make(map[string]i16)
			for constructor, h in n.constructors {
				current.class_constructors[j][constructor.identifier.name] = i16(h)
			}

			current.class_methods[j] = make(map[string]i16)
			for method, h in n.methods {
				current.class_methods[j][method.identifier.name] = i16(h)
			}
		}
	}
	return output
}

add_variable :: proc(c: ^Compiler, name: string) -> (addr: i16) {
	addr = c.var_count
	c.chunk.variables[addr] = Variable {
		stack_id = -1,
	}
	c.chunk_variables[name] = addr
	c.var_count += 1
	return
}

get_class_addr :: proc(c: ^Compiled_Module, name: string) -> (addr: i16) {
	return c.class_addr[name]
}

get_field_addr :: proc(c: ^Compiled_Module, class, field: string) -> (addr: i16) {
	class_addr := c.class_addr[class]
	return c.class_fields[class_addr][field]
}

get_constructor_addr :: proc(c: ^Compiled_Module, class, name: string) -> (addr: i16) {
	class_addr := c.class_addr[class]
	return c.class_constructors[class_addr][name]
}

get_method_addr :: proc(c: ^Compiled_Module, class, name: string) -> (addr: i16) {
	class_addr := c.class_addr[class]
	return c.class_methods[class_addr][name]
}

get_fn_addr :: proc(c: ^Compiled_Module, name: string) -> (addr: i16) {
	return c.fn_addr[name]
}

// FIXME: Does not handle module level variables
get_var_addr :: proc(c: ^Compiler, name: string) -> (addr: i16) {
	return c.chunk_variables[name]
}


reset_compiler :: proc(c: ^Compiler) {
	c.var_count = 0
	clear(&c.chunk_variables)
	c.constants = nil
}

compile_module :: proc(input: Checked_Output, output: []^Compiled_Module, index: int) {
	c := Compiler {
		input           = input,
		current         = input.modules[index],
		output          = output[index],
		chunk_variables = make(map[string]i16),
	}

	for node, i in c.current.classes {
		n := node.(^Checked_Class_Declaration)
		enter_class_scope(c.current, Token{text = n.identifier.name})
		defer pop_scope(c.current)

		vtable := &c.output.vtables[i]
		c.constants = &c.output.class_consts[i]
		for constructor, j in n.constructors {
			symbol := constructor.identifier
			enter_child_scope_by_id(c.current, symbol.fn_info.scope_id)
			defer pop_scope(c.current)

			c.chunk = make_chunk(false, len(c.current.scope.var_lookup))
			class_addr := get_class_addr(c.output, n.identifier.name)

			push_simple_instruction(&c.chunk, .Op_Make_Instance, class_addr)
			self_var_addr := add_variable(&c, "self")
			push_simple_instruction(&c.chunk, .Op_Set, self_var_addr)

			compile_fn_parameters(&c, constructor.params, 1)
			compile_node(&c, constructor.body)
			push_simple_instruction(&c.chunk, .Op_Return, SELF_STACK_ADDR)

			vtable.constructors[j] = Fn_Object {
				base = Object{kind = .Fn},
				chunk = c.chunk,
			}
			reset_compiler(&c)
		}

		for method, j in n.methods {
			symbol := method.identifier
			enter_child_scope_by_id(c.current, symbol.fn_info.scope_id)
			defer pop_scope(c.current)

			c.chunk = make_chunk(false, len(c.current.scope.var_lookup))
			class_addr := get_class_addr(c.output, n.identifier.name)


			self_addr := add_variable(&c, "self")
			push_double_instruction(&c.chunk, .Op_Bind, self_addr, SELF_STACK_ADDR)
			if symbol.fn_info.has_return {
				result_addr := add_variable(&c, "result")
				push_double_instruction(&c.chunk, .Op_Bind, result_addr, METHOD_RESULT_STACK_ADDR)
			}

			compile_fn_parameters(&c, method.params, 2 if symbol.fn_info.has_return else 1)
			compile_node(&c, method.body)

			if symbol.fn_info.has_return {
				push_simple_instruction(&c.chunk, .Op_Return, METHOD_RESULT_STACK_ADDR)
			}

			vtable.methods[j] = Fn_Object {
				base = Object{kind = .Fn},
				chunk = c.chunk,
			}
			reset_compiler(&c)
		}

		c.output.protypes[i] = Class_Prototype {
			field_count = len(n.fields),
		}
	}
}

compile_fn_parameters :: proc(c: ^Compiler, params: []^Symbol, offset: i16) {
	for param, i in params {
		param_addr := add_variable(c, param.name)
		push_double_instruction(&c.chunk, .Op_Bind, param_addr, i16(i) + offset)
	}
}

compile_node :: proc(c: ^Compiler, node: Checked_Node) {
	switch n in node {
	case ^Checked_Expression_Statement:
		compile_expr(c, n.expr)

	case ^Checked_Block_Statement:
		for inner_node in n.nodes {
			compile_node(c, inner_node)
		}

	case ^Checked_Assigment_Statement:
		compile_expr(c, n.right)
		#partial switch left in n.left {
		case ^Checked_Identifier_Expression:
			var_addr := get_var_addr(c, left.symbol.name)
			push_simple_instruction(&c.chunk, .Op_Set, var_addr)
		case ^Checked_Index_Expression:
			compile_expr(c, left.index)
			compile_expr(c, left.left)
			push_op_code(&c.chunk, .Op_Set_Elem)
		case ^Checked_Dot_Expression:
		}

	case ^Checked_If_Statement:

	case ^Checked_Range_Statement:

	case ^Checked_Var_Declaration:
		var_addr := add_variable(c, n.identifier.name)
		compile_expr(c, n.expr)
		push_simple_instruction(&c.chunk, .Op_Set, var_addr)

	case ^Checked_Fn_Declaration:

	case ^Checked_Type_Declaration:

	case ^Checked_Class_Declaration:

	}
}

compile_expr :: proc(c: ^Compiler, expr: Checked_Expression) {
	switch e in expr {
	case ^Checked_Literal_Expression:
		const_addr := add_constant(c.constants, e.value)
		push_simple_instruction(&c.chunk, .Op_Const, const_addr)

	case ^Checked_String_Literal_Expression:
		const_addr := add_string_constant(c.constants, e.value)
		push_simple_instruction(&c.chunk, .Op_Const, const_addr)

	case ^Checked_Array_Literal_Expression:
		for i := len(e.values) - 1; i >= 0; i -= 1 {
			value_expr := e.values[i]
			compile_expr(c, value_expr)
		}
		push_op_code(&c.chunk, .Op_Make_Array)

		for i in 0 ..< len(e.values) {
			push_op_code(&c.chunk, .Op_Append_Array)
		}

	case ^Checked_Unary_Expression:
		compile_expr(c, e.expr)
		#partial switch e.op {
		case .Minus_Op:
			push_op_code(&c.chunk, .Op_Neg)
		case .Not_Op:
			push_op_code(&c.chunk, .Op_Not)
		}

	case ^Checked_Binary_Expression:
		compile_expr(c, e.left)
		compile_expr(c, e.right)
		#partial switch e.op {
		case .Plus_Op:
			push_op_code(&c.chunk, .Op_Add)
		case .Minus_Op:
			push_op_code(&c.chunk, .Op_Neg)
			push_op_code(&c.chunk, .Op_Add)
		case .Mult_Op:
			push_op_code(&c.chunk, .Op_Mul)
		case .Div_Op:
			push_op_code(&c.chunk, .Op_Div)
		case .Rem_Op:
			push_op_code(&c.chunk, .Op_Rem)
		case .Or_Op:
			push_op_code(&c.chunk, .Op_Or)
		case .And_Op:
			push_op_code(&c.chunk, .Op_And)
		case .Equal_Op:
			push_op_code(&c.chunk, .Op_Eq)
		case .Greater_Op:
			push_op_code(&c.chunk, .Op_Greater)
		case .Greater_Eq_Op:
			push_op_code(&c.chunk, .Op_Greater_Eq)
		case .Lesser_Op:
			push_op_code(&c.chunk, .Op_Lesser)
		case .Lesser_Eq_Op:
			push_op_code(&c.chunk, .Op_Lesser_Eq)
		}

	case ^Checked_Identifier_Expression:
		#partial switch e.symbol.kind {
		case .Var_Symbol:
			var_addr := get_var_addr(c, e.symbol.name)
			push_simple_instruction(&c.chunk, .Op_Get, var_addr)

		case:
			assert(false)
		}

	case ^Checked_Index_Expression:
		#partial switch left in e.left {
		case ^Checked_Identifier_Expression:
			identifier := checked_expr_symbol(e.left)
			var_addr := get_var_addr(c, identifier.name)
			compile_expr(c, e.index)
			push_simple_instruction(&c.chunk, .Op_Get_Elem, var_addr)
		case:
			assert(false)
		}

	case ^Checked_Dot_Expression:
		current_module := c.current.id
		left_symbol, kind := compile_dot_left_operand(c, e.left)
		compile_dot_selector_operand(c, e.selector, left_symbol, kind)
		c.output = c.modules[current_module]

	case ^Checked_Call_Expression:
		symbol := checked_expr_symbol(e.func)
		push_op_code(&c.chunk, .Op_Begin)
		if symbol.fn_info.has_return {
			push_op_code(&c.chunk, .Op_Push)
		}
		for arg_expr in e.args {
			compile_expr(c, arg_expr)
		}
		fn_addr := get_fn_addr(c.output, symbol.name)
		push_simple_instruction(&c.chunk, .Op_Call, fn_addr)
	}
}

compile_dot_left_operand :: proc(c: ^Compiler, left: Checked_Expression) -> (
	symbol: ^Symbol,
	kind: Accessor_Kind,
) {
	#partial switch l in left {
	case ^Checked_Identifier_Expression:
		symbol = l.symbol
		#partial switch l.symbol.kind {
		case .Class_Symbol:
			class_addr := get_class_addr(c.output, l.symbol.name)
			push_simple_instruction(&c.chunk, .Op_Prototype, class_addr)
			kind = .Class_Access

		case .Var_Symbol:
			var_addr := get_var_addr(c, l.symbol.name)
			push_simple_instruction(&c.chunk, .Op_Get, var_addr)
			kind = .Instance_Access

		case .Module_Symbol:
			module_addr := l.symbol.module_info.ref_module_id
			push_simple_instruction(&c.chunk, .Op_Module, i16(module_addr))
			c.output = c.modules[module_addr]
			kind = .Module_Access

		case:
			assert(false)
		}

	case ^Checked_Index_Expression:
		assert(false)
	case ^Checked_Call_Expression:
		symbol = checked_expr_symbol(l.func)
		kind = .Instance_Access

		fn_addr := get_fn_addr(c.output, symbol.name)
		push_simple_instruction(&c.chunk, .Op_Call, fn_addr)

	case:
		assert(false)
	}
	return
}

compile_dot_selector_operand :: proc(
	c: ^Compiler,
	selector: Checked_Expression,
	left: ^Symbol,
	l_kind: Accessor_Kind,
) -> (
	symbol: ^Symbol,
	kind: Accessor_Kind,
) {
	#partial switch s in selector {
	case ^Checked_Identifier_Expression:
		switch l_kind {
		case .Invalid, .Class_Access:
			assert(false)
		case .Module_Access:
			var_addr := get_var_addr(c, s.symbol.name)
			push_simple_instruction(&c.chunk, .Op_Get, var_addr)

		case .Instance_Access:
			field_addr := get_field_addr(c.output, left.var_info.symbol.name, s.symbol.name)
			push_simple_instruction(&c.chunk, .Op_Get_Field, field_addr)
		}
		symbol = s.symbol
		kind = .Instance_Access

	case ^Checked_Index_Expression:
		assert(false)

	case ^Checked_Call_Expression:
		symbol = checked_expr_symbol(s)
		kind = .Instance_Access
		switch l_kind {
		case .Invalid:
			assert(false)
		case .Module_Access:
			fn_addr := get_fn_addr(c.output, symbol.name)
			push_simple_instruction(&c.chunk, .Op_Call, fn_addr)

		case .Class_Access:
			constructor_addr := get_constructor_addr(c.output, left.name, symbol.name)
			push_simple_instruction(&c.chunk, .Op_Call_Constr, constructor_addr)

		case .Instance_Access:
			method_addr := get_method_addr(c.output, left.name, symbol.name)
			push_simple_instruction(&c.chunk, .Op_Call_Method, method_addr)
		}

	case ^Checked_Dot_Expression:
		symbol, kind = compile_dot_selector_operand(c, s.left, left, l_kind)
		compile_dot_selector_operand(c, s.selector, symbol, kind)
	case:
		assert(false)
	}
	return
}

compile_lhs_dot_expr :: proc(c: ^Compiler, dot_expr: ^Checked_Dot_Expression) {
	current_module := c.current.id
	kind: Accessor_Kind
	symbol: ^Symbol
	#partial switch left in dot_expr.left {
	case ^Checked_Identifier_Expression:
		symbol = left.symbol
		#partial switch left.symbol.kind {
		case .Var_Symbol:
			var_addr := get_var_addr(c, symbol.name)
			push_simple_instruction(&c.chunk, .Op_Get, var_addr)
			symbol = symbol.var_info.symbol
			kind = .Instance_Access

		case .Module_Symbol:
			module_addr := symbol.module_info.ref_module_id
			push_simple_instruction(&c.chunk, .Op_Module, i16(module_addr))
			c.output = c.modules[module_addr]
			kind = .Module_Access
		}

	case ^Checked_Index_Expression:
		symbol = checked_expr_symbol(left.left)
		var_addr := get_var_addr(c, symbol.name)
		compile_expr(c, left.index)
		push_simple_instruction(&c.chunk, .Op_Get_Elem, var_addr)
		symbol = symbol.generic_info.symbol
		kind = .Instance_Access

	case ^Checked_Call_Expression:
		compile_expr(c, left)
		symbol = checked_expr_symbol(left.func).fn_info.return_symbol
		kind = .Instance_Access
	}

	inner_symbol := checked_expr_symbol(dot_expr.selector)
	#partial switch selector in dot_expr.selector {
	case ^Checked_Identifier_Expression:
		#partial switch kind {
		case .Instance_Access:
			field_addr := get_field_addr(c.output, symbol.name, selector.symbol.name)
			push_simple_instruction(&c.chunk, .Op_Set_Field, field_addr)

		case .Module_Access:
			var_addr := get_var_addr(c, selector.symbol.name)
			push_simple_instruction(&c.chunk, .Op_Set, var_addr)
		}
	case ^Checked_Index_Expression:
		#partial switch kind {
		case .Instance_Access:
			field_addr := get_field_addr(c.output, symbol.name, inner_symbol.name)
			push_simple_instruction(&c.chunk, .Op_Get_Field, field_addr)
			compile_expr(c, selector.index)
			push_op_code(&c.chunk, .Op_Set_Elem)

		case .Module_Access:
			var_addr := get_var_addr(c, inner_symbol.name)
			push_simple_instruction(&c.chunk, .Op_Get, var_addr)
			compile_expr(c, selector.index)
			push_op_code(&c.chunk, .Op_Set_Elem)
		}
	case ^Checked_Call_Expression:
		#partial switch kind {
		case .Instance_Access:
			push_op_code(&c.chunk, .Op_Begin)
			if symbol.fn_info.has_return {
				push_op_code(&c.chunk, .Op_Push)
			}
			for arg_expr in selector.args {
				compile_expr(c, arg_expr)
			}
			method_addr := get_method_addr(c.output, symbol.name, inner_symbol.name)
			push_simple_instruction(&c.chunk, .Op_Call_Method, method_addr)

		case .Module_Access:
			compile_expr(c, selector)
		}
	case ^Checked_Dot_Expression:
		compile_lhs_dot_expr(c, selector)
	}
	if c.output != c.modules[current_module] {
		c.output = c.modules[current_module]
		push_simple_instruction(&c.chunk, .Op_Module, i16(current_module))
	}
}
