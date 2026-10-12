class_name MapAdditions
extends RefCounted
## Things added to the finished map, after the budget of the buildings and the rebuild of the
## urban island, all at the end of the building list (no number moves):
##   - SIMPLE_BOATS simple boats and CARGO_SHIPS cargo ships at random places of the seas,
##   - three oil silos side by side at the edge of the container yards of the port (three
##     yards in a row become silos: their lots and numbers stay),
##   - a helipad beside the bunker of the secret base (VehicleSites parks the helicopter on it).
## The aircraft carriers round the fog island are not here: that island is not part of the
## cell grid (FogIslandShaper.ships).

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone
const Terrain := CityTypes.Terrain

const SIMPLE_BOATS := 8
const CARGO_SHIPS := 4
## Lots of the boats (the long side along north-south; turned a quarter for one boat in two).
const SIMPLE_LOT := Vector2i(4, 5)
const CARGO_LOT := Vector2i(4, 10)
## Sea kept free round a boat, cells between two boats, and rows kept clear of the bridges.
const SEA_MARGIN := 3
## No boat this close to the edge of the map.
const EDGE := 12
const BOAT_GAP := 16.0
const BRIDGE_CLEAR := 7
## Seed of the random places (the same map on every device).
const SEED := 81203
const TRIES := 4000
## The silos stand on container yards within this many cells of a crane of the port.
const SILO_COUNT := 3
const PORT_REACH := 26
## Lot of the helipad, and the cells between it and the bunker.
const PAD := Vector2i(3, 3)
const PAD_GAP := 1


## Returns {"boats": n, "cargo": n, "silos": n, "helipad": Rect2i}.
static func apply(data: CityData) -> Dictionary:
	var out := {"silos": _silos(data), "helipad": _helipad(data)}
	out.merge(_boats(data))
	return out


# --- Boats ---------------------------------------------------------------------------------------
static func _boats(data: CityData) -> Dictionary:
	var taken := PackedByteArray()
	taken.resize(data.size * data.size)
	var boats: Array[Vector2] = []
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		if data.b_kind[b] == Kind.BOAT:
			boats.append(Vector2(r.get_center()))
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if data.in_bounds(x, y):
					taken[data.idx(x, y)] = 1
	var forbid: Array[Rect2i] = []
	if data.bridge.x >= 0:
		forbid.append(Rect2i(data.bridge.x - 2, data.bridge.y - BRIDGE_CLEAR, data.size, BRIDGE_CLEAR * 2 + 1))
	if data.west_bridge.x >= 0:
		var wb := data.west_bridge
		forbid.append(Rect2i(wb.y - 2, wb.z - BRIDGE_CLEAR, wb.x - wb.y + 6, BRIDGE_CLEAR * 2 + 1))
	# The east edge of the map lies under the fog island: its sea is not the sea of this grid.
	var east := data.size
	if data.fog != null:
		east = mini(east, int(data.fog.origin.x))
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var out := {"boats": 0, "cargo": 0}
	for job: Array in [["cargo", BoatSites.CARGO, CARGO_LOT, CARGO_SHIPS], ["boats", BoatSites.SIMPLE, SIMPLE_LOT, SIMPLE_BOATS]]:
		var lot: Vector2i = job[2]
		for n in int(job[3]):
			for t in TRIES:
				var across := rng.randi() % 2 == 1
				var size := Vector2i(lot.y, lot.x) if across else lot
				var r := Rect2i(Vector2i(rng.randi_range(EDGE, east - size.x - SEA_MARGIN),
						rng.randi_range(EDGE, data.size - size.y - EDGE)), size)
				if not _open_sea(data, taken, r, forbid) or _near_boat(boats, Vector2(r.get_center())):
					continue
				# The bow points along the long side of the lot, one way or the other.
				data.add_building(r, Kind.BOAT, (1 if across else 0) + 2 * (rng.randi() % 2), int(job[1]), 0.5)
				boats.append(Vector2(r.get_center()))
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						taken[data.idx(x, y)] = 1
				out[job[0]] += 1
				break
	if out["boats"] < SIMPLE_BOATS or out["cargo"] < CARGO_SHIPS:
		push_warning("[Additions] no sea for all the boats: %s" % out)
	return out


static func _near_boat(boats: Array[Vector2], p: Vector2) -> bool:
	for b in boats:
		if b.distance_to(p) < BOAT_GAP:
			return true
	return false


