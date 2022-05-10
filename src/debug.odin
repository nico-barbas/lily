package lily

import "core:fmt"
import "core:strings"

AST_Printer :: struct {
	builder:      strings.Builder,
	indent_level: int,
	indent_width: int,
}

print_ast :: proc(program: ^Program) {
	printer := AST_Printer {
		builder      = strings.make_builder(),
		indent_width = 2,
	}
	defer strings.destroy_builder(&printer.builder)

	for node in program.nodes {
		print_node(&printer, node)
	}
	fmt.println(strings.to_string(printer.builder))
}

print_expr :: proc(p: ^AST_Printer, expr: Expression) {
	switch e in expr {
	case ^Literal_Expression:
		write(p, "Literal Expression: ")
		fmt.sbprint(&p.builder, e.value)

	case ^String_Literal_Expression:
		write(p, "String Literal Expression: ")
		fmt.sbprint(&p.builder, e.value)

	case ^Array_Literal_Expression:
		write(p, "Array Expression: ")
		increment(p)
		{
			write_line(p, "Type: ")
			print_expr(p, e.type_expr)
			write_line(p, "Elements: ")
			for element in e.values {
				print_expr(p, element)
			}

		}
		decrement(p)


	case ^Unary_Expression:
		write(p, "Unary Expression: ")
		increment(p)
		{
			write_line(p, "Operator: ")
			fmt.sbprint(&p.builder, e.op)
			write_line(p, "Expression: ")
			print_expr(p, e.expr)

		}
		decrement(p)

	case ^Binary_Expression:
		write(p, "Binary Expression: ")
		increment(p)
		{
			write_line(p, "Operator: ")
			fmt.sbprint(&p.builder, e.op)
			write_line(p, "Left Expression: ")
			print_expr(p, e.left)
			write_line(p, "Right Expression: ")
			print_expr(p, e.right)
		}
		decrement(p)

	case ^Identifier_Expression:
		write(p, "Identifier Expression: ")
		fmt.sbprint(&p.builder, e.name)

	case ^Index_Expression:
		write(p, "Index Expression: ")
		increment(p)
		{
			write_line(p, "Left: ")
			print_expr(p, e.left)
			write_line(p, "Index: ")
			print_expr(p, e.index)
		}
		decrement(p)

	case ^Call_Expression:
		write(p, "Call Expression: ")
		increment(p)
		{
			write_line(p, "Func: ")
			print_expr(p, e.func)
			write_line(p, "Arguments: ")
			increment(p)
			for i in 0 ..< e.arg_count {
				write_line(p)
				print_expr(p, e.args[i])
			}
			decrement(p)
		}
		decrement(p)

	case ^Array_Type:
		write(p, "Array of ")
		print_expr(p, e.elem_type)
	}

}

print_node :: proc(p: ^AST_Printer, node: Node) {
	switch n in node {
	case ^Expression_Statement:
		write_line(p, "Expression Statement: ")
		print_expr(p, n.expr)

	case ^Block_Statement:
		write_line(p, "Block Statement: ")
		increment(p)
		for inner in n.nodes {
			print_node(p, inner)
		}
		decrement(p)

	case ^Assignment_Statement:
		write_line(p, "Assignment Statement: ")
		increment(p)
		{
			write_line(p, "Left: ")
			print_expr(p, n.left)
			write_line(p, "Right: ")
			print_expr(p, n.right)
		}
		decrement(p)

	case ^If_Statement:
		write_line(p, "If Statement: ")
		increment(p)
		{
			write_line(p, "Condition: ")
			print_expr(p, n.condition)
			print_node(p, n.body)
			if n.next_branch != nil {
				write_line(p, "Else: ")
				print_node(p, n.next_branch)
			}
		}
		decrement(p)

	case ^Range_Statement:
		write_line(p, "For Statement: ")
		increment(p)
		{
			write_line(p, "Iterator identifier name: ")
			write(p, n.iterator_name)
			write_line(p, "Operator: ")
			fmt.sbprint(&p.builder, n.op)
			write_line(p, "Low: ")
			print_expr(p, n.low)
			write_line(p, "High: ")
			print_expr(p, n.high)
			print_node(p, n.body)
		}
		decrement(p)

	case ^Var_Declaration:
		write_line(p, "Var Declaration: ")
		increment(p)
		{
			write_line(p, "Identifier name: ")
			write(p, n.identifier)
			write_line(p, "Type: ")
			print_expr(p, n.type_expr)
			write_line(p, "Expression: ")
			print_expr(p, n.expr)
		}
		decrement(p)

	case ^Fn_Declaration:
		write_line(p, "Function Declaration: ")
		increment(p)
		{
			write_line(p, "Identifier name: ")
			write(p, n.identifier)
			write_line(p, "Parameters: ")
			increment(p)
			for i in 0 ..< n.param_count {
				write_line(p)
				fmt.sbprintf(&p.builder, "Name: %s, Type: ", n.parameters[i].name)
				print_expr(p, n.parameters[i].type_expr)
			}
			decrement(p)
			write_line(p, "Return type: ")
			print_expr(p, n.return_type_expr)

			print_node(p, n.body)
		}
		decrement(p)
	}
}

write :: proc(p: ^AST_Printer, s: string = "") {
	strings.write_string_builder(&p.builder, s)
}

write_line :: proc(p: ^AST_Printer, s: string = "") {
	strings.write_byte(&p.builder, '\n')
	indent(p)
	strings.write_string_builder(&p.builder, s)
}

indent :: proc(p: ^AST_Printer) {
	whitespace := p.indent_level * p.indent_width
	for _ in 0 ..< whitespace {
		strings.write_rune_builder(&p.builder, ' ')
	}
}

increment :: proc(p: ^AST_Printer) {
	p.indent_level += 1
}

decrement :: proc(p: ^AST_Printer) {
	p.indent_level -= 1
}
