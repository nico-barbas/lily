package lily

import "core:fmt"
import "core:mem"

Vm :: struct {
	ip:                int,
	modules:           []^Compiled_Module,
	current:           ^Compiled_Module,
	chunk:             ^Chunk,

	// Callbacks
	gc_allocator:      Gc_Allocator,
	gc:                mem.Allocator,
	state:             ^State,
	call_foreign_proc: proc(s: ^State, fn: Foreign_Procedure, stack_slice: []Value),

	// Stack states
	call_stack:        [255]struct {
		chunk:       ^Chunk,
		ip:          int,
		stack_depth: int,
	},
	call_count:        int,
	stack:             [255]Value,
	header_addr:       int,
	stack_ptr:         int,
	stack_depth:       int,

	// vm flags
	show_debug_info:   bool,
}

Vm_Config :: struct {
	state:             ^State,
	call_foreign_proc: proc(s: ^State, fn: Foreign_Procedure, stack_slice: []Value),
	show_debug_info:   bool,

	// Allocators
	temp_allocator:    mem.Allocator,
}

new_vm :: proc(
	config: Vm_Config,
	allocator := context.allocator,
	temp_allocator := context.temp_allocator,
) -> ^Vm {
	vm := new(Vm, allocator)
	vm.state = config.state
	vm.call_foreign_proc = config.call_foreign_proc
	vm.show_debug_info = config.show_debug_info

	init_gc_allocator(
		&vm.gc_allocator,
		Gc_Allocator_Options{
			gather_roots_proc = gather_vm_root_objects,
			data = vm,
			temp_allocator = temp_allocator,
			internals_allocator = allocator,
			initial_size = mem.Megabyte * 5,
			first_collection = mem.Byte * 200,
			growth_factor = 2,
		},
	)
	vm.gc = gc_allocator(&vm.gc_allocator)
	return vm
}

