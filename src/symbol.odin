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
	type_info:    Type_Info,
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

get_scoped_symbol :: proc(s: ^Semantic_Scope, name: Token) -> (result: ^Symbol, err: Error) {
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

get_scoped_var_symbol :: proc(s: ^Semantic_Scope, name: Token) -> (result: ^Symbol, err: Error) {
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


// update_scoped_symbol :: proc(s: ^Semantic_Scope, index: int, symbol: Symbol) {
// 	s.symbols[index] = symbol
// }


// get_scoped_symbol :: proc(s: ^Semantic_Scope, name: string) -> (
// 	result: Symbol,
// 	index: int,
// 	exist: bool,
// ) {
// 	for symbol, i in s.symbols {
// 		if symbol.name == name {
// 			result = symbol
// 			index = i
// 			exist = true
// 			break
// 		}
// 	}
// 	return
// }

// init_symbol_table :: proc(c: ^Checked_Module) {
// 	c.class_lookup = make(map[string]struct {
// 			name:       string,
// 			class_id:   int,
// 			scope_id:   Scope_ID,
// 			root_index: int,
// 		})
// 	c.scope = new_scope()
// 	c.root = c.scope
// 	c.scope_depth = 0
// }


// push_class_scope :: proc(c: ^Checked_Module, name: Token) -> (err: Error) {
// 	assert(c.scope.id == c.root.id, "Can only declare Class at the root of a module")
// 	class_scope := new_scope()
// 	class_scope.id = hash_scope_id(c, name)
// 	class_scope.parent = c.scope
// 	add_symbol_to_scope(
// 		c.scope,
// 		Symbol{
// 			name = name.text,
// 			kind = .Class_Ref_Symbol,
// 			module_id = c.id,
// 			scope_id = c.scope.id,
// 			ref_module_id = c.id,
// 			ref_scope_id = class_scope.id,
// 		},
// 	) or_return
// 	add_symbol_to_scope(
// 		class_scope,
// 		Symbol{
// 			name = "self",
// 			kind = .Class_Ref_Symbol,
// 			module_id = c.id,
// 			scope_id = class_scope.id,
// 			ref_module_id = c.id,
// 			ref_scope_id = class_scope.id,
// 		},
// 	) or_return
// 	append(&c.scope.children, class_scope)
// 	c.class_lookup[name.text] = {
// 		name       = name.text,
// 		scope_id   = class_scope.id,
// 		root_index = len(c.scope.children) - 1,
// 	}
// 	c.scope = class_scope
// 	c.scope_depth += 1
// 	return
// }

// enter_child_scope_by_id :: proc(c: ^Checked_Module, scope_id: Scope_ID, loc := #caller_location) -> (
// 	err: Error,
// ) {
// 	for scope in c.scope.children {
// 		if scope.id == scope_id {
// 			c.scope = scope
// 			c.scope_depth += 1
// 			return
// 		}
// 	}
// 	err = Internal_Error {
// 		kind         = .Unknown_Scope_Name,
// 		details      = fmt.tprintf("Scope #%i not known", scope_id),
// 		compiler_loc = loc,
// 	}
// 	return
// }

// enter_class_scope :: proc(c: ^Checked_Module, name: Token) -> (err: Error) {
// 	class_lookup_info := c.class_lookup[name.text]
// 	c.scope = c.root.children[class_lookup_info.root_index]
// 	c.scope_depth = 1
// 	return
// }

// enter_class_scope_by_id :: proc(c: ^Checked_Module, scope_id: Scope_ID, loc := #caller_location) -> (
// 	err: Error,
// ) {
// 	for _, class_lookup in c.class_lookup {
// 		if class_lookup.scope_id == scope_id {
// 			c.scope = c.root.children[class_lookup.root_index]
// 			c.scope_depth = 1
// 			return
// 		}
// 	}
// 	err = Internal_Error {
// 		kind         = .Unknown_Scope_Name,
// 		details      = fmt.tprintf("Scope #%i not known", scope_id),
// 		compiler_loc = loc,
// 	}
// 	return
// }


// get_class_scope_from_name :: proc(c: ^Checked_Module, name: string) -> ^Semantic_Scope {
// 	class_lookup, exist := c.class_lookup[name]
// 	if !exist {
// 		return nil
// 	} else {
// 		return c.root.children[class_lookup.root_index]
// 	}
// }

// get_class_scope_from_id :: proc(c: ^Checked_Module, scope_id: Scope_ID) -> ^Semantic_Scope {
// 	for _, class_lookup in c.class_lookup {
// 		if class_lookup.scope_id == scope_id {
// 			return c.root.children[class_lookup.root_index]
// 		}
// 	}
// 	return nil
// }
