package entities

import sdl "vendor:sdl2"

EntityType :: enum {
	Player,
	Pipe,
}

Entity :: struct {
	type:     EntityType,
	pos:      [2]f32,
	mov:      [2]f32 ,
	isActive: bool,
}

UpdateEntity :: proc(entity: ^Entity, game_state: ^GameState) {
	switch (entity.type) {
		case EntityType.Player:
			UpdatePlayerEntity(entity, game_state)
		case EntityType.Pipe:
	}
}

RenderEntity :: proc(renderer: ^sdl.Renderer, entity: ^Entity) {
	switch (entity.type) {
		case EntityType.Player:
			RenderPlayerEntity(renderer, entity)
		case EntityType.Pipe:
	}
}