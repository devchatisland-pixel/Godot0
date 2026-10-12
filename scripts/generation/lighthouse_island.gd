class_name LighthouseIsland
extends RefCounted
## Nineteenth wave, the last change to the finished map (after PortRework): a little island of
## its own in the open sea, with sandy beaches all round it and no tree, and on it the
## lighthouse of the club (lighthouse_club.glb: the "Light House Club" sign hangs on its east
## wall), facing south.
## The coast is an ellipse cut by two layers of noise, so the island is not round. Nothing
## else of the map moves: the island is painted on open sea, far from every building, boat,
## coast and from the fog island.

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone
const Terrain := CityTypes.Terrain

const MODEL := "lighthouse_club.glb: lighthouse_club"
## Where the search for open sea starts (cells): the sea south-east of the main island.
const AT := Vector2i(300, 336)
## Radii of the island (cells) and the turn of its long side (radians).
const RADII := Vector2(8.0, 6.0)
const TURN := 0.35
## Lot of the lighthouse (x by z, the building faces south; its sign juts out east).
const LOT := Vector2i(6, 4)
## Open sea kept all round the island (cells), and the distance kept from the fog island.
const SEA := 5
const FOG_GAP := 30.0
## Shape of the ground (e: 1 in the middle, 0 on the waterline): the land starts at LAND_E,
## the shallows end at SHALLOW_E. Noise: strength and frequency of the two layers.
const LAND_E := 0.42
const SHALLOW_E := -0.45
const NOISE := Vector2(0.28, 0.1)
const NOISE_FREQ := Vector2(0.09, 0.3)
## Elevation bytes (128 = waterline): the sand rises to SAND_TOP where the land starts (the
## ground shader draws sand up to 137), the sea slopes down gently through the shallows.
const SAND_TOP := 139.0
const SEA_SLOPE := 60.0
const SEED := 9191


## Returns {"island": cell of its centre or (-1, -1), "land": cells, "beach": cells}.
static func apply(data: CityData) -> Dictionary:
	var at := _spot(data)
	if at.x < 0:
		push_warning("[Lighthouse] no open sea for the island")
		return {"island": at, "land": 0, "beach": 0}
	var noise := FastNoiseLite.new()
	noise.seed = SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	var land := 0
	var beach := 0
	var reach := int(ceilf(maxf(RADII.x, RADII.y) * 1.6))
	for y in range(at.y - reach, at.y + reach + 1):
		for x in range(at.x - reach, at.x + reach + 1):
			if not data.in_bounds(x, y):
				continue
			var e := _height(noise, Vector2(x, y), Vector2(at))
			if e < SHALLOW_E:
				continue
			var i := data.idx(x, y)
			var t := Terrain.SHALLOW
			var b := 128.0 + e * SEA_SLOPE
			if e >= LAND_E:
				t = Terrain.LAND
				b = SAND_TOP + (e - LAND_E) * 160.0
				land += 1
			elif e >= 0.0:
				t = Terrain.BEACH
				b = 128.0 + (SAND_TOP - 128.0) * e / LAND_E
				beach += 1
			data.terrain[i] = t
			data.elevation[i] = maxi(data.elevation[i], clampi(int(b), 0, 255))
			data.zone[i] = Zone.ISLET if t >= Terrain.BEACH else Zone.NONE
			data.forest[i] = 0
			data.rocky[i] = 0
	# The lighthouse in the middle, facing south.
	var lot := Rect2i(at - LOT / 2, LOT)
	var b := data.add_building(lot, Kind.LIGHTHOUSE, 2, 0, 0.5)
	data.b_model[b] = MODEL
	return {"island": at, "land": land, "beach": beach}


## 1 in the middle of the island, 0 on its waterline, below 0 at sea.
static func _height(noise: FastNoiseLite, p: Vector2, at: Vector2) -> float:
	var d := (p + Vector2(0.5, 0.5) - at).rotated(-TURN)
	var t := Vector2(d.x / RADII.x, d.y / RADII.y).length()
	var n := noise.get_noise_2d(p.x * NOISE_FREQ.x, p.y * NOISE_FREQ.x) * NOISE.x \
			+ noise.get_noise_2d(p.x * NOISE_FREQ.y + 97.0, p.y * NOISE_FREQ.y) * NOISE.y
	# The middle always stays land (the lot of the lighthouse).
	if t < 0.55:
		n = maxf(n, 0.0)
	return 1.0 - t * t + n


## The centre nearest to AT whose island and the sea round it are open deep water, with no
## building (boats, balloons...) on them, far enough from the fog island.
static func _spot(data: CityData) -> Vector2i:
	var half := Vector2i(int(ceilf(RADII.x * 1.4)) + SEA, int(ceilf(RADII.x * 1.4)) + SEA)
	var taken: Array[Rect2i] = []
	for b in data.building_count():
		if data.b_kind[b] != Kind.EMPTY:
			taken.append(data.building_rect(b))
	var fog := Rect2()
	if data.fog != null:
		fog = Rect2(data.fog.origin, Vector2(FogIslandShaper.SIZE, FogIslandShaper.SIZE)).grow(FOG_GAP)
	for ring in 60:
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var c := AT + Vector2i(dx, dy) * 2
				var area := Rect2i(c - half, half * 2 + Vector2i.ONE)
				if fog.has_area() and fog.intersects(Rect2(area)):
					continue
				if _open(data, area, taken):
					return c
	return Vector2i(-1, -1)


static func _open(data: CityData, area: Rect2i, taken: Array[Rect2i]) -> bool:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if not data.in_bounds(x, y) or data.terrain[data.idx(x, y)] != Terrain.DEEP:
				return false
			var edge := mini(mini(x, y), mini(data.size - 1 - x, data.size - 1 - y))
			if edge < 6:
				return false
	for r in taken:
		if r.intersects(area):
			return false
	return true
