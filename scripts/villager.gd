# ============================================================
# Villager AI — Finite State Machine
# States: Idle → MovingToResource → Gathering → Returning
#         Idle → Patrolling → Attacking
# Features: Health, perimeter patrol, cabin-priority targeting
# ============================================================
extends Node2D

signal villager_died(villager: Node2D)

var state: int = GameConfig.VillagerState.IDLE
var role: int = GameConfig.Role.IDLE
var speed: float = GameConfig.VILLAGER_SPEED

# Health
var hp: int = GameConfig.VILLAGER_MAX_HP
var max_hp: int = GameConfig.VILLAGER_MAX_HP
var expertise_xp: Dictionary = {}  # role(int) -> xp(float)

# References (set by game scene after instantiation)
var map_state: Dictionary
var tilemap: TileMap
var threat_group: Node2D

# Movement
var target_tile := Vector2i.ZERO
var target_world := Vector2.ZERO

# Gathering
var gather_timer := 0.0
var carry_type := ""  # "wood", "stone", "gold"
var carry_amount := 0

# Patrol / Defend
var patrol_angle := randf() * TAU
var patrol_target := Vector2.ZERO
var attack_target: Node2D = null
var attack_cooldown := 0.0
var safe_zone_radius := GameConfig.CLEAR_RADIUS  # updated on evolution

# Home position (set after creation)
var home_position := Vector2.ZERO

# Healing hut support
var building_manager_ref  # set by game scene
var heal_timer := 0.0
var builder_tick := 0.0
var scholar_tick := 0.0
var forester_tick := 0.0

# Sprite reference
var sprite: Sprite2D
var shadow: ColorRect

# HP bar
var hp_bar_bg: ColorRect
var hp_bar: ColorRect

# Tree nodes reference (set by game scene)
var tree_nodes: Dictionary

# Smooth movement
var was_moving := false

# Textures (set by game scene)
var tex_lumberjack: ImageTexture
var tex_miner: ImageTexture
var tex_defender: ImageTexture
var tex_forester: ImageTexture

# External sprite animation pack
var use_external_anim := false
const RUN_ANIM_NAME := "running-4-frames"
const RUN_FPS := 10.0
const ACTION_FPS := 8.0

static var PACK_CACHE: Dictionary = {}
static var claimed_tiles: Dictionary = {}  # Vector2i -> villager ref

var idle_frames: Dictionary = {}
var run_frames: Dictionary = {}
var action_frames: Dictionary = {}
var facing_dir := "south"
var anim_timer := 0.0
var anim_frame_idx := 0
var current_anim := "idle"
var is_hiding_in_cabin: bool = false
var hide_requested: bool = false


func _ready() -> void:
	sprite = $Sprite2D
	_load_external_animation_pack_for_role(role)
	_update_texture()
	_create_shadow()
	_create_hp_bar()
	_apply_role_stat_scaling(false)


func set_role(new_role: int) -> void:
	if role == new_role:
		return
	role = new_role
	_load_external_animation_pack_for_role(role)
	_update_texture()
	_apply_role_stat_scaling(true)
	_reset_state()


func _update_texture() -> void:
	if not sprite:
		return
	if use_external_anim:
		_apply_idle_frame()
		return
	match role:
		GameConfig.Role.IDLE:
			if tex_lumberjack:
				sprite.texture = tex_lumberjack
		GameConfig.Role.LUMBERJACK:
			if tex_lumberjack:
				sprite.texture = tex_lumberjack
		GameConfig.Role.MINER:
			if tex_miner:
				sprite.texture = tex_miner
		GameConfig.Role.DEFENDER:
			if tex_defender:
				sprite.texture = tex_defender
		GameConfig.Role.BUILDER:
			if tex_miner:
				sprite.texture = tex_miner
		GameConfig.Role.SCHOLAR:
			if tex_lumberjack:
				sprite.texture = tex_lumberjack
		GameConfig.Role.FORESTER:
			if tex_forester:
				sprite.texture = tex_forester
			elif tex_lumberjack:
				sprite.texture = tex_lumberjack


func _release_claim() -> void:
	if target_tile != Vector2i.ZERO and claimed_tiles.get(target_tile) == self:
		claimed_tiles.erase(target_tile)


func _reset_state() -> void:
	_release_claim()
	state = GameConfig.VillagerState.IDLE
	target_tile = Vector2i.ZERO
	target_world = Vector2.ZERO
	gather_timer = 0.0
	carry_type = ""
	carry_amount = 0
	attack_target = null
	rotation = 0.0
	if use_external_anim:
		current_anim = "idle"
		anim_frame_idx = 0
		anim_timer = 0.0
		_apply_idle_frame()


