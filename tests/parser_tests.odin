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
		if err != nil {
			testing.fail_now(t, fmt.tprintf("%v", err))
		}
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
		if err != nil {
			testing.fail_now(t, fmt.tprintf("%v", err))
		}
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
		if err != nil {
			testing.fail_now(t, fmt.tprintf("%v", err))
		}
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
		if err != nil {
			testing.fail_now(t, fmt.tprintf("%v", err))
		}
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

check_array_type_expression :: proc(t: ^testing.T, expr: lily.Parsed_Expression, inner: string) {
	using lily

	type_expr, ok := expr.(^Parsed_Array_Type_Expression)
	testing.expect(t, ok, fmt.tprintf("Expected Parsed_Array_Type_Expression, got %v", expr))
	if ok {
		elem, ok := type_expr.elem_type.(^Parsed_Identifier_Expression)
		testing.expect(
			t,
			ok,
			fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", type_expr.elem_type),
		)
		testing.expect(
			t,
			elem.name.text == inner,
			fmt.tprintf("Expected %s as inner type, got %s", inner, elem.name.text),
		)
	}
}

@(test)
test_array_literal :: proc(t: ^testing.T) {
	using lily

	Array_Result :: struct {
		inner: string,
		lit:   bool,
		count: int,
	}

	inputs := [?]string{
		"array of number",
		"array of number[10]",
		"array of bool[]",
		`array of string["hello", "world"]`,
	}
	expected := [?]Array_Result{
		{"number", false, 0},
		{"number", true, 1},
		{"bool", true, 0},
		{"string", true, 2},
	}
	parsed_modules := [len(inputs)]^Parsed_Module{}

	track := mem.Tracking_Allocator{}
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer clean_parser_test(parsed_modules[:], &track)

	for input, i in inputs {
		parsed_modules[i] = make_parsed_module("")
		err := parse_module(input, parsed_modules[i])
		if err != nil {
			testing.fail_now(t, fmt.tprintf("%v", err))
		}
	}

	for i in 0 ..< len(inputs) {
		m := parsed_modules[i]
		e := expected[i]
		testing.expect(
			t,
			len(m.nodes) == 1,
			fmt.tprintf("Failed at %d, Expected %d nodes, Got %d\n%#v\n", i, 1, len(m.nodes), m),
		)
		node := m.nodes[0].(^Parsed_Expression_Statement)
		if e.lit {
			array, ok := node.expr.(^Parsed_Array_Literal_Expression)
			testing.expect(
				t,
				ok,
				fmt.tprintf("Expected Parsed_Array_Literal_Expression, got %v", node.expr),
			)
			check_array_type_expression(t, array.type_expr, e.inner)
			testing.expect(
				t,
				len(array.values) == e.count,
				fmt.tprintf("Expected %d values, got %d", e.count, len(array.values)),
			)
		} else {
			check_array_type_expression(t, node.expr, e.inner)
		}
	}
}

@(test)
test_multiline_array_literal :: proc(t: ^testing.T) {
	using lily

	Array_Result :: struct {
		inner: string,
		lit:   bool,
		count: int,
	}

	inputs := [?]string{
		`array of number[
			10,
			20,
			56,
		]`,
		`array of string[
			"hello", "world",
		]`,
		`array of string[
			"hello", "world",]`,
		`array of string["hello", "world",
		]`,
	}
	expected := [?]Array_Result{
		{"number", true, 3},
		{"string", true, 2},
		{"string", true, 2},
		{"string", true, 2},
	}
	parsed_modules := [len(inputs)]^Parsed_Module{}

	track := mem.Tracking_Allocator{}
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer clean_parser_test(parsed_modules[:], &track)

	for input, i in inputs {
		parsed_modules[i] = make_parsed_module("")
		err := parse_module(input, parsed_modules[i])
		if err != nil {
			testing.fail_now(t, fmt.tprintf("%v", err))
		}
	}

	for i in 0 ..< len(inputs) {
		m := parsed_modules[i]
		e := expected[i]
		testing.expect(
			t,
			len(m.nodes) == 1,
			fmt.tprintf("Failed at %d, Expected %d nodes, Got %d\n%#v\n", i, 1, len(m.nodes), m),
		)
		node := m.nodes[0].(^Parsed_Expression_Statement)
		if e.lit {
			array, ok := node.expr.(^Parsed_Array_Literal_Expression)
			testing.expect(
				t,
				ok,
				fmt.tprintf("Expected Parsed_Array_Literal_Expression, got %v", node.expr),
			)
			check_array_type_expression(t, array.type_expr, e.inner)
			testing.expect(
				t,
				len(array.values) == e.count,
				fmt.tprintf("Expected %d values, got %d", e.count, len(array.values)),
			)
		} else {
			check_array_type_expression(t, node.expr, e.inner)
		}
	}
}

