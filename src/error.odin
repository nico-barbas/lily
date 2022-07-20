package lily

import "core:runtime"
import "core:fmt"

Error :: union {
	Parsing_Error,
	Semantic_Error,
	Internal_Error,
}

format_error :: proc(err: Error, loc := #caller_location) -> Error {
	return set_error_location(err, loc)
}

set_error_location :: proc(err: Error, loc := #caller_location) -> (result: Error) {
	switch e in err {
	case Parsing_Error:
		r := e
		r.compiler_loc = loc
		result = r
	case Semantic_Error:
		r := e
		r.compiler_loc = loc
		result = r
	case Internal_Error:
		r := e
		r.compiler_loc = loc
		result = r
	}
	return
}

Parsing_Error :: struct {
	kind:         enum {
		Invalid_Syntax,
		Malformed_Number,
	},
	compiler_loc: runtime.Source_Code_Location,
	token:        Token,
	details:      string,
}

// format_parsing_err :: proc(err: Parsing_Error)

Semantic_Error :: struct {
	kind:         enum {
		Dependency_Cycle,
		Invalid_Symbol,
		Unknown_Symbol,
		Redeclared_Symbol,
		Mismatched_Types,
		Invalid_Mutability,
		Invalid_Arity,
		Unhandled_Match_Cases,
	},
	compiler_loc: runtime.Source_Code_Location,
	token:        Token,
	details:      string,
}

rhs_assign_semantic_err :: proc(s: ^Symbol, t: Token, loc := #caller_location) -> Error {
	return format_error(
		Semantic_Error{
			kind = .Invalid_Symbol,
			token = t,
			details = fmt.tprintf("Cannot assign %s", s.name),
		},
		loc,
	)
}

lhs_assign_semantic_err :: proc(s: ^Symbol, t: Token, loc := #caller_location) -> Error {
	return format_error(
		Semantic_Error{
			kind = .Invalid_Symbol,
			token = t,
			details = fmt.tprintf("Cannot assign to %s", s.name),
		},
		loc,
	)
}

mutable_semantic_err :: proc(s: ^Symbol, t: Token, loc := #caller_location) -> Error {
	return format_error(
		Semantic_Error{
			kind = .Invalid_Mutability,
			token = t,
			details = fmt.tprintf("Cannot assign to %s, %s is not mutable", s.name, s.name),
		},
		loc,
	)
}

index_semantic_err :: proc(s: ^Symbol, t: Token, loc := #caller_location) -> Error {
	return format_error(
		Semantic_Error{
			kind = .Invalid_Symbol,
			token = t,
			details = fmt.tprintf("Symbol %s is not indexable", s.name),
		},
		loc,
	)
}

arity_semantic_err :: proc(s: ^Symbol, t: Token, count: int, loc := #caller_location) -> Error {
	fn_info := s.info.(Fn_Symbol_Info)
	return format_error(
		Semantic_Error{
			kind = .Invalid_Arity,
			token = t,
			details = fmt.tprintf("Expected %d arguments, got %d", len(fn_info.param_symbols), count),
		},
		loc,
	)
}

call_semantic_err :: proc(s: ^Symbol, t: Token, loc := #caller_location) -> Error {
	return format_error(
		Semantic_Error{
			kind = .Invalid_Symbol,
			token = t,
			details = fmt.tprintf("Symbol %s is not a valid call target", s.name),
		},
		loc,
	)
}

dot_operand_semantic_err :: proc(s: ^Symbol, t: Token, loc := #caller_location) -> Error {
	return format_error(
		Semantic_Error{
			kind = .Invalid_Symbol,
			token = t,
			details = fmt.tprintf("Symbol %s is not a valid dot operand", s.name),
		},
		loc,
	)
}

Internal_Error :: struct {
	kind:         enum {
		Unknown_Scope_Name,
	},
	details:      string,
	compiler_loc: runtime.Source_Code_Location,
}

error_message :: proc(err: Error) -> string {
	switch e in err {
	case Parsing_Error:
		return e.details
	case Semantic_Error:
		return e.details
	case Internal_Error:
		return e.details
	case:
		return ""
	}
}
