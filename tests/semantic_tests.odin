package test

import "core:fmt"
import lily "../src"

test_semantic :: proc() {

}

test_simple_semantic :: proc() {
	using lily
	checker := &Checker{}

	init_checker(checker)

	bin_expr := &Binary_Expression{
		left = &Literal_Expression{value = Value{kind = .Number, data = 10}},
		right = &Literal_Expression{value = Value{kind = .Number, data = 20}},
		op = .Plus_Op,
	}

	result, err := check_expr(checker, bin_expr)
	assert(err == nil, fmt.tprint("Failed, Error raised ->", err))
	assert(result == "number", fmt.tprint("Failed, Invalid result ->", result))

	invalid_bin_expr := &Binary_Expression{
		left = &Literal_Expression{value = Value{kind = .Boolean, data = false}},
		right = &Literal_Expression{value = Value{kind = .Number, data = 20}},
		op = .Plus_Op,
	}

	result, err = check_expr(checker, invalid_bin_expr)
	assert(
		err == Semantic_Error.Mismatched_Types,
		fmt.tprint("Failed, Error 'Semantic_Error.Mismatched_Types' should be raised, got ->", err),
	)
	assert(result == nil, fmt.tprint("Failed, Invalid result ->", result))

	fmt.println("Simple Semantic: OK")
}
