extends SceneTree
## Counts, per kind of building, how many face a road, touch one, or stand away from it.
## Run: godot --headless --script res://tests/dump_facing.gd

const Kind := CityTypes.Kind


func _init() -> void:
	var cfg := CityConfig.create()
	var data := CityGenerator.new(cfg).generate()
	var stats := {}
	for b in data.building_count():
		var kind: int = data.b_kind[b]
		if kind == Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		var f: int = data.b_facing[b]
		if String(data.b_model.get(b, "")).begins_with("shop:"):
			f = (f + 2) % 4 # the shops of the catalog store the opposite of their front
		var gap := _gap(data, r, f)
		var best := 99
		for s in 4:
			best = mini(best, _gap(data, r, s))
		if gap != 0 and (kind == Kind.SHOP or kind == Kind.POOR_BLDG):
			print("[Facing] no road: %s at %s, gap %d, model '%s', sign %d, b%d" % [Kind.find_key(kind), r.position, gap, data.b_model.get(b, ""), data.b_sign[b], b])
		var key := String(Kind.find_key(kind))
		if not stats.has(key):
			stats[key] = {"n": 0, "face_touch": 0, "face_gap": 0, "face_none": 0, "other_touch": 0, "isolated": 0}
		var st: Dictionary = stats[key]
		st["n"] += 1
		if gap == 0:
			st["face_touch"] += 1
		elif gap < 99:
			st["face_gap"] += 1
		else:
			st["face_none"] += 1
			if best == 0:
				st["other_touch"] += 1
			elif best == 99:
				st["isolated"] += 1
	var keys := stats.keys()
	keys.sort_custom(func(a, b): return stats[a]["n"] > stats[b]["n"])
	for k in keys:
		var s: Dictionary = stats[k]
		if s["n"] < 5:
			continue
		print("[Facing] %-16s n=%4d  face+touch=%4d  face+gap=%4d  face-no-road=%4d (a side touches: %d, isolated: %d)" % [
				k, s["n"], s["face_touch"], s["face_gap"], s["face_none"], s["other_touch"], s["isolated"]])
	quit()


## Cells between the side `f` of `r` and the nearest road straight out from it (0 = touching), 99 = none within 6.
func _gap(data: CityData, r: Rect2i, f: int) -> int:
	var o := CityTypes.FACING_OFFSETS[f]
	var best := 99
	var cells := LotPlanner._side_cells(r, f)
	for c in cells:
		for d in 6:
			var p: Vector2i = c + o * d
			if not data.in_bounds(p.x, p.y):
				break
			if data.road[data.idx(p.x, p.y)] != 0:
				best = mini(best, d)
				break
	return best
