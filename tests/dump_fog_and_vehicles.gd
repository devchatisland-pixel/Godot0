extends SceneTree
## Counts the models of the fog island (buildings and vehicles) and of every vehicle on the whole map,
## per zone: godot --headless --path . --script res://tests/dump_fog_and_vehicles.gd -- <out.tsv>
## Columns: area, group, zone, kind, label, key, count.
##   key = what tools/render_zone_models.gd takes to draw it ("veh:<catalog id>", "shop:<id>" or a model name).

const Cat := ModelCatalog.Cat
const VEHICLE_KINDS := ["BOAT", "FIRE_TRUCK", "BALLOON", "UFO", "TANK", "PIRATE_SHIP"]

var _counts := {}


func _add(area: String, group: String, zone: String, kind: String, label: String, key: String, n: int = 1) -> void:
	if RemovedModels.has(key):
		return # taken off the map by hand (not drawn)
	var k := "\t".join([area, group, zone, kind, label, key])
	_counts[k] = _counts.get(k, 0) + n


## Part of the fog island a local cell belongs to.
static func fog_zone(at: Vector2) -> String:
	if Rect2(0, 89, 36, 15).has_point(at):
		return "CHECKPOINT"
	if FogBaseSites.BASE_RECT.grow(1.0).has_point(at):
		return "ARMY BASE"
	if FogBaseSites.PLANT_RECT.grow(1.0).has_point(at):
		return "NUCLEAR PLANT"
	if FogBaseSites.INDUSTRY_RECT.grow(2.0).has_point(at):
		return "INDUSTRY"
	if FogBaseSites.FARM_RECT.grow(4.0).has_point(at):
		return "FARM"
	var d := Vector2(at.x - FogCityLayout.CENTER.x, (at.y - FogCityLayout.CENTER.y) * 1.1).length()
	if d < FogCityLayout.CORE_R:
		return "CITY CORE"
	if d < FogCityLayout.MID_R:
		return "CITY MIDDLE"
	if d < FogCityLayout.MIXED_R:
		return "CITY MIXED"
	return "CITY SUBURBS"


func _init() -> void:
	var out := "user://fog_vehicles.tsv"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var cfg := CityConfig.create()
	cfg.use_threads = false
	var data := CityGenerator.new(cfg).generate()
	var lib := ModelLibrary.new()
	lib.begin(cfg)
	while lib.load_next(40) < 1.0:
		pass

	# --- The fog island ---
	var fog := data.fog
	for p in FogBaseSites.plan(fog):
		var at: Vector2 = p["at"]
		var z := fog_zone(at)
		if p.get("landing_zone", false):
			var id := -1
			for b in data.building_count():
				if data.b_kind[b] == CityTypes.Kind.AIRBASE:
					id = int(BuildingPlacer.pick_for(data, lib, b).get("id", -1))
					break
			if id >= 0:
				_add("FOG", "BUILDING", z, "LANDING_ZONE", lib.model_name(id), lib.model_name(id))
		elif p.has("veh"):
			var vid: String = p["veh"]
			_add("FOG", "VEHICLE", z, "VEHICLE", "%s (%s)" % [MapVehicles.entry(vid).get("name", vid), vid], "veh:" + vid)
		elif p.has("shop"):
			var sid: String = p["shop"]
			_add("FOG", "BUILDING", z, "SHOP", "%s (%s)" % [MapShops.entry(sid).get("name", sid), sid], "shop:" + sid)
		elif p.has("named"):
			var nm: String = p["named"]
			var kind := "CONTAINER" if nm.begins_with("yardbox:") else "FIELD"
			_add("FOG", "BUILDING", z, kind, nm, nm)
		elif p.has("cat"):
			var ids := lib.ids(p["cat"])
			if ids.is_empty():
				continue
			var mid: int = ids[int(p.get("v", 0)) % ids.size()]
			var kind2: String = FogBase.TITLES.get(p["cat"], ["", "BUILDING"])[1]
			var is_veh := kind2 == "VEHICLE"
			_add("FOG", "VEHICLE" if is_veh else "BUILDING", z, ModelCatalog.Cat.keys()[p["cat"]], lib.model_name(mid), lib.model_name(mid))
	var carriers := lib.ids(Cat.CARRIER)
	if not carriers.is_empty():
		_add("FOG", "VEHICLE", "SEA AROUND THE ISLAND", "CARRIER", lib.model_name(carriers[0]), lib.model_name(carriers[0]), FogBase.CARRIER_KEPT.size() + 4)
	var jets := lib.ids(Cat.JET_F111)
	if not jets.is_empty():
		_add("FOG", "VEHICLE", "SKY NORTH OF THE MAIN ISLAND", "AIRCRAFT", lib.model_name(jets[0]), lib.model_name(jets[0]), 3)

	# --- Vehicles of the whole map ---
	for p in VehicleSites.plan(data, MapVehicles.lengths_m()):
		var vid2: String = p["id"]
		var at2: Vector2 = p["at"]
		var zone: String = CityTypes.Zone.keys()[data.zone_at(int(at2.x), int(at2.y))]
		_add("MAIN", "VEHICLE", zone, "VEHICLE", "%s (%s)" % [MapVehicles.entry(vid2).get("name", vid2), vid2], "veh:" + vid2)
	for b in data.building_count():
		var kn: String = CityTypes.Kind.keys()[data.b_kind[b]]
		if not VEHICLE_KINDS.has(kn):
			continue
		var info := BuildingInfo.describe(data, lib, b)
		if info["model_id"] < 0:
			continue
		_add("MAIN", "VEHICLE", info["zone"], kn, info["model"], info["model"])
	var holder := Node3D.new()
	root.add_child(holder)
	var roadblocks := Roadblocks.new()
	holder.add_child(roadblocks)
	roadblocks.build(data, lib)
	for c in roadblocks.get_children():
		if not c.has_meta("pick"):
			continue
		var pk: Dictionary = c.get_meta("pick")
		var title: String = pk["title"]
		if not (pk["kind"] == "VEHICLE" or title.begins_with("Police car") or title.begins_with("Tank")):
			continue
		var o: Vector3 = (c as Node3D).position
		var zn: String = CityTypes.Zone.keys()[data.zone_at(int(o.x), int(o.z))]
		_add("MAIN", "VEHICLE", zn + " (roadblock)", "ROADBLOCK_VEHICLE", title + ": " + pk["model"], pk["model"])

	var keys := _counts.keys()
	keys.sort()
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_line("area\tgroup\tzone\tkind\tlabel\tkey\tcount")
	for k in keys:
		f.store_line("%s\t%d" % [k, _counts[k]])
	f.close()
	print("[FogVeh] %d rows -> %s" % [keys.size(), out])
	quit(0)
