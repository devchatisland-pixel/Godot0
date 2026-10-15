class_name ContinentShaper
extends RefCounted
## The continent north and east of the fog island: a big landmass of its own, joined to the
## fog island by two metal bridges, covered with the buildings of the "Continent" pack
## (FREEMODELS/curated/continent_city.glb, tools/build_continent_pack.py) and nothing else.
## Like the fog island it is not part of the cell grid of the city: it is its own grid (world
## cells, `origin` .. `origin + SIZE`) with its own ground textures, so it costs no lots or
## roads of the city. Pure data, runs on the generation thread; Continent draws it.
##
## Layout (all in world cells):
##   - land: three lobes (north, link, east) wrapped round the fog island, ragged coast;
##   - highways: smooth curves from the two bridge heads across the continent;
##   - streets: districts, each with its own street grid (turned, a little warped, an avenue
##     every third street), so the town is not one big chessboard;
##   - buildings: packed on what is left, aligned to the street grid of their district, big
##     towers first and small ones in the gaps, facing the nearest street.

const Cat := ModelCatalog.Cat

## World cell of the top-left corner of the continent's own grid, and its size in cells.
const ORIGIN := Vector2(392.0, -90.0)
const SIZE := Vector2i(350, 450)
## Texels per cell of the colour texture (streets are one cell wide: two texels).
const RES := 2

## Land: [centre, radii] of the lobes, in world cells.
const LOBES := [
	[Vector2(520.0, 38.0), Vector2(122.0, 70.0)],   # north of the fog island
	[Vector2(645.0, 78.0), Vector2(58.0, 38.0)],    # the link between the two
	[Vector2(632.0, 215.0), Vector2(92.0, 128.0)],  # east of the fog island
]
## e (1 - r^2 of the lobe + noise) above which a cell is land, and above which it is firm
## enough to build on (the beach is a few cells wide).
const LAND := 0.05
const FIRM := 0.14
const COAST_NOISE := 0.30

## The bridges: the cell column / row they cross at. North bridge: x, leaves the north coast of
## the fog island (the street of Eastbay, FogBaseSites). East bridge: z, the avenue of the island.
const NORTH_BRIDGE_X := 472.0
const EAST_BRIDGE_Z := 191.5
## The fog island's own roads that end where the bridge starts: a panel joins them to it.
const FOG_STREET_TOP := Vector2(472.0, 161.0)
const FOG_AVENUE_END := Vector2(478.0, 191.5)

## Highways: control points (world cells) of curves of width HIGHWAY_WIDTH. A curve is cut
## wherever it would leave the land.
const HIGHWAY_WIDTH := 3.0
const HIGHWAYS := [
	# From the north bridge round the north lobe, down the link and the east lobe to the south.
	[Vector2(472, 100), Vector2(484, 78), Vector2(510, 58), Vector2(552, 46), Vector2(598, 44),
		Vector2(634, 62), Vector2(652, 96), Vector2(655, 135), Vector2(644, 178), Vector2(636, 222),
		Vector2(650, 268), Vector2(662, 312)],
	# From the east bridge through the east lobe, up to the link.
	[Vector2(540, 191.5), Vector2(580, 188), Vector2(616, 168), Vector2(646, 138), Vector2(682, 150),
		Vector2(704, 196), Vector2(698, 250), Vector2(676, 300)],
	# The upper road of the north lobe, west to east.
	[Vector2(422, 34), Vector2(462, 24), Vector2(508, 8), Vector2(556, -4), Vector2(606, -2),
		Vector2(640, 24), Vector2(668, 62)],
	# Cross road of the east lobe.
	[Vector2(566, 246), Vector2(612, 258), Vector2(660, 244), Vector2(702, 226)],
	# A link between the north bridge highway and the upper road.
	[Vector2(510, 58), Vector2(500, 36), Vector2(508, 8)],
	# Southern bypass of the east lobe.
	[Vector2(590, 300), Vector2(630, 318), Vector2(668, 316)],
]
## Metres... cells kept free of buildings on each side of a highway centre line.
const HIGHWAY_CLEAR := 2.6

