package lily

import "core:runtime"

Error :: union {
	Parsing_Error,
	Semantic_Error,
	Internal_Error,
}

Parsing_Error :: struct {
	kind:    enum {
		Invalid_Syntax,
		Malformed_Number,
	},
	token:   Token,
	details: string,
}

Semantic_Error :: struct {
	kind:         enum {
		Invalid_Declaration,
		Invalid_Symbol,
		Unknown_Symbol,
		Redeclared_Symbol,
		Redeclared_Type,
		Mismatched_Types,
		Invalid_Arg_Count,
		Invalid_Type_Operation,
		Invalid_Dot_Operand,
		Invalid_Class_Constructor_Usage,
		Invalid_Class_Field_Access,
	},
	compiler_loc: runtime.Source_Code_Location,
	token:        Token,
	details:      string,
}

format_semantic_err :: proc(err: Semantic_Error, loc := #caller_location) -> Semantic_Error {
	result := err
	result.compiler_loc = loc
	return result
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
