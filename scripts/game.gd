# ============================================================
# Game Scene — Main gameplay script
# Orchestrates map, villagers, threats, camera, and managers
# ============================================================
extends Node2D

const AssetGenerator = preload("res://scripts/asset_generator.gd")
const MapGenerator = preload("res://scripts/map_generator.gd")
const BuildingManager = preload("res://scripts/building_manager.gd")

var textures: Dictionary
var map_state: Dictionary
var bm

var villagers: Array = []
var threat_spawn_timer := 0.0
var wave_count := 0
var game_over := false

# Cabin health
var cabin_hp: int = GameConfig.CABIN_MAX_HP
var cabin_max_hp: int = GameConfig.CABIN_MAX_HP

@onready var tilemap: TileMap = $TileMap
@onready var building_sprite: Sprite2D = $BuildingSprite
@onready var campfire_sprite: Sprite2D = $CampfireSprite
@onready var chest_sprite: Sprite2D = $ChestSprite
@onready var villager_container: Node2D = $Villagers
@onready var threat_container: Node2D = $Threats
@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUD

var campfire_light: PointLight2D
var fallback_world: Node2D
var is_dragging_camera := false
var drag_anchor_world := Vector2.ZERO
var campfire_anim_enabled := false
var campfire_anim_timer := 0.0

const CAMPFIRE_SHEET_PATH := "res://tent/Campfire-6_frames.png"
const CAMPFIRE_FRAMES := 6
const CAMPFIRE_FPS := 10.0
const CAMPFIRE_TARGET_HEIGHT := 24.0
const TREE_CELL_W := 600
const TREE_CELL_H := 864
const TREE1_PATH := "res://trees/tree1.png"
const TREE2_PATH := "res://trees/tree2.png"

# Cabin HP bar (world-space, above building)
var cabin_hp_bar_bg: ColorRect
var cabin_hp_bar: ColorRect

# Tree sprite sheet system
var tree_nodes: Dictionary = {}  # Vector2i → TreeResource
var tree_container: Node2D
var tree_atlas: Dictionary = {}
var fog_sprite: Sprite2D
var wave_spawn_world_positions: Array = []
var world_rect: Rect2
var foam_layer: Node2D
var minimap_update_timer: float = 0.0
var day_night_layer: CanvasLayer
var day_night_overlay: ColorRect
var day_night_time: float = 0.0
var builder_repair_boost_timer: float = 0.0
var burning_tiles: Dictionary = {}
var burning_visuals: Dictionary = {}
var construction_sites: Array = []
var construction_container: Node2D
var pending_manual_builds: Dictionary = {"trap": 0, "barricade": 0}
var active_manual_building_key: String = ""
var placement_preview: Sprite2D
var placement_anchor_line: Line2D
var barricade_points: Array = []
var barricade_block_tiles: Dictionary = {}
var selected_villager: Node2D
var selected_villager_ui_timer: float = 0.0
var selected_building_data: Dictionary = {}
var hide_mode_active: bool = false

# Preloaded scenes
var villager_scene: PackedScene = preload("res://scenes/villager.tscn")
var threat_scene: PackedScene = preload("res://scenes/threat.tscn")

const FOG_TEXTURE_SIZE := 512
const CAMERA_MARGIN_TILES := 3.0
const DAY_NIGHT_CYCLE_SECONDS := 160.0
const FIRE_BURN_DURATION := 3.4
const BUILDER_CONSTRUCT_RATE := 1.0
const NON_BUILDER_CONSTRUCT_RATE := 0.15
const CAMERA_ZOOM_MIN := 0.35
const CAMERA_ZOOM_MAX := 4.0

var touch_points: Dictionary = {}
var touch_last_drag_time: Dictionary = {}
var pinch_active: bool = false
var pinch_start_distance: float = 0.0
var pinch_start_zoom: float = 1.9
var pinch_last_distance: float = 0.0


func _ready() -> void:
	# Generate all textures
	textures = AssetGenerator.generate_all()

	# Build the tileset from generated tile textures
	_build_tileset()

	# Load save data early so we can restore the exact saved map state.
	var boot_save := _read_save_data()

	# Generate or restore map
	if boot_save.has("map_tiles") and boot_save["map_tiles"] is Dictionary:
		map_state = _map_state_from_save(boot_save["map_tiles"] as Dictionary)
	else:
		var load_seed := int(boot_save.get("map_seed", -1))
		map_state = MapGenerator.generate(GameConfig.CLEAR_RADIUS, load_seed)
	MapGenerator.apply_to_tilemap(map_state, tilemap)
	_load_tree_sprite_sheet()
	_cache_wave_spawn_points()
	world_rect = Rect2(
		Vector2.ZERO,
		Vector2(float(GameConfig.MAP_WIDTH * GameConfig.TILE_SIZE), float(GameConfig.MAP_HEIGHT * GameConfig.TILE_SIZE))
	)

	# Always add a primitive fallback layer behind TileMap.
	# If texture/tile rendering fails on a machine, the world remains visible.
	fallback_world = load("res://scripts/world_fallback.gd").new()
	fallback_world.map_state = map_state
	add_child(fallback_world)

	foam_layer = load("res://scripts/shoreline_foam.gd").new()
	foam_layer.map_state = map_state
	add_child(foam_layer)

	# Tree sheet integration is temporarily disabled while fixing rendering pipeline
	tree_container = Node2D.new()
	tree_container.name = "Trees"
	add_child(tree_container)
	_spawn_tree_nodes()

	construction_container = Node2D.new()
	construction_container.name = "ConstructionSites"
	add_child(construction_container)
	_setup_manual_placement_preview()

	# Map center in world coords
	var cx: float = map_state["center_x"] * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0
	var cy: float = map_state["center_y"] * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0

	# Place building, campfire, chest
	building_sprite.position = Vector2(cx, cy)
	building_sprite.texture = textures["building_tent"]
	building_sprite.z_index = 5
	_attach_shadow(building_sprite, Vector2(50, 18), Vector2(0, 16), 0.34)

	campfire_sprite.position = Vector2(cx + 40, cy + 30)
	_setup_campfire_sprite()
	campfire_sprite.z_index = 5
	_attach_shadow(campfire_sprite, Vector2(26, 10), Vector2(0, 10), 0.22)

	# PointLight2D for campfire with warm glow
	campfire_light = PointLight2D.new()
	campfire_light.texture = _make_light_texture()
	campfire_light.color = Color(1.0, 0.85, 0.4)
	campfire_light.energy = 1.0
	campfire_light.texture_scale = 3.0
	campfire_light.shadow_enabled = false
	campfire_sprite.add_child(campfire_light)

	chest_sprite.position = Vector2(cx - 40, cy + 20)
	chest_sprite.texture = textures["chest"]
	chest_sprite.z_index = 5
	_attach_shadow(chest_sprite, Vector2(20, 8), Vector2(0, 8), 0.28)

	# Campfire sprite alpha flicker
	var tween := create_tween().set_loops()
	tween.tween_property(campfire_sprite, "modulate:a", 0.8, 0.3)
	tween.tween_property(campfire_sprite, "modulate:a", 1.0, 0.3)

	# Building manager
	bm = BuildingManager.new()
	bm.setup(building_sprite, map_state, tilemap, textures)
	bm.evolved.connect(_on_building_evolved)
	bm.building_placed.connect(_on_building_placed)
	bm.building_destroyed.connect(_on_building_destroyed)
	_rebuild_barricade_cache()
	_sync_armory_unlock_state()
	cabin_max_hp = _get_cabin_max_hp_for_stage(bm.get_stage())
	cabin_hp = cabin_max_hp

	# Connect HUD
	hud.set_building_manager(bm)
	hud.update_cabin_hp(cabin_hp, cabin_max_hp)
	hud.update_population(GameConfig.INITIAL_VILLAGERS)
	if hud.has_signal("restart_requested"):
		hud.connect("restart_requested", Callable(self, "_restart_game"))
	if hud.has_signal("save_requested"):
		hud.connect("save_requested", Callable(self, "_save_game"))
	if hud.has_signal("call_to_arms_requested"):
		hud.connect("call_to_arms_requested", Callable(self, "_on_call_to_arms_requested"))
	if hud.has_signal("promote_requested"):
		hud.connect("promote_requested", Callable(self, "_on_promote_requested"))
	if hud.has_signal("emergency_repair_requested"):
		hud.connect("emergency_repair_requested", Callable(self, "_on_emergency_repair_requested"))
	if hud.has_signal("building_upgrade_requested"):
		hud.connect("building_upgrade_requested", Callable(self, "_on_building_upgrade_requested"))
	if hud.has_method("setup_minimap"):
		hud.setup_minimap(map_state)
	if hud.has_method("set_hide_mode"):
		hud.set_hide_mode(false)

	# Cabin HP bar (world space above building)
	_create_cabin_hp_bar(cx, cy)

	# Connect resource popup
	ResourceManager.resource_added.connect(_on_resource_added)

	# Spawn villagers
	for i in range(GameConfig.INITIAL_VILLAGERS):
		var angle: float = float(i) / GameConfig.INITIAL_VILLAGERS * TAU
		var r: float = 30.0 + randf() * 20.0
		var vx: float = cx + cos(angle) * r
		var vy: float = cy + sin(angle) * r
		_spawn_villager(vx, vy, cx, cy)

	# Camera
	camera.enabled = true
	camera.make_current()
	camera.position = Vector2(cx, cy)
	camera.zoom = Vector2(1.9, 1.9)
	_clamp_camera_to_world()
	_setup_distance_fog(cx, cy)
	_setup_day_night_overlay()

	# Try loading save data (restores resources, upgrades, buildings)
	_try_load_save(boot_save)


