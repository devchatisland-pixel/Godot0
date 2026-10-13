class_name BuildingExtras
extends RefCounted
## Small things added next to a building model: the golden arches, the U.N.
## emblem, the stadium floodlights, and the fillers of empty lots (industrial yards). Pure functions, thread safe.

const Kind := CityTypes.Kind
const Cat := ModelCatalog.Cat

## Helipad of the main hospital model: offset (x, z) from the centre of the model's box and
## size, as fractions of the model width / depth; HOSPITAL_ROOF is the height of the roof as a
## share of the box height. Measured on public_main.glb's hospital (box 4.74 x 2.317 x 3.0):
## the roof is at 2.013 (the blue units above it reach 2.317) and its painted helipad is a
## circle 1.15 across centred at x 0, z -0.358. The lit H sits on it, a little smaller.
const HOSPITAL_PAD := Vector3(0.0, -0.1193, 0.219)
const HOSPITAL_ROOF := 0.8688
## Size of the F-111 jets of the airbase (the model is 1.3 cells across).
const JET_SCALE := 0.85
## The emblem of the U.N. tower is a bit smaller than the tower is wide.
const UN_EMBLEM := 0.38
## The cellhouse of the prison (the school building model): its width inside the walls of the
## "prison" mesh (3.9 wide), and how far behind the middle it stands.
const PRISON_HALL := 2.5
const PRISON_HALL_BACK := 0.22

static func place_extras(data: CityData, lib: ModelLibrary, i: int, kind: int,
		pick: Dictionary, batch: InstanceBatch) -> void:
	var r := data.building_rect(i)
	var seed: int = data.b_seed[i]
	var back := (int(data.b_facing[i]) + 2) % 4
	var o := CityTypes.FACING_OFFSETS[back]
	var lot_center := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
	var to_back := Vector3(o.x * r.size.x, 0, o.y * r.size.y) * 0.5
	var side := Vector3(-o.y, 0, o.x) * (0.6 if seed & 1 else -0.6)
	var xform: Transform3D = pick["xform"]
	var pid: int = pick["id"]
	var box: AABB = lib.bounds[pid]
	if data.b_sign[i] != 0:
		_place_sign(data, lib, i, pid, xform, batch, data.b_sign[i])
	for more: Array in data.b_more_signs.get(i, []):
		_place_sign(data, lib, i, pid, xform, batch, more[0], more[1])
	if lib.cats[pid] == Cat.LIGHTHOUSE_CLUB:
		_lighthouse_neon(lib, xform, batch)
	match kind:
		Kind.CHURCH:
			if lib.model_name(pid) == CROSS_LIGHT_MODEL:
				# A tiny red light glowing on the tip of the cross.
				var tip := box.position + box.size * CROSS_TIP
				batch.add(lib.named_id("cross_light"), xform * Transform3D(Basis.from_scale(Vector3.ONE * CROSS_LIGHT_SIZE), tip))
		Kind.AIRBASE:
			var jets := lib.ids(Cat.JET_F111)
			if not jets.is_empty():
				for spot in MilitaryMeshes.JET_SPOTS:
					var turn := Basis(Vector3.UP, spot[1]).scaled(Vector3.ONE * JET_SCALE)
					var jet := xform * Transform3D(turn, spot[0])
					batch.add(jets[0], jet)
					NavLights.add_to(batch, lib, jets[0], jet)
		Kind.BOAT:
			# Red light on the left side, green on the right (NavLights).
			NavLights.add_to(batch, lib, pid, xform)
		Kind.AIRPORT:
			batch.add(lib.named_id("runway_ext"), xform)
		Kind.STADIUM:
			# Floodlights of the concert camp at the corners of the plot, aimed at the pitch
			# (the stadium itself only lights its inside at night: stadium_night.glb).
			var h := box.size.y * xform.basis.get_scale().y * STADIUM_FLOOD_HEIGHT
			var floods := lib.ids(Cat.FLOODLIGHT)
			if floods.is_empty():
				batch.add(lib.named_id("stadium_lights"), Transform3D(Basis.from_scale(Vector3(r.size.x, h, r.size.y)), lot_center))
			else:
				var s := h / lib.bounds[floods[0]].size.y
				for x in [-STADIUM_FLOOD_CORNER, STADIUM_FLOOD_CORNER]:
					for z in [-STADIUM_FLOOD_CORNER, STADIUM_FLOOD_CORNER]:
						var p := lot_center + Vector3(x * r.size.x, 0, z * r.size.y)
						batch.add(floods[0], _standing(lib, floods[0], p, _side_to((lot_center - p).normalized()), s))
		Kind.BOAT:
			_nav_lights(lib, lib.cats[pid], box, xform, batch)
		Kind.MCDONALDS:
			# Golden arches over the front, lit at night.
			var w := box.size.x * 0.5
			var at := Vector3(box.get_center().x, box.end.y + 0.02, box.get_center().z + box.size.z * 0.3)
			batch.add(lib.named_id("golden_arches"), xform * Transform3D(Basis.from_scale(Vector3(w, w, w)), at))
		Kind.UN_HQ:
			if ModelPools.is_pack_model(lib, pid, Cat.UN_TOWER):
				# Emblem and name high on the front of the tower.
				var front := Vector3(box.get_center().x, box.size.y * 0.66, box.end.z + 0.01)
				var w := box.size.x * UN_EMBLEM
				batch.add(lib.named_id("un_signs"), xform * Transform3D(Basis.from_scale(Vector3(w, w, w)), front))
		Kind.PRISON:
			var halls := lib.ids(Cat.BASE_HALL)
			if not halls.is_empty():
				var hb := lib.bounds[halls[0]]
				var hs := PRISON_HALL / hb.size.x
				var foot := Vector3(hb.get_center().x, hb.position.y, hb.get_center().z)
				batch.add(halls[0], xform * Transform3D(Basis.from_scale(Vector3.ONE * hs),
						Vector3(0, 0.03, -PRISON_HALL_BACK) - foot * hs))
		Kind.MAIN_HOSPITAL:
			if ModelPools.is_pack_model(lib, pid, Cat.HOSPITAL_MAIN):
				# Lit red H over the helipad of the roof.
				var pad := Vector3(box.get_center().x + box.size.x * HOSPITAL_PAD.x,
						box.position.y + box.size.y * HOSPITAL_ROOF + 0.005,
						box.get_center().z + box.size.z * HOSPITAL_PAD.y)
				var w := box.size.x * HOSPITAL_PAD.z
				batch.add(lib.named_id("helipad_h"), xform * Transform3D(Basis.from_scale(Vector3(w, 1, w)), pad))
		Kind.INDUSTRIAL:
			if lib.has_cat(Cat.INDUSTRIAL_PROP) and seed % 3 == 0:
				var props := lib.ids(Cat.INDUSTRIAL_PROP)
				var p := lot_center + to_back * 0.7 + side
				var prop := props[(seed >> 3) % props.size()]
				if lib.bounds[prop].size.x < 1.0 and lib.bounds[prop].size.z < 1.0:
					batch.add(prop, Transform3D(Basis(Vector3.UP, (seed & 3) * PI * 0.5), p))