func _process(delta: float) -> void:
	if hide_requested and not is_hiding_in_cabin:
		if _move_toward(home_position, delta):
			is_hiding_in_cabin = true
			state = GameConfig.VillagerState.IDLE
			if sprite:
				sprite.visible = false
			if shadow:
				shadow.visible = false
			if hp_bar_bg:
				hp_bar_bg.visible = false
			if hp_bar:
				hp_bar.visible = false
		return

	if is_hiding_in_cabin:
		global_position = home_position
		return

	# Check if we need healing (any role, any non-healing state)
	if state != GameConfig.VillagerState.MOVING_TO_HEAL and state != GameConfig.VillagerState.HEALING:
		if _should_seek_healing():
			state = GameConfig.VillagerState.MOVING_TO_HEAL
			target_world = home_position
			return

	match state:
		GameConfig.VillagerState.IDLE:
			_on_idle(delta)
		GameConfig.VillagerState.MOVING_TO_RESOURCE:
			_on_moving_to_resource(delta)
		GameConfig.VillagerState.GATHERING:
			_on_gathering(delta)
		GameConfig.VillagerState.RETURNING:
			_on_returning(delta)
		GameConfig.VillagerState.PATROLLING:
			_on_patrolling(delta)
		GameConfig.VillagerState.ATTACKING:
			_on_attacking(delta)
		GameConfig.VillagerState.FELLING:
			_on_felling(delta)
		GameConfig.VillagerState.COLLECTING_LOGS:
			_on_collecting_logs(delta)
		GameConfig.VillagerState.MOVING_TO_HEAL:
			_on_moving_to_heal(delta)
		GameConfig.VillagerState.HEALING:
			_on_healing(delta)


# ── STATE: Idle ──────────────────────────────────────────────

func _on_idle(_delta: float) -> void:
	if role == GameConfig.Role.IDLE:
		# Wander randomly near home
		if patrol_target == Vector2.ZERO or global_position.distance_to(patrol_target) < 4.0:
			patrol_target = home_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		_move_toward(patrol_target, _delta)
		return

	if role == GameConfig.Role.BUILDER:
		_builder_behavior(_delta)
		return

	if role == GameConfig.Role.SCHOLAR:
		_scholar_behavior(_delta)
		return

	if role == GameConfig.Role.FORESTER:
		_forester_behavior(_delta)
		return

	if role == GameConfig.Role.LUMBERJACK or role == GameConfig.Role.MINER:
		var target := _find_nearest_resource()
		if target != Vector2i(-1, -1):
			target_tile = target
			claimed_tiles[target] = self
			target_world = Vector2(
				target.x * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0,
				target.y * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0
			)
			state = GameConfig.VillagerState.MOVING_TO_RESOURCE
	elif role == GameConfig.Role.DEFENDER:
		_pick_patrol_point()
		state = GameConfig.VillagerState.PATROLLING


# ── STATE: Moving to resource ────────────────────────────────

func _on_moving_to_resource(delta: float) -> void:
	# Check if resource tile still exists
	var tile_type: int = map_state["resource_data"][target_tile.y][target_tile.x]
	if tile_type < 0:
		_release_claim()
		state = GameConfig.VillagerState.IDLE
		return

	if _move_toward(target_world, delta):
		if tile_type == GameConfig.TileType.LOG_PILE:
			# Log pile: skip straight to collecting
			state = GameConfig.VillagerState.COLLECTING_LOGS
			gather_timer = 0.0
		else:
			state = GameConfig.VillagerState.GATHERING
			gather_timer = 0.0
			# Start chopping animation on the tree node
			if tile_type == GameConfig.TileType.TREE_PINE or tile_type == GameConfig.TileType.TREE_OAK:
				var tree_node = _get_tree_at_tile(target_tile)
				if tree_node:
					tree_node.start_chopping()


# ── STATE: Gathering ─────────────────────────────────────────

func _on_gathering(delta: float) -> void:
	gather_timer += delta

	var tile_type: int = map_state["resource_data"][target_tile.y][target_tile.x]
	var is_tree := tile_type == GameConfig.TileType.TREE_PINE or tile_type == GameConfig.TileType.TREE_OAK
	if use_external_anim:
		if role == GameConfig.Role.LUMBERJACK and is_tree:
			_play_action_anim(delta, target_world - global_position)
		elif role == GameConfig.Role.MINER and not is_tree:
			_play_action_anim(delta, target_world - global_position)

	if not is_tree:
		# Rock/ore: oscillation animation
		rotation = sin(gather_timer * 6.0) * 0.18

	if gather_timer >= GameConfig.GATHER_TIME / _get_gather_speed_mult():
		rotation = 0.0

		if is_tree:
			# Tree: start falling animation if TreeResource exists, else fallback to legacy tile gather
			var tree_node = _get_tree_at_tile(target_tile)
			if tree_node:
				tree_node.start_falling()
				state = GameConfig.VillagerState.FELLING
				gather_timer = 0.0
			else:
				carry_type = "wood"
				carry_amount = GameConfig.WOOD_PER_CHOP + ResourceManager.get_yield_bonus("axe")
				_gain_expertise(GameConfig.Role.LUMBERJACK, GameConfig.EXPERTISE_GATHER_XP)
				map_state["resource_data"][target_tile.y][target_tile.x] = -1
				tilemap.erase_cell(1, target_tile)
				_spawn_gather_particles()
				state = GameConfig.VillagerState.RETURNING
		else:
			# Rock/ore: deplete and return (original behavior)
			if tile_type == GameConfig.TileType.ROCK:
				carry_type = "stone"
				carry_amount = GameConfig.STONE_PER_MINE + ResourceManager.get_yield_bonus("pickaxe")
			elif tile_type == GameConfig.TileType.ORE:
				carry_type = "gold"
				carry_amount = GameConfig.GOLD_PER_MINE + ResourceManager.get_yield_bonus("pickaxe")
			else:
				state = GameConfig.VillagerState.IDLE
				return
			_gain_expertise(GameConfig.Role.MINER, GameConfig.EXPERTISE_GATHER_XP)

			map_state["resource_data"][target_tile.y][target_tile.x] = -1
			tilemap.erase_cell(1, target_tile)
			_spawn_gather_particles()
			state = GameConfig.VillagerState.RETURNING


