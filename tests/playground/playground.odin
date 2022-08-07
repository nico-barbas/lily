package playground

import "core:fmt"
import "core:mem"
import lily "../lib"

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
	using lily

	// input: string = `
	// 	type Foo is class
	// 		x: number

	// 		constructor new(_x: number):
	// 			self.x = _x
	// 		end

	// 		fn add(n: number):
	// 			self.x = self.x + n
	// 		end
	// 	end

	//     var a = Foo.new(1)
	// 	a.add(13)
	// `
	input := `
	var a = map of (string, number)[]

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

	state := new_state(
		Config{allocator = compiler_allocator, temp_allocator = context.temp_allocator},
	)
	err := compile_source(state, "main", input)
	assert(err == nil, fmt.tprint(err))

	run_module(state, "main")
	// update_handle, handle_err := make_fn_handle(state, "main", "update")
	// assert(handle_err == nil)
	// call(state, update_handle)
	free_state(state)
	fmt.println("finished")
}
