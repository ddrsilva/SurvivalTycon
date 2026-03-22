# ============================================================
# Runtime Pixel Art Asset Generator
# Generates all game textures procedurally at startup
# ============================================================
class_name AssetGenerator
extends RefCounted

const T := GameConfig.TILE_SIZE
const EXTERNAL_TENT_PATH := "res://tent/tent.png"
const EXTERNAL_TENT_TARGET_HEIGHT := 96


## Generate all game textures and return a dictionary of ImageTextures.
static func generate_all() -> Dictionary:
	var textures := {}

	# Tile textures
	textures["tile_grass"] = _make_grass()
	textures["tile_dirt"] = _make_dirt()
	textures["tile_tree_pine"] = _make_tree_pine()
	textures["tile_tree_oak"] = _make_tree_oak()
	textures["tile_rock"] = _make_rock()
	textures["tile_ore"] = _make_ore()
	textures["tile_log_pile"] = _make_log_pile_tile()
	textures["tile_water"] = _make_water()
	textures["tile_sand"] = _make_sand()

	# Entity textures
	textures["villager"] = _make_villager(Color(0.788, 0.541, 0.369))
	textures["villager_lumberjack"] = _make_villager(Color(0.831, 0.627, 0.090))
	textures["villager_miner"] = _make_villager(Color(0.533, 0.533, 0.533))
	textures["villager_defender"] = _make_villager(Color(0.8, 0.2, 0.2))
	textures["villager_forester"] = _make_villager(Color(0.16, 0.72, 0.33))

	# Buildings
	textures["building_tent"] = _make_tent()
	textures["building_cabin"] = _make_cabin()
	textures["building_hall"] = _make_hall()
	var external_tent := _load_external_texture(EXTERNAL_TENT_PATH, EXTERNAL_TENT_TARGET_HEIGHT)
	if external_tent:
		textures["building_tent"] = external_tent

	# Placed building textures
	textures["bld_carpentry"] = _make_bld_carpentry()
	textures["bld_mining_house"] = _make_bld_mining()
	textures["bld_army_base"] = _make_bld_army()
	textures["bld_healing_hut"] = _make_bld_healing()
	textures["bld_forester_lodge"] = _make_bld_forester_lodge()
	textures["bld_training_grounds"] = _make_bld_training_grounds()
	textures["bld_armory"] = _make_bld_armory()
	textures["bld_trap"] = _make_bld_trap()
	textures["bld_barricade"] = _make_bld_barricade()
	textures["bld_mine"] = _make_bld_mine()
	textures["bld_watch_tower"] = _make_bld_watchtower()
	textures["bld_ballista_tower"] = _make_bld_ballista_tower()

	# Props
	textures["chest"] = _make_chest()
	textures["campfire"] = _make_campfire()
	textures["flame"] = _make_flame()
	textures["threat"] = _make_threat()
	textures["slime"] = _make_slime()
	textures["wolf"] = _make_wolf()
	textures["bear"] = _make_bear()

	return textures


# ── Helpers ──────────────────────────────────────────────────