func _read_save_data() -> Dictionary:
	if not FileAccess.file_exists("user://savegame.json"):
		return {}
	var file := FileAccess.open("user://savegame.json", FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()
	var data: Variant = json.data
	if data is Dictionary:
		return data as Dictionary
	return {}


func _build_saved_map_state() -> Dictionary:
	var threat_tiles: Array = []
	var src_threats: Array = map_state.get("threat_spawn_tiles", [])
	for t in src_threats:
		var tv: Vector2i = t
		threat_tiles.append({"x": tv.x, "y": tv.y})
	return {
		"map_seed": int(map_state.get("map_seed", -1)),
		"center_x": int(map_state.get("center_x", GameConfig.MAP_WIDTH / 2)),
		"center_y": int(map_state.get("center_y", GameConfig.MAP_HEIGHT / 2)),
		"ground_data": map_state.get("ground_data", []),
		"resource_data": map_state.get("resource_data", []),
		"threat_spawn_tiles": threat_tiles,
	}


func _map_state_from_save(saved_map: Dictionary) -> Dictionary:
	var threat_tiles: Array = []
	var saved_threats: Array = saved_map.get("threat_spawn_tiles", [])
	for t in saved_threats:
		if t is Dictionary:
			var td: Dictionary = t as Dictionary
			threat_tiles.append(Vector2i(int(td.get("x", 0)), int(td.get("y", 0))))
	var ms := {
		"map_seed": int(saved_map.get("map_seed", -1)),
		"center_x": int(saved_map.get("center_x", GameConfig.MAP_WIDTH / 2)),
		"center_y": int(saved_map.get("center_y", GameConfig.MAP_HEIGHT / 2)),
		"ground_data": saved_map.get("ground_data", []),
		"resource_data": saved_map.get("resource_data", []),
		"threat_spawn_tiles": threat_tiles,
	}
	if (ms["ground_data"] as Array).is_empty() or (ms["resource_data"] as Array).is_empty():
		return MapGenerator.generate(GameConfig.CLEAR_RADIUS, int(saved_map.get("map_seed", -1)))
	return ms


func _build_tileset() -> void:
	# Create a TileSet with an atlas from our generated tile textures
	# We'll compose all tiles into a single atlas image
	var tile_keys := ["tile_grass", "tile_dirt", "tile_tree_pine", "tile_tree_oak", "tile_rock", "tile_ore", "tile_log_pile", "tile_water", "tile_sand"]
	var atlas_width := tile_keys.size() * GameConfig.TILE_SIZE
	var atlas_img := Image.create(atlas_width, GameConfig.TILE_SIZE, false, Image.FORMAT_RGBA8)

	for i in range(tile_keys.size()):
		var tex: ImageTexture = textures[tile_keys[i]]
		var tile_img := tex.get_image()
		atlas_img.blit_rect(tile_img, Rect2i(0, 0, GameConfig.TILE_SIZE, GameConfig.TILE_SIZE),
			Vector2i(i * GameConfig.TILE_SIZE, 0))

	var atlas_tex := ImageTexture.create_from_image(atlas_img)

	# Build TileSet
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(GameConfig.TILE_SIZE, GameConfig.TILE_SIZE)

	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(GameConfig.TILE_SIZE, GameConfig.TILE_SIZE)

	# Create tiles for each column in the atlas
	for i in range(tile_keys.size()):
		source.create_tile(Vector2i(i, 0))

	tileset.add_source(source, 0)

	# Add two layers: 0 = ground, 1 = resources
	tilemap.tile_set = tileset
	if tilemap.get_layers_count() < 2:
		tilemap.add_layer(1)


func _spawn_villager(x: float, y: float, home_x: float, home_y: float) -> void:
	var v = villager_scene.instantiate()
	v.position = Vector2(x, y)
	v.home_position = Vector2(home_x, home_y)
	v.map_state = map_state
	v.tilemap = tilemap
	v.threat_group = threat_container
	v.tex_lumberjack = textures["villager_lumberjack"]
	v.tex_miner = textures["villager_miner"]
	v.tex_defender = textures["villager_defender"]
	v.tex_forester = textures.get("villager_forester", textures["villager_lumberjack"])
	v.tree_nodes = tree_nodes
	v.building_manager_ref = bm
	v.villager_died.connect(_on_villager_died)
	villager_container.add_child(v)
	villagers.append(v)
	TaskManager.add_villager(v)


func _sync_armory_unlock_state() -> void:
	if not bm:
		return
	if ResourceManager.has_method("set_sword_upgrade_unlocked"):
		ResourceManager.set_sword_upgrade_unlocked(bm.has_armory())


func _refresh_defender_scaling() -> void:
	for v in villagers:
		if not is_instance_valid(v):
			continue
		if int(v.get("role")) != GameConfig.Role.DEFENDER:
			continue
		if v.has_method("_apply_role_stat_scaling"):
			v.call("_apply_role_stat_scaling", true)


func plant_tree_at_tile(tile: Vector2i, tree_type: int = -1) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= GameConfig.MAP_WIDTH or tile.y >= GameConfig.MAP_HEIGHT:
		return false
	if int(map_state["resource_data"][tile.y][tile.x]) != -1:
		return false
	if int(map_state["ground_data"][tile.y][tile.x]) != GameConfig.TileType.DIRT:
		return false
	if tree_type != GameConfig.TileType.TREE_PINE and tree_type != GameConfig.TileType.TREE_OAK:
		tree_type = GameConfig.TileType.TREE_PINE if randf() < 0.6 else GameConfig.TileType.TREE_OAK
	map_state["resource_data"][tile.y][tile.x] = tree_type
	tilemap.set_cell(1, tile, 0, Vector2i(tree_type, 0))
	_spawn_single_tree_node(tile, tree_type)
	return true


func _spawn_single_tree_node(tile: Vector2i, tree_type: int) -> void:
	if tree_atlas.is_empty() or not tree_container:
		return
	if tree_nodes.has(tile):
		var existing = tree_nodes[tile]
		if is_instance_valid(existing):
			existing.queue_free()
		tree_nodes.erase(tile)
	var tree_script := load("res://scripts/tree_resource.gd")
	if tree_script == null:
		return
	var chop_arr: Array = []
	if tree_atlas.has("chop_0"):
		chop_arr = [tree_atlas["chop_0"], tree_atlas.get("chop_1"), tree_atlas.get("chop_2"), tree_atlas.get("chop_3")]
	var fall_arr: Array = []
	if tree_atlas.has("fall_0"):
		fall_arr = [tree_atlas["fall_0"], tree_atlas.get("fall_1"), tree_atlas.get("fall_2")]
	var pine_variants: Array = tree_atlas.get("static_pine_variants", [])
	var oak_variants: Array = tree_atlas.get("static_oak_variants", [])
	if pine_variants.is_empty() or oak_variants.is_empty():
		return
	var static_tex: Texture2D
	if tree_type == GameConfig.TileType.TREE_OAK:
		static_tex = oak_variants[randi() % oak_variants.size()]
	else:
		static_tex = pine_variants[randi() % pine_variants.size()]
	var tree = tree_script.new()
	tree.position = Vector2(tile.x * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0, tile.y * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0)
	tree.tile_pos = tile
	tree_container.add_child(tree)
	tree.setup(static_tex, chop_arr, fall_arr, tree_atlas.get("stump"), tree_atlas.get("log_pile"))
	tree_nodes[tile] = tree
	tilemap.erase_cell(1, tile)


func _spawn_wave() -> void:
	wave_count += 1
	var stage: int = bm.get_stage() if bm else 0
	var scaling: Dictionary = GameConfig.EVOLUTION_SCALING.get(stage, GameConfig.EVOLUTION_SCALING[0])
	var count := GameConfig.WAVE_BASE_COUNT + (wave_count - 1) * GameConfig.WAVE_GROWTH + int(scaling["wave_extra"])

	var cx: float = map_state["center_x"] * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0
	var cy: float = map_state["center_y"] * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0

	for i in range(count):
		var spawn_pos: Vector2 = _pick_wave_spawn_world(Vector2(cx, cy))
		if i == 0 and hud and hud.has_method("show_wave_warning"):
			hud.show_wave_warning(camera.position, spawn_pos)
		var sx: float = spawn_pos.x
		var sy: float = spawn_pos.y

		# Choose enemy type based on evolution stage
		var etype: int = GameConfig.EnemyType.SLIME
		if stage >= GameConfig.BuildingStage.STONE_HALL and randf() < 0.2:
			etype = GameConfig.EnemyType.BEAR
		elif wave_count >= 3 and randf() < 0.35:
			etype = GameConfig.EnemyType.WOLF

		var t = threat_scene.instantiate()
		t.position = Vector2(sx, sy)
		t.target_position = Vector2(cx, cy)
		t.setup_type(etype)

		# Apply evolution scaling to stats
		t.hp = int(t.hp * scaling["hp_mult"])
		t.max_hp = t.hp
		t.speed *= scaling["speed_mult"]
		t.damage = int(t.damage * scaling["dmg_mult"])

		# Set texture based on type
		match etype:
			GameConfig.EnemyType.SLIME:
				t.get_node("Sprite2D").texture = textures["slime"]
			GameConfig.EnemyType.WOLF:
				t.get_node("Sprite2D").texture = textures["wolf"]
			GameConfig.EnemyType.BEAR:
				t.get_node("Sprite2D").texture = textures.get("bear", textures["wolf"])

		t.reached_cabin.connect(_on_threat_reached_cabin)
		t.died.connect(_on_threat_died)
		t.villager_group = villager_container
		t.path_resolver = Callable(self, "_resolve_threat_step")
		threat_container.add_child(t)

	# Camera shake on wave arrival
	apply_shake(4.0)


func _cache_wave_spawn_points() -> void:
	wave_spawn_world_positions.clear()
	if map_state.has("threat_spawn_tiles"):
		var spawn_tiles: Array = map_state["threat_spawn_tiles"]
		for tile: Vector2i in spawn_tiles:
			wave_spawn_world_positions.append(Vector2(
				float(tile.x * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2),
				float(tile.y * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2)
			))


func _pick_wave_spawn_world(target_pos: Vector2) -> Vector2:
	if wave_spawn_world_positions.is_empty():
		# Fallback: spawn on an outer ring if no shoreline cache exists.
		var angle := randf() * TAU
		var r := GameConfig.MAIN_ISLAND_RADIUS * GameConfig.TILE_SIZE * randf_range(0.95, 1.2)
		var p := target_pos + Vector2(cos(angle), sin(angle)) * r
		p.x = clampf(p.x, 16.0, world_rect.size.x - 16.0)
		p.y = clampf(p.y, 16.0, world_rect.size.y - 16.0)
		return p

	var idx := randi() % wave_spawn_world_positions.size()
	return wave_spawn_world_positions[idx]


func _resolve_threat_step(current_pos: Vector2, target_pos: Vector2, step: float) -> Vector2:
	var to_target := target_pos - current_pos
	if to_target.length() <= 0.001:
		return current_pos

	var forward := to_target.normalized()
	var candidate := current_pos + forward * step
	if not _is_point_blocked_by_barricade(candidate):
		return candidate

	var best_pos := current_pos
	var best_score := INF
	for a_deg in [35.0, -35.0, 70.0, -70.0, 105.0, -105.0, 140.0, -140.0]:
		var dir := forward.rotated(deg_to_rad(a_deg))
		var p := current_pos + dir * step
		if _is_point_blocked_by_barricade(p):
			continue
		var score := p.distance_to(target_pos)
		if score < best_score:
			best_score = score
			best_pos = p

	if best_pos == current_pos:
		best_pos = current_pos + forward * (step * 0.2)

	best_pos.x = clampf(best_pos.x, 8.0, world_rect.size.x - 8.0)
	best_pos.y = clampf(best_pos.y, 8.0, world_rect.size.y - 8.0)
	return best_pos


func _is_point_blocked_by_barricade(point: Vector2) -> bool:
	if barricade_block_tiles.is_empty():
		return false
	var tx := int(floor(point.x / GameConfig.TILE_SIZE))
	var ty := int(floor(point.y / GameConfig.TILE_SIZE))
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			var key := Vector2i(tx + ox, ty + oy)
			if barricade_block_tiles.has(key):
				var bp: Vector2 = barricade_block_tiles[key]
				if bp.distance_to(point) <= GameConfig.BARRICADE_BLOCK_RADIUS:
					return true
	return false


func _rebuild_barricade_cache() -> void:
	barricade_points.clear()
	barricade_block_tiles.clear()
	if not bm:
		return
	for bld in bm.get_buildings():
		if not (bld is Dictionary):
			continue
		var bd: Dictionary = bld as Dictionary
		if String(bd.get("key", "")) != "barricade":
			continue
		if int(bd.get("hp", 0)) <= 0:
			continue
		var bp: Vector2 = bd.get("position", Vector2.ZERO)
		barricade_points.append(bp)
		var tx := int(floor(bp.x / GameConfig.TILE_SIZE))
		var ty := int(floor(bp.y / GameConfig.TILE_SIZE))
		barricade_block_tiles[Vector2i(tx, ty)] = bp


func _process(delta: float) -> void:
	if game_over:
		return

	_clamp_camera_to_world()

	_update_campfire_animation(delta)
	_flicker_campfire_light(delta)

	# Tower attacks (watch tower at wooden cabin+, ballista at stone hall)
	if bm and bm.get_stage() >= GameConfig.BuildingStage.WOODEN_CABIN:
		_update_tower_attacks(delta)
	_update_traps(delta)

	_update_day_night(delta)
	_update_burning(delta)
	_update_construction(delta)
	_update_manual_placement_preview()
	selected_villager_ui_timer += delta
	if selected_villager_ui_timer >= 0.2:
		selected_villager_ui_timer = 0.0
		_update_selected_villager_hud()
		_update_selected_building_hud()
	if builder_repair_boost_timer > 0.0:
		builder_repair_boost_timer = maxf(0.0, builder_repair_boost_timer - delta)

	# Wave spawning
	var tutorial_done := true
	if hud and hud.has_method("is_tutorial_completed"):
		tutorial_done = hud.is_tutorial_completed()
	if tutorial_done:
		threat_spawn_timer += delta
		if threat_spawn_timer >= _get_current_wave_interval():
			threat_spawn_timer = 0.0
			_spawn_wave()
			hud.update_wave(wave_count)
			AudioManager.play_sfx("wave_alert")
	else:
		threat_spawn_timer = 0.0

	minimap_update_timer += delta
	if minimap_update_timer >= 0.3:
		minimap_update_timer = 0.0
		_update_minimap()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
		else:
			touch_points.erase(event.index)
			touch_last_drag_time.erase(event.index)
		if touch_points.size() >= 2:
			_update_pinch_reference()
			is_dragging_camera = false
		else:
			_reset_pinch_state()
		return

	if event is InputEventScreenDrag:
		touch_points[event.index] = event.position
		var now := Time.get_ticks_msec() * 0.001
		touch_last_drag_time[event.index] = now
		if touch_points.size() >= 2:
			var pair_ids := _get_primary_touch_pair_ids()
			if pair_ids.size() < 2:
				return
			if not _is_active_pinch_pair(pair_ids, now):
				camera.position -= event.relative * camera.zoom.x
				_clamp_camera_to_world()
				return
			if not pinch_active or pinch_start_distance <= 0.0:
				_update_pinch_reference()
			var p0: Vector2 = touch_points[pair_ids[0]]
			var p1: Vector2 = touch_points[pair_ids[1]]
			var current_distance := maxf(p0.distance_to(p1), 1.0)
			if pinch_last_distance > 0.0:
				var zoom_factor := current_distance / pinch_last_distance
				_set_camera_zoom_scalar(camera.zoom.x * zoom_factor)
			pinch_last_distance = current_distance
			return
		elif touch_points.size() == 1:
			camera.position -= event.relative * camera.zoom.x
			_clamp_camera_to_world()
			return

	if event is InputEventMagnifyGesture:
		_set_camera_zoom_scalar(camera.zoom.x * maxf(event.factor, 0.01))
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if active_manual_building_key != "":
			_place_manual_defense_at_mouse()
			return
		_select_entity_at_mouse()

	# Drag to pan map
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			is_dragging_camera = event.pressed
			if event.pressed:
				drag_anchor_world = get_global_mouse_position()
		# Scroll to zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_camera_zoom_scalar(camera.zoom.x * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_camera_zoom_scalar(camera.zoom.x * 0.9)
	elif event is InputEventMouseMotion and is_dragging_camera:
		var current_world := get_global_mouse_position()
		camera.position += drag_anchor_world - current_world
		_clamp_camera_to_world()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if Input.is_key_pressed(KEY_SHIFT):
			_try_extinguish_fire_at_mouse()
		else:
			_try_ignite_tree_at_mouse()

	# Scroll to zoom
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			is_dragging_camera = false


func _set_camera_zoom_scalar(value: float) -> void:
	var clamped := clampf(value, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	camera.zoom = Vector2(clamped, clamped)
	_clamp_camera_to_world()


func _reset_pinch_state() -> void:
	pinch_active = false
	pinch_start_distance = 0.0
	pinch_last_distance = 0.0


func _update_pinch_reference() -> void:
	if touch_points.size() < 2:
		_reset_pinch_state()
		return
	var pair := _get_primary_touch_pair()
	if pair.size() < 2:
		_reset_pinch_state()
		return
	var p0: Vector2 = pair[0]
	var p1: Vector2 = pair[1]
	pinch_start_distance = maxf(p0.distance_to(p1), 1.0)
	pinch_start_zoom = camera.zoom.x
	pinch_last_distance = pinch_start_distance
	pinch_active = true


func _get_primary_touch_pair() -> Array:
	var ids: Array = touch_points.keys()
	ids.sort()
	if ids.size() < 2:
		return []
	return [touch_points[ids[0]], touch_points[ids[1]]]


func _get_primary_touch_pair_ids() -> Array:
	var ids: Array = touch_points.keys()
	ids.sort()
	if ids.size() < 2:
		return []
	return [ids[0], ids[1]]


func _is_active_pinch_pair(pair_ids: Array, now: float) -> bool:
	if pair_ids.size() < 2:
		return false
	var t0: float = float(touch_last_drag_time.get(pair_ids[0], -999.0))
	var t1: float = float(touch_last_drag_time.get(pair_ids[1], -999.0))
	return (now - t0) <= 0.16 and (now - t1) <= 0.16


func _select_entity_at_mouse() -> void:
	if _select_building_at_mouse():
		selected_villager = null
		_update_selected_villager_hud(true)
		return
	_select_villager_at_mouse()
	if is_instance_valid(selected_villager):
		selected_building_data = {}
		_update_selected_building_hud(true)


func _select_building_at_mouse() -> bool:
	if not bm:
		return false
	var mouse_world := get_global_mouse_position()
	var nearest: Dictionary = {}
	var best_dist := 24.0
	for bld in bm.get_buildings():
		if not (bld is Dictionary):
			continue
		var bd: Dictionary = bld as Dictionary
		if int(bd.get("hp", 0)) <= 0:
			continue
		var pos: Vector2 = bd.get("position", Vector2.ZERO)
		var d: float = pos.distance_to(mouse_world)
		if d <= best_dist:
			best_dist = d
			nearest = bd
	selected_building_data = nearest
	_update_selected_building_hud(true)
	return not nearest.is_empty()


func _select_villager_at_mouse() -> void:
	var mouse_world := get_global_mouse_position()
	var nearest: Node2D = null
	var best_dist := 22.0
	for v in villagers:
		if not is_instance_valid(v):
			continue
		var villager: Node2D = v
		var d: float = villager.global_position.distance_to(mouse_world)
		if d <= best_dist:
			best_dist = d
			nearest = villager
	selected_villager = nearest
	_update_selected_villager_hud(true)


func _update_selected_villager_hud(force_clear: bool = false) -> void:
	if not hud or not hud.has_method("set_selected_villager_info"):
		return
	if force_clear and not is_instance_valid(selected_villager):
		hud.call("set_selected_villager_info", {})
		return
	if not is_instance_valid(selected_villager):
		hud.call("set_selected_villager_info", {})
		return
	var v = selected_villager
	var role_key := int(v.get("role"))
	var level := 0
	if v.has_method("get_current_role_expertise_level"):
		level = int(v.call("get_current_role_expertise_level"))
	var gather_bonus := 0.0
	if v.has_method("get_current_role_gather_bonus_pct"):
		gather_bonus = float(v.call("get_current_role_gather_bonus_pct"))
	var hp_bonus := 0.0
	if v.has_method("get_current_role_hp_bonus_pct"):
		hp_bonus = float(v.call("get_current_role_hp_bonus_pct"))
	hud.call("set_selected_villager_info", {
		"role": role_key,
		"level": level,
		"gather_bonus_pct": gather_bonus,
		"hp_bonus_pct": hp_bonus,
		"hp": int(v.get("hp")),
		"max_hp": int(v.get("max_hp")),
	})


func _selected_building_valid() -> bool:
	if selected_building_data.is_empty():
		return false
	if int(selected_building_data.get("hp", 0)) <= 0:
		return false
	var spr: Sprite2D = selected_building_data.get("sprite")
	return spr and is_instance_valid(spr)


func _building_bonus_text(building_key: String) -> String:
	match building_key:
		"carpentry":
			return "Lumberjack gather speed+"
		"mining_house", "mine":
			return "Miner gather speed+"
		"army_base":
			return "Defender damage+"
		"training_grounds":
			return "Defender dmg+ and hp+"
		"forester_lodge":
			return "Replanting support"
		"armory":
			return "Unlocks sword upgrades"
		"watch_tower":
			return "Tower damage+ / cooldown-"
		"ballista_tower":
			return "Ballista damage+ / cooldown-"
		"trap":
			return "Trap damage+ / cooldown-"
		_:
			return "Building durability+"


func _update_selected_building_hud(force_clear: bool = false) -> void:
	if not hud or not hud.has_method("set_selected_building_info"):
		return
	if force_clear and not _selected_building_valid():
		hud.call("set_selected_building_info", {})
		return
	if not _selected_building_valid():
		selected_building_data = {}
		hud.call("set_selected_building_info", {})
		return
	var key := String(selected_building_data.get("key", ""))
	var level: int = bm.get_building_level(selected_building_data)
	var max_allowed: int = bm.get_building_max_level_allowed()
	var cost: Dictionary = bm.get_building_upgrade_cost(selected_building_data)
	var can_upgrade: bool = bm.can_upgrade_building(selected_building_data)
	var cost_text := "W:%d S:%d G:%d" % [int(cost.get("wood", 0)), int(cost.get("stone", 0)), int(cost.get("gold", 0))]
	if level >= max_allowed:
		cost_text = "CAP REACHED"
	hud.call("set_selected_building_info", {
		"name": String(GameConfig.BUILDINGS.get(key, {}).get("name", key.capitalize())),
		"level": level,
		"max_allowed": max_allowed,
		"hp": int(selected_building_data.get("hp", 0)),
		"max_hp": int(selected_building_data.get("max_hp", 0)),
		"bonus": _building_bonus_text(key),
		"can_upgrade": can_upgrade,
		"cost_text": cost_text,
	})


func _on_building_upgrade_requested() -> void:
	if not _selected_building_valid():
		return
	if not bm.try_upgrade_building(selected_building_data):
		return
	AudioManager.play_sfx("build")
	var sel_key := String(selected_building_data.get("key", ""))
	if sel_key == "barricade":
		_rebuild_barricade_cache()
	if sel_key == "training_grounds":
		_refresh_defender_scaling()
	if sel_key == "armory":
		_sync_armory_unlock_state()
	hud.update_resources()
	hud.update_building()
	_update_selected_building_hud(true)


# ── Campfire Light Flicker ────────────────────────────────────

func _flicker_campfire_light(_delta: float) -> void:
	if campfire_light:
		campfire_light.energy = randf_range(0.8, 1.2)


func _setup_day_night_overlay() -> void:
	day_night_layer = CanvasLayer.new()
	day_night_layer.layer = 1
	add_child(day_night_layer)

	day_night_overlay = ColorRect.new()
	day_night_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	day_night_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_night_overlay.color = Color(0.16, 0.20, 0.30, 0.0)
	day_night_layer.add_child(day_night_overlay)


func _update_day_night(delta: float) -> void:
	if not day_night_overlay:
		return
	day_night_time += delta
	var phase: float = fmod(day_night_time, DAY_NIGHT_CYCLE_SECONDS) / DAY_NIGHT_CYCLE_SECONDS
	# 0.0 = day, 0.5 = night, 1.0 = day
	var night_strength: float = sin(phase * PI)
	night_strength = night_strength * night_strength
	day_night_overlay.color = Color(0.14, 0.18, 0.28, 0.36 * night_strength)


func _get_current_wave_interval() -> float:
	var phase: float = fmod(day_night_time, DAY_NIGHT_CYCLE_SECONDS) / DAY_NIGHT_CYCLE_SECONDS
	var night_strength: float = sin(phase * PI)
	night_strength = night_strength * night_strength
	# Faster waves at night.
	return lerpf(GameConfig.THREAT_SPAWN_INTERVAL, GameConfig.THREAT_SPAWN_INTERVAL * 0.7, night_strength)


func _attach_shadow(target: Node2D, size: Vector2, offset: Vector2, alpha: float) -> void:
	if not target:
		return
	var shadow := ColorRect.new()
	shadow.color = Color(0.0, 0.0, 0.0, alpha)
	shadow.size = size
	shadow.position = Vector2(-size.x * 0.5 + offset.x, -size.y * 0.5 + offset.y)
	shadow.z_index = -1
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(shadow)


func _update_minimap() -> void:
	if not hud or not hud.has_method("update_minimap_entities"):
		return
	var threat_positions: Array = []
	for t in threat_container.get_children():
		if is_instance_valid(t):
			threat_positions.append(t.global_position)
	hud.update_minimap_entities(building_sprite.global_position, threat_positions)


func _on_call_to_arms_requested() -> void:
	hide_mode_active = not hide_mode_active
	for v in villagers:
		if not is_instance_valid(v):
			continue
		if int(v.get("role")) == GameConfig.Role.DEFENDER:
			if v.has_method("unhide_from_cabin"):
				v.call("unhide_from_cabin")
			continue
		if hide_mode_active:
			if v.has_method("hide_in_cabin"):
				v.call("hide_in_cabin")
		elif v.has_method("unhide_from_cabin"):
			v.call("unhide_from_cabin")
	if hud and hud.has_method("set_hide_mode"):
		hud.set_hide_mode(hide_mode_active)
	AudioManager.play_sfx("ui_click")


func _on_promote_requested(role: int) -> void:
	if role == GameConfig.Role.DEFENDER and bm and bm.get_stage() < GameConfig.BuildingStage.WOODEN_CABIN:
		return
	var assigned := TaskManager.assign_idle_to_role(role, 1)
	if assigned <= 0:
		var source_role := -1
		if role == GameConfig.Role.BUILDER:
			source_role = GameConfig.Role.SCHOLAR
		elif role == GameConfig.Role.SCHOLAR:
			source_role = GameConfig.Role.BUILDER
		if source_role >= 0:
			for v in villagers:
				if not is_instance_valid(v):
					continue
				if v.role == source_role and v.has_method("set_role"):
					v.set_role(role)
					break
	hud.update_tasks()


func _on_emergency_repair_requested() -> void:
	var repair_cost := {"wood": 0, "stone": 8, "gold": 4}
	if not ResourceManager.can_afford(repair_cost):
		return
	ResourceManager.spend(repair_cost)
	builder_repair_boost_timer = 16.0


func _try_ignite_tree_at_mouse() -> void:
	if map_state.is_empty():
		return
	var mouse: Vector2 = get_global_mouse_position()
	var tx: int = int(mouse.x / GameConfig.TILE_SIZE)
	var ty: int = int(mouse.y / GameConfig.TILE_SIZE)
	if tx < 0 or ty < 0 or tx >= GameConfig.MAP_WIDTH or ty >= GameConfig.MAP_HEIGHT:
		return
	var tile: int = int(map_state["resource_data"][ty][tx])
	if tile != GameConfig.TileType.TREE_PINE and tile != GameConfig.TileType.TREE_OAK and tile != GameConfig.TileType.LOG_PILE:
		return
	_ignite_tile(Vector2i(tx, ty))


func _try_extinguish_fire_at_mouse() -> void:
	if map_state.is_empty():
		return
	var mouse: Vector2 = get_global_mouse_position()
	var tx: int = int(mouse.x / GameConfig.TILE_SIZE)
	var ty: int = int(mouse.y / GameConfig.TILE_SIZE)
	var tile := Vector2i(tx, ty)
	if burning_tiles.has(tile):
		burning_tiles.erase(tile)
		_remove_burning_visual(tile)
		_spawn_extinguish_particles(_tile_center_world(tile))


func _ignite_tile(tile: Vector2i) -> void:
	if burning_tiles.has(tile):
		return
	burning_tiles[tile] = FIRE_BURN_DURATION
	_add_burning_visual(tile)
	_spawn_burn_particles(_tile_center_world(tile))


func _update_burning(delta: float) -> void:
	if burning_tiles.is_empty():
		return
	var to_finish: Array = []
	var to_spread: Array = []
	for tile in burning_tiles.keys():
		var rem: float = float(burning_tiles[tile]) - delta
		burning_tiles[tile] = rem
		if burning_visuals.has(tile):
			var spr: Sprite2D = burning_visuals[tile]
			if is_instance_valid(spr):
				spr.scale = Vector2(1.0 + randf_range(-0.08, 0.1), 1.0 + randf_range(-0.05, 0.12))
				spr.modulate.a = randf_range(0.78, 1.0)
		if rem <= 0.0:
			to_finish.append(tile)
			continue
		if randf() < delta * 2.4:
			_spawn_burn_particles(_tile_center_world(tile), 2)
		var spread_rate: float = 0.9
		if ResourceManager.has_technology("firebreaks"):
			spread_rate = 0.45
		if randf() < delta * spread_rate:
			to_spread.append(tile)

	for tile in to_finish:
		_finish_burning_tile(tile)

	for src in to_spread:
		_try_spread_fire(src)


func _try_spread_fire(src_tile: Vector2i) -> void:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var dir: Vector2i = dirs[randi() % dirs.size()]
	var t := src_tile + dir
	if t.x < 0 or t.y < 0 or t.x >= GameConfig.MAP_WIDTH or t.y >= GameConfig.MAP_HEIGHT:
		return
	if burning_tiles.has(t):
		return
	var tile_type: int = int(map_state["resource_data"][t.y][t.x])
	if tile_type == GameConfig.TileType.TREE_PINE or tile_type == GameConfig.TileType.TREE_OAK or tile_type == GameConfig.TileType.LOG_PILE:
		_ignite_tile(t)


func _finish_burning_tile(tile: Vector2i) -> void:
	burning_tiles.erase(tile)
	_remove_burning_visual(tile)
	if tile.x < 0 or tile.y < 0 or tile.x >= GameConfig.MAP_WIDTH or tile.y >= GameConfig.MAP_HEIGHT:
		return
	map_state["resource_data"][tile.y][tile.x] = -1
	map_state["ground_data"][tile.y][tile.x] = GameConfig.TileType.DIRT
	tilemap.erase_cell(1, tile)
	tilemap.set_cell(0, tile, 0, Vector2i(GameConfig.TileType.DIRT, 0))
	if tree_nodes.has(tile):
		var tree_node = tree_nodes[tile]
		if is_instance_valid(tree_node):
			tree_node.queue_free()
		tree_nodes.erase(tile)
	_spawn_burn_particles(_tile_center_world(tile), 5)


func _tile_center_world(tile: Vector2i) -> Vector2:
	return Vector2(float(tile.x * GameConfig.TILE_SIZE + 16), float(tile.y * GameConfig.TILE_SIZE + 16))


func _add_burning_visual(tile: Vector2i) -> void:
	if burning_visuals.has(tile):
		return
	var flame_tex: Texture2D = textures.get("flame")
	if flame_tex == null:
		return
	var spr := Sprite2D.new()
	spr.texture = flame_tex
	spr.position = _tile_center_world(tile) + Vector2(0, -8)
	spr.z_index = 14
	spr.modulate = Color(1, 1, 1, 0.92)
	add_child(spr)
	burning_visuals[tile] = spr


func _remove_burning_visual(tile: Vector2i) -> void:
	if not burning_visuals.has(tile):
		return
	var spr: Sprite2D = burning_visuals[tile]
	if is_instance_valid(spr):
		spr.queue_free()
	burning_visuals.erase(tile)


func _spawn_burn_particles(pos: Vector2, count: int = 8) -> void:
	for i in range(count):
		var p := ColorRect.new()
		p.size = Vector2(3, 3)
		p.position = pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		p.color = Color(0.95, 0.45, 0.15, 0.85)
		p.z_index = 16
		add_child(p)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", p.position + Vector2(randf_range(-8, 8), -20), 0.45)
		tw.tween_property(p, "modulate:a", 0.0, 0.45)
		tw.chain().tween_callback(p.queue_free)


func _spawn_extinguish_particles(pos: Vector2) -> void:
	for i in range(6):
		var p := ColorRect.new()
		p.size = Vector2(3, 3)
		p.position = pos + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		p.color = Color(0.4, 0.72, 0.95, 0.8)
		p.z_index = 16
		add_child(p)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", p.position + Vector2(randf_range(-10, 10), -10), 0.35)
		tw.tween_property(p, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(p.queue_free)


func builder_repair_tick(builder_home: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	if builder_repair_boost_timer > 0.0:
		amount = int(round(float(amount) * 1.8))
	if ResourceManager.has_technology("architecture"):
		amount = int(round(float(amount) * 1.2))
	var best_bld: Dictionary = {}
	var best_dist := 999999.0
	for bld: Dictionary in bm.get_buildings():
		var hp: int = int(bld.get("hp", 0))
		var max_hp: int = int(bld.get("max_hp", 0))
		if hp >= max_hp:
			continue
		var d := builder_home.distance_to(Vector2(bld["position"]))
		if d < best_dist:
			best_dist = d
			best_bld = bld

	if not best_bld.is_empty():
		best_bld["hp"] = mini(int(best_bld["hp"]) + amount, int(best_bld["max_hp"]))
		if bm.has_method("_update_bld_hp_bar"):
			bm._update_bld_hp_bar(best_bld)
		return

	if cabin_hp < cabin_max_hp:
		cabin_hp = mini(cabin_hp + amount, cabin_max_hp)
		_update_cabin_hp_bar()
		hud.update_cabin_hp(cabin_hp, cabin_max_hp)


func _clamp_camera_to_world() -> void:
	if world_rect.size == Vector2.ZERO:
		return
	var margin_px: float = CAMERA_MARGIN_TILES * GameConfig.TILE_SIZE
	var min_x: float = world_rect.position.x + margin_px
	var min_y: float = world_rect.position.y + margin_px
	var max_x: float = world_rect.end.x - margin_px
	var max_y: float = world_rect.end.y - margin_px
	camera.position.x = clampf(camera.position.x, min_x, max_x)
	camera.position.y = clampf(camera.position.y, min_y, max_y)


func _setup_distance_fog(cx: float, cy: float) -> void:
	fog_sprite = Sprite2D.new()
	fog_sprite.texture = _make_distance_fog_texture(FOG_TEXTURE_SIZE)
	fog_sprite.position = Vector2(cx, cy)
	fog_sprite.centered = true
	fog_sprite.z_index = 50
	var world_span: float = maxf(world_rect.size.x, world_rect.size.y)
	var tex_size: float = float(FOG_TEXTURE_SIZE)
	var fog_scale := world_span / tex_size
	fog_sprite.scale = Vector2(fog_scale, fog_scale)
	add_child(fog_sprite)
	_update_distance_fog_by_stage(bm.get_stage() if bm else 0)


func _update_distance_fog_by_stage(stage: int) -> void:
	if not fog_sprite:
		return
	var alpha_mult := 1.0
	match stage:
		GameConfig.BuildingStage.WOODEN_CABIN:
			alpha_mult = 0.9
		GameConfig.BuildingStage.STONE_HALL:
			alpha_mult = 0.78
	fog_sprite.modulate = Color(1, 1, 1, alpha_mult)


func _make_distance_fog_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(size) * 0.5, float(size) * 0.5)
	var radius := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x), float(y)).distance_to(center) / radius
			d = clampf(d, 0.0, 1.0)
			var alpha := 0.0
			if d > 0.32:
				var t := (d - 0.32) / 0.68
				alpha = t * t * GameConfig.FOG_DARKNESS
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))
	return ImageTexture.create_from_image(img)


