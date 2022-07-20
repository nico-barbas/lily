package main

import rl "vendor:raylib"

main :: proc() {


	rl.InitWindow(800, 600, "lily-pong")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

}
