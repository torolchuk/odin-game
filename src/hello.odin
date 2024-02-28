package main

import "core:fmt"
import "core:time"
import str "core:strings"

import sdl "vendor:sdl2"
import sdl_ttf "vendor:sdl2/ttf"

import const "constants"
import engine "engine"
import entities "entities"

get_time :: proc() -> f64 {
	return f64(sdl.GetPerformanceCounter()) * 1000 / f64(sdl.GetPerformanceFrequency())
}

main :: proc() {
	ctx := engine.CreateContext(
		"Hello world",
		cast(i32)(const.MAIN_TEXTURE_SIZE.x * const.SCREEN_UPSCALE),
		cast(i32)(const.MAIN_TEXTURE_SIZE.y * const.SCREEN_UPSCALE),
	)

	keyboard := []u8{}

	defer engine.DestroyContext(&ctx)

	texture := sdl.CreateTexture(
		ctx.renderer,
		cast(u32)sdl.PixelFormatEnum.ARGB8888,
		.TARGET,
		cast(i32)const.MAIN_TEXTURE_SIZE.x,
		cast(i32)const.MAIN_TEXTURE_SIZE.y,
	)
	assert(texture != nil, sdl.GetErrorString())
	defer sdl.DestroyTexture(texture)

	lastTickTime := get_time()
	debugConfig := engine.CreateDebugConfig()

	initialPlayerPos := engine.Vec2{
		cast(f32)(const.MAIN_TEXTURE_SIZE[0] / 3),
		cast(f32)(const.MAIN_TEXTURE_SIZE[1] / 2),
	}

	player := entities.Entity {
		type     = .Player,
		pos      = initialPlayerPos,
		mov      = [2]f32{0, 0},
		isActive = true,
	}

	event: sdl.Event
	loop: for {
		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				break loop
			}
		}

		keyboard = sdl.GetKeyboardStateAsSlice()

		entities.UpdateEntity(&player, &GameState{})

		sdl.SetRenderTarget(ctx.renderer, texture)
		engine.Util_SetRenderDrawColor(ctx.renderer, &const.COLOR_BLACK)
		sdl.RenderClear(ctx.renderer)

		entities.RenderEntity(ctx.renderer, &player)

		engine.Util_SetRenderDrawColor(ctx.renderer, &const.COLOR_GREED)

		curTickTime := get_time()
		delta := curTickTime - lastTickTime
		lastTickTime = curTickTime

		sdl.SetRenderTarget(ctx.renderer, nil)
		sdl.RenderCopy(ctx.renderer, texture, nil, nil)

		builder := str.Builder{}
		// engine.Debugger_AddLine(&builder, "Your current game session")
		engine.Debugger_AddIntLine(&builder, "Delta time: ", cast(int)delta, "")
		// engine.Debugger_AddStringLine(&builder, "Player Vector: ", str.to_string(player.mov[1]), "")
		message := str.to_string(builder)

		fmt.eprintln(message)

		debugTexture, debugRect := engine.GetDebugInfoTexture(
			ctx.renderer,
			&debugConfig,
			str.clone_to_cstring(message),
		)

		sdl.RenderCopy(ctx.renderer, debugTexture, nil, debugRect)

		sdl.RenderPresent(ctx.renderer)
	}
}
