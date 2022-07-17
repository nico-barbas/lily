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
			fmt.tprintf("Failed at %d, Expected %d nodes, Got %d\n%#v\n", i, 1, len(m.nodes), m),
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
			fmt.tprintf("Failed at %d, Expected %d nodes, Got %d\n%#v\n", i, 1, len(m.nodes), m),
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
