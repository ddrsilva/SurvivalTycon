# ============================================================
# Threat Entity — Enemies that approach the village
# Supports: enemy types, knockback, cabin damage
# ============================================================
extends Node2D

signal died(threat: Node2D)
signal reached_cabin(threat: Node2D, damage: int)

var hp: int = GameConfig.THREAT_HP
var max_hp: int = GameConfig.THREAT_HP
var speed: float = GameConfig.THREAT_SPEED
var damage: int = GameConfig.THREAT_DAMAGE
var enemy_type: int = GameConfig.EnemyType.SLIME
var target_position := Vector2.ZERO
var path_resolver: Callable

# Knockback
var knockback_velocity := Vector2.ZERO

# Attack cabin / villagers
var cabin_attack_cooldown := 0.0
var villager_attack_cooldown := 0.0
var villager_group: Node2D  # set by game scene

var sprite: Sprite2D
var hp_bar: ColorRect
var hp_bar_bg: ColorRect
var shadow: ColorRect


func _ready() -> void:
	sprite = $Sprite2D
	hp_bar_bg = $HPBarBG
	hp_bar = $HPBar
	shadow = ColorRect.new()
	shadow.size = Vector2(14, 5)
	shadow.position = Vector2(-7, 8)
	shadow.color = Color(0.0, 0.0, 0.0, 0.30)
	shadow.z_index = -1
	add_child(shadow)


func setup_type(etype: int) -> void:
	enemy_type = etype
	var stats: Dictionary = GameConfig.ENEMY_STATS[etype]
	hp = stats["hp"]
	max_hp = stats["hp"]
	speed = stats["speed"]
	damage = stats["damage"]
	_update_hp_bar()


func _process(delta: float) -> void:
	# Apply knockback decay
	if knockback_velocity.length() > 1.0:
		global_position += knockback_velocity * delta
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 8.0 * delta)
	else:
		knockback_velocity = Vector2.ZERO

	var diff := target_position - global_position
	var dist := diff.length()
	var step := speed * delta

	# Check if reached the cabin
	if dist <= GameConfig.THREAT_ATTACK_RANGE:
		cabin_attack_cooldown -= delta
		if cabin_attack_cooldown <= 0.0:
			cabin_attack_cooldown = GameConfig.THREAT_ATTACK_COOLDOWN
			reached_cabin.emit(self, damage)
	elif dist > step:
		if path_resolver.is_valid():
			global_position = path_resolver.call(global_position, target_position, step)
		else:
			global_position += diff.normalized() * step

	# Attack nearby villagers
	_try_attack_villager(delta)

	# Flip sprite based on direction
	if sprite:
		sprite.flip_h = diff.x < 0

	_update_hp_bar()


func take_damage(amount: int, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	hp -= amount

	# Flash red
	if sprite:
		sprite.modulate = Color(1.0, 0.2, 0.2)
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

	# Knockback away from attacker
	if attacker_pos != Vector2.ZERO:
		var kb_dir := (global_position - attacker_pos).normalized()
		knockback_velocity = kb_dir * GameConfig.THREAT_KNOCKBACK

	_update_hp_bar()

	if hp <= 0:
		_die()


func _update_hp_bar() -> void:
	if not hp_bar:
		return
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	hp_bar.size.x = 18.0 * ratio
	if ratio > 0.5:
		hp_bar.color = Color.GREEN
	elif ratio > 0.25:
		hp_bar.color = Color.ORANGE
	else:
		hp_bar.color = Color.RED


func _die() -> void:
	died.emit(self)
	# Death particles
	var death_color := Color(0.318, 0.769, 0.314) if enemy_type == GameConfig.EnemyType.SLIME else Color(0.420, 0.380, 0.345)
	for i in range(8):
		var p := ColorRect.new()
		p.size = Vector2(3, 3)
		p.color = death_color
		p.position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		p.z_index = 15
		get_tree().current_scene.add_child(p)

		var tween := p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position:y", p.position.y - 20, 0.5)
		tween.tween_property(p, "modulate:a", 0.0, 0.5)
		tween.chain().tween_callback(p.queue_free)

	queue_free()


func _try_attack_villager(delta: float) -> void:
	if not villager_group:
		return
	villager_attack_cooldown -= delta
	if villager_attack_cooldown > 0.0:
		return
	for v in villager_group.get_children():
		if not is_instance_valid(v):
			continue
		if v.global_position.distance_to(global_position) <= GameConfig.THREAT_ATTACK_RANGE:
			if v.has_method("take_damage"):
				v.take_damage(damage)
				villager_attack_cooldown = GameConfig.THREAT_ATTACK_COOLDOWN
				return
