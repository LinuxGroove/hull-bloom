// Value noise and fractal noise, shared by the Bloom's shaders.

float hb_hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float hb_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hb_hash3(i), hb_hash3(i + vec3(1, 0, 0)), f.x),
				   mix(hb_hash3(i + vec3(0, 1, 0)), hb_hash3(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hb_hash3(i + vec3(0, 0, 1)), hb_hash3(i + vec3(1, 0, 1)), f.x),
				   mix(hb_hash3(i + vec3(0, 1, 1)), hb_hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float hb_fbm(vec3 p) {
	return 0.5 * hb_noise(p) + 0.25 * hb_noise(p * 2.03) + 0.125 * hb_noise(p * 4.01) + 0.0625 * hb_noise(p * 8.07);
}

float hb_ridge(vec3 p) {
	return 1.0 - abs(2.0 * hb_noise(p) - 1.0);
}

// Raw, veined meat for a point in the model's rest pose: `scale` sets the
// size of the marbling. Returns the colour; `vein` is how much of a vein the
// point is, for the glow.
vec3 hb_meat(vec3 q, vec3 dark, vec3 mid, vec3 light, vec3 fat, vec3 vein_col, out float vein) {
	float n = hb_fbm(q);
	float b = hb_fbm(q * 0.45 + 7.3);
	vec3 meat = mix(dark, mid, smoothstep(0.28, 0.6, n));
	meat = mix(meat, light, smoothstep(0.56, 0.74, n) * 0.85);
	meat = mix(meat, fat, smoothstep(0.64, 0.72, b) * 0.75);
	vein = max(smoothstep(0.93, 0.985, hb_ridge(q * 2.6)), 0.7 * smoothstep(0.95, 0.99, hb_ridge(q * 6.3 + 3.0)));
	return mix(meat, vein_col, vein * 0.85);
}
