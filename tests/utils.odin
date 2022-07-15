package tests

import "core:fmt"
import "core:mem"
import lily "../src"

print_mem_leaks :: proc(track: ^mem.Tracking_Allocator) {
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

clean_parser_test :: proc(modules: []^lily.Parsed_Module, track: ^mem.Tracking_Allocator) {
	for module in modules {
		lily.delete_parsed_module(module)
	}
	print_mem_leaks(track)
}
