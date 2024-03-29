package tools

import "core:strings"
import "core:os"
import "core:slice"
import "core:sort"
import "core:fmt"
import lily "../lib"

Formatter :: struct {
	module:             ^lily.Parsed_Module,
	document:           ^Document,
	last_comment:       int,

	// Runtime states
	state:              Format_State,
	content:            Content_Kind,
	builder:            strings.Builder,
	written:            int,
	document_left:      int,

	// Configs
	indentation:        string,
	newline:            string,
	max_newlines:       int,
	basic_width:        int,
	fn_signature_width: int,
}

Format_State :: enum {
	Fit,
	Break,
}

Content_Kind :: enum {
	Basic,
	Fn_Signature,
}

Format_Error_Code :: enum {
	Invalid_File_Path,
	Source_Parsing_Error,
}

Format_Error :: Maybe(Format_Error_Code)

format_file :: proc(filepath: string, allocator := context.allocator) -> Format_Error {
	source, read_ok := os.read_entire_file(filepath, allocator)
	if !read_ok {
		return .Invalid_File_Path
	}

	module := lily.make_parsed_module("main")
	parse_ok := lily.parse_module(string(source), module)
	if !parse_ok {
		return .Source_Parsing_Error
	}

	output, _ := build_module_document(module, allocator)
	os.write_entire_file(filepath, transmute([]byte)output)
	return nil
}

build_module_document :: proc(module: ^lily.Parsed_Module, allocator := context.allocator) -> (string, bool) {
	context.allocator = allocator

	f := new(Formatter)
	f^ = Formatter {
		module             = module,
		indentation        = "\t",
		newline            = "\n",
		basic_width        = 90,
		fn_signature_width = 120,
	}

	document := list()
	list := cast(^Document_List)document
	for node in module.import_nodes {
		join(list, format_import_stmt(f, node.(^lily.Parsed_Import_Statement)))
	}
	join(list, newline(1))


	roots := slice.concatenate(
		[][]lily.Parsed_Node{module.types[:], module.functions[:], module.variables[:], module.nodes[:]},
		allocator,
	)
	sort.sort(sort.Interface {
		len = proc(it: sort.Interface) -> int {
			roots := cast(^[]lily.Parsed_Node)it.collection
			return len(roots)
		},
		less = proc(it: sort.Interface, i, j: int) -> bool {
			roots := cast(^[]lily.Parsed_Node)it.collection
			i_token, j_token := lily.parsed_node_token(roots[i]), lily.parsed_node_token(roots[j])
			return i_token.line < j_token.line
		},
		swap = proc(it: sort.Interface, i, j: int) {
			roots := cast(^[]lily.Parsed_Node)it.collection
			roots[i], roots[j] = roots[j], roots[i]
		},
		collection = &roots,
	})

	previous_line := len(module.import_nodes) + 1
	for node in roots {
		current_line := lily.parsed_node_token(node).line
		if current_line - previous_line > 1 {
			join(list, newline(1))
		}
		node_document := format_stmt(f, node, false)
		node_document = format_comment(f, node_document, current_line)
		join(list, node_document, newline(1))
		previous_line = current_line
	}

	f.document = document
	return print_document(f)
}

