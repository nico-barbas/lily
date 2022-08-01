package main

import "core:fmt"
import "core:unicode/utf8"
import lily "../../lib"
import rl "vendor:raylib"

main :: proc() {
	using lily

	state := new_state(Config{load_module_source = load_module_source_fn, bind_fn = rl_bind_foreign_fn})
	defer free_state(state)
	err := compile_file(state, "./game.lily")
	assert(err == nil, fmt.tprint(err))

	update_handle, update_err := make_fn_handle(state, "game", "update")
	assert(update_err == nil)
	draw_handle, draw_err := make_fn_handle(state, "game", "draw")
	assert(draw_err == nil)


	rl.InitWindow(800, 600, "lily-pong")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	for !rl.WindowShouldClose() {
		prepare_call(state, update_handle)
		state->set_value(f64(rl.GetFrameTime()), 0)
		call(state, update_handle)


		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		prepare_call(state, draw_handle)
		call(state, draw_handle)
		rl.EndDrawing()
	}

	rl.SetTargetFPS(60)
}

RL_BINDINGS :: `
type Color is class
	r: number
	g: number
	b: number
	a: number

	constructor new(_r: number, _g: number, _b: number, _a: number):
		self.r = _r
		self.g = _g
		self.b = _b
		self.a = _a
	end
end

foreign fn drawRectangle(x: number, y: number, w: number, h: number, clr: Color):
foreign fn drawText(text: string, x: number, y: number, size: number, clr: Color):
foreign fn isKeyDown(key: string): bool
`

load_module_source_fn :: proc(s: ^lily.State, name: string) -> (source: string, found: bool) {
	switch name {
	case "rl":
		source = RL_BINDINGS
		found = true
	}
	return
}

rl_bind_foreign_fn :: proc(s: ^lily.State, info: lily.Foreign_Decl_Info) -> lily.Foreign_Procedure {
	switch info.identifier {
	case "drawRectangle":
		return draw_rect_fn
	case "drawText":
		return draw_text_fn
	case "isKeyDown":
		return is_key_down_fn
	}
	return nil
}

draw_rect_fn :: proc(s: ^lily.State) {
	x := s->get_value(0).data.(f64)
	y := s->get_value(1).data.(f64)
	w := s->get_value(2).data.(f64)
	h := s->get_value(3).data.(f64)
	rl.DrawRectanglePro({f32(x), f32(y), f32(w), f32(h)}, {}, 0, rl.WHITE)
}

draw_text_fn :: proc(s: ^lily.State) {
	text := cast(^lily.String_Object)s->get_value(0).data.(^lily.Object)
	x := s->get_value(1).data.(f64)
	y := s->get_value(2).data.(f64)
	size := s->get_value(3).data.(f64)
	t := utf8.runes_to_string(text.data, context.temp_allocator)
	rl.DrawText(cstring(raw_data(t)), i32(x), i32(y), i32(size), rl.WHITE)
}

is_key_down_fn :: proc(s: ^lily.State) {
	key := cast(^lily.String_Object)s->get_value(1).data.(^lily.Object)
	switch key.data[0] {
	case 'w':
		s->set_value(rl.IsKeyDown(.W), 0)
	case 's':
		s->set_value(rl.IsKeyDown(.S), 0)
	}
}
