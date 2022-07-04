package lily

// when LILY_DEBUG {
// 	import "core:fmt"
// }

// VM_STACK_SIZE :: 255
// VM_STACK_GROWTH :: 2
// // VM_DEBUG_VIEW :: true

// Vm :: struct {
// 	// Persistant states
// 	checker:     Checker,

// 	// Runtime states
// 	modules:     []^Compiled_Module,
// 	module:      ^Compiled_Module,
// 	chunk:       ^Chunk,
// 	ip:          int,
// 	stack:       []Value,
// 	header_ptr:  int,
// 	stack_ptr:   int,
// 	stack_depth: int,

// 	// A stack for all the function calls
// 	call_stack:  [VM_STACK_SIZE]Call_Frame,
// 	call_count:  int,
// }


// new_vm :: proc() -> ^Vm {
// 	vm := new(Vm)
// 	vm.stack = make([]Value, VM_STACK_SIZE)
// 	return vm
// }

// free_vm :: proc(vm: ^Vm) {
// 	delete(vm.stack)
// }

// // compile_module :: proc(vm: ^Vm, module_path: string) -> (err: Error) {


// // 	init_checker(&vm.checker)
// // 	checked_module := check_module(&vm.checker, parsed_module) or_return
// // 	// defer free_checker(checker)
// // 	// defer delete_checked_module(checked_module)

// // 	// TODO: Store the checked_module in the checker or somewhere else
// // 	// It's probably be better to store it outside, this way we could checked multiple at once 
// // 	// (probably not in the forceable future)

// // 	compiler := new_compiler()
// // 	compiled_module := compile_checked_module(compiler, checked_module)
// // 	return
// // }

// Call_Frame :: struct {
// 	module_id: int,
// 	chunk:     ^Chunk,
// 	ip:        int,
// }

// push_call :: proc(vm: ^Vm, module_id: int, chunk: ^Chunk) {
// 	if vm.call_count > 0 {
// 		vm.call_stack[vm.call_count - 1].ip = vm.ip
// 	}
// 	vm.call_stack[vm.call_count] = Call_Frame {
// 		module_id = module_id,
// 		chunk     = chunk,
// 		ip        = 0,
// 	}
// 	vm.ip = 0
// 	vm.module = vm.modules[module_id]
// 	vm.chunk = chunk
// 	vm.call_count += 1
// }

// pop_call :: proc(vm: ^Vm) {
// 	vm.call_count -= 1
// 	call_frame := &vm.call_stack[vm.call_count - 1]
// 	vm.ip = call_frame.ip
// 	vm.module = vm.modules[call_frame.module_id]
// 	vm.chunk = call_frame.chunk
// 	// FIXME: this seems wrong..
// 	// vm.chunk = call_frame.fn.chunk if call_frame.fn != nil else vm.module.main
// }

// push_module :: proc(vm: ^Vm, module_id: int) {
// 	vm.call_stack[vm.call_count] = vm.call_stack[vm.call_count - 1]
// 	vm.call_stack[vm.call_count].module_id = module_id
// 	vm.module = vm.modules[module_id]
// 	vm.call_count += 1
// }

// pop_module :: proc(vm: ^Vm) {
// 	vm.call_count -= 1
// 	call_frame := &vm.call_stack[vm.call_count - 1]
// 	vm.module = vm.modules[call_frame.module_id]
// }

// push_stack :: proc(vm: ^Vm) {
// 	vm.stack[vm.stack_ptr] = Value {
// 		data = f64(vm.header_ptr),
// 	}
// 	vm.header_ptr = vm.stack_ptr
// 	vm.stack_ptr += 1
// 	vm.stack_depth += 1
// }

// pop_stack :: proc(vm: ^Vm) {
// 	vm.stack_ptr = vm.header_ptr
// 	vm.header_ptr = int(vm.stack[vm.header_ptr].data.(f64))
// 	vm.stack_depth -= 1
// }

// push_stack_value :: proc(vm: ^Vm, val: Value) {
// 	vm.stack[vm.stack_ptr] = val
// 	vm.stack_ptr += 1
// }

// pop_stack_value :: proc(vm: ^Vm) -> (result: Value) {
// 	result = vm.stack[vm.stack_ptr - 1]
// 	vm.stack_ptr -= 1
// 	return
// }

