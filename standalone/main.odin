package standalone

import "core:fmt"
import "core:os"
import lily "../src"

main :: proc() {
	using lily
	if len(os.args) < 2 {
		fmt.println("Invalid use: lily [filename] [options]")
		fmt.println("lily -help to learn more about the compiler options")
		return
	}

	file_name := os.args[1]
	input, read_ok := os.read_entire_file(file_name)
	if !read_ok {
		fmt.println("[LILY]: Invalid file name")
	}

	checker := Checker{}
	init_checker(&checker)
	checked, err := build_checked_program(&checker, "main", string(input))
	if err != nil {
		fmt.println(error_message(err))
	}

	compiled_program := make_compiled_program(checked)
	for i in 0 ..< len(compiled_program) {
		compile_module(checked, compiled_program, i)
	}
	run_program(compiled_program, 0)
}
