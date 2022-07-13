package tests

import "core:fmt"
import "core:testing"
import lily "../src"

// @(test)
// test_import_symbols :: proc(t: ^testing.T) {
// 	using lily
// 	input := `
// 		import sample
// 	`

// 	checker := Checker{}
// 	init_checker(&checker)
// 	checked_modules, err := build_checked_program(&checker, "main", input)
// 	testing.expect(t, err == nil)

// 	main_module := checked_modules[0]
// 	testing.expect(t, len(main_module.root.symbols) == 1)
// 	import_symbol := &main_module.root.symbols[0]
// 	testing.expect(t, import_symbol.kind == .Module_Symbol)
// 	testing.expect(t, import_symbol.module_info.ref_module_id == 1)
// }

// @(test)
// test_var_symbols :: proc(t: ^testing.T) {
// 	using lily
// 	input := `
// 		var a = 10
// 	`

// 	checker := Checker{}
// 	init_checker(&checker)
// 	checked_modules, err := build_checked_program(&checker, "main", input)

// 	main_module := checked_modules[0]
// 	testing.expect(t, len(main_module.root.symbols) == 1)

// 	import_symbol := &main_module.root.symbols[0]
// 	testing.expect(t, import_symbol.kind == .Var_Symbol)
// 	testing.expect(t, !import_symbol.var_info.immutable)
// 	testing.expect(t, !import_symbol.var_info.is_ref)
// 	fmt.println(import_symbol.var_info.var_symbol.kind)
// 	// testing.expect(t, import_symbol.var_info.var_symbol.kind == .Name)
// 	// testing.expect(t, import_symbol.var_info.var_symbol.module_id == -1)
// }

// @(test)
// test_fn_symbols :: proc(t: ^testing.T) {
// 	using lily
// 	input := `
// 		fn add(a: number, b:number): number
//             result = a + b
//         end
// 	`

// 	checker := Checker{}
// 	init_checker(&checker)
// 	checked_modules, err := build_checked_program(&checker, "main", input)
// 	testing.expect(t, err == nil)

// 	main_module := checked_modules[0]
// 	testing.expect(t, len(main_module.root.symbols) == 1)
// 	testing.expect(t, len(main_module.root.children) == 1)

// 	fn_symbol := &main_module.root.symbols[0]
// 	testing.expect(t, fn_symbol.kind == .Fn_Symbol)
// 	testing.expect(t, fn_symbol.fn_info.has_return)
// 	testing.expect(t, fn_symbol.fn_info.return_symbol.kind == .Name)
// 	testing.expect(t, fn_symbol.fn_info.return_symbol.module_id == -1)

// 	scope_err := enter_child_scope_by_id(main_module, fn_symbol.fn_info.scope_id)
// 	testing.expect(t, scope_err == nil)

// 	p0, p0_err := get_scoped_symbol(main_module.scope, Token{text = "a"})
// 	p1, p1_err := get_scoped_symbol(main_module.scope, Token{text = "b"})
// 	testing.expect(t, p0_err == nil)
// 	testing.expect(t, p0.kind == .Var_Symbol)
// 	testing.expect(t, p0.var_info.immutable)
// 	testing.expect(t, !p0.var_info.is_ref)
// 	testing.expect(t, p0.var_info.symbol.kind == .Name)

// 	testing.expect(t, p1_err == nil)
// 	testing.expect(t, p1.kind == .Var_Symbol)
// 	testing.expect(t, p1.var_info.immutable)
// 	testing.expect(t, !p1.var_info.is_ref)
// 	testing.expect(t, p1.var_info.symbol.kind == .Name)
// }

// @(test)
// test_alias_symbols :: proc(t: ^testing.T) {
// 	using lily
// 	input := `
// 		type Foo is number
// 	`

// 	checker := Checker{}
// 	init_checker(&checker)
// 	checked_modules, err := build_checked_program(&checker, "main", input)
// 	testing.expect(t, err == nil)

// 	main_module := checked_modules[0]
// 	testing.expect(t, len(main_module.root.symbols) == 1)

// 	alias_symbol := &main_module.root.symbols[0]
// 	testing.expect(t, alias_symbol.kind == .Alias_Symbol)
// 	testing.expect(t, alias_symbol.alias_info.symbol.kind == .Name)
// 	testing.expect(t, alias_symbol.alias_info.symbol.name == "number")
// }

// @(test)
// test_ref_alias_symbols :: proc(t: ^testing.T) {
// 	using lily
// 	input := `
//         import sample
// 		type Foo is sample.Vector
// 	`

// 	checker := Checker{}
// 	init_checker(&checker)
// 	checked_modules, err := build_checked_program(&checker, "main", input)
// 	testing.expect(t, err == nil)

