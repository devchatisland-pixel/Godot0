class_name GroundPlacer
extends RefCounted
## Everything placed per cell in a chunk: road tiles (oriented from their
## neighbours), street lights along avenues, trees in parks and forests,
## palms on beaches and islets, cacti in the desert.
## Pure functions, safe to run on worker threads.

const Cat := ModelCatalog.Cat
const Zone := CityTypes.Zone
## Where the bulb hangs under the arm of the Kenney street light (model space).
const BULB_OFFSET := Vector3(0.0, 0.64, -0.17)

## Road category for a connection mask.
static func road_cat(mask: int) -> int:
	match mask:
		15:
			return Cat.ROAD_CROSS
		7, 11, 13, 14:
			return Cat.ROAD_T
		5, 10, 0:
			return Cat.ROAD_STRAIGHT
		1, 2, 4, 8:
			return Cat.ROAD_END
	return Cat.ROAD_BEND


static func place_cells(data: CityData, lib: ModelLibrary, rect: Rect2i, batch: InstanceBatch) -> void:
	var road_rot := _road_rotations(lib)
	var trees := lib.ids(Cat.TREE)
	if trees.is_empty():
		trees = PackedInt32Array([lib.named_id("tree")])
	var lights := lib.ids(Cat.STREET_LIGHT)
	var palm := lib.named_id("palm")
	var cactus := lib.named_id("cactus")
	var bridge := _bridge_clearing(data)
	var checkpoint := Roadblocks.clearing(data)
	var ts := data.tree_share
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var i := y * data.size + x
			var road: int = data.road[i]
			if road != 0:
				_place_road(data, lib, x, y, road, road_rot, lights, batch)
				continue
			if data.occupied[i] == 1 or bridge.has_point(Vector2i(x, y)) 					or checkpoint.has_point(Vector2i(x, y)):
				continue
			if data.deco[i] != 0:
				_place_deco(data, lib, x, y, data.deco[i], batch)
				continue
			var z: int = data.zone[i]
			var beach: bool = data.terrain[i] == CityTypes.Terrain.BEACH and data.rocky[i] == 0
			match z:
				Zone.NATURE:
					if beach:
						_scatter(x, y, 0.06 * ts, 0.15, palm, batch)
					else:
						_place_forest(data, x, y, trees, batch)
				Zone.ISLET:
					_scatter(x, y, (0.12 if beach else 0.45) * ts, 0.2, palm, batch)
				Zone.PARK:
					_place_park_tree(data, x, y, trees, batch)
				Zone.DESERT:
					_scatter(x, y, 0.035 * ts, 0.1, cactus, batch)
				Zone.PRISON:
					if data.terrain[i] == CityTypes.Terrain.LAND:
						_scatter(x, y, 0.12 * ts, 0.2, trees[(x + y) % trees.size()], batch)
			if data.edge[i] != 0:
				_place_edge(lib, x, y, data.edge[i], batch)


## Where no tree or palm grows: round both ends of the metal bridge to the urban island.
const BRIDGE_CLEAR_X := Vector2i(5, 9)
const BRIDGE_CLEAR_Y := 7


static func _bridge_clearing(data: CityData) -> Rect2i:
	var wb := data.west_bridge
	if wb.x < 0:
		return Rect2i()
	var x0 := wb.y - BRIDGE_CLEAR_X.x
	return Rect2i(x0, wb.z - BRIDGE_CLEAR_Y, wb.x + BRIDGE_CLEAR_X.y - x0, BRIDGE_CLEAR_Y * 2 + 1)


# --- Park, boardwalk and the border of the desert -------------------------------------------------
static func _place_deco(data: CityData, lib: ModelLibrary, x: int, y: int, deco: int, batch: InstanceBatch) -> void:
	var at := Vector3(x + 0.5, 0.0, y + 0.5)
	match deco:
		AmenitiesPlanner.BENCH_X:
			batch.add(lib.named_id("bench"), Transform3D(Basis(), at))
		AmenitiesPlanner.BENCH_Z:
			batch.add(lib.named_id("bench"), Transform3D(Basis(Vector3.UP, PI * 0.5), at))
		AmenitiesPlanner.FLOWER:
			batch.add(lib.named_id("flowerbed"), Transform3D(Basis(), at))
		AmenitiesPlanner.PLAY_CENTER:
			batch.add(lib.named_id("playground"), Transform3D(Basis(), at))
		AmenitiesPlanner.BOARD:
			batch.add(lib.named_id("plank"), Transform3D(Basis(), at))
		AmenitiesPlanner.FENCE_X:
			batch.add(lib.named_id("fence"), Transform3D(Basis(), at))
		AmenitiesPlanner.FENCE_Z:
			batch.add(lib.named_id("fence"), Transform3D(Basis(Vector3.UP, PI * 0.5), at))
		AmenitiesPlanner.BOARD_LAMP:
			batch.add(lib.named_id("plank"), Transform3D(Basis(), at))
			batch.add(lib.named_id("boardwalk_lamp"), Transform3D(Basis(), at))