format_stmt :: proc(f: ^Formatter, node: lily.Parsed_Node, add_newline := true) -> ^Document {
	using lily

	switch n in node {
	case ^Parsed_Expression_Statement:
		document := list(format_expr(f, n.expr))
		list := cast(^Document_List)document
		if add_newline {
			join(list, newline(1))
		}
		return document


	case ^Parsed_Block_Statement:
		document := list(newline(1))
		list := cast(^Document_List)document
		for inner_node, i in n.nodes {
			last_elem := i == len(n.nodes) - 1
			join(list, format_stmt(f, inner_node, !last_elem))
		}
		if add_newline {
			join(list, newline(1))
		}
		return nest(document)

	case ^Parsed_Assignment_Statement:
		document := list(
			format_expr(f, n.left),
			space(),
			text(n.token.text),
			space(),
			format_expr(f, n.right),
		)
		if add_newline {
			join(cast(^Document_List)document, newline(1))
		}
		return document


	case ^Parsed_If_Statement:
		document := list()
		outer := cast(^Document_List)document
		if !n.is_alternative {
			join(outer, text("if"), space(), format_expr(f, n.condition))
		}
		join(outer, text(":"))
		join(outer, format_stmt(f, n.body, false), newline(1))
		if n.next_branch != nil {
			join(outer, text("else"))
			if !n.next_branch.is_alternative {
				join(outer, text(" "))
			}
			join(outer, format_stmt(f, n.next_branch))
		} else {
			join(outer, text("end"), newline(1))
		}

		if add_newline {
			join(outer, newline(1))
		}
		return document


	case ^Parsed_Match_Statement:
		document := list(text("match"), space(), format_expr(f, n.evaluation), text(":"))
		outer := cast(^Document_List)document
		for c, i in n.cases {
			// inner_document :=
			inner := list(newline(1), text("when"), space(), format_expr(f, c.condition), text(":"))
			join(cast(^Document_List)inner, format_stmt(f, c.body, false), newline(1), text("end"))
			join(outer, nest(inner))
			if i != len(n.cases) - 1 {
				join(outer, newline(1))
			}
		}
		join(outer, newline(1), text("end"))
		if add_newline {
			join(outer, newline(1))
		}
		return document


	case ^Parsed_Flow_Statement:
		document := list(text(n.token.text))
		if add_newline {
			join(cast(^Document_List)document, newline(1))
		}
		return document

	case ^Parsed_Range_Statement:
		document := list(
			text("for"),
			space(),
			text(n.iterator_name.text),
			space(),
			text("in"),
			space(),
			format_expr(f, n.low),
			space(),
			text(n.op_token.text),
			space(),
			format_expr(f, n.high),
			text(":"),
			format_stmt(f, n.body, false),
			newline(1),
			text("end"),
		)
		list := cast(^Document_List)document
		if add_newline {
			join(cast(^Document_List)document, newline(1))
		}
		return document

	case ^Parsed_Import_Statement:


	case ^Parsed_Return_Statement:
		document := list(text("return"))
		if add_newline {
			join(cast(^Document_List)document, newline(1))
		}
		return document


	case ^Parsed_Field_Declaration:


	case ^Parsed_Var_Declaration:
		document := list(text("var"), space(), text(n.identifier.text))
		list := cast(^Document_List)document
		if n.type_expr != nil {
			if type_expr, ok := n.type_expr.(^Parsed_Identifier_Expression); ok {
				if type_expr.name.text != "untyped" {
					join(list, text(":"), format_expr(f, n.type_expr))
				}
			} else {
				join(list, text(":"), format_expr(f, n.type_expr))
			}
		}
		join(list, space())
		if n.expr != nil {
			join(list, text("="), space(), format_expr(f, n.expr))
		}
		if add_newline {
			join(list, newline(1))
		}
		return document

	case ^Parsed_Fn_Declaration:
		document := list(elements = {}, mod = {.Can_Break})
		list := cast(^Document_List)document

		#partial switch n.kind {
		case .Foreign:
			join(list, text("foreign"), space(), text("fn"), space())
		case .Constructor:
			join(list, text("constructor"), space())
		case .Method, .Function:
			join(list, text("fn"), space())
		}
		join(
			list,
			text(n.identifier.text),
			text("("),
			format_fn_signature(f, n),
			newline_if_break(1),
			text(")"),
			text(":"),
			format_expr(f, n.return_type_expr),
			newline(1),
		)

		if n.kind != .Foreign {
			join(list, format_stmt(f, n.body, false))
		}
		join(list, newline(1))

		join(list, text("end"))
		if add_newline {
			join(list, newline(1))
		}
		return document

	case ^Parsed_Type_Declaration:
		document := list(text("type"), space(), text(n.identifier.text), space(), text("is"), space())
		list := cast(^Document_List)document
		switch n.type_kind {
		case .Class:
			join(list, text("class"), nest(format_class_decl(f, n)), newline(1), text("end"))
		case .Enum:
			join(list, text("enum"), nest(format_enum_decl(f, n)), newline(1), text("end"))
		case .Alias:
		}
		if add_newline {
			join(list, newline(1))
		}
		return document
	}
	return empty()
}

format_import_stmt :: proc(f: ^Formatter, node: ^lily.Parsed_Import_Statement) -> ^Document {
	return list(text("import"), space(), text(node.identifier.text), newline(1))
}

format_fn_signature :: proc(f: ^Formatter, decl: ^lily.Parsed_Fn_Declaration) -> ^Document {
	document := list(elements = {}, mod = {.Nest_If_Break, .Force_Newline, .Can_Break})
	outer := cast(^Document_List)document

	max_len := -1
	max_at := 0
	for field, i in decl.parameters {
		current_len := field_name_len(field)
		if current_len > max_len {
			max_len = current_len
			max_at = i
		}
	}

	for param, i in decl.parameters {
		last_param := i == len(decl.parameters) - 1
		inner := list(
			format_expr(f, param.name),
			text(":"),
			space_if_break(" ", max(1, max_len) if i != max_at else 1),
			format_expr(f, param.type_expr.?),
			text(",") if !last_param else text_if_break(","),
		)
		if !last_param {
			join(cast(^Document_List)inner, space())
		}
		join(outer, inner)
	}
	return document
}

format_class_decl :: proc(f: ^Formatter, decl: ^lily.Parsed_Type_Declaration) -> ^Document {
	document := list(newline(1))
	list := cast(^Document_List)document
	join(list, format_field_list(f, decl.fields[:]))
	for constructor, i in decl.constructors {
		join(list, newline(1), format_stmt(f, constructor))
		if i != len(decl.constructors) - 1 {
			join(list, newline(1))
		}
	}
	for method, i in decl.methods {
		join(list, newline(1), format_stmt(f, method, false))
		if i != len(decl.methods) - 1 {
			join(list, newline(1))
		}
	}
	return document
}

format_enum_decl :: proc(f: ^Formatter, decl: ^lily.Parsed_Type_Declaration) -> ^Document {
	document := list(newline(1), format_field_list(f, decl.fields[:]))
	return document
}

