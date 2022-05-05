package test

import "core:fmt"
import lily "../src"

vm: ^lily.Vm

main :: proc() {
	vm = lily.new_vm()
	defer lily.delete_vm(vm)

	test_lexer()

	test_semantic()

	fmt.println("=====")
	fmt.println("=====")
	playground()
}

playground :: proc() {
	using lily
	input: string = `
		var stop = true
		var foobar = go(false) and stop
		var foo = add(10, 20)

		fn add(a: number, b: number): number
			var d = 10
			result = a + b + d
		end

		fn go(a: bool): bool
			result = not a
		end

		var bar = foo + 10

		if stop:
			bar = 10
		else:
			bar = 20
		end

		var test = 10
		for i in 0..10:
			test = test + i
		end
	`
	program, err := make_program(input)

	assert(err == nil, fmt.tprint("Failed, Error raised ->", err))


	checker := &Checker{}

	init_checker(checker)
	check_err := check_program(checker, &program)
	assert(check_err == nil, fmt.tprint("Failed, Error raised ->", check_err))

	print_ast(program)
	run_program(vm, &program)
	fmt.println(vm.names)
	fmt.println(vm.functions)
	// fmt.println(vm.stack)
	fmt.println(get_stack_value(vm, "test"))
	test := 10
	for i in 0 ..< 10 {
		test += i
	}
	fmt.println(test)
}

test_lexer :: proc() {
	using lily
	inputs := [?]string{
		"= == < <= > >=",
		". .. ... ,",
		"+ - * / %",
		"var fn return and or true false",
		"10 1.2",
	}
	counts := [?]int{6, 4, 5, 7, 2}
	expects := [?][]Token_Kind{
		{.Assign, .Equal, .Lesser, .Lesser_Equal, .Greater, .Greater_Equal},
		{.Dot, .Double_Dot, .Triple_Dot, .Comma},
		{.Plus, .Minus, .Star, .Slash, .Percent},
		{.Var, .Fn, .Return, .And, .Or, .True, .False},
		{.Number_Literal, .Number_Literal},
	}

	lexer := Lexer{}
	for input, i in inputs {
		count := 0
		set_lexer_input(&lexer, input)
		for {
			t := scan_token(&lexer)
			if t.kind == .EOF {
				break
			}
			assert(
				t.kind == expects[i][count],
				fmt.tprint("Failed, Expected", expects[i][count], "Got", t.kind),
			)
			count += 1
		}
		assert(
			count == counts[i],
			fmt.tprintf(
				"Failed, Too many tokens for input number %i; Got %i, but expected %i",
				i,
				count,
				counts[i],
			),
		)
	}

	fmt.println("Lexer: OK")
}
