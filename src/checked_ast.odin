package lily

import "core:fmt"
import "core:hash"
import "core:strings"

// In Lily, type and function declaration is only 
// allowed at the file scope. This means that all the
// type infos can be kept at one place,
Checked_Module :: struct {
	name:         string,
	// This is all the nodes at the file level
	nodes:        [dynamic]Checked_Node,
	functions:    [dynamic]Checked_Node,
	classes:      [dynamic]Checked_Node,
	// types:       [dynamic]Type_Info,
	type_lookup:  map[string]Type_Info,
	type_count:   int,

	// symbols
	symbol_table: Symbol_Table,
}

new_checked_module :: proc() -> ^Checked_Module {
	m := new_clone(
		Checked_Module{
			nodes = make([dynamic]Checked_Node),
			functions = make([dynamic]Checked_Node),
			classes = make([dynamic]Checked_Node),
			type_lookup = make(map[string]Type_Info),
		},
	)
	init_symbol_table(&m.symbol_table, m.name)
	return m
}

get_class_decl :: proc(m: ^Checked_Module, type_id: Type_ID) -> ^Checked_Class_Declaration {
	for class in m.classes {
		c := class.(^Checked_Class_Declaration)
		if c.type_info.type_id == type_id {
			return c
		}
	}
	return nil
}

Checked_Expression :: struct {
	expr:      Expression,
	type_info: Type_Info,
}

Checked_Node :: union {
	^Checked_Expression_Statement,
	^Checked_Block_Statement,
	^Checked_Assigment_Statement,
	^Checked_If_Statement,
	^Checked_Range_Statement,
	^Checked_Var_Declaration,
	^Checked_Fn_Declaration,
	^Checked_Type_Declaration,
	^Checked_Class_Declaration,
}

Checked_Expression_Statement :: struct {
	token: Token,
	expr:  Checked_Expression,
}

Checked_Block_Statement :: struct {
	nodes: [dynamic]Checked_Node,
}

Checked_Assigment_Statement :: struct {
	token: Token,
	left:  Checked_Expression,
	right: Checked_Expression,
}

Checked_If_Statement :: struct {
	token:       Token,
	condition:   Checked_Expression,
	body:        Checked_Node,
	next_branch: Checked_Node,
}

Checked_Range_Statement :: struct {
	token:              Token,
	iterator_name:      Token,
	iterator_type_info: Type_Info,
	low:                Checked_Expression,
	high:               Checked_Expression,
	reverse:            bool,
	op:                 Range_Operator,
	body:               Checked_Node,
}

Checked_Var_Declaration :: struct {
	token:       Token,
	identifier:  Token,
	type_info:   Type_Info,
	expr:        Checked_Expression,
	initialized: bool,
}

Checked_Fn_Declaration :: struct {
	token:       Token,
	identifier:  Token,
	body:        Checked_Node,
	type_info:   Type_Info,
	param_names: []Token,
}

Checked_Type_Declaration :: struct {
	token:      Token,
	is_token:   Token,
	identifier: Token,
	type_info:  Type_Info,
}

Checked_Class_Declaration :: struct {
	token:        Token,
	is_token:     Token,
	identifier:   Token,
	type_info:    Type_Info,
	field_names:  []Token,
	constructors: []^Checked_Fn_Declaration,
	methods:      []^Checked_Fn_Declaration,
}

// Symbol table stuff

Semantic_Scope :: struct {
	id:             Scope_ID,
	symbols:        [dynamic]Symbol,
	variable_types: map[string]Type_Info,
	parent:         ^Semantic_Scope,
	children:       [dynamic]^Semantic_Scope,
}

Symbol :: union {
	string,
	Composite_Symbol,
}

Composite_Symbol :: struct {
	name:     string,
	scope_ip: Scope_ID,
}

new_scope :: proc() -> ^Semantic_Scope {
	scope := new(Semantic_Scope)
	scope.symbols = make([dynamic]Symbol)
	scope.variable_types = make(map[string]Type_Info)
	scope.children = make([dynamic]^Semantic_Scope)
	return scope
}

delete_scope :: proc(s: ^Semantic_Scope) {
	delete(s.symbols)
	free(s)
}

add_scoped_symbol :: proc(s: ^Semantic_Scope, token: Token, shadow := false) -> (err: Error) {
	if !shadow && contain_scoped_symbol(s, token.text) {
		return Semantic_Error{
			kind = .Redeclared_Symbol,
			token = token,
			details = fmt.tprintf("Redeclared symbol: %s", token.text),
		}
	}

	append(&s.symbols, token.text)
	return
}