func _setup_campfire_sprite() -> void:
	campfire_anim_enabled = false
	campfire_anim_timer = 0.0
	campfire_sprite.scale = Vector2.ONE
	campfire_sprite.hframes = 1
	campfire_sprite.vframes = 1
	campfire_sprite.frame = 0
	campfire_sprite.texture = textures["campfire"]
	_apply_campfire_scale(campfire_sprite.texture)

	if not ResourceLoader.exists(CAMPFIRE_SHEET_PATH):
		var direct_sheet := _load_texture_direct(CAMPFIRE_SHEET_PATH)
		if direct_sheet == null:
			print("Campfire sheet not found, using generated campfire: ", CAMPFIRE_SHEET_PATH)
			return
		if direct_sheet.get_width() < CAMPFIRE_FRAMES:
			print("Campfire sheet width invalid for 6 frames, using generated campfire: ", direct_sheet.get_width())
			return
		campfire_sprite.texture = direct_sheet
		campfire_sprite.hframes = CAMPFIRE_FRAMES
		campfire_sprite.vframes = 1
		campfire_sprite.frame = 0
		_apply_campfire_scale(campfire_sprite.texture)
		campfire_anim_enabled = true
		print("Campfire sheet loaded (direct): ", CAMPFIRE_SHEET_PATH)
		return

	var sheet_tex = load(CAMPFIRE_SHEET_PATH) as Texture2D
	if sheet_tex == null:
		sheet_tex = _load_texture_direct(CAMPFIRE_SHEET_PATH)
		if sheet_tex == null:
			print("Campfire sheet load failed, using generated campfire: ", CAMPFIRE_SHEET_PATH)
			return
	if sheet_tex.get_width() < CAMPFIRE_FRAMES:
		print("Campfire sheet width invalid for 6 frames, using generated campfire: ", sheet_tex.get_width())
		return

	campfire_sprite.texture = sheet_tex
	campfire_sprite.hframes = CAMPFIRE_FRAMES
	campfire_sprite.vframes = 1
	campfire_sprite.frame = 0
	_apply_campfire_scale(campfire_sprite.texture)
	campfire_anim_enabled = true
	print("Campfire sheet loaded: ", CAMPFIRE_SHEET_PATH)