## Footprint (x, height, z) of every model, in cells at scale 1 (tools/build_continent_pack.py).
const MODELS := {
	"continent_01": Vector3(2.00, 3.36, 0.81), "continent_02": Vector3(1.68, 2.31, 1.43),
	"continent_03": Vector3(2.00, 3.11, 0.81), "continent_04": Vector3(2.00, 3.13, 0.81),
	"continent_05": Vector3(1.98, 3.10, 0.80), "continent_06": Vector3(1.39, 6.24, 2.08),
	"continent_07": Vector3(2.94, 10.10, 2.38), "continent_08": Vector3(1.41, 6.39, 2.10),
	"continent_12": Vector3(1.43, 7.36, 2.16), "continent_14": Vector3(1.89, 8.92, 3.66),
	"continent_15": Vector3(5.05, 3.07, 1.94), "continent_16": Vector3(1.98, 3.06, 0.80),
	"continent_18": Vector3(0.60, 1.97, 1.72), "continent_19": Vector3(2.30, 1.68, 1.17),
	"continent_20": Vector3(1.50, 4.29, 0.78), "continent_21": Vector3(2.31, 1.52, 1.19),
	"continent_22": Vector3(1.88, 4.34, 1.58), "continent_23": Vector3(2.21, 5.45, 1.21),
	"continent_24": Vector3(2.21, 3.60, 1.21), "continent_28": Vector3(2.91, 8.31, 3.29),
	"continent_29": Vector3(0.91, 3.24, 1.66), "continent_30": Vector3(0.90, 3.06, 1.64),
	"continent_31": Vector3(4.28, 5.02, 5.26), "continent_32": Vector3(1.17, 4.73, 1.55),
	"continent_34": Vector3(1.17, 4.57, 1.55), "continent_36": Vector3(0.91, 3.13, 1.66),
}

## Districts: how many, and the spacing (cells) of the streets of their grid.
const DISTRICT_COUNT := 16
const STREET_MIN := 9.0
const STREET_MAX := 13.0
## Gap kept between two buildings (cells).
const GAP := 0.25
## Candidate lattice step of the three packing passes (big, middle, small models).
const STEPS := [3.0, 1.9, 1.2]
## Footprint area (cells^2) above which a model is "big", and below which it is "small".
const BIG_AREA := 7.0
const SMALL_AREA := 2.6
## The pack's buildings are drawn this much smaller than modelled, to sit well beside the fog
## island and the city.
const BUILDING_SCALE := 0.8
const MAX_BUILDINGS := 6500
## Strength of the warp of the street grids (cells).
const WARP := 3.5

## Per cell of the continent grid (index z * SIZE.x + x): ground height in the L8 encoding of
## the fog island (128 = sea level), and a flag of the firm land.
var elevation := PackedByteArray()
## RGBA, SIZE * RES texels: land colour, alpha 0 = rocky shore (see ground.gdshader).
var colors := PackedByteArray()
## The highways as polylines of world cells: Array of PackedVector2Array.
var highways: Array[PackedVector2Array] = []
## Bridges: {"from": Vector2 (coast of the continent), "to": Vector2 (coast of the fog island)}.
var bridges: Array[Dictionary] = []
## Buildings, parallel arrays: model name, x, z (world centre), yaw, scale, height class.
var b_model := PackedStringArray()
var b_pos := PackedVector2Array()
var b_yaw := PackedFloat32Array()
var b_scale := PackedFloat32Array()

## Milliseconds since shape() started, after each step (printed by the dump tests).
var timings := {}

var _cfg: CityConfig
var _data: CityData
var _noise := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _land := PackedByteArray()      # per cell: 0 sea, 1 beach, 2 firm land
var _road := PackedByteArray()      # per half cell: 0 none, 1 street, 2 avenue, 3 highway
var _occ := PackedByteArray()       # per half cell: 1 = a building stands there
var _district := PackedByteArray()  # per cell of 4: district number
var _d_at := PackedVector2Array()   # per district: seed, grid turn (cos, sin), street spacing, density
var _d_cos := PackedFloat32Array()
var _d_sin := PackedFloat32Array()
var _d_sx := PackedFloat32Array()
var _d_sy := PackedFloat32Array()
var _d_dense := PackedFloat32Array()
var _wx := PackedFloat32Array()     # street grid warp per cell
var _wz := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _w := 0                         # half cell grid width
var _h := 0


