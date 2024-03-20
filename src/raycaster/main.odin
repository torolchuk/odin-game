package main

import "core:fmt"
import "core:log"
import math "core:math"
import linalg "core:math/linalg"

import sdl "vendor:sdl2"

WINDOW_NAME :: "RAYCASTED"
WINDOW_WIDHT :: 1024 * 2
WINDOW_HEIGHT :: 512 * 2
PIXEL_SIZE :: 2 * 2
TEXTURE_WIDTH :: WINDOW_WIDHT / PIXEL_SIZE
TEXTURE_HEIGHT :: WINDOW_HEIGHT / PIXEL_SIZE

COLOR_CLEAR := [4]u8{0x40, 0x40, 0x40, 0xff}
COLOR_BLACK := [4]u8{0x00, 0x00, 0x00, 0xff}
COLOR_GRAY := [4]u8{0xcc, 0xcc, 0xcc, 0xff}
COLOR_LIGHTGRAY := [4]u8{0x88, 0x88, 0x88, 0xff}
COLOR_WHITE := [4]u8{0xff, 0xff, 0xff, 0xff}
COLOR_YELLOW := [4]u8{0xff, 0xff, 0x00, 0xff}
COLOR_RED := [4]u8{0xff, 0x00, 0x00, 0xff}
COLOR_GREEN := [4]u8{0x00, 0xff, 0x00, 0xff}
COLOR_BLUE := [4]u8{0x00, 0x00, 0xff, 0xff}

MAP_X := 8
MAP_Y := 8
TILE_SIZE := 32

INITIAL_MAP := [64]int {
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	0,
	0,
	1,
	0,
	0,
	0,
	1,
	1,
	0,
	0,
	0,
	0,
	0,
	0,
	1,
	1,
	0,
	2,
	0,
	0,
	0,
	0,
	1,
	1,
	0,
	0,
	3,
	0,
	0,
	0,
	1,
	1,
	0,
	1,
	0,
	4,
	0,
	0,
	1,
	1,
	0,
	0,
	1,
	0,
	5,
	0,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
}

MAP_COLORS := map[int](^[4]u8) {
	1 = &COLOR_WHITE,
	2 = &COLOR_RED,
	3 = &COLOR_GREEN,
	4 = &COLOR_BLUE,
}

GameTime :: struct {
	lastTick: f64,
	delta:    f64,
}

TICKRATE := 240.0
TICKTIME := 1000.0 / TICKRATE

time_get_current :: proc() -> (time: f64) {
	return f64(sdl.GetPerformanceCounter()) * 1000 / f64(sdl.GetPerformanceFrequency())
}

time_update :: proc(gt: ^GameTime) {
	last := gt.lastTick
	curr := time_get_current()
	delta := curr - last

	gt.lastTick = curr
	gt.delta += delta
}

GameState :: struct {
	time:         GameTime,
	inputs:       []u8,
	game_map:     [64]int,
	player_pos:   [2]f32,
	player_angle: f32,
}

set_render_color :: proc(renderer: ^sdl.Renderer, color: ^[4]u8) {
	sdl.SetRenderDrawColor(renderer, color[0], color[1], color[2], color[3])
}

render_clear :: proc(renderer: ^sdl.Renderer) {
	set_render_color(renderer, &COLOR_CLEAR)
	sdl.RenderClear(renderer)
}

get_mapi_from_xy :: proc(x: int, y: int) -> (mapi: int) {
	return (x / TILE_SIZE) + (y / TILE_SIZE) * MAP_Y
}

get_xy_from_mapi :: proc(size_x: int, size_y: int, pos: int) -> (x: int, y: int) {
	x = (pos % size_x)
	y = (((pos >> 3) << 3) / size_y)

	return x, y
}

get_xy_from_rad :: proc(rad: f32) -> (x: f32, y: f32) {
	x = math.cos(rad)
	y = math.sin(rad)

	return x, y
}

