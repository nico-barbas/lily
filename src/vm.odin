package lily

VM_STACK_SIZE :: 255
VM_STACK_GROWTH :: 2
VM_DEBUG_VIEW :: true

Vm :: struct {
	module:      ^Compiled_Module,
	chunk:       Chunk,
	ip:          int,
	stack:       []Value,
	header_ptr:  int,
	stack_ptr:   int,
	stack_depth: int,

	// A stack for all the function calls
	call_stack:  [VM_STACK_SIZE]Call_Frame,
	call_count:  int,
}

Call_Frame :: struct {
	fn: ^Fn_Object,
	ip: int,
}

push_call :: proc(vm: ^Vm, fn: ^Fn_Object) {
	vm.call_stack[vm.call_count - 1].ip = vm.ip
	vm.call_stack[vm.call_count] = Call_Frame {
		fn = fn,
		ip = 0,
	}
	vm.ip = 0
	vm.chunk = fn.chunk
	vm.call_count += 1
}

pop_call :: proc(vm: ^Vm) {
	vm.call_count -= 1
	call_frame := &vm.call_stack[vm.call_count - 1]
	vm.ip = call_frame.ip
	vm.chunk = call_frame.fn.chunk if call_frame.fn != nil else vm.module.main
}

push_stack :: proc(vm: ^Vm) {
	vm.stack[vm.stack_ptr] = Value {
		data = f64(vm.header_ptr),
	}
	vm.header_ptr = vm.stack_ptr
	vm.stack_ptr += 1
	vm.stack_depth += 1
}

