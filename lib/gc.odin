package lily

import "core:mem"

Gc :: struct {
	allocator:      mem.Allocator,
	temp_allocator: mem.Allocator,
	objects:        [dynamic]^Object,

	// runtime data
	worklist:       [dynamic]^Object,
	closed_set:     [dynamic]^Object,
}

Trace_Color :: enum {
	White,
	Gray,
	Black,
}

allocate_traced_string :: proc(gc: ^Gc, from: string) -> Value {
	value := new_string_object(from, gc.allocator)
	object := value.data.(^Object)
	object.traced = true
	append(&gc.objects, object)
	return value
}

allocate_traced_array :: proc(gc: ^Gc) -> Value {
	value := new_array_object(gc.allocator)
	object := value.data.(^Object)
	object.traced = true
	append(&gc.objects, object)
	return value
}

allocate_traced_map :: proc(gc: ^Gc) -> Value {
	value := new_map_object(gc.allocator)
	object := value.data.(^Object)
	object.traced = true
	append(&gc.objects, object)
	return value
}

allocate_traced_class :: proc(gc: ^Gc, prototype: ^Class_Object) -> Value {
	value := new_class_object(prototype, gc.allocator)
	object := value.data.(^Object)
	object.traced = true
	append(&gc.objects, object)
	return value
}

mark :: proc(gc: ^Gc, vm: ^Vm) {
	context.allocator = gc.temp_allocator

	gc.worklist = make([dynamic]^Object)

	mark_roots(gc, vm)

	for len(gc.worklist) > 0 {
		object := pop(&gc.worklist)

		switch object.kind {
		case .Fn, .String:
		case .Array:
			array := cast(^Array_Object)object
			for element in array.data {
				if element.kind == .Object_Ref {
					next := element.data.(^Object)
					mark_object_gray(gc, next)
				}
			}
		case .Map:
			_map := cast(^Map_Object)object
			for key, value in _map.data {
				if key.kind == .Object_Ref {
					next := key.data.(^Object)
					mark_object_gray(gc, next)
				}
				if value.kind == .Object_Ref {
					next := value.data.(^Object)
					mark_object_gray(gc, next)
				}
			}
		case .Class:
			instance := cast(^Array_Object)object
			for field in instance.data {
				if field.kind == .Object_Ref {
					next := field.data.(^Object)
					mark_object_gray(gc, next)
				}
			}
		}

		object.tracing_color = .Black
	}
}

mark_roots :: proc(gc: ^Gc, vm: ^Vm) {
	mark_root_slice(gc, vm.stack[:vm.stack_ptr])
	for module in vm.modules {
		mark_root_slice(gc, module.variables)
	}
}

mark_root_slice :: proc(gc: ^Gc, s: []Value) {
	for value in s {
		if value.kind == .Object_Ref {
			object := value.data.(^Object)
			object.marked = true
			object.tracing_color = .Gray
			append(&gc.worklist, object)
		}
	}
}

mark_object_gray :: proc(gc: ^Gc, object: ^Object) {
	if !object.marked {
		object.marked = true
		switch object.tracing_color {
		case .White:
			object.tracing_color = .Gray
			append(&gc.worklist, object)
		case .Gray, .Black:
		}
	}
}

sweep :: proc(gc: ^Gc) {
	for object in gc.objects {
		if !object.marked && object.tracing_color == .White {
			free_object(object)
		}
	}
}
