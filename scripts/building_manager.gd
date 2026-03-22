# ============================================================
# Building Manager — Cabin evolution + placeable buildings
# Evolution is now manual (player clicks "Evolve" button).
# Placeable buildings: Carpentry, Mining House, Army Base,
#                      Healing Hut
# Each placed building has HP, a sprite, and can be destroyed.
# ============================================================
class_name BuildingManager
extends RefCounted

signal evolved(stage: int)
signal building_placed(building_key: String)
signal building_destroyed(building_key: String, bld_data: Dictionary)

var stage: int = GameConfig.BuildingStage.TENT
var sprite: Sprite2D
var map_state: Dictionary
var tilemap: TileMap
var textures: Dictionary

# Array of placed building dicts:
#   { "key": String, "level": int, "hp": int, "max_hp": int, "sprite": Sprite2D,
#     "position": Vector2, "hp_bar_bg": ColorRect, "hp_bar_fill": ColorRect }
var buildings: Array = []
# Quick counts
var placed: Dictionary = {}
var healing_hut_count: int = 0


func setup(building_sprite: Sprite2D, ms: Dictionary, tm: TileMap, tex: Dictionary) -> void:
	sprite = building_sprite
	map_state = ms
	tilemap = tm
	textures = tex
	sprite.texture = textures.get("building_tent")


# ── Manual evolution ─────────────────────────────────────────

func can_evolve() -> bool:
	var req: Variant = get_next_requirements()
	if req == null:
		return false
	var rd: Dictionary = req as Dictionary
	return ResourceManager.can_afford({"wood": rd["wood"], "stone": rd["stone"], "gold": rd["gold"]})


func try_evolve() -> bool:
	if not can_evolve():
		return false
	if stage == GameConfig.BuildingStage.TENT:
		var req: Dictionary = GameConfig.EVOLUTION["wooden_cabin"]
		_evolve(GameConfig.BuildingStage.WOODEN_CABIN, "building_cabin", req)
		return true
	elif stage == GameConfig.BuildingStage.WOODEN_CABIN:
		var req: Dictionary = GameConfig.EVOLUTION["stone_hall"]
		_evolve(GameConfig.BuildingStage.STONE_HALL, "building_hall", req)
		return true
	return false


func _evolve(new_stage: int, texture_key: String, req: Dictionary) -> void:
	ResourceManager.spend({"wood": req["wood"], "stone": req["stone"], "gold": req["gold"]})
	stage = new_stage
	sprite.texture = textures.get(texture_key)
	evolved.emit(stage)


# ── Placeable buildings ──────────────────────────────────────

func can_place(building_key: String) -> bool:
	var info: Dictionary = GameConfig.BUILDINGS.get(building_key, {})
	if info.is_empty():
		return false
	if not is_unlocked(building_key):
		return false
	return ResourceManager.can_afford(info["cost"])


func try_place(building_key: String) -> bool:
	if not can_place(building_key):
		return false
	var info: Dictionary = GameConfig.BUILDINGS[building_key]
	ResourceManager.spend(info["cost"])
	placed[building_key] = placed.get(building_key, 0) + 1
	if building_key == "healing_hut":
		healing_hut_count += 1
	building_placed.emit(building_key)
	return true


func register_building(bld_data: Dictionary) -> void:
	if not bld_data.has("level"):
		bld_data["level"] = 1
	if not bld_data.has("base_max_hp"):
		bld_data["base_max_hp"] = int(bld_data.get("max_hp", 1))
	if not bld_data.has("base_scale"):
		var spr: Sprite2D = bld_data.get("sprite")
		bld_data["base_scale"] = spr.scale if spr else Vector2.ONE
	buildings.append(bld_data)
	_apply_building_level_visual(bld_data)


func get_building_max_level_allowed() -> int:
	return int(GameConfig.BUILDING_LEVEL_CAP_BY_STAGE.get(stage, 1))


func get_building_level(bld_data: Dictionary) -> int:
	return maxi(1, int(bld_data.get("level", 1)))


func get_building_upgrade_cost(bld_data: Dictionary) -> Dictionary:
	var key := String(bld_data.get("key", ""))
	var info: Dictionary = GameConfig.BUILDINGS.get(key, {})
	if info.is_empty():
		return {"wood": 0, "stone": 0, "gold": 0}
	var base: Dictionary = info.get("cost", {"wood": 0, "stone": 0, "gold": 0})
	var target_level := get_building_level(bld_data) + 1
	var factor := 1.0 + GameConfig.BUILDING_UPGRADE_COST_SCALE * float(target_level - 1)
	return {
		"wood": maxi(0, int(round(float(base.get("wood", 0)) * factor))),
		"stone": maxi(0, int(round(float(base.get("stone", 0)) * factor))),
		"gold": maxi(0, int(round(float(base.get("gold", 0)) * factor))),
	}


