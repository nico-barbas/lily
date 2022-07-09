package lily

import "core:fmt"


Semantic_Scope :: struct {
	id:       Scope_ID,
	symbols:  [dynamic]Symbol,
	lookup:   map[string]^Symbol,
	parent:   ^Semantic_Scope,
	children: map[Scope_ID]^Semantic_Scope,
}

Scope_ID :: distinct int

Symbol :: struct {
	name:      string,
	kind:      enum {
		Name,
		Generic_Symbol,
		Alias_Symbol,
		Class_Symbol,
		Fn_Symbol,
		Var_Symbol,
		Module_Symbol,
	},
	type_id:   Type_ID,
	module_id: int,
	scope_id:  Scope_ID,
	info:      union {
		Module_Symbol_Info,
		Generic_Symbol_Info,
		Alias_Symbol_Info,
		Class_Symbol_Info,
		Fn_Symbol_Info,
		Var_Symbol_Info,
	},
}

Module_Symbol_Info :: struct {
	ref_mod_id: int,
}

Generic_Symbol_Info :: struct {
	symbol: ^Symbol,
}

Alias_Symbol_Info :: struct {
	symbol: ^Symbol,
}


Class_Symbol_Info :: struct {
	sub_scope_id: Scope_ID,
}

Var_Symbol_Info :: struct {
	symbol:  ^Symbol,
	mutable: bool,
}

Fn_Symbol_Info :: struct {
	sub_scope_id:  Scope_ID,
	has_return:    bool,
	kind:          Fn_Kind,
	param_symbols: []^Symbol,
	return_symbol: ^Symbol,
}

is_type_symbol :: proc(s: ^Symbol) -> bool {
	return s.kind == .Alias_Symbol || s.kind == .Name || s.kind == .Class_Symbol
}

is_valis_accessor :: proc(s: ^Symbol) -> bool {
	#partial switch s.kind {
	case .Class_Symbol:
		return true
	case .Generic_Symbol:
		if s.type_id == ARRAY_ID {
			return true
		} else {
			return false
		}
	case:
		return false
	}
}

new_scope :: proc() -> ^Semantic_Scope {
	scope := new(Semantic_Scope)
	scope.symbols = make([dynamic]Symbol)
	scope.lookup = make(map[string]^Symbol)
	scope.children = make(map[Scope_ID]^Semantic_Scope)
	return scope
}

free_scope :: proc(s: ^Semantic_Scope) {
	for _, children in s.children {
		free_scope(children)
	}
	delete(s.symbols)
	delete(s.lookup)
	delete(s.children)
	free(s)
}


add_symbol_to_scope :: proc(s: ^Semantic_Scope, symbol: Symbol, shadow := false) -> (
	result: ^Symbol,
	err: Error,
) {
	if !shadow && contain_scoped_symbol(s, symbol.name) {
		err = Semantic_Error {
			kind    = .Redeclared_Symbol,
			details = fmt.tprintf("Redeclared symbol: %s", symbol.name),
		}
		return
	}
	append(&s.symbols, symbol)
	result = &s.symbols[len(s.symbols) - 1]
	s.lookup[symbol.name] = result
	return
}

contain_scoped_symbol :: proc(s: ^Semantic_Scope, name: string) -> bool {
	if _, exist := s.lookup[name]; exist {
		return true
	}
	return false
}

get_scoped_symbol :: proc(s: ^Semantic_Scope, name: Token, loc := #caller_location) -> (
	result: ^Symbol,
	err: Error,
) {
	if symbol, exist := s.lookup[name.text]; exist {
		result = symbol
	} else {
		err =
			format_semantic_err(
				Semantic_Error{
					kind = .Unknown_Symbol,
					token = name,
					details = fmt.tprintf("Unknown symbol %s in scope %d", name.text, s.id),
				},
				loc,
			)
	}
	return
}
