class_name DevIsland
extends RefCounted
## The street and the little port of the development island (Zone.DEV), drawn on the finished
## map (after MuseumSite). No model for the port: only its ground and roads.
##   - a two-lane street from the west to the east end of the island, along its middle line;
##     the shops stand north of it and the modular buildings south of it (ShopSites);
##   - at the east end a port road runs south to the coast and onto a quay: a flat paved
##     platform built out over the sea, with a road along its edge.
## Nothing is random: the shape of the island decides.

const Zone := CityTypes.Zone
const Terrain := CityTypes.Terrain

## Lanes of the street (rows of cells, the first one on the middle line of the island).
const STREET_LANES := 2
## The port road leaves the street this many cells before the east end of the street.
const PORT_FROM_END := 5
## The quay: how far it reaches out over the sea (cells), its width along the coast, and how
## deep the water must be under its far edge.
const QUAY_OUT := 6
const QUAY_WIDTH := 12


## Returns {"street": cells, "port": cells of the port road, "quay": cells of new ground}.
static func apply(data: CityData) -> Dictionary:
	var lo := Vector2i(data.size, data.size)
	var hi := Vector2i(-1, -1)
	for y in data.size:
		for x in data.size:
			if _dev_land(data, x, y):
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0:
		push_warning("[DevIsland] no development island on this map")
		return {"street": 0, "port": 0, "quay": 0}
	var yc := (lo.y + hi.y) / 2
	# The street: the longest run of dry land of the middle line (every lane must be dry).
	var run := Vector2i(-1, -2)
	var start := -1
	for x in range(lo.x, hi.x + 2):
		var ok := x <= hi.x
		for k in STREET_LANES:
			ok = ok and _dev_land(data, x, yc + k)
		if ok and start < 0:
			start = x
		elif not ok and start >= 0:
			if x - start > run.y - run.x + 1:
				run = Vector2i(start, x - 1)
			start = -1
	var street := 0
	for x in range(run.x, run.y + 1):
		for k in STREET_LANES:
			data.road[data.idx(x, yc + k)] = CityTypes.ROAD_STREET
			street += 1

	# The port road: south from the street to the last dry cell, then the quay beyond it.
	var px := run.y - PORT_FROM_END
	var port := 0
	var y := yc + STREET_LANES
	while _dev_land(data, px, y) and _dev_land(data, px + 1, y):
		data.road[data.idx(px, y)] = CityTypes.ROAD_STREET
		data.road[data.idx(px + 1, y)] = CityTypes.ROAD_STREET
		port += 2
		y += 1
	var shore := y # first cell past the dry land
	var ground := data.elevation[data.idx(px, shore - 1)]
	var quay := 0
	var x0 := px - QUAY_WIDTH / 2 + 1
	for qy in range(shore - 1, shore + QUAY_OUT):
		for qx in range(x0, x0 + QUAY_WIDTH):
			if not data.in_bounds(qx, qy):
				continue
			var i := data.idx(qx, qy)
			if data.terrain[i] == Terrain.LAND and qy < shore:
				continue
			if data.terrain[i] != Terrain.LAND:
				quay += 1
			data.terrain[i] = Terrain.LAND
			data.zone[i] = Zone.DEV
			data.elevation[i] = maxi(ground, 138)
			data.forest[i] = 0
			data.rocky[i] = 0
	# The port road goes on to the far edge of the quay, and a road runs along that edge.
	var edge := shore + QUAY_OUT - 2
	for qy in range(shore, edge + 1):
		for k in 2:
			data.road[data.idx(px + k, qy)] = CityTypes.ROAD_STREET
			port += 1
	for qx in range(x0 + 1, x0 + QUAY_WIDTH - 1):
		if data.road[data.idx(qx, edge)] == 0:
			data.road[data.idx(qx, edge)] = CityTypes.ROAD_STREET
			port += 1
	return {"street": street, "port": port, "quay": quay}


static func _dev_land(data: CityData, x: int, y: int) -> bool:
	if not data.in_bounds(x, y):
		return false
	var i := data.idx(x, y)
	return data.zone[i] == Zone.DEV and data.terrain[i] == Terrain.LAND
