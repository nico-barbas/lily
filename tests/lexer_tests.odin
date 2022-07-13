package tests

import "core:fmt"
import "core:testing"
import lily "../src"

@(test)
test_lexer :: proc(t: ^testing.T) {using lily
	//
	inputs := [?]string{
		"= == < <= > >=",
		". .. ... ,",
		"+ - * / %",
		"var fn type is class",
		"return if else for in end break continue",
		"true false and or",
		"number bool string array map of",
		`10 1.2 "hello" --comment`,
	}
	counts := [?]int{6, 4, 5, 5, 8, 4, 6, 4}
	expects := [?][]Token_Kind{
		{.Assign, .Equal, .Lesser, .Lesser_Equal, .Greater, .Greater_Equal},
		{.Dot, .Double_Dot, .Triple_Dot, .Comma},
		{.Plus, .Minus, .Star, .Slash, .Percent},
		{.Var, .Fn, .Type, .Is, .Class},
		{.Return, .If, .Else, .For, .In, .End, .Break, .Continue},
		{.True, .False, .And, .Or},
		{.Number, .Boolean, .String, .Array, .Map, .Of},
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