func can_upgrade_building(bld_data: Dictionary) -> bool:
	if not (bld_data is Dictionary):
		return false
	if int(bld_data.get("hp", 0)) <= 0:
		return false
	var level := get_building_level(bld_data)
	if level >= get_building_max_level_allowed():
		return false
	var cost := get_building_upgrade_cost(bld_data)
	return ResourceManager.can_afford(cost)


func try_upgrade_building(bld_data: Dictionary) -> bool:
	if not can_upgrade_building(bld_data):
		return false
	var cost := get_building_upgrade_cost(bld_data)
	ResourceManager.spend(cost)
	var old_level := get_building_level(bld_data)
	var new_level := old_level + 1
	bld_data["level"] = new_level
	var base_max_hp := int(bld_data.get("base_max_hp", bld_data.get("max_hp", 1)))
	bld_data["base_max_hp"] = base_max_hp
	var old_max_hp := maxi(1, int(bld_data.get("max_hp", base_max_hp)))
	var hp_ratio := clampf(float(int(bld_data.get("hp", old_max_hp))) / float(old_max_hp), 0.0, 1.0)
	var new_max_hp := maxi(1, int(round(float(base_max_hp) * (1.0 + GameConfig.BUILDING_UPGRADE_HP_PER_LEVEL * float(new_level - 1)))))
	bld_data["max_hp"] = new_max_hp
	bld_data["hp"] = clampi(int(round(float(new_max_hp) * hp_ratio)), 1, new_max_hp)
	_apply_building_level_visual(bld_data)
	_update_bld_hp_bar(bld_data)
	return true


func _apply_building_level_visual(bld_data: Dictionary) -> void:
	var spr: Sprite2D = bld_data.get("sprite")
	if not spr or not is_instance_valid(spr):
		return
	var level := get_building_level(bld_data)
	var base_scale: Vector2 = bld_data.get("base_scale", Vector2.ONE)
	var mult := 1.0 + float(level - 1) * GameConfig.BUILDING_VISUAL_SCALE_PER_LEVEL
	spr.scale = base_scale * mult


func _sum_extra_levels_for_key(building_key: String) -> int:
	var total := 0
	for bld in buildings:
		if not (bld is Dictionary):
			continue
		var bd: Dictionary = bld as Dictionary
		if String(bd.get("key", "")) != building_key:
			continue
		if int(bd.get("hp", 0)) <= 0:
			continue
		total += maxi(0, get_building_level(bd) - 1)
	return total


func get_role_gather_speed_mult(role_key: int) -> float:
	if role_key == GameConfig.Role.LUMBERJACK:
		var extra := _sum_extra_levels_for_key("carpentry")
		return 1.0 + float(extra) * GameConfig.BUILDING_SUPPORT_BONUS_PER_LEVEL
	if role_key == GameConfig.Role.MINER:
		var extra := _sum_extra_levels_for_key("mining_house") + _sum_extra_levels_for_key("mine")
		return 1.0 + float(extra) * GameConfig.BUILDING_SUPPORT_BONUS_PER_LEVEL
	return 1.0


func get_defender_damage_mult() -> float:
	var extra := _sum_extra_levels_for_key("army_base") + _sum_extra_levels_for_key("training_grounds")
	return 1.0 + float(extra) * GameConfig.BUILDING_DEFENSE_DAMAGE_PER_LEVEL


func get_defender_hp_mult() -> float:
	var extra := _sum_extra_levels_for_key("training_grounds")
	return 1.0 + float(extra) * GameConfig.BUILDING_SUPPORT_BONUS_PER_LEVEL


func get_tower_damage_mult() -> float:
	var extra := _sum_extra_levels_for_key("watch_tower")
	return 1.0 + float(extra) * GameConfig.BUILDING_DEFENSE_DAMAGE_PER_LEVEL


func get_tower_cooldown_mult() -> float:
	var extra := _sum_extra_levels_for_key("watch_tower")
	return maxf(0.45, 1.0 - float(extra) * GameConfig.BUILDING_DEFENSE_COOLDOWN_REDUCTION_PER_LEVEL)