## Called without arguments when CitySnapshot rebuilds a stored city.
func _init(cfg: CityConfig = null, data: CityData = null) -> void:
	if cfg == null:
		return
	_cfg = cfg
	_data = data
	_rng.seed = cfg.seed + 31337
	_noise.seed = cfg.seed + 4242
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	_noise.frequency = 0.045
	_warp.seed = cfg.seed + 777
	_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_warp.frequency = 0.011
	_w = SIZE.x * 2
	_h = SIZE.y * 2


func shape() -> void:
	var t := Time.get_ticks_msec()
	_build_land()
	timings["land"] = Time.get_ticks_msec() - t
	_plan_bridges()
	_plan_highways()
	_plan_districts()
	timings["plan"] = Time.get_ticks_msec() - t
	_streets()
	timings["streets"] = Time.get_ticks_msec() - t
	_place_buildings()
	timings["buildings"] = Time.get_ticks_msec() - t
	_paint()
	timings["paint"] = Time.get_ticks_msec() - t
	_noise = null
	_warp = null


## True when the world cell (x, z) of the continent grid is firm land.
func is_firm(x: int, z: int) -> bool:
	var lx := x - int(ORIGIN.x)
	var lz := z - int(ORIGIN.y)
	if lx < 0 or lz < 0 or lx >= SIZE.x or lz >= SIZE.y:
		return false
	return _land[lz * SIZE.x + lx] == 2


func is_land(x: int, z: int) -> bool:
	var lx := x - int(ORIGIN.x)
	var lz := z - int(ORIGIN.y)
	if lx < 0 or lz < 0 or lx >= SIZE.x or lz >= SIZE.y:
		return false
	return _land[lz * SIZE.x + lx] >= 1


# --- Land ---------------------------------------------------------------------------------------
func _build_land() -> void:
	elevation.resize(SIZE.x * SIZE.y)
	_land.resize(SIZE.x * SIZE.y)
	for z in SIZE.y:
		for x in SIZE.x:
			var p := ORIGIN + Vector2(x + 0.5, z + 0.5)
			var e := -1.0
			for l in LOBES:
				var d := (p - (l[0] as Vector2)) / (l[1] as Vector2)
				e = maxf(e, 1.0 - d.length_squared())
			e += _noise.get_noise_2d(p.x, p.y) * COAST_NOISE
			# The border of the grid, and the strip next to the city map, stay sea.
			var edge := mini(mini(x, z), mini(SIZE.x - 1 - x, SIZE.y - 1 - z))
			if edge < 6:
				e = minf(e, -0.3 + edge * 0.03)
			elevation[z * SIZE.x + x] = clampi(128 + int(e * 255.0), 0, 255)
			_land[z * SIZE.x + x] = 2 if e > FIRM else (1 if e > LAND else 0)


# --- Bridges --------------------------------------------------------------------------------------
## Where each bridge leaves the fog island and reaches the continent (first land seen from the
## other side), scanned on the real maps.
func _plan_bridges() -> void:
	var fog := _data.fog
	if fog == null:
		return
	var n := FogIslandShaper.SIZE
	# North bridge: up the column NORTH_BRIDGE_X from the north coast of the fog island.
	var cx := int(NORTH_BRIDGE_X)
	var lx := cx - int(fog.origin.x)
	var zf := -1
	for y in n:
		if fog.elevation[y * n + lx] > 128:
			zf = int(fog.origin.y) + y
			break
	if zf > 0:
		var zc := -1
		for z in range(zf - 3, int(ORIGIN.y), -1):
			if is_land(cx, z):
				zc = z + 1
				break
		if zc > 0:
			bridges.append({"from": Vector2(NORTH_BRIDGE_X + 0.5, float(zc)),
					"to": Vector2(NORTH_BRIDGE_X + 0.5, float(zf))})
			highways.append(PackedVector2Array([FOG_STREET_TOP + Vector2(0.5, 0.0),
					Vector2(NORTH_BRIDGE_X + 0.5, float(zf))]))
	# East bridge: along the row EAST_BRIDGE_Z from the east coast of the fog island.
	var row := int(EAST_BRIDGE_Z)
	var ly := row - int(fog.origin.y)
	var xf := -1
	for x in range(n - 1, -1, -1):
		if fog.elevation[ly * n + x] > 128:
			xf = int(fog.origin.x) + x + 1
			break
	if xf > 0:
		var xc := -1
		for x in range(xf + 3, int(ORIGIN.x) + SIZE.x):
			if is_land(x, row):
				xc = x
				break
		if xc > 0:
			bridges.append({"from": Vector2(float(xc), EAST_BRIDGE_Z), "to": Vector2(float(xf), EAST_BRIDGE_Z)})
			highways.append(PackedVector2Array([FOG_AVENUE_END, Vector2(float(xf), EAST_BRIDGE_Z)]))


