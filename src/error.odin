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
	kind:    enum {
		Invalid_Symbol,
		Unknown_Symbol,
		Redeclared_Symbol,
		Redeclared_Type,
		Mismatched_Types,
		Invalid_Arg_Count,
		Invalid_Type_Operation,
		Invalid_Class_Constructor_Usage,
	},
	token:   Token,
	details: string,
}

Internal_Error :: struct {
	kind:         enum {
		Unknown_Scope_Name,
	},
	details:      string,
	compiler_loc: runtime.Source_Code_Location,
}
