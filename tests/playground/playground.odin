package playground

import "core:fmt"
import "core:mem"
import "lily:lib"

main :: proc() {
	track := mem.Tracking_Allocator{}
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	playground()

	if len(track.allocation_map) > 0 {
		fmt.printf("Leaks:")
		for _, v in track.allocation_map {
			fmt.printf("\t%v\n\n", v)
		}
	}
	fmt.printf("Leak count: %d\n", len(track.allocation_map))
	if len(track.bad_free_array) > 0 {
		fmt.printf("Bad Frees:")
		for v in track.bad_free_array {
			fmt.printf("\t%v\n\n", v)
		}
	}
}

playground :: proc() {
	using lib
	input :: `
	import std

	type Foo is class
		constructor new():
		end
	end

	var a: Foo
	std.print(a)
	if a == nil:
		std.print("is nil")
		var a  = Foo.new()
	end
	`

	init_global_temporary_allocator(mem.Megabyte * 20)

	buf := make([]byte, mem.Megabyte * 20)
	compiler_arena: mem.Arena
	mem.init_arena(&compiler_arena, buf)
	compiler_allocator := mem.arena_allocator(&compiler_arena)
	defer {
		free_all(compiler_allocator)
		delete(buf)
	}

	state := new_state(Config{allocator = compiler_allocator, temp_allocator = context.temp_allocator})
	errors := compile_source(state, "main", input)
	if len(errors) > 0 {
		for err in errors {
			fmt.println(err)
		}
		return
	}

	run_module(state, "main")
	free_state(state)
	fmt.println("finished")
}