## Stadium floodlights: as tall as this many times the stadium, at this share of the plot from
## its centre (the corners).
const STADIUM_FLOOD_HEIGHT := 1.6
const STADIUM_FLOOD_CORNER := 0.47
## Navigation lights of the boats: where the red (port) light is in the box of the model (share
## of its size); the green (starboard) one is its mirror across the middle of the boat. Port is
## +X on the boats whose bow is +Z, -X on the fishing boat (wheelhouse forward, gantry aft) and
## the submarine (sail forward), whose bows are -Z. Measured on the models:
## the front corners of the cabin (simple boat), the gunwales near the bow (wooden boat), the
## sides of the wheelhouse (fishing boat), the bridge wings (cargo ship), the sides of the sail
## (submarine).
const NAV_LIGHTS := {
	Cat.BOAT_SIMPLE: Vector3(0.855, 0.436, 0.475),
	Cat.BOAT_WOODEN: Vector3(0.834, 0.971, 0.829),
	Cat.BOAT_FISHING: Vector3(0.281, 0.911, 0.45),
	Cat.BOAT_CARGO: Vector3(0.825, 0.814, 0.289),
	Cat.BOAT_SUB: Vector3(0.423, 0.862, 0.437),
}
## Size of a navigation light, as a share of the width of the boat.
const NAV_LIGHT_SIZE := 0.06


