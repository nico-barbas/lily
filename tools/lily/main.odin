package standalone

import "core:fmt"
import "core:os"
import "core:mem"
import "core:strings"
import "lily:lib"

main :: proc() {
	if len(os.args) < 2 {
		fmt.println("Invalid use: lily [filename] [options]")
		fmt.println("lily -help to learn more about the compiler options")
		return
	}
	init_global_temporary_allocator(mem.Megabyte * 20)

	file_path := os.args[1]
	builder := strings.builder_make(200, context.temp_allocator)
	writing := false
	for i := len(file_path) - 1; i >= 0; i -= 1 {
		if writing {
			if file_path[i] == '/' {
				break
			}
			strings.write_byte(&builder, file_path[i])
		} else {
			if file_path[i] == '.' {
				writing = true
			}
		}
	}
	module_name := strings.reverse(strings.to_string(builder), context.temp_allocator)


	buf := make([]byte, mem.Megabyte * 20)
	compiler_arena: mem.Arena
	mem.init_arena(&compiler_arena, buf)
	compiler_allocator := mem.arena_allocator(&compiler_arena)


	state := lib.new_state(
		lib.Config{
			allocator = compiler_allocator,
			temp_allocator = context.temp_allocator,
		},
	)
	defer {
		lib.free_state(state)
		free_all(compiler_allocator)
		delete(buf)
	}
	errors := lib.compile_file(state, file_path)
	if len(errors) > 0 {
		for err in errors {
			fmt.println(err)
		}
		return
	}

	lib.run_module(state, module_name)
}