# --- Highways -------------------------------------------------------------------------------------
## Catmull-Rom curves through the control points, cut where they leave the firm land. The first
## point of a curve that starts at a bridge is moved to the coast point of that bridge.
func _plan_highways() -> void:
	for h in HIGHWAYS:
		var pts: Array = (h as Array).duplicate()
		for b in bridges:
			var head: Vector2 = b["from"]
			if (pts[0] as Vector2).distance_to(head) < 14.0:
				pts[0] = head + (Vector2(0, -1) if is_equal_approx(head.x, NORTH_BRIDGE_X + 0.5) else Vector2(1, 0)) * 1.0
		var samples := PackedVector2Array()
		for i in pts.size() - 1:
			var p0: Vector2 = pts[maxi(i - 1, 0)]
			var p1: Vector2 = pts[i]
			var p2: Vector2 = pts[i + 1]
			var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
			var n := maxi(2, int(p1.distance_to(p2) / 2.0))
			for k in n:
				var t := float(k) / float(n)
				samples.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
						+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
		samples.append(pts[pts.size() - 1])
		var run := PackedVector2Array()
		for s in samples:
			if is_firm(floori(s.x), floori(s.y)):
				run.append(s)
			else:
				if run.size() >= 4:
					highways.append(run)
				run = PackedVector2Array()
		if run.size() >= 4:
			highways.append(run)
	# The beach between a bridge and the first firm cell of its highway is road as well.
	for b in bridges:
		var head: Vector2 = b["from"]
		for h in highways.duplicate():
			if h.size() < 4:
				continue
			for end in [h[0], h[h.size() - 1]]:
				if (end as Vector2).distance_to(head) < 14.0 and (end as Vector2).distance_to(head) > 0.5:
					highways.append(PackedVector2Array([head, end]))


# --- Districts and streets ----------------------------------------------------------------------------
## Seeds on a jittered lattice over the firm land; every district gets its own street grid.
func _plan_districts() -> void:
	var step := 64.0
	var gx := int(ceil(float(SIZE.x) / step))
	var gz := int(ceil(float(SIZE.y) / step))
	for j in gz:
		for i in gx:
			var p := ORIGIN + Vector2((i + 0.15 + _rng.randf() * 0.7) * step, (j + 0.15 + _rng.randf() * 0.7) * step)
			if not is_firm(floori(p.x), floori(p.y)):
				continue
			var yaw := _rng.randf() * PI * 0.5
			_d_at.append(p)
			_d_cos.append(cos(yaw))
			_d_sin.append(sin(yaw))
			_d_sx.append(lerpf(STREET_MIN, STREET_MAX, _rng.randf()))
			_d_sy.append(lerpf(STREET_MIN, STREET_MAX, _rng.randf()))
			_d_dense.append(_rng.randf())
	if _d_at.is_empty():
		_d_at.append(ORIGIN + Vector2(SIZE) * 0.5)
		_d_cos.append(1.0)
		_d_sin.append(0.0)
		_d_sx.append(10.0)
		_d_sy.append(10.0)
		_d_dense.append(0.5)
	# District of every 4 x 4 block of cells.
	var bw := (SIZE.x + 3) / 4
	var bh := (SIZE.y + 3) / 4
	_district.resize(bw * bh)
	for by in bh:
		for bx in bw:
			var p := ORIGIN + Vector2(bx * 4 + 2, by * 4 + 2)
			var best := 0
			var bd := INF
			for k in _d_at.size():
				var d := p.distance_squared_to(_d_at[k])
				if d < bd:
					bd = d
					best = k
			_district[by * bw + bx] = best
	# Warp of the street grid, per cell, on the land only (gentle: streets bend, they do not wiggle).
	_wx.resize(SIZE.x * SIZE.y)
	_wz.resize(SIZE.x * SIZE.y)
	for z in SIZE.y:
		for x in SIZE.x:
			var i := z * SIZE.x + x
			if _land[i] == 0:
				continue
			var wx := ORIGIN.x + x
			var wz := ORIGIN.y + z
			_wx[i] = _warp.get_noise_2d(wx, wz) * WARP
			_wz[i] = _warp.get_noise_2d(wx + 517.0, wz - 233.0) * WARP


