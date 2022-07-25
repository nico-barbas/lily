package lily

// TODO: remove the hard-coded length of parameters and arguments in functions

// Values are runtime representation of different object kinds.
// For now, they do not store type informations.
// There is 2 main types of values: basic values and reference values
// Basic values are Number, Bool.
// Reference values are String, Array, Map, Function, Class.

Value_Kind :: enum {
	Nil,
	Number,
	Boolean,
	Object_Ref,
}

Value_Data :: union {
	f64,
	bool,
	^Object,
}

Value :: struct {
	kind: Value_Kind,
	data: Value_Data,
}

data_to_value :: proc(data: Value_Data) -> Value {
	v := Value {
		data = data,
	}
	switch d in data {
	case bool:
		v.kind = .Boolean
	case f64:
		v.kind = .Number
	case ^Object:
		assert(false)
	}
	return v
}

value_equal :: proc(v1, v2: Value) -> bool {
	if v1.kind == v2.kind {
		switch v1.kind {
		case .Nil:
			return true
		case .Number:
			return v1.data.(f64) == v2.data.(f64)
		case .Boolean:
			return v1.data.(bool) == v2.data.(bool)
		case .Object_Ref:
			return false
		}
	}
	return false
}

Object_Kind :: enum {
	String,
	Array,
	Map,
	Fn,
	Class,
}

Object :: struct {
	kind: Object_Kind,
}

String_Object :: struct {
	using base: Object,
	data:       []rune,
}

Array_Object :: struct {
	using base: Object,
	data:       [dynamic]Value,
}

Map_Object :: struct {
	using base: Object,
	data:       map[Value]Value,
}

Fn_Kind :: enum {
	Builtin,
	Foreign,
	Constructor,
	Method,
	Function,
}

Fn_Object :: struct {
	using base: Object,
	chunk:      Chunk,
	foreign_fn: Foreign_Procedure,
}

Class_Object :: struct {
	using base: Object,
	fields:     []Value,
	vtable:     ^Class_Vtable,
}

Class_Vtable :: struct {
	constructors: []Fn_Object,
	methods:      []Fn_Object,
}

new_string_object :: proc(from := "") -> Value {
	str_object := new_clone(String_Object{base = Object{kind = .String}, data = make([]rune, len(from))})
	for r, i in from {
		str_object.data[i] = r
	}
	return Value{kind = .Object_Ref, data = cast(^Object)str_object}
}

new_array_object :: proc() -> Value {
	return Value{
		kind = .Object_Ref,
		data = cast(^Object)new_clone(
			Array_Object{base = Object{kind = .Array}, data = make([dynamic]Value)},
		),
	}
}

new_map_object :: proc() -> Value {
	return Value{
		kind = .Object_Ref,
		data = cast(^Object)new_clone(Map_Object{base = Object{kind = .Map}, data = make(map[Value]Value)}),
	}
}

free_object :: proc(object: ^Object) {
	switch object.kind {
	case .String:
	case .Array:
	case .Map:
	case .Fn:
		fn_object := cast(^Fn_Object)object
	// delete_chunk(&fn_object.chunk)
	case .Class:
		class_object := cast(^Class_Object)object
		// FIXME: Need to recursively delete fields
		for field in class_object.fields {
			if field_object, ok := field.data.(^Object); ok {
				free_object(field_object)
			}
		}
	// delete_chunk(class_object.fields)
	}
}

token_to_operator :: proc(kind: Token_Kind) -> Operator {
	#partial switch kind {
	case .Not:
		return .Not_Op
	case .Plus:
		return .Plus_Op
	case .Minus:
		return .Minus_Op
	case .Star:
		return .Mult_Op
	case .Slash:
		return .Div_Op
	case .Percent:
		return .Rem_Op
	case .And:
		return .And_Op
	case .Or:
		return .Or_Op
	case .Equal:
		return .Equal_Op
	case .Greater:
		return .Greater_Op
	case .Greater_Equal:
		return .Greater_Eq_Op
	case .Lesser:
		return .Lesser_Op
	case .Lesser_Equal:
		return .Lesser_Eq_Op
	case:
		// This is a bit dodgy, but the operator has already been checked
		// by the parse_expr() and there is no way it is an invalid Token_Kind
		return .Plus_Op
	}
}

Operator :: enum {
	Not_Op,
	Minus_Op,
	Plus_Op,
	Mult_Op,
	Div_Op,
	Rem_Op,
	Or_Op,
	And_Op,
	Equal_Op,
	Greater_Op,
	Greater_Eq_Op,
	Lesser_Op,
	Lesser_Eq_Op,
}

Range_Operator :: enum {
	Inclusive,
	Exclusive,
}

Control_Flow_Operator :: enum {
	Break,
	Continue,
}