static func _nav_lights(lib: ModelLibrary, cat: int, box: AABB, xform: Transform3D, batch: InstanceBatch) -> void:
	if not NAV_LIGHTS.has(cat):
		return
	var at: Vector3 = NAV_LIGHTS[cat]
	var size := Basis.from_scale(Vector3.ONE * box.size.x * NAV_LIGHT_SIZE)
	var port := box.position + box.size * at
	var starboard := box.position + box.size * Vector3(1.0 - at.x, at.y, at.z)
	batch.add(lib.named_id("nav_light_red"), xform * Transform3D(size, port))
	batch.add(lib.named_id("nav_light_green"), xform * Transform3D(size, starboard))


## Props on industrial yards (gardens and plazas stay bare: there are no trees).
static func place_filler(data: CityData, lib: ModelLibrary, i: int, kind: int, batch: InstanceBatch) -> void:
	if kind == Kind.INDUSTRIAL_YARD:
		_place_yard(lib, data.building_rect(i), data.b_seed[i], batch)


## Scale of the shipping containers of the yards (cells per metre): 6.1 m long = 1.2 cells.
const YARD_BOX_SCALE := 0.2


## The shipping containers of the Low-poly Container pack used on the map (named meshes).
static func _yard_boxes(lib: ModelLibrary) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in ModelLibrary.YARD_CONTAINERS:
		var id := lib.named_id("yardbox:" + String(c).trim_prefix("container-"))
		if id >= 0:
			out.append(id)
	return out


## Industrial yard: stacked containers or oil barrels (cartoon pack), else the Kenney props. The
## containers are the five textures of the Low-poly Container pack; there are no trucks.
static func _place_yard(lib: ModelLibrary, r: Rect2i, seed: int, batch: InstanceBatch) -> void:
	var c := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
	var turn := Basis(Vector3.UP, (seed & 1) * PI * 0.5)
	match seed % 3:
		0:
			var boxes := _yard_boxes(lib)
			if not boxes.is_empty():
				for i in 3:
					var p := c + turn * Vector3(0.0, 0.0, (i - 1) * 0.55)
					var s := Basis.from_scale(Vector3.ONE * YARD_BOX_SCALE)
					batch.add(boxes[((seed >> 3) + i) % boxes.size()], Transform3D(turn * s, p))
					if i == 1:
						batch.add(boxes[(seed >> 5) % boxes.size()],
								Transform3D(turn * s, p + Vector3(0, 2.65 * YARD_BOX_SCALE, 0)))
				return
			var old := lib.ids(Cat.CONTAINER)
			if not old.is_empty():
				for i in 3:
					var p := c + turn * Vector3(0.0, 0.0, (i - 1) * 0.55)
					var s := Basis.from_scale(Vector3(1.5, 1.5, 1.5))
					batch.add(old[(seed >> 3) % old.size()], Transform3D(turn * s, p))
					if i == 1:
						batch.add(old[(seed >> 5) % old.size()], Transform3D(turn * s, p + Vector3(0, 0.62, 0)))
				return
		1:
			var barrels := lib.ids(Cat.BARREL)
			if not barrels.is_empty():
				for i in 5:
					var p := c + Vector3(float(i % 3) - 1.0, 0.0, float(i / 3) - 0.5) * 0.4
					batch.add(barrels[(seed >> (3 + i)) % barrels.size()], Transform3D(Basis.from_scale(Vector3(1.8, 1.8, 1.8)), p))
				return
		_:
			# The truck of the cartoon pack was removed on request: this yard stays bare.
			return
	var props := lib.ids(Cat.INDUSTRIAL_PROP)
	if not props.is_empty():
		var prop := props[seed % props.size()]
		var boxes := _yard_boxes(lib)
		if not boxes.is_empty() and lib.model_name(prop).contains("shipping-container"):
			batch.add(boxes[seed % boxes.size()], Transform3D(turn * Basis.from_scale(Vector3.ONE * YARD_BOX_SCALE), c))
			return
		batch.add(prop, Transform3D(Basis(Vector3.UP, (seed & 1) * PI * 0.5), c))


