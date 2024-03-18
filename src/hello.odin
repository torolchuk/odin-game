package main
import "core:fmt"
import "core:time"
import strings "core:strings"
import math "core:math"
import rnd "core:math/rand"

import sdl "vendor:sdl2"
import ttf "vendor:sdl2/ttf"

APP_NAME :: "BIRDS OF ODIN"

Context :: struct {
	window:   ^sdl.Window,
	renderer: ^sdl.Renderer,
	texture:  ^sdl.Texture,
}

GameTime :: struct {
  last: f64,
  delta: f64,
}

AppState :: struct {
  scene: GameScene,
	inputs: []u8,
  time: GameTime,
  delta: f64,
  entity: ^Entity,
	pipes: [3]Entity,
  rand: ^rnd.Rand,
  score: int,
}

GameScene :: enum {
  MainMenu,
  InGame,
  Death,
}

EntityType :: enum {
	Player,
	Pipe,
}

PIPE_ACTIVATED_FLAG_INDEX :: 0

Entity :: struct {
	type: EntityType,
	pos: [2]f32,
  vel: [2]f32,
  flags: [8]byte,
}

PLAYER_WIDTH, PLAYER_HEIGHT:i32 = 24.0, 24.0

get_player_rect :: proc(player: ^Entity) -> sdl.Rect {
  return sdl.Rect{
    cast(i32)player.pos[0] - PLAYER_WIDTH / 2,
    cast(i32)player.pos[1] - PLAYER_HEIGHT / 2,
    PLAYER_WIDTH,
    PLAYER_HEIGHT,
  }
}

render_player :: proc(renderer: ^sdl.Renderer, entity: ^Entity) {
  playerRect := get_player_rect(entity)

  sdl.SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff)
  sdl.RenderDrawRect(renderer, &playerRect)

  bobblingy := cast(i32)entity.vel[1] / 20 
  sdl.RenderDrawRect(renderer, &sdl.Rect{
    playerRect.x + playerRect.w - 3,
    playerRect.y + (playerRect.h / 2) + bobblingy - 3,
    6,
    6,
  })
  sdl.RenderDrawRect(renderer, &sdl.Rect{
    playerRect.x - 3,
    playerRect.y + (playerRect.h / 2) - bobblingy + 3,
    6,
    6,
  })
}

PIPE_WIDTH :: 32
PIPE_SPACING_X :: 140
PIPE_SPACING_Y :: 80
PIPE_OFFSET_Y :: PIPE_SPACING_Y / 2

get_pipe_top_rect :: proc (pipe: ^Entity) -> sdl.Rect {
  return sdl.Rect{
    cast(i32)pipe.pos.x - PIPE_WIDTH / 2,
    0,
    PIPE_WIDTH,
    cast(i32)pipe.pos.y - PIPE_OFFSET_Y,
  }
}

get_pipe_bottom_rect :: proc(pipe: ^Entity) -> sdl.Rect {
  return sdl.Rect{
    cast(i32)pipe.pos.x - PIPE_WIDTH / 2,
    cast(i32)pipe.pos.y + PIPE_OFFSET_Y,
    PIPE_WIDTH,
    MAIN_TEXTURE_SIZE[1] - cast(i32)pipe.pos.y - PIPE_OFFSET_Y, 
  }
}

get_pipe_success_rect :: proc(pipe: ^Entity) -> sdl.Rect {
  return sdl.Rect{
    cast(i32)pipe.pos.x + PIPE_WIDTH / 2,
    cast(i32)pipe.pos.y - PIPE_SPACING_Y / 2,
    PIPE_WIDTH,
    PIPE_SPACING_Y,
  }
}

render_pipe :: proc(renderer: ^sdl.Renderer, entity: ^Entity) {
  sdl.SetRenderDrawColor(renderer, 0xEE,0xEE,0xEE,0xFF)
  topRect := get_pipe_top_rect(entity)
  sdl.RenderDrawRect(renderer, &topRect)
  
  bottomRect := get_pipe_bottom_rect(entity)
  sdl.RenderDrawRect(renderer, &bottomRect)
}

render_entity :: proc(renderer: ^sdl.Renderer, entity: ^Entity) {
  switch(entity.type) {
    case EntityType.Player:
      render_player(renderer, entity)
      break;
    case EntityType.Pipe:
      render_pipe(renderer, entity)
      break;
  }
}