# ── STATE: Felling (waiting for fall animation) ──────────────

func _on_felling(delta: float) -> void:
	gather_timer += delta
	var tree_node = _get_tree_at_tile(target_tile)
	if (tree_node and tree_node.is_fell_complete()) or gather_timer > 3.0:
		# Tree has fallen
		_spawn_dust_particles()
		var game_node = get_tree().current_scene
		if game_node and game_node.has_method("apply_shake"):
			game_node.apply_shake(3.0)
		# Mark tile as log pile
		map_state["resource_data"][target_tile.y][target_tile.x] = GameConfig.TileType.LOG_PILE
		state = GameConfig.VillagerState.COLLECTING_LOGS
		gather_timer = 0.0


# ── STATE: Collecting logs ───────────────────────────────────

func _on_collecting_logs(delta: float) -> void:
	gather_timer += delta
	if use_external_anim and role == GameConfig.Role.LUMBERJACK:
		_play_action_anim(delta, target_world - global_position)
	rotation = sin(gather_timer * 4.0) * 0.1

	if gather_timer >= GameConfig.LOG_COLLECT_TIME:
		rotation = 0.0
		carry_type = "wood"
		carry_amount = GameConfig.WOOD_PER_CHOP + ResourceManager.get_yield_bonus("axe")
		_gain_expertise(GameConfig.Role.LUMBERJACK, GameConfig.EXPERTISE_GATHER_XP)
		# Remove log pile, leave stump
		map_state["resource_data"][target_tile.y][target_tile.x] = -1
		var tree_node = _get_tree_at_tile(target_tile)
		if tree_node:
			tree_node.collect_logs()
		_spawn_gather_particles()
		state = GameConfig.VillagerState.RETURNING


# ── STATE: Moving to heal ────────────────────────────────────

func _on_moving_to_heal(delta: float) -> void:
	if _move_toward(home_position, delta):
		state = GameConfig.VillagerState.HEALING
		heal_timer = 0.0


# ── STATE: Healing ───────────────────────────────────────────

func _on_healing(delta: float) -> void:
	heal_timer += delta
	hp = mini(hp + int(GameConfig.HEAL_RATE * delta), max_hp)
	_update_hp_bar()
	if hp >= max_hp:
		state = GameConfig.VillagerState.IDLE


# ── Heal check ───────────────────────────────────────────────

func _should_seek_healing() -> bool:
	if hp >= int(float(max_hp) * GameConfig.HEAL_SEEK_HP):
		return false
	if building_manager_ref and building_manager_ref.has_healing_hut():
		return true
	return false


# ── STATE: Returning to chest ────────────────────────────────

func _on_returning(delta: float) -> void:
	_release_claim()
	if _move_toward(home_position, delta):
		if carry_type != "" and carry_amount > 0:
			ResourceManager.add_resource(carry_type, carry_amount)
		carry_type = ""
		carry_amount = 0
		state = GameConfig.VillagerState.IDLE


# ── STATE: Patrolling ────────────────────────────────────────

func _on_patrolling(delta: float) -> void:
	# Check for nearby threats — prioritize closest to cabin
	var threat := _find_closest_threat_to_cabin()
	if threat:
		attack_target = threat
		state = GameConfig.VillagerState.ATTACKING
		return

	if patrol_target == Vector2.ZERO:
		_pick_patrol_point()

	if _move_toward(patrol_target, delta):
		_pick_patrol_point()


# ── STATE: Attacking ─────────────────────────────────────────

