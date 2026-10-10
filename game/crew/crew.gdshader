// Marigold's crew: grimy coveralls coloured by job, boots and gloves, skin
// and hair, on Quaternius' Universal Base Characters. Works from the rest pose
// baked by Crew.bake (CUSTOM0 the position, CUSTOM1 how much of each vertex is
// head, hand and foot), so it needs no UVs and sticks to a moving body.
// Instance uniforms turn the living crew into the dead and the Taken: pale
// skin, blood, and the Bloom bursting out of them.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://game/bloom/noise.gdshaderinc"

global uniform float calm_walls;

uniform vec3 suit : source_color = vec3(0.86, 0.36, 0.08);
uniform vec3 stripe : source_color = vec3(0.85, 0.85, 0.78);
uniform vec3 under : source_color = vec3(0.12, 0.12, 0.13);
uniform vec3 skin : source_color = vec3(0.78, 0.56, 0.44);
uniform vec3 hair : source_color = vec3(0.12, 0.08, 0.05);
uniform vec3 glove : source_color = vec3(0.1, 0.1, 0.11);
uniform vec3 boot : source_color = vec3(0.07, 0.07, 0.08);
// 0 short hair, 1 shaved, 2 long.
uniform int hair_style = 0;
uniform float top = 1.82;

instance uniform float dead = 0.0;
instance uniform float blood = 0.0;
instance uniform float bloom = 0.0;
instance uniform float hurt = 0.0;
instance uniform float charred = 0.0;
instance uniform float seed = 0.0;

varying vec3 rest;
varying vec3 region;
varying float growth;

float bloom_mask(vec3 p) {
	if (bloom <= 0.0) {
		return 0.0;
	}
	// The Bloom bursts out of the back and chest first, then everywhere.
	float torso = smoothstep(0.85, 1.15, p.y) * (1.0 - smoothstep(1.45, 1.6, p.y)) * (1.0 - smoothstep(0.25, 0.4, abs(p.x)));
	float n = hb_fbm(p * 3.2 + seed * 7.1);
	float want = mix(0.78, 0.42, bloom) - torso * 0.22 * bloom;
	return smoothstep(want, want + 0.06, n);
}

void vertex() {
	rest = CUSTOM0.xyz;
	region = CUSTOM1.xyz;
	growth = bloom_mask(rest);
	float b = growth * (0.02 + 0.04 * hb_noise(rest * 9.0));
	b *= 1.0 + 0.15 * calm_walls * sin(TIME * 1.4 + seed * 3.0 + rest.y * 4.0);
	VERTEX += NORMAL * b;
}

void fragment() {
	vec3 p = rest;
	float head = region.x;
	float hand = region.y;
	float foot = region.z;
	// The coverall: a belt, reflective stripes on the arms and shins, seams
	// and grime.
	vec3 c = suit;
	float belt = smoothstep(0.03, 0.02, abs(p.y - 1.0));
	float shin = smoothstep(0.025, 0.015, abs(p.y - 0.42)) * step(p.y, 0.8);
	float arm = smoothstep(0.025, 0.015, abs(abs(p.x) - 0.42)) * step(1.3, p.y);
	c = mix(c, stripe, max(shin, arm));
	c = mix(c, under, belt);
	float seam = smoothstep(0.006, 0.0, abs(p.x)) * step(p.y, 1.45) * step(0.0, p.z);
	c *= 1.0 - seam * 0.4;
	float grime = hb_fbm(p * 6.0 + seed);
	c *= mix(0.7, 1.05, grime);
	c = mix(c, c * vec3(0.55, 0.5, 0.42), smoothstep(0.45, 0.0, p.y) * 0.6);
	// Skin and hair.
	vec3 sk = mix(skin, vec3(0.6, 0.62, 0.55) * (0.8 + 0.2 * hb_noise(p * 30.0)), dead);
	float hair_line = top - (hair_style == 2 ? 0.2 : 0.085);
	float on_hair = smoothstep(hair_line, hair_line + 0.01, p.y + max(0.0, -p.z) * 1.4 - max(0.0, p.z - 0.04) * 1.2);
	if (hair_style == 1) {
		on_hair *= 0.35;
	}
	vec3 h = mix(sk, hair * (0.8 + 0.4 * hb_noise(p * 90.0)), on_hair);
	c = mix(c, h, head);
	c = mix(c, glove, hand);
	c = mix(c, boot, foot);
	// Veins under dead skin.
	float vein = smoothstep(0.93, 0.99, hb_ridge(p * 16.0 + seed)) * dead * max(head, 0.4);
	c = mix(c, vec3(0.2, 0.08, 0.22), vein * 0.6);
	// Blood: splashes and runs down.
	float spl = hb_fbm(vec3(p.x * 7.0, p.y * 2.2, p.z * 7.0) + seed * 3.0);
	float bl = smoothstep(1.0 - blood * 0.62, 1.05 - blood * 0.62, spl + hb_noise(p * 14.0) * 0.12);
	c = mix(c, vec3(0.2, 0.012, 0.016), bl * 0.92);
	float rough = mix(0.82, 0.25, bl);
	// Where the Bloom has burst out.
	float vb;
	vec3 meat = hb_meat(p * 6.0 + seed, vec3(0.118, 0.012, 0.024), vec3(0.369, 0.047, 0.078), vec3(0.659, 0.227, 0.235), vec3(0.784, 0.627, 0.439), vec3(0.094, 0.031, 0.149), vb);
	float edge = smoothstep(0.0, 0.25, growth) - smoothstep(0.25, 1.0, growth);
	c = mix(c, vec3(0.16, 0.02, 0.03), edge * 0.7);
	c = mix(c, meat, growth);
	rough = mix(rough, 0.2, growth);
	c = mix(c, vec3(0.02, 0.012, 0.01), clamp(charred, 0.0, 1.0) * smoothstep(0.3, 0.7, hb_noise(p * 12.0)));
	ALBEDO = mix(c, vec3(1.0, 0.85, 0.8), clamp(hurt, 0.0, 1.0) * 0.45);
	ROUGHNESS = rough;
	SPECULAR = 0.4;
	CLEARCOAT = max(growth, bl * 0.6);
	CLEARCOAT_ROUGHNESS = 0.15;
	float pulse = 0.75 + 0.25 * sin(TIME * 1.3 + seed * 5.0) * calm_walls;
	EMISSION = vec3(0.85, 0.12, 0.05) * vb * growth * 0.35 * pulse;
}