func _update_campfire_animation(delta: float) -> void:
	if not campfire_anim_enabled:
		return
	if campfire_sprite.hframes != CAMPFIRE_FRAMES:
		return

	campfire_anim_timer += delta
	var frame_time := 1.0 / CAMPFIRE_FPS
	while campfire_anim_timer >= frame_time:
		campfire_anim_timer -= frame_time
		campfire_sprite.frame = (campfire_sprite.frame + 1) % CAMPFIRE_FRAMES


func _load_texture_direct(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _apply_campfire_scale(tex: Texture2D) -> void:
	if tex == null:
		return
	var h := float(tex.get_height())
	if h <= 0.0:
		return
	var s := CAMPFIRE_TARGET_HEIGHT / h
	campfire_sprite.scale = Vector2(s, s)


# ── Camera Shake (callable from villagers) ────────────────────

func apply_shake(intensity: float) -> void:
	if camera and camera.has_method("apply_shake"):
		camera.apply_shake(intensity)


# ── Light Texture Generator ──────────────────────────────────

func _make_light_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var radius := size / 2.0
	for y in range(size):
		for x in range(size):
			var dist := Vector2(x, y).distance_to(center)
			var alpha := clampf(1.0 - dist / radius, 0.0, 1.0)
			alpha = alpha * alpha  # quadratic falloff
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


func _on_building_evolved(_stage: int) -> void:
	AudioManager.play_sfx("evolve")
	_update_distance_fog_by_stage(_stage)
	cabin_max_hp = _get_cabin_max_hp_for_stage(_stage)
	cabin_hp = cabin_max_hp
	_update_cabin_hp_bar()
	hud.update_cabin_hp(cabin_hp, cabin_max_hp)
	# Update safe zone radius for defender patrol
	var new_radius := GameConfig.CLEAR_RADIUS
	match _stage:
		GameConfig.BuildingStage.WOODEN_CABIN:
			new_radius = GameConfig.EVOLUTION["wooden_cabin"]["clear_radius"]
		GameConfig.BuildingStage.STONE_HALL:
			new_radius = GameConfig.EVOLUTION["stone_hall"]["clear_radius"]
	for v in villagers:
		if is_instance_valid(v):
			v.safe_zone_radius = new_radius

	# Camera flash effect
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 0.8, 0.6)
	flash.size = get_viewport_rect().size
	flash.z_index = 100
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.5)
	tween.tween_callback(flash.queue_free)


