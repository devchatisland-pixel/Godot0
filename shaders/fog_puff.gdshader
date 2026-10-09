shader_type spatial;
// Billows of fog and smoke: camera-facing quads showing a painted cloud
// (textures/fog_puffs.png, 2x2 sheet). They drift and turn very slowly.
// INSTANCE_CUSTOM: x = picture (0..3) / 4, y = phase, z = opacity, w = darkness.
// No depth test: the billows are never cut by the ground they hang over.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D puff_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float night = 0.0;
uniform vec3 night_tint : source_color = vec3(0.30, 0.33, 0.44);
uniform vec3 smoke_tint : source_color = vec3(0.42, 0.42, 0.44);

varying vec4 custom;

void vertex() {
	custom = INSTANCE_CUSTOM;
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 origin = MODEL_MATRIX[3].xyz;
	float ph = custom.y * 6.2831;
	origin.x += sin(TIME * 0.045 + ph) * 2.5;
	origin.z += cos(TIME * 0.035 + ph) * 1.8;
	origin.y += sin(TIME * 0.06 + ph * 2.0) * 0.4;
	float ang = ph + TIME * 0.008 * (custom.y > 0.5 ? 1.0 : -1.0);
	vec2 v = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * VERTEX.xy;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = origin + (right * v.x + up * v.y) * s;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
	float idx = floor(custom.x * 4.0 + 0.5);
	UV = UV * 0.5 + vec2(mod(idx, 2.0), floor(idx / 2.0)) * 0.5;
}

void fragment() {
	vec4 t = texture(puff_tex, UV);
	vec3 col = mix(t.rgb, t.rgb * smoke_tint, custom.w);
	ALBEDO = col * mix(vec3(1.0), night_tint, night);
	ALPHA = t.a * custom.z;
}
