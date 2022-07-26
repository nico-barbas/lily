package lily

// import "core:mem"

Gc :: struct {
	refs: [dynamic]^Object,
}

mark_objects :: proc(vm: ^Vm){
	mark_slice :: proc(s: []Value) {
		for value in s {
			if value.kind != .Object_Ref {
				continue
			}
			
			object := value.data.(^Object)
			object.marked = true
		}
	}
	mark_slice(vm.stack[:vm.stack_ptr])
	for module in vm.modules {
		for pool in module.class_consts {
			mark_slice(pool[:])
		}
		mark_slice(module.variables)
	}
}
