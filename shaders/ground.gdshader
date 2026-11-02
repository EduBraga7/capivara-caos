shader_type canvas_item;
// Infinite procedural lawn. Everything is a function of world position,
// so it scrolls seamlessly with the camera and never repeats visibly.

uniform vec2 cam_pos = vec2(0.0);
uniform vec2 view_size = vec2(1280.0, 720.0);
uniform vec3 grass_a : source_color = vec3(0.38, 0.70, 0.31);
uniform vec3 grass_b : source_color = vec3(0.31, 0.62, 0.29);
uniform vec3 grass_c : source_color = vec3(0.50, 0.80, 0.38);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 wp = cam_pos + (UV - 0.5) * view_size;
	float n1 = vnoise(wp / 300.0);
	float n2 = vnoise(wp / 95.0 + 11.7);
	vec3 col = mix(grass_a, grass_b, smoothstep(0.32, 0.68, n1));
	col = mix(col, grass_c, smoothstep(0.58, 0.9, n2) * 0.55);

	// soft diagonal "mowed" bands
	float band = sin((wp.x + wp.y) / 120.0 + n1 * 3.0) * 0.5 + 0.5;
	col *= 0.965 + 0.035 * band;

	// grass flecks on a jittered grid
	vec2 g = wp / 30.0;
	vec2 cell = floor(g);
	vec2 cf = fract(g);
	float h = hash21(cell);
	vec2 cp = vec2(hash21(cell + 3.1), hash21(cell + 7.7)) * 0.6 + 0.2;
	vec2 d = (cf - cp) * vec2(1.0, 2.3);
	float fleck = smoothstep(0.17, 0.05, length(d));
	if (h > 0.62) {
		col = mix(col, col * 0.80, fleck * 0.9);
	} else if (h > 0.46) {
		col = mix(col, col * 1.16 + vec3(0.02, 0.04, 0.0), fleck * 0.8);
	}
	// rare tiny flowers
	if (h < 0.012) {
		float fl = smoothstep(0.11, 0.06, length((cf - cp)));
		vec3 fc = h < 0.006 ? vec3(1.0, 0.95, 0.5) : vec3(1.0, 1.0, 1.0);
		col = mix(col, fc, fl);
	}
	COLOR = vec4(col, 1.0);
}
