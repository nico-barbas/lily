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

check_node_kind :: proc(t: ^testing.T, node: lily.Parsed_Node, l: []string) -> int {
	using lily

	k := l[0]
	read_count := 1
	switch k {
	case "expr":
		_, ok := node.(^Parsed_Expression_Statement)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Expression_Statement, got %v", node))

	case "ass":
		_, ok := node.(^Parsed_Assignment_Statement)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Assignment_Statement, got %v", node))

	case "if":
		n, ok := node.(^Parsed_If_Statement)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_If_Statement, got %v", node))
		remain := l[1:]
		for inner, i in n.body.nodes {
			read := check_node_kind(t, inner, remain)
			remain = remain[read:]
			read_count += read
		}

	case "match":
		n, ok := node.(^Parsed_Match_Statement)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Match_Statement, got %v", node))
		remain := l[1:]
		for c in n.cases {
			for inner in c.body.nodes {
				read := check_node_kind(t, inner, remain)
				remain = remain[read:]
				read_count += read
			}
		}

	case "flow":
		_, ok := node.(^Parsed_Flow_Statement)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Flow_Statement, got %v", node))

	case "for":
		n, ok := node.(^Parsed_Range_Statement)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Range_Statement, got %v", node))
		remain := l[1:]
		for inner, i in n.body.nodes {
			read := check_node_kind(t, inner, remain)
			remain = remain[read:]
			read_count += read
		}

	case "imp":
		_, ok := node.(^Parsed_Import_Statement)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Import_Statement, got %v", node))

	case "var":
		_, ok := node.(^Parsed_Var_Declaration)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Var_Declaration, got %v", node))

	case "fn":
		_, ok := node.(^Parsed_Fn_Declaration)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Fn_Declaration, got %v", node))

	case "type":
		_, ok := node.(^Parsed_Type_Declaration)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Type_Declaration, got %v", node))
	}
	return read_count
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
