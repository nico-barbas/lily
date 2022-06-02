package lily

import "core:fmt"
import "core:strings"

// TODO: (debug.odin)
/*
	- Fix Array Priting
*/

AST_Printer :: struct {
	builder:      strings.Builder,
	indent_level: int,
	indent_width: int,
}

print_parsed_ast :: proc(program: ^Parsed_Module) {
	printer := AST_Printer {
		builder      = strings.make_builder(),
		indent_width = 2,
	}
	defer strings.destroy_builder(&printer.builder)

	write_line(&printer, "================ \n")
	write(&printer, "== PARSED AST == \n")
	for node in program.nodes {
		print_parsed_node(&printer, node)
	}
	fmt.println(strings.to_string(printer.builder))
}

print_parsed_expr :: proc(p: ^AST_Printer, expr: Expression) {
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
			print_parsed_expr(p, e.type_expr)
			write_line(p, "Elements: ")
			for element in e.values {
				print_parsed_expr(p, element)
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
			print_parsed_expr(p, e.expr)

		}
		decrement(p)

	case ^Binary_Expression:
		write(p, "Binary Expression: ")
		increment(p)
		{
			write_line(p, "Operator: ")
			fmt.sbprint(&p.builder, e.op)
			write_line(p, "Left Expression: ")
			print_parsed_expr(p, e.left)
			write_line(p, "Right Expression: ")
			print_parsed_expr(p, e.right)
		}
		decrement(p)

	case ^Identifier_Expression:
		write(p, "Identifier Expression: ")
		fmt.sbprint(&p.builder, e.name.text)

	case ^Index_Expression:
		write(p, "Index Expression: ")
		increment(p)
		{
			write_line(p, "Left: ")
			print_parsed_expr(p, e.left)
			write_line(p, "Index: ")
			print_parsed_expr(p, e.index)
		}
		decrement(p)

	case ^Call_Expression:
		write(p, "Call Expression: ")
		increment(p)
		{
			write_line(p, "Func: ")
			print_parsed_expr(p, e.func)
			write_line(p, "Arguments: ")
			increment(p)
			for arg in e.args {
				write_line(p)
				print_parsed_expr(p, arg)
			}
			decrement(p)
		}
		decrement(p)

	case ^Array_Type_Expression:
		write(p, "Array of ")
		print_parsed_expr(p, e.elem_type)
	}

}

print_parsed_node :: proc(p: ^AST_Printer, node: Node) {
	switch n in node {
	case ^Expression_Statement:
		write_line(p, "Expression Statement: ")
		print_parsed_expr(p, n.expr)

	case ^Block_Statement:
		write_line(p, "Block Statement: ")
		increment(p)
		for inner in n.nodes {
			print_parsed_node(p, inner)
		}
		decrement(p)

	case ^Assignment_Statement:
		write_line(p, "Assignment Statement: ")
		increment(p)
		{
			write_line(p, "Left: ")
			print_parsed_expr(p, n.left)
			write_line(p, "Right: ")
			print_parsed_expr(p, n.right)
		}
		decrement(p)

	case ^If_Statement:
		write_line(p, "If Statement: ")
		increment(p)
		{
			write_line(p, "Condition: ")
			print_parsed_expr(p, n.condition)
			print_parsed_node(p, n.body)
			if n.next_branch != nil {
				write_line(p, "Else: ")
				print_parsed_node(p, n.next_branch)
			}
		}
		decrement(p)

	case ^Range_Statement:
		write_line(p, "For Statement: ")
		increment(p)
		{
			write_line(p, "Iterator identifier name: ")
			write(p, n.iterator_name.text)
			write_line(p, "Operator: ")
			fmt.sbprint(&p.builder, n.op)
			write_line(p, "Low: ")
			print_parsed_expr(p, n.low)
			write_line(p, "High: ")
			print_parsed_expr(p, n.high)
			print_parsed_node(p, n.body)
		}
		decrement(p)

	case ^Var_Declaration:
		write_line(p, "Var Declaration: ")
		increment(p)
		{
			write_line(p, "Identifier name: ")
			write(p, n.identifier.text)
			write_line(p, "Type: ")
			print_parsed_expr(p, n.type_expr)
			write_line(p, "Expression: ")
			print_parsed_expr(p, n.expr)
		}
		decrement(p)

	case ^Fn_Declaration:
		write_line(p, "Function Declaration: ")
		increment(p)
		{
			write_line(p, "Identifier name: ")
			write(p, n.identifier.text)
			write_line(p, "Parameters: ")
			increment(p)
			for param in n.parameters {
				write_line(p)
				fmt.sbprintf(&p.builder, "Name: %s, Type: ", param.name.text)
				print_parsed_expr(p, param.type_expr)
			}
			decrement(p)
			write_line(p, "Return type: ")
			print_parsed_expr(p, n.return_type_expr)

			print_parsed_node(p, n.body)
		}
		decrement(p)

	case ^Type_Declaration:
		write_line(p, "Type Declaration: ")
		increment(p)
		{
			write_line(p, "Identifier name: ")
			write(p, n.identifier.text)
			write_line(p, "Type name: ")
			print_parsed_expr(p, n.type_expr)
		}
		decrement(p)
	}
}

