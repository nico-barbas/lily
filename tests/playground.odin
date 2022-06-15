package tests

import "core:fmt"
import lily "../src"

// vm: ^lily.Vm

main :: proc() {
	// vm = lily.new_vm()
	// defer lily.delete_vm(vm)

	playground()
}

playground :: proc() {using lily
	// input: string = `
	// 	type Foo is class
	// 		x: number

	// 		constructor new(_x: number):
	// 			self.x = _x
	// 		end
	// 	end

	//     var a = Foo.new(1)
	// `
	input := `
		var a = 10
	`

	parsed_module := make_module()
	defer delete_module(parsed_module)

	err := parse_module(input, parsed_module)

	assert(err == nil, fmt.tprint("Failed, Error raised ->", err))
	fmt.println(input)
	print_parsed_ast(parsed_module)

	checker := new_checker()
	checked_module, check_err := check_module(checker, parsed_module)
	print_symbol_table(checker, checked_module)
	assert(check_err == nil, fmt.tprint("Failed, Error raised ->", check_err))
	print_checked_ast(checked_module, checker)

	// compiler := new_compiler()
	// compiled_module := compile_module(compiler, checked_module)
	// // for class in compiled_module.
	// for fn in compiled_module.functions {
	// 	print_chunk(fn.chunk)
	// }
	// print_chunk(compiled_module.main)
	// fmt.println()
	// vm := Vm{}
	// run_module(&vm, compiled_module)
	// fmt.println()
	// fmt.println(vm.chunk.variables)

	// fmt.println(array.data)
}
