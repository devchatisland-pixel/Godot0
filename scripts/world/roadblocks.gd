class_name Roadblocks
extends Node3D
## Checkpoints on the three-lane highways, on land and away from the bridges:
##   - east (Golden Gate side): white stand barriers across the lanes, with cones, two
##     police cars on the road beyond them and one parked beside the road,
##   - west (main island side): a different barrier model plus a very small police
##     car parked beside the road (not on it).

const Cat := ModelCatalog.Cat
## Distance from the bridge head, in cells.
const EAST_BACK := 13
const WEST_BACK := 11
## Longest side of each model once placed, in cells.
const BARRIER_LEN := 1.05
const CAR_LEN := 0.98
const CONE_LEN := 0.15
const TANK_LEN := 1.98
## Height of the west barriers (R-15 to R-17) as a share of their modelled height.
const WEST_BARRIER_HEIGHT := 0.5
## How far before and after the west barriers the two pairs of police cars stand, in cells.
const WEST_CARS_APART := 2.2
## Cells west of the urban end of the west bridge where the second line of barriers stands.
const URBAN_EXIT_BACK := 2
## The black police car of that line stands this many cells towards the bridge from its barriers,
## turned by this much across the lane.
const URBAN_CAR_AHEAD := 1.6
const URBAN_CAR_SLANT := 0.45
## Second blockade of the Golden Gate (east): its barriers (the model of the west checkpoint) stand
## this many cells from the bridge head, the two tanks of the old verges stand on the road just
## behind it (towards the bridge), a Humvee parks by the first cruiser.
const GATE_BLOCK_BACK := 6
const GATE_TANKS_BEHIND := 2.4
const GATE_BARRIER_MODEL := "carto.glb: roadblock_b1"
const GATE_HUMVEE := "humvee_sand"
## Where the Humvee of the first blockade stands beside the cruiser parked before the barriers (cells
## towards the west) and its nose (east).
const GATE_HUMVEE_BESIDE := 1.4


func build(data: CityData, lib: ModelLibrary) -> void:
	if data.bridge.x >= 0:
		var x := data.bridge.x - EAST_BACK
		_block(lib, Cat.ROADBLOCK_A, x, data.bridge.y, true, true)
		_roadblock_cars(lib, x, data.bridge.y)
		# One more cruiser parked beside the road, before the barriers.
		_police_car(lib, x, data.bridge.y, 2.7)
		_tanks_facing_bridge(lib, x, data.bridge.y)
	if data.west_bridge.x >= 0:
		var x := data.west_bridge.x + WEST_BACK
		_block(lib, Cat.ROADBLOCK_B, x, data.west_bridge.z, false)
		_police_car(lib, x, data.west_bridge.z, 2.7)
		_west_cars(lib, x, data.west_bridge.z)
		_urban_exit_block(lib, data.west_bridge.y - URBAN_EXIT_BACK, data.west_bridge.z)
	if data.bridge.x >= 0:
		# New pieces come last: the numbers of the pieces above stay what they were.
		_gate_blockade(lib, data.bridge.x - GATE_BLOCK_BACK, data.bridge.y)
		_gate_humvee(lib, data.bridge.x - EAST_BACK, data.bridge.y)


## A line of barriers across the three lanes of the row `row` at column `x`.
## `same_model`: all three barriers use the same model (the same colour).
func _block(lib: ModelLibrary, cat: int, x: int, row: int, with_cones: bool, same_model: bool = false) -> void:
	var ids := lib.ids(cat)
	if ids.is_empty():
		return
	for k in 3:
		var id := ids[0 if same_model else k % ids.size()]
		var z := float(row) + 0.5 + float(k - 1)
		_put(lib, id, Vector3(float(x) + 0.5, 0.0, z), PI * 0.5, BARRIER_LEN, "Roadblock barrier",
				1.0 if with_cones else WEST_BARRIER_HEIGHT)
	if with_cones:
		var cones := lib.ids(Cat.CONE)
		if not cones.is_empty():
			for k in 4:
				var z := float(row) + 0.5 + (float(k) - 1.5) * 1.0
				_put(lib, cones[0], Vector3(float(x) - 1.4, 0.0, z), 0.0, CONE_LEN, "Traffic cone")