create_text_texture :: proc(
  renderer: ^sdl.Renderer,
  font: ^ttf.Font,
  message: cstring,
) -> (_texture: ^sdl.Texture, _rect: sdl.Rect) {
  surface := ttf.RenderText_Solid(font, message, sdl.Color{ 0xff, 0xff, 0xff, 0xff })
  texture := sdl.CreateTextureFromSurface(renderer, surface)
  rect := sdl.Rect{
    0,
    0,
    surface.w,
    surface.h,
  }

  return texture, rect;
}

FONT: ^ttf.Font

render_main_menu :: proc(renderer: ^sdl.Renderer) {
  if (ttf.WasInit() < 1) {
    ttf.Init()
  }
  if (FONT == nil) {
    FONT = ttf.OpenFont("noto.ttf", 12)
  }
  
  logo_texture, logo_rect := create_text_texture(renderer, FONT, APP_NAME)
  sdl.RenderCopy(renderer, logo_texture, nil, &sdl.Rect{
    MAIN_TEXTURE_SIZE[0] / 2 - logo_rect.w / 2,
    MAIN_TEXTURE_SIZE[1] / 2 - logo_rect.h / 2 - 40,
    logo_rect.w,
    logo_rect.h,
  })
  
  cta_texture, cta_rect := create_text_texture(renderer, FONT, "Press <space> to play")
  sdl.RenderCopy(renderer, cta_texture, nil, &sdl.Rect{
    MAIN_TEXTURE_SIZE[0] / 2 - cta_rect.w / 4,
    MAIN_TEXTURE_SIZE[1] / 2 - cta_rect.h / 4 + logo_rect.h - 20,
    cta_rect.w / 2,
    cta_rect.h / 2,
  })
}

render_death :: proc(renderer: ^sdl.Renderer, state: ^AppState) {
  if (ttf.WasInit() < 1) {
    ttf.Init()
  }
  if (FONT == nil) {
    FONT = ttf.OpenFont("noto.ttf", 12)
  }

  score_texture, score_rect := create_text_texture(
    renderer,
    FONT,
    strings.clone_to_cstring(get_score_text(state.score)),
  )
  sdl.RenderCopy(renderer, score_texture, &score_rect, &sdl.Rect{
    MAIN_TEXTURE_SIZE[0] / 2 - score_rect.w / 2,
    60,
    score_rect.w,
    score_rect.h,
  })

  // delete score_rect
  
  logo_texture, logo_rect := create_text_texture(renderer, FONT, "YOU'RE DEAD")
  sdl.RenderCopy(renderer, logo_texture, nil, &sdl.Rect{
    MAIN_TEXTURE_SIZE[0] / 2 - logo_rect.w / 2,
    MAIN_TEXTURE_SIZE[1] / 2 - logo_rect.h / 2,
    logo_rect.w,
    logo_rect.h,
  })
  
  cta_texture, cta_rect := create_text_texture(renderer, FONT, "Press <escape> to quit")
  sdl.RenderCopy(renderer, cta_texture, nil, &sdl.Rect{
    MAIN_TEXTURE_SIZE[0] / 2 - cta_rect.w / 4,
    MAIN_TEXTURE_SIZE[1] / 2 - cta_rect.h / 4 + logo_rect.h + 20,
    cta_rect.w / 2,
    cta_rect.h / 2,
  })
}

get_score_text :: proc(score: int) -> string {
  builder := strings.Builder{}
  strings.write_string(&builder, "Your score: ")
  strings.write_int(&builder, score)
  res := strings.to_string(builder)

  return res
}

render_ingame :: proc(renderer: ^sdl.Renderer, state: ^AppState) {
  score := strings.clone_to_cstring(get_score_text(state.score))

  score_texture, score_rect := create_text_texture(renderer, FONT, score)
 
  fmt.eprintln(score_rect)
  sdl.RenderCopy(renderer, score_texture, &score_rect, &sdl.Rect{
    MAIN_TEXTURE_SIZE[0] / 2 - score_rect.w / 2,
    20,
    score_rect.w,
    score_rect.h,
  })
}

PLAYER_JUMP_VELOCITY :: -100
PLAYER_GRAVITY_VEL :: 1
PLAYER_GRAVITY_LIMIT :: 100

