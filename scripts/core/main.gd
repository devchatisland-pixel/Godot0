extends Node3D
## Entry point: generates the city on a worker thread, loads the models a few
## per frame, then hands over to the camera and the chunk streamer.

enum Phase { MENU, GENERATING, LOADING_MODELS, RUNNING }

## Starting zoom (ortho size): the middle of the city, close enough to see its buildings.
## The map starts in the middle of the night (0.78 of the day cycle).
const START_PHASE := 0.78
const START_ZOOM := 62.0

var cfg: CityConfig
var data: CityData
var library: ModelLibrary
var camera: IsoCamera
var streamer: ChunkStreamer
var day_night: DayNight
var picker: BuildingPicker

var _phase := Phase.MENU
var _thread := Thread.new()
var _overlay: LoadingOverlay
var _gen_progress := 0.0
var _gen_text := ""
var _models_progress := 0.0
var _env: Environment
var _sun: DirectionalLight3D


var _t_begin := 0


func _ready() -> void:
	cfg = CityConfig.create()
	_setup_environment()
	_overlay = LoadingOverlay.new()
	add_child(_overlay)
	camera = IsoCamera.new()
	camera.name = "IsoCamera"
	add_child(camera)
	camera.current = true

	if "--capture" in OS.get_cmdline_user_args():
		_begin()
		add_child(load("res://tests/capture_runner.gd").new())
		return
	var menu := MapMenu.new()
	add_child(menu)
	menu.chosen.connect(_on_map_chosen)


func _on_map_chosen(show_continent: bool, show_fog_island: bool) -> void:
	cfg.show_continent = show_continent
	cfg.show_fog_island = show_fog_island
	_begin()


func _begin() -> void:
	_phase = Phase.GENERATING
	_t_begin = Time.get_ticks_msec()
	library = ModelLibrary.new()
	library.lookahead = _loader_lookahead()
	library.begin(cfg)
	if cfg.use_threads:
		_thread.start(_generate_city)
	else:
		_generate_without_thread()


## Test switch for timing the web build: ?loader=old|all|<n>. The web build reads models
## one by one by default (measured: 14 s, against 28 s with 4 files read ahead in the browser).
func _loader_lookahead() -> int:
	if not OS.has_feature("web"):
		return ModelLibrary.DEFAULT_LOOKAHEAD
	var q := str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('loader') || ''"))
	if q == "all":
		return -1
	return int(q) if q.is_valid_int() else 0


func _generate_city() -> CityData:
	# Exported builds ship the city generated at export time (same seed = same city).
	if OS.has_feature("template"):
		_on_gen_progress(0.5, "Unpacking the city")
		var stored := CitySnapshot.load_city(cfg)
		if stored != null:
			return stored
	return CityGenerator.new(cfg, _on_gen_progress).generate()


## Single-threaded builds: let the loading screen draw first, then generate.
func _generate_without_thread() -> void:
	_overlay.set_progress(0.0, "Generating the city")
	for i in 3:
		await get_tree().process_frame
	data = _generate_city()
	_gen_progress = 1.0


func _on_gen_progress(value: float, text: String) -> void:
	_gen_progress = value
	_gen_text = text


func _process(_delta: float) -> void:
	match _phase:
		Phase.GENERATING, Phase.LOADING_MODELS:
			_update_loading()
		Phase.RUNNING:
			streamer.update_view(camera.view_polygon(), camera.zoom)


func _update_loading() -> void:
	# Models load on the main thread while the city generates in the background.
	if _models_progress < 1.0:
		_models_progress = library.load_next(3)
		if _models_progress >= 1.0:
			print("[Startup] models loaded in %d ms (lookahead %d)" % [Time.get_ticks_msec() - _t_begin, library.lookahead])
	var total := _gen_progress * 0.6 + _models_progress * 0.4
	var text := _gen_text if _gen_progress < 1.0 else "Loading buildings"
	_overlay.set_progress(total, text)
	if data == null and _thread.is_started() and not _thread.is_alive():
		data = _thread.wait_to_finish()
		print("[Startup] city generated in %d ms" % (Time.get_ticks_msec() - _t_begin))
	if data != null and _models_progress >= 1.0:
		_start_city()