render_map :: proc(renderer: ^sdl.Renderer, game_map: [64]int) {
	for i: int = 0; i < len(game_map); i += 1 {
		x, y := get_xy_from_mapi(MAP_X, MAP_Y, i)
		size := cast(i32)TILE_SIZE

		if (game_map[i] > 0) {
			color := MAP_COLORS[game_map[i]]
			if (color == nil) {color = &COLOR_GRAY}
			tile_rect := &sdl.Rect {
				cast(i32)x * size + 1,
				cast(i32)y * size + 1,
				size - 2,
				size - 2,
			}
			set_render_color(renderer, color)
			sdl.RenderFillRect(renderer, tile_rect)
		}
	}
}

render_player :: proc(renderer: ^sdl.Renderer, gameState: ^GameState) {
	lineLength: f32 : 3.0
	px, py := gameState.player_pos[0], gameState.player_pos[1]
	pvx, pvy := get_xy_from_rad(gameState.player_angle)

	set_render_color(renderer, &COLOR_BLACK)
	sdl.RenderDrawLine(
		renderer,
		cast(i32)px,
		cast(i32)py,
		cast(i32)(px + pvx * lineLength),
		cast(i32)(py + pvy * lineLength),
	)

	set_render_color(renderer, &COLOR_YELLOW)
	sdl.RenderDrawPoint(renderer, cast(i32)px, cast(i32)py)
}

MAX_RAYCAST_PASSES :: 8
get_raycast_hit :: proc(env: ^[64]int, from: ^[2]f32, angle: f32) -> (hit: [2]f32, block_ind: int, dist: f32) {
	ts := f32(TILE_SIZE)
	fx, fy := from[0], from[1]
	offset_x := math.mod(fx, ts)
	offset_y := math.mod(fy, ts)
	atan := -1 / math.tan(angle)
	env_length := len(env)

	r, mx, my, hmp, vmp, passes: int
	rx, ry, ra, xo, yo: f32

	if (angle > math.PI) {
		ry = fy - offset_y - 0.0001
		rx = (fy - ry) * atan + fx
		yo = -ts
		xo = -yo * atan
	}
	if (angle < math.PI) {
		ry = fy - offset_y + ts
		rx = (fy - ry) * atan + fx
		yo = ts
		xo = -yo * atan
	}
	if (angle == 0 || angle == math.PI) {
		rx = fx
		ry = fy
		passes = 8
	}

	for (passes < MAX_RAYCAST_PASSES) {
		mx = int(rx / ts)
		my = int(ry / ts)
		hmp = my * MAP_Y + mx

		if (hmp >= 0 && hmp < env_length && env[hmp] > 0) {
			passes = MAX_RAYCAST_PASSES
		} else {
			rx += xo
			ry += yo
			passes += 1
		}
	}

  h_hit := [2]f32{rx,ry}

  passes = 0
  ntan:f32 = -math.tan(angle)
  hPI:f32 = math.PI / 2
  thPI:f32 = 3 * hPI
  if (angle > hPI && angle < thPI) {
		rx = fx - offset_x - 0.0001
		ry = (fx - rx) * ntan + fy
		xo = -ts
		yo = -xo * ntan
  }
  if (angle < hPI || angle > thPI) {
		rx = fx - offset_x + ts
		ry = (fx - rx) * ntan + fy
		xo = ts
		yo = -xo * ntan
  }
  if (angle == hPI || angle == thPI) {
		rx = fx
		ry = fy
		passes = 8
  }
  
	for (passes < MAX_RAYCAST_PASSES) {
		mx = int(rx / ts)
		my = int(ry / ts)
		vmp = my * MAP_Y + mx

		if (vmp >= 0 && vmp < env_length && env[vmp] > 0) {
			passes = MAX_RAYCAST_PASSES
		} else {
			rx += xo
			ry += yo
			passes += 1
		}
	}

  v_hit := [2]f32{rx, ry}

  h_dist := linalg.distance(from^, h_hit)
  v_dist := linalg.distance(from^, v_hit)

	if h_dist < v_dist {
    return h_hit, hmp, h_dist
  } else {
    return v_hit, vmp, v_dist
  }
}

