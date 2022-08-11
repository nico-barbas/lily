package lily

import "core:fmt"
import "core:strings"
import "core:os"
import "core:math"
import "core:math/rand"
import "core:mem"

DEFAULT_MODULE_COUNT :: 32

State :: struct {
	allocator:                   mem.Allocator,
	temp_allocator:              mem.Allocator,
	runtime_allocator:           mem.Allocator,
	sources:                     [dynamic]string,
	checked_modules:             []^Checked_Module,
	import_modules_id:           map[string]int,
	import_modules_name:         map[int]string,
	compiled_modules:            []^Compiled_Module,
	checker:                     Checker,
	vm:                          ^Vm,
	init_order:                  []int,
	need_init:                   bool,
	std_builder:                 strings.Builder,

	// Vm stack manipulation proc
	value_buf:                   []Value,
	set_value:                   proc(state: ^State, data: Value_Data, at: int),
	get_value:                   proc(state: ^State, at: int) -> Value,

	// Various callbacks
	internal_load_module_source: proc(state: ^State, name: string) -> (string, Error),
	internal_bind_fn:            proc(state: ^State, decl: ^Checked_Fn_Declaration) -> Foreign_Procedure,
	user_bind_fn:                proc(state: ^State, info: Foreign_Decl_Info) -> Foreign_Procedure,
	user_load_module_source:     proc(state: ^State, name: string) -> (string, bool),
}

Config :: struct {
	allocator:          mem.Allocator,
	temp_allocator:     mem.Allocator,
	runtime_allocator:  mem.Allocator,
	load_module_source: proc(state: ^State, name: string) -> (string, bool),
	bind_fn:            proc(state: ^State, info: Foreign_Decl_Info) -> Foreign_Procedure,
}

new_state :: proc(
	c: Config,
	allocator := context.allocator,
	temp_allocator := context.temp_allocator,
) -> ^State {
	DEBUG_VM :: false

	allocator := c.allocator if c.allocator.data != nil else allocator
	temp_allocator := c.temp_allocator if c.temp_allocator.data != nil else temp_allocator

	state := new(State, allocator)
	state^ = State {
		allocator = allocator,
		temp_allocator = temp_allocator,
		sources = make([dynamic]string, DEFAULT_MODULE_COUNT, allocator),
		import_modules_id = make(map[string]int, DEFAULT_MODULE_COUNT, allocator),
		import_modules_name = make(map[int]string, DEFAULT_MODULE_COUNT, allocator),
		checker = Checker{},
		std_builder = strings.builder_make(0, 200, allocator),
		set_value = proc(state: ^State, data: Value_Data, at: int) {
			value := data_to_value(data)
			if state.value_buf != nil {
				state.value_buf[at] = value
			} else {
				set_stack_value(state.vm, get_scope_start_addr(state.vm) + at, value)
			}
		},
		get_value = proc(state: ^State, at: int) -> Value {
			return state.value_buf[at]
		},
		internal_load_module_source = load_source,
		internal_bind_fn = bind_foreign_fn,
		user_bind_fn = c.bind_fn,
		user_load_module_source = c.load_module_source,
	}
	init_checker(&state.checker, allocator)
	state.vm = new_vm(
		Vm_Config{
			state = state,
			call_foreign_proc = call_foreign_proc,
			show_debug_info = DEBUG_VM,
			temp_allocator = temp_allocator,
		},
		allocator,
	)
	return state
}

free_state :: proc(state: ^State) {
	delete_vm(state.vm)
}

load_source :: proc(state: ^State, name: string) -> (source: string, err: Error) {
	module_path := strings.concatenate({name, ".lily"}, state.temp_allocator)

	if state.user_load_module_source != nil {
		if src, found := state->user_load_module_source(name); found {
			source = strings.clone(src, state.allocator)
			append(&state.sources, source)
			return
		}
	}
	source_slice, ok := os.read_entire_file(module_path, state.allocator)
	if !ok {
		err = format_error(
			Runtime_Error{
				kind = .Invalid_Source_File_Name,
				details = fmt.tprintf("Could not find source file: %state", module_path),
			},
		)
		return
	}
	source = string(source_slice)
	append(&state.sources, source)
	return
}