func _on_attacking(delta: float) -> void:
	# Drop target if it left the safe zone
	if is_instance_valid(attack_target):
		var defend_radius := float(safe_zone_radius + 3) * GameConfig.TILE_SIZE
		if home_position.distance_to(attack_target.global_position) > defend_radius:
			attack_target = null
			state = GameConfig.VillagerState.PATROLLING
			return

	# Keep reprioritizing so defenders always peel for the threat nearest to cabin.
	var priority_target := _find_closest_threat_to_cabin()
	if is_instance_valid(priority_target) and priority_target != attack_target:
		if not is_instance_valid(attack_target):
			attack_target = priority_target
		else:
			var current_cabin_dist := home_position.distance_to(attack_target.global_position)
			var priority_cabin_dist := home_position.distance_to(priority_target.global_position)
			if priority_cabin_dist + GameConfig.TILE_SIZE < current_cabin_dist:
				attack_target = priority_target

	if not is_instance_valid(attack_target):
		attack_target = null
		state = GameConfig.VillagerState.PATROLLING
		return

	var dist := global_position.distance_to(attack_target.global_position)

	if dist > GameConfig.ATTACK_RANGE:
		_move_toward(attack_target.global_position, delta)
	else:
		if use_external_anim and role == GameConfig.Role.DEFENDER:
			_play_action_anim(delta, attack_target.global_position - global_position)
		attack_cooldown -= delta
		if attack_cooldown <= 0.0:
			# Pass our position for knockback direction
			var dmg_mult := ResourceManager.get_attack_dmg_mult()
			if building_manager_ref:
				dmg_mult *= building_manager_ref.get_defender_damage_mult()
			var dmg := int(GameConfig.ATTACK_DAMAGE * dmg_mult)
			if attack_target.has_method("take_damage"):
				attack_target.take_damage(dmg, global_position)
				_gain_expertise(GameConfig.Role.DEFENDER, GameConfig.EXPERTISE_DEFENDER_HIT_XP)
			attack_cooldown = GameConfig.ATTACK_COOLDOWN * ResourceManager.get_attack_cd_mult()
			# Attack flash
			sprite.modulate = Color(1.0, 0.3, 0.3)
			var tween := create_tween()
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
			# Sword swipe particle
			_spawn_sword_swipe()


# ── Helpers ──────────────────────────────────────────────────

func _move_toward(target: Vector2, delta: float) -> bool:
	var diff := target - global_position
	var dist := diff.length()
	var step := speed * delta

	if dist <= step:
		global_position = target
		if use_external_anim:
			current_anim = "idle"
			anim_timer = 0.0
			anim_frame_idx = 0
			_apply_idle_frame()
		# Squash & stretch on stop
		if was_moving and sprite:
			was_moving = false
			var tween := create_tween()
			tween.tween_property(sprite, "scale", Vector2(1.8, 1.2), 0.06)
			tween.tween_property(sprite, "scale", Vector2(1.4, 1.6), 0.06)
			tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.05)
		return true

	# Smooth interpolated movement (lerp blend for organic feel)
	var lerp_speed := 8.0
	var lerp_pos := global_position.lerp(target, lerp_speed * delta / max(dist, 1.0))
	# Ensure we move at least step distance so we don't get stuck
	var lerp_diff := lerp_pos - global_position
	if lerp_diff.length() < step:
		global_position += diff.normalized() * step
	else:
		global_position = lerp_pos

	was_moving = true
	if use_external_anim:
		_play_run_anim(delta, diff)

	# Face direction
	if sprite and not use_external_anim:
		sprite.flip_h = diff.x < 0

	return false


func _find_nearest_resource() -> Vector2i:
	var my_tile := Vector2i(
		int(global_position.x / GameConfig.TILE_SIZE),
		int(global_position.y / GameConfig.TILE_SIZE)
	)
	var best := Vector2i(-1, -1)
	var best_dist := 999999.0

	var valid_types: Array
	if role == GameConfig.Role.LUMBERJACK:
		valid_types = [GameConfig.TileType.TREE_PINE, GameConfig.TileType.TREE_OAK, GameConfig.TileType.LOG_PILE]
	else:
		valid_types = [GameConfig.TileType.ROCK, GameConfig.TileType.ORE]

	# Search outward in rings
	for r in range(1, 31):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue  # ring perimeter only
				var tx := my_tile.x + dx
				var ty := my_tile.y + dy
				if tx < 0 or ty < 0 or tx >= GameConfig.MAP_WIDTH or ty >= GameConfig.MAP_HEIGHT:
					continue
				var tile_type: int = map_state["resource_data"][ty][tx]
				if tile_type in valid_types:
					var tile_pos := Vector2i(tx, ty)
					# Skip tiles already claimed by another villager
					if claimed_tiles.has(tile_pos) and claimed_tiles[tile_pos] != self:
						var claimer = claimed_tiles[tile_pos]
						if is_instance_valid(claimer):
							continue
						else:
							claimed_tiles.erase(tile_pos)
					var d := float(dx * dx + dy * dy)
					if d < best_dist:
						best_dist = d
						best = Vector2i(tx, ty)
		if best != Vector2i(-1, -1):
			break
	return best


