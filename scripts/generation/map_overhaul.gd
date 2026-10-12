class_name MapOverhaul
extends RefCounted
## The last drastic changes of the map, applied once everything else is built (and counted by
## BuildingBudget):
##   - no building stands on the urban island (west of the main island) any more: its streets,
##     its ground and the boats at sea off its coast stay;
##   - BALLOONS hot air balloons float over random places of the whole map, sea included;
##   - SUBMARINES more submarines, SIMPLE_BOATS simple boats and CARGO_SHIPS cargo ships lie at
##     random places of the open sea.
## Trees, fences and the buildings of the fog island are not drawn at all (GroundPlacer,
## FogIslandShaper), so nothing here deals with them.
## Everything random comes from one generator seeded by the city seed: same map on every device.

const Kind := CityTypes.Kind

const BALLOONS := 12
const SUBMARINES := 12
## Least distance (cells) between two new balloons, and between two submarines.
const BALLOONS_APART := 22
const SUBMARINES_APART := 18
## More simple boats and cargo ships at random places of the sea, and how far apart.
const SIMPLE_BOATS := 8
const SIMPLE_BOATS_APART := 24
const CARGO_SHIPS := 4
const CARGO_SHIPS_APART := 45
## Balloons keep this far from the edge of the map (cells).
const EDGE_MARGIN := 4


## Returns {"urban_cleared": n, "balloons": n, "submarines": n}.
static func apply(data: CityData, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 4242
	var out := {}
	out["urban_cleared"] = _clear_urban_island(data)
	out["balloons"] = _add_balloons(data, rng)
	out["submarines"] = BoatSites.scatter_submarines(data, SUBMARINES, SUBMARINES_APART, rng)
	out["simple_boats"] = BoatSites.scatter(data, BoatSites.SIMPLE, SIMPLE_BOATS, SIMPLE_BOATS_APART, Vector2i(4, 5), rng)
	out["cargo_ships"] = BoatSites.scatter(data, BoatSites.CARGO, CARGO_SHIPS, CARGO_SHIPS_APART, Vector2i(4, 10), rng)
	return out


## Every building whose lot centre is on the urban island becomes a cleared lot.
static func _clear_urban_island(data: CityData) -> int:
	var cleared := 0
	for b in data.building_count():
		var k: int = data.b_kind[b]
		if k == Kind.EMPTY or k == Kind.BOAT or k == Kind.BALLOON:
			continue
		if MapLayout.on_urban_island(data.building_rect(b).get_center()):
			data.b_kind[b] = Kind.EMPTY
			cleared += 1
	return cleared


## Balloons at random cells of the map (land or sea), apart from each other.
static func _add_balloons(data: CityData, rng: RandomNumberGenerator) -> int:
	var spots: Array[Vector2i] = []
	for b in data.building_count():
		if data.b_kind[b] == Kind.BALLOON:
			spots.append(data.building_rect(b).get_center())
	var placed := 0
	var tries := 0
	while placed < BALLOONS and tries < 2000:
		tries += 1
		var c := Vector2i(rng.randi_range(EDGE_MARGIN, data.size - 1 - EDGE_MARGIN),
				rng.randi_range(EDGE_MARGIN, data.size - 1 - EDGE_MARGIN))
		var crowded := false
		for o in spots:
			if Vector2(o).distance_to(Vector2(c)) < float(BALLOONS_APART):
				crowded = true
				break
		if crowded:
			continue
		data.add_building(Rect2i(c - Vector2i(1, 1), Vector2i(3, 3)), Kind.BALLOON, 2, 1, 0.5)
		spots.append(c)
		placed += 1
	return placed
