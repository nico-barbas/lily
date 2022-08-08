package lily

Token_Kind :: enum {
	EOF,
	Newline,
	Comment,
	Identifier,

	// Keywords
	_keyword_start_,
	Import,
	Foreign,
	Var,
	Fn,
	Type,
	Is,
	Class,
	Enum,
	Constructor,
	Self,
	Return,
	Result,
	If,
	Else,
	For,
	Match,
	When,
	Break,
	Continue,
	In,
	End,
	True,
	False,
	Any,
	Number,
	Boolean,
	String,
	Array,
	Map,
	Of,
	_keyword_end_,

	// Literals
	_literal_start_,
	Number_Literal,
	String_Literal,
	_literal_end_,

	// Operators
	_operator_start_,
	Assign,
	Plus_Assign,
	Minus_Assign,
	Mul_Assign,
	Div_Assign,
	Equal,
	Lesser,
	Lesser_Equal,
	Greater,
	Greater_Equal,
	Not,
	And,
	Or,
	Plus,
	Minus,
	Star,
	Slash,
	Percent,
	_operator_end_,

	// Punctuation
	_punctuation_start_,
	Dot,
	Double_Dot,
	Triple_Dot,
	Colon,
	Comma,
	Open_Paren,
	Close_Paren,
	Open_Bracket,
	Close_Bracket,
	_punctuation_end_,
}

Token_Kind_Group :: bit_set[Token_Kind]

Token :: struct {
	kind:   Token_Kind,
	text:   string,
	line:   int,
	column: Span,
	offset: Span,
}

Span :: struct {
	start: int,
	end:   int,
}

keywords := map[string]Token_Kind {
	"import"      = .Import,
	"foreign"     = .Foreign,
	"var"         = .Var,
	"fn"          = .Fn,
	"type"        = .Type,
	"is"          = .Is,
	"class"       = .Class,
	"enum"        = .Enum,
	"constructor" = .Constructor,
	"self"        = .Self,
	"return"      = .Return,
	"result"      = .Result,
	"if"          = .If,
	"else"        = .Else,
	"for"         = .For,
	"match"       = .Match,
	"when"        = .When,
	"break"       = .Break,
	"continue"    = .Continue,
	"in"          = .In,
	"end"         = .End,
	"not"         = .Not,
	"and"         = .And,
	"or"          = .Or,
	"true"        = .True,
	"false"       = .False,
	"any"         = .Any,
	"number"      = .Number,
	"bool"        = .Boolean,
	"string"      = .String,
	"array"       = .Array,
	"map"         = .Map,
	"of"          = .Of,
}

Lexer :: struct {
	input:   string,
	current: int,
	line:    int,
	column:  int,
}

set_lexer_input :: proc(l: ^Lexer, input: string) {
	l.input = input
	l.line = 1
	l.current = 0
}

scan_token :: proc(l: ^Lexer) -> (t: Token) {
	skip_whitespace(l)
	if is_eof(l) {
		t.kind = .EOF
		return
	}
	t.offset.start = l.current
	t.column.start = l.column
	t.line = l.line
	c := advance(l)
	switch c {
	case '\n':
		t.kind = .Newline
		l.line += 1
		l.column = 0

	case '"':
		t.kind = .String_Literal
		string_loop: for {
			if is_eof(l) || advance(l) == '"' {
				break string_loop
			}
		}

	case '=':
		if peek(l) == '=' {
			advance(l)
			t.kind = .Equal
		} else {
			t.kind = .Assign
		}

	case '<':
		if peek(l) == '=' {
			advance(l)
			t.kind = .Lesser_Equal
		} else {
			t.kind = .Lesser
		}

	case '>':
		if peek(l) == '=' {
			advance(l)
			t.kind = .Greater_Equal
		} else {
			t.kind = .Greater
		}

	case '+':
		if peek(l) == '=' {
			advance(l)
			t.kind = .Plus_Assign
		} else {
			t.kind = .Plus
		}

	case '-':
		next := peek(l)
		switch next {
		case '-':
			advance(l)
			t.kind = .Comment
			comment_loop: for {
				if is_eof(l) || peek(l) == '\n' {
					break comment_loop
				} else {
					advance(l)
				}
			}
		case '=':
			advance(l)
			t.kind = .Minus_Assign

		case:
			t.kind = .Minus
		}
	case '*':
		if peek(l) == '=' {
			advance(l)
			t.kind = .Mul_Assign
		} else {
			t.kind = .Star
		}

	case '/':
		if peek(l) == '=' {
			advance(l)
			t.kind = .Div_Assign
		} else {
			t.kind = .Slash
		}

	case '%':
		t.kind = .Percent

	case '.':
		// FIXME: Probably crashes if a malformed number is put at the end of the file
		// or a double dot 
		t.kind = .Dot
		if peek(l) == '.' {
			advance(l)
			t.kind = .Double_Dot
			if peek(l) == '.' {
				advance(l)
				t.kind = .Triple_Dot
			}
		}
	case ':':
		t.kind = .Colon
	case ',':
		t.kind = .Comma
	case '(':
		t.kind = .Open_Paren
	case ')':
		t.kind = .Close_Paren
	case '[':
		t.kind = .Open_Bracket
	case ']':
		t.kind = .Close_Bracket

	case:
		switch {
		case is_letter(c) || c == '_':
			identifier: for {
				if is_eof(l) {
					break identifier
				}
				next := peek(l)
				if is_letter(next) || is_number(next) || next == '_' {
					advance(l)
				} else {
					break identifier
				}
			}
			word := text_from_span(l, {t.offset.start, l.current})
			t.kind = lex_identifier(word)

		case is_number(c):
			has_decimal := false
			number: for {
				if is_eof(l) {
					break number
				}
				next := peek(l)
				if next == '.' && is_number(peek_next(l)) {
					if !has_decimal {
						has_decimal = true
						advance(l)
					} else {
						break number
					}
				} else if is_number(next) {
					advance(l)
				} else {
					break number
				}
			}
			t.kind = .Number_Literal
		case: // ??
		}
	}
	t.offset.end = l.current
	t.column.end = l.column
	t.text = text_from_span(l, t.offset)
	return
}

is_eof :: proc(l: ^Lexer) -> bool {
	return l.current >= len(l.input)
}

is_number :: proc(c: byte) -> bool {
	return c >= '0' && c <= '9'
}

is_letter :: proc(c: byte) -> bool {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

is_type_token :: proc(t: Token_Kind) -> bool {
	return t == .Identifier || t == .Number || t == .Boolean
}

is_assign_token :: proc(t: Token_Kind) -> bool {
	#partial switch t {
	case .Assign, .Plus_Assign, .Minus_Assign, .Mul_Assign, .Div_Assign:
		return true
	case:
		return false
	}
}

lex_identifier :: proc(word: string) -> Token_Kind {
	if kind, exist := keywords[word]; exist {
		return kind
	} else {
		return .Identifier
	}
}

advance :: proc(l: ^Lexer) -> byte {
	l.current += 1
	l.column += 1
	return l.input[l.current - 1]
}

peek :: proc(l: ^Lexer) -> byte {
	return l.input[l.current]
}

peek_next :: proc(l: ^Lexer) -> byte {
	return l.input[l.current + 1]
}

skip_whitespace :: proc(l: ^Lexer) {
	skip: for {
		if is_eof(l) {
			break skip
		}
		c := peek(l)
		if c == ' ' || c == '\r' || c == '\t' || c == '\b' {
			advance(l)
		} else {
			break skip
		}
	}
}

text_from_span :: proc(l: ^Lexer, s: Span) -> string {
	return l.input[s.start:s.end]
}
