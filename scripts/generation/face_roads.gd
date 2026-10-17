class_name FaceRoads
extends RefCounted
## The last review of the ordinary buildings of Chat City (houses, shops, flats, offices, quarter and poor
## buildings): every one faces a road and touches it.
##   - the front is a side with a road right beside it; when two or more sides have one, south is
##     preferred, then east (the camera sees those faces), then west, then north;
##   - a building that has no road beside it but one a few cells away on some side faces that road and its
##     lot moves up to it, when the cells in between are free;
##   - a building that cannot touch any road is deleted (its lot stays empty);
##   - buildings with a model chosen by hand, a sign, or that are not in KINDS are left as they are.
## Run at the very end of the generation (before the chunk index), so that nothing turns them again.

const Kind := CityTypes.Kind

const KINDS: Array[int] = [Kind.HOUSE, Kind.SHOP, Kind.APARTMENT, Kind.OFFICE, Kind.QUARTER_BLDG, Kind.POOR_BLDG]
## Kinds deleted when they do not touch the road they face, even when made by hand.
const DROP_KINDS: Array[int] = [Kind.SHOP, Kind.POOR_BLDG]
## Preference of a facing (0 N, 1 E, 2 S, 3 W): south first, then east.
const PREF: Array[int] = [1, 3, 4, 2]
## How far a road may be (cells) for the building to move up to it.
const REACH := 3
const SHOP_PREFIX := "shop:"


## A building that still cannot touch a road (none within REACH, or the way is blocked) is deleted.
## Returns {"turned": n, "moved": n, "removed": n, "checked": n}.
static func apply(data: CityData) -> Dictionary:
	var turned := 0
	var moved := 0
	var checked := 0
	var removed := 0
	# Cells under a lot (data.occupied is only made at the end of the generation).
	var own := PackedByteArray()
	own.resize(data.size * data.size)
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY:
			continue
		var br := data.building_rect(b)
		for y in range(br.position.y, br.end.y):
			for x in range(br.position.x, br.end.x):
				if data.in_bounds(x, y):
					own[data.idx(x, y)] = 1
	for b in data.building_count():
		if not KINDS.has(int(data.b_kind[b])):
			continue
		var model := String(data.b_model.get(b, ""))
		if data.b_sign[b] != 0 or data.b_more_signs.has(b) or (data.b_model.has(b) and not model.begins_with(SHOP_PREFIX)):
			# Left as they are (hand-made), but a shop or poor building that does not touch the road it faces goes.
			if DROP_KINDS.has(int(data.b_kind[b])) and _gap(data, own, data.building_rect(b), int(data.b_facing[b])) != 0:
				data.b_kind[b] = Kind.EMPTY
				removed += 1
			continue
		checked += 1
		# The shops of the catalog are modelled the other way round: b_facing is the opposite of their front.
		var flip := 2 if model.begins_with(SHOP_PREFIX) else 0
		var r := data.building_rect(b)
		var current := (int(data.b_facing[b]) + flip) % 4
		var gaps: Array[int] = []
		for f in 4:
			gaps.append(_gap(data, own, r, f))
		var want := _choose(gaps, current)
		if want < 0:
			data.b_kind[b] = Kind.EMPTY
			removed += 1
			continue
		if want != current:
			data.b_facing[b] = (want + flip) % 4
			turned += 1
		if gaps[want] > 0:
			if _move_up(data, own, b, r, want, gaps[want]):
				moved += 1
			else:
				data.b_kind[b] = Kind.EMPTY
				removed += 1
	return {"checked": checked, "turned": turned, "moved": moved, "removed": removed}


## The facing to use, or -1 when no road is within REACH on any side.
static func _choose(gaps: Array[int], current: int) -> int:
	var best := -1
	var best_gap := REACH + 1
	for f in 4:
		if gaps[f] > REACH:
			continue
		if gaps[f] < best_gap or (gaps[f] == best_gap and PREF[f] > PREF[best]):
			best = f
			best_gap = gaps[f]
	if best >= 0 and gaps[current] == best_gap and PREF[current] >= PREF[best]:
		return current
	return best


## Free cells between the side `f` of `r` and the nearest road straight out of it (0 = touching),
## REACH + 1 when there is none; a building or the sea in the way counts as no road.
static func _gap(data: CityData, own: PackedByteArray, r: Rect2i, f: int) -> int:
	var o := CityTypes.FACING_OFFSETS[f]
	var best := REACH + 1
	for c in LotPlanner._side_cells(r, f):
		for d in REACH + 1:
			var p: Vector2i = c + o * d
			if not data.in_bounds(p.x, p.y):
				break
			var i := data.idx(p.x, p.y)
			if data.road[i] != 0:
				best = mini(best, d)
				break
			if own[i] != 0 or data.terrain[i] != CityTypes.Terrain.LAND:
				break
	return best


## Moves the lot `gap` cells towards the road at its side `f`.
static func _move_up(data: CityData, own: PackedByteArray, b: int, r: Rect2i, f: int, gap: int) -> bool:
	var o := CityTypes.FACING_OFFSETS[f]
	for c in LotPlanner._side_cells(r, f):
		for d in gap: # the cells between the lot and the road (the road itself is at d = gap)
			var p: Vector2i = c + o * d
			if not data.in_bounds(p.x, p.y):
				return false
			var i := data.idx(p.x, p.y)
			if data.road[i] != 0 or own[i] != 0 or data.terrain[i] != CityTypes.Terrain.LAND:
				return false
	var moved := Rect2i(r.position + o * gap, r.size)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			own[data.idx(x, y)] = 0
	for y in range(moved.position.y, moved.end.y):
		for x in range(moved.position.x, moved.end.x):
			own[data.idx(x, y)] = 1
	data.set_building_rect(b, moved)
	return true