///////////////
// Checked AST debugging

print_checked_ast :: proc(module: ^Checked_Module, checker: ^Checker) {
	printer := AST_Printer {
		builder      = strings.make_builder(),
		indent_width = 2,
	}
	defer strings.destroy_builder(&printer.builder)

	write_line(&printer, "================= \n")
	write(&printer, "== CHECKED AST == \n")
	for function in module.functions {
		print_checked_node(&printer, checker, function)
	}

	for node in module.nodes {
		print_checked_node(&printer, checker, node)
	}
	fmt.println(strings.to_string(printer.builder))
}

print_checked_expr :: proc(p: ^AST_Printer, checked_expr: Checked_Expression) {
	print_parsed_expr(p, checked_expr.expr)
}

print_checked_node :: proc(p: ^AST_Printer, c: ^Checker, node: Checked_Node) {
	switch n in node {
	case ^Checked_Expression_Statement:
		write_line(p, "Expression Statement: ")
		print_checked_expr(p, n.expr)

	case ^Checked_Block_Statement:
		write_line(p, "Block Statement: ")
		increment(p)
		for inner in n.nodes {
			print_checked_node(p, c, inner)
		}
		decrement(p)

	case ^Checked_Assigment_Statement:
		write_line(p, "Assignment Statement: ")
		increment(p)
		{
			write_line(p, "Left: ")
			print_checked_expr(p, n.left)
			write_line(p, "Right: ")
			print_checked_expr(p, n.right)
		}
		decrement(p)

	case ^Checked_If_Statement:
		write_line(p, "If Statement: ")
		increment(p)
		{
			write_line(p, "Condition: ")
			print_checked_expr(p, n.condition)
			print_checked_node(p, c, n.body)
			if n.next_branch != nil {
				write_line(p, "Else: ")
				print_checked_node(p, c, n.next_branch)
			}
		}
		decrement(p)

	case ^Checked_Range_Statement:
		write_line(p, "For Statement: ")
		increment(p)
		{
			write_line(p, "Iterator identifier name: ")
			write(p, n.iterator_name.text)
			write_line(p, "Operator: ")
			fmt.sbprint(&p.builder, n.op)
			write_line(p, "Low: ")
			print_checked_expr(p, n.low)
			write_line(p, "High: ")
			print_checked_expr(p, n.high)
			print_checked_node(p, c, n.body)
		}
		decrement(p)

	case ^Checked_Var_Declaration:
		write_line(p, "Var Declaration: ")
		increment(p)
		{
			write_line(p, "Identifier name: ")
			write(p, n.identifier.text)
			write_line(p, "Type: ")
			print_type_info(p, c, n.type_info)
			write_line(p, "Expression: ")
			print_checked_expr(p, n.expr)
		}
		decrement(p)

	case ^Checked_Fn_Declaration:
		write_line(p, "Function Declaration: ")
		increment(p)
		{
			write_line(p, "Identifier name: ")
			write(p, n.identifier.text)
			write_line(p, "Signature: ")
			print_type_info(p, c, n.type_info)
			print_checked_node(p, c, n.body)
		}
		decrement(p)

	case ^Checked_Type_Declaration:
		write_line(p, "Type Declaration: ")
		increment(p)
		{
			write_line(p, "Identifier name: ")
			write(p, n.identifier.text)
			write_line(p, "Type name: ")
			print_type_info(p, c, n.type_info)
		}
		decrement(p)

	case ^Checked_Class_Declaration:
		assert(false, "Not Implemented yet")
	}
}