## Neon signs by model category: "roof" stands on the roof of the building at its south
## edge (on the highest point under the sign), "wall" hangs on its south wall at `height` (share of the building
## height). `scale` shrinks the model; `halo` is the size of the glow copy drawn behind it.
## "face" hangs flat on the wall the sign was set up for (CityData.b_sign_facing: east or south,
## the two walls the camera sees), in the middle of it, `fill` of the wall wide, at `height`.
## Church model whose cross carries a red light: where the tip of the cross is in the box of
## the model (share of its size), and the size of the light.
const CROSS_LIGHT_MODEL := "free_mini.glb: m12"
const CROSS_TIP := Vector3(0.48, 1.0, 0.83)
const CROSS_LIGHT_SIZE := 0.035
## "blade" (Taiwan signboards) sticks out of the east wall from its brackets (the -X end of the
## model), `out` cells long, its face to the south; "corner" (the LED band) wraps the south-east
## corner, along `fill` of the east wall. A roof sign with `deep` stands wholly on the roof
## (a board on legs), its front at the edge, instead of centred on the edge.
const ROOF_EDGE_INSET := 0.1
const SIGNS := {
	ModelCatalog.Cat.NEON_CONTROLLER: {"mount": "wall", "scale": 0.2, "height": 0.45, "halo": 1.25},
	ModelCatalog.Cat.NEON_PACMAN: {"mount": "roof", "scale": 0.58, "halo": 1.15, "yaw": PI * 0.5},
	ModelCatalog.Cat.NEON_WOMAN: {"mount": "face", "fill": 1.1, "height": 0.5, "max_height": 1.1, "halo": 1.12,
			"scale": 0.6},
	ModelCatalog.Cat.SIGN_WINDOWS: {"mount": "face", "fill": 0.86, "height": 0.6, "halo": 1.0},
	ModelCatalog.Cat.NEON_JOYSTICK: {"mount": "face", "fill": 0.9, "height": 0.6, "halo": 1.08},
	ModelCatalog.Cat.NEON_MARTINI: {"mount": "face", "fill": 0.9, "height": 0.58, "halo": 1.08},
	ModelCatalog.Cat.NEON_BAR: {"mount": "face", "fill": 0.55, "height": 0.6, "max_height": 0.3, "halo": 1.08},
	ModelCatalog.Cat.NEON_BULL: {"mount": "face", "fill": 0.9, "height": 0.6, "halo": 1.08, "scale": 0.55},
	ModelCatalog.Cat.NEON_FUN: {"mount": "face", "fill": 0.9, "height": 0.6, "halo": 1.08},
	ModelCatalog.Cat.NEON_PALM: {"mount": "face", "fill": 0.85, "height": 0.58, "halo": 1.08},
	ModelCatalog.Cat.NEON_CLUB: {"mount": "roof", "scale": 1.0, "halo": 1.1},
	ModelCatalog.Cat.NEON_GIRL: {"mount": "roof", "scale": 1.0, "halo": 1.1, "fill": 0.9, "height": 0.55},
	ModelCatalog.Cat.NEON_LOVE: {"mount": "roof", "scale": 1.0, "halo": 1.1},
	ModelCatalog.Cat.TW_BANASONIC: {"mount": "blade", "out": 2.6, "height": 0.45},
	ModelCatalog.Cat.TW_MCDONALDS: {"mount": "blade", "out": 2.0, "height": 0.45},
	ModelCatalog.Cat.TW_COLA_JP: {"mount": "blade", "out": 1.4, "height": 0.42},
	ModelCatalog.Cat.TW_COLA_BILLBOARD: {"mount": "roof", "scale": 1.0, "yaw": PI * 0.5, "deep": true},
	ModelCatalog.Cat.TW_LED_BOARD: {"mount": "roof", "scale": 1.0, "yaw": PI * 0.5, "deep": true},
	ModelCatalog.Cat.TW_LED_BAND: {"mount": "corner", "fill": 0.95, "height": 0.35},
	# The Vice City logo: a giant board on the roof of its tower (a board on legs, front at the east edge).
	ModelCatalog.Cat.SIGN_VICE_CITY: {"mount": "roof", "scale": 1.0, "yaw": PI * 0.5, "deep": true, "halo": 1.08},
}
## A wall sign is at most this share of the building's height (its spec may say "max_height").
const FACE_MAX_HEIGHT := 0.5


