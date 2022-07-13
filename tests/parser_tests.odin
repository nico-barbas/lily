package tests

import "core:fmt"
import "core:mem"
import "core:testing"
import lily "../src"

@(test)
test_literal_expressions :: proc(t: ^testing.T) {
	using lily

	inputs := [?]string{"not true", "-3", "myVar", `"string literal"`}
	parsed_modules := [len(inputs)]^Parsed_Module{}

	track := mem.Tracking_Allocator{}
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer clean_parser_test(parsed_modules[:], &track)

	for input, i in inputs {
		parsed_modules[i] = make_parsed_module("")
		err := parse_module(input, parsed_modules[i])
		testing.expect(t, err == nil, fmt.tprintf("Parsing error: %v", err))
	}

	// Unary not
	{
		m := parsed_modules[0]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		unary_expr, ok := node.expr.(^Parsed_Unary_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Unary Parsed_Expression, got %v", node.expr))
		if ok {
			lit_expr, ok := unary_expr.expr.(^Parsed_Literal_Expression)
			testing.expect(
				t,
				ok,
				fmt.tprintf("Expected Literal Parsed_Expression, got %v", unary_expr.expr),
			)
			testing.expect(
				t,
				unary_expr.op == .Not_Op,
				fmt.tprintf("Expected Not_Op, got %v", unary_expr.op),
			)
		}
	}
	// Unary minus
	{
		m := parsed_modules[1]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		unary_expr, ok := node.expr.(^Parsed_Unary_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Unary Parsed_Expression, got %v", node.expr))
		if ok {
			lit_expr, ok := unary_expr.expr.(^Parsed_Literal_Expression)
			testing.expect(
				t,
				ok,
				fmt.tprintf("Expected Literal Parsed_Expression, got %v", unary_expr.expr),
			)
			testing.expect(
				t,
				unary_expr.op == .Minus_Op,
				fmt.tprintf("Expected Minus_Op, got %v", unary_expr.op),
			)
		}
	}

	// Identifier
	{
		m := parsed_modules[2]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		id_expr, ok := node.expr.(^Parsed_Identifier_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Call_Expression, got %v", node.expr))
		if ok {
			testing.expect(
				t,
				id_expr.name.text == "myVar",
				fmt.tprintf("Expected variable name myVar, got %s", id_expr.name.text),
			)
		}
	}
	// String Literal 
	{
		m := parsed_modules[3]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		id_expr, ok := node.expr.(^Parsed_String_Literal_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Call_Expression, got %v", node.expr))
	}
}

@(test)
test_binary_expressions :: proc(t: ^testing.T) {
	using lily

	check_simple_binary_results :: proc(t: ^testing.T, m: ^lily.Parsed_Module, op: lily.Operator) {
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		bin_expr, ok := node.expr.(^Parsed_Binary_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Binary_Expression, got %v", node.expr))
		if ok {
			left_expr, left_ok := bin_expr.left.(^Parsed_Literal_Expression)
			right_expr, right_ok := bin_expr.right.(^Parsed_Literal_Expression)
			testing.expect(
				t,
				left_ok,
				fmt.tprintf("Expected Parsed_Literal_Expression, got %v", bin_expr.left),
			)
			testing.expect(
				t,
				right_ok,
				fmt.tprintf("Expected Parsed_Literal_Expression, got %v", bin_expr.right),
			)
			testing.expect(t, bin_expr.op == op, fmt.tprintf("Expected Plus_Op, got %v", bin_expr.op))
		}
	}

	inputs := [?]string{
		"10 + 2",
		"2 - 3",
		"2 * 3",
		"2 / 3",
		"2 % 3",
		"2 == 3",
		" 2 > 3",
		"2 >= 3",
		"2 < 3",
		"2 <= 3",
		"true and false",
		"true or false",
	}
	expected_operators := [?]Operator{
		.Plus_Op,
		.Minus_Op,
		.Mult_Op,
		.Div_Op,
		.Rem_Op,
		.Equal_Op,
		.Greater_Op,
		.Greater_Eq_Op,
		.Lesser_Op,
		.Lesser_Eq_Op,
		.And_Op,
		.Or_Op,
	}
	parsed_modules := [len(inputs)]^Parsed_Module{}

	track := mem.Tracking_Allocator{}
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer clean_parser_test(parsed_modules[:], &track)

	for input, i in inputs {
		parsed_modules[i] = make_parsed_module("")
		err := parse_module(input, parsed_modules[i])
		testing.expect(t, err == nil, fmt.tprintf("Parsing error: %v", err))
	}

	for i in 0 ..< len(inputs) {
		check_simple_binary_results(t, parsed_modules[i], expected_operators[i])
	}
}

@(test)
test_binary_precedence :: proc(t: ^testing.T) {
	using lily

	Binary_Result :: struct {
		kind:  string,
		left:  string,
		right: string,
		op:    lily.Operator,
	}

	check_nested_binary_results :: proc(t: ^testing.T, m: ^lily.Parsed_Module, e: [2]Binary_Result) {
		using lily
		check_binary_results :: proc(t: ^testing.T, b: ^Parsed_Binary_Expression, e: Binary_Result) {
			if e.kind == "left" {
				left_expr, left_ok := b.left.(^Parsed_Binary_Expression)
				testing.expect(
					t,
					left_ok,
					fmt.tprintf("Expected Parsed_Binary_Expression, got %v", b.left),
				)
				right_expr, right_ok := b.right.(^Parsed_Literal_Expression)
				testing.expect(
					t,
					right_ok,
					fmt.tprintf("Expected Parsed_Literal_Expression, got %v", b.right),
				)
				testing.expect(
					t,
					right_expr.token.text == e.right,
					fmt.tprintf("Expected %s, got %s", e.right, right_expr.token.text),
				)
			} else if e.kind == "right" {
				_, right_ok := b.right.(^Parsed_Binary_Expression)
				testing.expect(
					t,
					right_ok,
					fmt.tprintf("Expected Parsed_Binary_Expression, got %v", b.right),
				)
				left_expr, left_ok := b.left.(^Parsed_Literal_Expression)
				testing.expect(
					t,
					left_ok,
					fmt.tprintf("Expected Parsed_Literal_Expression, got %v", b.left),
				)
				testing.expect(
					t,
					left_expr.token.text == e.left,
					fmt.tprintf("Expected %s, got %s", e.left, left_expr.token.text),
				)
			} else if e.kind == "simple" {
				left_expr, left_ok := b.left.(^Parsed_Literal_Expression)
				testing.expect(
					t,
					left_ok,
					fmt.tprintf("Expected Parsed_Literal_Expression, got %v", b.left),
				)
				testing.expect(
					t,
					left_expr.token.text == e.left,
					fmt.tprintf("Expected %s, got %s", e.left, left_expr.token.text),
				)
				right_expr, right_ok := b.right.(^Parsed_Literal_Expression)
				testing.expect(
					t,
					right_ok,
					fmt.tprintf("Expected Parsed_Literal_Expression, got %v", b.right),
				)
				testing.expect(
					t,
					right_expr.token.text == e.right,
					fmt.tprintf("Expected %s, got %s", e.right, right_expr.token.text),
				)
			}
			testing.expect(t, b.op == e.op, fmt.tprintf("Expected Plus_Op, got %v", b.op))
		}
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		bin_expr, ok := node.expr.(^Parsed_Binary_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Binary_Expression, got %v", node.expr))
		if ok {
			if e[0].kind == "right" {
				check_binary_results(t, bin_expr.right.(^Parsed_Binary_Expression), e[1])
				check_binary_results(t, bin_expr, e[0])
			}
			if e[1].kind == "left" {
				check_binary_results(t, bin_expr.left.(^Parsed_Binary_Expression), e[0])
				check_binary_results(t, bin_expr, e[1])
			}
		}
	}

	inputs := [?]string{
		"(1 + 2) * 3",
		"(1 + 2) / 3",
		"(1 + 2) % 3",
		"(1 + 2) == 3",
		"(1 + 2) > 3",
		"(1 + 2) >= 3",
		"(1 + 2) < 3",
		"(1 + 2) <= 3",
		"3 * (1 + 3)",
		"3 / (1 + 3)",
	}
	expected := [?][2]Binary_Result{
		{{"simple", "1", "2", .Plus_Op}, {"left", "(1 + 2)", "3", .Mult_Op}},
		{{"simple", "1", "2", .Plus_Op}, {"left", "(1 + 2)", "3", .Div_Op}},
		{{"simple", "1", "2", .Plus_Op}, {"left", "(1 + 2)", "3", .Rem_Op}},
		{{"simple", "1", "2", .Plus_Op}, {"left", "(1 + 2)", "3", .Equal_Op}},
		{{"simple", "1", "2", .Plus_Op}, {"left", "(1 + 2)", "3", .Greater_Op}},
		{{"simple", "1", "2", .Plus_Op}, {"left", "(1 + 2)", "3", .Greater_Eq_Op}},
		{{"simple", "1", "2", .Plus_Op}, {"left", "(1 + 2)", "3", .Lesser_Op}},
		{{"simple", "1", "2", .Plus_Op}, {"left", "(1 + 2)", "3", .Lesser_Eq_Op}},
		{{"right", "3", "(1 + 3)", .Mult_Op}, {"simple", "1", "3", .Plus_Op}},
		{{"right", "3", "(1 + 3)", .Div_Op}, {"simple", "1", "3", .Plus_Op}},
	}
	parsed_modules := [len(inputs)]^Parsed_Module{}

	track := mem.Tracking_Allocator{}
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer clean_parser_test(parsed_modules[:], &track)

	for input, i in inputs {
		parsed_modules[i] = make_parsed_module("")
		err := parse_module(input, parsed_modules[i])
		testing.expect(t, err == nil, fmt.tprintf("Parsing error: %v", err))
	}

	for i in 0 ..< len(inputs) {
		check_nested_binary_results(t, parsed_modules[i], expected[i])
	}
}

@(test)
test_call_and_access_expressions :: proc(t: ^testing.T) {
	using lily

	inputs := [?]string{"call()", "call(1, true)", "call1(call2())", "myVar.x", "myVar.call()"}
	parsed_modules := [len(inputs)]^Parsed_Module{}

	track := mem.Tracking_Allocator{}
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer clean_parser_test(parsed_modules[:], &track)

	for input, i in inputs {
		parsed_modules[i] = make_parsed_module("")
		err := parse_module(input, parsed_modules[i])
	}

	// Call
	{
		m := parsed_modules[0]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		call_expr, ok := node.expr.(^Parsed_Call_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Call_Expression, got %v", node.expr))
		if ok {
			identifier, ok := call_expr.func.(^Parsed_Identifier_Expression)
			testing.expect(
				t,
				ok,
				fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", call_expr.func),
			)
			testing.expect(
				t,
				len(call_expr.args) == 0,
				fmt.tprintf("Expected no arguments, got %d", len(call_expr.args)),
			)
		}
	}
	// Call (with parameters)
	{
		m := parsed_modules[1]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		call_expr, ok := node.expr.(^Parsed_Call_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Call_Expression, got %v", node.expr))
		if ok {
			identifier, ok := call_expr.func.(^Parsed_Identifier_Expression)
			testing.expect(
				t,
				ok,
				fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", call_expr.func),
			)
			testing.expect(
				t,
				len(call_expr.args) == 2,
				fmt.tprintf("Expected no arguments, got %d", len(call_expr.args)),
			)
			arg0, arg_ok0 := call_expr.args[0].(^Parsed_Literal_Expression)
			testing.expect(
				t,
				arg_ok0,
				fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", call_expr.args[0]),
			)
			arg1, arg_ok1 := call_expr.args[1].(^Parsed_Literal_Expression)
			testing.expect(
				t,
				arg_ok1,
				fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", call_expr.args[1]),
			)
		}
	}
	// Nested calls
	{
		m := parsed_modules[2]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		call_expr, ok := node.expr.(^Parsed_Call_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Call_Expression, got %v", node.expr))
		if ok {
			identifier, ok := call_expr.func.(^Parsed_Identifier_Expression)
			testing.expect(
				t,
				ok,
				fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", call_expr.func),
			)
			testing.expect(
				t,
				len(call_expr.args) == 1,
				fmt.tprintf("Expected no arguments, got %d", len(call_expr.args)),
			)
			nested_call, nested_ok := call_expr.args[0].(^Parsed_Call_Expression)
			testing.expect(
				t,
				nested_ok,
				fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", call_expr.args[0]),
			)
			if nested_ok {
				identifier, ok := nested_call.func.(^Parsed_Identifier_Expression)
				testing.expect(
					t,
					ok,
					fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", nested_call.func),
				)
				testing.expect(
					t,
					len(nested_call.args) == 0,
					fmt.tprintf("Expected no arguments, got %d", len(nested_call.args)),
				)
			}
		}
	}
	// Dot expression (accessing fields)
	{
		m := parsed_modules[3]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		dot_expr, ok := node.expr.(^Parsed_Dot_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Call_Expression, got %v", node.expr))
		if ok {
			left, left_ok := dot_expr.left.(^Parsed_Identifier_Expression)
			testing.expect(
				t,
				left_ok,
				fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", dot_expr.left),
			)
			accessor, acc_ok := dot_expr.selector.(^Parsed_Identifier_Expression)
			testing.expect(
				t,
				acc_ok,
				fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", dot_expr.left),
			)
		}
	}
	// Dot expression (accessing methods)
	{
		m := parsed_modules[4]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		dot_expr, ok := node.expr.(^Parsed_Dot_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Call_Expression, got %v", node.expr))
		if ok {
			left, left_ok := dot_expr.left.(^Parsed_Identifier_Expression)
			testing.expect(
				t,
				left_ok,
				fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", dot_expr.left),
			)
			call_expr, call_ok := dot_expr.selector.(^Parsed_Call_Expression)
			testing.expect(
				t,
				call_ok,
				fmt.tprintf("Expected Parsed_Call_Expression, got %v", dot_expr.left),
			)
			if call_ok {
				identifier, id_ok := call_expr.func.(^Parsed_Identifier_Expression)
				testing.expect(
					t,
					id_ok,
					fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", call_expr.func),
				)
				testing.expect(
					t,
					len(call_expr.args) == 0,
					fmt.tprintf("Expected no arguments, got %d", len(call_expr.args)),
				)
			}
		}
	}
}

@(test)
test_array_expressions :: proc(t: ^testing.T) {
	using lily

	inputs := [?]string{"array of number", "array of number[10]"}
	parsed_modules := [len(inputs)]^Parsed_Module{}

	track := mem.Tracking_Allocator{}
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer clean_parser_test(parsed_modules[:], &track)

	for input, i in inputs {
		parsed_modules[i] = make_parsed_module("")
		err := parse_module(input, parsed_modules[i])
	}

	// Empty Array type expression 
	{
		m := parsed_modules[0]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		arr_expr, ok := node.expr.(^Parsed_Array_Type_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Call_Expression, got %v", node.expr))
		if ok {
			elem, ok := arr_expr.elem_type.(^Parsed_Identifier_Expression)
			testing.expect(
				t,
				ok,
				fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", arr_expr.elem_type),
			)
		}
	}

	// Array literal expression
	{
		m := parsed_modules[1]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		arr_expr, ok := node.expr.(^Parsed_Array_Literal_Expression)
		testing.expect(
			t,
			ok,
			fmt.tprintf("Expected Parsed_Array_Literal_Expression, got %v", node.expr),
		)
		if ok {
			type_expr, type_ok := arr_expr.type_expr.(^Parsed_Array_Type_Expression)
			testing.expect(
				t,
				ok,
				fmt.tprintf("Expected Parsed_Array_Type_Expression, got %v", arr_expr.type_expr),
			)
			if type_ok {
				elem, ok := type_expr.elem_type.(^Parsed_Identifier_Expression)
				testing.expect(
					t,
					ok,
					fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", type_expr.elem_type),
				)
			}
			testing.expect(
				t,
				len(arr_expr.values) == 1,
				fmt.tprintf("Expected no arguments, got %d", len(arr_expr.values)),
			)
			val, val_ok := arr_expr.values[0].(^Parsed_Literal_Expression)
			testing.expect(
				t,
				val_ok,
				fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", arr_expr.values[0]),
			)
		}
	}
}
