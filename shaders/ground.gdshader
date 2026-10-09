shader_type spatial;
// Island ground and sea: one large plane. Elevation (linear filtered) draws a
// smooth coastline; the zone texture (one texel per cell) colours the land.
// Outside the map the clamped border texels are deep sea.

uniform sampler2D elevation_tex : filter_linear, repeat_disable;
uniform sampler2D zone_tex : source_color, filter_nearest, repeat_disable;
uniform float beach_level = 0.035;
uniform float shallow_level = 0.10;
uniform vec3 deep_color : source_color = vec3(0.16, 0.45, 0.66);
uniform vec3 shallow_color : source_color = vec3(0.30, 0.68, 0.80);
uniform vec3 sand_color : source_color = vec3(0.91, 0.83, 0.60);
uniform vec3 wet_sand_color : source_color = vec3(0.80, 0.74, 0.55);
uniform vec3 rock_color : source_color = vec3(0.60, 0.47, 0.33);
uniform float map_size = 640.0;
// The island hidden in the fog, east of the map (FogIslandShaper).
uniform sampler2D fog_elevation_tex : filter_linear, repeat_disable;
uniform sampler2D fog_zone_tex : source_color, filter_nearest, repeat_disable;
uniform vec2 fog_origin = vec2(-100000.0);
uniform float fog_size = 128.0;

varying vec2 map_uv;

void vertex() {
	map_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz / map_size;
}

void fragment() {
	vec2 uv = clamp(map_uv, vec2(0.0), vec2(1.0));
	float e = texture(elevation_tex, uv).r - 128.0 / 255.0;
	vec4 zone = texture(zone_tex, uv);
	vec2 fog_uv = (map_uv * map_size - fog_origin) / fog_size;
	if (fog_uv.x >= 0.0 && fog_uv.y >= 0.0 && fog_uv.x <= 1.0 && fog_uv.y <= 1.0) {
		e = texture(fog_elevation_tex, fog_uv).r - 128.0 / 255.0;
		zone = texture(fog_zone_tex, fog_uv);
	}
	vec3 land = zone.rgb;
	vec3 col;
	if (e < 0.0) {
		float t = clamp(-e / shallow_level, 0.0, 1.0);
		col = mix(shallow_color, deep_color, smoothstep(0.0, 1.0, t));
		// Light rim of surf along the shore.
		col = mix(col, vec3(0.85, 0.93, 0.95), smoothstep(-0.006, 0.0, e) * 0.6);
	} else if (e < beach_level) {
		col = mix(wet_sand_color, sand_color, smoothstep(0.0, beach_level * 0.5, e));
		col = mix(rock_color, col, zone.a);
		// Alpha 0.5 = quay or coast without beach (port, desert): the land colour reaches the sea.
		float quay = step(0.4, zone.a) * (1.0 - step(0.6, zone.a));
		col = mix(col, land * 0.92, quay);
	} else {
		col = land;
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