func _find_nearest_threat() -> Node2D:
	if not threat_group:
		return null
	var closest: Node2D = null
	var closest_dist := GameConfig.ATTACK_RANGE * 3.0

	for threat in threat_group.get_children():
		if not is_instance_valid(threat):
			continue
		var d := global_position.distance_to(threat.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = threat
	return closest


## Prioritize threats closest to the cabin, but ONLY within safe zone radius + buffer
func _find_closest_threat_to_cabin() -> Node2D:
	if not threat_group:
		return null
	var best: Node2D = null
	var best_cabin_dist := 999999.0
	var defend_radius := float(safe_zone_radius + 2) * GameConfig.TILE_SIZE

	for threat in threat_group.get_children():
		if not is_instance_valid(threat):
			continue
		var d_to_cabin := home_position.distance_to(threat.global_position)
		# Only engage threats that have entered the safe zone perimeter
		if d_to_cabin > defend_radius:
			continue
		if d_to_cabin < best_cabin_dist:
			best_cabin_dist = d_to_cabin
			best = threat
	return best


func _pick_patrol_point() -> void:
	# Walk the perimeter of the safe zone (dirt/grass boundary)
	patrol_angle += 0.4 + randf() * 1.0
	var r := float(safe_zone_radius) * GameConfig.TILE_SIZE
	patrol_target = Vector2(
		home_position.x + cos(patrol_angle) * r,
		home_position.y + sin(patrol_angle) * r
	)


func _get_gather_speed_mult() -> float:
	var expertise_mult := 1.0 + float(_get_role_expertise_level(role)) * GameConfig.EXPERTISE_GATHER_SPEED_PER_LEVEL
	if role == GameConfig.Role.LUMBERJACK:
		var support_mult := 1.0
		if building_manager_ref:
			support_mult = building_manager_ref.get_role_gather_speed_mult(GameConfig.Role.LUMBERJACK)
		return ResourceManager.get_gather_speed_mult("axe") * expertise_mult * support_mult
	elif role == GameConfig.Role.MINER:
		var base := ResourceManager.get_gather_speed_mult("pickaxe")
		if building_manager_ref and building_manager_ref.get_placed_count("mine") > 0:
			base *= GameConfig.MINE_GATHER_SPEED_BONUS
		var support_mult := 1.0
		if building_manager_ref:
			support_mult = building_manager_ref.get_role_gather_speed_mult(GameConfig.Role.MINER)
		return base * expertise_mult * support_mult
	return 1.0


func _gain_expertise(role_key: int, amount: float) -> void:
	if role_key == GameConfig.Role.IDLE or amount <= 0.0:
		return
	var prev_level := _get_role_expertise_level(role_key)
	var xp_now := float(expertise_xp.get(role_key, 0.0)) + amount
	var xp_cap := GameConfig.EXPERTISE_XP_PER_LEVEL * float(GameConfig.EXPERTISE_MAX_LEVEL)
	expertise_xp[role_key] = clampf(xp_now, 0.0, xp_cap)
	var new_level := _get_role_expertise_level(role_key)
	if role == role_key and new_level != prev_level:
		_apply_role_stat_scaling(true)


func _get_role_expertise_level(role_key: int) -> int:
	var xp := float(expertise_xp.get(role_key, 0.0))
	if GameConfig.EXPERTISE_XP_PER_LEVEL <= 0.0:
		return 0
	var lvl := int(floor(xp / GameConfig.EXPERTISE_XP_PER_LEVEL))
	return clampi(lvl, 0, GameConfig.EXPERTISE_MAX_LEVEL)


func get_expertise_data() -> Dictionary:
	var out := {}
	for role_key in expertise_xp.keys():
		out[str(role_key)] = float(expertise_xp[role_key])
	return out


func set_expertise_data(data: Dictionary) -> void:
	expertise_xp.clear()
	var xp_cap := GameConfig.EXPERTISE_XP_PER_LEVEL * float(GameConfig.EXPERTISE_MAX_LEVEL)
	for key in data.keys():
		var role_key := int(key)
		expertise_xp[role_key] = clampf(float(data[key]), 0.0, xp_cap)
	_apply_role_stat_scaling(false)


func get_role_scaled_max_hp(role_key: int) -> int:
	if role_key == GameConfig.Role.DEFENDER:
		var lvl := _get_role_expertise_level(role_key)
		var mult := 1.0 + float(lvl) * GameConfig.EXPERTISE_DEFENDER_HP_PER_LEVEL
		if building_manager_ref:
			mult *= building_manager_ref.get_defender_hp_mult()
		return maxi(1, int(round(float(GameConfig.VILLAGER_MAX_HP) * mult)))
	return GameConfig.VILLAGER_MAX_HP


func get_current_role_expertise_level() -> int:
	return _get_role_expertise_level(role)


func get_current_role_gather_bonus_pct() -> float:
	if role != GameConfig.Role.LUMBERJACK and role != GameConfig.Role.MINER:
		return 0.0
	return float(_get_role_expertise_level(role)) * GameConfig.EXPERTISE_GATHER_SPEED_PER_LEVEL * 100.0


func get_current_role_hp_bonus_pct() -> float:
	if role != GameConfig.Role.DEFENDER:
		return 0.0
	return float(_get_role_expertise_level(role)) * GameConfig.EXPERTISE_DEFENDER_HP_PER_LEVEL * 100.0


func _apply_role_stat_scaling(keep_ratio: bool = true) -> void:
	var old_max := maxi(max_hp, 1)
	var hp_ratio := clampf(float(hp) / float(old_max), 0.0, 1.0)
	max_hp = get_role_scaled_max_hp(role)
	if keep_ratio:
		hp = clampi(int(round(float(max_hp) * hp_ratio)), 1, max_hp)
	else:
		hp = clampi(hp, 1, max_hp)
	_update_hp_bar()


func _builder_behavior(delta: float) -> void:
	builder_tick += delta
	if global_position.distance_to(home_position) > 36.0:
		_move_toward(home_position, delta)
		return
	if builder_tick < 1.0:
		return
	builder_tick = 0.0

	var game_node := get_tree().current_scene
	if game_node and game_node.has_method("builder_repair_tick"):
		game_node.builder_repair_tick(home_position, 5)


func _scholar_behavior(delta: float) -> void:
	scholar_tick += delta
	if global_position.distance_to(home_position) > 40.0:
		_move_toward(home_position, delta)
		return
	var tick_time := 4.5
	if ResourceManager.has_technology("scholarship"):
		tick_time = 3.0
	if scholar_tick < tick_time:
		return
	scholar_tick = 0.0
	ResourceManager.add_research(1)


func _forester_behavior(delta: float) -> void:
	forester_tick += delta
	if global_position.distance_to(home_position) > 46.0:
		_move_toward(home_position, delta)
		return
	if forester_tick < 3.2:
		return
	forester_tick = 0.0
	var tile := _find_replant_tile()
	if tile == Vector2i(-1, -1):
		return
	var game_node := get_tree().current_scene
	if game_node and game_node.has_method("plant_tree_at_tile"):
		var tree_type := GameConfig.TileType.TREE_PINE if randf() < 0.6 else GameConfig.TileType.TREE_OAK
		game_node.plant_tree_at_tile(tile, tree_type)


func _find_replant_tile() -> Vector2i:
	var my_tile := Vector2i(
		int(global_position.x / GameConfig.TILE_SIZE),
		int(global_position.y / GameConfig.TILE_SIZE)
	)
	for r in range(3, 16):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var tx := my_tile.x + dx
				var ty := my_tile.y + dy
				if tx < 0 or ty < 0 or tx >= GameConfig.MAP_WIDTH or ty >= GameConfig.MAP_HEIGHT:
					continue
				if int(map_state["resource_data"][ty][tx]) != -1:
					continue
				if int(map_state["ground_data"][ty][tx]) != GameConfig.TileType.DIRT:
					continue
				return Vector2i(tx, ty)
	return Vector2i(-1, -1)


func _get_tree_at_tile(tile: Vector2i) -> Node2D:
	if tree_nodes.has(tile):
		var t = tree_nodes[tile]
		if is_instance_valid(t):
			return t
	return null


func _spawn_dust_particles() -> void:
	for i in range(8):
		var p := ColorRect.new()
		p.size = Vector2(4, 4)
		p.color = Color(0.6, 0.55, 0.45, 0.8)
		var offset := Vector2(randf_range(-16, 16), randf_range(-8, 8))
		p.position = global_position + offset
		p.z_index = 15
		get_tree().current_scene.add_child(p)

		var tween := p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", p.position + Vector2(randf_range(-12, 12), -20), 0.6)
		tween.tween_property(p, "modulate:a", 0.0, 0.6)
		tween.chain().tween_callback(p.queue_free)


func _spawn_gather_particles() -> void:
	var color: Color
	match carry_type:
		"wood": color = Color(0.545, 0.412, 0.078)
		"stone": color = Color(0.533, 0.533, 0.533)
		"gold": color = Color(0.831, 0.627, 0.090)
		_: color = Color.WHITE

	var count := 5
	if carry_type == "wood":
		count = 8

	for i in range(count):
		var particle := ColorRect.new()
		particle.size = Vector2(3, 3)
		if carry_type == "wood" and i % 2 == 0:
			particle.size = Vector2(5, 2)
		particle.color = color
		particle.position = global_position + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		particle.z_index = 15
		get_tree().current_scene.add_child(particle)

		var drift_x := randf_range(-5, 5)
		if carry_type == "wood":
			drift_x = randf_range(-16, 16)

		var tween := particle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", particle.position + Vector2(drift_x, -15), 0.4)
		tween.tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.chain().tween_callback(particle.queue_free)

	_show_local_resource_popup()


func _show_local_resource_popup() -> void:
	if carry_amount <= 0:
		return
	var txt := ""
	match carry_type:
		"wood": txt = "+%d Wood" % carry_amount
		"stone": txt = "+%d Stone" % carry_amount
		"gold": txt = "+%d Gold" % carry_amount
		_:
			return

	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.90))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.position = global_position + Vector2(randf_range(-8, 8), -12)
	lbl.z_index = 18
	get_tree().current_scene.add_child(lbl)

	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 18, 0.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(lbl.queue_free)


