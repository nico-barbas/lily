package lily

VM_STACK_SIZE :: 255

Vm :: struct {
	names:       map[string]Stack_ID,
	stack:       [VM_STACK_SIZE]Value,
	header_ptr:  int,
	stack_ptr:   int,
	stack_depth: int,
	functions:   map[string]^Fn_Declaration,
}

Stack_ID :: distinct u8

new_vm :: proc() -> (vm: ^Vm) {
	vm = new(Vm)
	return
}

delete_vm :: proc(vm: ^Vm) {
	free(vm)
}

run_program :: proc(vm: ^Vm, program: []Node) {
	// Gather all the declarations
	for node in program {
		#partial switch n in node {
		case ^Var_Declaration:
			value: Value
			switch n.type_name {
			case "number":
				value = Value {
					kind = .Number,
					data = 0,
				}
			case "boolean":
				value = Value {
					kind = .Boolean,
					data = false,
				}
			case:
				value = Value {
					kind = .Nil,
					data = nil,
				}
			}
			push_stack_value(vm, n.identifier)

		case ^Fn_Declaration:
			vm.functions[n.identifier] = n
		}
	}

	// Run the program
	for node in program {
		eval_node(vm, node)
	}
}

push_stack_value :: proc(vm: ^Vm, name: string, value := Value{kind = .Nil}) {
	vm.names[name] = Stack_ID(vm.stack_ptr)
	vm.stack[vm.stack_ptr] = value
	vm.stack_ptr += 1
}

set_stack_value :: proc(vm: ^Vm, name: string, value: Value) {
	vm.stack[vm.names[name]] = value
}

get_stack_value :: proc(vm: ^Vm, name: string) -> Value {
	return vm.stack[vm.names[name]]
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

eval_expr :: proc(vm: ^Vm, expr: Expression) -> (result: Value, err: Error) {
	switch e in expr {
	case ^Literal_Expression:
		result = e.value

	case ^Unary_Expression:
		result = eval_expr(vm, e.expr) or_return
		#partial switch e.op {
		case .Minus_Op:
			result.data = -(result.data.(f64))
		case .Not_Op:
			result.data = !(result.data.(bool))
		}

	case ^Binary_Expression:
		// FIXME: Boolean operator needs to eval expr sequentially depending on
		// the result of the first
		left := eval_expr(vm, e.left) or_return
		right := eval_expr(vm, e.right) or_return
		#partial switch e.op {
		case .And_Op:
			result = Value {
				kind = .Boolean,
				data = left.data.(bool) && right.data.(bool),
			}

		case .Or_Op:
			result = Value {
				kind = .Boolean,
				data = left.data.(bool) || right.data.(bool),
			}

		case .Minus_Op:
			result = Value {
				kind = .Number,
				data = left.data.(f64) - right.data.(f64),
			}
		case .Plus_Op:
			result = Value {
				kind = .Number,
				data = left.data.(f64) + right.data.(f64),
			}
		case .Mult_Op:
			result = Value {
				kind = .Number,
				data = left.data.(f64) * right.data.(f64),
			}

		case .Div_Op:
			result = Value {
				kind = .Number,
				data = left.data.(f64) / right.data.(f64),
			}

		case .Rem_Op:
			result = Value {
				kind = .Number,
				data = f64(int(left.data.(f64)) % int(right.data.(f64))),
			}
		}

	case ^Identifier_Expression:
		result = get_stack_value(vm, e.name)

	case ^Fn_Literal_Expression:
		assert(false, "Function Literal and pointers not implemented yet")

	case ^Call_Expression:
		fn := vm.functions[e.name]
		push_stack(vm)
		defer pop_stack(vm)
		push_stack_value(vm, "result")
		for i in 0 ..< fn.param_count {
			arg := eval_expr(vm, e.args[i]) or_return
			push_stack_value(vm, fn.parameters[i].name, arg)
		}
		eval_node(vm, fn.body) or_return
		result = get_stack_value(vm, "result")

	}
	return
}

eval_node :: proc(vm: ^Vm, node: Node) -> (err: Error) {
	switch n in node {
	case ^Expression_Statement:
		eval_expr(vm, n.expr) or_return

	case ^Block_Statement:
		for body_node in n.nodes {
			eval_node(vm, body_node) or_return
		}

	case ^Assignment_Statement:
		result := eval_expr(vm, n.expr) or_return
		set_stack_value(vm, n.identifier, result)

	case ^If_Statement:
		push_stack(vm)
		defer pop_stack(vm)
		condition_result := eval_expr(vm, n.condition) or_return
		if condition_result.data.(bool) {
			eval_node(vm, n.body) or_return
		} else if n.next_branch != nil {
			eval_node(vm, n.next_branch) or_return
		}

	case ^Range_Statement:
		iterator := RANGE_ITERATOR_IMPL
		low_result := eval_expr(vm, n.low) or_return
		high_result := eval_expr(vm, n.high) or_return
		iterator.low = low_result.data.(f64)
		iterator.high = high_result.data.(f64)
		if n.op == .Exclusive {
			iterator.high -= 1
		}

		push_stack(vm)
		defer pop_stack(vm)
		push_stack_value(vm, n.iterator_name)
		range_loop: for {
			iterator_value, done := iterator->next()
			set_stack_value(vm, n.iterator_name, iterator_value)
			if done {
				break range_loop
			} else {
				eval_node(vm, n.body)
			}
		}

	case ^Var_Declaration:
		result := eval_expr(vm, n.expr) or_return
		if vm.stack_depth > 0 {
			push_stack_value(vm, n.identifier, result)
		} else {
			set_stack_value(vm, n.identifier, result)
		}

	case ^Fn_Declaration:
	// Not allowed to declare functions outside of the file scope

	}
	return
}