static func _create_image(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(maxi(y, 0), mini(y + h, img.get_height())):
		for px in range(maxi(x, 0), mini(x + w, img.get_width())):
			img.set_pixel(px, py, color)


static func _fill_circle(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for py in range(maxi(cy - radius, 0), mini(cy + radius + 1, img.get_height())):
		for px in range(maxi(cx - radius, 0), mini(cx + radius + 1, img.get_width())):
			if (px - cx) * (px - cx) + (py - cy) * (py - cy) <= radius * radius:
				img.set_pixel(px, py, color)


static func _fill_triangle(img: Image, x0: int, y0: int, x1: int, y1: int, x2: int, y2: int, color: Color) -> void:
	var min_x := maxi(mini(mini(x0, x1), x2), 0)
	var max_x := mini(maxi(maxi(x0, x1), x2), img.get_width() - 1)
	var min_y := maxi(mini(mini(y0, y1), y2), 0)
	var max_y := mini(maxi(maxi(y0, y1), y2), img.get_height() - 1)

	for py in range(min_y, max_y + 1):
		for px in range(min_x, max_x + 1):
			if _point_in_triangle(px, py, x0, y0, x1, y1, x2, y2):
				img.set_pixel(px, py, color)


static func _point_in_triangle(px: int, py: int, x0: int, y0: int, x1: int, y1: int, x2: int, y2: int) -> bool:
	var d1 := (px - x1) * (y0 - y1) - (x0 - x1) * (py - y1)
	var d2 := (px - x2) * (y1 - y2) - (x1 - x2) * (py - y2)
	var d3 := (px - x0) * (y2 - y0) - (x2 - x0) * (py - y0)
	var has_neg := (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos := (d1 > 0) or (d2 > 0) or (d3 > 0)
	return not (has_neg and has_pos)


static func _to_texture(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func _load_external_texture(path: String, target_height: int = 0) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null

	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(path))
	if err != OK:
		return null

	if target_height > 0 and img.get_height() > 0 and img.get_height() != target_height:
		var ratio := float(target_height) / float(img.get_height())
		var new_w := maxi(1, int(round(img.get_width() * ratio)))
		img.resize(new_w, target_height, Image.INTERPOLATE_NEAREST)

	return ImageTexture.create_from_image(img)


# ── Tile Generators ──────────────────────────────────────────

static func _make_grass() -> ImageTexture:
	var img := _create_image(T, T)
	_fill_rect(img, 0, 0, T, T, Color(0.26, 0.45, 0.22))
	for i in range(14):
		var px := randi_range(0, T - 2)
		var py := randi_range(0, T - 2)
		var c := Color(0.22, 0.40, 0.18) if randf() < 0.55 else Color(0.31, 0.53, 0.27)
		_fill_rect(img, px, py, 1, 1, c)
	for i in range(5):
		var px2 := randi_range(1, T - 4)
		var py2 := randi_range(1, T - 4)
		_fill_rect(img, px2, py2, 2, 2, Color(0.36, 0.58, 0.30, 0.55))
	return _to_texture(img)


static func _make_dirt() -> ImageTexture:
	var img := _create_image(T, T)
	_fill_rect(img, 0, 0, T, T, Color(0.53, 0.41, 0.29))
	for i in range(10):
		var px := randi_range(0, T - 2)
		var py := randi_range(0, T - 2)
		var dot := Color(0.44, 0.34, 0.24) if randf() < 0.65 else Color(0.62, 0.50, 0.37)
		_fill_rect(img, px, py, 1, 1, dot)
	for i in range(3):
		var rx := randi_range(2, T - 6)
		var ry := randi_range(2, T - 6)
		_fill_rect(img, rx, ry, 3, 2, Color(0.40, 0.31, 0.22, 0.7))
	return _to_texture(img)


static func _make_tree_pine() -> ImageTexture:
	var img := _create_image(T, T)
	_fill_rect(img, 0, 0, T, T, Color(0.26, 0.45, 0.22))  # grass base
	_fill_rect(img, 13, 20, 6, 12, Color(0.361, 0.227, 0.118))  # trunk
	_fill_triangle(img, 16, 2, 6, 16, 26, 16, Color(0.176, 0.353, 0.118))
	_fill_triangle(img, 16, 6, 8, 18, 24, 18, Color(0.212, 0.478, 0.157))
	_fill_triangle(img, 16, 10, 10, 22, 22, 22, Color(0.176, 0.353, 0.118))
	_fill_rect(img, 15, 8, 2, 2, Color(0.28, 0.55, 0.19))
	return _to_texture(img)


static func _make_tree_oak() -> ImageTexture:
	var img := _create_image(T, T)
	_fill_rect(img, 0, 0, T, T, Color(0.26, 0.45, 0.22))
	_fill_rect(img, 13, 18, 6, 14, Color(0.420, 0.259, 0.149))
	_fill_circle(img, 16, 12, 10, Color(0.227, 0.549, 0.165))
	_fill_circle(img, 14, 10, 6, Color(0.180, 0.478, 0.125))
	_fill_circle(img, 19, 11, 4, Color(0.26, 0.60, 0.20))
	return _to_texture(img)


static func _make_rock() -> ImageTexture:
	var img := _create_image(T, T)
	_fill_rect(img, 0, 0, T, T, Color(0.29, 0.486, 0.247))
	# Main rock body
	_fill_circle(img, 16, 18, 10, Color(0.533, 0.533, 0.533))
	_fill_circle(img, 14, 16, 7, Color(0.667, 0.667, 0.667))
	# Highlight
	_fill_rect(img, 12, 13, 3, 2, Color(0.75, 0.75, 0.75))
	return _to_texture(img)


static func _make_ore() -> ImageTexture:
	var img := _create_image(T, T)
	_fill_rect(img, 0, 0, T, T, Color(0.29, 0.486, 0.247))
	_fill_circle(img, 16, 18, 10, Color(0.467, 0.467, 0.467))
	_fill_circle(img, 14, 16, 7, Color(0.600, 0.600, 0.600))
	# Gold veins
	_fill_rect(img, 12, 14, 4, 3, Color(0.831, 0.627, 0.090))
	_fill_rect(img, 18, 18, 3, 3, Color(0.831, 0.627, 0.090))
	_fill_rect(img, 10, 20, 3, 2, Color(0.910, 0.722, 0.188))
	return _to_texture(img)


static func _make_log_pile_tile() -> ImageTexture:
	var img := _create_image(T, T)
	_fill_rect(img, 0, 0, T, T, Color(0.29, 0.486, 0.247))
	_fill_rect(img, 8, 18, 16, 4, Color(0.45, 0.30, 0.12))
	_fill_rect(img, 10, 14, 12, 4, Color(0.40, 0.27, 0.10))
	_fill_rect(img, 12, 22, 8, 3, Color(0.50, 0.33, 0.14))
	return _to_texture(img)


static func _make_water() -> ImageTexture:
	var img := _create_image(T, T)
	_fill_rect(img, 0, 0, T, T, Color(0.15, 0.33, 0.56))
	for y in range(T):
		if y % 6 == 0:
			_fill_rect(img, 0, y, T, 1, Color(0.12, 0.28, 0.50, 0.45))
	# Small wave highlights
	for i in range(5):
		var px := randi_range(2, T - 8)
		var py := randi_range(2, T - 4)
		_fill_rect(img, px, py, randi_range(4, 9), 1, Color(0.30, 0.50, 0.74, 0.9))
	return _to_texture(img)


static func _make_sand() -> ImageTexture:
	var img := _create_image(T, T)
	_fill_rect(img, 0, 0, T, T, Color(0.84, 0.74, 0.53))
	for i in range(8):
		var px := randi_range(0, T - 2)
		var py := randi_range(0, T - 2)
		var c := Color(0.77, 0.67, 0.47) if randf() < 0.6 else Color(0.91, 0.84, 0.67)
		_fill_rect(img, px, py, 1, 1, c)
	if randf() < 0.4:
		_fill_rect(img, randi_range(4, T - 8), randi_range(4, T - 8), 4, 2, Color(0.86, 0.80, 0.65, 0.8))
	if randf() < 0.3:
		_fill_rect(img, randi_range(4, T - 6), randi_range(4, T - 6), 2, 2, Color(0.88, 0.82, 0.68))
	return _to_texture(img)


# ── Entity Generators ────────────────────────────────────────

static func _make_villager(hat_color: Color) -> ImageTexture:
	var img := _create_image(16, 16)
	# Body
	_fill_rect(img, 5, 6, 6, 8, Color(0.788, 0.541, 0.369))
	# Head
	_fill_circle(img, 8, 4, 3, Color(0.910, 0.784, 0.620))
	# Eyes
	_fill_rect(img, 7, 3, 1, 1, Color(0.2, 0.2, 0.2))
	_fill_rect(img, 9, 3, 1, 1, Color(0.2, 0.2, 0.2))
	# Hat/badge (role color)
	_fill_rect(img, 5, 0, 6, 3, hat_color)
	return _to_texture(img)


# ── Building Generators ──────────────────────────────────────

static func _make_tent() -> ImageTexture:
	var size := T * 2
	var img := _create_image(size, size)
	var cx := T
	# Yellow tent triangle
	_fill_triangle(img, cx, 4, 4, size - 8, size - 4, size - 8, Color(0.910, 0.784, 0.251))
	# Darker half
	_fill_triangle(img, cx, 4, cx, size - 8, size - 4, size - 8, Color(0.784, 0.659, 0.188))
	# Entrance
	_fill_rect(img, cx - 4, size - 16, 8, 8, Color(0.361, 0.227, 0.118))
	return _to_texture(img)


static func _make_cabin() -> ImageTexture:
	var size := T * 2
	var img := _create_image(size, size)
	var cx := T
	# Walls
	_fill_rect(img, 4, 12, size - 8, size - 16, Color(0.545, 0.412, 0.078))
	# Roof
	_fill_triangle(img, cx, 2, 0, 16, size, 16, Color(0.361, 0.227, 0.118))
	# Door
	_fill_rect(img, cx - 4, size - 14, 8, 10, Color(0.227, 0.149, 0.063))
	# Windows
	_fill_rect(img, 10, 22, 6, 6, Color(0.529, 0.808, 0.922))
	_fill_rect(img, size - 16, 22, 6, 6, Color(0.529, 0.808, 0.922))
	return _to_texture(img)


static func _make_hall() -> ImageTexture:
	var size := T * 3
	var img := _create_image(size, size)
	var cx := size / 2
	# Stone walls
	_fill_rect(img, 6, 20, size - 12, size - 24, Color(0.600, 0.600, 0.600))
	# Roof
	_fill_triangle(img, cx, 4, 2, 24, size - 2, 24, Color(0.400, 0.400, 0.400))
	# Door
	_fill_rect(img, cx - 6, size - 18, 12, 14, Color(0.361, 0.227, 0.118))
	# Flag pole + flag
	_fill_rect(img, cx - 1, 0, 2, 10, Color(0.361, 0.227, 0.118))
	_fill_rect(img, cx + 1, 0, 8, 5, Color(0.800, 0.200, 0.200))
	# Windows
	for wx in range(16, size - 16, 18):
		_fill_rect(img, wx, 30, 8, 8, Color(0.529, 0.808, 0.922))
	return _to_texture(img)


static func _make_chest() -> ImageTexture:
	var img := _create_image(T, T)
	_fill_rect(img, 4, 8, 24, 18, Color(0.545, 0.412, 0.078))
	_fill_rect(img, 4, 8, 24, 4, Color(0.361, 0.227, 0.118))
	# Lock
	_fill_rect(img, 14, 16, 4, 4, Color(0.831, 0.627, 0.090))
	return _to_texture(img)


static func _make_campfire() -> ImageTexture:
	var img := _create_image(T, T)
	# Rocks in circle
	var rock_positions := [
		Vector2i(8, 24), Vector2i(14, 26), Vector2i(20, 24),
		Vector2i(24, 20), Vector2i(22, 16), Vector2i(12, 16), Vector2i(6, 20)]
	for pos in rock_positions:
		_fill_circle(img, pos.x, pos.y, 3, Color(0.400, 0.400, 0.400))
	# Flame outer
	_fill_triangle(img, 16, 6, 10, 22, 22, 22, Color(1.0, 0.4, 0.0))
	# Flame inner
	_fill_triangle(img, 16, 10, 12, 20, 20, 20, Color(1.0, 0.8, 0.0))
	return _to_texture(img)


static func _make_flame() -> ImageTexture:
	var img := _create_image(16, 20)
	# Outer flame
	_fill_triangle(img, 8, 1, 1, 19, 15, 19, Color(1.0, 0.42, 0.08, 0.94))
	# Inner flame
	_fill_triangle(img, 8, 5, 3, 19, 13, 19, Color(1.0, 0.84, 0.18, 0.96))
	# White-hot core
	_fill_triangle(img, 8, 9, 5, 19, 11, 19, Color(1.0, 0.96, 0.60, 0.90))
	return _to_texture(img)


static func _make_threat() -> ImageTexture:
	var img := _create_image(20, 20)
	# Body
	_fill_rect(img, 3, 8, 14, 8, Color(0.333, 0.333, 0.333))
	# Head
	_fill_circle(img, 15, 8, 5, Color(0.400, 0.400, 0.400))
	# Red eyes
	_fill_rect(img, 14, 6, 2, 2, Color(1.0, 0.2, 0.2))
	_fill_rect(img, 16, 6, 2, 2, Color(1.0, 0.2, 0.2))
	# Legs
	_fill_rect(img, 4, 16, 2, 4, Color(0.267, 0.267, 0.267))
	_fill_rect(img, 10, 16, 2, 4, Color(0.267, 0.267, 0.267))
	_fill_rect(img, 14, 16, 2, 4, Color(0.267, 0.267, 0.267))
	return _to_texture(img)


static func _make_slime() -> ImageTexture:
	var img := _create_image(20, 20)
	# Blobby body
	_fill_circle(img, 10, 12, 8, Color(0.318, 0.769, 0.314))
	_fill_circle(img, 10, 10, 6, Color(0.408, 0.851, 0.400))
	# Highlight
	_fill_circle(img, 7, 8, 2, Color(0.600, 0.950, 0.580))
	# Eyes
	_fill_rect(img, 7, 9, 2, 2, Color(0.1, 0.1, 0.1))
	_fill_rect(img, 11, 9, 2, 2, Color(0.1, 0.1, 0.1))
	return _to_texture(img)


static func _make_wolf() -> ImageTexture:
	var img := _create_image(22, 18)
	# Body
	_fill_rect(img, 3, 7, 16, 7, Color(0.420, 0.380, 0.345))
	# Head
	_fill_circle(img, 17, 6, 5, Color(0.467, 0.420, 0.380))
	# Ears
	_fill_triangle(img, 14, 0, 13, 4, 16, 4, Color(0.35, 0.31, 0.27))
	_fill_triangle(img, 19, 0, 18, 4, 21, 4, Color(0.35, 0.31, 0.27))
	# Eyes
	_fill_rect(img, 16, 5, 2, 2, Color(0.9, 0.7, 0.1))
	_fill_rect(img, 19, 5, 1, 1, Color(0.9, 0.7, 0.1))
	# Snout
	_fill_rect(img, 20, 7, 2, 2, Color(0.25, 0.22, 0.18))
	# Legs
	_fill_rect(img, 5, 14, 2, 4, Color(0.35, 0.31, 0.27))
	_fill_rect(img, 10, 14, 2, 4, Color(0.35, 0.31, 0.27))
	_fill_rect(img, 14, 14, 2, 4, Color(0.35, 0.31, 0.27))
	# Tail
	_fill_rect(img, 0, 6, 4, 2, Color(0.45, 0.40, 0.36))
	return _to_texture(img)


static func _make_bear() -> ImageTexture:
	var img := _create_image(26, 22)
	# Body (large stocky body)
	_fill_rect(img, 4, 6, 18, 10, Color(0.40, 0.26, 0.13))
	# Head
	_fill_circle(img, 20, 5, 6, Color(0.45, 0.30, 0.16))
	# Ears
	_fill_circle(img, 16, 0, 2, Color(0.35, 0.22, 0.10))
	_fill_circle(img, 23, 0, 2, Color(0.35, 0.22, 0.10))
	# Snout
	_fill_rect(img, 23, 5, 3, 3, Color(0.55, 0.40, 0.25))
	_fill_rect(img, 25, 5, 1, 1, Color(0.15, 0.10, 0.05))
	# Eyes
	_fill_rect(img, 19, 4, 2, 2, Color(0.1, 0.1, 0.1))
	_fill_rect(img, 22, 4, 1, 1, Color(0.1, 0.1, 0.1))
	# Legs (thick)
	_fill_rect(img, 5, 15, 3, 5, Color(0.35, 0.22, 0.10))
	_fill_rect(img, 10, 15, 3, 5, Color(0.35, 0.22, 0.10))
	_fill_rect(img, 15, 15, 3, 5, Color(0.35, 0.22, 0.10))
	_fill_rect(img, 19, 15, 3, 5, Color(0.35, 0.22, 0.10))
	# Belly highlight
	_fill_rect(img, 8, 10, 10, 4, Color(0.50, 0.35, 0.20))
	return _to_texture(img)


# ── Placed building sprites (small huts near cabin) ──────────

static func _make_bld_carpentry() -> ImageTexture:
	var s := T  # 32x32
	var img := _create_image(s, s)
	# Wooden hut
	_fill_rect(img, 4, 10, 24, 18, Color(0.55, 0.40, 0.15))
	# Roof
	_fill_triangle(img, 16, 2, 2, 14, 30, 14, Color(0.40, 0.28, 0.10))
	# Door
	_fill_rect(img, 13, 20, 6, 8, Color(0.30, 0.18, 0.08))
	# Axe sign on wall
	_fill_rect(img, 6, 14, 2, 8, Color(0.35, 0.22, 0.10))
	_fill_rect(img, 4, 14, 6, 2, Color(0.65, 0.65, 0.65))
	return _to_texture(img)


static func _make_bld_mining() -> ImageTexture:
	var s := T
	var img := _create_image(s, s)
	# Stone hut
	_fill_rect(img, 4, 10, 24, 18, Color(0.50, 0.50, 0.50))
	# Roof
	_fill_triangle(img, 16, 2, 2, 14, 30, 14, Color(0.38, 0.38, 0.38))
	# Door
	_fill_rect(img, 13, 20, 6, 8, Color(0.25, 0.15, 0.08))
	# Pickaxe sign
	_fill_rect(img, 22, 13, 2, 8, Color(0.55, 0.40, 0.20))
	_fill_rect(img, 20, 13, 6, 2, Color(0.65, 0.65, 0.65))
	return _to_texture(img)


static func _make_bld_army() -> ImageTexture:
	var s := T
	var img := _create_image(s, s)
	# Dark red fort
	_fill_rect(img, 4, 8, 24, 20, Color(0.50, 0.22, 0.18))
	# Battlements
	_fill_rect(img, 4, 6, 6, 6, Color(0.55, 0.25, 0.20))
	_fill_rect(img, 13, 6, 6, 6, Color(0.55, 0.25, 0.20))
	_fill_rect(img, 22, 6, 6, 6, Color(0.55, 0.25, 0.20))
	# Door
	_fill_rect(img, 13, 20, 6, 8, Color(0.25, 0.12, 0.08))
	# Flag on top
	_fill_rect(img, 15, 0, 2, 8, Color(0.40, 0.22, 0.12))
	_fill_rect(img, 17, 1, 6, 4, Color(0.85, 0.20, 0.15))
	return _to_texture(img)


static func _make_bld_healing() -> ImageTexture:
	var s := T
	var img := _create_image(s, s)
	# White hut
	_fill_rect(img, 4, 10, 24, 18, Color(0.85, 0.85, 0.80))
	# Roof
	_fill_triangle(img, 16, 2, 2, 14, 30, 14, Color(0.70, 0.72, 0.68))
	# Door
	_fill_rect(img, 13, 20, 6, 8, Color(0.45, 0.30, 0.18))
	# Red cross
	_fill_rect(img, 14, 12, 4, 8, Color(0.85, 0.18, 0.15))
	_fill_rect(img, 12, 14, 8, 4, Color(0.85, 0.18, 0.15))
	return _to_texture(img)


static func _make_bld_forester_lodge() -> ImageTexture:
	var s := T
	var img := _create_image(s, s)
	_fill_rect(img, 4, 10, 24, 18, Color(0.36, 0.44, 0.20))
	_fill_triangle(img, 16, 2, 2, 14, 30, 14, Color(0.28, 0.36, 0.15))
	_fill_rect(img, 13, 20, 6, 8, Color(0.24, 0.16, 0.08))
	_fill_triangle(img, 22, 8, 20, 14, 24, 14, Color(0.18, 0.62, 0.26))
	_fill_rect(img, 21, 11, 2, 6, Color(0.34, 0.22, 0.12))
	return _to_texture(img)


static func _make_bld_training_grounds() -> ImageTexture:
	var s := T
	var img := _create_image(s, s)
	_fill_rect(img, 3, 16, 26, 12, Color(0.45, 0.28, 0.18))
	_fill_rect(img, 4, 8, 4, 18, Color(0.54, 0.38, 0.20))
	_fill_rect(img, 24, 8, 4, 18, Color(0.54, 0.38, 0.20))
	_fill_rect(img, 8, 8, 16, 3, Color(0.58, 0.42, 0.24))
	_fill_rect(img, 14, 10, 4, 10, Color(0.80, 0.20, 0.15))
	_fill_rect(img, 10, 18, 12, 2, Color(0.72, 0.68, 0.61))
	return _to_texture(img)


static func _make_bld_armory() -> ImageTexture:
	var s := T
	var img := _create_image(s, s)
	_fill_rect(img, 4, 10, 24, 18, Color(0.40, 0.40, 0.45))
	_fill_triangle(img, 16, 2, 2, 14, 30, 14, Color(0.30, 0.30, 0.34))
	_fill_rect(img, 13, 20, 6, 8, Color(0.22, 0.22, 0.24))
	_fill_rect(img, 8, 14, 2, 8, Color(0.72, 0.72, 0.76))
	_fill_rect(img, 22, 14, 2, 8, Color(0.72, 0.72, 0.76))
	_fill_rect(img, 21, 14, 4, 2, Color(0.72, 0.72, 0.76))
	return _to_texture(img)


static func _make_bld_mine() -> ImageTexture:
	var s := T  # 32x32
	var img := _create_image(s, s)
	# Dark stone cave entrance
	_fill_rect(img, 4, 12, 24, 16, Color(0.35, 0.30, 0.25))
	# Cave opening (dark)
	_fill_rect(img, 8, 16, 16, 12, Color(0.12, 0.10, 0.08))
	# Stone arch
	_fill_triangle(img, 16, 4, 2, 16, 30, 16, Color(0.45, 0.42, 0.38))
	# Wooden beams
	_fill_rect(img, 7, 12, 2, 16, Color(0.55, 0.40, 0.15))
	_fill_rect(img, 23, 12, 2, 16, Color(0.55, 0.40, 0.15))
	_fill_rect(img, 7, 12, 18, 2, Color(0.55, 0.40, 0.15))
	# Gold veins on sides
	_fill_rect(img, 5, 18, 2, 2, Color(0.83, 0.63, 0.09))
	_fill_rect(img, 25, 22, 2, 2, Color(0.83, 0.63, 0.09))
	return _to_texture(img)


static func _make_bld_watchtower() -> ImageTexture:
	var s := T  # 32x32
	var img := _create_image(s, s)
	# Wooden tower base (tall narrow structure)
	_fill_rect(img, 10, 14, 12, 16, Color(0.50, 0.36, 0.12))
	# Legs/supports
	_fill_rect(img, 8, 20, 3, 10, Color(0.45, 0.32, 0.10))
	_fill_rect(img, 21, 20, 3, 10, Color(0.45, 0.32, 0.10))
	# Platform (wider than tower body)
	_fill_rect(img, 6, 12, 20, 3, Color(0.55, 0.40, 0.15))
	# Railing/crenellations
	_fill_rect(img, 6, 10, 3, 3, Color(0.55, 0.40, 0.15))
	_fill_rect(img, 12, 10, 3, 3, Color(0.55, 0.40, 0.15))
	_fill_rect(img, 18, 10, 3, 3, Color(0.55, 0.40, 0.15))
	_fill_rect(img, 23, 10, 3, 3, Color(0.55, 0.40, 0.15))
	# Roof
	_fill_triangle(img, 16, 2, 6, 10, 26, 10, Color(0.40, 0.28, 0.10))
	# Archer (small figure)
	_fill_rect(img, 14, 6, 4, 5, Color(0.80, 0.20, 0.15))
	return _to_texture(img)


static func _make_bld_ballista_tower() -> ImageTexture:
	var s := T
	var img := _create_image(s, s)
	_fill_rect(img, 8, 14, 16, 16, Color(0.46, 0.36, 0.20))
	_fill_rect(img, 6, 12, 20, 3, Color(0.56, 0.43, 0.24))
	_fill_triangle(img, 16, 4, 7, 12, 25, 12, Color(0.36, 0.27, 0.13))
	_fill_rect(img, 13, 8, 10, 2, Color(0.62, 0.62, 0.65))
	_fill_rect(img, 21, 7, 6, 3, Color(0.48, 0.34, 0.18))
	_fill_rect(img, 24, 6, 5, 1, Color(0.75, 0.75, 0.78))
	return _to_texture(img)


static func _make_bld_trap() -> ImageTexture:
	var s := T
	var img := _create_image(s, s)
	# Base plate
	_fill_rect(img, 6, 20, 20, 6, Color(0.42, 0.30, 0.18))
	# Spikes
	for i in range(6):
		var x := 7 + i * 3
		_fill_triangle(img, x + 1, 10, x, 20, x + 2, 20, Color(0.72, 0.72, 0.69))
	# Edge shading
	_fill_rect(img, 6, 25, 20, 1, Color(0.22, 0.16, 0.10))
	return _to_texture(img)


static func _make_bld_barricade() -> ImageTexture:
	var s := T
	var img := _create_image(s, s)
	# Vertical posts
	_fill_rect(img, 8, 8, 3, 20, Color(0.47, 0.33, 0.18))
	_fill_rect(img, 21, 8, 3, 20, Color(0.47, 0.33, 0.18))
	# Horizontal planks
	_fill_rect(img, 9, 11, 14, 3, Color(0.58, 0.42, 0.23))
	_fill_rect(img, 9, 17, 14, 3, Color(0.56, 0.39, 0.21))
	_fill_rect(img, 9, 23, 14, 3, Color(0.54, 0.37, 0.20))
	# Rope ties
	_fill_rect(img, 10, 10, 1, 4, Color(0.79, 0.66, 0.37))
	_fill_rect(img, 21, 22, 1, 4, Color(0.79, 0.66, 0.37))
	return _to_texture(img)
