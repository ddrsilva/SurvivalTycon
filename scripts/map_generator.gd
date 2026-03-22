# ============================================================
# Procedural Island Map Generator
# Creates a large archipelago: one main island plus secondary
# islands in the outer ocean, with beaches and biomes.
# ============================================================
class_name MapGenerator
extends RefCounted

# Biome types for internal use
const BIOME_FOREST := 0
const BIOME_PLAINS := 1
const BIOME_MOUNTAIN := 2


## Generate island map data.
## Returns a MapState dictionary including map_seed for reproducibility.
static func generate(clear_radius: int, custom_seed: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if custom_seed >= 0:
		rng.seed = custom_seed
	else:
		rng.randomize()
	var map_seed: int = rng.seed

	var w := GameConfig.MAP_WIDTH
	var h := GameConfig.MAP_HEIGHT
	var cx := w / 2
	var cy := h / 2

	# 1) Build island metadata and archipelago heightmap
	var islands: Array = _build_island_specs(rng, w, h, cx, cy)
	var heightmap := _gen_archipelago_heightmap(rng, w, h, islands)

	# 2) Build biome map using Voronoi regions
	var biome_map := _gen_biome_map(rng, w, h)

	# 3) Populate ground + resource arrays
	var ground_data := []
	var resource_data := []

	for y in range(h):
		ground_data.append([])
		resource_data.append([])
		for x in range(w):
			var height: float = heightmap[y][x]
			var dist := sqrt(pow(x - cx, 2) + pow(y - cy, 2))
			var right_edge := float(x) / float(maxi(w - 1, 1))

			# Force an ocean shelf on the far right with a sand transition strip.
			if right_edge > 0.955:
				ground_data[y].append(GameConfig.TileType.WATER)
				resource_data[y].append(-1)
				continue
			elif right_edge > 0.915:
				ground_data[y].append(GameConfig.TileType.SAND)
				resource_data[y].append(-1)
				continue

			if height < 0.24:
				# Deep / shallow water
				ground_data[y].append(GameConfig.TileType.WATER)
				resource_data[y].append(-1)
			elif height < 0.34:
				# Beach sand
				ground_data[y].append(GameConfig.TileType.SAND)
				resource_data[y].append(-1)
			elif dist <= clear_radius:
				# Cleared safe zone around cabin
				if dist <= clear_radius * 0.4:
					ground_data[y].append(GameConfig.TileType.DIRT)
				else:
					ground_data[y].append(GameConfig.TileType.GRASS)
				resource_data[y].append(-1)
			else:
				# Land — biome-dependent ground + resources
				var biome: int = biome_map[y][x]
				ground_data[y].append(_biome_ground(rng, biome))
				resource_data[y].append(_roll_resource(rng, biome))

	var main_radius: float = float(islands[0].get("radius", GameConfig.MAIN_ISLAND_RADIUS))
	var threat_spawn_tiles: Array = _collect_threat_spawn_tiles(ground_data, cx, cy, main_radius)

	return {
		"ground_data": ground_data,
		"resource_data": resource_data,
		"center_x": cx,
		"center_y": cy,
		"islands": islands,
		"threat_spawn_tiles": threat_spawn_tiles,
		"map_seed": map_seed,
	}


# ── Island specs ──────────────────────────────────────────────

static func _build_island_specs(rng: RandomNumberGenerator, w: int, h: int, cx: int, cy: int) -> Array:
	var islands: Array = []
	var main_radius: float = GameConfig.MAIN_ISLAND_RADIUS + rng.randf_range(-6.0, 7.0)
	islands.append({
		"id": "main",
		"kind": "main",
		"center_x": cx,
		"center_y": cy,
		"radius": main_radius,
		"unlock_stage": 0,
	})

	var target_count: int = rng.randi_range(GameConfig.SECONDARY_ISLAND_MIN, GameConfig.SECONDARY_ISLAND_MAX)
	var attempts := 0
	while islands.size() - 1 < target_count and attempts < 220:
		attempts += 1
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(main_radius + 35.0, main_radius + 92.0)
		var ix := int(round(float(cx) + cos(angle) * dist))
		var iy := int(round(float(cy) + sin(angle) * dist))
		var ir := rng.randf_range(15.0, 28.0)

		if ix < 16 or iy < 16 or ix >= w - 16 or iy >= h - 16:
			continue

		var overlap := false
		for existing: Dictionary in islands:
			var ex: int = int(existing["center_x"])
			var ey: int = int(existing["center_y"])
			var er: float = float(existing["radius"])
			var d := Vector2(float(ix), float(iy)).distance_to(Vector2(float(ex), float(ey)))
			if d < er + ir + 14.0:
				overlap = true
				break
		if overlap:
			continue

		var island_idx: int = islands.size()
		islands.append({
			"id": "island_%d" % island_idx,
			"kind": "secondary",
			"center_x": ix,
			"center_y": iy,
			"radius": ir,
			"unlock_stage": GameConfig.BuildingStage.STONE_HALL,
		})

	return islands


# ── Heightmap: organic archipelago via overlapping bumps ─────

static func _gen_archipelago_heightmap(rng: RandomNumberGenerator, w: int, h: int, islands: Array) -> Array:
	var bumps: Array = []

	for island: Dictionary in islands:
		var icx: float = float(island["center_x"])
		var icy: float = float(island["center_y"])
		var ir: float = float(island["radius"])
		var is_main: bool = String(island.get("kind", "secondary")) == "main"

		# Core mound
		var core_strength: float = 1.30
		if is_main:
			core_strength = 1.45
		bumps.append([icx, icy, ir * rng.randf_range(1.05, 1.18), core_strength])

		# Inner bumps create irregular shores
		var inner_count: int = rng.randi_range(7, 13) if is_main else rng.randi_range(4, 8)
		for i in range(inner_count):
			var a := rng.randf() * TAU
			var d := rng.randf_range(ir * 0.12, ir * 0.95)
			var bx := icx + cos(a) * d
			var by := icy + sin(a) * d
			var br := rng.randf_range(ir * 0.25, ir * 0.62)
			var bs := rng.randf_range(0.55, 1.12)
			bumps.append([bx, by, br, bs])

	var heightmap: Array = []

	for y in range(h):
		var row: Array = []
		for x in range(w):
			var height := -0.52
			for bump: Array in bumps:
				var dx := float(x) - float(bump[0])
				var dy := float(y) - float(bump[1])
				var d := sqrt(dx * dx + dy * dy)
				var r: float = float(bump[2])
				if d < r:
					var t := 1.0 - d / r
					height += t * t * float(bump[3])

			# Push map borders toward ocean to guarantee coast around all edges
			var edge_x: float = float(x)
			var edge_x_mirror: float = float(w - 1 - x)
			if edge_x_mirror < edge_x:
				edge_x = edge_x_mirror
			edge_x = edge_x / (float(w) * 0.5)

			var edge_y: float = float(y)
			var edge_y_mirror: float = float(h - 1 - y)
			if edge_y_mirror < edge_y:
				edge_y = edge_y_mirror
			edge_y = edge_y / (float(h) * 0.5)

			var edge: float = edge_x
			if edge_y < edge:
				edge = edge_y
			edge = clampf(edge, 0.0, 1.0)
			height -= (1.0 - edge) * (1.0 - edge) * 0.36

			# Fine noise roughens shorelines and biome boundaries
			height += (rng.randf() - 0.5) * 0.08

			row.append(height)
		heightmap.append(row)

	return heightmap


# ── Biome map: Voronoi regions ───────────────────────────────

static func _gen_biome_map(rng: RandomNumberGenerator, w: int, h: int) -> Array:
	var centers: Array = []
	var num_centers := rng.randi_range(22, 36)
	for i in range(num_centers):
		centers.append({
			"x": rng.randf_range(float(w) * 0.1, float(w) * 0.9),
			"y": rng.randf_range(float(h) * 0.1, float(h) * 0.9),
			"biome": rng.randi_range(0, 2),
		})

	var biome_map: Array = []
	for y in range(h):
		var row: Array = []
		for x in range(w):
			var nearest_biome := 0
			var nearest_dist := 999999.0
			for c: Dictionary in centers:
				var dx := float(x) - float(c["x"])
				var dy := float(y) - float(c["y"])
				var d := dx * dx + dy * dy
				if d < nearest_dist:
					nearest_dist = d
					nearest_biome = int(c["biome"])
			row.append(nearest_biome)
		biome_map.append(row)

	return biome_map


# ── Ground tile per biome ────────────────────────────────────

static func _biome_ground(rng: RandomNumberGenerator, biome: int) -> int:
	match biome:
		BIOME_MOUNTAIN:
			return GameConfig.TileType.DIRT if rng.randf() < 0.7 else GameConfig.TileType.GRASS
		BIOME_PLAINS:
			return GameConfig.TileType.GRASS if rng.randf() < 0.9 else GameConfig.TileType.DIRT
		_:  # FOREST
			return GameConfig.TileType.GRASS


# ── Resource roll per biome ──────────────────────────────────

static func _roll_resource(rng: RandomNumberGenerator, biome: int) -> int:
	var roll := rng.randf()
	match biome:
		BIOME_FOREST:
			if roll < 0.38:
				return GameConfig.TileType.TREE_PINE
			elif roll < 0.52:
				return GameConfig.TileType.TREE_OAK
			elif roll < 0.57:
				return GameConfig.TileType.ROCK
			elif roll < 0.60:
				return GameConfig.TileType.ORE
			else:
				return -1
		BIOME_PLAINS:
			if roll < 0.08:
				return GameConfig.TileType.TREE_PINE
			elif roll < 0.14:
				return GameConfig.TileType.TREE_OAK
			elif roll < 0.19:
				return GameConfig.TileType.ROCK
			elif roll < 0.22:
				return GameConfig.TileType.ORE
			else:
				return -1
		BIOME_MOUNTAIN:
			if roll < 0.22:
				return GameConfig.TileType.ROCK
			elif roll < 0.35:
				return GameConfig.TileType.ORE
			elif roll < 0.42:
				return GameConfig.TileType.TREE_PINE
			else:
				return -1
		_:
			return -1


static func _collect_threat_spawn_tiles(ground_data: Array, cx: int, cy: int, main_radius: float) -> Array:
	var tiles: Array = []
	var min_dist: float = main_radius * 0.72
	var max_dist: float = main_radius + 30.0

	for y in range(1, GameConfig.MAP_HEIGHT - 1):
		for x in range(1, GameConfig.MAP_WIDTH - 1):
			if int(ground_data[y][x]) != GameConfig.TileType.WATER:
				continue

			var d := Vector2(float(x), float(y)).distance_to(Vector2(float(cx), float(cy)))
			if d < min_dist or d > max_dist:
				continue

			var near_land := false
			if int(ground_data[y - 1][x]) != GameConfig.TileType.WATER:
				near_land = true
			elif int(ground_data[y + 1][x]) != GameConfig.TileType.WATER:
				near_land = true
			elif int(ground_data[y][x - 1]) != GameConfig.TileType.WATER:
				near_land = true
			elif int(ground_data[y][x + 1]) != GameConfig.TileType.WATER:
				near_land = true

			if near_land:
				tiles.append(Vector2i(x, y))

	if tiles.is_empty():
		for y in range(1, GameConfig.MAP_HEIGHT - 1):
			for x in range(1, GameConfig.MAP_WIDTH - 1):
				if int(ground_data[y][x]) == GameConfig.TileType.WATER:
					tiles.append(Vector2i(x, y))

	return tiles


## Apply map data to a TileMap using layer 0 = ground, layer 1 = resources.
static func apply_to_tilemap(map_state: Dictionary, tilemap: TileMap) -> void:
	for y in range(GameConfig.MAP_HEIGHT):
		for x in range(GameConfig.MAP_WIDTH):
			var ground_tile: int = map_state["ground_data"][y][x]
			tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(ground_tile, 0))

			var res_tile: int = map_state["resource_data"][y][x]
			if res_tile >= 0:
				tilemap.set_cell(1, Vector2i(x, y), 0, Vector2i(res_tile, 0))


## Clear tiles in a radius (for evolution expansion).
static func clear_area(map_state: Dictionary, new_radius: int, tilemap: TileMap) -> void:
	var cx: int = map_state["center_x"]
	var cy: int = map_state["center_y"]

	for y in range(GameConfig.MAP_HEIGHT):
		for x in range(GameConfig.MAP_WIDTH):
			var dist := sqrt(pow(x - cx, 2) + pow(y - cy, 2))
			if dist <= new_radius and map_state["resource_data"][y][x] >= 0:
				map_state["resource_data"][y][x] = -1
				tilemap.erase_cell(1, Vector2i(x, y))
				if dist <= new_radius * 0.4:
					map_state["ground_data"][y][x] = GameConfig.TileType.DIRT
				else:
					map_state["ground_data"][y][x] = GameConfig.TileType.GRASS
				tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(map_state["ground_data"][y][x], 0))