func _district_idx(wx: float, wz: float) -> int:
	var bw := (SIZE.x + 3) / 4
	var bh := (SIZE.y + 3) / 4
	var bx := clampi(int((wx - ORIGIN.x) / 4.0), 0, bw - 1)
	var by := clampi(int((wz - ORIGIN.y) / 4.0), 0, bh - 1)
	return _district[by * bw + bx]


## Warped street coordinates (u, v) of the world point (x, z) in district `k`, in street units.
func _grid(k: int, x: float, z: float) -> Vector2:
	var cx := clampi(int(x - ORIGIN.x), 0, SIZE.x - 1)
	var cz := clampi(int(z - ORIGIN.y), 0, SIZE.y - 1)
	var i := cz * SIZE.x + cx
	var px := x + _wx[i]
	var pz := z + _wz[i]
	var c := _d_cos[k]
	var s := _d_sin[k]
	return Vector2((px * c + pz * s) / _d_sx[k], (-px * s + pz * c) / _d_sy[k])


func _streets() -> void:
	_road.resize(_w * _h)
	# Streets: one cell wide, an avenue (two cells) every third line.
	for cz in SIZE.y:
		for cx in SIZE.x:
			var ci := cz * SIZE.x + cx
			if _land[ci] < 2:
				continue
			var k := _district_idx(ORIGIN.x + cx, ORIGIN.y + cz)
			var c := _d_cos[k]
			var sn := _d_sin[k]
			var sx := _d_sx[k]
			var sy := _d_sy[k]
			var ox := ORIGIN.x + cx + _wx[ci]
			var oz := ORIGIN.y + cz + _wz[ci]
			for j in 2:
				for i in 2:
					var px := ox + 0.25 + 0.5 * i
					var pz := oz + 0.25 + 0.5 * j
					var gu := (px * c + pz * sn) / sx
					var gv := (-px * sn + pz * c) / sy
					var iu := floorf(gu)
					var iv := floorf(gv)
					var wu := 2.0 if (int(iu) % 3) == 0 else 1.0
					var wv := 2.0 if (int(iv) % 3) == 0 else 1.0
					var at := (cz * 2 + j) * _w + cx * 2 + i
					if (gu - iu) * sx < wu:
						_road[at] = 2 if wu > 1.5 else 1
					elif (gv - iv) * sy < wv:
						_road[at] = 2 if wv > 1.5 else 1
	# Highways override: every half cell within half the width of a curve.
	for h in highways:
		for i in h.size() - 1:
			_stamp(h[i], h[i + 1], HIGHWAY_WIDTH * 0.5)


## Marks the half cells within `r` of the segment a-b as highway.
func _stamp(a: Vector2, b: Vector2, r: float) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(r, r)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(r, r)
	var x0 := maxi(0, int((lo.x - ORIGIN.x) * 2.0))
	var x1 := mini(_w - 1, int((hi.x - ORIGIN.x) * 2.0) + 1)
	var z0 := maxi(0, int((lo.y - ORIGIN.y) * 2.0))
	var z1 := mini(_h - 1, int((hi.y - ORIGIN.y) * 2.0) + 1)
	var ab := b - a
	var len2 := maxf(ab.length_squared(), 0.0001)
	for hz in range(z0, z1 + 1):
		for hx in range(x0, x1 + 1):
			var p := ORIGIN + Vector2((hx + 0.5) * 0.5, (hz + 0.5) * 0.5)
			var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			if p.distance_to(a + ab * t) <= r:
				_road[hz * _w + hx] = 3


# --- Buildings --------------------------------------------------------------------------------------
func _road_at(wx: float, wz: float) -> int:
	var hx := int((wx - ORIGIN.x) * 2.0)
	var hz := int((wz - ORIGIN.y) * 2.0)
	if hx < 0 or hz < 0 or hx >= _w or hz >= _h:
		return 0
	return _road[hz * _w + hx]


