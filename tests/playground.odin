package tests

import "core:fmt"
import lily "../src"

main :: proc() {

	playground()
}

playground :: proc() {using lily
	input: string = `
		type Foo is class
			x: number

			constructor new(_x: number):
				self.x = _x
			end

			fn add(n: number):
				self.x = self.x + n
			end
		end

	    var a = Foo.new(1)
		a.add(2)
	`
	// input := `
	// 	fn add(a: number, b: number): number
	// 		result = a + b
	// 	end

	// 	var a = add(2, 4)
	// `

	parsed_module := make_module()
	defer delete_module(parsed_module)

	err := parse_module(input, parsed_module)

	assert(err == nil, fmt.tprint("Failed, Error raised ->", err))
	// print_parsed_ast(parsed_module)

	checker := new_checker()
	checked_module, check_err := check_module(checker, parsed_module)
	// print_symbol_table(checker, checked_module)
	assert(check_err == nil, fmt.tprint("Failed, Error raised ->", check_err))
	print_checked_ast(checked_module, checker)

	compiler := new_compiler()
	compiled_module := compile_module(compiler, checked_module)
	// print_compiled_module(compiled_module)
	fmt.println()
	vm := Vm{}
	run_module(&vm, compiled_module)
	fmt.println("RESULT:")
	fmt.println(vm.chunk.variables)

}