@(test)
test_invalid_array_literal :: proc(t: ^testing.T) {
	using lily

	inputs := [?]string{
		`array of number
		[
			10,
			20,
			56,
		]`,
		`array of string[
			"hello",, "world",
		]`,
		`array of string[,"hello", "world",]`,
	}
	parsed_modules := [len(inputs)]^Parsed_Module{}

	track := mem.Tracking_Allocator{}
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer clean_parser_test(parsed_modules[:], &track)

	for input, i in inputs {
		parsed_modules[i] = make_parsed_module("")
		err := parse_module(input, parsed_modules[i])
		if err == nil {
			clean_parser_test(parsed_modules[:], &track)
			testing.fail_now(t, fmt.tprintf("Unhandled invalid array literal expression: %s\n", input))
		}
	}
}


check_map_type_expression :: proc(t: ^testing.T, expr: lily.Parsed_Expression, k, v: string) {
	using lily

	type_expr, ok := expr.(^Parsed_Map_Type_Expression)
	testing.expect(t, ok, fmt.tprintf("Expected Parsed_Map_Type_Expression, got %v", expr))
	if ok {
		key, k_ok := type_expr.key_type.(^Parsed_Identifier_Expression)
		testing.expect(
			t,
			k_ok,
			fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", type_expr.key_type),
		)
		testing.expect(
			t,
			key.name.text == k,
			fmt.tprintf("Expected %s as inner type, got %s", k, key.name.text),
		)

		value, v_ok := type_expr.value_type.(^Parsed_Identifier_Expression)
		testing.expect(
			t,
			v_ok,
			fmt.tprintf("Expected Parsed_Identifier_Expression, got %v", type_expr.value_type),
		)
		testing.expect(
			t,
			value.name.text == v,
			fmt.tprintf("Expected %s as inner type, got %s", v, value.name.text),
		)
	}
}

@(test)
test_map_literal :: proc(t: ^testing.T) {
	using lily

	Map_Result :: struct {
		key:   string,
		value: string,
		lit:   bool,
		count: int,
	}

	inputs := [?]string{
		`map of (string, number)`,
		`map of (string, number)["hello" = 1, "world" = 2]`,
		`map of (number, bool)[1 = false, 2 = true]`,
		`map of (number, bool)[]`,
		`map of (number, bool)[
			1 = false, 
			2 = true,
		]`,
		`map of (number, bool)[
			1 = false, 
			2 = true]`,
		`map of (number, bool)[
			1 = false, 
			2 = true,]`,
	}
	expected := [?]Map_Result{
		{"string", "number", false, 0},
		{"string", "number", true, 2},
		{"number", "bool", true, 2},
		{"number", "bool", true, 0},
		{"number", "bool", true, 2},
		{"number", "bool", true, 2},
		{"number", "bool", true, 2},
	}
	parsed_modules := [len(inputs)]^Parsed_Module{}

	track := mem.Tracking_Allocator{}
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer clean_parser_test(parsed_modules[:], &track)

	for input, i in inputs {
		parsed_modules[i] = make_parsed_module("")
		err := parse_module(input, parsed_modules[i])
		if err != nil {
			testing.fail_now(t, fmt.tprintf("%v", err))
		}
	}

	for i in 0 ..< len(inputs) {
		m := parsed_modules[i]
		e := expected[i]
		testing.expect(
			t,
			len(m.nodes) == 1,
			fmt.tprintf("Failed at %d, Expected %d nodes, Got %d\n%#v\n", i, 1, len(m.nodes), m),
		)
		node := m.nodes[0].(^Parsed_Expression_Statement)
		if e.lit {
			map_lit, ok := node.expr.(^Parsed_Map_Literal_Expression)
			testing.expect(
				t,
				ok,
				fmt.tprintf("Expected Parsed_Map_Literal_Expression, got %v", node.expr),
			)
			check_map_type_expression(t, map_lit.type_expr, e.key, e.value)
			testing.expect(
				t,
				len(map_lit.elements) == e.count,
				fmt.tprintf("Expected %d values, got %d", e.count, len(map_lit.elements)),
			)
		} else {
			check_map_type_expression(t, node.expr, e.key, e.value)
		}
	}
}
