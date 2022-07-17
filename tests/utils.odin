package tests

import "core:fmt"
import "core:mem"
import "core:testing"
import lily "../src"

@(private)
check_expr_kind :: proc(t: ^testing.T, expr: lily.Parsed_Expression, kind: string) {
	using lily

	switch kind {
	case "lit":
		e, ok := expr.(^Parsed_Literal_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Literal_Expression, got %v", expr))

	case "str":
		e, ok := expr.(^Parsed_String_Literal_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_String_Literal_Expression, got %v", expr))

	case "arr":
		e, ok := expr.(^Parsed_Array_Literal_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Array_Literal_Expression, got %v", expr))

	case "map":
		e, ok := expr.(^Parsed_Map_Literal_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Map_Literal_Expression, got %v", expr))

	case "unary":
		e, ok := expr.(^Parsed_Unary_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Unary_Expression, got %v", expr))

	case "binary":
		e, ok := expr.(^Parsed_Binary_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Binary_Expression, got %v", expr))

	case "ident":
		e, ok := expr.(^Parsed_Identifier_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", expr))

	case "index":
		e, ok := expr.(^Parsed_Index_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Index_Expression, got %v", expr))

	case "dot":
		e, ok := expr.(^Parsed_Dot_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Dot_Expression, got %v", expr))

	case "call":
		e, ok := expr.(^Parsed_Call_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Call_Expression, got %v", expr))
	}
}

check_node_kind :: proc(t: ^testing.T, node: lily.Parsed_Node, k: string) {

}

print_mem_leaks :: proc(track: ^mem.Tracking_Allocator) {
	if len(track.allocation_map) > 0 {
		fmt.printf("Leaks:")
		for _, v in track.allocation_map {
			fmt.printf("\t%v\n\n", v)
		}
		fmt.printf("Leak count: %d\n", len(track.allocation_map))
	}
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