# ── Building Placed — spawn role villagers + visual sprite ────

func _on_building_placed(building_key: String) -> void:
	AudioManager.play_sfx("build")
	if building_key == "trap" or building_key == "barricade":
		pending_manual_builds[building_key] = int(pending_manual_builds.get(building_key, 0)) + 1
		if active_manual_building_key == "":
			active_manual_building_key = building_key
		_show_manual_place_prompt(active_manual_building_key)
		return
	var bpos := _compute_building_position(building_key)
	_start_construction(building_key, bpos)

	hud.update_population(villagers.size())
	# Flash green to confirm
	var flash := ColorRect.new()
	flash.color = Color(0.2, 1.0, 0.4, 0.4)
	flash.size = get_viewport_rect().size
	flash.z_index = 100
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.4)
	tween.tween_callback(flash.queue_free)


func _place_manual_defense_at_mouse() -> void:
	if active_manual_building_key == "":
		return
	if int(pending_manual_builds.get(active_manual_building_key, 0)) <= 0:
		_select_next_pending_manual_build()
		if active_manual_building_key != "":
			_show_manual_place_prompt(active_manual_building_key)
		return

	var tile := _mouse_world_to_tile()
	if tile.x < 0 or tile.y < 0 or tile.x >= GameConfig.MAP_WIDTH or tile.y >= GameConfig.MAP_HEIGHT:
		return

	# Only allow defense placement on solid ground.
	var ground := int(map_state["ground_data"][tile.y][tile.x])
	if ground == GameConfig.TileType.WATER:
		return

	var base_pos := Vector2(
		float(tile.x * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2),
		float(tile.y * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2)
	)
	var placement := _resolve_manual_defense_position(active_manual_building_key, base_pos)
	var final_pos: Vector2 = placement.get("pos", base_pos)

	if _is_build_position_occupied(final_pos, 18.0):
		return

	_start_construction(active_manual_building_key, final_pos)
	pending_manual_builds[active_manual_building_key] = int(pending_manual_builds.get(active_manual_building_key, 0)) - 1
	if int(pending_manual_builds.get(active_manual_building_key, 0)) <= 0:
		_select_next_pending_manual_build()


func _select_next_pending_manual_build() -> void:
	if int(pending_manual_builds.get("barricade", 0)) > 0:
		active_manual_building_key = "barricade"
		return
	if int(pending_manual_builds.get("trap", 0)) > 0:
		active_manual_building_key = "trap"
		return
	active_manual_building_key = ""


func _setup_manual_placement_preview() -> void:
	placement_preview = Sprite2D.new()
	placement_preview.visible = false
	placement_preview.modulate = Color(0.70, 0.70, 0.70, 0.58)
	placement_preview.z_index = 40
	add_child(placement_preview)

	placement_anchor_line = Line2D.new()
	placement_anchor_line.visible = false
	placement_anchor_line.default_color = Color(0.82, 0.82, 0.82, 0.7)
	placement_anchor_line.width = 2.0
	placement_anchor_line.z_index = 39
	add_child(placement_anchor_line)


func _update_manual_placement_preview() -> void:
	if not placement_preview or not placement_anchor_line:
		return
	if active_manual_building_key == "":
		placement_preview.visible = false
		placement_anchor_line.visible = false
		return

	var tile := _mouse_world_to_tile()
	if tile.x < 0 or tile.y < 0 or tile.x >= GameConfig.MAP_WIDTH or tile.y >= GameConfig.MAP_HEIGHT:
		placement_preview.visible = false
		placement_anchor_line.visible = false
		return

	var base_pos := Vector2(
		float(tile.x * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2),
		float(tile.y * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2)
	)
	var ground := int(map_state["ground_data"][tile.y][tile.x])
	var placement := _resolve_manual_defense_position(active_manual_building_key, base_pos)
	var final_pos: Vector2 = placement.get("pos", base_pos)
	var anchor_used: bool = bool(placement.get("anchor_used", false))
	var anchor_pos: Vector2 = placement.get("anchor_pos", Vector2.ZERO)
	var is_valid := ground != GameConfig.TileType.WATER and not _is_build_position_occupied(final_pos, 18.0)

	var tex_key := "bld_" + active_manual_building_key
	if textures.has(tex_key):
		placement_preview.texture = textures[tex_key]
	placement_preview.position = final_pos
	if is_valid:
		placement_preview.modulate = Color(0.70, 0.70, 0.70, 0.58)
	else:
		placement_preview.modulate = Color(0.95, 0.35, 0.35, 0.72)
	placement_preview.visible = true

	if anchor_used and is_valid:
		placement_anchor_line.clear_points()
		placement_anchor_line.add_point(anchor_pos)
		placement_anchor_line.add_point(final_pos)
		placement_anchor_line.default_color = Color(0.82, 0.82, 0.82, 0.7)
		placement_anchor_line.visible = true
	elif anchor_used:
		placement_anchor_line.clear_points()
		placement_anchor_line.add_point(anchor_pos)
		placement_anchor_line.add_point(final_pos)
		placement_anchor_line.default_color = Color(0.95, 0.35, 0.35, 0.75)
		placement_anchor_line.visible = true
	else:
		placement_anchor_line.visible = false


func _resolve_manual_defense_position(building_key: String, base_pos: Vector2) -> Dictionary:
	if building_key != "barricade":
		return {"pos": base_pos, "anchor_used": false, "anchor_pos": Vector2.ZERO}
	return _snap_barricade_with_info(base_pos)


func _show_manual_place_prompt(building_key: String) -> void:
	if not hud:
		return
	var name := "Barricade"
	if building_key == "trap":
		name = "Spike Trap"
	var lbl := Label.new()
	lbl.text = "PLACE MODE: Click map to place " + name
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.65))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl.offset_top = 92
	hud.add_child(lbl)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)


func _mouse_world_to_tile() -> Vector2i:
	var mw := get_global_mouse_position()
	return Vector2i(
		int(floor(mw.x / GameConfig.TILE_SIZE)),
		int(floor(mw.y / GameConfig.TILE_SIZE))
	)


func _snap_barricade_with_info(base_pos: Vector2) -> Dictionary:
	var nearest := Vector2.ZERO
	var nearest_dist := INF

	for bp: Vector2 in barricade_points:
		var d := bp.distance_to(base_pos)
		if d < nearest_dist:
			nearest_dist = d
			nearest = bp

	for site_data in construction_sites:
		if not (site_data is Dictionary):
			continue
		var sd: Dictionary = site_data as Dictionary
		if String(sd.get("key", "")) != "barricade":
			continue
		var sp: Vector2 = sd.get("pos", Vector2.ZERO)
		var ds := sp.distance_to(base_pos)
		if ds < nearest_dist:
			nearest_dist = ds
			nearest = sp

	if nearest_dist > GameConfig.BARRICADE_LINK_DISTANCE:
		return {"pos": base_pos, "anchor_used": false, "anchor_pos": Vector2.ZERO}

	var dir := (base_pos - nearest).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	if absf(dir.x) >= absf(dir.y):
		dir = Vector2(signf(dir.x), 0.0)
	else:
		dir = Vector2(0.0, signf(dir.y))

	var candidate := nearest + dir * GameConfig.BARRICADE_SNAP_STEP
	for i in range(6):
		if not _is_build_position_occupied(candidate, 18.0):
			return {"pos": candidate, "anchor_used": true, "anchor_pos": nearest}
		candidate += dir * GameConfig.BARRICADE_SNAP_STEP
	return {"pos": base_pos, "anchor_used": false, "anchor_pos": Vector2.ZERO}


