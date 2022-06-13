package tests

import "core:fmt"
import "core:testing"
import lily "../src"

@(test)
test_expressions :: proc(t: ^testing.T) {using lily
	inputs := [?]string{
		"not true",
		"-3",
		"10 + 2",
		"call()",
		"myVar",
		"myVar.x",
		"myVar.call()",
		`"string literal"`,
		"array of number",
		"array of number(10, 2, 3, 4)",
	}
	parsed_modules := [len(inputs)]^Parsed_Module{}

	for input, i in inputs {
		parsed_modules[i] = make_module()
		err := parse_module(input, parsed_modules[i])
	}
	defer for module in parsed_modules {
		delete_module(module)
	}

	// Unary not
	{
		m := parsed_modules[0]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Expression_Statement)
		unary_expr, ok := node.expr.(^Unary_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Unary Expression, got %v", node.expr))
		if ok {
			lit_expr, ok := unary_expr.expr.(^Literal_Expression)
			testing.expect(t, ok, fmt.tprintf("Expected Literal Expression, got %v", unary_expr.expr))
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
		node := m.nodes[0].(^Expression_Statement)
		unary_expr, ok := node.expr.(^Unary_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Unary Expression, got %v", node.expr))
		if ok {
			lit_expr, ok := unary_expr.expr.(^Literal_Expression)
			testing.expect(t, ok, fmt.tprintf("Expected Literal Expression, got %v", unary_expr.expr))
			testing.expect(
				t,
				unary_expr.op == .Minus_Op,
				fmt.tprintf("Expected Minus_Op, got %v", unary_expr.op),
			)
		}
	}
}