// get_stack_value :: proc(vm: ^Vm, stack_id: int) -> (result: Value) {
// 	result = vm.stack[stack_id]
// 	return
// }

// set_stack_value :: proc(vm: ^Vm, stack_id: int, value: Value) {
// 	vm.stack[stack_id] = value
// 	if vm.stack_ptr < stack_id + 1 {
// 		vm.stack_ptr = stack_id + 1
// 	}
// }

// get_current_stack_id :: proc(vm: ^Vm) -> int {
// 	return vm.stack_ptr - 1 if vm.stack_ptr > 0 else 0
// }

// // Return the first adressable value of the stack scope
// get_scope_start_id :: proc(vm: ^Vm) -> int {
// 	return vm.header_ptr + 1
// }

// bind_variable_to_stack :: proc(vm: ^Vm, var_addr: i16) -> (stack_id: int) {
// 	stack_id = vm.stack_ptr
// 	vm.chunk.variables[var_addr].stack_id = stack_id
// 	push_stack_value(vm, {})
// 	return
// }

// get_variable_stack_id :: proc(vm: ^Vm, var_addr: i16) -> int {
// 	return vm.chunk.variables[var_addr].stack_id
// }

// jump_to_instruction :: proc(vm: ^Vm, ip: int) {
// 	vm.ip = ip
// }

// get_byte :: proc(vm: ^Vm) -> byte {
// 	vm.ip += 1
// 	return vm.chunk.bytecode[vm.ip - 1]
// }

// get_op_code :: proc(vm: ^Vm) -> Op_Code {
// 	return Op_Code(get_byte(vm))
// }

// get_i16 :: proc(vm: ^Vm) -> i16 {
// 	lower := get_byte(vm)
// 	upper := get_byte(vm)
// 	return i16(upper) << 8 | i16(lower)
// }

// run_module :: proc(vm: ^Vm, module_id: int) {
// 	vm.module = vm.modules[module_id]
// 	push_call(vm, module_id, &vm.module.main)
// 	vm.stack_ptr = 0

// 	run_bytecode(vm)
// }

// run_bytecode :: proc(vm: ^Vm) {
// 	for {
// 		op := get_op_code(vm)
// 		switch op {
// 		case .Op_Begin:
// 			push_stack(vm)

// 		case .Op_End:
// 			pop_stack(vm)

// 		case .Op_Const:
// 			const_addr := get_i16(vm)
// 			const_val := vm.chunk.constants[const_addr]
// 			push_stack_value(vm, const_val)

// 		case .Op_Set_Global:
// 			global_addr := get_i16(vm)
// 			value := pop_stack_value(vm)
// 			vm.module.module_variables[global_addr] = value

// 		case .Op_Get_Global:
// 			global_addr := get_i16(vm)
// 			push_stack_value(vm, vm.module.module_variables[global_addr])

// 		case .Op_Set:
// 			// We pop the new value off the stack
// 			// Then check if the variable has already been binded to the environment
// 			// Else
// 			should_pop := bool(get_byte(vm))
// 			var_addr := get_i16(vm)
// 			var := vm.chunk.variables[var_addr]
// 			var_stack_id: int
// 			value: Value
// 			switch should_pop {
// 			case true:
// 				value = pop_stack_value(vm)
// 			case false:
// 			}
// 			if var.stack_id == -1 {
// 				var_stack_id = bind_variable_to_stack(vm, var_addr)
// 			} else {
// 				var_stack_id = get_variable_stack_id(vm, var_addr)
// 			}

// 			set_stack_value(vm, var_stack_id, value)

// 		case .Op_Bind:
// 			var_addr := get_i16(vm)
// 			rel_stack_id := get_i16(vm)
// 			stack_id := get_scope_start_id(vm) + int(rel_stack_id)
// 			vm.chunk.variables[var_addr].stack_id = stack_id

// 		case .Op_Set_Scoped:
// 			rel_stack_id := get_i16(vm)
// 			stack_id := get_scope_start_id(vm) + int(rel_stack_id)
// 			value := pop_stack_value(vm)
// 			set_stack_value(vm, stack_id, value)

// 		case .Op_Get:
// 			var_addr := get_i16(vm)
// 			var_stack_id := get_variable_stack_id(vm, var_addr)
// 			push_stack_value(vm, get_stack_value(vm, var_stack_id))