## Dry tufts and a few rocks where the desert meets the meadow (`edge`: closeness 1..4 in the
## low nibble, 0x80 = the cell is desert).
static func _place_edge(lib: ModelLibrary, x: int, y: int, edge: int, batch: InstanceBatch) -> void:
	var closeness := float(edge & 15) / 4.0
	var desert := (edge & 0x80) != 0
	_scatter(x, y, closeness * (0.2 if desert else 0.5), 0.3, lib.named_id("dry_tuft"), batch)
	var h := CityTypes.hash2(x, y, 6151)
	if float(h & 1023) / 1024.0 < closeness * 0.1:
		var p := Vector3(x + 0.2 + float((h >> 10) & 255) / 255.0 * 0.6, 0, y + 0.2 + float((h >> 18) & 255) / 255.0 * 0.6)
		batch.add(lib.named_id("rock"), Transform3D(Basis(Vector3.UP, float(h & 63) * 0.1), p))


# --- Roads --------------------------------------------------------------------------------
## For every (category, wanted mask) the mesh id and yaw to use: {cat: {mask: [id, yaw]}}.
static func _road_rotations(lib: ModelLibrary) -> Dictionary:
	var out := {}
	for cat in [Cat.ROAD_STRAIGHT, Cat.ROAD_CROSS, Cat.ROAD_T, Cat.ROAD_BEND, Cat.ROAD_END]:
		if not lib.has_cat(cat):
			continue
		var id := lib.ids(cat)[0]
		var native := lib.road_masks[id]
		var table := {}
		for k in 4:
			var yaw := k * PI * 0.5
			table[CityTypes.rotate_mask(native, yaw)] = [id, yaw]
		out[cat] = table
	return out


static func _place_road(data: CityData, lib: ModelLibrary, x: int, y: int, road: int,
		rot: Dictionary, lights: PackedInt32Array, batch: InstanceBatch) -> void:
	var mask := data.road_mask(x, y)
	var cat := road_cat(mask)
	var center := Vector3(x + 0.5, 0.0, y + 0.5)
	var want := mask if mask != 0 else CityTypes.DIR_E | CityTypes.DIR_W
	if rot.has(cat) and rot[cat].has(want):
		var e: Array = rot[cat][want]
		batch.add(e[0], Transform3D(Basis(Vector3.UP, e[1]), center))
	else:
		var box := lib.named_id("box")
		batch.add(box, Transform3D(Basis.from_scale(Vector3(1, 0.02, 1)), center))
	# Street lights on both sidewalks of straight avenues, every third cell.
	if (road & 3) == CityTypes.ROAD_AVENUE and not lights.is_empty() and (mask == 5 or mask == 10):
		if (x + y) % 3 == 0 and (road & CityTypes.ROAD_BRIDGE_FLAG) == 0:
			var along_x := mask == 10
			for s in [-1.0, 1.0]:
				var off := Vector3(0, 0, s * 0.47) if along_x else Vector3(s * 0.47, 0, 0)
				# The lamp arm points to -Z in the model: turn it towards the road.
				var yaw := atan2(off.x, off.z)
				var lamp := Transform3D(Basis(Vector3.UP, yaw), center + off)
				batch.add(lights[0], lamp)
				batch.add(lib.named_id("lamp_bulb"), lamp * Transform3D(Basis(), BULB_OFFSET))


# --- Trees -------------------------------------------------------------------------------------
static func _place_forest(data: CityData, x: int, y: int, trees: PackedInt32Array, batch: InstanceBatch) -> void:
	var f := float(data.forest[y * data.size + x]) / 255.0
	if f <= 0.0:
		return
	var h := CityTypes.hash2(x, y, 911)
	var count := 0
	if float(h & 1023) / 1024.0 < f * 0.9 * data.tree_share:
		count = 1 + int(f > 0.6 and (h >> 10) & 1 == 1)
	for t in count:
		var hh := CityTypes.hash2(x, y, 31 + t)
		var p := Vector3(x + 0.15 + float(hh & 255) / 255.0 * 0.7, 0,
				y + 0.15 + float((hh >> 8) & 255) / 255.0 * 0.7)
		batch.add(trees[hh % trees.size()], BuildingExtras.tree_xform(p, hh))


## One mesh on the cell with probability `chance`, jittered, random size and turn.
static func _scatter(x: int, y: int, chance: float, jitter_scale: float, mesh: int, batch: InstanceBatch) -> void:
	var h := CityTypes.hash2(x, y, 4242)
	if float(h & 1023) / 1024.0 >= chance:
		return
	var p := Vector3(x + 0.2 + float((h >> 10) & 255) / 255.0 * 0.6, 0,
			y + 0.2 + float((h >> 18) & 255) / 255.0 * 0.6)
	var s := 1.0 + (float((h >> 4) & 63) / 63.0 - 0.5) * jitter_scale * 2.0
	batch.add(mesh, Transform3D(Basis(Vector3.UP, float(h & 63) * 0.1).scaled(Vector3(s, s, s)), p))


static func _place_park_tree(data: CityData, x: int, y: int, trees: PackedInt32Array, batch: InstanceBatch) -> void:
	# The central park is a dense wood: up to two big trees per cell.
	for t in 2:
		var h := CityTypes.hash2(x, y, 517 + t)
		if h % 100 >= int(55.0 * data.tree_share):
			continue
		var p := Vector3(x + 0.15 + float(h & 255) / 255.0 * 0.7, 0, y + 0.15 + float((h >> 8) & 255) / 255.0 * 0.7)
		var xf := BuildingExtras.tree_xform(p, h)
		batch.add(trees[(h >> 4) % trees.size()], Transform3D(xf.basis.scaled(Vector3(1.3, 1.3, 1.3)), p))