func _compute_building_position(building_key: String) -> Vector2:
	var cx: float = map_state["center_x"] * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0
	var cy: float = map_state["center_y"] * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0
	var bld_count: int = bm.get_placed_count(building_key)
	var angle: float = float(bld_count) * 1.8 + float(building_key.hash() % 6)
	var dist: float = 55.0 + float(bld_count) * 18.0
	var base_pos := Vector2(cx + cos(angle) * dist, cy + sin(angle) * dist)

	if building_key != "barricade":
		return base_pos
	return _snap_barricade_with_info(base_pos).get("pos", base_pos)


func _is_build_position_occupied(pos: Vector2, min_dist: float = 18.0) -> bool:
	for bld in bm.get_buildings():
		if not (bld is Dictionary):
			continue
		var bd: Dictionary = bld as Dictionary
		if int(bd.get("hp", 0)) <= 0:
			continue
		var bp: Vector2 = bd.get("position", Vector2.ZERO)
		if bp.distance_to(pos) < min_dist:
			return true
	for site_data in construction_sites:
		if not (site_data is Dictionary):
			continue
		var sd: Dictionary = site_data as Dictionary
		var sp: Vector2 = sd.get("pos", Vector2.ZERO)
		if sp.distance_to(pos) < min_dist:
			return true
	return false


func _start_construction(building_key: String, bpos: Vector2) -> void:
	var site := Node2D.new()
	site.position = bpos
	construction_container.add_child(site)

	var placeholder := Sprite2D.new()
	var tex_key := "bld_" + building_key
	placeholder.texture = textures.get(tex_key)
	placeholder.modulate = Color(1, 1, 1, 0.45)
	placeholder.z_index = 4
	site.add_child(placeholder)

	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(32, 5)
	bar_bg.color = Color(0.10, 0.10, 0.10, 0.75)
	bar_bg.position = Vector2(-16, -26)
	bar_bg.z_index = 6
	site.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.size = Vector2(0, 3)
	bar_fill.color = Color(0.90, 0.72, 0.22)
	bar_fill.position = Vector2(-15, -25)
	bar_fill.z_index = 7
	site.add_child(bar_fill)

	var build_time: float = float(GameConfig.BUILD_TIME.get(building_key, 10.0))
	construction_sites.append({
		"key": building_key,
		"site": site,
		"bar_fill": bar_fill,
		"pos": bpos,
		"progress": 0.0,
		"required": build_time,
	})


func _update_construction(delta: float) -> void:
	if construction_sites.is_empty():
		return
	var counts: Dictionary = TaskManager.get_role_counts()
	var builders: int = int(counts.get(GameConfig.Role.BUILDER, 0))
	var scholars: int = int(counts.get(GameConfig.Role.SCHOLAR, 0))
	var work_rate: float = float(builders) * BUILDER_CONSTRUCT_RATE
	if work_rate <= 0.0:
		work_rate = float(scholars) * NON_BUILDER_CONSTRUCT_RATE
	if builder_repair_boost_timer > 0.0:
		work_rate *= 1.35
	if ResourceManager.has_technology("architecture"):
		work_rate *= 1.25
	if work_rate <= 0.0:
		return

	var work: float = work_rate * delta
	var completed: Array = []
	for site_data: Dictionary in construction_sites:
		site_data["progress"] = float(site_data["progress"]) + work
		var ratio: float = clampf(float(site_data["progress"]) / float(site_data["required"]), 0.0, 1.0)
		var bar_fill: ColorRect = site_data["bar_fill"]
		if bar_fill and is_instance_valid(bar_fill):
			bar_fill.size.x = 30.0 * ratio
		if ratio >= 1.0:
			completed.append(site_data)

	for site_data in completed:
		_finish_construction(site_data)
		construction_sites.erase(site_data)


func _finish_construction(site_data: Dictionary) -> void:
	var building_key: String = site_data["key"]
	var bpos: Vector2 = site_data["pos"]
	var site: Node2D = site_data["site"]
	if site and is_instance_valid(site):
		site.queue_free()

	var info: Dictionary = GameConfig.BUILDINGS.get(building_key, {})
	var spawn_count: int = int(info.get("villagers", 0))
	var target_role: int = GameConfig.building_role(building_key)

	var bld_sprite := Sprite2D.new()
	var tex_key := "bld_" + building_key
	bld_sprite.texture = textures.get(tex_key)
	bld_sprite.position = bpos
	bld_sprite.z_index = 4
	_attach_shadow(bld_sprite, Vector2(36, 12), Vector2(0, 14), 0.28)
	add_child(bld_sprite)

	var hp_max: int = GameConfig.BUILDING_HP.get(building_key, 50)
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0.2, 0.2, 0.2, 0.7)
	hp_bg.size = Vector2(30, 4)
	hp_bg.position = Vector2(bpos.x - 15, bpos.y - 22)
	hp_bg.z_index = 6
	add_child(hp_bg)

	var hp_fill := ColorRect.new()
	hp_fill.color = Color(0.35, 0.75, 0.30)
	hp_fill.size = Vector2(28, 2)
	hp_fill.position = Vector2(bpos.x - 14, bpos.y - 21)
	hp_fill.z_index = 7
	add_child(hp_fill)

	var bld_data := {
		"key": building_key,
		"level": 1,
		"hp": hp_max,
		"max_hp": hp_max,
		"base_max_hp": hp_max,
		"base_scale": bld_sprite.scale,
		"sprite": bld_sprite,
		"position": bpos,
		"hp_bar_bg": hp_bg,
		"hp_bar_fill": hp_fill,
	}
	bm.register_building(bld_data)
	if building_key == "barricade":
		_rebuild_barricade_cache()
	if building_key == "training_grounds":
		_refresh_defender_scaling()
	if building_key == "armory":
		_sync_armory_unlock_state()

	if spawn_count > 0 and target_role != GameConfig.Role.IDLE:
		var converted := TaskManager.assign_idle_to_role(target_role, spawn_count)
		var to_spawn := spawn_count - converted
		var cx: float = map_state["center_x"] * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0
		var cy: float = map_state["center_y"] * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0
		for i in range(to_spawn):
			var a := randf() * TAU
			var r := 30.0 + randf() * 20.0
			_spawn_villager(cx + cos(a) * r, cy + sin(a) * r, cx, cy)
			var v = villagers[villagers.size() - 1]
			if v and is_instance_valid(v) and v.has_method("set_role"):
				v.set_role(target_role)


# ── Watch Tower Arrow Attacks (Stone Hall / evo 3) ───────────

func _update_tower_attacks(delta: float) -> void:
	for bld: Dictionary in bm.get_buildings():
		var bkey := String(bld.get("key", ""))
		if bkey != "watch_tower" and bkey != "ballista_tower":
			continue
		if int(bld["hp"]) <= 0:
			continue
		var timer: float = float(bld.get("attack_timer", 0.0))
		timer -= delta
		if timer > 0.0:
			bld["attack_timer"] = timer
			continue
		# Find nearest threat in range
		var tower_pos: Vector2 = bld["position"]
		var best_threat: Node2D = null
		var best_dist := (GameConfig.BALLISTA_ATTACK_RANGE if bkey == "ballista_tower" else GameConfig.TOWER_ATTACK_RANGE) + 1.0
		var prefer_bear := bkey == "ballista_tower"
		var found_bear := false
		for threat in threat_container.get_children():
			if not is_instance_valid(threat):
				continue
			var d := tower_pos.distance_to(threat.global_position)
			var is_bear := int(threat.get("enemy_type")) == GameConfig.EnemyType.BEAR
			if prefer_bear:
				if is_bear and (not found_bear or d < best_dist):
					found_bear = true
					best_dist = d
					best_threat = threat
				elif not found_bear and d < best_dist:
					best_dist = d
					best_threat = threat
			elif d < best_dist:
				best_dist = d
				best_threat = threat
		if best_threat:
			var cd_mult: float = bm.get_tower_cooldown_mult()
			var damage := int(round(float(GameConfig.TOWER_ATTACK_DAMAGE) * bm.get_tower_damage_mult()))
			if bkey == "ballista_tower":
				cd_mult = bm.get_ballista_cooldown_mult()
				damage = int(round(float(GameConfig.BALLISTA_ATTACK_DAMAGE) * bm.get_ballista_damage_mult()))
				if int(best_threat.get("enemy_type")) == GameConfig.EnemyType.BEAR:
					damage = int(round(float(damage) * GameConfig.BALLISTA_BEAR_BONUS_MULT))
			bld["attack_timer"] = (GameConfig.BALLISTA_ATTACK_COOLDOWN if bkey == "ballista_tower" else GameConfig.TOWER_ATTACK_COOLDOWN) * cd_mult
			AudioManager.play_sfx("tower_arrow")
			_spawn_arrow(tower_pos, best_threat, damage)
		else:
			bld["attack_timer"] = 0.0


func _update_traps(delta: float) -> void:
	if not bm:
		return
	for bld in bm.get_buildings():
		if not (bld is Dictionary):
			continue
		var bd: Dictionary = bld as Dictionary
		if String(bd.get("key", "")) != "trap":
			continue
		if int(bd.get("hp", 0)) <= 0:
			continue
		var timer: float = float(bd.get("trap_timer", 0.0)) - delta
		if timer > 0.0:
			bd["trap_timer"] = timer
			continue
		var trap_pos: Vector2 = bd.get("position", Vector2.ZERO)
		var hit := false
		for threat in threat_container.get_children():
			if not is_instance_valid(threat):
				continue
			if trap_pos.distance_to(threat.global_position) <= GameConfig.TRAP_ATTACK_RANGE:
				if threat.has_method("take_damage"):
					var trap_dmg := int(round(float(GameConfig.TRAP_DAMAGE) * bm.get_trap_damage_mult()))
					threat.take_damage(trap_dmg, trap_pos)
				hit = true
				break
		if hit:
			bd["trap_timer"] = GameConfig.TRAP_COOLDOWN * bm.get_trap_cooldown_mult()


func _spawn_arrow(from: Vector2, target: Node2D, damage: int) -> void:
	var arrow := ColorRect.new()
	arrow.size = Vector2(6, 2)
	arrow.color = Color(0.55, 0.40, 0.15)
	arrow.position = from
	arrow.z_index = 10
	add_child(arrow)

	# Point arrow toward target
	var dir := (target.global_position - from).normalized()
	arrow.rotation = dir.angle()

	var target_ref: Variant = weakref(target)
	var tw := create_tween()
	tw.tween_property(arrow, "position", target.global_position, 0.25)
	tw.tween_callback(func():
		var t: Variant = target_ref.get_ref()
		if t and is_instance_valid(t) and t.has_method("take_damage"):
			t.take_damage(damage, from)
		arrow.queue_free()
	)


# ── Floating Resource Popup ──────────────────────────────────

