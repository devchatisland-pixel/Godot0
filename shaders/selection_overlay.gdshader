shader_type spatial;
// Laid over the selected building (material_overlay): a pulsing glowing skin with a bright
// rim, so the building clearly stands out. Additive, unshaded: costs one extra draw.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 glow_color : source_color = vec3(1.0, 0.72, 0.18);

void vertex() {
	VERTEX += NORMAL * 0.03;
}

void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * 5.0);
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	ALBEDO = glow_color * (0.16 + 0.22 * pulse + rim * 1.1);
}