delete_vm :: proc(vm: ^Vm) {
	free_all(vm.gc)
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
		chunk       = vm.chunk,
		ip          = vm.ip,
		stack_depth = vm.stack_depth,
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

reset_vm_stack :: proc(vm: ^Vm) {
	vm.stack_ptr = 0
	vm.header_addr = 0
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

call_frame_stack_depth :: proc(vm: ^Vm) -> int {
	return vm.call_stack[vm.call_count - 1].stack_depth
}

run_vm_fn :: proc(vm: ^Vm, fn_addr: i16) {
	push_call_frame(vm, &vm.current.functions[fn_addr].chunk)
	run_vm(vm)
	for var in &vm.current.functions[fn_addr].chunk.variables {
		var.stack_addr = -1
	}
}

run_vm :: proc(vm: ^Vm) {
	vm.ip = 0
	run: for {
		op := get_op_code(vm)
		switch op {
		case .Op_None:
			assert(false, "Invalid Op Code")

		case .Op_Push:
			push_stack_value(vm, {})

		case .Op_Pop:
			pop_stack_value(vm)

		case .Op_Push_Back:
			moved := pop_stack_value(vm)
			pop_stack_value(vm)
			push_stack_value(vm, moved)

		case .Op_Move:
			move_addr := int(get_i16(vm)) + get_scope_start_addr(vm)
			set_stack_value(vm, move_addr, pop_stack_value(vm))

		case .Op_Copy:
			src_addr := int(get_i16(vm)) + get_scope_start_addr(vm)
			push_stack_value(vm, get_stack_value(vm, src_addr))

		case .Op_Const:
			const_addr := get_i16(vm)
			if int(const_addr) >= len(vm.chunk.constants) {
				fmt.println(op_code_str[Op_Code(vm.chunk.bytecode[0])])
			}
			push_stack_value(vm, vm.chunk.constants[const_addr])

		case .Op_Module:
			module_addr := get_i16(vm)
			vm.current = vm.modules[module_addr]

		case .Op_Prototype:
			module_id := get_i16(vm)
			class_addr := get_i16(vm)
			prototype := Value {
				kind = .Object_Ref,
				data = cast(^Object)&vm.modules[module_id].prototypes[class_addr],
			}
			push_stack_value(vm, prototype)

		case .Op_Inc:
			val := pop_stack_value(vm)
			val.data = val.data.(f64) + 1
			push_stack_value(vm, val)

		case .Op_Dec:
			val := pop_stack_value(vm)
			val.data = val.data.(f64) - 1
			push_stack_value(vm, val)

		case .Op_Neg:
			val := pop_stack_value(vm)
			val.data = val.data.(f64) * -1
			push_stack_value(vm, val)

		case .Op_Not:
			val := pop_stack_value(vm)
			val.data = !val.data.(bool)
			push_stack_value(vm, val)

		case .Op_Add:
			v2, v1 := pop_stack_value(vm), pop_stack_value(vm)
			push_stack_value(vm, Value{kind = .Number, data = v1.data.(f64) + v2.data.(f64)})

		case .Op_Mul:
			v2, v1 := pop_stack_value(vm), pop_stack_value(vm)
			push_stack_value(vm, Value{kind = .Number, data = v1.data.(f64) * v2.data.(f64)})

		case .Op_Div:
			v2, v1 := pop_stack_value(vm), pop_stack_value(vm)
			push_stack_value(vm, Value{kind = .Number, data = v1.data.(f64) / v2.data.(f64)})

		case .Op_Rem:
			v2, v1 := pop_stack_value(vm), pop_stack_value(vm)
			result := int(v1.data.(f64)) % int(v2.data.(f64))
			push_stack_value(vm, Value{kind = .Number, data = f64(result)})

		case .Op_And:
			v2, v1 := pop_stack_value(vm), pop_stack_value(vm)
			push_stack_value(vm, Value{kind = .Boolean, data = v1.data.(bool) && v2.data.(bool)})

		case .Op_Or:
			v2, v1 := pop_stack_value(vm), pop_stack_value(vm)
			push_stack_value(vm, Value{kind = .Boolean, data = v1.data.(bool) || v2.data.(bool)})

		case .Op_Eq:
			v2, v1 := pop_stack_value(vm), pop_stack_value(vm)
			#partial switch v1.kind {
			case .Number:
				push_stack_value(vm, Value{kind = .Boolean, data = v1.data.(f64) == v2.data.(f64)})
			case .Boolean:
				push_stack_value(vm, Value{kind = .Boolean, data = v1.data.(bool) == v2.data.(bool)})
			}

		case .Op_Greater:
			v2, v1 := pop_stack_value(vm), pop_stack_value(vm)
			push_stack_value(vm, Value{kind = .Boolean, data = v1.data.(f64) > v2.data.(f64)})

		case .Op_Greater_Eq:
			v2, v1 := pop_stack_value(vm), pop_stack_value(vm)
			push_stack_value(vm, Value{kind = .Boolean, data = v1.data.(f64) >= v2.data.(f64)})

		case .Op_Lesser:
			v2, v1 := pop_stack_value(vm), pop_stack_value(vm)
			push_stack_value(vm, Value{kind = .Boolean, data = v1.data.(f64) < v2.data.(f64)})

		case .Op_Lesser_Eq:
			v2, v1 := pop_stack_value(vm), pop_stack_value(vm)
			push_stack_value(vm, Value{kind = .Boolean, data = v1.data.(f64) <= v2.data.(f64)})

		case .Op_Begin:
			push_stack_scope(vm)

		case .Op_End:
			pop_stack_scope(vm)

		case .Op_Call:
			fn_addr := get_i16(vm)
			push_call_frame(vm, &vm.current.functions[fn_addr].chunk)

		case .Op_Call_Foreign:
			fn_addr := get_i16(vm)
			has_return := false if get_i16(vm) == -1 else true
			return_val: Value

			fn_values := vm.stack[get_scope_start_addr(vm):vm.stack_ptr]
			vm.call_foreign_proc(vm.state, vm.current.functions[fn_addr].foreign_fn, fn_values)
			if has_return {
				return_val = fn_values[0]
			}
			pop_stack_scope(vm)
			if has_return {
				push_stack_value(vm, return_val)
			}

		case .Op_Call_Method:
			method_addr := get_i16(vm)
			instance_val := previous_scope_last_value(vm)
			set_stack_value(vm, get_scope_start_addr(vm), instance_val)
			instance := cast(^Class_Object)instance_val.data.(^Object)
			push_call_frame(vm, &instance.vtable.methods[method_addr].chunk)

		case .Op_Call_Constr:
			method_addr := get_i16(vm)
			proto_val := previous_scope_last_value(vm)
			push_stack_value(vm, proto_val)
			prototype := cast(^Class_Object)proto_val.data.(^Object)
			push_call_frame(vm, &prototype.vtable.constructors[method_addr].chunk)

		case .Op_Return:
			result_addr := get_i16(vm)
			result_val: Value
			if result_addr >= 0 {
				result_val = get_stack_value(vm, get_var_stack_addr(vm, result_addr))
			}
			pop_count := vm.stack_depth - call_frame_stack_depth(vm)
			for _ in 0 ..= pop_count {
				pop_stack_scope(vm)
			}
			pop_call_frame(vm)
			if result_addr >= 0 {
				push_stack_value(vm, result_val)
			}

		case .Op_Jump:
			vm.ip = int(get_i16(vm))

		case .Op_Jump_True:
			jmp_addr := int(get_i16(vm))
			conditional := pop_stack_value(vm)
			if conditional.data.(bool) {
				vm.ip = jmp_addr
			}

		case .Op_Jump_False:
			jmp_addr := int(get_i16(vm))
			conditional := pop_stack_value(vm)
			if !conditional.data.(bool) {
				vm.ip = jmp_addr
			}

		case .Op_Get:
			var_addr := get_i16(vm)
			var_val := get_stack_value(vm, get_var_stack_addr(vm, var_addr))
			push_stack_value(vm, var_val)

		case .Op_Get_Global:
			var_addr := get_i16(vm)
			push_stack_value(vm, vm.current.variables[var_addr])

		case .Op_Get_Elem:
			obj := pop_stack_value(vm).data.(^Object)
			#partial switch obj.kind {
			case .Array:
				array := cast(^Array_Object)obj
				index_val := pop_stack_value(vm)
				push_stack_value(vm, array.data[int(index_val.data.(f64))])
			case .Map:
				_map := cast(^Map_Object)obj
				index_val := pop_stack_value(vm)
				push_stack_value(vm, _map.data[index_val])
			}

		case .Op_Get_Field:
			field_addr := get_i16(vm)
			instance := cast(^Class_Object)pop_stack_value(vm).data.(^Object)
			push_stack_value(vm, instance.fields[field_addr])

		case .Op_Bind:
			var_addr := get_i16(vm)
			addr := int(get_i16(vm)) + get_scope_start_addr(vm)
			set_var_stack_addr(vm, var_addr, addr)

		case .Op_Set:
			var_addr := get_i16(vm)
			var_stack_addr := vm.chunk.variables[var_addr].stack_addr
			if var_stack_addr == -1 {
				addr := stack_addr(vm)
				set_var_stack_addr(vm, var_addr, addr)
			} else {
				if var_stack_addr != stack_addr(vm) {
					assert(var_stack_addr <= stack_addr(vm))
					set_stack_value(vm, var_stack_addr, pop_stack_value(vm))
				}
			}


		case .Op_Set_Global:
			var_addr := get_i16(vm)
			vm.current.variables[var_addr] = pop_stack_value(vm)

		case .Op_Set_Elem:
			obj := pop_stack_value(vm).data.(^Object)
			#partial switch obj.kind {
			case .Array:
				array := cast(^Array_Object)obj
				index_val := pop_stack_value(vm)
				array.data[int(index_val.data.(f64))] = pop_stack_value(vm)
			case .Map:
				_map := cast(^Map_Object)obj
				index_val := pop_stack_value(vm)
				_map.data[index_val] = pop_stack_value(vm)
			}

		case .Op_Set_Field:
			field_addr := get_i16(vm)
			instance := cast(^Class_Object)pop_stack_value(vm).data.(^Object)
			instance.fields[field_addr] = pop_stack_value(vm)

		case .Op_Make_Instance:
			prototype := cast(^Class_Object)pop_stack_value(vm).data.(^Object)
			instance := new_class_object(prototype, vm.gc)
			push_stack_value(vm, instance)

		case .Op_Make_Array:
			push_stack_value(vm, new_array_object(vm.gc))

		case .Op_Append_Array:
			array_val := pop_stack_value(vm)
			array := cast(^Array_Object)array_val.data.(^Object)
			array_object_append(array, pop_stack_value(vm))
			push_stack_value(vm, array_val)

		case .Op_Make_Map:
			init_elem_count := get_i16(vm)
			map_value := new_map_object(vm.gc)
			map_object := cast(^Map_Object)map_value.data.(^Object)
			for i in 0 ..< init_elem_count {
				k := pop_stack_value(vm)
				v := pop_stack_value(vm)
				map_object.data[v] = k
			}
			push_stack_value(vm, map_value)

		case .Op_Length:
			array := cast(^Array_Object)pop_stack_value(vm).data.(^Object)
			push_stack_value(vm, Value{kind = .Number, data = f64(len(array.data))})
		}


		if vm.show_debug_info {
			print_stack(vm, op)
		}
		if vm_finished(vm) {
			break run
		}
	}
}