## Sign `cat` on building `i`. `mount` puts it somewhere else than its entry of SIGNS says (a
## wall sign moved to the roof: it then looks the way the signs of the building look).
static func _place_sign(data: CityData, lib: ModelLibrary, i: int, pid: int, xform: Transform3D,
		batch: InstanceBatch, cat: int, mount: String = "") -> void:
	var ids := lib.ids(cat)
	if ids.is_empty() or not SIGNS.has(cat):
		return
	var spec: Dictionary = SIGNS[cat]
	if mount != "" and mount != spec["mount"]:
		spec = spec.duplicate()
		spec["mount"] = mount
		if mount == "roof" and int(data.b_sign_facing[i]) == 1:
			spec["yaw"] = PI * 0.5
	var s: float = spec.get("scale", 1.0)
	var yaw: float = spec.get("yaw", 0.0)
	# The sign stays where it was put when the building is turned afterwards.
	var anchor := BuildingPlacer.pick_for(data, lib, i, data.b_sign_facing[i])
	if not anchor.is_empty():
		pid = anchor["id"]
		xform = anchor["xform"]
	var body: AABB = xform * lib.bounds[pid]
	var model := lib.bounds[ids[0]]
	var local_center := Vector3(model.get_center().x, model.position.y, model.get_center().z)
	var at := Vector3(body.get_center().x, 0.0, body.get_center().z)
	if spec["mount"] == "wall":
		local_center = model.get_center()
		at.y = body.position.y + body.size.y * float(spec["height"])
		at.z = body.end.z + 0.02
	elif spec["mount"] == "face":
		var east := int(data.b_sign_facing[i]) == 1
		var wall := body.size.z if east else body.size.x
		s = minf(wall * float(spec["fill"]) / model.size.x,
					body.size.y * float(spec.get("max_height", FACE_MAX_HEIGHT)) / model.size.y)
		# Its back against the wall, its face (+Z of the model) outwards.
		local_center = Vector3(model.get_center().x, model.get_center().y, model.position.z)
		at.y = body.position.y + body.size.y * float(spec["height"])
		if east:
			yaw = PI * 0.5
			at.x = body.end.x + 0.02
		else:
			at.z = body.end.z + 0.02
	elif spec["mount"] == "blade":
		s = minf(float(spec["out"]) / model.size.x, body.size.y * FACE_MAX_HEIGHT / model.size.y)
		local_center = Vector3(model.position.x, model.get_center().y, model.get_center().z)
		at = Vector3(body.end.x, body.position.y + body.size.y * float(spec["height"]), body.get_center().z)
	elif spec["mount"] == "corner":
		s = body.size.z * float(spec["fill"]) / model.size.z
		local_center = Vector3(model.end.x, model.get_center().y, model.end.z)
		at = Vector3(body.end.x + 0.02, body.position.y + body.size.y * float(spec["height"]), body.end.z + 0.02)
	else:
		# A parapet sign: on the flat roof of the model (not on the box of the whole model, which
		# also holds annexes and masts), flush with the roof edge the sign faces (south, or east
		# when it is turned 90 degrees), centred along that edge and no longer than it.
		var roof := _roof(lib, pid, xform)
		var rr: Rect2 = roof["rect"]
		var east := absf(sin(yaw)) > 0.5
		var edge_len := rr.size.y if east else rr.size.x
		s = minf(s, edge_len * 0.92 / model.size.x)
		var inset := ROOF_EDGE_INSET + (model.size.z * s * 0.5 if spec.get("deep", false) else 0.0)
		if east:
			at.x = rr.end.x - inset
			at.z = rr.get_center().y
		else:
			at.x = rr.get_center().x
			at.z = rr.end.y - inset
		at.y = roof["y"]
	var turn := Basis(Vector3.UP, yaw)
	batch.add(ids[0], Transform3D(turn * Basis.from_scale(Vector3(s, s, s)), at - turn * (local_center * s)))
	var halo := lib.named_id("neon_halo_%d" % cat)
	if halo >= 0:
		var h: float = s * float(spec["halo"])
		var back := Vector3(0, 0, -0.03)
		batch.add(halo, Transform3D(turn * Basis.from_scale(Vector3(h, h, s)),
				at + back - turn * (local_center * Vector3(h, h, s))))


## The glowing part of the "Light House Club" sign of the lighthouse club: built in the frame
## of the building (tools/build_wave16_models.py), so it takes the same transform; its halo is
## a bigger copy round the middle of the sign.
const LIGHTHOUSE_HALO := 1.08


