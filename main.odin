package main

import "core:mem"
import "lily:tools"

main :: proc() {
	init_global_temporary_allocator(mem.Megabyte * 10)

	tools.format("samples\\test.lily", context.temp_allocator)
}
