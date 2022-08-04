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
		v.kind = .Object_Ref
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
	kind:          Object_Kind,
	marked:        bool,
	traced:        bool,
	tracing_color: Trace_Color,
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

Fn_Kind_Set :: bit_set[Fn_Kind]

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

zero_value :: proc(kind: Value_Kind) -> (value: Value) {
	value.kind = kind
	switch kind {
	case .Nil, .Object_Ref:
	case .Boolean:
		value.data = false
	case .Number:
		value.data = 0
	}
	return
}

new_string_object :: proc(from := "", allocator := context.allocator) -> Value {
	object := new(String_Object, allocator)
	object^ = String_Object {
		base = Object{kind = .String},
		data = make([]rune, len(from), allocator),
	}
	for r, i in from {
		object.data[i] = r
	}
	return Value{kind = .Object_Ref, data = cast(^Object)object}
}

new_array_object :: proc(allocator := context.allocator) -> Value {
	object := new(Array_Object, allocator)
	object^ = Array_Object {
		base = Object{kind = .Array},
		data = make([dynamic]Value, allocator),
	}
	return Value{kind = .Object_Ref, data = cast(^Object)object}
}

new_map_object :: proc(allocator := context.allocator) -> Value {
	DEFAULT_MAP_SIZE :: 16

	object := new(Map_Object, allocator)
	object^ = Map_Object {
		base = Object{kind = .Map},
		data = make(map[Value]Value, DEFAULT_MAP_SIZE, allocator),
	}
	return Value{kind = .Object_Ref, data = cast(^Object)object}
}

new_class_object :: proc(prototype: ^Class_Object, allocator := context.allocator) -> Value {
	object := new(Class_Object)
	object^ = Class_Object {
		base = Object{kind = .Class},
		fields = make([]Value, len(prototype.fields), allocator),
		vtable = prototype.vtable,
	}
	for field, i in prototype.fields {
		object.fields[i] = field
	}
	return Value{kind = .Object_Ref, data = cast(^Object)object}
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

assign_token_to_operator :: proc(kind: Token_Kind) -> Operator {
	#partial switch kind {
	case .Plus_Assign:
		return .Plus_Op
	case .Minus_Assign:
		return .Minus_Op
	case .Mul_Assign:
		return .Mult_Op
	case .Div_Assign:
		return .Div_Op
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
