// Space outside Marigold's windows: stars, a faint nebula, and the survey
// moon's planet below the station, lit from one side.
shader_type sky;

uniform vec3 planet_dir = vec3(0.55, -0.42, -0.72);
uniform vec3 sun_dir = vec3(-0.7, 0.35, -0.2);
uniform float planet_size = 0.32;
uniform vec3 planet_color : source_color = vec3(0.32, 0.42, 0.55);
uniform vec3 band_color : source_color = vec3(0.55, 0.45, 0.35);
uniform vec3 nebula_a : source_color = vec3(0.16, 0.05, 0.2);
uniform vec3 nebula_b : source_color = vec3(0.02, 0.12, 0.16);

float hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return 0.5 * vnoise(p) + 0.25 * vnoise(p * 2.1) + 0.125 * vnoise(p * 4.3) + 0.0625 * vnoise(p * 8.7);
}

float stars(vec3 d, float scale, float density) {
	vec3 g = d * scale;
	vec3 id = floor(g);
	vec3 f = fract(g) - 0.5;
	float h = hash(id);
	if (h < 1.0 - density) {
		return 0.0;
	}
	vec3 off = vec3(hash(id + 3.1), hash(id + 7.7), hash(id + 1.3)) - 0.5;
	float s = smoothstep(0.12, 0.0, length(f - off * 0.6));
	return s * (0.4 + 0.6 * (h - (1.0 - density)) / density);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 c = vec3(0.004, 0.005, 0.01);
	float n = fbm(d * 2.5 + 4.0);
	float n2 = fbm(d * 5.0 + 9.0);
	c += nebula_a * smoothstep(0.45, 0.8, n) * 0.6 + nebula_b * smoothstep(0.5, 0.85, n2) * 0.5;
	c += vec3(1.0, 0.95, 0.9) * (stars(d, 160.0, 0.025) + stars(d, 320.0, 0.03) * 0.6);
	c += vec3(0.7, 0.8, 1.0) * stars(d, 60.0, 0.006) * 2.0;
	// The planet.
	vec3 pd = normalize(planet_dir);
	float a = acos(clamp(dot(d, pd), -1.0, 1.0));
	if (a < planet_size) {
		// The sphere's normal where this ray meets it: facing us at the
		// middle, turning to the side at the rim.
		vec3 p = d - pd * cos(a);
		p = length(p) > 1e-5 ? normalize(p) : vec3(0.0, 1.0, 0.0);
		float r = clamp(sin(a) / sin(planet_size), 0.0, 1.0);
		vec3 nrm = normalize(p * r - pd * sqrt(1.0 - r * r));
		float lit = smoothstep(-0.25, 0.6, dot(nrm, normalize(sun_dir))) * 0.95 + 0.05;
		float bands = fbm(vec3(dot(d, vec3(0.2, 1.0, 0.1)) * 18.0, n * 2.0, 0.0));
		vec3 surf = mix(planet_color, band_color, smoothstep(0.35, 0.7, bands));
		c = surf * lit * 0.55;
		c += vec3(0.3, 0.55, 0.9) * pow(a / planet_size, 6.0) * lit * 0.6;
	} else {
		// A thin glow of atmosphere round the edge.
		c += vec3(0.25, 0.45, 0.8) * exp(-(a - planet_size) * 40.0) * 0.35;
	}
	COLOR = c;
}
