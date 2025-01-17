package main
import "core:fmt"
import "core:math/rand"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

Color :: enum {
	BLACK,
	WHITE,
	RED,
	GREEN,
	BLUE,
	GOLD,
	PEARL,
}

Owner :: enum {
	BOARD,
	BAG,
	PLAYER1,
	PLAYER2,
}

Vector2 :: [2]u8
MousePosition :: [2]f32

Token :: struct {
	color: Color,
	owner: Owner,
}

Cell :: struct {
	is_highlighted: bool,
	token:          ^Token,
}

Scroll :: struct {
	owner: Owner,
}

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

TOKEN_NUMBER :: 25
CELL_SIZE :: 100
HIGHLIGHT_SIZE :: CELL_SIZE + 10
PLAYER_HAND_SIZE :: 20
OFFSET_X :: 370
OFFSET_Y :: 110

SCROLL_HEIGHT :: 30
SCROLL_WIDTH :: 10

GAP :: 10

color_to_rlcolor :: proc(color: Color) -> rl.Color {
	switch color {
	case .BLACK:
		return rl.BLACK
	case .WHITE:
		return rl.WHITE
	case .RED:
		return rl.RED
	case .GREEN:
		return rl.GREEN
	case .BLUE:
		return rl.BLUE
	case .GOLD:
		return rl.GOLD
	case .PEARL:
		return rl.PINK
	}

	return rl.DARKPURPLE
}

draw_board :: proc(board: map[Vector2]Cell, positions: []Vector2) {
	for key, cell in board {
		if cell.token == nil {
			continue
		}

		if cell.token.owner != Owner.BOARD {
			continue
		}

		x := i32(key[0]) * CELL_SIZE + CELL_SIZE / 2
		y := i32(key[1]) * CELL_SIZE + CELL_SIZE / 2
		color := color_to_rlcolor(cell.token.color)
		rl.DrawCircle(x + OFFSET_X, y + OFFSET_Y, CELL_SIZE / 2, color)
	}
}

owner_count_scrolls :: proc(scrolls: []Scroll) -> map[Owner]u8 {
	owner_count := map[Owner]u8 {
		Owner.BOARD   = 0,
		Owner.PLAYER1 = 0,
		Owner.PLAYER2 = 0,
	}

	for scroll in scrolls {
		owner_count[scroll.owner] += 1
	}

	return owner_count
}

draw_scrolls :: proc(scrolls: []Scroll) {
	owner_count := owner_count_scrolls(scrolls)

	x, y, text_x, text_y: i32

	for owner, count in owner_count {
		switch owner {
		case Owner.BOARD:
			x = WINDOW_WIDTH / 2 - 2 * SCROLL_WIDTH - SCROLL_WIDTH / 2
			y = 0
			text_x = x
			text_y = y + SCROLL_HEIGHT + GAP
		case Owner.PLAYER1:
			x = 0 + GAP
			y = WINDOW_HEIGHT - SCROLL_HEIGHT - GAP
			text_x = x + SCROLL_WIDTH + GAP
			text_y = y + SCROLL_HEIGHT / 4
		case Owner.PLAYER2:
			x = WINDOW_WIDTH - GAP - SCROLL_WIDTH
			y = WINDOW_HEIGHT - SCROLL_HEIGHT - GAP
			text_x = x - GAP
			text_y = y + SCROLL_HEIGHT / 4
		case Owner.BAG:
			os.exit(1)
		}

		rl.DrawRectangleV({f32(x), f32(y)}, {SCROLL_WIDTH, SCROLL_HEIGHT}, rl.BEIGE)

		buffer: [2]byte
		score_text := strconv.itoa(buffer[:], int(count))
		rl.DrawText(
			strings.clone_to_cstring(score_text, context.temp_allocator),
			text_x,
			text_y,
			18,
			rl.BEIGE,
		)
	}

}

count_owner_tokens :: proc(tokens: []Token, owner: Owner) -> map[Color]uint {
	color_map := map[Color]uint {
		Color.BLACK = 0,
		Color.WHITE = 0,
		Color.RED   = 0,
		Color.GREEN = 0,
		Color.BLUE  = 0,
		Color.GOLD  = 0,
		Color.PEARL = 0,
	}

	for token in tokens {
		if token.owner != owner {
			continue
		}
		color_map[token.color] += 1
	}

	return color_map
}

draw_player_tokens :: proc(tokens: []Token, player: Owner) {
	assert(player != Owner.BOARD && player != Owner.BAG)

	token_count := count_owner_tokens(tokens, player)

	x, m: i32
	if player == Owner.PLAYER1 {
		x = 10 + PLAYER_HAND_SIZE
		m = 1
	} else {
		x = WINDOW_WIDTH - PLAYER_HAND_SIZE - 10
		m = -1
	}

	y_offset: i32 = PLAYER_HAND_SIZE * 2

	for key, value in token_count {
		y := 20 + PLAYER_HAND_SIZE / 2 + i32(key) * y_offset

		color := color_to_rlcolor(key)
		rl.DrawCircle(x, y, PLAYER_HAND_SIZE, color)

		buffer: [2]byte
		score_text := strconv.itoa(buffer[:], int(value))
		text_x := x + m * (PLAYER_HAND_SIZE + 10)
		text_y := y - PLAYER_HAND_SIZE / 2
		rl.DrawText(
			strings.clone_to_cstring(score_text, context.temp_allocator),
			text_x,
			text_y,
			18,
			color,
		)
	}
}