compile_source :: proc(state: ^State, module_name: string, source: string) -> []Error {
	DEBUG_PARSER :: false
	DEBUG_SYMBOLS :: false
	DEBUG_CHECKER :: true
	DEBUG_COMPILER :: false

	context.allocator = state.allocator
	context.temp_allocator = state.temp_allocator

	parsed_modules := make([dynamic]^Parsed_Module, state.temp_allocator)
	defer {
		when DEBUG_PARSER {
			for p in parsed_modules {
				print_parsed_ast(p)
			}
		}
	}


	module := make_parsed_module(module_name, state.temp_allocator)
	parse_ok := parse_module(source, module, state.temp_allocator)
	append(&state.sources, source)
	append(&parsed_modules, module)
	if !parse_ok {
		return module.errors[:]
	}

	state.import_modules_id[module_name] = 0

	parse_ok = parse_dependencies(
		state,
		&parsed_modules,
		&state.import_modules_id,
		module,
		state.temp_allocator,
	)
	if !parse_ok {
		parsing_errors := make([dynamic]Error, state.temp_allocator)
		for m in parsed_modules {
			for err in m.errors {
				append(&parsing_errors, err)
			}
		}
		return parsing_errors[:]
	}
	for name, id in state.import_modules_id {
		state.import_modules_name[id] = name
	}


	dep_err: Error
	state.init_order, dep_err = check_dependency_graph(
		parsed_modules[:],
		state.import_modules_id,
		module_name,
	)
	if dep_err != nil {
		errors := make([]Error, 1, state.temp_allocator)
		errors[0] = dep_err
		return errors
	}

	state.checked_modules = make([]^Checked_Module, len(parsed_modules))

	state.checker.modules = state.checked_modules
	_, check_err := build_checked_program(
		&state.checker,
		state.import_modules_id,
		parsed_modules[:],
		state.init_order,
	)
	if check_err != nil {
		errors := make([]Error, 1, state.temp_allocator)
		errors[0] = check_err
		return errors
	}

	// Compile program
	state.compiled_modules = make_compiled_program(state)
	for i in 0 ..< len(state.compiled_modules) {
		when DEBUG_SYMBOLS {
			print_symbol_table(&state.checker, state.checked_modules[i])
		}
		when DEBUG_CHECKER {
			print_checked_ast(state.checked_modules[i], &state.checker)
		}
		compile_module(state, i)
		when DEBUG_COMPILER {
			print_compiled_module(state.compiled_modules[i])
		}
	}
	state.need_init = true
	state.vm.modules = state.compiled_modules
	return nil
}

compile_file :: proc(state: ^State, file_path: string) -> []Error {
	module_name: string
	source: string
	{
		strings.builder_reset(&state.std_builder)
		writing := false
		for i := len(file_path) - 1; i >= 0; i -= 1 {
			if writing {
				if file_path[i] == '/' {
					break
				}
				strings.write_byte(&state.std_builder, file_path[i])
			} else {
				if file_path[i] == '.' {
					writing = true
				}
			}
		}
		module_name = strings.reverse(strings.to_string(state.std_builder))
		source_slice, ok := os.read_entire_file(file_path)
		if !ok {
			errors := make([]Error, 1, state.temp_allocator)
			errors[0] = format_error(
				Runtime_Error{
					kind = .Invalid_Source_File_Name,
					details = fmt.tprintf("Could not find source file: %state", file_path),
				},
			)
			return errors
		}
		source = string(source_slice)
	}
	return compile_source(state, module_name, source)
}

run_module :: proc(state: ^State, module_name: string) {
	entry_point := state.import_modules_id[module_name]
	should_run := true
	if state.need_init {
		for id in state.init_order {
			if id == entry_point {
				should_run = false
			}
			if len(state.compiled_modules[id].main.bytecode) == 0 {
				continue
			}
			state.vm.current = state.compiled_modules[id]
			state.vm.chunk = &state.compiled_modules[id].main
			run_vm(state.vm)
		}
		state.need_init = false
	}

	if should_run {
		state.vm.current = state.compiled_modules[entry_point]
		state.vm.chunk = &state.compiled_modules[entry_point].main
		run_vm(state.vm)
	}
}

prepare_call :: proc(state: ^State, handle: Handle) {
	if state.need_init {
		for id in state.init_order {
			if len(state.compiled_modules[id].main.bytecode) == 0 {
				continue
			}
			state.vm.current = state.compiled_modules[id]
			state.vm.chunk = &state.compiled_modules[id].main
			run_vm(state.vm)
			reset_vm_stack(state.vm)
		}

		state.need_init = false
	}

	push_stack_scope(state.vm)
	info := transmute([2]i32)handle.info
	if info[1] == 1 {
		push_stack_value(state.vm, {})
	}
	for _ in 0 ..< info[0] {
		push_stack_value(state.vm, {})
	}
}

call :: proc(state: ^State, handle: Handle) {
	switch handle.kind {
	case .Fn_Handle:
		state.vm.current = state.compiled_modules[handle.module_id]
		run_vm_fn(state.vm, handle.primary_id)
	}

	pop_stack_scope(state.vm)
}

Foreign_Decl_Info :: struct {
	identifier:  string,
	arity:       int,
	parameters:  []string,
	return_type: string,
}

Foreign_Procedure :: #type proc(state: ^State)

bind_foreign_fn :: proc(state: ^State, decl: ^Checked_Fn_Declaration) -> (fn: Foreign_Procedure) {
	module_name := state.import_modules_name[decl.identifier.module_id]
	if module_name == "std" {
		switch decl.identifier.name {
		case "print":
			return std_print
		case "toString":
			return std_to_string
		case "sqrt":
			return std_sqrt
		case "rand":
			return std_rand
		case "randN":
			return std_rand_n
		case "randRange":
			return std_rand_range
		}
	} else {
		fn_info := decl.identifier.info.(Fn_Symbol_Info)
		info := Foreign_Decl_Info {
			identifier  = decl.identifier.name,
			arity       = len(decl.params),
			parameters  = make([]string, len(decl.params), context.temp_allocator),
			return_type = fn_info.return_symbol.name if fn_info.has_return else "",
		}
		for param, i in decl.params {
			info.parameters[i] = param.name
		}
		fn = state->user_bind_fn(info)
	}
	return
}

