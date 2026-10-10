class_name BoatSites
extends RefCounted
## One boat of each kind at sea: a simple boat off the red district, a wooden boat and a
## fishing boat beside the piers, the cargo ship off the industrial port and the submarine
## in the sea north of the Golden Gate bridge, a good way from it. The seed of a boat is
## its kind (ModelPools.BOAT_CATS). Added at the end of the building list.

const Kind := CityTypes.Kind
const Terrain := CityTypes.Terrain
const Zone := CityTypes.Zone

const SIMPLE := 0
const WOODEN := 1
const FISHING := 2
const CARGO := 3
const SUB := 4

## Where the cargo ship looks for sea: west of the industrial port (the quay and cranes).
const CARGO_TARGET := Vector2i(66, 183)
## The submarine: offset from the end of the Golden Gate highway, and rows kept clear of the bridge.
const SUB_OFFSET := Vector2i(14, -17)
const BRIDGE_CLEAR := 6
## How far a search for sea goes, in cells.
const REACH := 14
## Sea north of the main island, where the wooden boat lies.
const NORTH_SEA := Vector2i(150, 30)
## Cells of open sea all round a pirate ship at sea, and the sea beside the graveyard islet.
const FAR_FROM_LAND := 10
const GRAVEYARD_SEA := Vector2i(139, 252)


static func apply(data: CityData) -> int:
	var taken := PackedByteArray()
	taken.resize(data.size * data.size)
	var piers: Array[Rect2i] = []
	var piers_facing: Array[int] = []
	var quarter_south := Vector2i(-1, -1)
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		if data.b_kind[b] == Kind.PIER:
			piers.append(r)
			piers_facing.append(data.b_facing[b])
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				taken[data.idx(x, y)] = 1
	for y in data.size:
		for x in data.size:
			if data.zone[data.idx(x, y)] == Zone.QUARTER and y > quarter_south.y:
				quarter_south = Vector2i(x, y)
	var forbid: Array[Rect2i] = []
	if data.bridge.x >= 0:
		forbid.append(Rect2i(data.bridge.x - 2, data.bridge.y - BRIDGE_CLEAR, 50, BRIDGE_CLEAR * 2 + 1))
	if data.west_bridge.x >= 0:
		var wb := data.west_bridge
		forbid.append(Rect2i(wb.y - 2, wb.z - BRIDGE_CLEAR, wb.x - wb.y + 6, BRIDGE_CLEAR * 2 + 1))

	var plan: Array = []
	plan.append([CARGO, CARGO_TARGET, Vector2i(4, 10), 2])
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
	plan.append([WOODEN, NORTH_SEA, Vector2i(3, 4), 2])
	# A second oil tanker north-west of the nuclear plant.
	plan.append([CARGO, Vector2i(40, 76), Vector2i(10, 4), 1])
	# Four more submarines all round the seas, far from each other.
	for t in [Vector2i(100, 16), Vector2i(16, 215), Vector2i(190, 262), Vector2i(250, 16)]:
		plan.append([SUB, t, Vector2i(4, 9), 2])
	# Four more pirate ships, always far from any beach, and one beside the graveyard islet.
	for t in [Vector2i(60, 252), Vector2i(130, 266), Vector2i(262, 70), Vector2i(170, 12)]:
		plan.append([0, t, Vector2i(7, 3), 2, FAR_FROM_LAND, Kind.PIRATE_SHIP])
	plan.append([0, GRAVEYARD_SEA, Vector2i(7, 3), 2, 0, Kind.PIRATE_SHIP])
	# Three more pirate ships and two more submarines.
	for t in [Vector2i(80, 20), Vector2i(200, 250), Vector2i(24, 250)]:
		plan.append([0, t, Vector2i(7, 3), 2, FAR_FROM_LAND, Kind.PIRATE_SHIP])
	for t in [Vector2i(216, 28), Vector2i(120, 242)]:
		plan.append([SUB, t, Vector2i(4, 9), 2])
	var placed := 0
	for p in plan:
		var far: int = p[4] if p.size() > 4 else 0
		var kind: int = p[5] if p.size() > 5 else Kind.BOAT
		var spot := _water(data, taken, p[1], p[2], forbid, far)
		if spot.size.x <= 0:
			push_warning("[Boats] no sea found for boat %d near %s" % [p[0], p[1]])
			continue
		data.add_building(spot, kind, p[3], p[0] if kind == Kind.BOAT else CityTypes.hash2(spot.position.x, spot.position.y, 66), 0.5)
		for y in range(spot.position.y - 1, spot.end.y + 1):
			for x in range(spot.position.x - 1, spot.end.x + 1):
				if data.in_bounds(x, y):
					taken[data.idx(x, y)] = 1
		placed += 1
	return placed


## The free rectangle of open sea closest to `target`, or an empty one.
static func _water(data: CityData, taken: PackedByteArray, target: Vector2i, size: Vector2i,
		forbid: Array[Rect2i], far: int = 0) -> Rect2i:
	for radius in REACH + 1:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var r := Rect2i(target + Vector2i(dx, dy) - size / 2, size)
				if _sea(data, taken, r, forbid) and (far <= 0 or _open_sea(data, r, far)):
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


## True when no land lies within `reach` cells of the rectangle (sampled every 3 cells).
static func _open_sea(data: CityData, r: Rect2i, reach: int) -> bool:
	for dy in range(-reach, reach + 1, 3):
		for dx in range(-reach, reach + 1, 3):
			var x := r.get_center().x + dx
			var y := r.get_center().y + dy
			if data.in_bounds(x, y) and data.terrain[data.idx(x, y)] >= Terrain.BEACH:
				return false
	return true