## A police car beside the road, `side` rows from the middle lane (the text of the model is
## readable from the south, so the car is turned the way the road runs).
func _police_car(lib: ModelLibrary, x: int, row: int, side: float = 2.7) -> void:
	var car := _cruiser(lib)
	if car.is_empty():
		return
	_put(lib, car["id"], Vector3(float(x) - 1.6, 0.0, float(row) + 0.5 + side), PI + car["turn"], CAR_LEN, "Police car (roadblock)")


## The two police cars stand on the highway just beyond the barriers, both facing north.
func _roadblock_cars(lib: ModelLibrary, x: int, row: int) -> void:
	var car := _cruiser(lib)
	if car.is_empty():
		return
	var z := float(row) + 0.5
	_put(lib, car["id"], Vector3(float(x) + 2.6, 0.0, z - 0.9), PI + car["turn"], CAR_LEN, "Police car (roadblock)")
	_put(lib, car["id"], Vector3(float(x) + 2.6, 0.0, z + 0.9), PI + car["turn"], CAR_LEN, "Police car (roadblock)")


## The police car of the roadblocks: the US cruiser of the vehicle catalog (its nose is -Z,
## the yaws below were made for the old model whose nose is +Z, hence the half turn).
## Falls back to the old model when the catalog vehicle cannot be loaded.
func _cruiser(lib: ModelLibrary, vehicle: String = "police_us_cruiser") -> Dictionary:
	var id := MapVehicles.mesh_id(lib, vehicle)
	if id >= 0:
		return {"id": id, "turn": PI}
	var ids := lib.ids(Cat.POLICE_CAR)
	if ids.is_empty():
		return {}
	return {"id": ids[0], "turn": 0.0}


## Four police cars across the road at the west checkpoint, two before the barriers and two
## after them, slightly slanted so that together they close the three lanes.
func _west_cars(lib: ModelLibrary, x: int, row: int) -> void:
	var car := _cruiser(lib)
	if car.is_empty():
		return
	var z := float(row) + 0.5
	for side: float in [-1.0, 1.0]:
		for k in 2:
			var dz := -0.95 if k == 0 else 0.95
			var slant: float = 0.25 * side * (1.0 if k == 0 else -1.0)
			_put(lib, car["id"], Vector3(float(x) + 0.5 + side * WEST_CARS_APART, 0.0, z + dz),
					PI + car["turn"] + slant, CAR_LEN, "Police car (roadblock)")


## A simple line of roadblock_a2 barriers across the three lanes where the west bridge lets
## out on the urban island (column `x`), and a black Japanese police car in front of the bridge entrance.
func _urban_exit_block(lib: ModelLibrary, x: int, row: int) -> void:
	var ids := lib.ids(Cat.ROADBLOCK_A)
	if ids.is_empty():
		return
	var id: int = ids[1 if ids.size() > 1 else 0]
	for k in 3:
		_put(lib, id, Vector3(float(x) + 0.5, 0.0, float(row) + 0.5 + float(k - 1)), PI * 0.5, BARRIER_LEN,
				"Roadblock barrier")
	var car := _cruiser(lib, "police_jp_black")
	if not car.is_empty():
		# On the road, between the barriers and the bridge entrance, slanted across the south lane (it
		# stood beside the road, hidden by the towers of the urban island).
		_put(lib, car["id"], Vector3(float(x) + URBAN_CAR_AHEAD, 0.0, float(row) + 0.5 + 1.0),
				car["turn"] + URBAN_CAR_SLANT, CAR_LEN, "Police car (roadblock)")


