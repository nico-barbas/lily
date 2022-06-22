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

Value :: struct {
	kind: Value_Kind,
	data: union {
		f64,
		bool,
		^Object,
	},
}

Object_Kind :: enum {
	String,
	Array,
	// Map,
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

Fn_Object :: struct {
	using base: Object,
	chunk:      Chunk,
}

Class_Object :: struct {
	using base: Object,
	fields:     []Class_Field,
	vtable:     ^Class_Vtable,
}

Class_Field :: struct {
	name:  string,
	value: Value,
}

Class_Vtable :: struct {
	constructors: []Fn_Object,
	methods:      []Fn_Object,
}

free_object :: proc(object: ^Object) {
	switch object.kind {
	case .String:
	case .Array:
	case .Fn:
		fn_object := cast(^Fn_Object)object
	// delete_chunk(&fn_object.chunk)
	case .Class:
		class_object := cast(^Class_Object)object
		// FIXME: Need to recursively delete fields
		for field in class_object.fields {
			if field_object, ok := field.value.data.(^Object); ok {
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

Iterator :: struct {
	next:  proc(i: ^Iterator) -> (Value, bool),
	index: int,
}

base_iterator_next :: proc(i: ^Iterator) {
	i.index += 1
}

Range_Iterator :: struct {
	using base: Iterator,
	low:        f64,
	high:       f64,
	reverse:    bool,
}

//odinfmt: disable
RANGE_ITERATOR_IMPL :: Range_Iterator {
	base = Iterator {
		next = proc(i: ^Iterator) -> (value: Value, done: bool) {
			r := cast(^Range_Iterator)i
			value.kind = .Number
			if r.reverse {
				value.data = r.high - f64(r.index)
				done = value.data.(f64) < r.low
			} else {
				value.data = r.low + f64(r.index)
				done = value.data.(f64) > r.high
			}
			base_iterator_next(r)
			return
		},
	},
}
//odinfmt: enable
