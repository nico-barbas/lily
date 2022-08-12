package lily

import "core:fmt"
import "core:mem"
import "lily:lib/allocators"

DEFAULT_GC_THRESHOLD :: mem.Byte * 1000
DEFAULT_TRACED_NODE_CAP :: 50

Gc_Allocator :: struct {
	temp_allocator:       mem.Allocator,
	backing:              allocators.Free_List_Allocator,
	traced_allocations:   map[rawptr]Traced_Allocation_Entry,
	gather_roots_proc:    Gather_Roots_Proc,
	data:                 rawptr,

	// runtime data
	growth_factor:        int,
	next_collection:      int,
	last_collection_size: int,
	nodes:                [dynamic]Mark_Node_Interface,
}

Gc_Allocator_Options :: struct {
	gather_roots_proc:   Gather_Roots_Proc,
	data:                rawptr,
	temp_allocator:      mem.Allocator,
	internals_allocator: mem.Allocator,
	initial_size:        int,
	first_collection:    int,
	growth_factor:       int,
}

Gather_Roots_Proc :: #type proc(data: rawptr, allocator := context.temp_allocator) -> []Mark_Node_Interface

Mark_Node_Interface :: struct {
	data:      rawptr,
	mark_proc: proc(gc: ^Gc_Allocator, data: rawptr),
}

Traced_Allocation_Entry :: struct {
	size:      int,
	alignment: int,
	data:      rawptr,
	color:     enum {
		White,
		Gray,
		Black,
	},
}

init_gc_allocator :: proc(gc: ^Gc_Allocator, opt: Gc_Allocator_Options) {
	gc.gather_roots_proc = opt.gather_roots_proc
	gc.data = opt.data
	gc.traced_allocations.allocator = opt.internals_allocator
	gc.nodes.allocator = opt.temp_allocator
	gc.temp_allocator = opt.temp_allocator

	backing_buf := make([]byte, opt.initial_size, opt.internals_allocator)
	allocators.init_free_list_allocator(&gc.backing, backing_buf, .Find_Best, 8)

	gc.growth_factor = opt.growth_factor
	gc.next_collection = opt.first_collection
}

gc_allocator_proc :: proc(
	allocator_data: rawptr,
	mode: mem.Allocator_Mode,
	size,
	alignment: int,
	old_memory: rawptr,
	old_size: int,
	location := #caller_location,
) -> (
	result: []byte,
	err: mem.Allocator_Error,
) {
	gc := cast(^Gc_Allocator)allocator_data

	if mode == .Free {
		assert(false)
		return nil, .Mode_Not_Implemented
	}
	result, err = allocators.free_list_allocator_proc(
		&gc.backing,
		mode,
		size,
		alignment,
		old_memory,
		old_size,
		location,
	)
	if err != nil {
		return nil, err
	}

	result_ptr := raw_data(result)
	#partial switch mode {
	case .Alloc:
		gc.traced_allocations[result_ptr] = Traced_Allocation_Entry {
			size      = size,
			alignment = alignment,
			data      = result_ptr,
			color     = .White,
		}
	case .Free_All:
		clear(&gc.traced_allocations)
	case .Resize:
		if old_memory != result_ptr {
			delete_key(&gc.traced_allocations, old_memory)
		}
		gc.traced_allocations[result_ptr] = Traced_Allocation_Entry {
			size      = size,
			alignment = alignment,
			data      = result_ptr,
			color     = .White,
		}

	case:
		return result, err
	}


	if gc.backing.used >= gc.next_collection {
		collect_garbage(gc)
	}

	return
}

gc_allocator :: proc(gc: ^Gc_Allocator) -> mem.Allocator {
	return mem.Allocator{data = gc, procedure = gc_allocator_proc}
}

collect_garbage :: proc(gc: ^Gc_Allocator) {
	fmt.println("Collection at:", gc.backing.used)
	defer fmt.println("End at:", gc.backing.used)
	clear(&gc.nodes)
	roots := gc.gather_roots_proc(gc.data, gc.temp_allocator)
	for root in roots {
		root.mark_proc(gc, root.data)
	}

	for len(gc.nodes) > 0 {
		node := pop(&gc.nodes)
		node.mark_proc(gc, node.data)
	}

	garbage := make([dynamic]Traced_Allocation_Entry, gc.temp_allocator)
	for ptr, entry in &gc.traced_allocations {
		if entry.color == .White {
			append(&garbage, entry)
		}
		entry.color = .White
		gc.traced_allocations[ptr] = entry
	}
	for entry in garbage {
		allocator := allocators.free_list_allocator(&gc.backing)
		free(entry.data, allocator)
		delete_key(&gc.traced_allocations, entry.data)
	}

	gc.next_collection *= gc.growth_factor
}

mark_raw_allocation :: proc(gc: ^Gc_Allocator, memory: rawptr) {
	if entry, exist := gc.traced_allocations[memory]; exist {
		if entry.color == .White {
			entry.color = .Gray
			gc.traced_allocations[memory] = entry
		}
	}
}

mark_slice :: proc(gc: ^Gc_Allocator, a: $T/[]$E) {
	mark_raw_allocation(gc, raw_slice_data(a))
}

mark_string :: proc(gc: ^Gc_Allocator, s: string) {
	mark_raw_allocation(gc, raw_string_data(s))
}

mark_dynamic_array :: proc(gc: ^Gc_Allocator, a: $T/[dynamic]$E) {
	mark_raw_allocation(gc, raw_dynamic_array_data(a))
}

mark_map :: proc(gc: ^Gc_Allocator, m: $T/map[$K]$V) {
	raw := transmute(mem.Raw_Map)m
	mark_raw_allocation(gc, raw_data(raw.hashes))
	mark_raw_allocation(gc, raw.entries.data)
}

append_mark_node :: proc(gc: ^Gc_Allocator, node: Mark_Node_Interface) {
	append(&gc.nodes, node)
}