## Five tanks beyond the roadblock, their guns towards the bridge (east): three on the verges and
## two (the 3rd and the 4th, R-13 and R-14) on the road just behind the second blockade, in its two
## outer lanes, turned as they were.
func _tanks_facing_bridge(lib: ModelLibrary, x: int, row: int) -> void:
	var ids := lib.ids(Cat.TANK)
	if ids.is_empty():
		return
	var z := float(row) + 0.5
	var behind := float(EAST_BACK - GATE_BLOCK_BACK) + 0.5 + GATE_TANKS_BEHIND
	var spots := [Vector2(12.6, 4.6), Vector2(7.2, 4.6), Vector2(behind, 1.0), Vector2(behind, -1.0), Vector2(8.5, -4.2)]
	for spot in spots:
		_put(lib, ids[0], Vector3(float(x) + spot.x, 0.0, z + spot.y), PI * 0.5, TANK_LEN, "Tank (roadblock)")


## The second blockade of the Golden Gate: a line of the barriers of the west checkpoint (model
## GATE_BARRIER_MODEL, half height) across the three lanes at column `x`, near the sand Humvee.
func _gate_blockade(lib: ModelLibrary, x: int, row: int) -> void:
	var ids := lib.ids(Cat.ROADBLOCK_B)
	if ids.is_empty():
		return
	var id := ids[0]
	for i in ids:
		if lib.model_name(i) == GATE_BARRIER_MODEL:
			id = i
	for k in 3:
		_put(lib, id, Vector3(float(x) + 0.5, 0.0, float(row) + 0.5 + float(k - 1)), PI * 0.5, BARRIER_LEN,
				"Roadblock barrier", WEST_BARRIER_HEIGHT)


## A sand Humvee like the one beyond the first blockade, parked beside the cruiser that stands
## before the first barriers (`x` is that blockade's column), its nose to the bridge (east).
func _gate_humvee(lib: ModelLibrary, x: int, row: int) -> void:
	var id := MapVehicles.mesh_id(lib, GATE_HUMVEE)
	if id < 0:
		return
	var box := lib.bounds[id]
	var length := maxf(box.size.x, box.size.z) * VehicleSites.CELLS_PER_METRE
	var e := MapVehicles.entry(GATE_HUMVEE)
	_put(lib, id, Vector3(float(x) - 1.6 - GATE_HUMVEE_BESIDE, 0.0, float(row) + 0.5 + 2.7), -PI * 0.5, length,
			String(e.get("name", GATE_HUMVEE)), 1.0, "VEHICLE", String(e.get("category", "")))


## Rectangle (cells) round the Golden Gate checkpoint where no tree grows.
static func clearing(data: CityData) -> Rect2i:
	if data.bridge.x < 0:
		return Rect2i()
	var x := data.bridge.x - EAST_BACK
	return Rect2i(x - 7, data.bridge.y - 8, 26, 18)


## Puts model `id` on the ground at `at`, scaled so that its longest side is `length`.
func _put(lib: ModelLibrary, id: int, at: Vector3, yaw: float, length: float, title: String = "Roadblock piece",
		height: float = 1.0, kind: String = "ROADBLOCK", category: String = "Roadblock") -> void:
	if RemovedModels.has(lib.model_name(id)):
		return
	var box := lib.bounds[id]
	var longest := maxf(box.size.x, box.size.z)
	if longest <= 0.0:
		return
	var s := length / longest
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(s, s * height, s))
	var center := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var mi := MeshInstance3D.new()
	mi.mesh = lib.meshes[id]
	mi.transform = Transform3D(basis, at - basis * center)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "%s_%d" % [title.replace(" ", ""), get_child_count()]
	add_child(mi)
	mi.set_meta("pick", {
		"uid": "R-%02d" % get_child_count(), "number": get_child_count(), "title": title,
		"kind": kind, "model": lib.model_name(id), "category": category, "note": "checkpoint",
	})