PLAYER_FOV :: math.PI / 2
PLAYER_FOV_HALF :: PLAYER_FOV / 2
RAY_COUNT:f32 : 128
RAY_STEP :: PLAYER_FOV / RAY_COUNT
render_2d_raycasts :: proc(renderer: ^sdl.Renderer, gameState: ^GameState) {
	for i: f32 = 0.0; i < RAY_COUNT; i += 1.0 {
		ray_offset := RAY_STEP * i - PLAYER_FOV_HALF
    ray_angle := gameState.player_angle + ray_offset
    if (ray_angle < 0) { ray_angle += math.PI * 2 }
    if (ray_angle > math.PI * 2) { ray_angle -= math.PI * 2 }

    hit, mp, length := get_raycast_hit(
			&gameState.game_map,
			&gameState.player_pos,
			ray_angle,
		)

		set_render_color(renderer, &COLOR_LIGHTGRAY)
		sdl.RenderDrawLine(
			renderer,
			cast(i32)gameState.player_pos[0],
			cast(i32)gameState.player_pos[1],
			cast(i32)hit[0],
			cast(i32)hit[1],
		)
	}
}

clamp_angle :: proc (angle: f32) -> f32 {
  if (angle < 0) {
    return angle + math.PI * 2
  }
  if (angle > math.PI * 2) {
    return angle - math.PI * 2
  }

  return angle
}

render_projection :: proc(renderer: ^sdl.Renderer, game_state: ^GameState) {
  width:f32 = TEXTURE_WIDTH / RAY_COUNT
  max_height:f32 = TEXTURE_HEIGHT / 2

  max_distance: f32 = 100

  for i: f32 = 0; i < RAY_COUNT; i += 1 {
    ray_offset := RAY_STEP * i - PLAYER_FOV_HALF
    ray_angle := clamp_angle(game_state.player_angle + ray_offset)
    
    hit, mp, length := get_raycast_hit(
			&game_state.game_map,
			&game_state.player_pos,
			ray_angle,
		)
  
    wall_height:f32 = 1 - math.min(length, max_distance) / max_distance

    set_render_color(renderer, MAP_COLORS[game_state.game_map[mp]])

    rect := sdl.Rect{
      cast(i32)(width * i),
      cast(i32)(max_height - max_height * wall_height),
      cast(i32)(width),
      cast(i32)(wall_height * max_height * 2),
    }
    sdl.RenderFillRect(renderer, &rect)

  }
}

render_game :: proc(renderer: ^sdl.Renderer, gameState: ^GameState) {
	render_map(renderer, gameState.game_map)
	render_2d_raycasts(renderer, gameState)
	render_player(renderer, gameState)
  // render_projection(renderer, gameState)
}

PLAYER_MOV_SPEED :: 0.3
PLAYER_ROTATION_SPEED :: math.PI / 180

INPUTS_MAP := map[GameInput](u8) {
	.FORWARD = cast(u8)sdl.SCANCODE_W,
	.BACK    = cast(u8)sdl.SCANCODE_S,
	.LEFT    = cast(u8)sdl.SCANCODE_A,
	.RIGHT   = cast(u8)sdl.SCANCODE_D,
}

is_button_pressed :: proc(keyboardState: []u8, input: GameInput) -> bool {
	scancode := INPUTS_MAP[input]
	return cast(bool)keyboardState[scancode]
}

GameInput :: enum {
	FORWARD,
	BACK,
	LEFT,
	RIGHT,
}