vm_finished :: proc(vm: ^Vm) -> bool {
	return vm.chunk == nil || vm.ip >= len(vm.chunk.bytecode)
}

object_to_mark_proc := map[Object_Kind]proc(gc: ^Gc_Allocator, data: rawptr) {
	.Array = proc(gc: ^Gc_Allocator, data: rawptr) {
		array_object := cast(^Array_Object)data
		mark_raw_allocation(gc, data)
		mark_slice(gc, array_object.data)
		for elem in array_object.data {
			if elem.kind == .Object_Ref {
				append_mark_node(gc, object_to_mark_interface(elem.data.(^Object)))
			}
		}
	},
	.Class = proc(gc: ^Gc_Allocator, data: rawptr) {
		class_object := cast(^Class_Object)data
		mark_raw_allocation(gc, data)
		mark_slice(gc, class_object.fields)
		for field in class_object.fields {
			if field.kind == .Object_Ref {
				append_mark_node(gc, object_to_mark_interface(field.data.(^Object)))
			}
		}
	},
	.Map = proc(gc: ^Gc_Allocator, data: rawptr) {
		map_object := cast(^Map_Object)data
		mark_raw_allocation(gc, data)
		mark_map(gc, map_object.data)
		for key, value in map_object.data {
			if key.kind == .Object_Ref {
				append_mark_node(gc, object_to_mark_interface(key.data.(^Object)))
			}
			if value.kind == .Object_Ref {
				append_mark_node(gc, object_to_mark_interface(value.data.(^Object)))
			}
		}
	},
	.String = proc(gc: ^Gc_Allocator, data: rawptr) {
		string_object := cast(^String_Object)data
		mark_raw_allocation(gc, data)
		mark_slice(gc, string_object.data)
	},
}

object_to_mark_interface :: proc(object: ^Object) -> Mark_Node_Interface {
	return Mark_Node_Interface{data = object, mark_proc = object_to_mark_proc[object.kind]}
}

gather_vm_root_objects :: proc(data: rawptr, allocator := context.temp_allocator) -> []Mark_Node_Interface {
	vm := cast(^Vm)data
	roots := make([dynamic]Mark_Node_Interface, allocator)
	for value in vm.stack[:vm.stack_ptr] {
		if value.kind == .Object_Ref {
			append(&roots, object_to_mark_interface(value.data.(^Object)))
		}
	}

	for module in vm.modules {
		for variable in module.variables {
			if variable.kind == .Object_Ref {
				append(&roots, object_to_mark_interface(variable.data.(^Object)))
			}
		}
	}
	return roots[:]
}
