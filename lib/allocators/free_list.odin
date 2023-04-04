package allocators

import "core:mem"

Free_List_Allocator :: struct {
	data:          []byte,
	size:          int,
	used:          int,
	head:          ^Free_List_Node,
	policy:        Free_List_Policy,
	min_alignment: int,
}

Free_List_Policy :: enum {
	Find_First,
	Find_Best,
}

Free_List_Node :: struct {
	next: ^Free_List_Node,
	size: int,
}

Free_List_Header :: struct {
	size:    int,
	padding: int,
}

init_free_list_allocator :: proc(
	fl: ^Free_List_Allocator,
	buf: []byte,
	policy: Free_List_Policy,
	min_alignment: int,
) {
	fl^ = Free_List_Allocator {
		data          = buf,
		size          = len(buf),
		head          = cast(^Free_List_Node)&buf[0],
		policy        = policy,
		min_alignment = min_alignment,
	}
	fl.head.next = nil
	fl.head.size = len(buf)
}

find_first_free_list_node :: proc(
	fl: ^Free_List_Allocator,
	size, alignment: int,
) -> (
	node: ^Free_List_Node,
	previous: ^Free_List_Node,
	padding: int,
) {
	node = fl.head
	for node != nil {
		padding = mem.calc_padding_with_header(
			uintptr(node),
			uintptr(alignment),
			size_of(Free_List_Header),
		)
		required_size := size + padding
		if node.size >= required_size {
			break
		}
		previous = node
		node = node.next
	}
	return
}

find_best_free_list_node :: proc(
	fl: ^Free_List_Allocator,
	size, alignment: int,
) -> (
	node: ^Free_List_Node,
	previous: ^Free_List_Node,
	padding: int,
) {
	current := fl.head
	smallest_diff := 0
	for current != nil {
		p := mem.calc_padding_with_header(
			uintptr(current),
			uintptr(alignment),
			size_of(Free_List_Header),
		)
		required_size := size + p
		if current.size >= required_size && (current.size - required_size) < smallest_diff {
			node = current
			smallest_diff = current.size - required_size
		}
		previous = current
		current = current.next
	}

	if node != nil {
		padding = mem.calc_padding_with_header(
			uintptr(node),
			uintptr(alignment),
			size_of(Free_List_Header),
		)
	}
	return
}

free_list_allocator_proc :: proc(
	allocator_data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	location := #caller_location,
) -> (
	[]byte,
	mem.Allocator_Error,
) {

	fl := cast(^Free_List_Allocator)allocator_data
	if fl.data == nil {
		return nil, .Invalid_Argument
	}

	raw_alloc :: proc(
		fl: ^Free_List_Allocator,
		size, alignment: int,
	) -> (
		[]byte,
		mem.Allocator_Error,
	) {
		best_align := alignment if alignment > fl.min_alignment else fl.min_alignment
		best_size := size if size > size_of(Free_List_Node) else size_of(Free_List_Node)

		node: ^Free_List_Node
		previous: ^Free_List_Node
		padding: int
		switch fl.policy {
		case .Find_First:
			node, previous, padding = find_first_free_list_node(fl, best_size, best_align)
		case .Find_Best:
			node, previous, padding = find_first_free_list_node(fl, best_size, best_align)
		}
		if node == nil {
			return nil, .Out_Of_Memory
		}
		alloc_size := size + padding
		remaining := node.size - alloc_size
		result := uintptr(node) + uintptr(padding)

		if remaining > 0 {
			new_node := cast(^Free_List_Node)(uintptr(node) + uintptr(alloc_size))
			new_node.size = remaining
			insert_free_list_node(fl, previous, new_node)
		}
		remove_free_list_node(fl, previous, node)

		header := cast(^Free_List_Header)(result - size_of(Free_List_Header))
		header^ = Free_List_Header {
			size    = alloc_size,
			padding = padding - size_of(Free_List_Header),
		}

		fl.used += alloc_size
		mem.zero(rawptr(result), size)
		return mem.byte_slice(rawptr(result), size), nil
	}

	raw_free :: proc(fl: ^Free_List_Allocator, memory: rawptr) -> mem.Allocator_Error {
		mem_start := uintptr(memory)
		start := uintptr(&fl.data[0])
		end := start + uintptr(len(fl.data))
		if mem_start < start || mem_start >= end {
			return .Invalid_Pointer
		}

		free_start := mem_start - size_of(Free_List_Header)
		header := cast(^Free_List_Header)free_start
		free := cast(^Free_List_Node)free_start
		free.size = header.size + header.padding

		previous: ^Free_List_Node
		current := fl.head
		for current != nil {
			if mem_start < uintptr(current) {
				insert_free_list_node(fl, previous, free)
				break
			}
			previous = current
			current = current.next
		}

		fl.used -= free.size

		next_start := uintptr(free) + uintptr(free.size)
		if free.next != nil && next_start == uintptr(free.next) {
			free.size += free.next.size
			remove_free_list_node(fl, free, free.next)
		}
		if previous != nil {
			previous_end := uintptr(previous) + uintptr(previous.size)
			if previous.next != nil && previous_end == free_start {
				previous.size += free.size
				remove_free_list_node(fl, previous, free)
			}
		}

		return nil
	}

	switch mode {
	case .Alloc, .Alloc_Non_Zeroed:
		memory, err := raw_alloc(fl, size, alignment)
		if err == .None && mode != .Alloc_Non_Zeroed {
			mem.zero(raw_data(memory), size)
		}
		return memory, err

	case .Resize:
		if old_memory == nil {
			return raw_alloc(fl, size, alignment)
		}
		if size == 0 {
			raw_free(fl, old_memory)
			return nil, nil
		}

		result, err := raw_alloc(fl, size, alignment)
		if err != nil {
			return nil, err
		}
		old := mem.byte_slice(old_memory, old_size)
		copy(result, old)
		raw_free(fl, old_memory)

		return result, err

	case .Free:
		if old_memory == nil {
			return nil, nil
		}
		raw_free(fl, old_memory)

	case .Free_All:
		fl.used = 0
		fl.head = cast(^Free_List_Node)&fl.data[0]
		fl.head^ = Free_List_Node {
			next = nil,
			size = fl.size,
		}
	case .Query_Features:
		set := cast(^mem.Allocator_Mode_Set)(old_memory)
		if set != nil {
			set^ = {.Alloc, .Free, .Free_All, .Resize, .Query_Features}
		}
		return nil, nil
	case .Query_Info:
		return nil, .Mode_Not_Implemented
	}

	return nil, nil
}

free_list_allocator :: proc(fl: ^Free_List_Allocator) -> mem.Allocator {
	return mem.Allocator{procedure = free_list_allocator_proc, data = fl}
}

insert_free_list_node :: proc(fl: ^Free_List_Allocator, previous, node: ^Free_List_Node) {
	if previous == nil {
		if fl.head != nil {
			fl.head.next = node
		} else {
			fl.head = node
		}
	} else {
		if previous.next == nil {
			previous.next = node
			node.next = nil
		} else {
			node.next = previous.next
			previous.next = node
		}
	}
}

remove_free_list_node :: proc(fl: ^Free_List_Allocator, previous, node: ^Free_List_Node) {
	if previous == nil {
		fl.head = node.next
	} else {
		previous.next = node.next
	}
}
