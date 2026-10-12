class_name BoatSites
extends RefCounted
## One boat of each kind at sea: a simple boat off the red district, a wooden boat and a
## fishing boat beside the piers, the cargo ship off the industrial port and the submarine
## in the sea north of the Golden Gate bridge, a good way from it. The seed of a boat is
## its kind (ModelPools.BOAT_CATS). Added at the end of the building list.
## `scatter_submarines` adds more submarines at random places of the open sea (MapOverhaul).

const Kind := CityTypes.Kind
const Terrain := CityTypes.Terrain
const Zone := CityTypes.Zone

const SIMPLE := 0
const WOODEN := 1
const FISHING := 2
const CARGO := 3
const SUB := 4

## The submarine: offset from the end of the Golden Gate highway, and rows kept clear of the bridge.
const SUB_OFFSET := Vector2i(14, -17)
const BRIDGE_CLEAR := 6
## How far a search for sea goes, in cells.
const REACH := 14


static func apply(data: CityData) -> int:
	var taken := _taken_cells(data)
	var piers: Array[Rect2i] = []
	var piers_facing: Array[int] = []
	var quarter_south := Vector2i(-1, -1)
	for b in data.building_count():
		if data.b_kind[b] == Kind.PIER:
			piers.append(data.building_rect(b))
			piers_facing.append(data.b_facing[b])
	for y in data.size:
		for x in data.size:
			if data.zone[data.idx(x, y)] == Zone.QUARTER and y > quarter_south.y:
				quarter_south = Vector2i(x, y)
	var forbid := _bridge_strips(data)

	var plan: Array = []
	plan.append([CARGO, MapLayout.point("cargo_ship"), Vector2i(4, 10), 2])
	if data.bridge.x >= 0:
		plan.append([SUB, data.bridge + SUB_OFFSET, Vector2i(4, 9), 2])
	if quarter_south.x >= 0:
		plan.append([SIMPLE, quarter_south + Vector2i(0, 9), Vector2i(4, 5), 2])
	for k in mini(2, piers.size()):
		var r := piers[k]
		var d: Vector2i = CityTypes.FACING_OFFSETS[piers_facing[k]]
		var out := Vector2i(r.get_center()) + d * (maxi(r.size.x, r.size.y) / 2 + 5)
		var side := Vector2i(-d.y, d.x) * 3
		if k == 0:
			plan.append([FISHING, out + side, Vector2i(5, 3), 1])
	# The wooden boat lies off the north coast of the main island.
	plan.append([WOODEN, MapLayout.point("north_sea"), Vector2i(3, 4), 2])
	# A second oil tanker north-west of the nuclear plant.
	plan.append([CARGO, MapLayout.point("tanker"), Vector2i(10, 4), 1])
	# Four more submarines all round the seas, far from each other.
	for t in MapLayout.points("submarines_a"):
		plan.append([SUB, t, Vector2i(4, 9), 2])
	# Two more submarines.
	for t in MapLayout.points("submarines_b"):
		plan.append([SUB, t, Vector2i(4, 9), 2])
	var placed := 0
	for p in plan:
		var spot := _water(data, taken, p[1], p[2], forbid)
		if spot.size.x <= 0:
			push_warning("[Boats] no sea found for boat %d near %s" % [p[0], p[1]])
			continue
		data.add_building(spot, Kind.BOAT, p[3], p[0], 0.5)
		for y in range(spot.position.y - 1, spot.end.y + 1):
			for x in range(spot.position.x - 1, spot.end.x + 1):
				if data.in_bounds(x, y):
					taken[data.idx(x, y)] = 1
		placed += 1
	return placed


## Cells under a building (1), the rest 0.
static func _taken_cells(data: CityData) -> PackedByteArray:
	var taken := PackedByteArray()
	taken.resize(data.size * data.size)
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				taken[data.idx(x, y)] = 1
	return taken


## Rows kept clear of boats along the two bridges.
static func _bridge_strips(data: CityData) -> Array[Rect2i]:
	var forbid: Array[Rect2i] = []
	if data.bridge.x >= 0:
		forbid.append(Rect2i(data.bridge.x - 2, data.bridge.y - BRIDGE_CLEAR, 50, BRIDGE_CLEAR * 2 + 1))
	if data.west_bridge.x >= 0:
		var wb := data.west_bridge
		forbid.append(Rect2i(wb.y - 2, wb.z - BRIDGE_CLEAR, wb.x - wb.y + 6, BRIDGE_CLEAR * 2 + 1))
	return forbid


## Adds `count` submarines on open sea picked at random all over the map, at least `apart`
## cells from each other (and not on another boat, nor near a bridge). Returns how many were
## placed.
static func scatter_submarines(data: CityData, count: int, apart: int, rng: RandomNumberGenerator) -> int:
	var taken := _taken_cells(data)
	var forbid := _bridge_strips(data)
	var centres: Array[Vector2i] = []
	for b in data.building_count():
		if data.b_kind[b] == Kind.BOAT and data.b_seed[b] == SUB:
			centres.append(data.building_rect(b).get_center())
	var placed := 0
	var tries := 0
	while placed < count and tries < 4000:
		tries += 1
		var east_west := rng.randi() % 2 == 0
		var size := Vector2i(9, 4) if east_west else Vector2i(4, 9)
		var at := Vector2i(rng.randi_range(2, data.size - 3), rng.randi_range(2, data.size - 3))
		var r := Rect2i(at - size / 2, size)
		var c := r.get_center()
		var crowded := false
		for o in centres:
			if Vector2(o).distance_to(Vector2(c)) < float(apart):
				crowded = true
				break
		if crowded or not _sea(data, taken, r, forbid):
			continue
		data.add_building(r, Kind.BOAT, 1 if east_west else 2, SUB, 0.5)
		centres.append(c)
		for y in range(r.position.y - 1, r.end.y + 1):
			for x in range(r.position.x - 1, r.end.x + 1):
				taken[data.idx(x, y)] = 1
		placed += 1
	if placed < count:
		push_warning("[Boats] only %d of %d submarines found open sea" % [placed, count])
	return placed


## The free rectangle of open sea closest to `target`, or an empty one.
static func _water(data: CityData, taken: PackedByteArray, target: Vector2i, size: Vector2i,
		forbid: Array[Rect2i]) -> Rect2i:
	for radius in REACH + 1:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var r := Rect2i(target + Vector2i(dx, dy) - size / 2, size)
				if _sea(data, taken, r, forbid):
					return r
	return Rect2i()


static func _sea(data: CityData, taken: PackedByteArray, r: Rect2i, forbid: Array[Rect2i]) -> bool:
	for f in forbid:
		if f.intersects(r):
			return false
	for y in range(r.position.y - 1, r.end.y + 1):
		for x in range(r.position.x - 1, r.end.x + 1):
			if not data.in_bounds(x, y):
				return false
			var i := data.idx(x, y)
			if data.terrain[i] >= Terrain.BEACH or taken[i] == 1:
				return false
	return true
