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

	state := new_state(Config{})
	err := compile_source(state, "main", string(input))
	assert(err == nil, fmt.tprint(err))

	run_module(state, "main")
	fmt.println("finished")
}
