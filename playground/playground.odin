package playground

import "core:fmt"
import "core:mem"
import lily "../src"

main :: proc() {
	track := mem.Tracking_Allocator{}
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	playground()

	fmt.println()
	if len(track.allocation_map) > 0 {
		fmt.printf("Leaks:")
		for _, v in track.allocation_map {
			fmt.printf("\t%v\n\n", v)
		}
	}
	fmt.printf("Leak count: %d\n", len(track.allocation_map))
	if len(track.bad_free_array) > 0 {
		fmt.printf("Bad Frees:")
		for v in track.bad_free_array {
			fmt.printf("\t%v\n\n", v)
		}
	}
}

playground :: proc() {using lily
	PRINT_AST :: true
	PRINT_SYMBOL_TABLE :: false
	PRINT_COMPILE :: true
	PRINT_VM_STATE :: true

	RUN_PARSER :: true
	RUN_CHECKER :: true
	RUN_COMPILER :: true
	RUN_VM :: true

	// input: string = `
	// 	type Foo is class
	// 		x: number

	// 		constructor new(_x: number):
	// 			self.x = _x
	// 		end

	// 		fn add(n: number):
	// 			self.x = self.x + n
	// 		end
	// 	end

	//     var a = Foo.new(1)
	// 	a.add(2)
	// `
	input := `
		import math

		var a = math.Vector.new()
	`

	checker := Checker{}
	init_checker(&checker)
	_, err := build_checked_program(&checker, "main", input)
	assert(err == nil, fmt.tprint(err))

	for module in checker.parsed_results {
		print_parsed_ast(module)
	}

	for module in checker.modules {
		print_checked_ast(module, &checker)
	}

	// compiler := new_compiler()
	// compiled_module := compile_module(compiler, checked_modules, 0)
	// print_compiled_module(compiled_module)

	// compiled_modules := [?]^Compiled_Module{compiled_module}

	// vm := new_vm()
	// vm.modules = compiled_modules[:]
	// run_module(vm, 0)

	// when RUN_PARSER {
	// 	// Parsing
	// 	parsed_module := make_parsed_module()
	// 	defer delete_parsed_module(parsed_module)
	// 	err := parse_module(input, parsed_module)
	// 	assert(err == nil, fmt.tprint("Failed, Error raised ->", err))

	// 	when PRINT_AST {
	// 		print_parsed_ast(parsed_module)
	// 	}

	// 	when RUN_CHECKER {
	// 		checker := Checker{}
	// 		init_checker(&checker)
	// 		build_checked_program(&checker, parsed_module) or_return
	// 		// checked_module, check_err := check_module(&checker, parsed_module)
	// 		defer free_checker(&checker)
	// 		defer delete_checked_module(checked_module)
	// 		assert(check_err == nil, fmt.tprint("Failed, Error raised ->", check_err))

	// 		when PRINT_AST {

	// 			print_checked_ast(checked_module, &checker)
	// 		}
	// 		when PRINT_SYMBOL_TABLE {
	// 			print_symbol_table(checker, checked_module)
	// 		}

	// 		when RUN_COMPILER {
	// 			compiler := new_compiler()
	// 			compiled_module := compile_checked_module(compiler, checked_module)
	// 			defer free_compiler(compiler)
	// 			defer delete_compiled_module(compiled_module)

	// 			when PRINT_COMPILE {
	// 				print_compiled_module(compiled_module)
	// 				fmt.println("== END COMPILED MODULE ==")
	// 			}
	// 			when RUN_VM {
	// 				vm := new_vm()
	// 				defer free_vm(vm)
	// 				run_module(vm, compiled_module)
	// 			}
	// 			when PRINT_VM_STATE {
	// 				fmt.println("RESULT:")
	// 				fmt.println(vm.chunk.variables)
	// 			}
	// 		}
	// 	}
	// }
}