call_foreign_proc :: proc(state: ^State, fn: Foreign_Procedure, values: []Value) {
	state.value_buf = values
	fn(state)
	state.value_buf = nil
}

Handle :: struct {
	kind:         enum {
		Fn_Handle,
	},
	module_id:    int,
	primary_id:   i16,
	secondary_id: i16,
	info:         int,
}

make_fn_handle :: proc(state: ^State, module_name, fn_name: string) -> (handle: Handle, err: Error) {
	if id, exist := state.import_modules_id[module_name]; exist {
		module := state.compiled_modules[id]
		if fn_id, exist := module.fn_addr[fn_name]; exist {
			fn_decl := state.checked_modules[id].functions[fn_id].(^Checked_Fn_Declaration)
			fn_info := fn_decl.identifier.info.(Fn_Symbol_Info)
			arity_bits := i32(len(fn_decl.params))
			return_bits := i32(1 if fn_info.has_return else -1)
			handle = Handle {
				module_id  = id,
				primary_id = fn_id,
				info       = transmute(int)[2]i32{arity_bits, return_bits},
			}

		} else {
			err = format_error(
				Runtime_Error{
					kind = .Invalid_Module_Name,
					details = fmt.tprintf("No imported module with name %state", module_name),
				},
			)
		}
	} else {
		err = format_error(
			Runtime_Error{
				kind = .Invalid_Module_Name,
				details = fmt.tprintf("No imported module with name %state", module_name),
			},
		)
	}
	return
}

std_source :: `
foreign fn print(state: any):
foreign fn toString(a: any): string
foreign fn rand(): number
foreign fn randN(n: number): number
foreign fn randRange(lo: number, hi: number): number
foreign fn sqrt(n: number): number
`

std_print :: proc(state: ^State) {
	value := state->get_value(0)
	strings.builder_reset(&state.std_builder)
	switch value.kind {
	case .Nil:
		fmt.println("nil")
	case .Boolean, .Number:
		fmt.println(value.data)
	case .Object_Ref:
		obj := value.data.(^Object)
		#partial switch obj.kind {
		case .String:
			str_object := cast(^String_Object)obj
			for r in str_object.data {
				strings.write_rune(&state.std_builder, r)
			}
			fmt.println(strings.to_string(state.std_builder))
		case .Array:
			array := cast(^Array_Object)obj
			strings.write_rune(&state.std_builder, '[')
			for elem, i in array.data {
				fmt.sbprint(&state.std_builder, elem.data)
				if i < len(array.data) - 1 {
					fmt.sbprint(&state.std_builder, ", ")
				}
			}
			strings.write_rune(&state.std_builder, ']')
			fmt.println(strings.to_string(state.std_builder))

		case .Class:
			instance := cast(^Class_Object)obj
			fmt.println(instance.fields)
		}
	}
}

std_to_string :: proc(state: ^State) {
	value := state->get_value(1)
	strings.builder_reset(&state.std_builder)
	str: string
	switch value.kind {
	case .Nil:
		str = "nil"
	case .Boolean, .Number:
		str = fmt.tprint(value.data)
	case .Object_Ref:
		obj := value.data.(^Object)
		#partial switch obj.kind {
		case .String:
			str_object := cast(^String_Object)obj
			for r in str_object.data {
				strings.write_rune(&state.std_builder, r)
			}
			str = fmt.tprint(strings.to_string(state.std_builder))
		case .Array:
			array := cast(^Array_Object)obj
			strings.write_rune(&state.std_builder, '[')
			for elem, i in array.data {
				fmt.sbprint(&state.std_builder, elem.data)
				if i < len(array.data) - 1 {
					fmt.sbprint(&state.std_builder, ", ")
				}
			}
			strings.write_rune(&state.std_builder, ']')
			str = fmt.tprint(strings.to_string(state.std_builder))

		case .Class:
			instance := cast(^Class_Object)obj
			str = fmt.tprint(instance.fields)
		}
	}
	str_object := new_string_object(str, state.vm.gc)
	state->set_value(str_object.data.(^Object), 0)
}

std_sqrt :: proc(state: ^State) {
	n := state->get_value(1).data.(f64)
	sqrt_n := math.sqrt(n)
	state->set_value(sqrt_n, 0)
}

std_rand :: proc(state: ^State) {
	state->set_value(rand.float64(), 0)
}

std_rand_n :: proc(state: ^State) {
	n := state->get_value(1).data.(f64)
	state->set_value(rand.float64_range(0, n), 0)
}

std_rand_range :: proc(state: ^State) {
	lo := state->get_value(1).data.(f64)
	hi := state->get_value(2).data.(f64)
	state->set_value(rand.float64_range(lo, hi), 0)
}
