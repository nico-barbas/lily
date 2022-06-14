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
		"myVar",
		`"string literal"`,
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
		node := m.nodes[0].(^Parsed_Expression_Statement)
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
		node := m.nodes[0].(^Parsed_Expression_Statement)
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
	// Binary plus
	{
		m := parsed_modules[2]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		bin_expr, ok := node.expr.(^Binary_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Binary_Expression, got %v", node.expr))
		if ok {
			left_expr, left_ok := bin_expr.left.(^Literal_Expression)
			right_expr, right_ok := bin_expr.right.(^Literal_Expression)
			testing.expect(t, left_ok, fmt.tprintf("Expected Literal_Expression, got %v", bin_expr.left))
			testing.expect(t, right_ok, fmt.tprintf("Expected Literal_Expression, got %v", bin_expr.right))
			testing.expect(t, bin_expr.op == .Plus_Op, fmt.tprintf("Expected Plus_Op, got %v", bin_expr.op))
		}
	}
	
    // Identifier
	{
		m := parsed_modules[3]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		id_expr, ok := node.expr.(^Identifier_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Call_Expression, got %v", node.expr))
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
        m := parsed_modules[4]
        testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		id_expr, ok := node.expr.(^String_Literal_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Call_Expression, got %v", node.expr))
    }
}

@(test)
test_call_and_access_expressions :: proc(t: ^testing.T) {
    using lily
    inputs := [?]string{
        "call()",
        "call(1, true)",
        "call1(call2())",
		"myVar.x",
		"myVar.call()",
    }

    parsed_modules := [len(inputs)]^Parsed_Module{}

	for input, i in inputs {
		parsed_modules[i] = make_module()
		err := parse_module(input, parsed_modules[i])
	}
	defer for module in parsed_modules {
		delete_module(module)
	}

    // Call
	{
		m := parsed_modules[0]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		call_expr, ok := node.expr.(^Call_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Call_Expression, got %v", node.expr))
		if ok {
			identifier, ok := call_expr.func.(^Identifier_Expression)
			testing.expect(t, ok, fmt.tprintf("Expected Identifier_Expression, got %v", call_expr.func))
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
		call_expr, ok := node.expr.(^Call_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Call_Expression, got %v", node.expr))
		if ok {
			identifier, ok := call_expr.func.(^Identifier_Expression)
			testing.expect(t, ok, fmt.tprintf("Expected Identifier_Expression, got %v", call_expr.func))
			testing.expect(
				t,
				len(call_expr.args) == 2,
				fmt.tprintf("Expected no arguments, got %d", len(call_expr.args)),
			)
            arg0, arg_ok0 := call_expr.args[0].(^Literal_Expression)
            testing.expect(t, arg_ok0, fmt.tprintf("Expected Identifier_Expression, got %v", call_expr.args[0]))
            arg1, arg_ok1 := call_expr.args[1].(^Literal_Expression)
            testing.expect(t, arg_ok1, fmt.tprintf("Expected Identifier_Expression, got %v", call_expr.args[1]))
		}
	}
    // Nested calls
	{
		m := parsed_modules[2]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		call_expr, ok := node.expr.(^Call_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Call_Expression, got %v", node.expr))
		if ok {
			identifier, ok := call_expr.func.(^Identifier_Expression)
			testing.expect(t, ok, fmt.tprintf("Expected Identifier_Expression, got %v", call_expr.func))
			testing.expect(
				t,
				len(call_expr.args) == 1,
				fmt.tprintf("Expected no arguments, got %d", len(call_expr.args)),
			)
            nested_call, nested_ok := call_expr.args[0].(^Call_Expression)
            testing.expect(t, nested_ok, fmt.tprintf("Expected Identifier_Expression, got %v", call_expr.args[0]))
            if nested_ok {
                identifier, ok := nested_call.func.(^Identifier_Expression)
			    testing.expect(t, ok, fmt.tprintf("Expected Identifier_Expression, got %v", nested_call.func))
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
		dot_expr, ok := node.expr.(^Dot_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Call_Expression, got %v", node.expr))
		if ok {
			left, left_ok := dot_expr.left.(^Identifier_Expression)
			testing.expect(t, left_ok, fmt.tprintf("Expected Identifier_Expression, got %v", dot_expr.left))
            accessor, acc_ok := dot_expr.accessor.(^Identifier_Expression)
			testing.expect(t, acc_ok, fmt.tprintf("Expected Identifier_Expression, got %v", dot_expr.left))
		}
	}
    // Dot expression (accessing methods)
	{
		m := parsed_modules[4]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		dot_expr, ok := node.expr.(^Dot_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Call_Expression, got %v", node.expr))
		if ok {
			left, left_ok := dot_expr.left.(^Identifier_Expression)
			testing.expect(t, left_ok, fmt.tprintf("Expected Identifier_Expression, got %v", dot_expr.left))
            call_expr, call_ok := dot_expr.accessor.(^Call_Expression)
			testing.expect(t, call_ok, fmt.tprintf("Expected Call_Expression, got %v", dot_expr.left))
            if call_ok {
                identifier, id_ok := call_expr.func.(^Identifier_Expression)
			    testing.expect(t, id_ok, fmt.tprintf("Expected Identifier_Expression, got %v", call_expr.func))
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
    inputs := [?]string{
        "array of number",
		"array of number[10]",
    }

    parsed_modules := [len(inputs)]^Parsed_Module{}

	for input, i in inputs {
		parsed_modules[i] = make_module()
		err := parse_module(input, parsed_modules[i])
	}
	defer for module in parsed_modules {
		delete_module(module)
	}
    
    // Empty Array type expression 
    {
        m := parsed_modules[0]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		arr_expr, ok := node.expr.(^Array_Type_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Call_Expression, got %v", node.expr))
		if ok {
			elem, ok :=  arr_expr.elem_type.(^Identifier_Expression)
            testing.expect(t, ok, fmt.tprintf("Expected Identifier_Expression, got %v", arr_expr.elem_type))
		}
    }

    // Array literal expression
    {
        m := parsed_modules[1]
		testing.expect(t, len(m.nodes) == 1, fmt.tprint("Failed, Expected", 1, "Got", len(m.nodes)))
		node := m.nodes[0].(^Parsed_Expression_Statement)
		arr_expr, ok := node.expr.(^Array_Literal_Expression)
		testing.expect(t, ok, fmt.tprintf("Expected Array_Literal_Expression, got %v", node.expr))
		if ok {
			type_expr, type_ok :=  arr_expr.type_expr.(^Array_Type_Expression)
            testing.expect(t, ok, fmt.tprintf("Expected Array_Type_Expression, got %v", arr_expr.type_expr))
            if type_ok {
                elem, ok :=  type_expr.elem_type.(^Identifier_Expression)
                testing.expect(t, ok, fmt.tprintf("Expected Identifier_Expression, got %v", type_expr.elem_type))
            }
            testing.expect(
                t, 
                len(arr_expr.values) == 1, 
                fmt.tprintf("Expected no arguments, got %d", len(arr_expr.values)),
            )
            val, val_ok := arr_expr.values[0].(^Literal_Expression)
            testing.expect(t, val_ok, fmt.tprintf("Expected Identifier_Expression, got %v", arr_expr.values[0]))
		}
    }
}