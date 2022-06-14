package lily

// TODO: Embed the module ID inside the Type_ID

Type_ID :: distinct int
UNTYPED_ID :: 0
UNTYPED_NUMBER_ID :: 1
UNTYPED_BOOL_ID :: 2
UNTYPED_STRING_ID :: 3
NUMBER_ID :: 4
BOOL_ID :: 5
STRING_ID :: 6
FN_ID :: 7
ARRAY_ID :: 8
BUILT_IN_ID_COUNT :: ARRAY_ID + 1

UNTYPED_INFO :: Type_Info {
	name      = "untyped",
	type_id   = UNTYPED_ID,
	type_kind = .Builtin,
}
UNTYPED_NUMBER_INFO :: Type_Info {
	name      = "untyped number",
	type_id   = UNTYPED_NUMBER_ID,
	type_kind = .Builtin,
}
UNTYPED_BOOL_INFO :: Type_Info {
	name      = "untyped bool",
	type_id   = UNTYPED_BOOL_ID,
	type_kind = .Builtin,
}
UNTYPED_STRING_INFO :: Type_Info {
	name      = "untyped string",
	type_id   = UNTYPED_STRING_ID,
	type_kind = .Builtin,
}
NUMBER_INFO :: Type_Info {
	name      = "number",
	type_id   = NUMBER_ID,
	type_kind = .Builtin,
}
BOOL_INFO :: Type_Info {
	name      = "bool",
	type_id   = BOOL_ID,
	type_kind = .Builtin,
}
STRING_INFO :: Type_Info {
	name      = "string",
	type_id   = STRING_ID,
	type_kind = .Builtin,
}
// FIXME: ?? Why do we need this
FN_INFO :: Type_Info {
	name      = "fn",
	type_id   = FN_ID,
	type_kind = .Builtin,
}
ARRAY_INFO :: Type_Info {
	name      = "array",
	type_id   = ARRAY_ID,
	type_kind = .Builtin,
}

Module_ID :: distinct int
BUILTIN_MODULE_ID :: 0

Scope_ID :: distinct int

Type_Alias_Info :: struct {
	underlying_type_id: Type_ID,
}

Generic_Type_Info :: struct {
	spec_type_id: Type_ID,
}

Fn_Signature_Info :: struct {
	parameters:     []Type_Info,
	return_type_id: Type_ID,
}

Class_Definition_Info :: struct {
	fields:       []Type_Info,
	constructors: []Type_Info,
	methods:      []Type_Info,
}

Type_Info :: struct {
	name:         string,
	type_id:      Type_ID,
	type_kind:    enum {
		Builtin,
		Elementary_Type,
		Type_Alias,
		Fn_Type,
		Class_Type,
		Generic_Type,
	},
	type_id_data: union {
		Type_Alias_Info,
		Generic_Type_Info,
		Fn_Signature_Info,
		Class_Definition_Info,
	},
}

is_untyped_type :: proc(t: Type_Info) -> bool {
	return t.type_id == UNTYPED_NUMBER_ID || t.type_id == UNTYPED_BOOL_ID || t.type_id == UNTYPED_STRING_ID
}

// In Lily, a truthy type can be of only 2 kind:
// - of Boolean type (BOOL_ID)
// - of a type alias with a parent of type Untyped Bool (UNTYPED_BOOL_ID)
is_truthy_type :: proc(t: Type_Info) -> bool {
	#partial switch t.type_kind {
	case .Builtin:
		if t.type_id == BOOL_ID || t.type_id == UNTYPED_BOOL_ID {
			return true
		}
	case .Type_Alias:
		parent := t.type_id_data.(Type_Alias_Info)
		if parent.underlying_type_id == UNTYPED_BOOL_ID {
			return true
		}
	}
	return false
}

is_numerical_type :: proc(t: Type_Info) -> bool {
	#partial switch t.type_kind {
	case .Builtin:
		if t.type_id == NUMBER_ID || t.type_id == UNTYPED_NUMBER_ID {
			return true
		}
	case .Type_Alias:
		parent := t.type_id_data.(Type_Alias_Info)
		if parent.underlying_type_id == UNTYPED_NUMBER_ID {
			return true
		}
	}
	return false
}

// Rules of type aliasing:
// - Type alias is incompatible with the parent type; a value from the parent type
// cannot be assigned to a variable from the type alias
// - Type alias inherits all the fields and methods of the parent
// - Type alias conserve the same capabilities as their parent (only applicable for native types)
// i.e: an alias of type bool can still be used for conditional (considered "truthy")  
//
// EXAMPLE: Following type alias scenario should eval to true
// type MyNumber is number
// var foo: MyNumber = 10
//
// |- foo: MyNumber and |- 10: untyped number
// Number Literal are of type "untyped number" 
// and coherced to right type upon evaluation
// FIXME: Probably needs a rewrite at some point
type_equal :: proc(c: ^Checker, t0, t1: Type_Info) -> (result: bool) {
	if t0.type_id == t1.type_id {
		if t0.type_kind == t1.type_kind {
			#partial switch t0.type_kind {
			case .Generic_Type:
				t0_generic_id := t0.type_id_data.(Generic_Type_Info)
				t1_generic_id := t1.type_id_data.(Generic_Type_Info)
				if t0_generic_id.spec_type_id == t1_generic_id.spec_type_id {
					result = true
				}
			case:
				result = true
			}
		} else {
			assert(false, "Invalid type equality branch")
		}
	} else if t0.type_kind == .Type_Alias || t1.type_kind == .Type_Alias {
		alias: Type_Alias_Info
		other: Type_Info
		if t0.type_kind == .Type_Alias {
			alias = t0.type_id_data.(Type_Alias_Info)
			other = t1
		} else {
			alias = t1.type_id_data.(Type_Alias_Info)
			other = t0
		}
		if is_untyped_type(other) {
			parent_type := get_type_from_id(c, alias.underlying_type_id)
			result = type_equal(c, parent_type, other)
		}

	} else if is_untyped_type(t0) || is_untyped_type(t1) {
		untyped_t: Type_Info
		typed_t: Type_Info
		other: Type_Info
		if is_untyped_type(t0) {
			untyped_t = t0
			other = t1
		} else {
			untyped_t = t1
			other = t0
		}
		switch untyped_t.type_id {
		case UNTYPED_NUMBER_ID:
			typed_t = NUMBER_INFO
		case UNTYPED_BOOL_ID:
			typed_t = BOOL_INFO
		case UNTYPED_STRING_ID:
			typed_t = STRING_INFO
		}
		result = type_equal(c, typed_t, other)
	}
	return
}