format_field_list :: proc(f: ^Formatter, fields: []^lily.Parsed_Field_Declaration) -> ^Document {
	document := list()
	list := cast(^Document_List)document
	max_len := -1
	max_at := 0
	for field, i in fields {
		current_len := field_name_len(field)
		if current_len > max_len {
			max_len = current_len
			max_at = i
		}
	}
	for field, i in fields {
		if field.type_expr == nil {
			join(list, format_expr(f, field.name), newline(1))
		} else {
			join(
				list,
				format_expr(f, field.name),
				text(":"),
				space(" ", max(1, max_len) if i != max_at else 1),
				format_expr(f, field.type_expr.?),
				newline(1),
			)
		}
	}
	return document
}

field_name_len :: proc(field: ^lily.Parsed_Field_Declaration) -> int {
	return len(field.name.(^lily.Parsed_Identifier_Expression).name.text)
}


format_expr :: proc(f: ^Formatter, expr: lily.Parsed_Expression) -> ^Document {
	using lily

	switch e in expr {
	case ^Parsed_Literal_Expression:
		return text(e.token.text)


	case ^Parsed_String_Literal_Expression:
		return list(text(`"`), text(e.value), text(`"`))


	case ^Parsed_Array_Literal_Expression:
		document := list(elements = {format_expr(f, e.type_expr), text("[")}, mod = {.Can_Break})
		list := cast(^Document_List)document
		join(list, format_expr_list(f, e.values[:]), newline_if_break(1), text("]"))
		return document


	case ^Parsed_Map_Literal_Expression:
		document := list(elements = {format_expr(f, e.type_expr), text("[")}, mod = {.Can_Break})
		list := cast(^Document_List)document
		join(list, format_map_elements(f, e.elements[:]), newline_if_break(1), text("]"))
		return document


	case ^Parsed_Unary_Expression:
		return list(text(e.token.text), format_expr(f, e.expr))

	case ^Parsed_Binary_Expression:
		document := list()
		list := cast(^Document_List)document
		if !is_assign_token(e.token.kind) {
			join(list, format_expr(f, e.left), text(e.token.text))
		}
		join(list, format_expr(f, e.right))
		return document

	case ^Parsed_Identifier_Expression:
		return text(e.name.text)

	case ^Parsed_Index_Expression:
		return list(format_expr(f, e.left), text("["), format_expr(f, e.index), text("]"))


	case ^Parsed_Dot_Expression:
		return list(format_expr(f, e.left), text("."), format_expr(f, e.selector))


	case ^Parsed_Call_Expression:
		document := list(elements = {format_expr(f, e.func), text("(")}, mod = {.Can_Break})
		list := cast(^Document_List)document
		join(list, format_expr_list(f, e.args[:]), newline_if_break(1), text(")"))
		return document


	case ^Parsed_Array_Type_Expression:
		return list(text("array"), space(), text("of"), space(), format_expr(f, e.elem_type))


	case ^Parsed_Map_Type_Expression:
		return(
			list(
				text("map"),
				space(),
				text("of"),
				space(),
				text("("),
				format_expr(f, e.key_type),
				text(","),
				space(),
				format_expr(f, e.value_type),
				text(")"),
			) \
		)
	}
	return empty()
}

format_expr_list :: proc(f: ^Formatter, exprs: []lily.Parsed_Expression) -> ^Document {
	document := list(elements = {}, mod = {.Nest_If_Break, .Force_Newline, .Can_Break})
	outer := cast(^Document_List)document
	for expr, i in exprs {
		last_param := i == len(exprs) - 1
		inner := list(format_expr(f, expr), text(",") if !last_param else text_if_break(","))
		if !last_param {
			join(cast(^Document_List)inner, space())
		}
		join(outer, inner)
	}
	return document
}

format_map_elements :: proc(f: ^Formatter, elements: []lily.Parsed_Map_Element) -> ^Document {
	document := list(elements = {}, mod = {.Nest_If_Break, .Force_Newline, .Can_Break})
	outer := cast(^Document_List)document
	for elem, i in elements {
		last_param := i == len(elements) - 1
		inner := list(
			format_expr(f, elem.key),
			space(),
			text("="),
			space(),
			format_expr(f, elem.value),
			text(",") if !last_param else text_if_break(","),
		)
		if !last_param {
			join(cast(^Document_List)inner, space())
		}
		join(outer, inner)
	}
	return document
}

format_comment :: proc(f: ^Formatter, previous: ^Document, line: int) -> ^Document {
	document := previous
	comments: ^Document
	comment_list: ^Document_List
	to := -1
	for comment, i in f.module.comments[f.last_comment:] {
		if comment.line < line {
			if i == 0 {
				comments = list()
				comment_list = cast(^Document_List)comments
			}
			join(comment_list, text(comment.text), newline(1))
			to = f.last_comment + i
		} else if comment.line == line {
			document = list(document, text(comment.text))
			to = f.last_comment + i
			break
		} else {
			break
		}
	}
	if to >= 0 {
		f.last_comment = to + 1
	}
	if comments != nil {
		return list(comments, document)
	} else {
		return document
	}
}
