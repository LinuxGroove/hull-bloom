// The Bloom's growth on the station's floors, walls and ceilings. Each sheet
// is a flat, finely divided plane; this shader reads the deck's growth levels
// from the bloom_map (one texel a tile, red the level / 4, green how freshly
// it was burnt) and swells the sheet into wet, veined flesh where the Bloom
// has reached, thicker the more it has grown. Floors grow first, then the
// walls from the floor up, then the ceilings.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://game/bloom/noise.gdshaderinc"

global uniform sampler2D bloom_map : filter_linear, repeat_disable;
global uniform vec4 bloom_rect;
global uniform float calm_walls;

// 0 floor, 1 wall, 2 ceiling.
uniform int surface = 0;
uniform vec3 edge_color : source_color = vec3(0.1, 0.018, 0.028);
uniform vec3 mid_color : source_color = vec3(0.38, 0.065, 0.085);
uniform vec3 top_color : source_color = vec3(0.64, 0.26, 0.25);
uniform vec3 fat_color : source_color = vec3(0.62, 0.46, 0.32);
uniform vec3 vein_color : source_color = vec3(0.09, 0.02, 0.1);
uniform vec3 glow_color : source_color = vec3(0.95, 0.2, 0.16);
uniform float glow = 0.35;
uniform float bumps = 0.6;

varying float cover;
varying float height_t;
varying vec3 wpos;
varying float scorch;

float level_at(vec2 p) {
	vec2 uv = (p - bloom_rect.xy) / bloom_rect.zw;
	float smooth_l = texture(bloom_map, uv).r;
	// A warped nearest sample keeps the growth mostly to its own tiles, with
	// a ragged edge, rather than smearing evenly across doorways.
	vec2 warp = vec2(hb_noise(vec3(p * 0.45, 1.7)), hb_noise(vec3(p * 0.45, 5.3))) - 0.5;
	vec2 tex_size = vec2(textureSize(bloom_map, 0));
	vec2 nuv = (floor((p + warp * 2.2 - bloom_rect.xy) / bloom_rect.zw * tex_size) + 0.5) / tex_size;
	float near_l = texture(bloom_map, nuv).r;
	return mix(smooth_l, near_l, 0.55) * 4.0;
}

float scorch_at(vec2 p) {
	return texture(bloom_map, (p - bloom_rect.xy) / bloom_rect.zw).g;
}

// How covered a point is (below 0: bare) and how thick the growth is there.
vec2 growth_at(vec3 wp, vec3 wn) {
	vec2 p = wp.xz + wn.xz * 1.6;
	float lvl = level_at(p);
	float n = hb_fbm(wp * 0.8);
	float c;
	if (surface == 0) {
		c = lvl * 0.42 + (n - 0.5) * 0.9 - 0.12;
	} else if (surface == 1) {
		// Climbs the walls as it grows: knee high at 2, the ceiling at 4.
		float climb = max(0.0, lvl - 1.2) * 1.8;
		c = (climb - wp.y) * 0.45 + (n - 0.5) * 0.9;
	} else {
		c = (lvl - 2.8) * 0.75 + (n - 0.5) * 0.9;
	}
	float lump = 0.55 + 0.45 * hb_fbm(wp * 1.5 + 3.1) + 0.15 * max(0.0, hb_noise(wp * 4.0) - 0.5);
	float thick = (0.06 + 0.08 * lvl) * (surface == 2 ? 1.3 : 1.0);
	float h = c > 0.0 ? thick * (0.08 + 0.92 * pow(min(c, 1.2), 0.8)) * lump : 0.0;
	// Veins stand proud of the flesh like cords.
	float vein = smoothstep(0.86, 0.98, hb_ridge(wp * 1.1));
	h += c > 0.05 ? vein * 0.035 * min(c * 3.0, 1.0) : 0.0;
	return vec2(c, h);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 wt = normalize((MODEL_MATRIX * vec4(TANGENT, 0.0)).xyz);
	vec3 wb = cross(wn, wt);
	vec2 g = growth_at(wp, wn);
	float e = 0.09;
	float hx = growth_at(wp + wt * e, wn).y;
	float hy = growth_at(wp + wb * e, wn).y;
	float breath = 1.0 + 0.06 * calm_walls * sin(TIME * 1.1 + hb_noise(wp * 0.6) * 6.2831);
	float h = g.y * breath;
	VERTEX += NORMAL * h;
	// The slope of the swelling gives the normal.
	vec3 n_world = normalize(wn - wt * (hx * breath - h) / e - wb * (hy * breath - h) / e);
	NORMAL = normalize((inverse(MODEL_MATRIX) * vec4(n_world, 0.0)).xyz);
	cover = g.x;
	height_t = clamp(h / (0.06 + 0.08 * 4.0), 0.0, 1.0);
	wpos = wp;
	scorch = scorch_at(wp.xz + wn.xz * 1.6);
}

// The fine wet texture of the flesh, as a height for bump mapping.
float skin(vec3 p) {
	return hb_fbm(p * 7.0) * 0.6 + hb_noise(p * 23.0) * 0.15 + smoothstep(0.9, 0.99, hb_ridge(p * 2.9)) * 0.5;
}

void fragment() {
	if (cover < 0.0) {
		discard;
	}
	float t = clamp(height_t * 1.6, 0.0, 1.0);
	float vein;
	vec3 meat = hb_meat(wpos * 1.6, edge_color, mid_color, top_color, fat_color, vein_color, vein);
	// Thin growth at the edges is a dark film; it fattens into meat.
	vec3 c = mix(edge_color, meat, smoothstep(0.0, 0.3, t) * 0.8 + 0.2);
	float rim_vein = smoothstep(0.86, 0.98, hb_ridge(wpos * 1.1));
	c = mix(c, vein_color * 1.4, rim_vein * 0.75);
	// Freshly burnt growth is charred black and dull.
	float char_amt = clamp(scorch * 1.4, 0.0, 1.0) * smoothstep(0.25, 0.65, hb_noise(wpos * 3.0));
	c = mix(c, vec3(0.025, 0.015, 0.012), char_amt);
	ALBEDO = c;
	// Bumps from the skin's height, in view space.
	float hgt = skin(wpos);
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(hgt) * r1 + dFdy(hgt) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * bumps * 0.03 * (1.0 - char_amt * 0.7));
	ROUGHNESS = mix(0.12, 0.45, hb_noise(wpos * 6.0)) + char_amt * 0.45;
	SPECULAR = 0.6;
	CLEARCOAT = 1.0 - char_amt;
	CLEARCOAT_ROUGHNESS = 0.08;
	SSS_STRENGTH = 0.25 * (1.0 - char_amt);
	// A few swollen nodules glow from inside, slowly.
	float pulse = 0.75 + 0.25 * sin(TIME * 1.1 + hb_noise(wpos * 0.5) * 6.0) * calm_walls;
	float node = smoothstep(0.86, 0.95, hb_noise(wpos * 6.5 + 11.0)) * smoothstep(0.4, 0.9, t);
	EMISSION = glow_color * (node * 0.7 + vein * 0.05) * glow * pulse * (1.0 - char_amt)
		+ vec3(1.0, 0.35, 0.05) * char_amt * scorch * 0.6 * smoothstep(0.6, 0.9, hb_noise(wpos * 9.0 + TIME));
}