update_player :: proc(gameState: ^GameState) {
	rad := gameState.player_angle

	if (is_button_pressed(gameState.inputs, .LEFT)) {
		rad -= PLAYER_ROTATION_SPEED
	}
	if (is_button_pressed(gameState.inputs, .RIGHT)) {
		rad += PLAYER_ROTATION_SPEED
	}

	PI2 := cast(f32)math.PI * 2
	if (rad > math.PI * 2) {rad -= PI2} else if (rad < 0) {rad += PI2}
	gameState.player_angle = rad

	vx, vy := get_xy_from_rad(rad)

	movSpeed: f32 = 0.0
	if (is_button_pressed(gameState.inputs, .FORWARD)) {
		movSpeed += PLAYER_MOV_SPEED
	}
	if (is_button_pressed(gameState.inputs, .BACK)) {
		movSpeed -= PLAYER_MOV_SPEED
	}

	if (movSpeed == .0) {return}

	upx := gameState.player_pos[0] + vx * movSpeed
	upy := gameState.player_pos[1] + vy * movSpeed


	newMapPosX := get_mapi_from_xy(cast(int)upx, cast(int)gameState.player_pos[1])
	if (gameState.game_map[newMapPosX] == 0) {
		gameState.player_pos[0] += vx * movSpeed
	}

	newMapPosY := get_mapi_from_xy(cast(int)gameState.player_pos[0], cast(int)upy)
	if (gameState.game_map[newMapPosY] == 0) {
		gameState.player_pos[1] += vy * movSpeed
	}
}

update_game :: proc(gameState: ^GameState) {
	update_player(gameState)
}

get_tilepos_centered :: proc(x: int, y: int) -> (tilepos: [2]f32) {
	ts := cast(f32)TILE_SIZE

	return [2]f32{cast(f32)x * ts + ts / 2, cast(f32)y * ts + ts / 2}
}

main :: proc() {
	context.logger = log.create_console_logger()

	window := sdl.CreateWindow(
		WINDOW_NAME,
		sdl.WINDOWPOS_CENTERED,
		sdl.WINDOWPOS_CENTERED,
		WINDOW_WIDHT,
		WINDOW_HEIGHT,
		nil,
	)

	renderer := sdl.CreateRenderer(window, -1, {.ACCELERATED, .TARGETTEXTURE})

	texture_2d := sdl.CreateTexture(
		renderer,
		cast(u32)sdl.PixelFormatEnum.ARGB8888,
		.TARGET,
		TEXTURE_WIDTH / 2,
		TEXTURE_HEIGHT,
	)

	texture_3d := sdl.CreateTexture(
		renderer,
		cast(u32)sdl.PixelFormatEnum.ARGB8888,
		.TARGET,
		TEXTURE_WIDTH,
		TEXTURE_HEIGHT,
	)


	gameState := GameState {
		time       = GameTime{time_get_current(), 0},
		inputs     = []u8{},
		game_map   = INITIAL_MAP,
		player_pos = get_tilepos_centered(4, 4),
	}

	for {
		event: sdl.Event
		for (sdl.PollEvent(&event)) {
			#partial switch (event.type) {
			case .QUIT:
				{
					return
				}
			}
		}

		gameState.inputs = sdl.GetKeyboardStateAsSlice()

		time_update(&gameState.time)

		for (gameState.time.delta >= TICKTIME) {
			gameState.time.delta -= TICKTIME

			update_game(&gameState)
		}


		sdl.SetRenderTarget(renderer, texture_2d)
		render_clear(renderer)

		render_game(renderer, &gameState)

    sdl.SetRenderTarget(renderer, texture_3d)

    set_render_color(renderer, &COLOR_BLACK)
    sdl.RenderClear(renderer)
    set_render_color(renderer, &COLOR_BLUE)
    sdl.RenderFillRect(renderer, &sdl.Rect{0, 0, TEXTURE_WIDTH, TEXTURE_HEIGHT / 2})
    set_render_color(renderer, &COLOR_GRAY)
    sdl.RenderFillRect(renderer, &sdl.Rect{0, TEXTURE_HEIGHT / 2, TEXTURE_WIDTH, TEXTURE_HEIGHT / 2})
    render_projection(renderer, &gameState)
    
		sdl.SetRenderTarget(renderer, nil)
		sdl.RenderCopy(renderer, texture_3d, nil, nil)
		sdl.RenderCopy(renderer, texture_2d, nil, &sdl.Rect{ 20, 20, 160, 160 })
		sdl.RenderPresent(renderer)
	}
}