// 		case .Op_Get_Scoped:
// 			rel_stack_id := get_i16(vm)
// 			stack_id := get_scope_start_id(vm) + int(rel_stack_id)
// 			push_stack_value(vm, get_stack_value(vm, stack_id))

// 		case .Op_Pop:
// 			pop_stack_value(vm)

// 		case .Op_Push:
// 			push_stack_value(vm, Value{})

// 		case .Op_Inc:
// 			operand := pop_stack_value(vm)
// 			result := (operand.data.(f64)) + 1
// 			push_stack_value(vm, Value{kind = .Number, data = result})

// 		case .Op_Dec:
// 			operand := pop_stack_value(vm)
// 			result := (operand.data.(f64)) - 1
// 			push_stack_value(vm, Value{kind = .Number, data = result})

// 		case .Op_Neg:
// 			operand := pop_stack_value(vm)
// 			result := -(operand.data.(f64))
// 			push_stack_value(vm, Value{kind = .Number, data = result})

// 		case .Op_Not:
// 			operand := pop_stack_value(vm)
// 			result := !(operand.data.(bool))
// 			push_stack_value(vm, Value{kind = .Boolean, data = result})

// 		case .Op_Add:
// 			right := pop_stack_value(vm)
// 			left := pop_stack_value(vm)
// 			result := left.data.(f64) + right.data.(f64)
// 			push_stack_value(vm, Value{kind = .Number, data = result})

// 		case .Op_Mul:
// 			right := pop_stack_value(vm)
// 			left := pop_stack_value(vm)
// 			result := left.data.(f64) * right.data.(f64)
// 			push_stack_value(vm, Value{kind = .Number, data = result})

// 		case .Op_Div:
// 			right := pop_stack_value(vm)
// 			left := pop_stack_value(vm)
// 			result := left.data.(f64) / right.data.(f64)
// 			push_stack_value(vm, Value{kind = .Number, data = result})

// 		case .Op_Rem:
// 			right := pop_stack_value(vm)
// 			left := pop_stack_value(vm)
// 			result := int(left.data.(f64)) % int(right.data.(f64))
// 			push_stack_value(vm, Value{kind = .Number, data = f64(result)})

// 		case .Op_And:
// 			right := pop_stack_value(vm)
// 			left := pop_stack_value(vm)
// 			result := left.data.(bool) && right.data.(bool)
// 			push_stack_value(vm, Value{kind = .Boolean, data = result})

// 		case .Op_Or:
// 			right := pop_stack_value(vm)
// 			left := pop_stack_value(vm)
// 			result := left.data.(bool) || right.data.(bool)
// 			push_stack_value(vm, Value{kind = .Boolean, data = result})

// 		case .Op_Eq:
// 			right := pop_stack_value(vm)
// 			left := pop_stack_value(vm)
// 			result := left.data.(f64) == right.data.(f64)
// 			push_stack_value(vm, Value{kind = .Boolean, data = result})

// 		case .Op_Greater:
// 			right := pop_stack_value(vm)
// 			left := pop_stack_value(vm)
// 			result := left.data.(f64) > right.data.(f64)
// 			push_stack_value(vm, Value{kind = .Boolean, data = result})

// 		case .Op_Greater_Eq:
// 			right := pop_stack_value(vm)
// 			left := pop_stack_value(vm)
// 			result := left.data.(f64) >= right.data.(f64)
// 			push_stack_value(vm, Value{kind = .Boolean, data = result})

// 		case .Op_Lesser:
// 			right := pop_stack_value(vm)
// 			left := pop_stack_value(vm)
// 			result := left.data.(f64) < right.data.(f64)
// 			push_stack_value(vm, Value{kind = .Boolean, data = result})

// 		case .Op_Lesser_Eq:
// 			right := pop_stack_value(vm)
// 			left := pop_stack_value(vm)
// 			result := left.data.(f64) <= right.data.(f64)
// 			push_stack_value(vm, Value{kind = .Boolean, data = result})

// 		case .Op_Jump:
// 			jump_ip := get_i16(vm)
// 			jump_to_instruction(vm, int(jump_ip))

