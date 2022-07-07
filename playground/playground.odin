package playground

import "core:fmt"
import "core:mem"
import lily "../src"

main :: proc() {
	track := mem.Tracking_Allocator{}
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	playground()

	// fmt.println()
	// if len(track.allocation_map) > 0 {
	// 	fmt.printf("Leaks:")
	// 	for _, v in track.allocation_map {
	// 		fmt.printf("\t%v\n\n", v)
	// 	}
	// }
	// fmt.printf("Leak count: %d\n", len(track.allocation_map))
	// if len(track.bad_free_array) > 0 {
	// 	fmt.printf("Bad Frees:")
	// 	for v in track.bad_free_array {
	// 		fmt.printf("\t%v\n\n", v)
	// 	}
	// }
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
	// 	a.add(13)
	// `
	input := `
		import math 
		
		var foo = math.Vector.new()
		var b = true
		for i in 0..10:
			foo.add(i)
		end
	`

	checker := Checker{}
	init_checker(&checker)
	checked, err := build_checked_program(&checker, "main", input)
	assert(err == nil, fmt.tprint(err))

	for module in checked.modules {
		print_symbol_table(&checker, module)
		print_checked_ast(module, &checker)
	}

	compiled_program := make_compiled_program(checked)
	for i in 0 ..< len(compiled_program) {
		compile_module(checked, compiled_program, i)
		print_compiled_module(compiled_program[i])
	}
	run_program(compiled_program, 0)
}
