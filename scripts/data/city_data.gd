class_name CityData
extends RefCounted
## Compact storage of the whole generated city.
## Everything is packed arrays so a 640x640 island stays around a few MB.
## After generation the data is read-only and safe to read from worker threads.

var size: int
var chunk_size: int

# Per-cell layers (index = y * size + x)
var terrain := PackedByteArray()
var zone := PackedByteArray()
var road := PackedByteArray()
## Elevation mapped to 0..255 (128 = sea level). Used by the ground shader.
var elevation := PackedByteArray()
## 0..1 forest density used for trees in nature areas.
var forest := PackedByteArray()
## 1 where the shore is rocky instead of sandy.
var rocky := PackedByteArray()
## 1 where a building stands (trees, palms and cacti avoid these cells).
var occupied := PackedByteArray()

# Buildings / lots (index = building id)
var b_rect := PackedInt32Array()     # x, y, w, h (4 ints per building)
var b_kind := PackedByteArray()
var b_facing := PackedByteArray()
var b_seed := PackedInt32Array()
var b_height := PackedFloat32Array() # relative height factor (density driven)

# Chunk index -> building ids whose lot origin is inside the chunk
var chunk_buildings: Array[PackedInt32Array] = []

# City centers, filled by the district planner (Vector2 in cells)
var centers: Array[Vector2] = []
var center_weights: PackedFloat32Array = PackedFloat32Array()
var city_name := "Chat City"
## Cell (x, row) where the Golden Gate bridge leaves the east coast; x < 0 = none.
var bridge := Vector2i(-1, -1)
## West bridge: (x of the main island's west-most land, x of the urban island's east-most land,
## row); x < 0 = none. Drawn by WestBridge with the metal bridge model.
var west_bridge := Vector3i(-1, -1, -1)
## The island hidden in the fog, east of the map (FogIslandShaper).
var fog: FogIslandShaper


func _init(p_size: int, p_chunk: int) -> void:
	size = p_size
	chunk_size = p_chunk
	var n := size * size
	terrain.resize(n)
	zone.resize(n)
	road.resize(n)
	elevation.resize(n)
	forest.resize(n)
	rocky.resize(n)
	occupied.resize(n)


# --- Cell access -----------------------------------------------------------------
func idx(x: int, y: int) -> int:
	return y * size + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < size


func is_land(x: int, y: int) -> bool:
	return in_bounds(x, y) and terrain[y * size + x] >= CityTypes.Terrain.BEACH


func is_road(x: int, y: int) -> bool:
	return in_bounds(x, y) and road[y * size + x] != 0


func road_mask(x: int, y: int) -> int:
	var m := 0
	if is_road(x, y - 1): m |= CityTypes.DIR_N
	if is_road(x + 1, y): m |= CityTypes.DIR_E
	if is_road(x, y + 1): m |= CityTypes.DIR_S
	if is_road(x - 1, y): m |= CityTypes.DIR_W
	return m


func zone_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return CityTypes.Zone.NONE
	return zone[y * size + x]


# --- Buildings -----------------------------------------------------------------------
func building_count() -> int:
	return b_kind.size()


func add_building(r: Rect2i, kind: int, facing: int, seed: int, height: float) -> int:
	b_rect.append(r.position.x)
	b_rect.append(r.position.y)
	b_rect.append(r.size.x)
	b_rect.append(r.size.y)
	b_kind.append(kind)
	b_facing.append(facing)
	b_seed.append(seed)
	b_height.append(height)
	return b_kind.size() - 1


func building_rect(i: int) -> Rect2i:
	var o := i * 4
	return Rect2i(b_rect[o], b_rect[o + 1], b_rect[o + 2], b_rect[o + 3])


## Removes the buildings flagged in `removed` (compacts all arrays).
func remove_buildings(removed: Dictionary) -> void:
	if removed.is_empty():
		return
	var r := PackedInt32Array()
	var k := PackedByteArray()
	var f := PackedByteArray()
	var s := PackedInt32Array()
	var h := PackedFloat32Array()
	for i in b_kind.size():
		if removed.has(i):
			continue
		for j in 4:
			r.append(b_rect[i * 4 + j])
		k.append(b_kind[i])
		f.append(b_facing[i])
		s.append(b_seed[i])
		h.append(b_height[i])
	b_rect = r
	b_kind = k
	b_facing = f
	b_seed = s
	b_height = h


# --- Chunks ------------------------------------------------------------------------------
func chunks_per_side() -> int:
	return ceili(float(size) / float(chunk_size))


func chunk_rect(cx: int, cy: int) -> Rect2i:
	var r := Rect2i(cx * chunk_size, cy * chunk_size, chunk_size, chunk_size)
	return r.intersection(Rect2i(0, 0, size, size))


func build_chunk_index() -> void:
	var side := chunks_per_side()
	chunk_buildings.clear()
	chunk_buildings.resize(side * side)
	for i in chunk_buildings.size():
		chunk_buildings[i] = PackedInt32Array()
	occupied.fill(0)
	for i in b_kind.size():
		var cx := b_rect[i * 4] / chunk_size
		var cy := b_rect[i * 4 + 1] / chunk_size
		chunk_buildings[cy * side + cx].append(i)
		if b_kind[i] != CityTypes.Kind.PLAZA and b_kind[i] != CityTypes.Kind.GARDEN:
			var r := building_rect(i)
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					occupied[y * size + x] = 1


## Returns true when a chunk holds nothing but deep water (skipped by streaming).
func chunk_is_empty(cx: int, cy: int) -> bool:
	var r := chunk_rect(cx, cy)
	for y in range(r.position.y, r.end.y, 2):
		for x in range(r.position.x, r.end.x, 2):
			if terrain[y * size + x] != CityTypes.Terrain.DEEP:
				return false
	return true