// 		case .Op_Jump_False:
// 			// 1. pop value on stack
// 			// 2. eval the value
// 			// 3. branch
// 			conditional := pop_stack_value(vm)
// 			jump_ip := get_i16(vm)
// 			if !conditional.data.(bool) {
// 				jump_to_instruction(vm, int(jump_ip))
// 			}


// 		case .Op_Call:
// 			fn_addr := get_i16(vm)
// 			fn := &vm.module.functions[fn_addr]
// 			push_call(vm, vm.module.id, &fn.chunk)

// 		case .Op_Return_Val:
// 			result_addr := get_i16(vm)
// 			result_stack_id := get_variable_stack_id(vm, result_addr)
// 			result_value := get_stack_value(vm, result_stack_id)
// 			pop_call(vm)
// 			pop_stack(vm)
// 			push_stack_value(vm, result_value)

// 		case .Op_Return:
// 			pop_call(vm)
// 			pop_stack(vm)

// 		case .Op_Push_Module:
// 			module_addr := get_i16(vm)
// 			push_module(vm, int(module_addr))

// 		case .Op_Pop_Module:
// 			pop_module(vm)

// 		case .Op_Make_Array:
// 			array := make([dynamic]Value)
// 			obj := new_clone(Array_Object{base = Object{kind = .Array}, data = array})
// 			array_object := Value {
// 				kind = .Object_Ref,
// 				data = cast(^Object)obj,
// 			}
// 			push_stack_value(vm, array_object)

// 		case .Op_Assign_Array:
// 			obj := pop_stack_value(vm)
// 			index_value := pop_stack_value(vm)
// 			value := pop_stack_value(vm)

// 			array_object := cast(^Array_Object)obj.data.(^Object)
// 			array_object.data[int(index_value.data.(f64))] = value

// 		case .Op_Index_Array:
// 			obj := pop_stack_value(vm)
// 			index_value := pop_stack_value(vm)
// 			array_object := cast(^Array_Object)obj.data.(^Object)
// 			result := array_object.data[int(index_value.data.(f64))]
// 			push_stack_value(vm, result)

// 		case .Op_Append_Array:
// 			obj := pop_stack_value(vm)
// 			element := pop_stack_value(vm)
// 			array_object := cast(^Array_Object)obj.data.(^Object)
// 			append(&array_object.data, element)
// 			push_stack_value(vm, obj)

// 		case .Op_Len_Array:
// 			obj := pop_stack_value(vm)
// 			array_object := cast(^Array_Object)obj.data.(^Object)
// 			push_stack_value(vm, Value{kind = .Number, data = f64(len(array_object.data))})

// 		case .Op_Make_Instance:
// 			class_addr := get_i16(vm)
// 			new_instance := new_clone(vm.module.classe_prototypes[class_addr])
// 			class_object := Value {
// 				kind = .Object_Ref,
// 				data = cast(^Object)new_instance,
// 			}
// 			push_stack_value(vm, class_object)

// 		case .Op_Call_Constr:
// 			class_addr := get_i16(vm)
// 			constr_addr := get_i16(vm)
// 			constr := &vm.module.class_vtables[class_addr].constructors[constr_addr]
// 			push_call(vm, vm.module.id, &constr.chunk)

// 		case .Op_Call_Method:
// 			method_addr := get_i16(vm)
// 			instance_addr := get_scope_start_id(vm)
// 			obj := get_stack_value(vm, instance_addr)
// 			instance := cast(^Class_Object)obj.data.(^Object)
// 			method := &instance.vtable.methods[method_addr]
// 			push_call(vm, vm.module.id, &method.chunk)

// 		case .Op_Get_Field:
// 			field_addr := get_i16(vm)
// 			obj := pop_stack_value(vm)
// 			instance := cast(^Class_Object)obj.data.(^Object)
// 			push_stack_value(vm, instance.fields[field_addr].value)

// 		case .Op_Set_Field:
// 			field_addr := get_i16(vm)
// 			obj := pop_stack_value(vm)
// 			value := pop_stack_value(vm)
// 			instance := cast(^Class_Object)obj.data.(^Object)
// 			instance.fields[field_addr].value = value
// 		}
// 		when LILY_DEBUG {
// 			fmt.printf("== %v ==", op)
// 			print_stack(vm)
// 		}
// 		if vm.ip >= len(vm.chunk.bytecode) {
// 			break
// 		}
// 	}
// }
