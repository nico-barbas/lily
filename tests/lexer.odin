package test

import "core:fmt"
import "core:testing"
import lily "../src"

@(test)
test_lexer :: proc(t: ^testing.T) {
	using lily
	inputs := [?]string{
		"= == < <= > >=",
		". .. ... ,",
		"+ - * / %",
		"var fn return and or true false",
		`10 1.2 "hello" --comment`,
	}
	counts := [?]int{6, 4, 5, 7, 4}
	expects := [?][]Token_Kind{
		{.Assign, .Equal, .Lesser, .Lesser_Equal, .Greater, .Greater_Equal},
		{.Dot, .Double_Dot, .Triple_Dot, .Comma},
		{.Plus, .Minus, .Star, .Slash, .Percent},
		{.Var, .Fn, .Return, .And, .Or, .True, .False},
		{.Number_Literal, .Number_Literal, .String_Literal, .Comment},
	}

	lexer := Lexer{}
	for input, i in inputs {
		count := 0
		set_lexer_input(&lexer, input)
		for {
			token := scan_token(&lexer)
			if token.kind == .EOF {
				break
			}
			testing.expect(
				t,
				token.kind == expects[i][count],
				fmt.tprint("Failed, Expected", expects[i][count], "Got", token.kind),
			)
			count += 1
		}
		testing.expect(
			t,
			count == counts[i],
			fmt.tprintf(
				"Failed, Too many tokens for input number %i; Got %i, but expected %i",
				i,
				count,
				counts[i],
			),
		)
	}
}
