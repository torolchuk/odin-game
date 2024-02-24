package engine

import "core:fmt"
import SDL "vendor:sdl2"

Context :: struct {
  window: ^SDL.Window,
  renderer: ^SDL.Renderer,
}

CreateContext :: proc(title: cstring, width: i32, height: i32) -> Context {
  ctx := Context{}
  ctx.window = SDL.CreateWindow(
    title,
    SDL.WINDOWPOS_CENTERED,
    SDL.WINDOWPOS_CENTERED,
    width,
    height,
    {},
  )

  ctx.renderer = SDL.CreateRenderer(
    ctx.window,
    -1,
    { .TARGETTEXTURE },
  )

  assert(ctx.window != nil, SDL.GetErrorString())
  assert(ctx.renderer != nil, SDL.GetErrorString())
  
  return ctx;
}

DestroyContext :: proc(ctx: ^Context) {
  fmt.eprintln("Destroy context called")

  SDL.DestroyWindow(ctx.window)
  SDL.DestroyRenderer(ctx.renderer)
  
  free(ctx)
}

