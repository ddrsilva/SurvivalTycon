shader_type canvas_item;

// Wind sway shader — applies gentle horizontal wave to top portions of tiles.
// Works best on tree tiles where the canopy is in the upper half.

uniform float wind_speed : hint_range(0.5, 4.0) = 1.5;
uniform float wind_strength : hint_range(0.0, 8.0) = 2.5;

void vertex() {
	// UV.y == 0 at top, 1 at bottom. We want to sway only the top half.
	float sway_factor = clamp(1.0 - UV.y * 2.0, 0.0, 1.0); // 1 at top, 0 at middle, 0 at bottom
	sway_factor = sway_factor * sway_factor; // ease-in curve for natural look

	float wave = sin(TIME * wind_speed + VERTEX.x * 0.02 + VERTEX.y * 0.01) * wind_strength;
	VERTEX.x += wave * sway_factor;
}
