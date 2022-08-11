package lily

import "core:mem"
import "core:runtime"
// import "core:fmt"

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
	kind: Object_Kind,
}

String_Object :: struct {
	using base: Object,
	data:       []rune,
}

Array_Object :: struct {
	using base: Object,
	data:       []Value,
	cap:        int,
	len:        int,
	allocator:  mem.Allocator,
	size:       int,
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

object_size :: #force_inline proc(object: ^Object) -> (size: int) {
	switch object.kind {
	case .String:
		string_object := cast(^String_Object)object
		size += size_of(String_Object)
		size += len(string_object.data) * size_of(rune)
	case .Array:
		array_object := cast(^Array_Object)object
		size += size_of(Array_Object)
		size += len(array_object.data) * size_of(Value)
	case .Map:
		map_object := cast(^Map_Object)object
		size += size_of(Map_Object)
		header := runtime.__get_map_header(&map_object.data)
		cap := cap(map_object.data)
		size += header.entry_size * cap
		size += cap * 2 * size_of(header.m.hashes)

	case .Fn:
		assert(false)
	case .Class:
		class_object := cast(^Class_Object)object
		size += size_of(Class_Object)
		size += len(class_object.fields) * size_of(Value)
	}
	return size
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
	value := Value {
		kind = .Object_Ref,
		data = cast(^Object)object,
	}
	return value
}

DEFAULT_ARRAY_SIZE :: 16
new_array_object :: proc(allocator := context.allocator) -> Value {
	object := new(Array_Object, allocator)
	object^ = Array_Object {
		base = Object{kind = .Array},
		data = make([]Value, DEFAULT_ARRAY_SIZE, allocator),
		len = 0,
		cap = DEFAULT_ARRAY_SIZE,
		allocator = allocator,
		size = size_of(Value) * DEFAULT_ARRAY_SIZE,
	}
	value := Value {
		kind = .Object_Ref,
		data = cast(^Object)object,
	}
	return value
}

array_object_resize :: proc(array: ^Array_Object) {
	old := array.data
	array.cap *= 2
	array.size = size_of(Value) * array.cap
	array.data = make([]Value, array.cap, array.allocator)
	copy(array.data[:array.len], old[:])
	delete(old)
}

array_object_append :: proc(array: ^Array_Object, value: Value) {
	if array.len >= array.cap {
		array_object_resize(array)
	}
	array.data[array.len] = value
	array.len += 1
}

DEFAULT_MAP_SIZE :: 32
new_map_object :: proc(allocator := context.allocator) -> Value {

	object := new(Map_Object, allocator)
	object^ = Map_Object {
		base = Object{kind = .Map},
		data = make(map[Value]Value, DEFAULT_MAP_SIZE, allocator),
	}
	return Value{kind = .Object_Ref, data = cast(^Object)object}
}

new_class_object :: proc(prototype: ^Class_Object, allocator := context.allocator) -> Value {
	object := new(Class_Object, allocator)
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

free_object :: proc(object: ^Object, allocator: mem.Allocator) {
	switch object.kind {
	case .String:
		object := cast(^String_Object)object
		delete(object.data, allocator)
		free(object, allocator)
	case .Array:
		object := cast(^Array_Object)object
		delete(object.data, allocator)
		free(object, allocator)
	case .Map:
		object := cast(^Map_Object)object
		delete(object.data)
		free(object, allocator)
	case .Fn:
		assert(false)
	case .Class:
		object := cast(^Class_Object)object
		delete(object.fields, allocator)
		free(object, allocator)
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
