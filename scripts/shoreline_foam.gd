# ============================================================
# ShorelineFoam — animated foam where sand meets ocean
# ============================================================
extends Node2D

var map_state: Dictionary
var phase: float = 0.0

const FOAM_COLOR := Color(1.0, 1.0, 1.0, 0.22)
const FOAM_THICKNESS := 2.0


func _ready() -> void:
	z_index = 2
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	phase += delta * 2.4
	queue_redraw()


func _draw() -> void:
	if map_state.is_empty():
		return
	if not map_state.has("ground_data"):
		return

	var ground_data: Array = map_state["ground_data"]
	var h: int = ground_data.size()
	if h <= 2:
		return
	var w: int = (ground_data[0] as Array).size()
	if w <= 2:
		return

	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var tile: int = int(ground_data[y][x])
			if tile != GameConfig.TileType.SAND:
				continue

			var wx: float = float(x * GameConfig.TILE_SIZE)
			var wy: float = float(y * GameConfig.TILE_SIZE)
			var amp: float = 1.5 + sin(phase + float(x + y) * 0.13)

			# Draw foam line on edges where sand touches water.
			if int(ground_data[y - 1][x]) == GameConfig.TileType.WATER:
				draw_line(Vector2(wx + 2.0, wy + amp), Vector2(wx + GameConfig.TILE_SIZE - 2.0, wy + amp), FOAM_COLOR, FOAM_THICKNESS)
			if int(ground_data[y + 1][x]) == GameConfig.TileType.WATER:
				draw_line(Vector2(wx + 2.0, wy + GameConfig.TILE_SIZE - amp), Vector2(wx + GameConfig.TILE_SIZE - 2.0, wy + GameConfig.TILE_SIZE - amp), FOAM_COLOR, FOAM_THICKNESS)
			if int(ground_data[y][x - 1]) == GameConfig.TileType.WATER:
				draw_line(Vector2(wx + amp, wy + 2.0), Vector2(wx + amp, wy + GameConfig.TILE_SIZE - 2.0), FOAM_COLOR, FOAM_THICKNESS)
			if int(ground_data[y][x + 1]) == GameConfig.TileType.WATER:
				draw_line(Vector2(wx + GameConfig.TILE_SIZE - amp, wy + 2.0), Vector2(wx + GameConfig.TILE_SIZE - amp, wy + GameConfig.TILE_SIZE - 2.0), FOAM_COLOR, FOAM_THICKNESS)
