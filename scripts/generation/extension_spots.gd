class_name ExtensionSpots
extends RefCounted
## Finding free ground for the districts around the finished city: round blobs
## (ellipses with a wobbly edge), plots of dry land, open meadow, open water and
## random free rectangles. Also claims the chosen rectangles for a building kind.
## Used by ExtensionPlanner, ExtensionRoads, ExtensionFeatures and UrbanIslandPlanner.

const Zone := CityTypes.Zone
const Terrain := CityTypes.Terrain

## Buildings placed through `claim`, per kind.
var counts := {}
## Set by the planner once lots and services exist.
var lots: LotPlanner
var services: ServicePlanner

var _data: CityData
var _island: ExtensionIsland
var _rng: RandomNumberGenerator
var _shape := FastNoiseLite.new()


func _init(cfg: CityConfig, data: CityData, island: ExtensionIsland, rng: RandomNumberGenerator) -> void:
	_data = data
	_island = island
	_rng = rng
	_shape.seed = cfg.seed + 31
	_shape.frequency = 0.045


# --- Round shapes --------------------------------------------------------------------------
## True when the cell is inside the blob (an ellipse with a wobbly edge).
func in_blob(b: Dictionary, x: int, y: int, grow: float = 0.0) -> bool:
	var at: Vector2 = b["at"]
	var r: Vector2 = b["r"]
	var n := Vector2((float(x) + 0.5 - at.x) / r.x, (float(y) + 0.5 - at.y) / r.y)
	return n.length() + _shape.get_noise_2d(x, y) * 0.22 < 1.0 + grow


func blob_rect(b: Dictionary) -> Rect2i:
	var at: Vector2 = b["at"]
	var r: Vector2 = b["r"]
	return Rect2i(Vector2i((at - r * 1.15).round()), Vector2i((r * 2.3).round()))


## Free for the extension: land that is not used by the core (or by a district).
func is_open(i: int) -> bool:
	return _data.zone[i] == Zone.NONE or _data.zone[i] == Zone.NATURE


## Free cells (open land, no road) inside the blob.
func blob_mask(b: Dictionary) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(_data.size * _data.size)
	var rect := blob_rect(b)
	for y in range(maxi(rect.position.y, 0), mini(rect.end.y, _data.size)):
		for x in range(maxi(rect.position.x, 0), mini(rect.end.x, _data.size)):
			var i := _data.idx(x, y)
			if in_blob(b, x, y) and _data.terrain[i] == Terrain.LAND and is_open(i) and _data.road[i] == 0:
				mask[i] = 1
	return mask


func mask_bounds(mask: PackedByteArray) -> Rect2i:
	var mn := Vector2i(_data.size, _data.size)
	var mx := Vector2i(-1, -1)
	for i in mask.size():
		if mask[i] == 1:
			var x := i % _data.size
			var y := i / _data.size
			mn = Vector2i(mini(mn.x, x), mini(mn.y, y))
			mx = Vector2i(maxi(mx.x, x), maxi(mx.y, y))
	return Rect2i(mn, mx - mn + Vector2i.ONE) if mx.x >= 0 else Rect2i()


## A block counts when most of its cells are free.
func mostly_free(r: Rect2i, mask: PackedByteArray) -> bool:
	var free := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			free += mask[_data.idx(x, y)]
	return free * 4 >= r.get_area() * 3


func near_water(x: int, y: int, dist: int) -> bool:
	for dy in range(-dist, dist + 1):
		for dx in range(-dist, dist + 1):
			if dx * dx + dy * dy > dist * dist or not _data.in_bounds(x + dx, y + dy):
				continue
			if _data.terrain[_data.idx(x + dx, y + dy)] < Terrain.BEACH:
				return true
	return false


# --- Plots -------------------------------------------------------------------------------------
## A free plot closest to `target` whose cells are all dry open land; for a blob given,
## the whole plot must be inside it, else it must be on the urban island.
func find_plot(target: Vector2i, size: Vector2i, blob: Dictionary) -> Rect2i:
	for radius in 30:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var r := Rect2i(target + Vector2i(dx, dy) - size / 2, size)
				if _plot_ok(r, blob):
					return r
	return Rect2i()