func _on_resource_added(type: String, amount: int) -> void:
	if amount <= 0:
		return
	AudioManager.play_gather(type)
	var color: Color
	var icon_char: String
	match type:
		"wood":
			color = Color(0.55, 0.40, 0.15)
			icon_char = "W"
		"stone":
			color = Color(0.60, 0.60, 0.60)
			icon_char = "S"
		"gold":
			color = Color(0.85, 0.65, 0.10)
			icon_char = "G"
		_:
			return

	# Spawn near chest with slight random offset
	var base_pos := chest_sprite.position + Vector2(randf_range(-12, 12), randf_range(-16, -4))

	var lbl := Label.new()
	lbl.text = "+%d %s" % [amount, icon_char]
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.position = base_pos
	lbl.z_index = 20
	add_child(lbl)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", base_pos.y - 24, 0.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(lbl.queue_free)


# ── Building Destroyed — fire workers ────────────────────────

func _on_building_destroyed(building_key: String, _bld_data: Dictionary) -> void:
	AudioManager.play_sfx("death")
	if not selected_building_data.is_empty() and selected_building_data == _bld_data:
		selected_building_data = {}
		_update_selected_building_hud(true)
	if building_key == "barricade":
		_rebuild_barricade_cache()
	if building_key == "training_grounds":
		_refresh_defender_scaling()
	if building_key == "armory":
		_sync_armory_unlock_state()
	hud.update_building()
	var target_role: int = GameConfig.building_role(building_key)
	if target_role == GameConfig.Role.IDLE:
		return
	# Count how many workers should be fired (building's villager count)
	var info: Dictionary = GameConfig.BUILDINGS.get(building_key, {})
	var fire_count: int = int(info.get("villagers", 0))
	var fired := 0
	for v in villagers:
		if fired >= fire_count:
			break
		if is_instance_valid(v) and v.role == target_role:
			v.set_role(GameConfig.Role.IDLE)
			fired += 1
	hud.update_tasks()
	# Red flash for destruction
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.2, 0.1, 0.35)
	flash.size = get_viewport_rect().size
	flash.z_index = 100
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.5)
	tween.tween_callback(flash.queue_free)
	apply_shake(4.0)


# ── Cabin Damage / HP ────────────────────────────────────────

func _on_threat_reached_cabin(_threat: Node2D, dmg: int) -> void:
	if game_over:
		return

	# Also damage nearby buildings
	_damage_nearby_buildings(_threat, dmg)

	cabin_hp = maxi(cabin_hp - dmg, 0)
	_update_cabin_hp_bar()
	hud.update_cabin_hp(cabin_hp, cabin_max_hp)
	apply_shake(2.0)

	# Flash building red briefly
	building_sprite.modulate = Color(1.0, 0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(building_sprite, "modulate", Color.WHITE, 0.2)

	if cabin_hp <= 0:
		_trigger_game_over()


func _on_threat_died(_threat: Node2D) -> void:
	pass  # Could track kill count here


# ── Building Damage from Threats ─────────────────────────────

func _damage_nearby_buildings(threat: Node2D, dmg: int) -> void:
	if not bm:
		return
	var tpos := threat.global_position
	for bld: Dictionary in bm.get_buildings():
		var bpos: Vector2 = bld["position"]
		if tpos.distance_to(bpos) < 50.0:
			bm.damage_building(bld, dmg)
			break  # only damage one building per hit


# ── Villager Death ───────────────────────────────────────────

func _on_villager_died(v: Node2D) -> void:
	villagers.erase(v)
	if selected_villager == v:
		selected_villager = null
		_update_selected_villager_hud(true)
	TaskManager.remove_villager(v)
	hud.update_population(villagers.size())


# ── Game Over ────────────────────────────────────────────────

func _trigger_game_over() -> void:
	game_over = true
	# Freeze all villagers
	for v in villagers:
		if is_instance_valid(v):
			v.set_process(false)
	# Freeze all threats
	for t in threat_container.get_children():
		if is_instance_valid(t):
			t.set_process(false)
	hud.show_game_over()
	apply_shake(8.0)


func _restart_game() -> void:
	# Delete save on explicit restart
	if FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	if TaskManager.has_method("reset_state"):
		TaskManager.reset_state()
	if ResourceManager.has_method("reset_state"):
		ResourceManager.reset_state()
	get_tree().reload_current_scene()


func _save_game() -> void:
	var saved_buildings: Array = []
	for bld in bm.get_buildings():
		if not (bld is Dictionary):
			continue
		var bd: Dictionary = bld as Dictionary
		var pos: Vector2 = bd.get("position", Vector2.ZERO)
		saved_buildings.append({
			"key": String(bd.get("key", "")),
			"level": int(bd.get("level", 1)),
			"hp": int(bd.get("hp", 0)),
			"max_hp": int(bd.get("max_hp", 0)),
			"x": pos.x,
			"y": pos.y,
		})

	var saved_villagers: Array = []
	for v in villagers:
		if not is_instance_valid(v):
			continue
		var home: Vector2 = v.get("home_position") if v.has_method("get") else Vector2.ZERO
		saved_villagers.append({
			"x": v.global_position.x,
			"y": v.global_position.y,
			"home_x": home.x,
			"home_y": home.y,
			"role": int(v.get("role")),
			"hp": int(v.get("hp")),
			"expertise": v.call("get_expertise_data") if v.has_method("get_expertise_data") else {},
		})

	var data := {
		"resources": ResourceManager.get_all(),
		"tool_levels": {
			"axe": ResourceManager.get_tool_level("axe"),
			"pickaxe": ResourceManager.get_tool_level("pickaxe"),
			"sword": ResourceManager.get_tool_level("sword"),
		},
		"building_stage": bm.get_stage(),
		"buildings_placed": bm.placed.duplicate(),
		"buildings": saved_buildings,
		"wave_count": wave_count,
		"cabin_hp": cabin_hp,
		"map_seed": map_state.get("map_seed", -1),
		"map_tiles": _build_saved_map_state(),
		"villager_count": villagers.size(),
		"villagers": saved_villagers,
		"role_counts": TaskManager.get_role_counts(),
		"tutorial_step": hud.get_tutorial_step() if hud and hud.has_method("get_tutorial_step") else 0,
		"researched_techs": ResourceManager.get_researched_techs(),
		"music_enabled": AudioManager.music_enabled,
		"sfx_enabled": AudioManager.sfx_enabled,
	}
	var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	# Show saved notification
	_show_save_notification()


func _show_save_notification() -> void:
	var lbl := Label.new()
	lbl.text = "GAME SAVED!"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.40))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl.offset_top = 120
	hud.add_child(lbl)
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)


func _try_load_save(preloaded: Dictionary = {}) -> void:
	var d: Dictionary = preloaded
	if d.is_empty():
		d = _read_save_data()
	if d.is_empty():
		return

	# Restore resources
	if d.has("resources"):
		var res: Dictionary = d["resources"]
		ResourceManager.resources["wood"] = int(res.get("wood", 30))
		ResourceManager.resources["stone"] = int(res.get("stone", 25))
		ResourceManager.resources["gold"] = int(res.get("gold", 5))
		ResourceManager.research_points = int(res.get("research", 0))
		ResourceManager.researched_techs = {}
		if d.has("researched_techs"):
			var rt: Dictionary = d["researched_techs"]
			for tech_key: String in rt.keys():
				if bool(rt[tech_key]):
					ResourceManager.researched_techs[tech_key] = true
		ResourceManager.resources_changed.emit(ResourceManager.resources)
		ResourceManager.research_changed.emit(ResourceManager.research_points)

	# Restore tool levels
	if d.has("tool_levels"):
		var tl: Dictionary = d["tool_levels"]
		ResourceManager.tool_levels["axe"] = int(tl.get("axe", 0))
		ResourceManager.tool_levels["pickaxe"] = int(tl.get("pickaxe", 0))
		ResourceManager.tool_levels["sword"] = int(tl.get("sword", 0))

	# Restore villagers exactly (position/role/hp) if present.
	if d.has("villagers") and d["villagers"] is Array:
		for old_v in villagers:
			if is_instance_valid(old_v):
				old_v.queue_free()
		villagers.clear()
		if TaskManager.has_method("reset_state"):
			TaskManager.reset_state()
		var saved_villagers: Array = d["villagers"]
		for item in saved_villagers:
			if not (item is Dictionary):
				continue
			var vd: Dictionary = item as Dictionary
			var vx := float(vd.get("x", 0.0))
			var vy := float(vd.get("y", 0.0))
			var hx := float(vd.get("home_x", map_state["center_x"] * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0))
			var hy := float(vd.get("home_y", map_state["center_y"] * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0))
			_spawn_villager(vx, vy, hx, hy)
			var v = villagers[villagers.size() - 1]
			if is_instance_valid(v):
				if v.has_method("set_expertise_data") and vd.has("expertise") and vd["expertise"] is Dictionary:
					v.call("set_expertise_data", vd["expertise"] as Dictionary)
				var role_key := int(vd.get("role", GameConfig.Role.IDLE))
				if v.has_method("set_role"):
					v.set_role(role_key)
				var max_v_hp := GameConfig.VILLAGER_MAX_HP
				if v.has_method("get_role_scaled_max_hp"):
					max_v_hp = int(v.call("get_role_scaled_max_hp", role_key))
				v.set("hp", clampi(int(vd.get("hp", max_v_hp)), 1, max_v_hp))
				if v.has_method("_update_hp_bar"):
					v.call("_update_hp_bar")

	# Restore building stage
	if d.has("building_stage"):
		var target_stage := int(d["building_stage"])
		while bm.get_stage() < target_stage:
			if bm.get_stage() == GameConfig.BuildingStage.TENT:
				bm.stage = GameConfig.BuildingStage.WOODEN_CABIN
				bm.sprite.texture = textures.get("building_cabin")
			elif bm.get_stage() == GameConfig.BuildingStage.WOODEN_CABIN:
				bm.stage = GameConfig.BuildingStage.STONE_HALL
				bm.sprite.texture = textures.get("building_hall")
			else:
				break
	cabin_max_hp = _get_cabin_max_hp_for_stage(bm.get_stage())

	# Restore wave count and cabin HP
	if d.has("wave_count"):
		wave_count = int(d["wave_count"])
		hud.update_wave(wave_count)
	if d.has("cabin_hp"):
		cabin_hp = clampi(int(d["cabin_hp"]), 0, cabin_max_hp)
		_update_cabin_hp_bar()
		hud.update_cabin_hp(cabin_hp, cabin_max_hp)

	# Restore audio settings
	if d.has("music_enabled"):
		AudioManager.set_music_enabled(bool(d["music_enabled"]))
	if d.has("sfx_enabled"):
		AudioManager.set_sfx_enabled(bool(d["sfx_enabled"]))

	# Restore placed buildings (exact positions if saved, fallback to counts)
	bm.placed.clear()
	bm.healing_hut_count = 0
	if d.has("buildings") and d["buildings"] is Array:
		var sb_list: Array = d["buildings"]
		for item in sb_list:
			if not (item is Dictionary):
				continue
			var bd: Dictionary = item as Dictionary
			var bkey: String = String(bd.get("key", ""))
			if bkey == "":
				continue
			bm.placed[bkey] = bm.placed.get(bkey, 0) + 1
			if bkey == "healing_hut":
				bm.healing_hut_count += 1
			var bpos := Vector2(float(bd.get("x", 0.0)), float(bd.get("y", 0.0)))
			var bhp := int(bd.get("hp", GameConfig.BUILDING_HP.get(bkey, 50)))
			var blvl := int(bd.get("level", 1))
			_place_building_visual(bkey, bpos, bhp, false, blvl)
	elif d.has("buildings_placed"):
		var bp: Dictionary = d["buildings_placed"]
		for key: String in bp:
			var count := int(bp[key])
			for i in range(count):
				if bm.is_unlocked(key):
					bm.placed[key] = bm.placed.get(key, 0) + 1
					if key == "healing_hut":
						bm.healing_hut_count += 1
					_place_building_visual(key, null, -1, false, 1)
		if hud and hud.has_method("sync_tutorial_from_buildings"):
			hud.sync_tutorial_from_buildings(bp)

	# Tutorial persistence: explicit step from save wins; fallback to building-based sync.
	if hud:
		if d.has("tutorial_step") and hud.has_method("set_tutorial_step"):
			hud.set_tutorial_step(int(d.get("tutorial_step", 0)))
		elif hud.has_method("sync_tutorial_from_buildings"):
			hud.sync_tutorial_from_buildings(bm.placed)

	hud.update_building()
	hud.update_resources()
	_rebuild_barricade_cache()
	_sync_armory_unlock_state()
	_refresh_defender_scaling()

	if (not d.has("villagers") or not (d["villagers"] is Array)) and d.has("role_counts"):
		var rc: Dictionary = d["role_counts"]
		_apply_loaded_role_counts(rc)

	hud.update_population(villagers.size())


