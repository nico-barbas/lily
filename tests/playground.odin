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
		var a = 1
        for i in 0..10:
            a = a + 1
        end
	`
	parsed_module := make_module()
	defer delete_module(parsed_module)

	err := parse_module(input, parsed_module)

	assert(err == nil, fmt.tprint("Failed, Error raised ->", err))
	fmt.println(input)
	//print_parsed_ast(parsed_module)

	checker := new_checker()
	checked_module, check_err := check_module(checker, parsed_module)
	assert(check_err == nil, fmt.tprint("Failed, Error raised ->", check_err))
	print_checked_ast(checked_module, checker)

	compiler := new_compiler()
	compiled_module := compile_module(compiler, checked_module)
	print_chunk(compiled_module.main)
	fmt.println()
	vm := Vm{}
	run_bytecode(&vm, compiled_module.main)
	fmt.println(vm.stack[:vm.stack_ptr])
	fmt.println(vm.chunk.variables)
	// run_program(vm, program.nodes[:])
	// array := cast(^Array_Object)get_stack_value(vm, "foo").data.(^Object)

	// fmt.println(array.data)
}