func call_to_arms() -> void:
	hide_in_cabin()


func hide_in_cabin() -> void:
	if is_hiding_in_cabin:
		return
	_release_claim()
	attack_target = null
	hide_requested = true
	state = GameConfig.VillagerState.RETURNING


func unhide_from_cabin() -> void:
	hide_requested = false
	is_hiding_in_cabin = false
	if sprite:
		sprite.visible = true
	if shadow:
		shadow.visible = true
	state = GameConfig.VillagerState.IDLE
	_reset_state()


# ── Health System ────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if is_hiding_in_cabin:
		return
	hp -= amount
	# Flash red
	if sprite:
		sprite.modulate = Color(1.0, 0.2, 0.2)
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	_update_hp_bar()
	if hp <= 0:
		_die_villager()


func _die_villager() -> void:
	_release_claim()
	AudioManager.play_sfx("death")
	villager_died.emit(self)
	# Death particles
	for i in range(6):
		var p := ColorRect.new()
		p.size = Vector2(3, 3)
		p.color = Color(0.788, 0.541, 0.369)
		p.position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		p.z_index = 15
		get_tree().current_scene.add_child(p)
		var tween := p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position:y", p.position.y - 18, 0.5)
		tween.tween_property(p, "modulate:a", 0.0, 0.5)
		tween.chain().tween_callback(p.queue_free)
	queue_free()


