extends Node
## Test helper: when the game runs with `-- --capture <dir>`, waits for the
## city, then saves screenshots of several places / zoom levels and quits.

const Kind := CityTypes.Kind
const SHOTS := [
	{"zoom": 62.0, "at": "start"},
	{"zoom": 230.0, "at": "center"},
	{"zoom": 230.0, "at": "center", "night": true},
	{"zoom": 40.0, "at": "bridge"},
	{"zoom": 110.0, "at": "urban"},
	{"zoom": 50.0, "at": "port"},
	{"zoom": 26.0, "at": Kind.MCDONALDS},
	{"zoom": 40.0, "at": Kind.PRISON},
	{"zoom": 40.0, "at": Kind.MOUNTAIN},
	{"zoom": 30.0, "at": Kind.CASINO},
	{"zoom": 45.0, "at": Kind.NUCLEAR_PLANT},
	{"zoom": 30.0, "at": Kind.BT_TOWER, "night": true},
	{"zoom": 22.0, "at": Kind.WATCHTOWER},
	{"zoom": 30.0, "at": Kind.NIGHTCLUB},
	{"zoom": 16.0, "at": Kind.CONCERT},
	{"zoom": 16.0, "at": Kind.FIRE_TRUCK},
	{"zoom": 14.0, "at": "blockade"},
	{"zoom": 16.0, "at": "eiffel"},
	{"zoom": 40.0, "at": Kind.TELECOM_TOWER},
	{"zoom": 40.0, "at": Kind.BT_TOWER, "night": true},
	{"zoom": 9.0, "at": Vector3(26, 0, 45)},
	{"zoom": 12.0, "at": Vector3(196, 0, 212)},
	{"zoom": 12.0, "at": Vector3(207, 0, 218)},
	{"zoom": 9.0, "at": Vector3(9, 0, 9), "night": true},
]

var _dir := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--capture")
	if i >= 0 and i + 1 < args.size():
		_dir = args[i + 1]
	_run()


func _run() -> void:
	var main := get_parent()
	while main.streamer == null:
		await get_tree().process_frame
	var cam: IsoCamera = main.camera
	var data: CityData = main.data
	# The loading screen stays up while the continent is raised: wait for it to go.
	var overlay = main.get("_overlay")
	var waited := 0
	while overlay != null and overlay.visible and waited < 3000:
		await get_tree().process_frame
		waited += 1
	var args := OS.get_cmdline_user_args()
	if "--cityshop" in args:
		await _city_shops(main)
		return
	if "--fogcity" in args:
		await _fog_city(main)
		return
	if "--continent" in args:
		await _continent(main)
		return
	var bi := args.find("--building")
	if bi >= 0 and bi + 1 < args.size():
		await _single(main, int(args[bi + 1]))
		return
	var spots := args.find("--spots")
	if spots >= 0 and spots + 1 < args.size():
		await _spots(main, args[spots + 1])
		return
	var base := cam.target
	# `--shots 4,10` takes only these shots (numbers of SHOTS).
	var only := PackedStringArray()
	var si := args.find("--shots")
	if si >= 0 and si + 1 < args.size():
		only = args[si + 1].split(",")
	for s in SHOTS.size():
		if not only.is_empty() and not only.has(str(s)):
			continue
		var shot: Dictionary = SHOTS[s]
		cam.target = _place(data, shot["at"], base)
		cam.zoom = shot["zoom"]
		cam.set("_zoom_goal", shot["zoom"])
		var frames := 0
		while frames < 600:
			await get_tree().process_frame
			frames += 1
			if frames > 20 and main.streamer.pending_jobs() == 0:
				break
		if main.day_night != null:
			main.day_night.set_phase(0.78 if shot.get("night", false) else 0.2)
		for k in 5:
			await get_tree().process_frame
		var path: String = _dir.path_join("shot_%d.png" % s)
		get_viewport().get_texture().get_image().save_png(path)
		print("[Capture] ", path, " at ", shot["at"], " chunks ", main.streamer.loaded_counts())
	get_tree().quit()


## `-- --capture <dir> --cityshop`: four of the candy shops standing in the streets of the city.
func _city_shops(main: Node) -> void:
	var cam: IsoCamera = main.camera
	var data: CityData = main.data
	var found: Array[Vector3] = []
	for b in data.building_count():
		if data.b_model.get(b, "") == "shop:shop-general-orange-b-unlit":
			var r := data.building_rect(b)
			found.append(Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5))
	print("[Capture] %d city candy shops" % found.size())
	var n := mini(4, found.size())
	for s in n:
		cam.target = found[(s * found.size()) / n]
		cam.zoom = 14.0
		cam.set("_zoom_goal", 14.0)
		for k in 120:
			await get_tree().process_frame
		if main.day_night != null:
			main.day_night.set_phase(0.2)
		for k in 8:
			await get_tree().process_frame
		var path := _dir.path_join("cityshop_%d.png" % s)
		get_viewport().get_texture().get_image().save_png(path)
		print("[Capture] ", path)
	get_tree().quit()


