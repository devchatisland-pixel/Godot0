shader_type spatial;
// One sheet of the fog bank over the hidden island. Three samples of a
// photographic cloud texture (tools/make_fog_textures.py) drift with the wind
// at different scales; their sum is the density. Holes open and close, so the
// buildings below show through now and then. Darker where the fog is thin.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 center = vec2(0.0);
uniform vec2 radius = vec2(50.0);
uniform float density = 0.8;
uniform float scale = 0.02;
uniform vec2 wind = vec2(0.006, 0.003);
uniform float seed = 0.0;
// The fog stays away from the Golden Gate: x range of the bridge, its row, clear radius and fade width.
uniform vec3 clear_seg = vec3(-1000.0, -1000.0, 0.0);
uniform float clear_radius = 14.0;
uniform float clear_fade = 18.0;
uniform float night = 0.0;
uniform vec3 day_light : source_color = vec3(0.92, 0.92, 0.94);
uniform vec3 day_shadow : source_color = vec3(0.42, 0.44, 0.50);
uniform vec3 night_light : source_color = vec3(0.30, 0.33, 0.42);
uniform vec3 night_shadow : source_color = vec3(0.10, 0.11, 0.16);

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv = wpos * scale + vec2(seed, seed * 0.7);
	float a = texture(noise_tex, uv + TIME * wind).r;
	float b = texture(noise_tex, uv * 2.3 - TIME * wind * 1.7 + 0.37).r;
	float c = texture(noise_tex, uv * 0.45 + TIME * wind * 0.5 + 0.71).r;
	float d = a * 0.5 + b * 0.25 + c * 0.55;
	vec2 q = (wpos - center) / radius;
	float mask = 1.0 - smoothstep(0.7, 1.2, length(q));
	vec3 lit = mix(day_light, night_light, night);
	vec3 shade = mix(day_shadow, night_shadow, night);
	ALBEDO = mix(shade, lit, smoothstep(0.3, 1.15, d));
	ALPHA = clamp(smoothstep(0.24, 0.85, d) * mask * density, 0.0, 1.0);
	float dx = max(max(clear_seg.x - wpos.x, wpos.x - clear_seg.y), 0.0);
	float dist_to_bridge = length(vec2(dx, wpos.y - clear_seg.z));
	ALPHA *= smoothstep(clear_radius, clear_radius + clear_fade, dist_to_bridge);
}