func _create_hp_bar() -> void:
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.size = Vector2(20, 3)
	hp_bar_bg.position = Vector2(-10, -18)
	hp_bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	hp_bar_bg.z_index = 1
	hp_bar_bg.visible = false
	add_child(hp_bar_bg)

	hp_bar = ColorRect.new()
	hp_bar.size = Vector2(18, 2)
	hp_bar.position = Vector2(-9, -17.5)
	hp_bar.color = Color.GREEN
	hp_bar.z_index = 2
	hp_bar.visible = false
	add_child(hp_bar)


func _create_shadow() -> void:
	shadow = ColorRect.new()
	shadow.size = Vector2(11, 4)
	shadow.position = Vector2(-5.5, 7)
	shadow.color = Color(0.0, 0.0, 0.0, 0.28)
	shadow.z_index = -1
	add_child(shadow)


func _update_hp_bar() -> void:
	if not hp_bar:
		return
	# Only show if damaged
	var show_bar := hp < max_hp
	hp_bar_bg.visible = show_bar
	hp_bar.visible = show_bar
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	hp_bar.size.x = 18.0 * ratio
	if ratio > 0.5:
		hp_bar.color = Color.GREEN
	elif ratio > 0.25:
		hp_bar.color = Color.ORANGE
	else:
		hp_bar.color = Color.RED


# ── Sword Swipe Particle ────────────────────────────────────

