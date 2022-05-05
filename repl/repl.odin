package repl

import "core:fmt"
import "core:os"
import lily "../src"

Repl :: struct {
	program:    ^lily.Program,
	checker:    ^lily.Checker,
	vm:         ^lily.Vm,
	node_count: int,
}

main :: proc() {
	using lily
	buf := make([]byte, 500)
	buf_ptr := 0
	defer delete(buf)

	repl := Repl {
		program = make_program(),
		checker = new_checker(),
		vm      = new_vm(),
	}
	defer delete_program(repl.program)
	defer delete_vm(repl.vm)
	defer delete_checker(repl.checker)

	fmt.println("Welcome to the Lily interactive REPL\n-> Type any code..")
	repl_loop: for {
		fmt.print(">")
		at, _ := os.read(os.stdin, buf[buf_ptr:])
		input := string(buf[buf_ptr:buf_ptr + at - 2])
		c := input[len(input) - 1]
		if c == '/' {
			buf[len(input) - 1] = '\n'
			buf_ptr = at - 2
			continue repl_loop
		}
		switch input {
		case "exit":
			break repl_loop
		case "@printast":
			print_ast(repl.program)
		case:
			parse_err := append_to_program(input, repl.program)
			assert(parse_err == nil, fmt.tprint("Error while parsing the program: ", parse_err))
			check_err := check_program(
				repl.checker,
				repl.program.nodes[repl.node_count:len(repl.program.nodes)],
			)
			assert(check_err == nil, fmt.tprint("Error while checking the program: ", check_err))
			run_program(repl.vm, repl.program.nodes[repl.node_count:len(repl.program.nodes)])
			repl.node_count = len(repl.program.nodes)

		}
		buf_ptr = 0
	}
}
