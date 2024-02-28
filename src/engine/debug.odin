package engine

import sdl "vendor:sdl2"
import ttf "vendor:sdl2/ttf"

import str "core:strings"

FONT_PATH := "noto.ttf"
DEBUG_TEXT_COLOR := sdl.Color{ 0x00, 0xFF, 0x00, 0xFF }

DebugMenu :: struct {
  font: ^ttf.Font,
}

CreateDebugConfig :: proc() -> DebugMenu {
  if (ttf.WasInit() == 0) {
    ttf.Init()
  }

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

@(private)
Debugger_NextLine :: proc(
  builder: ^str.Builder
) {
  str.write_string(builder, "\n")
}

Debugger_AddLine :: proc(
  builder: ^str.Builder,
  text: string,
) {
  str.write_string(builder, text)
  Debugger_NextLine(builder)
}

Debugger_AddIntLine :: proc(
  builder: ^str.Builder,
  prefix: string,
  data: int,
  suffix: string = "",
) {
  str.write_string(builder, prefix)
  str.write_int(builder, data)
  str.write_string(builder, suffix)
  Debugger_NextLine(builder)
}

Debugger_AddStringLine :: proc(
  builder: ^str.Builder,
  prefix: string,
  data: string,
  suffix: string = "",
) {
  str.write_string(builder, prefix)
  str.write_string(builder, data)
  str.write_string(builder, suffix)
  Debugger_NextLine(builder)
}