func _place_buildings() -> void:
	_occ.resize(_w * _h)
	# Keep a clear margin beside the highways: mark it as occupied.
	for h in highways:
		for i in h.size() - 1:
			_stamp_occ(h[i], h[i + 1], HIGHWAY_CLEAR)
	var names: Array = MODELS.keys()
	var big: Array = []
	var mid: Array = []
	var small: Array = []
	for n in names:
		var v: Vector3 = MODELS[n]
		var a := v.x * v.z
		if a >= BIG_AREA:
			big.append(n)
		elif a >= SMALL_AREA:
			mid.append(n)
		else:
			small.append(n)
	var classes := [big, mid, small]
	for pass_i in 3:
		var step: float = STEPS[pass_i]
		var pool: Array = classes[pass_i]
		if pool.is_empty():
			continue
		var z := ORIGIN.y + 4.0
		while z < ORIGIN.y + SIZE.y - 4.0:
			var x := ORIGIN.x + 4.0
			while x < ORIGIN.x + SIZE.x - 4.0:
				if b_model.size() >= MAX_BUILDINGS:
					return
				var jitter := Vector2(_rng.randf() - 0.5, _rng.randf() - 0.5) * step * 0.6
				var p := Vector2(x, z) + jitter
				x += step
				if not is_firm(floori(p.x), floori(p.y)):
					continue
				_try_place(p, pool, pass_i)
			z += step * 0.9


func _try_place(p: Vector2, pool: Array, pass_i: int) -> void:
	var h0 := int((p.y - ORIGIN.y) * 2.0) * _w + int((p.x - ORIGIN.x) * 2.0)
	if _occ[h0] != 0 or _road[h0] != 0:
		return
	var k := _district_idx(p.x, p.y)
	# Dense districts take the tall models, the others stay low.
	if pass_i == 0 and _d_dense[k] < 0.35 and _rng.randf() < 0.7:
		return
	var pick: String = pool[_rng.randi() % pool.size()]
	var v: Vector3 = MODELS[pick]
	var s := lerpf(0.94, 1.06, _rng.randf()) * BUILDING_SCALE
	var hw := v.x * s * 0.5
	var hd := v.z * s * 0.5
	# Local direction of the street grid: the gradient of the warped u coordinate.
	var g0 := _grid(k, p.x, p.y)
	var gu := _grid(k, p.x + 1.0, p.y) - g0
	var yaw0 := atan2(gu.y * _d_sy[k], gu.x * _d_sx[k])
	if gu == Vector2.ZERO:
		yaw0 = atan2(_d_cos[k], _d_sin[k])
	# Which side faces a street: probe the four directions of the grid.
	var k0 := _rng.randi() % 4
	var best_k := k0
	for j in 4:
		var a := yaw0 + float(k0 + j) * PI * 0.5
		var probe := p + Vector2(sin(a), cos(a)) * (hd + 1.2)
		if _road_at(probe.x, probe.y) != 0:
			best_k = (k0 + j) % 4
			break
	var yaw := yaw0 + float(best_k) * PI * 0.5
	var m := GAP * 0.5
	if not _fits(p, yaw, hw + m, hd + m):
		return
	_mark(p, yaw, hw + m, hd + m)
	b_model.append(pick)
	b_pos.append(p)
	b_yaw.append(yaw)
	b_scale.append(s)


## Half-cell range covered by the box with half sides (hw along the local x, hd along z).
func _box_range(p: Vector2, yaw: float, hw: float, hd: float) -> Rect2i:
	var ext := absf(cos(yaw)) * hw + absf(sin(yaw)) * hd
	var exz := absf(sin(yaw)) * hw + absf(cos(yaw)) * hd
	var x0 := int(floor((p.x - ext - ORIGIN.x) * 2.0))
	var x1 := int(floor((p.x + ext - ORIGIN.x) * 2.0))
	var z0 := int(floor((p.y - exz - ORIGIN.y) * 2.0))
	var z1 := int(floor((p.y + exz - ORIGIN.y) * 2.0))
	return Rect2i(x0, z0, x1 - x0 + 1, z1 - z0 + 1)


