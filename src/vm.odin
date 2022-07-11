package lily

import "core:fmt"

Vm :: struct {
	ip:          int,
	modules:     []^Compiled_Module,
	current:     ^Compiled_Module,
	chunk:       ^Chunk,

	// Stack states
	call_stack:  [255]struct {
		chunk: ^Chunk,
		ip:    int,
	},
	call_count:  int,
	stack:       [255]Value,
	header_addr: int,
	stack_ptr:   int,
	stack_depth: int,
}

get_byte :: proc(vm: ^Vm) -> byte {
	vm.ip += 1
	return vm.chunk.bytecode[vm.ip - 1]
}

get_op_code :: proc(vm: ^Vm) -> Op_Code {
	return Op_Code(get_byte(vm))
}

get_i16 :: proc(vm: ^Vm) -> i16 {
	lower := get_byte(vm)
	upper := get_byte(vm)
	return i16(upper) << 8 | i16(lower)
}

push_call_frame :: proc(vm: ^Vm, next: ^Chunk) {
	vm.call_stack[vm.call_count] = {
		chunk = vm.chunk,
		ip    = vm.ip,
	}
	vm.call_count += 1
	vm.chunk = next
	vm.ip = 0
}

pop_call_frame :: proc(vm: ^Vm) {
	vm.call_count -= 1
	previous := vm.call_stack[vm.call_count]
	vm.ip = previous.ip
	vm.chunk = previous.chunk
}

push_stack_scope :: proc(vm: ^Vm) {
	vm.stack[vm.stack_ptr] = Value {
		data = f64(vm.header_addr),
	}
	vm.header_addr = vm.stack_ptr
	vm.stack_ptr += 1
	vm.stack_depth += 1
}

pop_stack_scope :: proc(vm: ^Vm) {
	vm.stack_ptr = vm.header_addr
	vm.header_addr = int(vm.stack[vm.header_addr].data.(f64))
	vm.stack_depth -= 1
}

push_stack_value :: proc(vm: ^Vm, val: Value) {
	vm.stack[vm.stack_ptr] = val
	vm.stack_ptr += 1
}

pop_stack_value :: proc(vm: ^Vm) -> (result: Value) {
	result = vm.stack[vm.stack_ptr - 1]
	vm.stack_ptr -= 1
	return
}

get_stack_value :: proc(vm: ^Vm, addr: int) -> (result: Value) {
	result = vm.stack[addr]
	return
}

set_stack_value :: proc(vm: ^Vm, addr: int, value: Value) {
	vm.stack[addr] = value
	// if vm.stack_ptr < addr + 1 {
	// 	vm.stack_ptr = addr + 1
	// }
}

stack_addr :: proc(vm: ^Vm) -> int {
	return vm.stack_ptr - 1 if vm.stack_ptr > 0 else 0
}

previous_scope_last_value :: proc(vm: ^Vm) -> Value {
	return vm.stack[vm.header_addr - 1]
}

// Return the first adressable value of the stack scope
get_scope_start_addr :: proc(vm: ^Vm) -> int {
	return vm.header_addr + 1
}

set_var_stack_addr :: proc(vm: ^Vm, var_addr: i16, addr: int) {
	vm.chunk.variables[var_addr].stack_addr = addr
}

get_var_stack_addr :: proc(vm: ^Vm, var_addr: i16) -> int {
	return vm.chunk.variables[var_addr].stack_addr
}

