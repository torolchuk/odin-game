package main

import "core:fmt"
import "core:time"
import str "core:strings"

import SDL "vendor:sdl2"
import TTF "vendor:sdl2/ttf"

import ENG "engine"

AppState :: struct {
  ctx: ENG.Context,
  texture: ^SDL.Texture,
  gameState: ^GameState,
}

Vector2 :: struct {
  x: int,
  y: int,
}

GameState :: struct {
  pos: ^Vector2,
  mov: ^Vector2,
}

MAIN_TEXTURE_SIZE: ^Vector2 = &Vector2{
  256,
  144,
}

createDebugTexture :: proc(renderer: ^SDL.Renderer, message: cstring) -> (^SDL.Texture, ^SDL.Rect) {
  font := TTF.OpenFont("noto.ttf", 24)
  assert(font != nil, SDL.GetErrorString())
  surface := TTF.RenderText_Solid(font, message, { 0x00, 0xFF, 0x00, 0xFF })
  texture := SDL.CreateTextureFromSurface(renderer, surface)

  size := &SDL.Rect{ 0, 0, surface.w, surface.h }
  return texture, size
}

main :: proc() {
  state := AppState {};
  state.gameState = &GameState{
    &Vector2{ 0, 0 },
    &Vector2{ 1, 1 },
  }

  TTF.Init()

  state.ctx = ENG.CreateContext(
    "Hello world",
    cast(i32)MAIN_TEXTURE_SIZE.x * 4,
    cast(i32)MAIN_TEXTURE_SIZE.y * 4,
  )
  
  defer ENG.DestroyContext(&state.ctx)

  texture := SDL.CreateTexture(
    state.ctx.renderer,
    cast(u32)SDL.PixelFormatEnum.ARGB8888,
    .TARGET,
    256,
    144,
  )
  assert(texture != nil, SDL.GetErrorString())
  defer SDL.DestroyTexture(texture)
  state.texture = texture;

  lastTickTime := time.now()._nsec
  debugMenu := ENG.CreateDebugMenu()

  event: SDL.Event
  loop: for {
    for SDL.PollEvent(&event) {
      #partial switch event.type {
      case .QUIT:
          break loop
      }
    }

    state.gameState.pos.x += state.gameState.mov.x;
    state.gameState.pos.y += state.gameState.mov.y;

    if (state.gameState.pos.x >= MAIN_TEXTURE_SIZE.x || state.gameState.pos.x <= 0) {
      fmt.eprintln("before changing x")
      state.gameState.mov.x = -state.gameState.mov.x;
      fmt.eprintln("after changing x")
    }
    if (state.gameState.pos.y >= MAIN_TEXTURE_SIZE.y || state.gameState.pos.y <= 0) {
      fmt.eprintln("before changing y")
      state.gameState.mov.y = -state.gameState.mov.y;
      fmt.eprintln("after changing y")
    }

    _texture := SDL.CreateTexture(state.ctx.renderer, &SDL.Rect{0,0,MAIN_TEXTURE_SIZE.x, MAIN_TEXTURE_SIZE.y})
    SDL.SetRenderTarget(state.ctx.renderer, state.texture)
    SDL.SetRenderDrawColor(state.ctx.renderer, 0, 0, 0xFF, 0xFF)
    SDL.RenderClear(state.ctx.renderer)

    SDL.SetRenderDrawColor(state.ctx.renderer, 0xFF, 0, 0, 0xFF)
    SDL.RenderFillRect(
      state.ctx.renderer, 
      &SDL.Rect{
        cast(i32)state.gameState.pos.x,
        cast(i32)state.gameState.pos.y,
        10,
        10,
      },
    )

    SDL.SetRenderTarget(state.ctx.renderer, nil)
    SDL.RenderCopy(state.ctx.renderer, state.texture, nil, nil)

    curTickTime := time.now()._nsec
    delta := curTickTime - lastTickTime
    lastTickTime = curTickTime
    
    builder := str.Builder{}
    str.write_string(&builder, "Delta time: ")
    str.write_int(&builder, cast(int)delta)
    str.write_string(&builder, "\n")
    message := str.to_string(builder)

    debugTexture, debugRect := ENG.GetDebugInfoTexture(state.ctx.renderer, &debugMenu, "Hello world")
    SDL.RenderCopy(state.ctx.renderer, debugTexture, nil, &SDL.Rect{10, 10, debugRect.w, debugRect.h })

    SDL.RenderPresent(state.ctx.renderer)
  }
}

