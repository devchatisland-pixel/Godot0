class_name GroundPlacer
extends RefCounted
## Everything placed per cell in a chunk: road tiles (oriented from their
## neighbours), street lights along avenues and trees in parks and forests.
## Pure functions, safe to run on worker threads.

const Cat := ModelCatalog.Cat
const Zone := CityTypes.Zone

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
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var i := y * data.size + x
			var road: int = data.road[i]
			if road != 0:
				_place_road(data, lib, x, y, road, road_rot, lights, batch)
				continue
			var z: int = data.zone[i]
			if z == Zone.NATURE:
				_place_forest(data, x, y, trees, batch)
			elif z == Zone.PARK:
				_place_park_tree(data, x, y, trees, batch)


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
				batch.add(lights[0], Transform3D(Basis(Vector3.UP, yaw), center + off))


# --- Trees -------------------------------------------------------------------------------------
static func _place_forest(data: CityData, x: int, y: int, trees: PackedInt32Array, batch: InstanceBatch) -> void:
	var f := float(data.forest[y * data.size + x]) / 255.0
	if f <= 0.0:
		return
	var h := CityTypes.hash2(x, y, 911)
	var count := 0
	if float(h & 1023) / 1024.0 < f * 0.9:
		count = 1 + int(f > 0.6 and (h >> 10) & 1 == 1)
	for t in count:
		var hh := CityTypes.hash2(x, y, 31 + t)
		var p := Vector3(x + 0.15 + float(hh & 255) / 255.0 * 0.7, 0,
				y + 0.15 + float((hh >> 8) & 255) / 255.0 * 0.7)
		batch.add(trees[hh % trees.size()], BuildingPlacer._tree_xform(p, hh))


static func _place_park_tree(data: CityData, x: int, y: int, trees: PackedInt32Array, batch: InstanceBatch) -> void:
	var h := CityTypes.hash2(x, y, 517)
	if h % 100 >= 38:
		return
	var p := Vector3(x + 0.2 + float(h & 255) / 255.0 * 0.6, 0, y + 0.2 + float((h >> 8) & 255) / 255.0 * 0.6)
	batch.add(trees[(h >> 4) % trees.size()], BuildingPlacer._tree_xform(p, h))