update_player :: proc(entity: ^Entity, state: ^AppState) {
  isJumpPressed := b8(state.inputs[sdl.SCANCODE_SPACE])

  if (isJumpPressed) {
    entity.vel[1] = PLAYER_JUMP_VELOCITY
  } else { 
    entity.vel[1] = math.min(entity.vel[1] + PLAYER_GRAVITY_VEL, PLAYER_GRAVITY_LIMIT)
  }

  entity.pos += entity.vel * f32(TICKTIME) / 1000.0
}

PIPE_MOV_SPEED :: 1
update_pipe :: proc(entity: ^Entity, state: ^AppState) {
  entity.pos[0] -= PIPE_MOV_SPEED *f32(TICKRATE) / 1000.0

  if (entity.pos[0] <= f32(-PIPE_WIDTH * 2)) {
    entity.flags[PIPE_ACTIVATED_FLAG_INDEX] = 0o0
    entity.pos[0] += f32(PIPE_SPACING_X) * 3.0
    entity.pos[1] = get_random_pipe_y(state.rand)
  } 
}

update_entity :: proc(entity: ^Entity, state: ^AppState) {
  switch(entity.type) {
    case .Player:
      update_player(entity, state)
      break
    case .Pipe:
      update_pipe(entity, state)
      break
  }
}

check_rect_collision :: proc(recta: ^sdl.Rect, rectb: ^sdl.Rect) -> bool {
  lefta := recta.x
  righta := recta.x + recta.w
  topa := recta.y
  bottoma := recta.y + recta.h
  
  leftb := rectb.x
  rightb := rectb.x + rectb.w
  topb := rectb.y
  bottomb := rectb.y + rectb.h
  
  return !(
    bottoma <= topb ||
    topa >= bottomb ||
    righta <= leftb ||
    lefta >= rightb)
}

check_boundaries :: proc (player: ^Entity) -> bool {
  posy := cast(i32)player.pos[1]
  offset := PLAYER_HEIGHT / 2
  return (
    posy - offset <= 0 ||
    posy + offset >= MAIN_TEXTURE_SIZE[1])
}

check_pipe_collision :: proc(pipe: ^Entity, player: ^Entity) -> bool {
  playerRect := get_player_rect(player)
  topPipeRect := get_pipe_top_rect(pipe)
  bottomPipeRect := get_pipe_bottom_rect(pipe)

  return (
    check_rect_collision(&playerRect, &topPipeRect) || 
    check_rect_collision(&playerRect, &bottomPipeRect))
}

check_death :: proc(state: ^AppState, player: ^Entity) -> bool {
  if (check_boundaries(player)) {
    return true
  }

  for _, i in state.pipes {
    if (check_pipe_collision(&state.pipes[i], player)) {
      return true
    }
  }
  return false;
}

check_pipe_passed :: proc(player: ^Entity, pipe: ^Entity) -> bool {
  isPipeActivated := pipe.flags[PIPE_ACTIVATED_FLAG_INDEX];
  if (bool(isPipeActivated)) {
    return false
  }

  pipeRect := get_pipe_success_rect(pipe)
  playerRect := get_player_rect(player)
  return check_rect_collision(&playerRect, &pipeRect);
}

check_score_up :: proc(state: ^AppState, player: ^Entity) -> bool {
  for _, i in state.pipes {
    if (check_pipe_passed(player, &state.pipes[i])) {
      state.pipes[i].flags[PIPE_ACTIVATED_FLAG_INDEX] = 0o1
      return true;
    }
  }
  return false;
}

// WINDOW
MAIN_TEXTURE_SIZE :: [2]i32{160.0, 240.0}
WINDOW_SCALING :: 4

// TIME
TICKRATE :: 240.0
TICKTIME :: 1000.0 / TICKRATE

get_time :: proc() -> f64 {
  return f64(sdl.GetPerformanceCounter()) * 1000 / f64(sdl.GetPerformanceFrequency())
}

get_random_pipe_y :: proc(rand: ^rnd.Rand) -> f32 {
  return rnd.float32_range(.25, .75, rand) * cast(f32)MAIN_TEXTURE_SIZE[1]
}

