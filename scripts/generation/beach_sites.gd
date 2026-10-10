class_name BeachSites
extends RefCounted
## A few huts on the beaches of the main island, most of them with a pier running out
## into the sea. Added at the end of the building list, so no number moves.
## A site is a hut on dry land, the beach in front of it and open water beyond.

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone
const Terrain := CityTypes.Terrain

## How many huts, how far apart (cells), and how many of them get a pier.
const SITES := 5
const MIN_GAP := 50.0
const PIERS := 3
## Minimum distance of the two extra piers from the other huts.
const EXTRA_GAP := 9.0
## Cells of a pier over the sea, and its width.
const PIER_WATER := 3
const PIER_WIDTH := 2
## The zones a hut may stand on.
const ZONES := [Zone.NATURE, Zone.SAND]
const SEED := 4711


## Adds the sites; returns how many huts.
static func apply(data: CityData) -> int:
	var taken := PackedByteArray()
	taken.resize(data.size * data.size)
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				taken[data.idx(x, y)] = 1
	var found: Array = []
	for y in range(8, data.size - 8):
		for x in range(8, data.size - 8):
			if data.terrain[data.idx(x, y)] != Terrain.BEACH:
				continue
			for f in 4:
				var site := _site(data, taken, Vector2i(x, y), f)
				if not site.is_empty():
					site["key"] = CityTypes.hash2(x, y, SEED)
					found.append(site)
	found.sort_custom(func(a, b): return a["key"] < b["key"])
	var chosen: Array = []
	for s in found:
		var c := Vector2((s["hut"] as Rect2i).get_center())
		var apart := true
		for o in chosen:
			if Vector2((o["hut"] as Rect2i).get_center()).distance_to(c) < MIN_GAP:
				apart = false
		if apart:
			chosen.append(s)
			if chosen.size() >= SITES:
				break
	# Two more sites close to the first one (the fishing boat lies off it).
	if not chosen.is_empty():
		var around := Vector2((chosen[0]["hut"] as Rect2i).get_center())
		var near: Array = found.filter(func(f): return Vector2((f["hut"] as Rect2i).get_center()).distance_to(around) < 45.0)
		near.sort_custom(func(a, b): return Vector2((a["hut"] as Rect2i).get_center()).distance_to(around) < Vector2((b["hut"] as Rect2i).get_center()).distance_to(around))
		var extra := 0
		for s in near:
			var c := Vector2((s["hut"] as Rect2i).get_center())
			var apart := true
			for o in chosen:
				if Vector2((o["hut"] as Rect2i).get_center()).distance_to(c) < EXTRA_GAP:
					apart = false
			if apart:
				chosen.append(s)
				extra += 1
				if extra >= 2:
					break
	for k in chosen.size():
		var s: Dictionary = chosen[k]
		data.add_building(s["hut"], Kind.BEACH_HUT, s["facing"], CityTypes.hash2(k, 17, SEED), 0.5)
		if k < PIERS or k >= SITES:
			data.add_building(s["pier"], Kind.PIER, s["facing"], CityTypes.hash2(k, 23, SEED), 0.5)
	return chosen.size()


## The site whose sea side is the beach cell `b` looking towards `facing`, or {}.
static func _site(data: CityData, taken: PackedByteArray, b: Vector2i, facing: int) -> Dictionary:
	var d: Vector2i = CityTypes.FACING_OFFSETS[facing]
	# The beach cell must be the inland-most of its row: land behind it, water ahead.
	var behind := b - d
	if not _land(data, taken, behind):
		return {}
	var n := 0
	var p := b
	while data.in_bounds(p.x, p.y) and data.terrain[data.idx(p.x, p.y)] == Terrain.BEACH \
			and data.rocky[data.idx(p.x, p.y)] == 0 and taken[data.idx(p.x, p.y)] == 0:
		n += 1
		p += d
	if n < 1 or n > 3:
		return {}
	for w in PIER_WATER:
		if not data.in_bounds(p.x, p.y) or data.terrain[data.idx(p.x, p.y)] >= Terrain.BEACH \
				or taken[data.idx(p.x, p.y)] == 1:
			return {}
		p += d
	# Hut: 2x2 on the land behind the beach; pier: 2 wide from the beach into the water.
	var side := Vector2i(-d.y, d.x)
	var hut_cells := [behind, behind + side, behind - d, behind - d + side]
	for c in hut_cells:
		if not _land(data, taken, c):
			return {}
	var pier_cells := []
	for k in n + PIER_WATER:
		for w in PIER_WIDTH:
			pier_cells.append(b + d * k + side * w)
	for c in pier_cells:
		if not data.in_bounds(c.x, c.y) or data.road[data.idx(c.x, c.y)] != 0:
			return {}
	return {"hut": _bounds(hut_cells), "pier": _bounds(pier_cells), "facing": facing}


static func _land(data: CityData, taken: PackedByteArray, c: Vector2i) -> bool:
	if not data.in_bounds(c.x, c.y):
		return false
	var i := data.idx(c.x, c.y)
	return data.terrain[i] == Terrain.LAND and data.road[i] == 0 and taken[i] == 0 \
			and ZONES.has(int(data.zone[i]))


static func _bounds(cells: Array) -> Rect2i:
	var r := Rect2i(cells[0], Vector2i.ONE)
	for c in cells:
		r = r.expand(c)
		r = r.expand(c + Vector2i.ONE)
	return r
