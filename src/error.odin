package lily

Error :: union {
	Parsing_Error,
	Semantic_Error,
}

Parsing_Error :: struct {
	kind:    enum {
		Invalid_Syntax,
		Malformed_Number,
	},
	token:   Token,
	details: string,
}

Semantic_Error :: enum {
	Invalid_Symbol,
	Unknown_Symbol,
	Redeclared_Symbol,
	Mismatched_Types,
	Invalid_Arg_Count,
	Invalid_Type_Operation,
}