func _apply_loaded_role_counts(rc: Dictionary) -> void:
	var order: Array = [
		GameConfig.Role.DEFENDER,
		GameConfig.Role.BUILDER,
		GameConfig.Role.SCHOLAR,
		GameConfig.Role.FORESTER,
		GameConfig.Role.LUMBERJACK,
		GameConfig.Role.MINER,
	]
	for role_key in order:
		var target_count: int = int(rc.get(role_key, 0))
		if target_count <= 0:
			continue
		var assigned := 0
		for v in villagers:
			if assigned >= target_count:
				break
			if is_instance_valid(v) and v.role == GameConfig.Role.IDLE:
				v.set_role(role_key)
				assigned += 1


func _place_building_visual(building_key: String, forced_pos: Variant = null, forced_hp: int = -1, assign_workers: bool = true, forced_level: int = 1) -> void:
	var info: Dictionary = GameConfig.BUILDINGS.get(building_key, {})

	var bld_sprite := Sprite2D.new()
	var tex_key := "bld_" + building_key
	bld_sprite.texture = textures.get(tex_key)
	var bpos: Vector2 = _compute_building_position(building_key)
	if forced_pos is Vector2:
		bpos = forced_pos as Vector2
	bld_sprite.position = bpos
	bld_sprite.z_index = 4
	_attach_shadow(bld_sprite, Vector2(36, 12), Vector2(0, 14), 0.28)
	add_child(bld_sprite)

	var hp_base: int = GameConfig.BUILDING_HP.get(building_key, 50)
	var level_now := maxi(1, forced_level)
	var hp_max: int = maxi(1, int(round(float(hp_base) * (1.0 + GameConfig.BUILDING_UPGRADE_HP_PER_LEVEL * float(level_now - 1)))))
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0.2, 0.2, 0.2, 0.7)
	hp_bg.size = Vector2(30, 4)
	hp_bg.position = Vector2(bpos.x - 15, bpos.y - 22)
	hp_bg.z_index = 6
	add_child(hp_bg)

	var hp_fill := ColorRect.new()
	hp_fill.color = Color(0.35, 0.75, 0.30)
	hp_fill.size = Vector2(28, 2)
	hp_fill.position = Vector2(bpos.x - 14, bpos.y - 21)
	hp_fill.z_index = 7
	add_child(hp_fill)

	var hp_now := hp_max
	if forced_hp >= 0:
		hp_now = clampi(forced_hp, 0, hp_max)

	var bld_data := {
		"key": building_key,
		"level": level_now,
		"hp": hp_now,
		"max_hp": hp_max,
		"base_max_hp": hp_base,
		"base_scale": bld_sprite.scale,
		"sprite": bld_sprite,
		"position": bpos,
		"hp_bar_bg": hp_bg,
		"hp_bar_fill": hp_fill,
	}
	bm.register_building(bld_data)
	if building_key == "barricade":
		_rebuild_barricade_cache()
	bm._update_bld_hp_bar(bld_data)

	# Assign workers for loaded buildings
	var spawn_count: int = int(info.get("villagers", 0))
	var target_role: int = GameConfig.building_role(building_key)
	if assign_workers and spawn_count > 0 and target_role != GameConfig.Role.IDLE:
		TaskManager.assign_idle_to_role(target_role, spawn_count)


# ── Cabin HP Bar (world space) ───────────────────────────────

func _create_cabin_hp_bar(cx: float, cy: float) -> void:
	cabin_hp_bar_bg = ColorRect.new()
	cabin_hp_bar_bg.size = Vector2(50, 6)
	cabin_hp_bar_bg.position = Vector2(cx - 25, cy - 40)
	cabin_hp_bar_bg.color = Color(0.15, 0.15, 0.15, 0.85)
	cabin_hp_bar_bg.z_index = 20
	add_child(cabin_hp_bar_bg)

	cabin_hp_bar = ColorRect.new()
	cabin_hp_bar.size = Vector2(48, 4)
	cabin_hp_bar.position = Vector2(cx - 24, cy - 39)
	cabin_hp_bar.color = Color(0.2, 0.8, 0.2)
	cabin_hp_bar.z_index = 21
	add_child(cabin_hp_bar)


func _update_cabin_hp_bar() -> void:
	if not cabin_hp_bar:
		return
	var ratio := clampf(float(cabin_hp) / float(cabin_max_hp), 0.0, 1.0)
	cabin_hp_bar.size.x = 48.0 * ratio
	if ratio > 0.5:
		cabin_hp_bar.color = Color(0.2, 0.8, 0.2)
	elif ratio > 0.25:
		cabin_hp_bar.color = Color.ORANGE
	else:
		cabin_hp_bar.color = Color.RED


func _get_cabin_max_hp_for_stage(stage: int) -> int:
	if GameConfig.CABIN_STAGE_HP.has(stage):
		return int(GameConfig.CABIN_STAGE_HP[stage])
	return GameConfig.CABIN_MAX_HP


# ── Tree Sprite Sheet System ─────────────────────────────────

func _load_tree_sprite_sheet() -> void:
	tree_atlas.clear()

	# Always load standalone tree PNGs first — these are the primary static sprites
	var t1 := _load_texture_direct(TREE1_PATH)
	var t2 := _load_texture_direct(TREE2_PATH)
	if t1:
		tree_atlas["static_pine_variants"] = [t1]
		print("tree1.png loaded OK")
	else:
		push_warning("trees/tree1.png failed to load from: " + TREE1_PATH)
	if t2:
		tree_atlas["static_oak_variants"] = [t2]
		print("tree2.png loaded OK")
	else:
		push_warning("trees/tree2.png failed to load from: " + TREE2_PATH)

	# Optionally load animation frames from sprite sheet (chop/fall/stump/logs)
	var img := Image.new()
	var path := ProjectSettings.globalize_path("res://tree_sprite_sheet.png")
	if img.load(path) != OK:
		print("tree_sprite_sheet.png not found, skipping optional chop/fall/stump frames")
		return
	var cols := img.get_width() / TREE_CELL_W
	var rows := img.get_height() / TREE_CELL_H
	if cols < 4 or rows < 6:
		print("tree_sprite_sheet.png too small, skipping optional chop/fall frames")
		return

	# Chopping frames (row 3)
	tree_atlas["chop_0"] = _make_grid_tex_from_image(img, 0, 3)
	tree_atlas["chop_1"] = _make_grid_tex_from_image(img, 1, 3)
	tree_atlas["chop_2"] = _make_grid_tex_from_image(img, 2, 3)
	tree_atlas["chop_3"] = _make_grid_tex_from_image(img, 3, 3)

	# Falling frames (row 4)
	tree_atlas["fall_0"] = _make_grid_tex_from_image(img, 0, 4)
	tree_atlas["fall_1"] = _make_grid_tex_from_image(img, 1, 4)
	tree_atlas["fall_2"] = _make_grid_tex_from_image(img, 2, 4)

	# Stump + log pile
	tree_atlas["stump"] = _make_grid_tex_from_image(img, 0, 5)
	tree_atlas["log_pile"] = _make_grid_tex_from_image(img, 1, 2)


func _make_atlas_tex(sheet: ImageTexture, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	return atlas


func _make_grid_tex(sheet: ImageTexture, col: int, row: int, cols: int, rows: int) -> AtlasTexture:
	var cell_w := float(sheet.get_width()) / float(cols)
	var cell_h := float(sheet.get_height()) / float(rows)
	var region := Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
	return _make_atlas_tex(sheet, region)


func _make_grid_tex_from_image(src: Image, col: int, row: int) -> ImageTexture:
	var x := col * TREE_CELL_W
	var y := row * TREE_CELL_H
	var max_w := src.get_width() - x
	var max_h := src.get_height() - y
	var w := mini(TREE_CELL_W, max_w)
	var h := mini(TREE_CELL_H, max_h)
	if w <= 0 or h <= 0:
		return null
	var cell := Image.create(w, h, false, Image.FORMAT_RGBA8)
	cell.blit_rect(src, Rect2i(x, y, w, h), Vector2i.ZERO)
	return ImageTexture.create_from_image(cell)


func _spawn_tree_nodes() -> void:
	if tree_atlas.is_empty():
		return
	var tree_script := load("res://scripts/tree_resource.gd")
	if tree_script == null:
		return
	if not tree_atlas.has("static_pine_variants") or not tree_atlas.has("static_oak_variants"):
		return
	var chop_arr: Array = []
	if tree_atlas.has("chop_0"):
		chop_arr = [tree_atlas["chop_0"], tree_atlas.get("chop_1"), tree_atlas.get("chop_2"), tree_atlas.get("chop_3")]
	var fall_arr: Array = []
	if tree_atlas.has("fall_0"):
		fall_arr = [tree_atlas["fall_0"], tree_atlas.get("fall_1"), tree_atlas.get("fall_2")]
	var pine_variants: Array = tree_atlas["static_pine_variants"]
	var oak_variants: Array = tree_atlas["static_oak_variants"]

	for y in range(GameConfig.MAP_HEIGHT):
		for x in range(GameConfig.MAP_WIDTH):
			var tile_type: int = map_state["resource_data"][y][x]
			if tile_type != GameConfig.TileType.TREE_PINE and tile_type != GameConfig.TileType.TREE_OAK:
				continue

			var tree = tree_script.new()
			var world_x := x * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0
			var world_y := y * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0
			tree.position = Vector2(world_x, world_y)
			tree.tile_pos = Vector2i(x, y)
			tree_container.add_child(tree)

			var static_tex: Texture2D
			if tile_type == GameConfig.TileType.TREE_PINE:
				static_tex = pine_variants[randi() % pine_variants.size()]
			else:
				static_tex = oak_variants[randi() % oak_variants.size()]

			tree.setup(static_tex, chop_arr, fall_arr, tree_atlas.get("stump"), tree_atlas.get("log_pile"))
			tree_nodes[Vector2i(x, y)] = tree
			tilemap.erase_cell(1, Vector2i(x, y))


func _clear_trees_in_radius(radius: int) -> void:
	var cx: int = map_state["center_x"]
	var cy: int = map_state["center_y"]
	var tiles_to_remove: Array = []
	for tile in tree_nodes:
		var dist := sqrt(pow(tile.x - cx, 2) + pow(tile.y - cy, 2))
		if dist <= radius:
			tiles_to_remove.append(tile)
	for tile in tiles_to_remove:
		var tree = tree_nodes[tile]
		if is_instance_valid(tree):
			tree.queue_free()
		tree_nodes.erase(tile)
