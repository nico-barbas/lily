package tools

Document :: union {
	Document_Nil,
	Document_Text,
	Document_Newline,
	Document_Spacing,
	Document_Nest,
	Document_List,
	Document_If_Break,
}

Document_Nil :: struct {}

Document_Text :: struct {
	value: string,
}

Document_Newline :: struct {
	count: int,
}

Document_Spacing :: struct {
	value: string,
	count: int,
}

Document_Nest :: struct {
	document: ^Document,
}

Document_List :: struct {
	modifiers: Format_Modifiers,
	elements:  [dynamic]^Document,
}

Document_If_Break :: struct {
	document: ^Document,
}

Format_Modifier :: enum {
	None,
	Nest_If_Break,
	Can_Break,
	Force_Newline,
}

Format_Modifiers :: bit_set[Format_Modifier]

empty :: proc(allocator := context.allocator) -> (result: ^Document) {
	return new(Document, allocator)
}

text :: proc(value: string, allocator := context.allocator) -> (result: ^Document) {
	result = new(Document, allocator)
	result^ = Document_Text {
		value = value,
	}
	return
}

text_if_break :: proc(
	value: string,
	allocator := context.allocator,
) -> (
	result: ^Document,
) {
	result = new(Document, allocator)
	result^ = Document_If_Break {
		document = text(value, allocator),
	}
	return
}

newline :: proc(count: int, allocator := context.allocator) -> (result: ^Document) {
	result = new(Document, allocator)
	result^ = Document_Newline {
		count = count,
	}
	return
}

newline_if_break :: proc(
	count: int,
	allocator := context.allocator,
) -> (
	result: ^Document,
) {
	result = new(Document, allocator)
	result^ = Document_If_Break {
		document = newline(count, allocator),
	}
	return
}

space :: proc(
	spacing := " ",
	count: int = 1,
	allocator := context.allocator,
) -> (
	result: ^Document,
) {
	result = new(Document, allocator)
	result^ = Document_Spacing {
		value = spacing,
		count = count,
	}
	return
}

space_if_break :: proc(
	spacing := " ",
	count: int = 1,
	allocator := context.allocator,
) -> (
	result: ^Document,
) {
	result = new(Document, allocator)
	result^ = Document_If_Break {
		document = space(spacing, count, allocator),
	}
	return
}

nest :: proc(
	document: ^Document,
	allocator := context.allocator,
) -> (
	result: ^Document,
) {
	result = new(Document, allocator)
	result^ = Document_Nest {
		document = document,
	}
	return
}

list :: proc(
	elements: ..^Document,
	mod: Format_Modifiers = {.None},
	allocator := context.allocator,
) -> (
	result: ^Document,
) {
	list := make([dynamic]^Document, allocator)
	for elem in elements {
		#partial switch e in elem {
		case Document_Nil:
			continue
		case:
			append(&list, e)
		}
	}
	result = new(Document)
	result^ = Document_List {
		elements  = list,
		modifiers = mod,
	}
	return
}

join :: proc(
	document: ^Document_List,
	elements: ..^Document,
	allocator := context.allocator,
) {
	for elem in elements {
		#partial switch e in elem {
		case Document_Nil:
			continue
		case:
			append(&document.elements, e)
		}
	}
}