static func _lighthouse_neon(lib: ModelLibrary, xform: Transform3D, batch: InstanceBatch) -> void:
	var ids := lib.ids(Cat.NEON_LIGHTHOUSE)
	if ids.is_empty():
		return
	batch.add(ids[0], xform)
	var halo := lib.named_id("neon_halo_%d" % Cat.NEON_LIGHTHOUSE)
	if halo >= 0:
		var c := lib.bounds[ids[0]].get_center()
		var grow := Transform3D(Basis.from_scale(Vector3(LIGHTHOUSE_HALO, LIGHTHOUSE_HALO, 1.0)),
				c - c * Vector3(LIGHTHOUSE_HALO, LIGHTHOUSE_HALO, 1.0) - Vector3(0, 0, 0.03))
		batch.add(halo, xform * grow)


## The flat roof of a model placed with `xform`: {"y": height, "rect": Rect2 in x, z}. The roof
## level is the height (above the middle of the model) holding the most vertices; its rect is
## the box of the vertices at that level.
static func _roof(lib: ModelLibrary, id: int, xform: Transform3D) -> Dictionary:
	var mesh := lib.meshes[id]
	var pts := PackedVector3Array()
	var top := -INF
	for sf in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(sf)[Mesh.ARRAY_VERTEX]
		for v in verts:
			var p := xform * v
			pts.append(p)
			top = maxf(top, p.y)
	var counts := {}
	var best_key := 0
	for p in pts:
		if p.y < top * 0.5:
			continue
		var key := int(round(p.y * 50.0))
		counts[key] = counts.get(key, 0) + 1
		if counts[key] > counts.get(best_key, 0):
			best_key = key
	var level := float(best_key) / 50.0
	var rect := _level_rect(pts, level)
	if rect.size == Vector2.ZERO:
		var b := xform * lib.bounds[id]
		return {"y": b.end.y, "rect": Rect2(b.position.x, b.position.z, b.size.x, b.size.z)}
	# A lid over the whole of that level (a tower whose top band has fewer corners than a ledge
	# below it) is the real roof: a sign on the ledge would be buried in the top band.
	var lid := _level_rect(pts, top)
	if top > level + 0.05 and lid.get_area() >= rect.get_area() * 0.9:
		return {"y": top, "rect": lid}
	return {"y": level, "rect": rect}


## Box (x, z) of the points at height `level`; zero size when there are none.
static func _level_rect(pts: PackedVector3Array, level: float) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		if absf(p.y - level) <= 0.03:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	if lo.x == INF:
		return Rect2()
	return Rect2(lo, hi - lo)


# --- Concert camp (ConcertSite) ---------------------------------------------------------------
## The stage stands at the back of the camp (its back to the sea), the crowd in front of it.
## Distances are in cells, along the camp: u across it, v from its back edge to its gate.
## Gap between the stage and the front-of-stage barrier.
const CONCERT_PIT := 0.6
## The barrier model is as tall as a man on the stage: drawn at half its size.
const CONCERT_BARRIER_SCALE := 0.5
## Floodlight heads look along the model's local +X, bleacher seats along its local -X.
const CONCERT_SIDE_TURN := -PI * 0.5
const CONCERT_SEAT_TURN := PI


## Axes of the camp of building `i`: {"back": centre of its back edge, "right", "front",
## "width", "depth"}.
static func _camp_axes(data: CityData, i: int) -> Dictionary:
	var r := data.building_rect(i)
	var o := CityTypes.FACING_OFFSETS[int(data.b_facing[i]) % 4]
	var front := Vector3(o.x, 0, o.y)
	var depth := float(r.size.y if o.y != 0 else r.size.x)
	var center := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
	return {"back": center - front * depth * 0.5, "right": Vector3(-o.y, 0, o.x), "front": front,
			"width": float(r.size.x if o.y != 0 else r.size.y), "depth": depth}


static func _camp_at(ax: Dictionary, u: float, v: float) -> Vector3:
	return ax["back"] + ax["right"] * u + ax["front"] * v


## Turned by `yaw`, the bottom centre of the model's box on `p`.
static func _standing(lib: ModelLibrary, id: int, p: Vector3, yaw: float, scale: float = 1.0) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * scale)
	var box := lib.bounds[id]
	return Transform3D(basis, p - basis * Vector3(box.get_center().x, box.position.y, box.get_center().z))


## Yaw that turns the model's local +X towards `dir`.
static func _side_to(dir: Vector3) -> float:
	return atan2(dir.x, dir.z) + CONCERT_SIDE_TURN


