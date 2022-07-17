package tests

import "core:fmt"
import "core:mem"
import "core:testing"
import lily "../src"

@(test)
test_assign_statement :: proc(t: ^testing.T) {
	using lily

	Assign_Result :: struct {
		left:  string,
		right: string,
	}

	inputs := [?]string{"foo = 10", "foo[0] = 10", "foo.bar = 10"}
	expected := [?]Assign_Result{{"ident", "number"}, {"index", "number"}, {"dot", "number"}}
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
			fmt.tprintf("Failed at %d, Expected %d nodes, Got %d\n%#v\n", i, len(m.nodes), i, m),
		)
		node, ok := m.nodes[0].(^Parsed_Assignment_Statement)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Assignment_Statement, got %v", node))

		check_expr_type(t, node.left, e.left)
		check_expr_type(t, node.right, e.right)
	}
}

@(test)
test_if_statement :: proc(t: ^testing.T) {
	using lily

	If_Result :: struct {
		branches:    int,
		kind:        string,
		node_counts: []int,
	}

	inputs := [?]string{
		`
        if i == 1:
            i = 55
        end
        `,
		`
        if i == 1:
            i = 55
        else if i == 2:
            i = 33
        end
        `,
		`
        if i == 1:
            i = 55
        else if i == 2:
            i = 33
        else:
            i = -1
        end
        `,
	}
    //odinfmt: disable
	expected := [?]If_Result{
        {0, "binary",  {1}},
        {1, "binary",  {1, 1}},
        {2, "binary",  {1, 1, 1}},
    }
    //odinfmt: enable
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
			fmt.tprintf("Failed at %d, Expected %d nodes, Got %d\n%#v\n", i, len(m.nodes), i, m),
		)
		node, ok := m.nodes[0].(^Parsed_If_Statement)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_If_Statement, got %v", node))

		branch := node
		for j in 0 ..< e.branches {
			testing.expect(
				t,
				branch.next_branch != nil,
				fmt.tprintf("Failed at %d, Expected %d branches, Got %d\n", i, e.branches, j),
			)
			branch = branch.next_branch
		}

		branch = node
		for j in 0 ..< e.branches {
			check_expr_type(t, branch.condition, e.kind)
			testing.expect(
				t,
				e.node_counts[j] == len(branch.body.nodes),
				fmt.tprintf(
					"Expected %d nodes in branch %d, Got %d\n",
					e.node_counts[j],
					j,
					len(branch.body.nodes),
				),
			)
			branch = branch.next_branch
		}
	}
}

@(test)
test_range_statement :: proc(t: ^testing.T) {
	using lily

	has_flow_stmt :: proc(b: ^lily.Parsed_Block_Statement, k: lily.Control_Flow_Operator) -> bool {
		for inner in b.nodes {
			#partial switch expr in inner {
			case ^Parsed_If_Statement:
				if has_flow_stmt(expr.body, k) {
					return true
				}
			case ^Parsed_Range_Statement:
				if has_flow_stmt(expr.body, k) {
					return true
				}
			case ^Parsed_Flow_Statement:
				if expr.kind == k do return true
			}
		}
		return false
	}

	For_Result :: struct {
		low:          string,
		high:         string,
		node_count:   int,
		has_break:    bool,
		has_continue: bool,
	}

	inputs := [?]string{
		`
        for i in 0..10:
            b = 55
        end
        `,
		`
        for i in 0..a:
            b = 55
        end
        `,
		`
        for i in 0..a:
            break
        end
        `,
		`
        for i in 0..a:
            continue
        end
        `,
		`
        for i in 0..a:
            if i % 2 == 0:
                continue
            end
            if i == 10:
                break
            end
        end
        `,
	}
    //odinfmt: disable
	expected := [?]For_Result{
        {"lit", "lit",  1, false, false},
        {"lit", "ident",  1, false, false},
        {"lit", "ident",  1, true, false},
        {"lit", "ident",  1, false, true},
        {"lit", "ident",  2, true, true},
    }
    //odinfmt: enable
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
			fmt.tprintf("Failed at %d, Expected %d nodes, Got %d\n%s\n", i, len(m.nodes), i, inputs[i]),
		)
		node, ok := m.nodes[0].(^Parsed_Range_Statement)
		testing.expect(t, ok, fmt.tprintf("Expected Parsed_Range_Statement, got %v", node))

		check_expr_type(t, node.low, e.low)
		check_expr_type(t, node.high, e.high)
		testing.expect(
			t,
			e.node_count == len(node.body.nodes),
			fmt.tprintf("Expected %d nodes in body, Got %d\n", e.node_count, len(node.body.nodes)),
		)

		if e.has_continue {
			testing.expect(
				t,
				has_flow_stmt(node.body, .Continue),
				fmt.tprintf("Expected Continue Statement node in body %d", i),
			)
		}
		if e.has_break {
			testing.expect(
				t,
				has_flow_stmt(node.body, .Break),
				fmt.tprintf("Expected Break Statement node in body %d", i),
			)
		}
	}
}