run_program :: proc(state: ^State, entry_point: int) {
	vm := Vm {
		modules = state.compiled_modules,
		current = state.compiled_modules[entry_point],
		chunk   = &state.compiled_modules[entry_point].main,
	}

	run: for {
		op := get_op_code(&vm)
		switch op {
		case .Op_None:
			assert(false, "Invalid Op Code")

		case .Op_Push:
			push_stack_value(&vm, {})

		case .Op_Pop:
			pop_stack_value(&vm)

		case .Op_Push_Back:
			moved := pop_stack_value(&vm)
			pop_stack_value(&vm)
			push_stack_value(&vm, moved)

		case .Op_Move:
			move_addr := int(get_i16(&vm)) + get_scope_start_addr(&vm)
			set_stack_value(&vm, move_addr, pop_stack_value(&vm))

		case .Op_Copy:
			src_addr := int(get_i16(&vm)) + get_scope_start_addr(&vm)
			push_stack_value(&vm, get_stack_value(&vm, src_addr))

		case .Op_Const:
			const_addr := get_i16(&vm)
			if int(const_addr) >= len(vm.chunk.constants) {
				fmt.println(op_code_str[Op_Code(vm.chunk.bytecode[0])])
			}
			push_stack_value(&vm, vm.chunk.constants[const_addr])

		case .Op_Module:
			module_addr := get_i16(&vm)
			vm.current = vm.modules[module_addr]

		case .Op_Prototype:
			class_addr := get_i16(&vm)
			prototype := Value {
				kind = .Object_Ref,
				data = cast(^Object)&vm.current.protypes[class_addr],
			}
			push_stack_value(&vm, prototype)

		case .Op_Inc:
			val := pop_stack_value(&vm)
			val.data = val.data.(f64) + 1
			push_stack_value(&vm, val)

		case .Op_Dec:
			val := pop_stack_value(&vm)
			val.data = val.data.(f64) - 1
			push_stack_value(&vm, val)

		case .Op_Neg:
			val := pop_stack_value(&vm)
			val.data = val.data.(f64) * -1
			push_stack_value(&vm, val)

		case .Op_Not:
			val := pop_stack_value(&vm)
			val.data = !val.data.(bool)
			push_stack_value(&vm, val)

		case .Op_Add:
			v1, v2 := pop_stack_value(&vm), pop_stack_value(&vm)
			push_stack_value(&vm, Value{kind = .Number, data = v1.data.(f64) + v2.data.(f64)})

		case .Op_Mul:
			v1, v2 := pop_stack_value(&vm), pop_stack_value(&vm)
			push_stack_value(&vm, Value{kind = .Number, data = v1.data.(f64) * v2.data.(f64)})

		case .Op_Div:
			v1, v2 := pop_stack_value(&vm), pop_stack_value(&vm)
			push_stack_value(&vm, Value{kind = .Number, data = v1.data.(f64) / v2.data.(f64)})

		case .Op_Rem:
			v1, v2 := pop_stack_value(&vm), pop_stack_value(&vm)
			result := int(v1.data.(f64)) % int(v2.data.(f64))
			push_stack_value(&vm, Value{kind = .Number, data = f64(result)})

		case .Op_And:
			v1, v2 := pop_stack_value(&vm), pop_stack_value(&vm)
			push_stack_value(&vm, Value{kind = .Boolean, data = v1.data.(bool) && v2.data.(bool)})

		case .Op_Or:
			v1, v2 := pop_stack_value(&vm), pop_stack_value(&vm)
			push_stack_value(&vm, Value{kind = .Boolean, data = v1.data.(bool) || v2.data.(bool)})

		case .Op_Eq:
			v1, v2 := pop_stack_value(&vm), pop_stack_value(&vm)
			#partial switch v1.kind {
			case .Number:
				push_stack_value(&vm, Value{kind = .Boolean, data = v1.data.(f64) == v2.data.(f64)})
			case .Boolean:
				push_stack_value(&vm, Value{kind = .Boolean, data = v1.data.(bool) == v2.data.(bool)})
			}

		case .Op_Greater:
			v1, v2 := pop_stack_value(&vm), pop_stack_value(&vm)
			push_stack_value(&vm, Value{kind = .Boolean, data = v1.data.(f64) > v2.data.(f64)})

		case .Op_Greater_Eq:
			v1, v2 := pop_stack_value(&vm), pop_stack_value(&vm)
			push_stack_value(&vm, Value{kind = .Boolean, data = v1.data.(f64) >= v2.data.(f64)})

		case .Op_Lesser:
			v1, v2 := pop_stack_value(&vm), pop_stack_value(&vm)
			push_stack_value(&vm, Value{kind = .Boolean, data = v1.data.(f64) > v2.data.(f64)})

		case .Op_Lesser_Eq:
			v1, v2 := pop_stack_value(&vm), pop_stack_value(&vm)
			push_stack_value(&vm, Value{kind = .Boolean, data = v1.data.(f64) >= v2.data.(f64)})

		case .Op_Begin:
			push_stack_scope(&vm)

		case .Op_End:
			pop_stack_scope(&vm)

		case .Op_Call:
			fn_addr := get_i16(&vm)
			push_call_frame(&vm, &vm.current.functions[fn_addr].chunk)

		case .Op_Call_Foreign:
			fn_addr := get_i16(&vm)
			fn_values := vm.stack[get_scope_start_addr(&vm):vm.stack_ptr]
			call_foreign_fn(state, vm.current.functions[fn_addr].foreign_fn, fn_values)

		case .Op_Call_Method:
			method_addr := get_i16(&vm)
			instance_val := previous_scope_last_value(&vm)
			set_stack_value(&vm, get_scope_start_addr(&vm), instance_val)
			instance := cast(^Class_Object)instance_val.data.(^Object)
			push_call_frame(&vm, &instance.vtable.methods[method_addr].chunk)

		case .Op_Call_Constr:
			method_addr := get_i16(&vm)
			proto_val := previous_scope_last_value(&vm)
			push_stack_value(&vm, proto_val)
			prototype := cast(^Class_Object)proto_val.data.(^Object)
			push_call_frame(&vm, &prototype.vtable.constructors[method_addr].chunk)

		case .Op_Return:
			result_addr := get_i16(&vm)
			result_val: Value
			if result_addr >= 0 {
				result_val = get_stack_value(&vm, get_var_stack_addr(&vm, result_addr))
			}
			pop_stack_scope(&vm)
			pop_call_frame(&vm)
			if result_addr >= 0 {
				push_stack_value(&vm, result_val)
			}

		case .Op_Jump:
			vm.ip = int(get_i16(&vm))

		case .Op_Jump_True:
			jmp_addr := int(get_i16(&vm))
			conditional := pop_stack_value(&vm)
			if conditional.data.(bool) {
				vm.ip = jmp_addr
			}

		case .Op_Jump_False:
			jmp_addr := int(get_i16(&vm))
			conditional := pop_stack_value(&vm)
			if !conditional.data.(bool) {
				vm.ip = jmp_addr
			}

		case .Op_Get:
			var_addr := get_i16(&vm)
			var_val := get_stack_value(&vm, get_var_stack_addr(&vm, var_addr))
			push_stack_value(&vm, var_val)

		case .Op_Get_Global:
			var_addr := get_i16(&vm)
			push_stack_value(&vm, vm.current.variables[var_addr])

		case .Op_Get_Elem:
			array := cast(^Array_Object)pop_stack_value(&vm).data.(^Object)
			index_val := pop_stack_value(&vm)
			push_stack_value(&vm, array.data[int(index_val.data.(f64))])

		case .Op_Get_Field:
			field_addr := get_i16(&vm)
			instance := cast(^Class_Object)pop_stack_value(&vm).data.(^Object)
			push_stack_value(&vm, instance.fields[field_addr])

		case .Op_Bind:
			var_addr := get_i16(&vm)
			addr := int(get_i16(&vm)) + get_scope_start_addr(&vm)
			set_var_stack_addr(&vm, var_addr, addr)

		case .Op_Set:
			var_addr := get_i16(&vm)
			addr := stack_addr(&vm)
			set_var_stack_addr(&vm, var_addr, addr)


		case .Op_Set_Global:
			var_addr := get_i16(&vm)
			vm.current.variables[var_addr] = pop_stack_value(&vm)

		case .Op_Set_Elem:
			array := cast(^Array_Object)pop_stack_value(&vm).data.(^Object)
			index_val := pop_stack_value(&vm)
			array.data[int(index_val.data.(f64))] = pop_stack_value(&vm)

		case .Op_Set_Field:
			field_addr := get_i16(&vm)
			instance := cast(^Class_Object)pop_stack_value(&vm).data.(^Object)
			instance.fields[field_addr] = pop_stack_value(&vm)

		case .Op_Make_Instance:
			prototype := cast(^Class_Object)pop_stack_value(&vm).data.(^Object)
			instance :=
				new_clone(
					Class_Object{
						base = Object{kind = .Class},
						fields = make([]Value, len(prototype.fields)),
						vtable = prototype.vtable,
					},
				)
			push_stack_value(&vm, Value{kind = .Object_Ref, data = cast(^Object)instance})

		case .Op_Make_Array:
			push_stack_value(&vm, new_array_object())

		case .Op_Append_Array:
			array_val := pop_stack_value(&vm)
			array := cast(^Array_Object)array_val.data.(^Object)
			append(&array.data, pop_stack_value(&vm))
			push_stack_value(&vm, array_val)

		case .Op_Length:
			array := cast(^Array_Object)pop_stack_value(&vm).data.(^Object)
			push_stack_value(&vm, Value{kind = .Number, data = f64(len(array.data))})
		}


		// print_stack(&vm, op)
		if vm.ip >= len(vm.chunk.bytecode) {
			break run
		}
	}
}