func _fits(p: Vector2, yaw: float, hw: float, hd: float) -> bool:
	var r := _box_range(p, yaw, hw, hd)
	if r.position.x < 0 or r.position.y < 0 or r.end.x > _w or r.end.y > _h:
		return false
	var c := cos(yaw)
	var s := sin(yaw)
	var bx := ORIGIN.x + 0.25 - p.x
	var bz := ORIGIN.y + 0.25 - p.y
	for hz in range(r.position.y, r.end.y):
		var qy := bz + hz * 0.5
		for hx in range(r.position.x, r.end.x):
			var qx := bx + hx * 0.5
			if absf(qx * c - qy * s) > hw or absf(qx * s + qy * c) > hd:
				continue
			var i := hz * _w + hx
			if _occ[i] != 0 or _road[i] != 0 or _land[(hz >> 1) * SIZE.x + (hx >> 1)] < 2:
				return false
	return true


func _mark(p: Vector2, yaw: float, hw: float, hd: float) -> void:
	var r := _box_range(p, yaw, hw, hd)
	var c := cos(yaw)
	var s := sin(yaw)
	var bx := ORIGIN.x + 0.25 - p.x
	var bz := ORIGIN.y + 0.25 - p.y
	for hz in range(r.position.y, r.end.y):
		var qy := bz + hz * 0.5
		for hx in range(r.position.x, r.end.x):
			var qx := bx + hx * 0.5
			if absf(qx * c - qy * s) <= hw and absf(qx * s + qy * c) <= hd:
				_occ[hz * _w + hx] = 1


func _stamp_occ(a: Vector2, b: Vector2, r: float) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(r, r)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(r, r)
	var x0 := maxi(0, int((lo.x - ORIGIN.x) * 2.0))
	var x1 := mini(_w - 1, int((hi.x - ORIGIN.x) * 2.0) + 1)
	var z0 := maxi(0, int((lo.y - ORIGIN.y) * 2.0))
	var z1 := mini(_h - 1, int((hi.y - ORIGIN.y) * 2.0) + 1)
	var ab := b - a
	var len2 := maxf(ab.length_squared(), 0.0001)
	for hz in range(z0, z1 + 1):
		for hx in range(x0, x1 + 1):
			var p := ORIGIN + Vector2((hx + 0.5) * 0.5, (hz + 0.5) * 0.5)
			var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			if p.distance_to(a + ab * t) <= r:
				_occ[hz * _w + hx] = 1


# --- Ground colours ------------------------------------------------------------------------------------
const GRASS := Color("86bd66")
const PAVED := Color("c4c2b8")
const STREET := Color("5c6070")
const AVENUE := Color("50546a")
const HIGHWAY := Color("484c5e")


func _paint() -> void:
	var tw := SIZE.x * RES
	var th := SIZE.y * RES
	colors.resize(tw * th * 4)
	colors.fill(120)
	var rb := PackedByteArray()
	for c: Color in [Color("000000"), STREET, AVENUE, HIGHWAY]:
		rb.append(c.r8)
		rb.append(c.g8)
		rb.append(c.b8)
	for cz in SIZE.y:
		for cx in SIZE.x:
			var land: int = _land[cz * SIZE.x + cx]
			if land == 0:
				continue
			var wx := ORIGIN.x + cx + 0.5
			var wz := ORIGIN.y + cz + 0.5
			var dense := _d_dense[_district_idx(wx, wz)]
			var f := clampf(_noise.get_noise_2d(wx * 2.0, wz * 2.0) * 0.8 + 0.5, 0.0, 1.0)
			var base := GRASS.lerp(PAVED, clampf(0.35 + dense * 0.55, 0.0, 1.0) * 0.8).lerp(Color("78ab5a"), f * 0.25)
			var rocky := _noise.get_noise_2d(cx * 2.0 + 300.0, cz * 2.0) > 0.55
			var under := base.darkened(0.12)
			for oy in RES:
				for ox in RES:
					var hx := cx * 2 + ox
					var hz := cz * 2 + oy
					var r: int = _road[hz * _w + hx]
					var i := ((cz * RES + oy) * tw + cx * RES + ox) * 4
					if r != 0:
						colors[i] = rb[r * 3]
						colors[i + 1] = rb[r * 3 + 1]
						colors[i + 2] = rb[r * 3 + 2]
					else:
						var c := under if (_occ[hz * _w + hx] != 0 and land == 2) else base
						colors[i] = c.r8
						colors[i + 1] = c.g8
						colors[i + 2] = c.b8
					colors[i + 3] = 0 if rocky else 255


## Rect of the continent grid in world cells.
static func rect() -> Rect2:
	return Rect2(ORIGIN, Vector2(SIZE))
