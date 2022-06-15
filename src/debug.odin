package lily

import "core:fmt"
import "core:strings"

// TODO: (debug.odin)
/*
	- Fix Array Priting
*/

Debug_Printer :: struct {
	builder:      strings.Builder,
	indent_level: int,
	indent_width: int,
}

print_parsed_ast :: proc(program: ^Parsed_Module) {
	printer := Debug_Printer {
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

print_parsed_expr :: proc(p: ^Debug_Printer, expr: Parsed_Expression) {
	switch e in expr {
	case ^Parsed_Literal_Expression:
		write(p, "Literal Expression: ")
		fmt.sbprint(&p.builder, e.value)

	case ^Parsed_String_Literal_Expression:
		write(p, "String Literal Expression: ")
		fmt.sbprint(&p.builder, e.value)

	case ^Parsed_Array_Literal_Expression:
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


	case ^Parsed_Unary_Expression:
		write(p, "Unary Expression: ")
		increment(p)
		{
			write_line(p, "Operator: ")
			fmt.sbprint(&p.builder, e.op)
			write_line(p, "Expression: ")
			print_parsed_expr(p, e.expr)

		}
		decrement(p)

	case ^Parsed_Binary_Expression:
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

	case ^Parsed_Identifier_Expression:
		write(p, "Identifier Expression: ")
		fmt.sbprint(&p.builder, e.name.text)

	case ^Parsed_Index_Expression:
		write(p, "Index Expression: ")
		increment(p)
		{
			write_line(p, "Left: ")
			print_parsed_expr(p, e.left)
			write_line(p, "Index: ")
			print_parsed_expr(p, e.index)
		}
		decrement(p)

	case ^Parsed_Dot_Expression:
		write(p, "Dot Expression: ")
		increment(p)
		{
			write_line(p, "Left: ")
			print_parsed_expr(p, e.left)
			write_line(p, "Selector: ")
			print_parsed_expr(p, e.selector)
		}
		decrement(p)

	case ^Parsed_Call_Expression:
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

	case ^Parsed_Array_Type_Expression:
		write(p, "Array of ")
		print_parsed_expr(p, e.elem_type)
	}

}

print_parsed_node :: proc(p: ^Debug_Printer, node: Parsed_Node) {
	switch n in node {
	case ^Parsed_Expression_Statement:
		write_line(p, "Expression Statement: ")
		print_parsed_expr(p, n.expr)

	case ^Parsed_Block_Statement:
		write_line(p, "Block Statement: ")
		increment(p)
		for inner in n.nodes {
			print_parsed_node(p, inner)
		}
		decrement(p)

	case ^Parsed_Assignment_Statement:
		write_line(p, "Assignment Statement: ")
		increment(p)
		{
			write_line(p, "Left: ")
			print_parsed_expr(p, n.left)
			write_line(p, "Right: ")
			print_parsed_expr(p, n.right)
		}
		decrement(p)

	case ^Parsed_If_Statement:
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

	case ^Parsed_Range_Statement:
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

	case ^Parsed_Var_Declaration:
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

	case ^Parsed_Fn_Declaration:
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

	case ^Parsed_Type_Declaration:
		write_line(p, "Type Declaration: ")
		increment(p)
		{
			write_line(p, "Identifier name: ")
			write(p, n.identifier.text)
			switch n.type_kind {
			case .Alias:
				write_line(p, "Type name: ")
				print_parsed_expr(p, n.type_expr)
			case .Class:
				write_line(p, "Fields: ")
				increment(p)
				for field in n.fields {
					write_line(p)
					fmt.sbprintf(&p.builder, "Name: %s, Type: ", field.name.text)
					print_parsed_expr(p, field.type_expr)
				}
				decrement(p)

				write_line(p, "Constructors: ")
				increment(p)
				for constructor in n.constructors {
					print_parsed_node(p, constructor)
				}
				decrement(p)

				write_line(p, "Methods: ")
				increment(p)
				for method in n.methods {
					print_parsed_node(p, method)
				}
				decrement(p)
			}
		}
		decrement(p)
	}
}

///////////////
// Checked AST debugging

print_checked_ast :: proc(module: ^Checked_Module, checker: ^Checker) {
	printer := Debug_Printer {
		builder      = strings.make_builder(),
		indent_width = 2,
	}
	defer strings.destroy_builder(&printer.builder)

	write_line(&printer, "================= \n")
	write(&printer, "== CHECKED AST ==")

	write_line(&printer, "====================")
	write_line(&printer, "* Module's Classes *")
	write_line(&printer, "====================")
	for class in module.classes {
		print_checked_node(&printer, checker, class)
	}

	write_line(&printer, "======================")
	write_line(&printer, "* Module's Functions *")
	write_line(&printer, "======================")
	for function in module.functions {
		print_checked_node(&printer, checker, function)
	}

	write_line(&printer, "=================")
	write_line(&printer, "* Module's Body *")
	write_line(&printer, "=================")
	for node in module.nodes {
		print_checked_node(&printer, checker, node)
	}
	fmt.println(strings.to_string(printer.builder))
}

print_checked_expr :: proc(p: ^Debug_Printer, c: ^Checker, checked_expr: Checked_Expression) {
	switch e in checked_expr {
	case ^Checked_Literal_Expression:
		write(p, "Literal Expression: ")
		fmt.sbprint(&p.builder, e.value)

	case ^Checked_String_Literal_Expression:
		write(p, "String Literal Expression: ")
		fmt.sbprint(&p.builder, e.value)

	case ^Checked_Array_Literal_Expression:
		write(p, "Array Expression: ")
		increment(p)
		{
			write_line(p, "Type: ")
			print_type_info(p, c, e.type_info)
			write_line(p, "Elements: ")
			for element in e.values {
				print_checked_expr(p, c, element)
			}

		}
		decrement(p)


	case ^Checked_Unary_Expression:
		write(p, "Unary Expression: ")
		increment(p)
		{
			write_line(p, "Operator: ")
			fmt.sbprint(&p.builder, e.op)
			write_line(p, "Expression: ")
			print_checked_expr(p, c, e.expr)

		}
		decrement(p)

	case ^Checked_Binary_Expression:
		write(p, "Binary Expression: ")
		increment(p)
		{
			write_line(p, "Operator: ")
			fmt.sbprint(&p.builder, e.op)
			write_line(p, "Left Expression: ")
			print_checked_expr(p, c, e.left)
			write_line(p, "Right Expression: ")
			print_checked_expr(p, c, e.right)
		}
		decrement(p)

	case ^Checked_Identifier_Expression:
		write(p, "Identifier Expression: ")
		fmt.sbprint(&p.builder, e.name.text)

	case ^Checked_Index_Expression:
		write(p, "Index Expression: ")
		increment(p)
		{
			write_line(p, "Left: ")
			write(p, e.left.text)
			write_line(p, "Index: ")
			print_checked_expr(p, c, e.index)
		}
		decrement(p)

	case ^Checked_Dot_Expression:
		write(p, "Dot Expression: ")
		increment(p)
		{
			write_line(p, "Left: ")
			write(p, e.left.text)
			write_line(p, "Selector: ")
			write(p, e.selector.text)
		}
		decrement(p)

	case ^Checked_Call_Expression:
		write(p, "Call Expression: ")
		increment(p)
		{
			write_line(p, "Func: ")
			print_checked_expr(p, c, e.func)
			write_line(p, "Arguments: ")
			increment(p)
			for arg in e.args {
				write_line(p)
				print_checked_expr(p, c, arg)
			}
			decrement(p)
		}
		decrement(p)

	}

}

print_checked_node :: proc(p: ^Debug_Printer, c: ^Checker, node: Checked_Node) {
	switch n in node {
	case ^Checked_Expression_Statement:
		write_line(p, "Expression Statement: ")
		print_checked_expr(p, c, n.expr)

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
			print_checked_expr(p, c, n.left)
			write_line(p, "Right: ")
			print_checked_expr(p, c, n.right)
		}
		decrement(p)

	case ^Checked_If_Statement:
		write_line(p, "If Statement: ")
		increment(p)
		{
			write_line(p, "Condition: ")
			print_checked_expr(p, c, n.condition)
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
			print_checked_expr(p, c, n.low)
			write_line(p, "High: ")
			print_checked_expr(p, c, n.high)
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
			print_checked_expr(p, c, n.expr)
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
		write_line(p, "Type Declaration: ")
		increment(p)
		{
			write_line(p, "Identifier name: ")
			write(p, n.identifier.text)
			class_info := n.type_info.type_id_data.(Class_Definition_Info)
			write_line(p, "Fields: ")
			increment(p)
			for field, i in n.field_names {
				write_line(p)
				fmt.sbprintf(&p.builder, "Name: %s, Type: ", field.text)
				print_type_info(p, c, class_info.fields[i])
			}
			decrement(p)

			write_line(p, "Constructors: ")
			increment(p)
			for constructor in n.constructors {
				print_checked_node(p, c, constructor)
			}
			decrement(p)

			write_line(p, "Methods: ")
			increment(p)
			for method in n.methods {
				print_checked_node(p, c, method)
			}
			decrement(p)
		}
		decrement(p)
	}
}

print_type_info :: proc(p: ^Debug_Printer, c: ^Checker, t: Type_Info) {
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
	case .Class_Type:
		write(p, t.name)
	}
}

print_symbol_table :: proc(c: ^Checker, m: ^Checked_Module) {
	printer := Debug_Printer {
		builder      = strings.make_builder(),
		indent_width = 2,
	}
	defer strings.destroy_builder(&printer.builder)
	scope := m.scope
	for scope.parent != nil {
		scope = scope.parent
	}

	write_line(&printer, "================= \n")
	write(&printer, "== SYMBOL TABLE ==")
	print_semantic_scope(&printer, c, scope)
	fmt.println(strings.to_string(printer.builder))
}

print_semantic_scope :: proc(p: ^Debug_Printer, c: ^Checker, s: ^Semantic_Scope) {
	write_line(p, "Scope: ")
	fmt.sbprintf(&p.builder, "%d", s.id)
	increment(p)
	{
		write_line(p, "Symbols: ")
		increment(p)
		for symbol in s.symbols {
			write_line(p, "- ")
			switch smbl in symbol {
			case string:
				fmt.sbprintf(&p.builder, "Name: %s", smbl)
			case Scope_Ref_Symbol:
				fmt.sbprintf(&p.builder, "Name: %s, Referred Scope: %d", smbl.name, smbl.scope_id)
			case Var_Symbol:
				fmt.sbprintf(&p.builder, "Name: %s, Type: ", smbl.name)
				print_type_info(p, c, smbl.type_info)
			}
		}
		decrement(p)
		if len(s.children) > 0 {
			write_line(p, "Inner Scopes: ")
			increment(p)
			for child in s.children {
				print_semantic_scope(p, c, child)
			}
			decrement(p)
		}
	}
	decrement(p)

}

// Utility procedures

write :: proc(p: ^Debug_Printer, s: string = "") {
	strings.write_string_builder(&p.builder, s)
}

write_line :: proc(p: ^Debug_Printer, s: string = "") {
	strings.write_byte(&p.builder, '\n')
	indent(p)
	strings.write_string_builder(&p.builder, s)
}

indent :: proc(p: ^Debug_Printer) {
	whitespace := p.indent_level * p.indent_width
	for _ in 0 ..< whitespace {
		strings.write_rune_builder(&p.builder, ' ')
	}
}

increment :: proc(p: ^Debug_Printer) {
	p.indent_level += 1
}

decrement :: proc(p: ^Debug_Printer) {
	p.indent_level -= 1
}


///////////////
// Chunk Decompiling

print_chunk :: proc(c: Chunk) {
	printer := Debug_Printer {
		builder      = strings.make_builder(),
		indent_width = 2,
	}
	defer strings.destroy_builder(&printer.builder)

	write_line(&printer, "======================= \n")
	write(&printer, "== CHUNK DISASSEMBLY == \n")
	op_code_str := map[Op_Code]string {
		.Op_Begin        = "Op_Begin",
		.Op_End          = "Op_End",
		.Op_Pop          = "Op_Pop",
		.Op_Const        = "Op_Const",
		.Op_Bind         = "Op_Bind",
		.Op_Set          = "Op_Set",
		.Op_Set_Scoped   = "Op_Set_Scoped",
		.Op_Get          = "Op_Get",
		.Op_Get_Scoped   = "Op_Get_Scoped",
		.Op_Inc          = "Op_Inc",
		.Op_Dec          = "Op_Dec",
		.Op_Neg          = "Op_Neg",
		.Op_Not          = "Op_Not",
		.Op_Add          = "Op_Add",
		.Op_Mul          = "Op_Mul",
		.Op_Div          = "Op_Div",
		.Op_Rem          = "Op_Rem",
		.Op_And          = "Op_And",
		.Op_Or           = "Op_Or",
		.Op_Eq           = "Op_Eq",
		.Op_Greater      = "Op_Greater",
		.Op_Greater_Eq   = "Op_Greater_Eq",
		.Op_Lesser       = "Op_Lesser",
		.Op_Lesser_Eq    = "Op_Lesser_Eq",
		.Op_Jump         = "Op_Jump",
		.Op_Jump_False   = "Op_Jump_False",
		.Op_Return       = "Op_Return",
		.Op_Call         = "Op_Call",
		.Op_Make_Array   = "Op_Make_Array",
		.Op_Index_Array  = "Op_Index_Array",
		.Op_Index_Array  = "Op_Index_Array",
		.Op_Append_Array = "Op_Append_Array",
	}
	max_str := -1
	for k, v in op_code_str {
		if len(v) > max_str {
			max_str = len(v)
		}
	}

	print_ip :: proc(p: ^Debug_Printer, ip: int) {
		fmt.sbprintf(&p.builder, "%04d    ", ip)
	}

	format :: proc(p: ^Debug_Printer, word: string, max_len: int) {
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
		case .Op_Begin, .Op_End:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " ||")

		case .Op_Const:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " || const addr: %d", get_i16(&vm))

		case .Op_Bind:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(
				&printer.builder,
				" || var addr: %d  ==  relative stack id: %d",
				get_i16(&vm),
				get_i16(&vm),
			)

		case .Op_Set:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			get_byte(&vm)
			fmt.sbprintf(&printer.builder, " || var addr: %d", get_i16(&vm))

		case .Op_Set_Scoped:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " || var addr: %d", get_i16(&vm))

		case .Op_Get, .Op_Get_Scoped, .Op_Return:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " || var addr: %d", get_i16(&vm))

		case .Op_Pop, .Op_Neg, .Op_Inc, .Op_Dec, .Op_Not:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " ||")

		case .Op_Add, .Op_Mul, .Op_Div, .Op_Rem, .Op_And, .Op_Or, .Op_Eq, .Op_Greater, .Op_Greater_Eq, .Op_Lesser, .Op_Lesser_Eq:
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

		case .Op_Call:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " || fn addr: %04d", get_i16(&vm))

		case .Op_Make_Array, .Op_Assign_Array, .Op_Index_Array, .Op_Append_Array:
			write(&printer, op_code_str[op])
			format(&printer, op_code_str[op], max_str)
			fmt.sbprintf(&printer.builder, " ||")
		}
		if vm.ip >= len(vm.chunk.bytecode) {
			break
		}

		write_line(&printer)
	}
	fmt.println(strings.to_string(printer.builder))
}

