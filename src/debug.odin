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
		builder      = strings.builder_make(),
		indent_width = 2,
	}
	defer strings.builder_destroy(&printer.builder)

	write_line(&printer, "================ \n")
	write(&printer, "== PARSED AST == \n")
	fmt.sbprintf(&printer.builder, "== import count: %d", len(program.import_nodes))
	for node in program.import_nodes {
		print_parsed_node(&printer, node)
	}

	fmt.sbprintf(&printer.builder, "\n== type count: %d", len(program.types))
	for node in program.types {
		print_parsed_node(&printer, node)
	}

	fmt.sbprintf(&printer.builder, "\n== variable count: %d", len(program.variables))
	for node in program.variables {
		print_parsed_node(&printer, node)
	}

	fmt.sbprintf(&printer.builder, "\n== function count: %d", len(program.functions))
	for node in program.functions {
		print_parsed_node(&printer, node)
	}

	fmt.sbprintf(&printer.builder, "\n== node count: %d", len(program.nodes))
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
		write(p, `String Literal Expression: "`)
		fmt.sbprint(&p.builder, e.value)
		write(p, `"`)

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

	case ^Parsed_Map_Literal_Expression:
		write(p, "Map Expression: ")
		increment(p)
		{
			write_line(p, "Type: ")
			print_parsed_expr(p, e.type_expr)
			write_line(p, "Elements: ")
			increment(p)
			for element in e.elements {
				write_line(p, "Key: ")
				print_parsed_expr(p, element.key)
				write_line(p, "Value: ")
				print_parsed_expr(p, element.value)
			}
			decrement(p)
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

	case ^Parsed_Map_Type_Expression:
		write(p, "Map of (")
		print_parsed_expr(p, e.key_type)
		write(p, ", ")
		print_parsed_expr(p, e.value_type)
		write(p, ")")
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

	case ^Parsed_Match_Statement:
		write_line(p, "Match Statement: ")
		increment(p)
		{
			write_line(p, "Evaluated expression: ")
			print_parsed_expr(p, n.evaluation)
			for c in n.cases {
				write_line(p, "Match Branch: ")
				increment(p)
				{
					write_line(p, "Condition: ")
					print_parsed_expr(p, c.condition)
					print_parsed_node(p, c.body)
				}
				decrement(p)
			}
		}
		decrement(p)

	case ^Parsed_Flow_Statement:
		write_line(p, "Flow Statement: ")
		switch n.kind {
		case .Break:
			write(p, "Break")
		case .Continue:
			write(p, "Continue")
		}

	case ^Parsed_Import_Statement:
		write_line(p, "Import Statement: ")
		write(p, n.identifier.text)

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
		builder      = strings.builder_make(),
		indent_width = 2,
	}
	defer strings.builder_destroy(&printer.builder)

	write_line(&printer, "================= \n")
	write(&printer, "== CHECKED AST ==")

	write_line(&printer, "====================")
	write_line(&printer, "* Module's Classes *")
	write_line(&printer, "====================")
	for class in module.classes {
		print_checked_node(&printer, checker, class)
	}

	write_line(&printer, "====================")
	write_line(&printer, "* Module's Variables *")
	write_line(&printer, "====================")
	for class in module.variables {
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
			print_symbol(p, e.symbol)
			write_line(p, "Elements: ")
			for element in e.values {
				print_checked_expr(p, c, element)
			}

		}
		decrement(p)

	case ^Checked_Map_Literal_Expression:
		write(p, "Map Expression: ")
		increment(p)
		{
			write_line(p, "Type: ")
			print_symbol(p, e.symbol)
			write_line(p, "Elements: ")
			increment(p)
			for element in e.elements {
				write_line(p, "Key: ")
				print_checked_expr(p, c, element.key)
				write_line(p, "Value: ")
				print_checked_expr(p, c, element.value)
			}
			decrement(p)

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
		print_symbol(p, e.symbol, "")

	case ^Checked_Index_Expression:
		write(p, "Index Expression: ")
		increment(p)
		{
			write_line(p, "Left: ")
			print_checked_expr(p, c, e.left)
			write_line(p, "Index: ")
			print_checked_expr(p, c, e.index)
		}
		decrement(p)

	case ^Checked_Dot_Expression:
		write(p, "Dot Expression: ")
		increment(p)
		{
			write_line(p, "Left: ")
			print_checked_expr(p, c, e.left)
			write_line(p, "Selector: ")
			print_checked_expr(p, c, e.selector)
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
			write_line(p, "Iterator: ")
			print_symbol(p, n.iterator)
			write_line(p, "Operator: ")
			fmt.sbprint(&p.builder, n.op)
			write_line(p, "Low: ")
			print_checked_expr(p, c, n.low)
			write_line(p, "High: ")
			print_checked_expr(p, c, n.high)
			print_checked_node(p, c, n.body)
		}
		decrement(p)

	case ^Checked_Match_Statement:
		write_line(p, "Match Statement: ")
		increment(p)
		{
			write_line(p, "Evaluated Expression: ")
			print_checked_expr(p, c, n.evaluation)
			for ca in n.cases {
				write_line(p, "Match Branch: ")
				write_line(p, "Condition: ")
				print_checked_expr(p, c, ca.condition)
				if ca.body != nil {
					print_checked_node(p, c, ca.body)
				}
			}
		}
		decrement(p)

	case ^Checked_Flow_Statement:
		write_line(p, "Flow Statement: ")
		switch n.kind {
		case .Break:
			write(p, "Break")
		case .Continue:
			write(p, "Continue")
		}

	case ^Checked_Var_Declaration:
		write_line(p, "Var Declaration: ")
		increment(p)
		{
			write_line(p, "Identifier name: ")
			print_symbol(p, n.identifier)
			write_line(p, "Expression: ")
			print_checked_expr(p, c, n.expr)
		}
		decrement(p)

	case ^Checked_Fn_Declaration:
		write_line(p, "Function Declaration: ")
		increment(p)
		{
			write_line(p, "Identifier: ")
			print_symbol(p, n.identifier)
			for param in n.params {
				print_symbol(p, param)
			}
			print_checked_node(p, c, n.body)
		}
		decrement(p)

	case ^Checked_Type_Declaration:
	// write_line(p, "Type Declaration: ")
	// increment(p)
	// {
	// 	write_line(p, "Identifier name: ")
	// 	write(p, n.identifier.text)

	// 	write_line(p, "Type name: ")
	// 	print_type_info(p, c, n.type_info)
	// }
	// decrement(p)

	case ^Checked_Class_Declaration:
		write_line(p, "Type Declaration: ")
		increment(p)
		{
			write_line(p, "Identifier name: ")
			print_symbol(p, n.identifier)
			write_line(p, "Fields: ")
			increment(p)
			for field, i in n.fields {
				print_symbol(p, field)
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

print_symbol_table :: proc(c: ^Checker, m: ^Checked_Module) {
	printer := Debug_Printer {
		builder      = strings.builder_make(),
		indent_width = 2,
	}
	defer strings.builder_destroy(&printer.builder)
	scope := m.scope
	for scope.parent != nil {
		scope = scope.parent
	}

	write_line(&printer, "================= \n")
	write(&printer, "== SYMBOL TABLE ==")
	print_semantic_scope(&printer, c, scope)
	fmt.println(strings.to_string(printer.builder))
}

print_semantic_scope_standalone :: proc(c: ^Checker, s: ^Semantic_Scope) {
	printer := Debug_Printer {
		builder      = strings.builder_make(),
		indent_width = 2,
	}
	defer strings.builder_destroy(&printer.builder)
	print_semantic_scope(&printer, c, s)
	fmt.println(strings.to_string(printer.builder))
}

print_semantic_scope :: proc(p: ^Debug_Printer, c: ^Checker, s: ^Semantic_Scope) {
	write_line(p, "Scope: ")
	fmt.sbprintf(&p.builder, "%d", s.id)
	increment(p)
	{
		write_line(p, "Symbols: ")
		increment(p)
		for _, i in s.symbols {
			print_symbol(p, &s.symbols[i])
		}
		decrement(p)
		if len(s.children) > 0 {
			write_line(p, "Inner Scopes: ")
			increment(p)
			for _, child in s.children {
				print_semantic_scope(p, c, child)
			}
			decrement(p)
		}
	}
	decrement(p)

}

print_symbol :: proc(p: ^Debug_Printer, symbol: ^Symbol, leading_char := "-") {
	write_line(p, leading_char)
	write(p, " ")
	fmt.sbprintf(
		&p.builder,
		"Name: %s, Type ID: %d, Module ID: %d, Scope ID: %d, ",
		symbol.name,
		symbol.type_id,
		symbol.module_id,
		symbol.scope_id,
	)
	switch symbol.kind {
	case .Name:
	case .Alias_Symbol:
		increment(p)
		alias_info := symbol.info.(Alias_Symbol_Info)
		print_symbol(p, alias_info.symbol, "=>")
		decrement(p)

	case .Generic_Symbol:
		increment(p)
		generic_info := symbol.info.(Generic_Symbol_Info)
		for inner_symbol in generic_info.symbols {
			print_symbol(p, inner_symbol, "=>")
		}
		decrement(p)

	case .Class_Symbol:
		class_info := symbol.info.(Class_Symbol_Info)
		fmt.sbprintf(&p.builder, "Info: Class Scope ID: %d", class_info.sub_scope_id)

	case .Module_Symbol:
		module_info := symbol.info.(Module_Symbol_Info)
		fmt.sbprintf(&p.builder, "Info: Ref Module ID: %d", module_info.ref_mod_id)

	case .Fn_Symbol:
		fn_info := symbol.info.(Fn_Symbol_Info)
		fmt.sbprintf(
			&p.builder,
			"Info: Inner Scope ID: %d, Has return: %t",
			fn_info.sub_scope_id,
			fn_info.has_return,
		)
		if fn_info.has_return {
			increment(p)
			print_symbol(p, fn_info.return_symbol, "=>")
			decrement(p)
		}

	case .Var_Symbol:
		var_info := symbol.info.(Var_Symbol_Info)
		fmt.sbprintf(&p.builder, "Info: Mutable: %t, Depth: %d", var_info.mutable, var_info.depth)
		if var_info.symbol != nil {
			increment(p)
			print_symbol(p, var_info.symbol, "=>")
			decrement(p)
		}
	}
}

// Utility procedures

write :: proc(p: ^Debug_Printer, s: string = "") {
	strings.write_string(&p.builder, s)
}

write_line :: proc(p: ^Debug_Printer, s: string = "") {
	strings.write_byte(&p.builder, '\n')
	indent(p)
	strings.write_string(&p.builder, s)
}

indent :: proc(p: ^Debug_Printer) {
	whitespace := p.indent_level * p.indent_width
	for _ in 0 ..< whitespace {
		strings.write_rune(&p.builder, ' ')
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

print_compiled_module :: proc(m: ^Compiled_Module) {
	printer := Debug_Printer {
		builder      = strings.builder_make(),
		indent_width = 2,
	}
	defer strings.builder_destroy(&printer.builder)

	write_line(&printer, "================= \n")
	write(&printer, "== CLASSES  ==")
	increment(&printer)
	for name, index in m.class_addr {
		vtable := m.vtables[index]
		write_line(&printer, "- ")
		fmt.sbprintf(&printer.builder, "%s : ", name)

		increment(&printer)
		{
			// write_line(&printer, "Fields: ")
			// increment(&printer)
			// for field in prototype.fields {
			// 	write_line(&printer, "- ")
			// 	fmt.sbprintf(&printer.builder, "%s", field.name)
			// }
			// decrement(&printer)

			write_line(&printer, "Construtors: ")
			increment(&printer)
			for _, i in vtable.constructors {
				constructor := &vtable.constructors[i]
				write_line(&printer, "- #")
				fmt.sbprintf(&printer.builder, "%d: ", i)
				print_chunk(&printer, &constructor.chunk)
			}
			decrement(&printer)

			write_line(&printer, "Methods: ")
			increment(&printer)
			for _, i in vtable.methods {
				method := &vtable.methods[i]
				write_line(&printer, "- #")
				fmt.sbprintf(&printer.builder, "%d: ", i)
				print_chunk(&printer, &method.chunk)
			}
			decrement(&printer)
		}
		decrement(&printer)
	}
	decrement(&printer)

	write_line(&printer, "================= \n")
	write(&printer, "== FUNCTIONS  ==")
	for _, i in m.functions {
		fn := &m.functions[i]
		print_chunk(&printer, &fn.chunk)
	}

	if len(m.main.bytecode) > 0 {
		write_line(&printer, "================= \n")
		write(&printer, "== MAIN  ==")
		print_chunk(&printer, &m.main)
	}

	fmt.println(strings.to_string(printer.builder))
}

op_code_str := map[Op_Code]string {
	.Op_None          = "Op_None",
	.Op_Push          = "Op_Push",
	.Op_Pop           = "Op_Pop",
	.Op_Push_Back     = "Op_Push_Back",
	.Op_Move          = "Op_Move",
	.Op_Copy          = "Op_Copy",
	.Op_Const         = "Op_Const",
	.Op_Module        = "Op_Module",
	.Op_Prototype     = "Op_Prototype",
	.Op_Inc           = "Op_Inc",
	.Op_Dec           = "Op_Dec",
	.Op_Neg           = "Op_Neg",
	.Op_Not           = "Op_Not",
	.Op_Add           = "Op_Add",
	.Op_Mul           = "Op_Mul",
	.Op_Div           = "Op_Div",
	.Op_Rem           = "Op_Rem",
	.Op_And           = "Op_And",
	.Op_Or            = "Op_Or",
	.Op_Eq            = "Op_Eq",
	.Op_Greater       = "Op_Greater",
	.Op_Greater_Eq    = "Op_Greater_Eq",
	.Op_Lesser        = "Op_Lesser",
	.Op_Lesser_Eq     = "Op_Lesser_Eq",
	.Op_Begin         = "Op_Begin",
	.Op_End           = "Op_End",
	.Op_Call          = "Op_Call",
	.Op_Call_Foreign  = "Op_Call_Foreign",
	.Op_Call_Method   = "Op_Call_Method",
	.Op_Call_Constr   = "Op_Call_Constr",
	.Op_Return        = "Op_Return",
	.Op_Jump          = "Op_Jump",
	.Op_Jump_False    = "Op_Jump_False",
	.Op_Get           = "Op_Get",
	.Op_Get_Global    = "Op_Get_Global",
	.Op_Get_Elem      = "Op_Get_Elem",
	.Op_Get_Field     = "Op_Get_Field",
	.Op_Bind          = "Op_Bind",
	.Op_Set           = "Op_Set",
	.Op_Set_Global    = "Op_Set_Global",
	.Op_Set_Elem      = "Op_Set_Elem",
	.Op_Set_Field     = "Op_Set_Field",
	.Op_Make_Instance = "Op_Make_Instance",
	.Op_Make_Array    = "Op_Make_Array",
	.Op_Append_Array  = "Op_Append_Array",
	.Op_Make_Map      = "Op_Make_Map",
	.Op_Length        = "Op_Length",
}

print_chunk :: proc(p: ^Debug_Printer, c: ^Chunk) {
	if len(c.bytecode) == 0 {
		return
	}
	write_line(p, "=======================")
	write_line(p, "== CHUNK DISASSEMBLY ==")
	fmt.sbprintf(&p.builder, "\nbyte count: %d", len(c.bytecode))
	write_line(p)
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

	debug_get_byte :: proc(c: ^Chunk, ip: ^int) -> byte {
		ip^ += 1
		return c.bytecode[ip^ - 1]
	}

	debug_get_i16 :: proc(c: ^Chunk, ip: ^int) -> i16 {
		ip^ += 2
		lower := c.bytecode[ip^ - 2]
		upper := c.bytecode[ip^ - 1]
		return i16(upper) << 8 | i16(lower)
	}

	ip := 0

	for {
		print_ip(p, ip)
		op := Op_Code(debug_get_byte(c, &ip))
		write(p, op_code_str[op])
		format(p, op_code_str[op], max_str)
		switch op {
		case .Op_None, .Op_Push, .Op_Pop, .Op_Push_Back:
			fmt.sbprintf(&p.builder, " ||")

		case .Op_Move:
			fmt.sbprintf(&p.builder, " || move addr: %d", debug_get_i16(c, &ip))

		case .Op_Copy:
			fmt.sbprintf(&p.builder, " || copy addr: %d", debug_get_i16(c, &ip))

		case .Op_Const:
			fmt.sbprintf(&p.builder, " || const addr: %d", debug_get_i16(c, &ip))

		case .Op_Module:
			fmt.sbprintf(&p.builder, " || module addr: %d", debug_get_i16(c, &ip))

		case .Op_Prototype:
			fmt.sbprintf(&p.builder, " || class addr: %d", debug_get_i16(c, &ip))

		case .Op_Inc, .Op_Dec, .Op_Neg, .Op_Not:
			fmt.sbprintf(&p.builder, " ||")

		case .Op_Add, .Op_Mul, .Op_Div, .Op_Rem, .Op_And, .Op_Or, .Op_Eq, .Op_Greater, .Op_Greater_Eq, .Op_Lesser, .Op_Lesser_Eq:
			fmt.sbprintf(&p.builder, " ||")

		case .Op_Begin, .Op_End:
			fmt.sbprintf(&p.builder, " ||")

		case .Op_Call, .Op_Call_Foreign, .Op_Call_Method, .Op_Call_Constr:
			fmt.sbprintf(&p.builder, " || fn addr: %d", debug_get_i16(c, &ip))

		case .Op_Return:
			fmt.sbprintf(&p.builder, " || result stack addr: %d", debug_get_i16(c, &ip))

		case .Op_Jump, .Op_Jump_False, .Op_Jump_True:
			fmt.sbprintf(&p.builder, " || jump addr: %d", debug_get_i16(c, &ip))

		case .Op_Get, .Op_Get_Global, .Op_Set, .Op_Set_Global:
			fmt.sbprintf(&p.builder, " || var addr: %d", debug_get_i16(c, &ip))

		case .Op_Get_Elem, .Op_Set_Elem:
			fmt.sbprintf(&p.builder, " ||")

		case .Op_Get_Field, .Op_Set_Field:
			fmt.sbprintf(&p.builder, " || field addr: %d", debug_get_i16(c, &ip))

		case .Op_Bind:
			fmt.sbprintf(
				&p.builder,
				" || var addr: %d  ==  relative stack id: %d",
				debug_get_i16(c, &ip),
				debug_get_i16(c, &ip),
			)

		case .Op_Make_Instance, .Op_Make_Array, .Op_Append_Array, .Op_Length:
			fmt.sbprintf(&p.builder, " ||")

		case .Op_Make_Map:
			fmt.sbprintf(&p.builder, " || init element count: %d", debug_get_i16(c, &ip))
		}
		if ip >= len(c.bytecode) {
			break
		}

		write_line(p)
	}

}

print_module_variables :: proc(m: ^Compiled_Module, name: string) {
	p := Debug_Printer {
		builder      = strings.builder_make(),
		indent_width = 2,
	}
	defer strings.builder_destroy(&p.builder)
	write_line(&p, name)
	write(&p, " Module Variables:")
	increment(&p)
	for global in m.variables {
		write_line(&p)
		print_value(&p, global)
	}
	decrement(&p)
	fmt.println(strings.to_string(p.builder))
}

print_stack :: proc(vm: ^Vm, op := Op_Code.Op_None) {
	printer := Debug_Printer {
		builder      = strings.builder_make(),
		indent_width = 2,
	}
	defer strings.builder_destroy(&printer.builder)

	write_line(&printer, "========================= \n")
	write(&printer, "== VM STACK DEBUG VIEW == \n")
	fmt.sbprintf(&printer.builder, "Current Op Code: %s\n", op_code_str[op])

	for value, i in vm.stack[:vm.stack_ptr] {
		fmt.sbprintf(&printer.builder, "%03d   ", i)
		print_value(&printer, value)
		if i == vm.header_addr && vm.stack_depth > 0 {
			write(&printer, "     <- Scope Header")
		} else if i == vm.header_addr + 1 && vm.stack_depth > 0 {
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
				strings.write_rune(&p.builder, r)
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

		case .Map:
			map_object := cast(^Map_Object)data
			write(p, `[`)
			for key, value in map_object.data {
				print_value(p, key)
				write(p, ` = `)
				print_value(p, value)
				write(p, `,`)
			}
			write(p, `]`)

		case .Fn:
		case .Class:
			class_object := cast(^Class_Object)data
			fmt.sbprintf(&p.builder, "%p [", class_object)
			// write(p, `[`)
			for field, i in class_object.fields {
				fmt.sbprintf(&p.builder, "%d: ", i)
				print_value(p, field)
				write(p, `,`)
			}
			write(p, `]`)
		}
	case:
		write(p, "Nil")
	}
}