refill :: proc(tokens: []Token, board: map[Vector2]Cell) {
	refills: [dynamic]^Token

	for &token in tokens {
		if token.owner == Owner.BAG {
			append(&refills, &token)
		}
	}
	rand.shuffle(refills[:])

	for key, &cell in board {
		if cell.token.owner == .BAG {
			cell.token = pop(&refills)
			cell.token.owner = Owner.BOARD
		}

		if len(refills) == 0 {
			break
		}
	}
}

draw_hovers :: proc(cell_x, cell_y: f32, color: rl.Color = rl.PURPLE) {
	if cell_x < 0 || cell_x > 4 {
		return
	}

	if cell_y < 0 || cell_y > 4 {
		return
	}

	x := i32(cell_x) * CELL_SIZE + CELL_SIZE / 2
	y := i32(cell_y) * CELL_SIZE + CELL_SIZE / 2
	rl.DrawCircle(x + OFFSET_X, y + OFFSET_Y, HIGHLIGHT_SIZE / 2, color)
}

draw_selection :: proc(selection: []Vector2, board: map[Vector2]Cell) {
	for position in selection {
		draw_hovers(f32(position[0]), f32(position[1]), rl.ORANGE)
	}
}

sort_selection :: proc(i, j: Vector2) -> bool {
	return i[0] + i[1] < j[0] + j[1]
}

select :: proc(selection: []Vector2, selection_id: ^int, choice: Vector2) {
	// Deselect element
	for i in 0 ..< 3 {
		if selection[i] == choice {
			selection[i] = {10, 10}
			slice.sort_by(selection, sort_selection)
			selection_id^ -= 1

			return
		}
	}

	if selection_id^ >= 3 {
		return
	}

	// Select element
	selection[selection_id^] = choice
	selection_id^ += 1
}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Splendid")
	rl.SetTargetFPS(30)

	positions := [?]Vector2 {
		{2, 2},
		{2, 3},
		{1, 3},
		{1, 2},
		{1, 1},
		{2, 1},
		{3, 1},
		{3, 2},
		{3, 3},
		{3, 4},
		{2, 4},
		{1, 4},
		{0, 4},
		{0, 3},
		{0, 2},
		{0, 1},
		{0, 0},
		{1, 0},
		{2, 0},
		{3, 0},
		{4, 0},
		{4, 1},
		{4, 2},
		{4, 3},
		{4, 4},
	}

	tokens := [?]Token {
		0 ..= 3 = Token{Color.BLACK, Owner.BOARD},
		4 ..= 7 = Token{Color.WHITE, Owner.BOARD},
		8 ..= 11 = Token{Color.RED, Owner.BOARD},
		12 ..= 15 = Token{Color.GREEN, Owner.BOARD},
		16 ..= 19 = Token{Color.BLUE, Owner.BOARD},
		20 ..= 22 = Token{Color.GOLD, Owner.BAG},
		23 ..= 24 = Token{Color.PEARL, Owner.BAG},
	}
	rand.shuffle(positions[:])

	scrolls: [3]Scroll
	scrolls[0].owner = Owner.PLAYER2

	board: map[Vector2]Cell
	for i in 0 ..< TOKEN_NUMBER {
		board[positions[i]] = Cell {
			is_highlighted = false,
			token          = &tokens[i],
		}
	}

	selection := [3]Vector2{{10, 10}, {10, 10}, {10, 10}}
	selection_id := 0

	for !rl.WindowShouldClose() {
		if rl.IsKeyDown(.ENTER) {
			refill(tokens[:], board)
		}

		cell_x: f32 = f32(rl.GetMouseX() - OFFSET_X) / CELL_SIZE
		cell_y: f32 = f32(rl.GetMouseY() - OFFSET_Y) / CELL_SIZE

		if rl.IsMouseButtonPressed(.LEFT) {
			select(selection[:], &selection_id, {u8(cell_x), u8(cell_y)})
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		rl.DrawRectangleV({OFFSET_X - 10, OFFSET_Y - 10}, {520, 520}, rl.BROWN)
		draw_hovers(cell_x, cell_y)
		draw_selection(selection[:], board)
		draw_board(board, positions[:])
		draw_player_tokens(tokens[:], Owner.PLAYER1)
		draw_player_tokens(tokens[:], Owner.PLAYER2)
		draw_scrolls(scrolls[:])

		rl.EndDrawing()
	}

	rl.CloseWindow()

}