func _start_city() -> void:
	# Parts switched off on the start screen are never drawn.
	if not cfg.show_fog_island:
		data.fog = null
	if not cfg.show_continent:
		data.continent = null
	ServiceMeshes.build_all(library)
	LandmarkMeshes.build_all(library)
	EntertainmentMeshes.build_all(library)
	NatureMeshes.build_all(library)
	CivicMeshes.build_all(library)
	PublicMeshes.build_all(library)
	MilitaryMeshes.build_all(library)
	NavLights.build_all(library)
	FarmMeshes.build_all(library)
	ParkMeshes.build_all(library)
	NightWindows.apply(library)
	var ground := GroundLayer.new()
	ground.name = "Ground"
	add_child(ground)
	ground.build(cfg, data)
	# Elevation is now in a texture, the CPU copy is no longer needed.
	data.elevation = PackedByteArray()

	streamer = ChunkStreamer.new()
	streamer.name = "City"
	add_child(streamer)
	streamer.setup(cfg, data, library)

	var fog_island: FogIsland = null
	var fog_base: FogBase = null
	if data.fog != null:
		fog_island = FogIsland.new()
		fog_island.name = "FogIsland"
		add_child(fog_island)
		fog_island.build(cfg, data, library)
		fog_base = FogBase.new()
		fog_base.name = "FogBase"
		add_child(fog_base)
		fog_base.build(data, library)
	if data.continent != null:
		var continent := Continent.new()
		continent.name = "Continent"
		add_child(continent)
		continent.build(cfg, data, library, camera)
	var west_bridge := WestBridge.new()
	west_bridge.name = "WestBridge"
	add_child(west_bridge)
	west_bridge.build(data, library)

	var asphalt := HighwaySurface.new()
	asphalt.name = "HighwaySurface"
	add_child(asphalt)
	asphalt.build(data)

	var roadblocks := Roadblocks.new()
	roadblocks.name = "Roadblocks"
	add_child(roadblocks)
	roadblocks.build(data, library)

	var vehicles := MapVehicles.new()
	vehicles.name = "Vehicles"
	add_child(vehicles)
	vehicles.build(data, library)

	var shops := MapShops.new()
	shops.name = "Shops"
	add_child(shops)
	shops.build(data, library)

	var fences := MapFences.new()
	fences.name = "Fences"
	add_child(fences)
	fences.build(data, library)
	var wood_fences := MapWoodFences.new()
	wood_fences.name = "WoodFences"
	add_child(wood_fences)
	wood_fences.build(data, library)
	var club_cycles := MapClubCycles.new()
	club_cycles.name = "ClubCycles"
	add_child(club_cycles)
	club_cycles.build(data, library)
	var jail := PrisonCompound.new()
	jail.name = "Jail"
	add_child(jail)
	jail.build(data, library)

	# Every building can be clicked: glow and information bubble.
	picker = BuildingPicker.new()
	picker.name = "BuildingPicker"
	add_child(picker)
	picker.setup(camera, data, library)
	# Vehicles, shops and roadblock pieces are not numbered buildings: clickable all the same.
	var props := picker.add_props(vehicles) + picker.add_props(shops) + picker.add_props(roadblocks) + picker.add_props(fences) + picker.add_props(jail)
	# The military base, the carriers, the F-111 and the Golden Gate as well.
	if fog_island != null:
		props += picker.add_props(fog_island) + fog_base.picks.size()
		for e in fog_base.picks:
			picker.add_prop(e["mesh"], e["xform"], e["pick"])
	print("[Picker] %d vehicles, shops and roadblock pieces are clickable" % props)

	# Start on the centre of the city (zoom out to see the islands).
	var c := Vector2(data.size, data.size) * 0.5
	camera.setup(cfg, data.size, Vector3(c.x, 0, c.y), START_ZOOM)
	var bounds := Rect2(0, 0, data.size, data.size)
	if data.fog != null:
		bounds = Rect2(0, 0, data.fog.origin.x + FogIslandShaper.SIZE, data.size)
	if data.continent != null:
		bounds = bounds.merge(ContinentShaper.rect())
	camera.set_bounds(bounds)
	_overlay.finish(data.city_name)

	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(_sun, _env, cfg.day_cycle_seconds, START_PHASE)
	day_night.fog_island = fog_island
	_phase = Phase.RUNNING
	print("[Startup] map ready in %d ms" % (Time.get_ticks_msec() - _t_begin))


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = GroundLayer.DEEP_SEA
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.84, 0.95)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	_env = env

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, 22.0, 0.0)
	sun.light_energy = 0.95
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = cfg.shadows
	add_child(sun)
	_sun = sun


func _exit_tree() -> void:
	if _thread.is_started():
		_thread.wait_to_finish()
