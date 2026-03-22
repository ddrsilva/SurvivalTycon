# ============================================================
# Global Task Manager — Tracks villager roles (read-only stats)
# Roles are assigned when buildings are placed, not manually.
# Autoloaded as "TaskManager"
# ============================================================
extends Node

signal allocation_changed(allocation: Dictionary)

var villagers: Array = []


func reset_state() -> void:
	villagers.clear()
	allocation_changed.emit(get_allocation())


func add_villager(villager) -> void:
	_prune_invalid_villagers()
	villagers.append(villager)
	allocation_changed.emit(get_allocation())


func remove_villager(villager) -> void:
	_prune_invalid_villagers()
	villagers.erase(villager)
	allocation_changed.emit(get_allocation())


## Return percentage breakdown of current roles (computed from actual villager roles).
func get_allocation() -> Dictionary:
	var counts := get_role_counts()
	var total := 0
	for role_key: int in counts:
		total += int(counts[role_key])
	var alloc := {}
	for role_key: int in counts:
		if total > 0:
			alloc[role_key] = roundi(float(counts[role_key]) / total * 100)
		else:
			alloc[role_key] = 0
	return alloc


## Get count of villagers per role
func get_role_counts() -> Dictionary:
	_prune_invalid_villagers()
	var counts := {
		GameConfig.Role.IDLE: 0,
		GameConfig.Role.LUMBERJACK: 0,
		GameConfig.Role.MINER: 0,
		GameConfig.Role.DEFENDER: 0,
		GameConfig.Role.BUILDER: 0,
		GameConfig.Role.SCHOLAR: 0,
		GameConfig.Role.FORESTER: 0,
	}
	for v in villagers:
		if v and is_instance_valid(v):
			counts[v.role] = counts.get(v.role, 0) + 1
	return counts


## Assign a batch of idle villagers to a specific role (called when building placed).
func assign_idle_to_role(target_role: int, count: int) -> int:
	_prune_invalid_villagers()
	var assigned := 0
	for v in villagers:
		if assigned >= count:
			break
		if v and is_instance_valid(v) and v.role == GameConfig.Role.IDLE:
			if v.has_method("set_role"):
				v.set_role(target_role)
			assigned += 1
	allocation_changed.emit(get_allocation())
	return assigned


func _prune_invalid_villagers() -> void:
	var alive := []
	for v in villagers:
		if v and is_instance_valid(v):
			alive.append(v)
	villagers = alive


## Kept for backward compatibility — does nothing now (roles are read-only).
func adjust_role(_role: int, _delta: int) -> void:
	pass