print_stack :: proc(vm: ^Vm) {
	printer := Debug_Printer {
		builder      = strings.make_builder(),
		indent_width = 2,
	}
	defer strings.destroy_builder(&printer.builder)

	write_line(&printer, "========================= \n")
	write(&printer, "== VM STACK DEBUG VIEW == \n")

	for value, i in vm.stack[:vm.stack_ptr] {
		fmt.sbprintf(&printer.builder, "%03d   ", i)
		print_value(&printer, value)
		if i == vm.header_ptr && vm.stack_depth > 0 {
			write(&printer, "     <- Scope Header")
		} else if i == vm.header_ptr + 1 && vm.stack_depth > 0 {
			write(&printer, "     <- Scope Start")
		}
		write_line(&printer)
	}

	fmt.println(strings.to_string(printer.builder))
}

print_value :: proc(p: ^Debug_Printer, value: Value) {
	switch data in value.data {
	case f64:
		fmt.sbprintf(&p.builder, "%01f", data)
	case bool:
		fmt.sbprintf(&p.builder, "%t", data)
	case ^Object:
		switch data.kind {
		case .String:
			str_object := cast(^String_Object)data
			write(p, `"`)
			for r in str_object.data {
				strings.write_rune_builder(&p.builder, r)
			}
			write(p, `"`)
		case .Array:
			array_object := cast(^Array_Object)data
			write(p, `[`)
			for element in array_object.data {
				print_value(p, element)
				write(p, `,`)
			}
			write(p, `]`)
		case .Fn:
		case .Class:
		}
	}
}
