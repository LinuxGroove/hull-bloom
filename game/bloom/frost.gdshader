// Frost on a creature from the cryo sprayer, drawn over its own material
// (material_overlay): white patches that spread as it chills and crust it
// over when it's frozen solid. Works from the rest pose in CUSTOM0 when the
// mesh has one, so the frost sticks to a moving body.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, diffuse_burley, specular_schlick_ggx;

#include "res://game/bloom/noise.gdshaderinc"

uniform bool use_rest = false;
uniform vec3 ice_color : source_color = vec3(0.82, 0.91, 0.97);
uniform vec3 ice_deep : source_color = vec3(0.42, 0.62, 0.78);
// A slot of its own, clear of the ones the flesh and crew shaders use.
instance uniform float frost : instance_index(12) = 0.0;

varying vec3 rest;

void vertex() {
	// Noise in metres, whatever the model's scale.
	float sc = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	rest = (use_rest ? CUSTOM0.xyz : VERTEX) * sc;
	VERTEX += NORMAL * (0.004 + 0.012 * frost) / sc;
}

void fragment() {
	float crystals = hb_noise(rest * 14.0) * 0.6 + hb_noise(rest * 37.0) * 0.4;
	float n = hb_fbm(rest * 3.0) * 0.7 + crystals * 0.3;
	// Patches first, joining up as the chill builds.
	float edge = 1.0 - frost * 1.15;
	float cover = smoothstep(edge, edge + 0.08, n);
	if (frost <= 0.0 || cover <= 0.0) {
		discard;
	}
	ALBEDO = mix(ice_deep, ice_color, smoothstep(0.35, 0.75, crystals));
	ALPHA = cover * mix(0.6, 0.95, frost);
	ROUGHNESS = mix(0.2, 0.7, crystals);
	SPECULAR = 0.7;
	RIM = 0.4;
	RIM_TINT = 0.3;
	float glint = smoothstep(0.93, 0.99, hb_noise(rest * 60.0));
	EMISSION = vec3(0.55, 0.8, 1.0) * glint * 0.4 * frost;
}