main :: proc() {
  rand := rnd.create(cast(u64)get_time())
  state := &AppState{
    scene = .MainMenu,
    time = GameTime{ get_time(), 0 },
    rand = &rand,
    pipes = [3]Entity{ 
      Entity{
        .Pipe,
        [2]f32{
          f32(MAIN_TEXTURE_SIZE[0]),
          get_random_pipe_y(&rand),
        },
        [2]f32{},
        0,
      },
      Entity{
        .Pipe,
        [2]f32{
          f32(MAIN_TEXTURE_SIZE[0]) + f32(PIPE_SPACING_X),
          get_random_pipe_y(&rand),
        },
        [2]f32{},
        0,
      },
      Entity{
        .Pipe,
        [2]f32{
          f32(MAIN_TEXTURE_SIZE[0]) + f32(PIPE_SPACING_X) * 2.0,
          get_random_pipe_y(&rand),
        },
        [2]f32{},
        0,
      },
    },
  }
	ctx := &Context{}

	ctx.window = sdl.CreateWindow(
		APP_NAME,
		sdl.WINDOWPOS_CENTERED,
		sdl.WINDOWPOS_CENTERED,
		MAIN_TEXTURE_SIZE[0] * WINDOW_SCALING,
		MAIN_TEXTURE_SIZE[1] * WINDOW_SCALING,
		sdl.WINDOW_SHOWN,
	)
	assert(ctx.window != nil, sdl.GetErrorString())
	defer sdl.DestroyWindow(ctx.window)

	ctx.renderer = sdl.CreateRenderer(ctx.window, -1, {.ACCELERATED, .TARGETTEXTURE})
	assert(ctx.renderer != nil, sdl.GetErrorString())
	defer sdl.DestroyRenderer(ctx.renderer)

	ctx.texture = sdl.CreateTexture(
		ctx.renderer,
		cast(u32)sdl.PixelFormatEnum.ARGB8888,
		.TARGET,
		MAIN_TEXTURE_SIZE[0],
		MAIN_TEXTURE_SIZE[1],
	)
	assert(ctx.texture != nil, sdl.GetErrorString())
	defer sdl.DestroyTexture(ctx.texture)

  player := &Entity{
    .Player,
    [2]f32{
      cast(f32)MAIN_TEXTURE_SIZE[0] / 3,
      cast(f32)MAIN_TEXTURE_SIZE[1] / 2,
    },
    [2]f32{ 0, 0 },
    0,
  }

	for {
		event: sdl.Event
    for sdl.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				return
			}
    }

    state.inputs = sdl.GetKeyboardStateAsSlice()
    
    currentTime := get_time()
    state.time.delta = currentTime - state.time.last
    state.time.last = currentTime

    for (state.time.delta >= TICKTIME) {
      state.time.delta -= TICKTIME

      switch (state.scene) { 
        case .InGame:
          update_entity(player, state)

          for _, i in state.pipes {
            update_entity(&state.pipes[i], state)
          }

          if (check_death(state, player)) {
            state.scene = .Death
          } else if (check_score_up(state, player)) {
            state.score += 1
          }
          break;
        case .MainMenu:
          if (b8(state.inputs[sdl.SCANCODE_SPACE])) {
            state.scene = .InGame
          }
          break;
        case .Death:
          if (b8(state.inputs[sdl.SCANCODE_ESCAPE])) {
            return
          }

          for _, i in state.pipes {
            update_entity(&state.pipes[i], state)
          }

          break;
      }
    }

    sdl.SetRenderDrawColor(ctx.renderer, 0x00, 0x00, 0x00, 0xFF)
    sdl.RenderClear(ctx.renderer)
    sdl.SetRenderTarget(ctx.renderer, ctx.texture)
    sdl.RenderClear(ctx.renderer)

    switch(state.scene) {
      case .MainMenu:
        render_main_menu(ctx.renderer)
        break;
      case .Death:
        for _, i in state.pipes {
          render_entity(ctx.renderer, &state.pipes[i])
        }
        render_death(ctx.renderer, state)
        break;
      case .InGame:
        render_entity(ctx.renderer, player)
        for _, i in state.pipes {
          render_entity(ctx.renderer, &state.pipes[i])
        }

        render_ingame(ctx.renderer, state)
        break;
    }

    sdl.SetRenderTarget(ctx.renderer, nil)
    sdl.RenderCopy(ctx.renderer, ctx.texture, nil, nil)
    sdl.RenderPresent(ctx.renderer)
	}
}
