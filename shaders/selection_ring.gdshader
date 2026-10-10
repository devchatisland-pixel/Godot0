shader_type spatial;
// A glowing frame on the ground around the selected building, with a wave that keeps
// leaving it. UV 0..1 spans the quad; `half_size` is the footprint's half size in the
// quad's units (0..0.5 of the quad).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 ring_color : source_color = vec3(1.0, 0.72, 0.18);
uniform vec2 half_size = vec2(0.3, 0.3);
uniform float thickness = 0.012;

void fragment() {
	vec2 p = UV - vec2(0.5);
	vec2 q = abs(p) - half_size;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0); // distance to the footprint edge
	float frame = 1.0 - smoothstep(thickness, thickness * 2.2, abs(d));
	float wave_pos = fract(TIME * 0.55) * 0.12;
	float wave = (1.0 - smoothstep(0.0, thickness * 2.0, abs(d - wave_pos))) * (1.0 - fract(TIME * 0.55));
	float fill = (1.0 - smoothstep(-0.02, 0.0, d)) * (0.10 + 0.07 * sin(TIME * 5.0));
	float a = clamp(frame + wave * 0.8 + fill, 0.0, 1.0);
	ALBEDO = ring_color * a;
	ALPHA = a;
}