add_scoped_composite_symbol :: proc(
	s: ^Semantic_Scope,
	token: Token,
	scope_id: Scope_ID,
	shadow := false,
) -> (
	err: Error,
) {
	if !shadow && contain_scoped_symbol(s, token.text) {
		return Semantic_Error{
			kind = .Redeclared_Symbol,
			token = token,
			details = fmt.tprintf("Redeclared symbol: %s", token.text),
		}
	}

	append(&s.symbols, Composite_Symbol{name = token.text, scope_ip = scope_id})
	return
}

contain_scoped_symbol :: proc(s: ^Semantic_Scope, name: string) -> bool {
	for symbol in s.symbols {
		switch smbl in symbol {
		case string:
			if smbl == name {
				return true
			}
		case Composite_Symbol:
			if smbl.name == name {
				return true
			}
		}
	}
	return false
}

Symbol_Table :: struct {
	module_name:  string,
	class_scopes: map[Scope_ID]^Semantic_Scope,
	scope:        ^Semantic_Scope,
	scope_depth:  int,
}

init_symbol_table :: proc(s: ^Symbol_Table, name: string) {
	s.module_name = name
	s.class_scopes = make(map[Scope_ID]^Semantic_Scope)
	s.scope = new_scope()
	s.scope_depth = 0
}

format_scope_name :: proc(s: ^Symbol_Table, name: Token) -> (result: string) {
	result = strings.concatenate(
		{s.module_name, name.text, fmt.tprint(name.line, name.start)},
		context.temp_allocator,
	)
	return
}

hash_scope_id :: proc(s: ^Symbol_Table, name: Token) -> Scope_ID {
	scope_name := format_scope_name(s, name)
	defer delete(scope_name)
	return Scope_ID(hash.fnv32(transmute([]u8)scope_name))
}

push_scope :: proc(s: ^Symbol_Table, name: Token) -> Scope_ID {
	scope := new_scope()
	scope.id = hash_scope_id(s, name)
	append(&s.scope.children, scope)
	scope.parent = s.scope
	s.scope = scope
	s.scope_depth += 1
	return scope.id
}

push_existing_scope :: proc(s: ^Symbol_Table, scope: ^Semantic_Scope) {
	for child in scope.children {
		if child.id == scope.id {
			return
		}
	}
	append(&s.scope.children, scope)
	s.scope = scope
	s.scope_depth += 1
}

add_class_scope :: proc(s: ^Symbol_Table, scope_id: Scope_ID) {
	get_child_scope :: proc(s: ^Semantic_Scope, scope_id: Scope_ID) -> ^Semantic_Scope {
		for child in s.children {
			if child.id == scope_id {
				return child
			}
			scope := get_child_scope(child, scope_id)
			if scope != nil {
				return scope
			}
		}
		return nil
	}

	current := s.scope
	for current.parent != nil {
		current = current.parent
	}

	class_scope := get_child_scope(current, scope_id)
	s.class_scopes[scope_id] = class_scope
}

enter_child_scope :: proc(s: ^Symbol_Table, name: Token) -> (err: Error) {
	scope_id := hash_scope_id(s, name)
	for scope in s.scope.children {
		if scope.id == scope_id {
			s.scope = scope
			return
		}
	}
	err = Internal_Error {
		kind    = .Unknown_Scope_Name,
		details = fmt.tprintf("Scope #%i not known", scope_id),
	}
	return
}

enter_child_scope_by_id :: proc(s: ^Symbol_Table, scope_id: Scope_ID) -> (err: Error) {
	for scope in s.scope.children {
		if scope.id == scope_id {
			s.scope = scope
			return
		}
	}
	err = Internal_Error {
		kind    = .Unknown_Scope_Name,
		details = fmt.tprintf("Scope #%i not known", scope_id),
	}
	return
}

enter_parent_scope_by_id :: proc(s: ^Symbol_Table, scope_id: Scope_ID) -> (err: Error) {
	scope := s.scope
	find: for scope != nil {
		if scope.id == scope_id {
			push_existing_scope(s, scope)
			return
		}
		scope = scope.parent
	}
	err = Internal_Error {
		kind    = .Unknown_Scope_Name,
		details = fmt.tprintf("Scope #%i not known", scope_id),
	}
	return
}


pop_scope :: proc(s: ^Symbol_Table) {
	scope := s.scope
	s.scope = scope.parent
	s.scope_depth -= 1
}

get_class_scope :: proc(s: ^Symbol_Table, scope_id: Scope_ID) -> ^Semantic_Scope {
	return s.class_scopes[scope_id]
}
