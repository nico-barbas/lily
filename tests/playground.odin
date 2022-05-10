package test

import "core:fmt"
import lily "../src"

vm: ^lily.Vm

main :: proc() {
	vm = lily.new_vm()
	defer lily.delete_vm(vm)

	playground()
}

playground :: proc() {
	using lily
	input: string = `
		var r = 1
		fn add(a: number, b: number): number
			result = a + b
		end
	`
	program := make_program()
	defer delete_program(program)

	err := append_to_program(input, program)

	assert(err == nil, fmt.tprint("Failed, Error raised ->", err))
	fmt.println(input)

	checker := new_checker()
	check_err := check_nodes(checker, program.nodes[:])
	assert(check_err == nil, fmt.tprint("Failed, Error raised ->", check_err))

	print_ast(program)
	run_program(vm, program.nodes[:])
	fmt.println(get_stack_value(vm, "foo"))
}