// 	main_module := checked_modules[0]
// 	testing.expect(t, len(main_module.root.symbols) == 1)

// 	alias_symbol := &main_module.root.symbols[0]
// 	testing.expect(t, alias_symbol.kind == .Alias_Symbol)
// 	testing.expect(t, alias_symbol.alias_info.symbol.kind == .Class_Symbol)
// 	testing.expect(t, alias_symbol.alias_info.symbol.name == "Vector")
// }

// @(test)
// test_class_symbols :: proc(t: ^testing.T) {
// 	using lily
// 	input := `
// 		type Foo is class
//             x: number

//             constructor new(_x: number):
//                 self.x = _x
//             end

//             fn add(n: number):
//                 self.x = self.x + n
//             end
//         end
// 	`

// 	checker := Checker{}
// 	init_checker(&checker)
// 	checked_modules, err := build_checked_program(&checker, "main", input)
// 	testing.expect(t, err == nil)

// 	main_module := checked_modules[0]
// 	testing.expect(t, len(main_module.root.symbols) == 1)
// 	testing.expect(t, len(main_module.root.children) == 1)

// 	class_symbol := &main_module.root.symbols[0]
// 	testing.expect(t, class_symbol.kind == .Class_Symbol)

// 	scope_err := enter_class_scope(main_module, Token{text = "Foo"})
// 	testing.expect(t, scope_err == nil)
// 	testing.expect(t, len(main_module.scope.symbols) == 4)
// 	testing.expect(t, len(main_module.scope.children) == 2)

// 	self, self_err := get_scoped_symbol(main_module.scope, Token{text = "self"})
// 	testing.expect(t, self_err == nil)
// 	testing.expect(t, self.kind == .Var_Symbol)
// 	testing.expect(t, !self.var_info.immutable)
// 	testing.expect(t, self.var_info.is_ref)
// 	testing.expect(t, self.var_info.symbol.kind == .Class_Symbol)
// 	testing.expect(t, self.var_info.symbol.name == "Foo")
// 	testing.expect(
// 		t,
// 		self.var_info.symbol.class_info.class_scope_id == class_symbol.class_info.class_scope_id,
// 	)
// 	testing.expect(t, self.scope_id == class_symbol.class_info.class_scope_id)

// 	x, x_err := get_scoped_symbol(main_module.scope, Token{text = "x"})
// 	testing.expect(t, x_err == nil)
// 	testing.expect(t, x.kind == .Var_Symbol)
// 	testing.expect(t, !x.var_info.immutable)
// 	testing.expect(t, !x.var_info.is_ref)
// 	testing.expect(t, x.var_info.symbol.kind == .Name)

// 	{
// 		new_symbol, new_err := get_scoped_symbol(main_module.scope, Token{text = "new"})
// 		testing.expect(t, new_err == nil)
// 		testing.expect(t, new_symbol.kind == .Fn_Symbol)
// 		testing.expect(t, new_symbol.fn_info.has_return)
// 		testing.expect(t, new_symbol.fn_info.return_symbol.kind == .Class_Symbol)
// 		testing.expect(t, new_symbol.fn_info.return_symbol.name == "Foo")

// 		scope_err := enter_child_scope_by_id(main_module, new_symbol.fn_info.scope_id)
// 		testing.expect(t, scope_err == nil)

// 		p, p_err := get_scoped_symbol(main_module.scope, Token{text = "_x"})
// 		testing.expect(t, p_err == nil)
// 		testing.expect(t, p.kind == .Var_Symbol)
// 		testing.expect(t, p.var_info.immutable)
// 		testing.expect(t, !p.var_info.is_ref)
// 		testing.expect(t, p.var_info.symbol.kind == .Name)

// 		pop_scope(main_module)
// 	}

// 	{
// 		add, add_err := get_scoped_symbol(main_module.scope, Token{text = "add"})
// 		testing.expect(t, add_err == nil)
// 		testing.expect(t, add.kind == .Fn_Symbol)
// 		testing.expect(t, !add.fn_info.has_return)

// 		scope_err := enter_child_scope_by_id(main_module, add.fn_info.scope_id)
// 		testing.expect(t, scope_err == nil)

// 		p, p_err := get_scoped_symbol(main_module.scope, Token{text = "n"})
// 		testing.expect(t, p_err == nil)
// 		testing.expect(t, p.kind == .Var_Symbol)
// 		testing.expect(t, p.var_info.immutable)
// 		testing.expect(t, !p.var_info.is_ref)
// 		testing.expect(t, p.var_info.symbol.kind == .Name)

// 		pop_scope(main_module)
// 	}
// }

// @(test)
// test_import_class_symbols :: proc(t: ^testing.T) {

// }
