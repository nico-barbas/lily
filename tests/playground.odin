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
		var foo = array of number[2, 3]
		foo[0] = 10
		foo[1] = add(4, 9)
		foo[0] = add(foo[0], foo[1])
		fn add(a: number, b: number): number
			result = a + b
		end

		fn testParemeterless():
	
		end
	`
	program := make_program()
	defer delete_program(program)

	err := append_to_program(input, program)

	assert(err == nil, fmt.tprint("Failed, Error raised ->", err))
	fmt.println(input)
	print_ast(program)

	checker := new_checker()
	check_err := check_nodes(checker, program.nodes[:])
	assert(check_err == nil, fmt.tprint("Failed, Error raised ->", check_err))

	run_program(vm, program.nodes[:])
	array := cast(^Array_Object)get_stack_value(vm, "foo").data.(^Object)

	fmt.println(array.data)
}
