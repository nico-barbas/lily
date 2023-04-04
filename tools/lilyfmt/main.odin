package main

import "core:mem"
import "core:os"
// import "core:fmt"
import tools ".."

LILYFMT_USAGE_INFO :: `
lilyfmt is a formatting tool for Lily source files
Usage: lilyfmt [filepath]`

main :: proc() {
	init_global_temporary_allocator(mem.Megabyte * 10)

	if len(os.args) == 1 {
		fmt.println(LILYFMT_USAGE_INFO)
		return
	}
	err := tools.format_file(os.args[1], context.temp_allocator)
	if err != nil {
		fmt.printf("ERROR: %s\n", err)
	}
}
