package tools

import "core:fmt"
import "core:strings"

Print_Item :: struct {
	document:      ^Document,
	indentation:   int,
	force_newline: bool,
}

print_newline :: proc(f: ^Formatter, item: Print_Item, should_indent: bool) {
	strings.write_string(&f.builder, f.newline)
	f.written = len(f.newline)
	if should_indent {
		for i in 0 ..< item.indentation {
			strings.write_string(&f.builder, f.indentation)
			f.written += len(f.indentation)
		}
	}
}

print_document :: proc(f: ^Formatter, allocator := context.allocator) -> (result: string, ok: bool) {
	list := make([dynamic]Print_Item, allocator)
	start := Print_Item {
		document      = f.document,
		indentation   = 0,
		force_newline = false,
	}
	append(&list, start)

	recalculate := false

	for len(list) > 0 {
		item := pop(&list)

		f.document_left = max(0, f.document_left - 1)
		if f.document_left == 0 {
			f.state = .Fit
		}
		if item.force_newline && f.state == .Break {
			print_newline(f, item, true)
		}
		switch d in item.document {
		case Document_Nil:

		case Document_Text:
			strings.write_string(&f.builder, d.value)
			f.written += len(d.value)

		case Document_Newline:
			for i in 0 ..< d.count - 1 {
				print_newline(f, item, false)
			}
			print_newline(f, item, true)

		case Document_Nest:
			nested := Print_Item {
				document      = d.document,
				indentation   = item.indentation + 1,
				force_newline = item.force_newline,
			}
			append(&list, nested)

		case Document_Spacing:
			for i in 0 ..< d.count {
				strings.write_string(&f.builder, d.value)
				f.written += len(d.value)
			}

		case Document_List:
			indentation := item.indentation
			force_newline := false
			if .Can_Break in d.modifiers {
				if !fits(f, item.document) {
					if .Nest_If_Break in d.modifiers {
						indentation += 1
					}
					force_newline = .Force_Newline in d.modifiers
				}
			}

			for i := len(d.elements) - 1; i >= 0; i -= 1 {
				inner := Print_Item {
					document      = d.elements[i],
					indentation   = indentation,
					force_newline = force_newline,
				}
				append(&list, inner)
			}

		case Document_If_Break:
			if f.state == .Break {
				if_item := Print_Item {
					document      = d.document,
					indentation   = item.indentation,
					force_newline = item.force_newline,
				}
				append(&list, if_item)
			}
		}
	}

	result = strings.to_string(f.builder)
	return
}

fits :: proc(f: ^Formatter, document: ^Document) -> (ok: bool) {
	list := make([dynamic]^Document)
	append(&list, document)

	width := 0
	count := 0

	loop: for len(&list) > 0 {
		next := pop(&list)
		count += 1

		switch d in next {
		case Document_Nil, Document_Nest:
			continue loop

		case Document_Text:
			width += len(d.value)

		case Document_Newline:
			break loop

		case Document_Spacing:
			width += len(d.value) * d.count

		case Document_List:
			for i := len(d.elements) - 1; i >= 0; i -= 1 {
				append(&list, d.elements[i])
			}

		case Document_If_Break:
			append(&list, d.document)
		}
	}
	max_width := f.basic_width
	if f.content == .Fn_Signature {
		max_width = f.fn_signature_width
	}

	ok = f.written + width <= max_width
	if !ok {
		if f.state != .Break {
			f.document_left = count
		}
		f.state = .Break
	}
	return
}