func get_trap_damage_mult() -> float:
	var extra := _sum_extra_levels_for_key("trap")
	return 1.0 + float(extra) * GameConfig.BUILDING_DEFENSE_DAMAGE_PER_LEVEL


func get_trap_cooldown_mult() -> float:
	var extra := _sum_extra_levels_for_key("trap")
	return maxf(0.45, 1.0 - float(extra) * GameConfig.BUILDING_DEFENSE_COOLDOWN_REDUCTION_PER_LEVEL)


func get_ballista_damage_mult() -> float:
	var extra := _sum_extra_levels_for_key("ballista_tower")
	return 1.0 + float(extra) * GameConfig.BUILDING_DEFENSE_DAMAGE_PER_LEVEL


func get_ballista_cooldown_mult() -> float:
	var extra := _sum_extra_levels_for_key("ballista_tower")
	return maxf(0.45, 1.0 - float(extra) * GameConfig.BUILDING_DEFENSE_COOLDOWN_REDUCTION_PER_LEVEL)


func has_armory() -> bool:
	return get_placed_count("armory") > 0


func get_placed_count(building_key: String) -> int:
	return int(placed.get(building_key, 0))


func has_healing_hut() -> bool:
	return healing_hut_count > 0


func is_unlocked(building_key: String) -> bool:
	var info: Dictionary = GameConfig.BUILDINGS.get(building_key, {})
	var min_stage: int = int(info.get("min_stage", 0))
	if stage >= min_stage:
		return true
	if GameConfig.BUILDING_TECH_REQUIREMENTS.has(building_key):
		var tech_key: String = String(GameConfig.BUILDING_TECH_REQUIREMENTS[building_key])
		return ResourceManager.has_technology(tech_key)
	return false


func get_buildings() -> Array:
	return buildings


func damage_building(bld_data: Dictionary, dmg: int) -> void:
	bld_data["hp"] = maxi(int(bld_data["hp"]) - dmg, 0)
	_update_bld_hp_bar(bld_data)
	# Flash red
	var spr: Sprite2D = bld_data["sprite"]
	if spr and is_instance_valid(spr):
		spr.modulate = Color(1.0, 0.3, 0.3)
		var tween := spr.create_tween()
		tween.tween_property(spr, "modulate", Color.WHITE, 0.2)
	if int(bld_data["hp"]) <= 0:
		_destroy_building(bld_data)


func _destroy_building(bld_data: Dictionary) -> void:
	var key: String = bld_data["key"]
	placed[key] = maxi(int(placed.get(key, 0)) - 1, 0)
	if key == "healing_hut":
		healing_hut_count = maxi(healing_hut_count - 1, 0)
	# Remove sprite and HP bars
	var spr: Sprite2D = bld_data["sprite"]
	if spr and is_instance_valid(spr):
		spr.queue_free()
	var bg: ColorRect = bld_data.get("hp_bar_bg")
	if bg and is_instance_valid(bg):
		bg.queue_free()
	var fill: ColorRect = bld_data.get("hp_bar_fill")
	if fill and is_instance_valid(fill):
		fill.queue_free()
	buildings.erase(bld_data)
	building_destroyed.emit(key, bld_data)


func _update_bld_hp_bar(bld_data: Dictionary) -> void:
	var fill: ColorRect = bld_data.get("hp_bar_fill")
	if not fill or not is_instance_valid(fill):
		return
	var max_hp := int(bld_data["max_hp"])
	if max_hp <= 0:
		return
	var ratio := clampf(float(bld_data["hp"]) / float(max_hp), 0.0, 1.0)
	fill.size.x = 28.0 * ratio
	if ratio > 0.5:
		fill.color = Color(0.35, 0.75, 0.30)
	elif ratio > 0.25:
		fill.color = Color(0.90, 0.65, 0.15)
	else:
		fill.color = Color(0.85, 0.22, 0.18)


# ── Info helpers ─────────────────────────────────────────────

func get_stage() -> int:
	return stage


func get_stage_name() -> String:
	match stage:
		GameConfig.BuildingStage.TENT: return "Tent"
		GameConfig.BuildingStage.WOODEN_CABIN: return "Wooden Cabin"
		GameConfig.BuildingStage.STONE_HALL: return "Stone Town Hall"
	return "Unknown"


func get_next_requirements() -> Variant:
	match stage:
		GameConfig.BuildingStage.TENT:
			return GameConfig.EVOLUTION["wooden_cabin"]
		GameConfig.BuildingStage.WOODEN_CABIN:
			return GameConfig.EVOLUTION["stone_hall"]
	return null
