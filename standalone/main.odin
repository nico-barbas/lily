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

	parsed_module := make_parsed_module()
	parse_err := parse_module(string(input), parsed_module)
	defer delete_parsed_module(parsed_module)
	if parse_err != nil {
		fmt.tprint(parse_err)
		return
	}

	checker := new_checker()
	checked_module, check_err := check_module(checker, parsed_module)
	defer free_checker(checker)
	defer delete_checked_module(checked_module)
	if check_err != nil {
		fmt.tprint(check_err)
		return
	}

	compiler := new_compiler()
	compiled_module := compile_module(compiler, checked_module)
	defer free_compiler(compiler)
	defer delete_compiled_module(compiled_module)
	vm := Vm{}
	run_module(&vm, compiled_module)

	// when PRINT_AST {
	// 	print_parsed_ast(parsed_module)
	// 	print_checked_ast(checked_module, checker)
	// }
	// when PRINT_SYMBOL_TABLE {
	// 	print_symbol_table(checker, checked_module)
	// }


	// when PRINT_COMPILE {
	// 	print_compiled_module(compiled_module)
	// 	fmt.println("== END COMPILED MODULE ==")
	// }
	// when PRINT_VM_STATE {
	// 	fmt.println("RESULT:")
	// 	fmt.println(vm.chunk.variables)
	// }

}
