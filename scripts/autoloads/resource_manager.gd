# ============================================================
# Resource Manager — Tracks Wood, Stone, Gold
# Autoloaded as "ResourceManager"
# ============================================================
extends Node

signal resources_changed(resources: Dictionary)
signal tool_upgraded(tool_type: String, level: int)
signal resource_added(type: String, amount: int)
signal research_changed(points: int)
signal tech_researched(tech_key: String)

var resources := { "wood": 30, "stone": 25, "gold": 5 }
var research_points: int = 0
var researched_techs: Dictionary = {}
var sword_upgrade_unlocked: bool = false

# Tool upgrade levels (0-based index into GameConfig.TOOL_UPGRADES)
var tool_levels := { "axe": 0, "pickaxe": 0, "sword": 0 }

# Per-minute rate tracking
var _rate_window := 60.0  # seconds
var _rate_history: Dictionary = { "wood": [], "stone": [], "gold": [] }  # Array of [timestamp, amount]


func _process(_delta: float) -> void:
	# Prune old entries beyond the rate window
	var now := Time.get_ticks_msec() / 1000.0
	var cutoff := now - _rate_window
	for type: String in _rate_history:
		var arr: Array = _rate_history[type]
		while arr.size() > 0:
			var entry: Array = arr[0]
			if float(entry[0]) < cutoff:
				arr.pop_front()
			else:
				break


func get_rate(type: String) -> float:
	## Returns resources gathered per minute for the given type
	var arr: Array = _rate_history.get(type, [])
	var total := 0.0
	for entry: Array in arr:
		total += float(entry[1])
	return total  # Already per 60s window = per minute


func reset_state() -> void:
	resources["wood"] = 30
	resources["stone"] = 25
	resources["gold"] = 5
	research_points = 0
	researched_techs.clear()
	tool_levels = { "axe": 0, "pickaxe": 0, "sword": 0 }
	sword_upgrade_unlocked = false
	_rate_history = { "wood": [], "stone": [], "gold": [] }
	resources_changed.emit(resources)
	research_changed.emit(research_points)


func add_resource(type: String, amount: int) -> void:
	if type not in resources:
		return
	resources[type] += amount
	var now := Time.get_ticks_msec() / 1000.0
	_rate_history[type].append([now, amount])
	resource_added.emit(type, amount)
	resources_changed.emit(resources)


func spend(costs: Dictionary) -> bool:
	for type in costs:
		if resources.get(type, 0) < costs[type]:
			return false
	for type in costs:
		resources[type] -= costs[type]
	resources_changed.emit(resources)
	return true


func can_afford(costs: Dictionary) -> bool:
	for type in costs:
		if resources.get(type, 0) < costs[type]:
			return false
	return true


func get_resource(type: String) -> int:
	return resources.get(type, 0)


func get_all() -> Dictionary:
	var out := resources.duplicate()
	out["research"] = research_points
	return out


func add_research(amount: int) -> void:
	if amount <= 0:
		return
	research_points += amount
	research_changed.emit(research_points)


func get_research_points() -> int:
	return research_points


func has_technology(tech_key: String) -> bool:
	return bool(researched_techs.get(tech_key, false))


func get_researched_techs() -> Dictionary:
	return researched_techs.duplicate()


func can_research_technology(tech_key: String) -> bool:
	if has_technology(tech_key):
		return false
	if not GameConfig.TECHNOLOGIES.has(tech_key):
		return false
	var info: Dictionary = GameConfig.TECHNOLOGIES[tech_key]
	var req_cost: int = int(info.get("cost", 0))
	if research_points < req_cost:
		return false
	var prereq: Array = info.get("requires", [])
	for pre: String in prereq:
		if not has_technology(pre):
			return false
	return true


func research_technology(tech_key: String) -> bool:
	if not can_research_technology(tech_key):
		return false
	var info: Dictionary = GameConfig.TECHNOLOGIES[tech_key]
	var req_cost: int = int(info.get("cost", 0))
	research_points -= req_cost
	researched_techs[tech_key] = true
	research_changed.emit(research_points)
	tech_researched.emit(tech_key)
	return true


# ── Tool Upgrades ────────────────────────────────────────────

func get_tool_level(tool_type: String) -> int:
	return tool_levels.get(tool_type, 0)


func get_tool_info(tool_type: String) -> Dictionary:
	var lvl := get_tool_level(tool_type)
	var upgrades: Array = GameConfig.TOOL_UPGRADES[tool_type]
	var info: Dictionary = upgrades[lvl]
	return info


func get_next_tool_info(tool_type: String) -> Dictionary:
	var lvl := get_tool_level(tool_type)
	var upgrades: Array = GameConfig.TOOL_UPGRADES[tool_type]
	if lvl + 1 >= upgrades.size():
		return {}
	var info: Dictionary = upgrades[lvl + 1]
	return info


func try_upgrade_tool(tool_type: String) -> bool:
	if tool_type == "sword" and not sword_upgrade_unlocked:
		return false
	var next: Dictionary = get_next_tool_info(tool_type)
	if next.is_empty():
		return false
	if not can_afford(next["cost"]):
		return false
	spend(next["cost"])
	tool_levels[tool_type] += 1
	tool_upgraded.emit(tool_type, tool_levels[tool_type])
	return true


func set_sword_upgrade_unlocked(unlocked: bool) -> void:
	sword_upgrade_unlocked = unlocked


func get_gather_speed_mult(tool_type: String) -> float:
	var info: Dictionary = get_tool_info(tool_type)
	return info.get("speed_mult", 1.0)


func get_yield_bonus(tool_type: String) -> int:
	var info: Dictionary = get_tool_info(tool_type)
	return info.get("yield_bonus", 0)


func get_attack_dmg_mult() -> float:
	var info: Dictionary = get_tool_info("sword")
	return info.get("dmg_mult", 1.0)


func get_attack_cd_mult() -> float:
	var info: Dictionary = get_tool_info("sword")
	return info.get("cd_mult", 1.0)
