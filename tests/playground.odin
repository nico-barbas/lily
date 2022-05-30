package test

import "core:fmt"
import lily "../src"

// vm: ^lily.Vm

main :: proc() {
	// vm = lily.new_vm()
	// defer lily.delete_vm(vm)

	playground()
}

playground :: proc() {
	using lily
	input: string = `
		var foo = 10

		--var foo = array of number[2, 3]
		--foo[0] = 10
		--foo[1] = add(4, 9)
		--foo[0] = add(foo[0], foo[1])
		--fn add(a: number, b: number): number
		--	result = a + b
		--end
		--type MyType is number
		--var bar: MyType = 4
	`
	parsed_module := make_module()
	defer delete_module(parsed_module)

	err := parse_module(input, parsed_module)

	assert(err == nil, fmt.tprint("Failed, Error raised ->", err))
	fmt.println(input)
	print_parsed_ast(parsed_module)

	checker := new_checker()
	checked_module, check_err := check_module(checker, parsed_module)
	assert(check_err == nil, fmt.tprint("Failed, Error raised ->", check_err))
	fmt.println(checked_module)

	// run_program(vm, program.nodes[:])
	// array := cast(^Array_Object)get_stack_value(vm, "foo").data.(^Object)

	// fmt.println(array.data)
}
