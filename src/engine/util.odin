package engine

import sdl "vendor:sdl2"

Util_SetRenderDrawColor :: proc (renderer: ^sdl.Renderer, color: ^sdl.Color) {
  sdl.SetRenderDrawColor(
    renderer,
    color.r,
    color.g,
    color.b,
    color.a,
  )
}