func _plot_ok(r: Rect2i, blob: Dictionary) -> bool:
	for y in range(r.position.y - 1, r.end.y + 1):
		for x in range(r.position.x - 1, r.end.x + 1):
			if not _data.in_bounds(x, y):
				return false
			var i := _data.idx(x, y)
			if _data.terrain[i] != Terrain.LAND or _data.road[i] != 0 \
					or not (is_open(i) or _data.zone[i] == Zone.URBAN):
				return false
			if not blob.is_empty() and not in_blob(blob, x, y):
				return false
			# Cluster plots stay on the urban island, ferris wheel plots on the main one.
			if blob.is_empty() and not _island.is_urban_island(x, y):
				return false
	return true


## Free rectangle of open water closest to `target`.
func find_water(target: Vector2i, size: Vector2i, max_radius: int) -> Rect2i:
	for radius in max_radius + 1:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var r := Rect2i(target + Vector2i(dx, dy) - size / 2, size)
				if _water_ok(r):
					return r
	return Rect2i()


func _water_ok(r: Rect2i) -> bool:
	for y in range(r.position.y - 1, r.end.y + 1):
		for x in range(r.position.x - 1, r.end.x + 1):
			if not _data.in_bounds(x, y) or _data.terrain[_data.idx(x, y)] >= Terrain.BEACH:
				return false
	return true


# --- Spots (free rectangles of one zone) ---------------------------------------------------------
## Marks the rectangle as taken by `kind`, so roads and other buildings keep off it.
func claim(r: Rect2i, kind: int, facing: int, zone: int = -1, seed: int = -1) -> void:
	services.claim(r, kind, facing, zone, seed)
	counts[kind] = counts.get(kind, 0) + 1


## One free rectangle of `size` somewhere in `area`, or an empty one.
func spots_one(area: Rect2i, zone: int, size: Vector2i, margin: int) -> Rect2i:
	var found := spots(area, zone, size, 1, 0.0, margin, 400)
	return found[0] if not found.is_empty() else Rect2i()


## Random free rectangles of `size` in `area` (cells of `zone`), at least `gap`
## apart and with `margin` free cells around them.
func spots(area: Rect2i, zone: int, size: Vector2i, count: int, gap: float, margin: int,
		tries: int = 600) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for t in tries:
		if out.size() >= count:
			break
		var r := Rect2i(_rng.randi_range(area.position.x, maxi(area.end.x - size.x, area.position.x)),
				_rng.randi_range(area.position.y, maxi(area.end.y - size.y, area.position.y)), size.x, size.y)
		if not spot_free(r, zone, margin):
			continue
		var c := Vector2(r.get_center())
		if out.any(func(q: Rect2i) -> bool: return Vector2(q.get_center()).distance_to(c) < gap):
			continue
		out.append(r)
	return out


## Closest free rectangle around `near` (same test as `spots`).
func find_spot(near: Vector2i, size: Vector2i, zone: int, max_radius: int, margin: int) -> Rect2i:
	for radius in max_radius + 1:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var r := Rect2i(near + Vector2i(dx, dy), size)
				if spot_free(r, zone, margin):
					return r
	return Rect2i()


func spot_free(r: Rect2i, zone: int, margin: int) -> bool:
	for y in range(r.position.y - margin, r.end.y + margin):
		for x in range(r.position.x - margin, r.end.x + margin):
			if not _data.in_bounds(x, y):
				return false
			var i := _data.idx(x, y)
			var inside := r.has_point(Vector2i(x, y))
			if inside:
				if _data.terrain[i] != Terrain.LAND or _data.zone[i] != zone \
						or _data.road[i] != 0 or lots.owner[i] != -1:
					return false
			elif _data.road[i] != 0 or lots.owner[i] >= 0:
				return false
	return true