## The stage of the camp: {"id", "xform"}, or {} when the model is missing.
static func concert_stage(data: CityData, lib: ModelLibrary, i: int) -> Dictionary:
	var ids := lib.ids(Cat.CONCERT_STAGE)
	if ids.is_empty():
		return {}
	var ax := _camp_axes(data, i)
	var depth := lib.bounds[ids[0]].size.z
	var yaw := CityTypes.facing_yaw(int(data.b_facing[i]) % 4)
	return {"id": ids[0], "xform": _standing(lib, ids[0], _camp_at(ax, 0.0, depth * 0.5 + 0.4), yaw)}


## Stage, floodlights, bleachers and crowd barriers; only a box for the stage when far.
static func place_concert(data: CityData, lib: ModelLibrary, i: int, batch: InstanceBatch, far: bool) -> void:
	var stage := concert_stage(data, lib, i)
	if stage.is_empty():
		return
	var sid: int = stage["id"]
	if far:
		var box: AABB = stage["xform"] * lib.bounds[sid]
		batch.add_box(Transform3D(Basis.from_scale(box.size), box.get_center() - Vector3(0, box.size.y * 0.5, 0)),
				Color("4a3a5c"))
		return
	batch.add(sid, stage["xform"])
	var ax := _camp_axes(data, i)
	var w: float = ax["width"]
	var d: float = ax["depth"]
	var front: Vector3 = ax["front"]
	var right: Vector3 = ax["right"]
	var sw := lib.bounds[sid].size.x
	var sd := lib.bounds[sid].size.z
	var stage_mid := _camp_at(ax, 0.0, sd * 0.5 + 0.4)

	# Crowd barrier: one line in front of the stage (no fence round the camp).
	var barriers := lib.ids(Cat.CROWD_BARRIER)
	if not barriers.is_empty():
		_barrier_line(lib, barriers[0], _camp_at(ax, -sw * 0.5, sd + 0.4 + CONCERT_PIT),
				_camp_at(ax, sw * 0.5, sd + 0.4 + CONCERT_PIT), batch)

	# Floodlights: two beside the stage, two at the back corners of the crowd, all aimed at it.
	var lights := lib.ids(Cat.FLOODLIGHT)
	if not lights.is_empty():
		for p: Vector3 in [_camp_at(ax, -sw * 0.5 - 0.7, 0.8), _camp_at(ax, sw * 0.5 + 0.7, 0.8),
				_camp_at(ax, -w * 0.5 + 1.0, d - 2.0), _camp_at(ax, w * 0.5 - 1.0, d - 2.0)]:
			var to := stage_mid - p
			to.y = 0.0
			batch.add(lights[0], _standing(lib, lights[0], p, _side_to(to.normalized())))

	# Bleachers: a row at the back of the crowd and two on each side, all looking at the stage.
	var stands := lib.ids(Cat.BLEACHER)
	if not stands.is_empty():
		var bl := lib.bounds[stands[0]].size.z + 0.15
		var row := mini(4, int((w - 4.0) / bl))
		for k in row:
			var u := (float(k) - (row - 1) * 0.5) * bl
			batch.add(stands[0], _standing(lib, stands[0], _camp_at(ax, u, d - 1.3),
					_side_to(-front) + CONCERT_SEAT_TURN))
		for side in [-1.0, 1.0]:
			for k in 2:
				var p := _camp_at(ax, side * (w * 0.5 - 1.1), d * 0.45 + k * bl)
				batch.add(stands[0], _standing(lib, stands[0], p, _side_to(-right * side) + CONCERT_SEAT_TURN))


## Barriers end to end from `a` to `b` (the model is long along its local Z).
static func _barrier_line(lib: ModelLibrary, id: int, a: Vector3, b: Vector3, batch: InstanceBatch) -> void:
	var piece := lib.bounds[id].size.z * CONCERT_BARRIER_SCALE
	var dist := a.distance_to(b)
	if piece <= 0.0 or dist < piece:
		return
	var dir := (b - a) / dist
	var n := int(dist / piece)
	var start := a + dir * (dist - n * piece) * 0.5
	var yaw := atan2(dir.x, dir.z)
	for k in n:
		batch.add(id, _standing(lib, id, start + dir * (k + 0.5) * piece, yaw, CONCERT_BARRIER_SCALE))
