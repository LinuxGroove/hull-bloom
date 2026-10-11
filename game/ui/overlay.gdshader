// What's happening to the tech, over the whole view: a red flash and red at
// the edges when hurt, the Bloom's veins creeping in as the infection rises, and a short
// blur when a pod's spores burst in your face (or only a tint, with the
// Spore blur setting off).
shader_type canvas_item;

#include "res://game/bloom/noise.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float hurt = 0.0;
uniform float pulse = 0.0;
uniform float infection = 0.0;
uniform float blur = 0.0;
uniform float tint = 0.0;
uniform float down = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = (uv - 0.5) * vec2(1.6, 1.0);
	float r = length(d);
	vec3 c = textureLod(screen, uv, blur * 4.0).rgb;
	if (blur > 0.0) {
		vec3 c2 = textureLod(screen, uv + vec2(0.006, 0.0) * blur, blur * 3.0).rgb;
		c = mix(c, c2, 0.5);
	}
	// Spores: a sickly yellow green.
	float sp = max(blur, tint);
	c = mix(c, c * vec3(0.85, 1.0, 0.55) + vec3(0.05, 0.07, 0.0), sp * 0.6);
	// Infection: veins from the edges inward.
	if (infection > 0.0) {
		vec3 q = vec3(d * 4.0, TIME * 0.05);
		float v = smoothstep(0.9, 0.98, hb_ridge(q * 1.4));
		float reach = smoothstep(1.05 - infection * 0.55, 1.15 - infection * 0.4, r + (hb_noise(q * 2.0) - 0.5) * 0.25);
		c = mix(c, vec3(0.16, 0.02, 0.08), reach * (0.4 + 0.6 * v) * 0.85);
		c = mix(c, vec3(0.5, 0.05, 0.1), v * reach * 0.5);
	}
	// Hurt: red at the edges, and a moment's red over everything as a blow lands.
	float edge = smoothstep(0.35, 1.0, r);
	c = mix(c, vec3(0.5, 0.0, 0.0), edge * hurt * 0.9);
	c = mix(c, vec3(0.6, 0.02, 0.0), pulse * (0.2 + 0.45 * edge));
	// Down: everything fades to dark red.
	c = mix(c, vec3(0.08, 0.0, 0.0), down * smoothstep(0.0, 1.0, r + down * 0.6));
	COLOR = vec4(c, 1.0);
}
