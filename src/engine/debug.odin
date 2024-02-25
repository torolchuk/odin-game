package engine

import sdl "vendor:sdl2"
import ttf "vendor:sdl2/ttf"

DEBUG_TEXT_COLOR := sdl.Color{ 0x00, 0xFF, 0x00, 0xFF }

DebugMenu :: struct {
  font: ^ttf.Font,
}

CreateDebugMenu :: proc() -> DebugMenu {
  font := ttf.OpenFont("noto.ttf", 10)

  return DebugMenu{ font }
}

GetDebugInfoTexture :: proc(
  renderer: ^sdl.Renderer,
  debugMenu: ^DebugMenu,
  message: cstring
) -> (^sdl.Texture, ^sdl.Rect) {
  surface := ttf.RenderText_Solid(debugMenu.font, message, DEBUG_TEXT_COLOR)
  texture := sdl.CreateTextureFromSurface(renderer, surface)
  
  rect := &sdl.Rect{0,0,surface.w, surface.h}

  return texture, rect
}

