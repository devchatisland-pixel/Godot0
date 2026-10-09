class_name CoreEmbed
extends RefCounted
## Copies the finished core city into the middle of the bigger map. Every
## layer and every building moves by the same offset, so the original city is
## exactly as it was generated.


static func copy(core: CityData, dst: CityData, offset: int) -> void:
	var cs := core.size
	for y in cs:
		var src_row := y * cs
		var dst_row := (y + offset) * dst.size + offset
		for x in cs:
			var s := src_row + x
			var d := dst_row + x
			dst.terrain[d] = core.terrain[s]
			dst.zone[d] = core.zone[s]
			dst.road[d] = core.road[s]
			dst.elevation[d] = core.elevation[s]
			dst.forest[d] = core.forest[s]
			dst.rocky[d] = core.rocky[s]
	for b in core.building_count():
		var r := core.building_rect(b)
		dst.add_building(Rect2i(r.position + Vector2i(offset, offset), r.size), core.b_kind[b],
				core.b_facing[b], core.b_seed[b], core.b_height[b])
	if core.bridge.x >= 0:
		dst.bridge = core.bridge + Vector2i(offset, offset)
	dst.centers = [Vector2(dst.size, dst.size) * 0.5]
	dst.center_weights = PackedFloat32Array([1.0])
