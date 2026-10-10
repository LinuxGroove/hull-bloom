// The Bloom's flesh: raw, wet, veined meat that needs no UVs. The colour
// comes from noise on the model's rest pose (CUSTOM0, baked by Flesh.bake),
// so it sticks to a moving body; models without it use their own vertices.
// It breathes slowly (the Calm walls setting slows or stops it), and glows
// along its veins.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://game/bloom/noise.gdshaderinc"

global uniform float calm_walls;

uniform vec3 dark : source_color = vec3(0.118, 0.012, 0.024);
uniform vec3 mid : source_color = vec3(0.369, 0.047, 0.078);
uniform vec3 light : source_color = vec3(0.659, 0.227, 0.235);
uniform vec3 fat : source_color = vec3(0.784, 0.627, 0.439);
uniform vec3 vein_color : source_color = vec3(0.094, 0.031, 0.149);
uniform vec3 glow_color : source_color = vec3(0.85, 0.12, 0.05);
uniform float glow = 0.35;
uniform float scale = 3.0;
uniform float wet = 0.9;
uniform float breathe = 0.02;
uniform bool use_rest = false;

// Per creature: how hurt it looks for a moment, how charred by the cutter,
// and how strongly its outline shows against the growth it hunts in.
instance uniform float hurt = 0.0;
instance uniform float charred = 0.0;
instance uniform float edge = 0.0;
uniform vec3 edge_color : source_color = vec3(1.0, 0.78, 0.66);

varying vec3 rest;

void vertex() {
	rest = use_rest ? CUSTOM0.xyz : VERTEX;
	float n = hb_noise(rest * 1.7);
	VERTEX += NORMAL * breathe * calm_walls * sin(TIME * 1.3 + n * 6.2831) * (0.5 + n);
}

void fragment() {
	vec3 q = rest * scale;
	float vein;
	vec3 meat = hb_meat(q, dark, mid, light, fat, vein_color, vein);
	meat = mix(meat, vec3(0.02, 0.012, 0.01), clamp(charred, 0.0, 1.0) * smoothstep(0.3, 0.7, hb_noise(q * 3.0)));
	ALBEDO = mix(meat, vec3(1.0, 0.85, 0.8), clamp(hurt, 0.0, 1.0) * 0.5);
	ROUGHNESS = mix(0.18, 0.62, smoothstep(0.3, 0.8, hb_fbm(rest * 5.0 + 2.0))) * mix(1.0, 0.6, wet);
	SPECULAR = 0.6;
	CLEARCOAT = wet;
	CLEARCOAT_ROUGHNESS = 0.12;
	RIM = 0.25;
	RIM_TINT = 0.6;
	float pulse = 0.75 + 0.25 * sin(TIME * 1.3 + hb_noise(rest * 0.7) * 6.0) * calm_walls;
	EMISSION = glow_color * vein * glow * pulse * (1.0 - clamp(charred, 0.0, 1.0));
	EMISSION += edge_color * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * edge;
}