func _spawn_sword_swipe() -> void:
	if not is_instance_valid(attack_target):
		return
	var dir := (attack_target.global_position - global_position).normalized()
	var base_pos := global_position + dir * 12.0

	# Spawn arc of particles simulating a sword slash
	for i in range(5):
		var offset_angle := deg_to_rad(-40 + i * 20)
		var rotated_dir := dir.rotated(offset_angle)
		var p := ColorRect.new()
		p.size = Vector2(4, 2)
		p.color = Color(0.9, 0.9, 1.0, 0.9)
		p.rotation = rotated_dir.angle()
		p.position = base_pos + rotated_dir * (4.0 + i * 2.0)
		p.z_index = 20
		get_tree().current_scene.add_child(p)

		var end_pos := p.position + rotated_dir * 10.0
		var tween := p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", end_pos, 0.15)
		tween.tween_property(p, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(p.queue_free)


# ── External Villager Animation Pack ───────────────────────

func _get_role_pack_info(p_role: int) -> Dictionary:
	match p_role:
		GameConfig.Role.LUMBERJACK:
			return {
				"root": "res://Villager_with_axe/",
				"action": "custom-cutting with axe"
			}
		GameConfig.Role.MINER:
			return {
				"root": "res://Villager_with_pickaxe/",
				"action": "custom-Mining with pickaxe"
			}
		GameConfig.Role.DEFENDER:
			return {
				"root": "res://Villager_with_sword/",
				"action": "custom-swinging a sword"
			}
		_:
			return {}


func _load_external_animation_pack_for_role(p_role: int) -> void:
	var pack := _get_role_pack_info(p_role)
	if pack.is_empty():
		use_external_anim = false
		return

	var root: String = pack["root"]
	var action_name: String = pack["action"]
	var cache_key := root + "|" + action_name

	if PACK_CACHE.has(cache_key):
		var cached: Dictionary = PACK_CACHE[cache_key]
		idle_frames = cached["idle"]
		run_frames = cached["run"]
		action_frames = cached["action"]
		use_external_anim = not idle_frames.is_empty()
		if use_external_anim and sprite:
			sprite.scale = Vector2(0.5, 0.5)
		return

	var local_idle: Dictionary = {}
	var local_run: Dictionary = {}
	var local_action: Dictionary = {}

	var meta_path := ProjectSettings.globalize_path(root + "metadata.json")
	if not FileAccess.file_exists(meta_path):
		use_external_anim = false
		return
	var f := FileAccess.open(meta_path, FileAccess.READ)
	if f == null:
		use_external_anim = false
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		use_external_anim = false
		return
	if not parsed.has("frames"):
		use_external_anim = false
		return

	var frames_dict: Dictionary = parsed["frames"]
	if frames_dict.has("rotations"):
		for dir_key in (frames_dict["rotations"] as Dictionary).keys():
			var rel_path: String = frames_dict["rotations"][dir_key]
			var tex := _load_image_texture(root, rel_path)
			if tex:
				local_idle[dir_key] = tex

	if frames_dict.has("animations"):
		var anims: Dictionary = frames_dict["animations"]
		if anims.has(RUN_ANIM_NAME):
			var run_dict: Dictionary = anims[RUN_ANIM_NAME]
			for dir_key in run_dict.keys():
				var arr: Array = []
				for rel_path in run_dict[dir_key]:
					var tex := _load_image_texture(root, String(rel_path))
					if tex:
						arr.append(tex)
				if not arr.is_empty():
					local_run[dir_key] = arr

		if anims.has(action_name):
			var action_dict: Dictionary = anims[action_name]
			for dir_key in action_dict.keys():
				var arr: Array = []
				for rel_path in action_dict[dir_key]:
					var tex := _load_image_texture(root, String(rel_path))
					if tex:
						arr.append(tex)
				if not arr.is_empty():
					local_action[dir_key] = arr

	idle_frames = local_idle
	run_frames = local_run
	action_frames = local_action
	PACK_CACHE[cache_key] = {
		"idle": local_idle,
		"run": local_run,
		"action": local_action,
	}

	use_external_anim = not idle_frames.is_empty()
	if use_external_anim and sprite:
		sprite.scale = Vector2(0.5, 0.5)


func _load_image_texture(root: String, relative_path: String) -> Texture2D:
	var full_res := root + relative_path
	var abs := ProjectSettings.globalize_path(full_res)
	if not FileAccess.file_exists(abs):
		return null
	var img := Image.new()
	var err := img.load(abs)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)


func _play_run_anim(delta: float, move_vec: Vector2) -> void:
	if run_frames.is_empty():
		return
	facing_dir = _dir8_from_vec(move_vec)
	if not run_frames.has(facing_dir):
		return
	if current_anim != "run":
		current_anim = "run"
		anim_timer = 0.0
		anim_frame_idx = 0
	var frames: Array = run_frames[facing_dir]
	_play_frames(delta, frames, RUN_FPS)


func _play_action_anim(delta: float, aim_vec: Vector2) -> void:
	if action_frames.is_empty():
		return
	facing_dir = _dir4_from_vec(aim_vec)
	if not action_frames.has(facing_dir):
		return
	if current_anim != "action":
		current_anim = "action"
		anim_timer = 0.0
		anim_frame_idx = 0
	var frames: Array = action_frames[facing_dir]
	_play_frames(delta, frames, ACTION_FPS)


func _play_frames(delta: float, frames: Array, fps: float) -> void:
	if frames.is_empty() or not sprite:
		return
	anim_timer += delta
	var frame_dur := 1.0 / fps
	while anim_timer >= frame_dur:
		anim_timer -= frame_dur
		anim_frame_idx = (anim_frame_idx + 1) % frames.size()
	sprite.texture = frames[anim_frame_idx]


func _apply_idle_frame() -> void:
	if not sprite:
		return
	if idle_frames.has(facing_dir):
		sprite.texture = idle_frames[facing_dir]
	elif idle_frames.has("south"):
		sprite.texture = idle_frames["south"]


func _dir8_from_vec(v: Vector2) -> String:
	if v.length() < 0.001:
		return facing_dir
	var dirs := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	var idx := int(round(v.angle() / (PI / 4.0)))
	idx = posmod(idx, 8)
	return dirs[idx]


func _dir4_from_vec(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "east" if v.x >= 0.0 else "west"
	return "south" if v.y >= 0.0 else "north"
