# ============================================================
# WorldFallback — Draws the map using primitive shapes.
# This guarantees a visible world even if TileMap textures fail.
# ============================================================
extends Node2D

var map_state: Dictionary

func _ready() -> void:
	z_index = -100
	queue_redraw()


func _draw() -> void:
	if map_state.is_empty():
		return

	for y in range(GameConfig.MAP_HEIGHT):
		for x in range(GameConfig.MAP_WIDTH):
			var p := Vector2(x * GameConfig.TILE_SIZE, y * GameConfig.TILE_SIZE)
			var rect := Rect2(p, Vector2(GameConfig.TILE_SIZE, GameConfig.TILE_SIZE))
			var ground: int = map_state["ground_data"][y][x]
			if ground == GameConfig.TileType.WATER:
				draw_rect(rect, Color(0.18, 0.35, 0.58))
			elif ground == GameConfig.TileType.SAND:
				draw_rect(rect, Color(0.82, 0.72, 0.52))
			elif ground == GameConfig.TileType.DIRT:
				draw_rect(rect, Color(0.50, 0.42, 0.30))
			else:
				draw_rect(rect, Color(0.28, 0.49, 0.24))

			var res: int = map_state["resource_data"][y][x]
			if res == GameConfig.TileType.TREE_PINE or res == GameConfig.TileType.TREE_OAK:
				draw_circle(p + Vector2(16, 14), 10.0, Color(0.16, 0.35, 0.16))
				draw_rect(Rect2(p + Vector2(14, 18), Vector2(4, 10)), Color(0.35, 0.22, 0.12))
			elif res == GameConfig.TileType.ROCK:
				draw_circle(p + Vector2(16, 18), 8.0, Color(0.52, 0.52, 0.52))
			elif res == GameConfig.TileType.ORE:
				draw_circle(p + Vector2(16, 18), 8.0, Color(0.45, 0.45, 0.45))
				draw_rect(Rect2(p + Vector2(14, 16), Vector2(4, 3)), Color(0.85, 0.66, 0.15))
			elif res == GameConfig.TileType.LOG_PILE:
				draw_rect(Rect2(p + Vector2(10, 18), Vector2(12, 6)), Color(0.45, 0.30, 0.12))
