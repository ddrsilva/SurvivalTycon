# ============================================================
# CameraShake — Attach to a Camera2D to add screen shake
# Call apply_shake(intensity) from anywhere to trigger
# ============================================================
extends Camera2D

var shake_intensity := 0.0
var shake_decay := 5.0

func apply_shake(intensity: float) -> void:
	shake_intensity = max(shake_intensity, intensity)

func _process(delta: float) -> void:
	if shake_intensity > 0.01:
		offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
	else:
		shake_intensity = 0.0
		offset = Vector2.ZERO
