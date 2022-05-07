package lily

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
	Map,
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
