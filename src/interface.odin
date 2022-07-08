package lily

import "core:fmt"
import "core:strings"

State :: struct {
	checked_modules:     []^Checked_Module,
	import_modules_id:   map[string]int,
	import_modules_name: map[int]string,
	compiled_modules:    []^Compiled_Module,
	vm:                  Vm,
	std_builder:         strings.Builder,

	// Vm stack manipulation proc
	value_buf:           []Value,
	set_value:           proc(state: ^State, data: Value_Data, at: int),
	get_value:           proc(state: ^State, at: int) -> Value,

	// Various callbacks
	internal_bind_fn:    proc(state: ^State, decl: ^Checked_Fn_Declaration) -> Foreign_Procedure,
	user_bind_fn:        proc(state: ^State, info: Foreign_Decl_Info) -> Foreign_Procedure,
}

Config :: struct {
	bind_fn: proc(state: ^State, info: Foreign_Decl_Info) -> Foreign_Procedure,
}

new_state :: proc(c: Config) -> ^State {
	//odinfmt: disable
	return new_clone(State{
		std_builder = strings.make_builder(0, 200),
		get_value = proc(state: ^State, at: int) -> Value {
			return state.value_buf[at]
		},
		internal_bind_fn = bind_foreign_fn,
	})
	//odinfmt: enable
}

compile_source :: proc(s: ^State, module_name: string, source: string) -> (err: Error) {
	checker := Checker{}
	init_checker(&checker)
	s.checked_modules = build_checked_program(&checker, module_name, source) or_return
	s.import_modules_id = checker.import_names_lookup
	for name, id in s.import_modules_id {
		s.import_modules_name[id] = name
	}
	s.compiled_modules = make_compiled_program(s)
	for i in 0 ..< len(s.compiled_modules) {
		// print_checked_ast(s.checked_modules[i], &checker)
		compile_module(s, i)
		print_compiled_module(s.compiled_modules[i])
	}
	return
}

run_module :: proc(s: ^State, module_name: string) {
	run_program(s, s.import_modules_id[module_name])
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
		}
	} else {
		fn_info := decl.identifier.info.(Fn_Symbol_Info)
		info := Foreign_Decl_Info {
			identifier  = decl.identifier.name,
			arity       = len(decl.params),
			parameters  = make([]string, len(decl.params), context.temp_allocator),
			return_type = fn_info.return_symbol.name,
		}
		for param, i in decl.params {
			info.parameters[i] = param.name
		}
		fn = state->user_bind_fn(info)
	}
	return
}

call_foreign_fn :: proc(state: ^State, fn: Foreign_Procedure, values: []Value) {
	state.value_buf = values
	fn(state)
}

std_source :: `
foreign fn print(s: any):
`

std_print :: proc(state: ^State) {
	value := state->get_value(0)
	strings.reset_builder(&state.std_builder)
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
				strings.write_rune_builder(&state.std_builder, r)
			}
			fmt.println(strings.to_string(state.std_builder))
		case .Array:
			array := cast(^Array_Object)obj
			fmt.println(array.data)
		case .Class:
			instance := cast(^Class_Object)obj
			fmt.println(instance.fields)
		}
	}
}
