# ============================================================
# TreeResource — Animated Tree with Sprite Sheet
# Lifecycle: Static → Chopping → Falling → StumpAndLogs → StumpOnly
# ============================================================
class_name TreeResource
extends Node2D

enum State { STATIC, CHOPPING, FALLING, STUMP_AND_LOGS, STUMP_ONLY }

var state: int = State.STATIC
var tile_pos := Vector2i.ZERO

# Child sprites (created in _ready)
var tree_sprite: Sprite2D
var stump_sprite: Sprite2D
var log_sprite: Sprite2D
var shadow_sprite: ColorRect

# Textures
var static_tex: Texture2D
var chop_textures: Array = []
var fall_textures: Array = []
var stump_tex: Texture2D
var log_tex: Texture2D

# Animation
var anim_timer := 0.0
var current_frame := 0
var sway_phase := randf() * TAU

# Display constants
const TREE_H := 80.0
const STUMP_H := 28.0
const LOG_H := 30.0


func _ready() -> void:
	z_index = 4

	tree_sprite = Sprite2D.new()
	add_child(tree_sprite)

	shadow_sprite = ColorRect.new()
	shadow_sprite.size = Vector2(16, 6)
	shadow_sprite.position = Vector2(-8, 2)
	shadow_sprite.color = Color(0.0, 0.0, 0.0, 0.24)
	shadow_sprite.z_index = -1
	add_child(shadow_sprite)

	stump_sprite = Sprite2D.new()
	stump_sprite.visible = false
	add_child(stump_sprite)

	log_sprite = Sprite2D.new()
	log_sprite.visible = false
	add_child(log_sprite)


func setup(p_static: Texture2D, p_chop: Array, p_fall: Array, p_stump: Texture2D, p_log: Texture2D) -> void:
	static_tex = p_static
	chop_textures = p_chop
	fall_textures = p_fall
	stump_tex = p_stump
	log_tex = p_log

	tree_sprite.texture = static_tex
	_scale_to_height(tree_sprite, static_tex, TREE_H)
	tree_sprite.offset.y = -_get_tex_size(static_tex).y * 0.5

	if stump_tex:
		stump_sprite.texture = stump_tex
		_scale_to_height(stump_sprite, stump_tex, STUMP_H)

	if log_tex:
		log_sprite.texture = log_tex
		_scale_to_height(log_sprite, log_tex, LOG_H)
		log_sprite.position = Vector2(12, -4)


func _process(delta: float) -> void:
	match state:
		State.STATIC:
			tree_sprite.rotation = sin(Time.get_ticks_msec() * 0.0015 + sway_phase) * 0.03
		State.CHOPPING:
			_update_chop(delta)
		State.FALLING:
			_update_fall(delta)


func start_chopping() -> void:
	if state != State.STATIC:
		return
	state = State.CHOPPING
	anim_timer = 0.0
	current_frame = 0
	tree_sprite.rotation = 0.0
	if chop_textures.size() > 0:
		_set_tree_frame(chop_textures[0])


func start_falling() -> void:
	state = State.FALLING
	anim_timer = 0.0
	current_frame = 0
	tree_sprite.rotation = 0.0
	if fall_textures.size() > 0:
		_set_tree_frame(fall_textures[0])
	else:
		_finish_fall()


func is_fell_complete() -> bool:
	return state == State.STUMP_AND_LOGS or state == State.STUMP_ONLY


func collect_logs() -> void:
	state = State.STUMP_ONLY
	log_sprite.visible = false


# ── Animation updates ────────────────────────────────────────

func _update_chop(delta: float) -> void:
	if chop_textures.is_empty():
		return
	anim_timer += delta
	var frame_dur := 1.0 / GameConfig.TREE_CHOP_FPS
	if anim_timer >= frame_dur:
		anim_timer -= frame_dur
		current_frame = (current_frame + 1) % chop_textures.size()
		_set_tree_frame(chop_textures[current_frame])
	# Slight shake during chopping
	tree_sprite.rotation = sin(anim_timer * 14.0) * 0.04


func _update_fall(delta: float) -> void:
	if fall_textures.is_empty():
		_finish_fall()
		return
	anim_timer += delta
	var frame_dur := 1.0 / GameConfig.TREE_FALL_FPS
	if anim_timer >= frame_dur:
		anim_timer -= frame_dur
		current_frame += 1
		if current_frame >= fall_textures.size():
			_finish_fall()
		else:
			_set_tree_frame(fall_textures[current_frame])


func _finish_fall() -> void:
	state = State.STUMP_AND_LOGS
	tree_sprite.visible = false
	stump_sprite.visible = true
	log_sprite.visible = true


func _set_tree_frame(tex: Texture2D) -> void:
	if tex == null:
		return
	tree_sprite.texture = tex
	_scale_to_height(tree_sprite, tex, TREE_H)
	tree_sprite.offset.y = -_get_tex_size(tex).y * 0.5


static func _scale_to_height(spr: Sprite2D, tex: Texture2D, target_h: float) -> void:
	var h := _get_tex_size(tex).y
	if h <= 0:
		return
	var s := target_h / h
	spr.scale = Vector2(s, s)


static func _get_tex_size(tex: Texture2D) -> Vector2:
	if tex == null:
		return Vector2.ZERO
	if tex is AtlasTexture:
		return (tex as AtlasTexture).region.size
	return Vector2(float(tex.get_width()), float(tex.get_height()))
