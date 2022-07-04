package lily

import "core:fmt"


Semantic_Scope :: struct {
	id:           Scope_ID,
	symbols:      [dynamic]Symbol,
	class_lookup: map[string]struct {
		symbol_index: int,
		scope_index:  int,
	},
	var_lookup:   map[string]int,
	parent:       ^Semantic_Scope,
	children:     [dynamic]^Semantic_Scope,
}

Scope_ID :: distinct int

Symbol :: struct {
	name:         string,
	kind:         enum {
		Name,
		Alias_Symbol,
		Class_Symbol,
		Fn_Symbol,
		Var_Symbol,
		Module_Symbol,
	},
	type_id:      Type_ID,
	module_id:    int,
	scope_id:     Scope_ID,
	generic_info: struct {
		is_generic: bool,
		symbol:     ^Symbol,
	},
	alias_info:   struct {
		symbol: ^Symbol,
	},
	class_info:   struct {
		class_scope_id: Scope_ID,
	},
	var_info:     struct {
		symbol:    ^Symbol,
		is_ref:    bool,
		immutable: bool,
	},
	fn_info:      struct {
		scope_id:      Scope_ID,
		has_return:    bool,
		constructor:   bool,
		return_symbol: ^Symbol,
	},
	module_info:  struct {
		ref_module_id: int,
	},
}

is_ref_symbol :: proc(s: ^Symbol) -> bool {
	#partial switch s.kind {
	case .Alias_Symbol:
		return is_ref_symbol(s.alias_info.symbol)
	case .Class_Symbol:
		return true
	}
	return false
}

is_type_symbol :: proc(s: ^Symbol) -> bool {
	return s.kind == .Alias_Symbol || s.kind == .Name || s.kind == .Class_Symbol
}

// builtin_container_symbols :: [?]string{"len", "append"}

// is_builtin_container_symbol :: proc(s: string) -> bool {
// 	for symbol in builtin_container_symbols {
// 		if s == symbol {
// 			return true
// 		}
// 	}
// 	return false
// }

new_scope :: proc() -> ^Semantic_Scope {
	scope := new(Semantic_Scope)
	scope.symbols = make([dynamic]Symbol)
	scope.var_lookup = make(map[string]int)
	scope.children = make([dynamic]^Semantic_Scope)
	return scope
}

free_scope :: proc(s: ^Semantic_Scope) {
	for children in s.children {
		free_scope(children)
	}
	delete(s.symbols)
	delete(s.var_lookup)
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
	if symbol.kind == .Var_Symbol {
		s.var_lookup[symbol.name] = len(s.symbols) - 1
	}
	return
}

contain_scoped_symbol :: proc(s: ^Semantic_Scope, name: string) -> bool {
	for symbol in s.symbols {
		if symbol.name == name {
			return true
		}
	}
	return false
}

get_scoped_symbol :: proc(s: ^Semantic_Scope, name: Token) -> (
	result: ^Symbol,
	err: Error,
) {
	for symbol, i in s.symbols {
		if symbol.name == name.text {
			result = &s.symbols[i]
			return
		}
	}
	err = Semantic_Error {
			kind    = .Unknown_Symbol,
			token   = name,
			details = fmt.tprintf("Unknown symbol %s in scope %d", name.text, s.id),
		}
	return
}

get_scoped_var_symbol :: proc(s: ^Semantic_Scope, name: Token) -> (
	result: ^Symbol,
	err: Error,
) {
	if var_index, exist := s.var_lookup[name.text]; exist {
		result = &s.symbols[var_index]
	} else {
		err = Semantic_Error {
				kind    = .Unknown_Symbol,
				token   = name,
				details = fmt.tprintf("No variable symbol with name %s", name.text),
			}
	}
	return
}

get_scoped_class_symbol :: proc(s: ^Semantic_Scope, name: Token) -> (
	result: ^Symbol,
	err: Error,
) {
	result = &s.symbols[s.class_lookup[name.text].symbol_index]
	return
}