print_type_info :: proc(p: ^AST_Printer, c: ^Checker, t: Type_Info) {
	switch t.type_kind {
	case .Builtin, .Elementary_Type, .Type_Alias:
		write(p, t.name)
	case .Generic_Type:
		generic_id := t.type_id_data.(Generic_Type_Info)
		generic_info := get_type_from_id(c, generic_id.spec_type_id)
		fmt.sbprintf(&p.builder, "%s of %s", t.name, generic_info.name)
	case .Fn_Type:
		fn_signature := t.type_id_data.(Fn_Signature_Info)
		increment(p)
		write_line(p, "Parameters: ")
		for param in fn_signature.parameters {
			print_type_info(p, c, param)
			write(p, ", ")
		}
		write_line(p, "Returns: ")
		return_type := get_type_from_id(c, fn_signature.return_type_id)
		print_type_info(p, c, return_type)
		decrement(p)
	}
}

// Utility procedures

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


///////////////
// Chunk Decompiling

print_chunk :: proc(c: Chunk) {
	printer := AST_Printer {
		builder      = strings.make_builder(),
		indent_width = 2,
	}
	defer strings.destroy_builder(&printer.builder)

	write_line(&printer, "======================= \n")
	write(&printer, "== CHUNK DISASSEMBLY == \n")
	op_code_str := map[Op_Code]string {
		.Op_Begin      = "Op_Begin",
		.Op_End        = "Op_End",
		.Op_Pop        = "Op_Pop",
		.Op_Const      = "Op_Const",
		.Op_Set        = "Op_Set",
		.Op_Get        = "Op_Get",
		.Op_Inc        = "Op_Inc",
		.Op_Dec        = "Op_Dec",
		.Op_Neg        = "Op_Neg",
		.Op_Not        = "Op_Not",
		.Op_Add        = "Op_Add",
		.Op_Mul        = "Op_Mul",
		.Op_Div        = "Op_Div",
		.Op_Rem        = "Op_Rem",
		.Op_And        = "Op_And",
		.Op_Or         = "Op_Or",
		.Op_Eq         = "Op_Eq",
		.Op_Greater    = "Op_Greater",
		.Op_Greater_Eq = "Op_Greater_Eq",
		.Op_Lesser     = "Op_Lesser",
		.Op_Lesser_Eq  = "Op_Lesser_Eq",
		.Op_Jump       = "Op_Jump",
		.Op_Jump_False = "Op_Jump_False",
	}
	max_str := -1
	for k, v in op_code_str {
		if len(v) > max_str {
			max_str = len(v)
		}
	}

	print_ip :: proc(p: ^AST_Printer, ip: int) {
		fmt.sbprintf(&p.builder, "%04d    ", ip)
	}

	format :: proc(p: ^AST_Printer, word: string, max_len: int) {
		diff := max_len - len(word)
		for _ in 0 ..< diff {
			write(p, " ")
		}
	}

	vm := Vm{}
	// vm.stack = make([]Value, VM_STACK_SIZE)
	// vm.stack_ptr = 0
	vm.chunk = c
	vm.ip = 0
	for {
		print_ip(&printer, vm.ip)
		op := get_op_code(&vm)
		switch op {
		case .Op_Begin:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " ||")

		case .Op_End:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " ||")


		case .Op_Const:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " || const addr: %d", get_i16(&vm))

		case .Op_Set:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " || var addr: %d", get_i16(&vm))

		case .Op_Get:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " || var addr: %d", get_i16(&vm))

		case .Op_Pop:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " ||")

		case .Op_Neg, .Op_Inc, .Op_Dec:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " ||")

		case .Op_Not:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " ||")

		case .Op_Add:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " ||")

		case .Op_Mul:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " ||")

		case .Op_Div:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " ||")

		case .Op_Rem:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " ||")

		case .Op_And:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " ||")

		case .Op_Or:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " ||")

		case .Op_Eq, .Op_Greater, .Op_Greater_Eq, .Op_Lesser, .Op_Lesser_Eq:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " ||")

		case .Op_Jump:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " || jump IP: %04d", get_i16(&vm))

		case .Op_Jump_False:
			write(&printer, "Op_Jump_False")
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " || jump IP: %04d", get_i16(&vm))

		}
		if vm.ip >= len(vm.chunk.bytecode) {
			break
		}

		write_line(&printer)
	}
	fmt.println(strings.to_string(printer.builder))
}