pop_stack :: proc(vm: ^Vm) {
	vm.stack_ptr = vm.header_ptr
	vm.header_ptr = int(vm.stack[vm.header_ptr].data.(f64))
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

get_stack_value :: proc(vm: ^Vm, stack_id: int) -> (result: Value) {
	result = vm.stack[stack_id]
	return
}

set_stack_value :: proc(vm: ^Vm, stack_id: int, value: Value) {
	vm.stack[stack_id] = value
	if vm.stack_ptr < stack_id + 1 {
		vm.stack_ptr = stack_id + 1
	}
}

get_current_stack_id :: proc(vm: ^Vm) -> int {
	return vm.stack_ptr - 1 if vm.stack_ptr > 0 else 0
}

// Return the first adressable value of the stack scope
get_scope_start_id :: proc(vm: ^Vm) -> int {
	return vm.header_ptr + 1
}

bind_variable_to_stack :: proc(vm: ^Vm, var_addr: i16) -> (stack_id: int) {
	stack_id = vm.stack_ptr
	vm.chunk.variables[var_addr].stack_id = stack_id
	push_stack_value(vm, {})
	return
}

get_variable_stack_id :: proc(vm: ^Vm, var_addr: i16) -> int {
	return vm.chunk.variables[var_addr].stack_id
}

jump_to_instruction :: proc(vm: ^Vm, ip: int) {
	vm.ip = ip
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

run_module :: proc(vm: ^Vm, c: ^Compiled_Module) {
	vm.module = c
	vm.chunk = c.main
	vm.stack = make([]Value, VM_STACK_SIZE)
	vm.stack_ptr = 0
	vm.ip = 0
	vm.call_count = 1

	run_bytecode(vm)
}

run_bytecode :: proc(vm: ^Vm) {
	for {
		op := get_op_code(vm)
		switch op {
		case .Op_Begin:
			push_stack(vm)

		case .Op_End:
			pop_stack(vm)

		case .Op_Const:
			const_addr := get_i16(vm)
			const_val := vm.chunk.constants[const_addr]
			push_stack_value(vm, const_val)

		case .Op_Set:
			// We pop the new value off the stack
			// Then check if the variable has already been binded to the environment
			// Else
			should_pop := bool(get_byte(vm))
			var_addr := get_i16(vm)
			var := vm.chunk.variables[var_addr]
			var_stack_id: int
			value: Value
			switch should_pop {
			case true:
				value = pop_stack_value(vm)
			case false:
			}
			if var.stack_id == -1 {
				var_stack_id = bind_variable_to_stack(vm, var_addr)
			} else {
				var_stack_id = get_variable_stack_id(vm, var_addr)
			}

			set_stack_value(vm, var_stack_id, value)

		case .Op_Bind:
			var_addr := get_i16(vm)
			rel_stack_id := get_i16(vm)
			stack_id := get_scope_start_id(vm) + int(rel_stack_id)
			vm.chunk.variables[var_addr].stack_id = stack_id

		case .Op_Set_Scoped:
			rel_stack_id := get_i16(vm)
			stack_id := get_scope_start_id(vm) + int(rel_stack_id)
			value := pop_stack_value(vm)
			set_stack_value(vm, stack_id, value)

		case .Op_Get:
			var_addr := get_i16(vm)
			var_stack_id := get_variable_stack_id(vm, var_addr)
			push_stack_value(vm, get_stack_value(vm, var_stack_id))

		case .Op_Get_Scoped:
			rel_stack_id := get_i16(vm)
			stack_id := get_scope_start_id(vm) + int(rel_stack_id)
			push_stack_value(vm, get_stack_value(vm, stack_id))

		case .Op_Pop:
			pop_stack_value(vm)

		case .Op_Inc:
			operand := pop_stack_value(vm)
			result := (operand.data.(f64)) + 1
			push_stack_value(vm, Value{kind = .Number, data = result})

		case .Op_Dec:
			operand := pop_stack_value(vm)
			result := (operand.data.(f64)) - 1
			push_stack_value(vm, Value{kind = .Number, data = result})

		case .Op_Neg:
			operand := pop_stack_value(vm)
			result := -(operand.data.(f64))
			push_stack_value(vm, Value{kind = .Number, data = result})

		case .Op_Not:
			operand := pop_stack_value(vm)
			result := !(operand.data.(bool))
			push_stack_value(vm, Value{kind = .Boolean, data = result})

		case .Op_Add:
			right := pop_stack_value(vm)
			left := pop_stack_value(vm)
			result := left.data.(f64) + right.data.(f64)
			push_stack_value(vm, Value{kind = .Number, data = result})

		case .Op_Mul:
			right := pop_stack_value(vm)
			left := pop_stack_value(vm)
			result := left.data.(f64) * right.data.(f64)
			push_stack_value(vm, Value{kind = .Number, data = result})

		case .Op_Div:
			right := pop_stack_value(vm)
			left := pop_stack_value(vm)
			result := left.data.(f64) / right.data.(f64)
			push_stack_value(vm, Value{kind = .Number, data = result})

		case .Op_Rem:
			right := pop_stack_value(vm)
			left := pop_stack_value(vm)
			result := int(left.data.(f64)) % int(right.data.(f64))
			push_stack_value(vm, Value{kind = .Number, data = f64(result)})

		case .Op_And:
			right := pop_stack_value(vm)
			left := pop_stack_value(vm)
			result := left.data.(bool) && right.data.(bool)
			push_stack_value(vm, Value{kind = .Boolean, data = result})

		case .Op_Or:
			right := pop_stack_value(vm)
			left := pop_stack_value(vm)
			result := left.data.(bool) || right.data.(bool)
			push_stack_value(vm, Value{kind = .Boolean, data = result})

		case .Op_Eq:
			right := pop_stack_value(vm)
			left := pop_stack_value(vm)
			result := left.data.(f64) == right.data.(f64)
			push_stack_value(vm, Value{kind = .Boolean, data = result})

		case .Op_Greater:
			right := pop_stack_value(vm)
			left := pop_stack_value(vm)
			result := left.data.(f64) > right.data.(f64)
			push_stack_value(vm, Value{kind = .Boolean, data = result})

		case .Op_Greater_Eq:
			right := pop_stack_value(vm)
			left := pop_stack_value(vm)
			result := left.data.(f64) >= right.data.(f64)
			push_stack_value(vm, Value{kind = .Boolean, data = result})

		case .Op_Lesser:
			right := pop_stack_value(vm)
			left := pop_stack_value(vm)
			result := left.data.(f64) < right.data.(f64)
			push_stack_value(vm, Value{kind = .Boolean, data = result})

		case .Op_Lesser_Eq:
			right := pop_stack_value(vm)
			left := pop_stack_value(vm)
			result := left.data.(f64) <= right.data.(f64)
			push_stack_value(vm, Value{kind = .Boolean, data = result})

		case .Op_Jump:
			jump_ip := get_i16(vm)
			jump_to_instruction(vm, int(jump_ip))

		case .Op_Jump_False:
			// 1. pop value on stack
			// 2. eval the value
			// 3. branch
			conditional := pop_stack_value(vm)
			jump_ip := get_i16(vm)
			if !conditional.data.(bool) {
				jump_to_instruction(vm, int(jump_ip))
			}


		case .Op_Call:
			fn_addr := get_i16(vm)
			fn := &vm.module.functions[fn_addr]
			// fn.chunk.variables
			push_call(vm, fn)

		case .Op_Return:
			result_addr := get_i16(vm)
			result_stack_id := get_variable_stack_id(vm, result_addr)
			result_value := get_stack_value(vm, result_stack_id)
			pop_call(vm)
			pop_stack(vm)
			push_stack_value(vm, result_value)

		case .Op_Make_Array:
			array := make([dynamic]Value)
			obj := new_clone(Array_Object{base = Object{kind = .Array}, data = array})
			array_object := Value {
				kind = .Object_Ref,
				data = cast(^Object)obj,
			}
			push_stack_value(vm, array_object)

		case .Op_Assign_Array:
			obj := pop_stack_value(vm)
			index_value := pop_stack_value(vm)
			value := pop_stack_value(vm)

			array_object := cast(^Array_Object)obj.data.(^Object)
			array_object.data[int(index_value.data.(f64))] = value

		case .Op_Index_Array:
			obj := pop_stack_value(vm)
			index_value := pop_stack_value(vm)
			array_object := cast(^Array_Object)obj.data.(^Object)
			result := array_object.data[int(index_value.data.(f64))]
			push_stack_value(vm, result)

		case .Op_Append_Array:
			obj := pop_stack_value(vm)
			element := pop_stack_value(vm)
			array_object := cast(^Array_Object)obj.data.(^Object)
			append(&array_object.data, element)
			push_stack_value(vm, obj)
		}
		when VM_DEBUG_VIEW {
			print_stack(vm)
		}
		if vm.ip >= len(vm.chunk.bytecode) {
			break
		}
	}
}


// import "core:strings"

// VM_STACK_SIZE :: 255

// Vm :: struct {
// 	names:       map[string]Stack_ID,
// 	stack:       [VM_STACK_SIZE]Value,
// 	header_ptr:  int,
// 	stack_ptr:   int,
// 	stack_depth: int,
// }

// Stack_ID :: distinct u8

// new_vm :: proc() -> (vm: ^Vm) {
// 	vm = new(Vm)
// 	return
// }

// delete_vm :: proc(vm: ^Vm) {
// 	free(vm)
// }

// run_program :: proc(vm: ^Vm, program: []Parsed_Node) {
// 	// Gather all the declarations
// 	for node in program {
// 		#partial switch n in node {
// 		case ^Parsed_Var_Declaration:
// 			value: Value
// 			#partial switch t in n.type_expr {
// 			case ^Identifier_Expression:
// 				switch t.name {
// 				case "number":
// 					value = Value {
// 						kind = .Number,
// 						data = 0,
// 					}
// 				case "boolean":
// 					value = Value {
// 						kind = .Boolean,
// 						data = false,
// 					}
// 				case:
// 					value = Value {
// 						kind = .Nil,
// 						data = nil,
// 					}
// 				}

// 			case ^Array_Type_Expression:
// 				assert(false, "Array not implemented yet")
// 			}
// 			push_stack_value(vm, n.identifier)

// 		case ^Parsed_Fn_Declaration:
// 			fn := new(Fn_Object)
// 			fn.base = Object {
// 				kind = .Fn,
// 			}
// 			for i in 0 ..< n.param_count {
// 				fn.parameters[i] = strings.clone(n.parameters[i].name)
// 			}
// 			fn.param_count = n.param_count
// 			fn.body = n.body
// 			push_stack_value(vm, n.identifier, Value{kind = .Object_Ref, data = cast(^Object)fn})
// 		}
// 	}

// 	// Run the program
// 	for node in program {
// 		eval_node(vm, node)
// 	}
// }

// push_stack_value :: proc(vm: ^Vm, name: string, value := Value{kind = .Nil}) {
// 	vm.names[name] = Stack_ID(vm.stack_ptr)
// 	vm.stack[vm.stack_ptr] = value
// 	vm.stack_ptr += 1
// }

// set_stack_value :: proc(vm: ^Vm, name: string, value: Value) {
// 	vm.stack[vm.names[name]] = value
// }

// get_stack_value :: proc(vm: ^Vm, name: string) -> Value {
// 	return vm.stack[vm.names[name]]
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

// eval_expr :: proc(vm: ^Vm, expr: Expression) -> (result: Value, err: Error) {
// 	switch e in expr {
// 	case ^Literal_Expression:
// 		result = e.value

// 	case ^String_Literal_Expression:
// 		// FIXME: Very naive approach. No reuse of constant strings or stack allocation
// 		str := make([]rune, len(e.value))
// 		for r, i in e.value {
// 			str[i] = r
// 		}
// 		obj := new_clone(String_Object{base = Object{kind = .String}, data = str})
// 		result = Value {
// 			kind = .Object_Ref,
// 			data = cast(^Object)obj,
// 		}

// 	case ^Array_Literal_Expression:
// 		array := make([dynamic]Value)
// 		for element_expr, i in e.values {
// 			value := eval_expr(vm, element_expr) or_return
// 			append(&array, value)
// 		}
// 		obj := new_clone(Array_Object{base = Object{kind = .Array}, data = array})
// 		result = Value {
// 			kind = .Object_Ref,
// 			data = cast(^Object)obj,
// 		}

// 	case ^Unary_Expression:
// 		result = eval_expr(vm, e.expr) or_return
// 		#partial switch e.op {
// 		case .Minus_Op:
// 			result.data = -(result.data.(f64))
// 		case .Not_Op:
// 			result.data = !(result.data.(bool))
// 		}

// 	case ^Binary_Expression:
// 		// FIXME: Boolean operator needs to eval expr sequentially depending on
// 		// the result of the first
// 		left := eval_expr(vm, e.left) or_return
// 		right := eval_expr(vm, e.right) or_return
// 		#partial switch e.op {
// 		case .And_Op:
// 			result = Value {
// 				kind = .Boolean,
// 				data = left.data.(bool) && right.data.(bool),
// 			}

// 		case .Or_Op:
// 			result = Value {
// 				kind = .Boolean,
// 				data = left.data.(bool) || right.data.(bool),
// 			}

// 		case .Minus_Op:
// 			result = Value {
// 				kind = .Number,
// 				data = left.data.(f64) - right.data.(f64),
// 			}
// 		case .Plus_Op:
// 			result = Value {
// 				kind = .Number,
// 				data = left.data.(f64) + right.data.(f64),
// 			}
// 		case .Mult_Op:
// 			result = Value {
// 				kind = .Number,
// 				data = left.data.(f64) * right.data.(f64),
// 			}

// 		case .Div_Op:
// 			result = Value {
// 				kind = .Number,
// 				data = left.data.(f64) / right.data.(f64),
// 			}

// 		case .Rem_Op:
// 			result = Value {
// 				kind = .Number,
// 				data = f64(int(left.data.(f64)) % int(right.data.(f64))),
// 			}
// 		}

// 	case ^Identifier_Expression:
// 		result = get_stack_value(vm, e.name)

// 	case ^Index_Expression:
// 		obj := get_stack_value(vm, e.left.(^Identifier_Expression).name)
// 		array := cast(^Array_Object)obj.data.(^Object)
// 		index_value := eval_expr(vm, e.index) or_return
// 		result = array.data[int(index_value.data.(f64))]
// 	// e.

// 	case ^Array_Type_Expression:
// 		assert(false, "Invalid branch")

// 	case ^Call_Expression:
// 		value := eval_expr(vm, e.func) or_return
// 		fn := cast(^Fn_Object)value.data.(^Object)
// 		push_stack(vm)
// 		defer pop_stack(vm)
// 		push_stack_value(vm, "result")
// 		for i in 0 ..< fn.param_count {
// 			arg := eval_expr(vm, e.args[i]) or_return
// 			push_stack_value(vm, fn.parameters[i], arg)
// 		}
// 		eval_node(vm, fn.body) or_return
// 		result = get_stack_value(vm, "result")

// 	}
// 	return
// }

// eval_node :: proc(vm: ^Vm, node: Parsed_Node) -> (err: Error) {
// 	switch n in node {
// 	case ^Parsed_Expression_Statement:
// 		eval_expr(vm, n.expr) or_return

// 	case ^Parsed_Block_Statement:
// 		for body_node in n.nodes {
// 			eval_node(vm, body_node) or_return
// 		}

// 	case ^Parsed_Assignment_Statement:
// 		result := eval_expr(vm, n.right) or_return
// 		#partial switch left in n.left {
// 		case ^Identifier_Expression:
// 			set_stack_value(vm, left.name, result)
// 		case ^Index_Expression:
// 			obj := get_stack_value(vm, left.left.(^Identifier_Expression).name)
// 			array := cast(^Array_Object)obj.data.(^Object)
// 			index_value := eval_expr(vm, left.index) or_return
// 			array.data[int(index_value.data.(f64))] = result
// 		case:
// 			assert(false, "Left handside expression kind in Assignment Statement not implemented")
// 		}

// 	case ^Parsed_If_Statement:
// 		push_stack(vm)
// 		defer pop_stack(vm)
// 		condition_result := eval_expr(vm, n.condition) or_return
// 		if condition_result.data.(bool) {
// 			eval_node(vm, n.body) or_return
// 		} else if n.next_branch != nil {
// 			eval_node(vm, n.next_branch) or_return
// 		}

// 	case ^Parsed_Range_Statement:
// 		iterator := RANGE_ITERATOR_IMPL
// 		low_result := eval_expr(vm, n.low) or_return
// 		high_result := eval_expr(vm, n.high) or_return
// 		iterator.low = low_result.data.(f64)
// 		iterator.high = high_result.data.(f64)
// 		if n.op == .Exclusive {
// 			iterator.high -= 1
// 		}

// 		push_stack(vm)
// 		defer pop_stack(vm)
// 		push_stack_value(vm, n.iterator_name)
// 		range_loop: for {
// 			iterator_value, done := iterator->next()
// 			set_stack_value(vm, n.iterator_name, iterator_value)
// 			if done {
// 				break range_loop
// 			} else {
// 				eval_node(vm, n.body)
// 			}
// 		}

// 	case ^Parsed_Var_Declaration:
// 		result: Value
// 		switch n.initialized {
// 		case true:
// 			result = eval_expr(vm, n.expr) or_return

// 		// We zero initialize the value
// 		case false:
// 			// FIXME: Undecided on this semantic
// 			// Should the complex types (array, map, class, which are dynamically allocated)
// 			// Be initialized or left as nil?
// 			// In any case, need a transformed "typed" AST before being able to do any of that
// 			assert(false, "Uninitialized value not supported at runtime yet")
// 		}
// 		if vm.stack_depth > 0 {
// 			push_stack_value(vm, n.identifier, result)
// 		} else {
// 			set_stack_value(vm, n.identifier, result)
// 		}

// 	case ^Parsed_Fn_Declaration:
// 	case ^Parsed_Type_Declaration:
// 		assert(false)
// 	}
// 	return
// }

// zero_initialize_primitive_value :: proc(kind: Value_Kind) -> (result: Value, err: Error) {
// 	result = Value {
// 		kind = kind,
// 	}
// 	return
// }

// zero_initialize_object_value :: proc() -> (result: Value, err: Error) {
// 	assert(false, "Complex type zero initialization not implemented yet")
// 	return
// }