## `r` and SEA_MARGIN cells round it are water with nothing on it, away from the bridges.
static func _open_sea(data: CityData, taken: PackedByteArray, r: Rect2i, forbid: Array[Rect2i]) -> bool:
	for f in forbid:
		if f.intersects(r):
			return false
	for y in range(r.position.y - SEA_MARGIN, r.end.y + SEA_MARGIN):
		for x in range(r.position.x - SEA_MARGIN, r.end.x + SEA_MARGIN):
			if not data.in_bounds(x, y):
				return false
			var i := data.idx(x, y)
			if data.terrain[i] >= Terrain.BEACH or taken[i] == 1:
				return false
	return true


# --- Oil silos -------------------------------------------------------------------------------------
## Three container yards side by side (2x2 lots in a row) of the port become silos: the row
## with the fewest yards round it (the edge of the yards), then the one nearest to the camera.
static func _silos(data: CityData) -> int:
	var cranes: Array[Vector2] = []
	var yards := {}
	for b in data.building_count():
		var r := data.building_rect(b)
		if data.zone_at(r.position.x, r.position.y) != Zone.INDUSTRIAL:
			continue
		if data.b_kind[b] == Kind.CRANE:
			cranes.append(Vector2(r.get_center()))
		elif data.b_kind[b] == Kind.INDUSTRIAL_YARD and r.size == Vector2i(2, 2):
			yards[r.position] = b
	var best: Array[int] = []
	var best_score := -INF
	for p: Vector2i in yards:
		var row: Array[int] = []
		for k in SILO_COUNT:
			var q := p + Vector2i(2 * k, 0)
			if yards.has(q):
				row.append(yards[q])
		if row.size() < SILO_COUNT:
			continue
		var mid := Vector2(p) + Vector2(SILO_COUNT, 1)
		var near := false
		for c in cranes:
			if c.distance_to(mid) < PORT_REACH:
				near = true
		if not near:
			continue
		var around := 0
		var block := Rect2i(p, Vector2i(2 * SILO_COUNT, 2)).grow(3)
		for q: Vector2i in yards:
			if block.has_point(q) and not row.has(yards[q]):
				around += 1
		var score := -100.0 * around + float(p.x + p.y)
		if score > best_score:
			best_score = score
			best = row
	for b in best:
		data.b_kind[b] = Kind.SILO
		data.b_facing[b] = 2
	if best.is_empty():
		push_warning("[Additions] no row of container yards for the silos")
	return best.size()


# --- Helipad ----------------------------------------------------------------------------------------
## The helipad stands beside the bunker of the secret base: on one of its sides first (the
## cars park at its front), then behind it.
static func _helipad(data: CityData) -> Rect2i:
	var bunker := -1
	for b in data.building_count():
		if data.b_kind[b] == Kind.BUNKER:
			bunker = b
	if bunker < 0:
		return Rect2i()
	var r := data.building_rect(bunker)
	var front: Vector2i = CityTypes.FACING_OFFSETS[data.b_facing[bunker]]
	var side := Vector2i(-front.y, front.x)
	var c := r.get_center()
	var tries: Array[Vector2i] = []
	for reach in range(PAD_GAP, PAD_GAP + 4):
		for dir: Vector2i in [side, -side, -front]:
			# Centre of the pad: `reach` cells clear of the lot of the bunker on that side.
			var half := (r.size.x if dir.x != 0 else r.size.y) / 2 + reach + PAD.x / 2 + 1
			tries.append(c + dir * half)
	for at in tries:
		var lot := Rect2i(at - PAD / 2, PAD)
		if _pad_free(data, lot):
			data.add_building(lot, Kind.HELIPAD, 2, 0, 0.3)
			return lot
	push_warning("[Additions] no room for the helipad beside the bunker")
	return Rect2i()


## Dry ground of the desert or of the base, no road, outside the fence of the base, and no
## building within a cell.
static func _pad_free(data: CityData, lot: Rect2i) -> bool:
	for y in range(lot.position.y, lot.end.y):
		for x in range(lot.position.x, lot.end.x):
			if not data.in_bounds(x, y):
				return false
			var i := data.idx(x, y)
			if data.terrain[i] != Terrain.LAND or data.road[i] != 0:
				return false
			if data.zone[i] != Zone.DESERT and data.zone[i] != Zone.CIVIC:
				return false
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY:
			continue
		if data.building_rect(b).grow(1).intersects(lot):
			return false
		if data.b_kind[b] == Kind.AIRBASE:
			var ring: Rect2i = AmenitiesPlanner.base_fence(data.building_rect(b))["rect"]
			if ring.intersects(lot):
				return false
	return true