## `-- --capture <dir> --fogcity`: the city of the fog island (centre, shops, port, plant, overview).
func _fog_city(main: Node) -> void:
	var cam: IsoCamera = main.camera
	var shots := [
		[Vector3(418, 0, 193), 60.0, false], [Vector3(418, 0, 193), 230.0, false],
		[Vector3(418, 0, 160), 40.0, false], [Vector3(418, 0, 235), 50.0, false],
		[Vector3(470, 0, 205), 40.0, false], [Vector3(418, 0, 193), 90.0, true],
	]
	for s in shots.size():
		cam.target = shots[s][0]
		cam.zoom = shots[s][1]
		cam.set("_zoom_goal", shots[s][1])
		for k in 40:
			await get_tree().process_frame
		if main.day_night != null:
			main.day_night.set_phase(0.78 if shots[s][2] else 0.2)
		for k in 8:
			await get_tree().process_frame
		var path := _dir.path_join("fogcity_%d.png" % s)
		get_viewport().get_texture().get_image().save_png(path)
		print("[Capture] ", path)
	get_tree().quit()


## `-- --capture <dir> --continent`: the continent from several places (bridges, streets, far).
func _continent(main: Node) -> void:
	var cam: IsoCamera = main.camera
	var shots := [
		[Vector3(472, 0, 120), 55.0, false], [Vector3(515, 0, 191), 55.0, false],
		[Vector3(560, 0, 50), 70.0, false], [Vector3(640, 0, 230), 110.0, false],
		[Vector3(580, 0, 140), 330.0, false], [Vector3(580, 0, 140), 330.0, true],
		[Vector3(600, 0, 60), 45.0, true], [Vector3(472, 0, 120), 40.0, true],
	]
	for s in shots.size():
		cam.target = shots[s][0]
		cam.zoom = shots[s][1]
		cam.set("_zoom_goal", shots[s][1])
		for k in 40:
			await get_tree().process_frame
		if main.day_night != null:
			main.day_night.set_phase(0.78 if shots[s][2] else 0.2)
		for k in 8:
			await get_tree().process_frame
		var path := _dir.path_join("continent_%d.png" % s)
		get_viewport().get_texture().get_image().save_png(path)
		print("[Capture] ", path)
	get_tree().quit()


func _place(data: CityData, at, base: Vector3) -> Vector3:
	if at is Vector3:
		return at
	match at:
		"center", "start":
			return base
		"both":
			return Vector3(data.size, 0, data.size * 0.5)
		"fog":
			var c := data.fog.center()
			return Vector3(c.x, 0, c.y)
		"bridge":
			return Vector3(data.bridge.x + 4, 0, data.bridge.y)
		"eiffel", "blockade":
			return base # their places are not on the map since it went back to PR 64
		"west_bridge":
			return Vector3(data.west_bridge.x - 6, 0, data.west_bridge.z)
		"urban":
			var u := MapLayout.blob("urban")["at"] as Vector2
			return Vector3(u.x + 6.0, 0, u.y - 22.0)
		"port":
			return Vector3(84, 0, 182)
	return _find(data, at, base)


## Centre of the building of `kind` closest to `near` (at a little distance for houses).
func _find(data: CityData, kind: int, near: Vector3) -> Vector3:
	var best := near
	var best_d := INF
	for b in data.building_count():
		if data.b_kind[b] != kind:
			continue
		var r := data.building_rect(b)
		var p := Vector3(r.get_center().x, 0, r.get_center().y)
		var d := p.distance_to(near)
		if kind == Kind.HOUSE:
			d = absf(d - 50.0)
		if d < best_d:
			best_d = d
			best = p
	return best


## One close shot of building `id` (zoom 9, by day) saved as building.png, then quit.
func _single(main: Node, id: int) -> void:
	var cam: IsoCamera = main.camera
	var r: Rect2i = main.data.building_rect(id)
	cam.target = Vector3(r.get_center().x, 0, r.get_center().y)
	cam.zoom = 9.0
	cam.set("_zoom_goal", 9.0)
	var frames := 0
	while frames < 900:
		await get_tree().process_frame
		frames += 1
		if frames > 30 and main.streamer.pending_jobs() == 0:
			break
	if main.day_night != null:
		main.day_night.set_phase(0.2)
	for k in 5:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_dir.path_join("building.png"))
	print("[Capture] building ", id, " saved")
	get_tree().quit()


## `--spots "x,z,zoom;x,z,zoom"`: one shot per cell (spot_0.png, spot_1.png, ...) by day; a
## fourth value 1 takes it at night.
func _spots(main: Node, list: String) -> void:
	var cam: IsoCamera = main.camera
	var n := 0
	for item in list.split(";", false):
		var v := item.split(",")
		cam.target = Vector3(float(v[0]), 0, float(v[1]))
		cam.zoom = float(v[2])
		cam.set("_zoom_goal", float(v[2]))
		var frames := 0
		while frames < 900:
			await get_tree().process_frame
			frames += 1
			if frames > 30 and main.streamer.pending_jobs() == 0:
				break
		if main.day_night != null:
			main.day_night.set_phase(0.78 if v.size() > 3 and v[3] == "1" else 0.2)
		for k in 5:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(_dir.path_join("spot_%d.png" % n))
		print("[Capture] spot ", n, " at ", item)
		n += 1
	get_tree().quit()
