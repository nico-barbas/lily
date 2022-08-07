package lily

import "core:fmt"
import "core:mem"
import "core:os"

DEFAULT_GC_THRESHOLD :: mem.Byte * 1000
DEFAULT_TRACED_OBJECT_CAP :: 50

Gc :: struct {
	roots_interface:       Gc_Roots_Interface,
	// NOTE(nico): Not used for now. Will most likely be some sort of slab allocator
	class_allocator:       mem.Allocator,
	heap_allocator:        mem.Allocator,
	temp_allocator:        mem.Allocator,
	nodes:                 [dynamic]Traced_Node,

	// runtime data
	allocated_bytes:       int,
	collection_threshhold: int,
	collecting:            bool,
	worklist:              [dynamic]^Object,
}

Gc_Roots_Interface :: struct {
	gather_roots_proc: proc(data: rawptr, allocator := context.allocator) -> [][]Value,
	data:              rawptr,
}

Trace_Color :: enum {
	White,
	Gray,
	Black,
}

Traced_Node :: struct {
	data:      rawptr,
	size:      int,
	free_proc: proc(data: rawptr, allocator: mem.Allocator),
	color:     Trace_Color,
}

traced_node :: proc(object: ^Object) -> Traced_Node {
	node := Traced_Node {
		data = object,
		size = object_size(object),
		free_proc = proc(data: rawptr, allocator: mem.Allocator) {
			object := cast(^Object)data
			free_object(object, allocator)
		},
	}
	return node
}

new_gc :: proc(
	it: Gc_Roots_Interface,
	initial_threshold := DEFAULT_GC_THRESHOLD,
	allocator := context.allocator,
	temp_allocator := context.temp_allocator,
) -> ^Gc {

	gc := new(Gc, allocator)
	gc.roots_interface = it
	gc.heap_allocator = mem.Allocator {
		procedure = gc_generic_allocator_proc,
		data      = gc,
	}
	gc.nodes = make([dynamic]Traced_Node, 0, DEFAULT_TRACED_OBJECT_CAP, allocator)
	gc.temp_allocator = temp_allocator
	gc.collection_threshhold = initial_threshold
	return gc
}

delete_gc :: proc(gc: ^Gc) {
	start := gc.allocated_bytes
	for node in gc.nodes {
		node.free_proc(node.data, gc.heap_allocator)
		gc.allocated_bytes -= node.size
	}
	fmt.printf(
		"Closed GC. %d bytes freed\n%d bytes leaked\n",
		start - gc.allocated_bytes,
		gc.allocated_bytes,
	)
}

allocate_traced_string :: proc(gc: ^Gc, from: string) -> Value {
	value := new_string_object(from, gc.heap_allocator)
	object := value.data.(^Object)
	object.traced = true
	append(&gc.nodes)
	return value
}

allocate_traced_array :: proc(gc: ^Gc) -> Value {
	value := new_array_object(gc.heap_allocator)
	object := value.data.(^Object)
	object.traced = true
	append(&gc.nodes, traced_node(object))
	return value
}

allocate_traced_map :: proc(gc: ^Gc) -> Value {
	value := new_map_object(gc.heap_allocator)
	object := value.data.(^Object)
	object.traced = true
	append(&gc.nodes, traced_node(object))
	return value
}

allocate_traced_class :: proc(gc: ^Gc, prototype: ^Class_Object) -> Value {
	value := new_class_object(prototype, gc.heap_allocator)
	object := value.data.(^Object)
	object.traced = true
	append(&gc.nodes, traced_node(object))
	return value
}

// gc_class_allocator :: proc() {}

gc_generic_allocator_proc :: proc(
	allocator_data: rawptr,
	mode: mem.Allocator_Mode,
	size,
	alignment: int,
	old_memory: rawptr,
	old_size: int,
	location := #caller_location,
) -> (
	[]byte,
	mem.Allocator_Error,
) {
	gc := cast(^Gc)allocator_data

	#partial switch mode {
	case .Alloc:
		fmt.println(location, size)
		gc.allocated_bytes += size
	case .Free:
	case .Resize:
		fmt.println(size, "/", old_size)
		gc.allocated_bytes += size - old_size
	}

	if gc.allocated_bytes >= gc.collection_threshhold && !gc.collecting {
		gc.collecting = true
		defer {
			gc.collecting = false
			gc.collection_threshhold *= 2
		}
		collect_garbage(gc)
	}

	bytes, err := os.heap_allocator_proc(
		allocator_data,
		mode,
		size,
		alignment,
		old_memory,
		old_size,
		location,
	)
	return bytes, err
}

collect_garbage :: proc(gc: ^Gc) {
	start := gc.allocated_bytes
	fmt.println("collecting garbage:", start)
	mark(gc)
	fmt.println("finish marking")
	sweep(gc)
	fmt.printf("collected %d bytes of garbage\n", start - gc.allocated_bytes)
}

mark :: proc(gc: ^Gc) {
	gc.worklist = make([dynamic]^Object, gc.temp_allocator)

	roots := gc.roots_interface.gather_roots_proc(
		gc.roots_interface.data,
		gc.temp_allocator,
	)

	for root_slice in roots {
		mark_root_slice(gc, root_slice)
	}

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
					append(&gc.worklist, next)
				}
			}
		case .Map:
			_map := cast(^Map_Object)object
			for key, value in _map.data {
				if key.kind == .Object_Ref {
					next := key.data.(^Object)
					mark_object_gray(gc, next)
					append(&gc.worklist, next)
				}
				if value.kind == .Object_Ref {
					next := value.data.(^Object)
					mark_object_gray(gc, next)
					append(&gc.worklist, next)
				}
			}
		case .Class:
			instance := cast(^Array_Object)object
			for field in instance.data {
				if field.kind == .Object_Ref {
					next := field.data.(^Object)
					mark_object_gray(gc, next)
					append(&gc.worklist, next)
				}
			}
		}

		object.tracing_color = .Black
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
	remaining := make([dynamic]Traced_Node, 0, len(gc.nodes), gc.temp_allocator)
	for node in gc.nodes {
		object := cast(^Object)node.data
		if !object.marked && object.tracing_color == .White {
			node.free_proc(node.data, gc.heap_allocator)
			gc.allocated_bytes -= node.size
		} else {
			object.marked = false
			object.tracing_color = .White
			append(&remaining, node)
		}
	}

	clear(&gc.nodes)
	for node in remaining {
		append(&gc.nodes, node)
	}
}
