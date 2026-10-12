extends Node3D
## Entry point: reads the baked city and model library when the build has them (CityBake,
## ModelLibrary.BAKE_PATH; tools/bake.gd), else generates the city on a worker thread and
## loads the models a few per frame; then hands over to the camera and the chunk streamer.

enum Phase { GENERATING, LOADING_MODELS, RUNNING }

## Starting zoom (ortho size): the middle of the city, close enough to see its buildings.
## 32 shows half the chunks of the old 62 (12 instead of 24), so the first view is ready
## twice as fast. The map starts in the middle of the night (0.78 of the day cycle).
const START_PHASE := 0.78
const START_ZOOM := 32.0

var cfg: CityConfig
var data: CityData
var library: ModelLibrary
var camera: IsoCamera
var streamer: ChunkStreamer
var day_night: DayNight
var picker: BuildingPicker

var _phase := Phase.GENERATING
var _thread := Thread.new()
var _overlay: LoadingOverlay
var _gen_progress := 0.0
var _gen_text := "Reading the city"
var _models_progress := 0.0
## True while the baked model library is being read in the background.
var _models_baking := false
## The baked chunk lists (ChunkBake), read with the baked city.
var _baked_chunks := {}
var _env: Environment
var _sun: DirectionalLight3D
## Frames since the city is shown, until the first view is complete (see _process).
var _first_view_frames := -1


func _ready() -> void:
	cfg = CityConfig.create()
	_setup_environment()
	_overlay = LoadingOverlay.new()
	add_child(_overlay)
	camera = IsoCamera.new()
	camera.name = "IsoCamera"
	add_child(camera)
	camera.current = true

	library = ModelLibrary.new()
	if ResourceLoader.exists(ModelLibrary.BAKE_PATH) \
			and ResourceLoader.load_threaded_request(ModelLibrary.BAKE_PATH) == OK:
		_models_baking = true
	else:
		library.begin(cfg)
	if cfg.use_threads:
		_thread.start(_generate_city)
	else:
		_generate_without_thread()
	if "--capture" in OS.get_cmdline_user_args():
		add_child(load("res://tests/capture_runner.gd").new())


func _generate_city() -> CityData:
	var t0 := Time.get_ticks_msec()
	var baked := CityBake.load_city(cfg)
	if baked != null:
		_baked_chunks = ChunkBake.read()
		print("[City] read from %s in %d ms (with the chunk lists)" % [CityBake.PATH, Time.get_ticks_msec() - t0])
		return baked
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
			if _first_view_frames >= 0:
				_first_view_frames += 1
				if _first_view_frames > 5 and streamer.pending_jobs() == 0:
					_mark("first view complete, chunks (near, far) %s" % streamer.loaded_counts())
					_first_view_frames = -1


func _update_loading() -> void:
	# Models load on the main thread while the city generates in the background (or the
	# baked library is read in the background).
	if _models_baking:
		_poll_baked_models()
	elif _models_progress < 1.0:
		_models_progress = library.load_next(3)
	var total := _gen_progress * 0.6 + _models_progress * 0.4
	var text := _gen_text if _gen_progress < 1.0 else "Loading buildings"
	_overlay.set_progress(total, text)
	if data == null and _thread.is_started() and not _thread.is_alive():
		data = _thread.wait_to_finish()
		_gen_progress = 1.0
		_mark("city ready")
	if data != null and _models_progress >= 1.0:
		_start_city()


func _poll_baked_models() -> void:
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(ModelLibrary.BAKE_PATH, progress)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_models_progress = minf(float(progress[0]) if not progress.is_empty() else 0.0, 0.99)
		return
	_models_baking = false
	var res: Resource = null
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		res = ResourceLoader.load_threaded_get(ModelLibrary.BAKE_PATH)
	if library.use_bake(res as BakedModels, cfg):
		_models_progress = 1.0
		_mark("baked models read")
	else:
		library.begin(cfg)
		_models_progress = 0.0


## The meshes made in code (services, landmarks, park furniture...); the baked library has them.
static func build_procedural(lib: ModelLibrary) -> void:
	ServiceMeshes.build_all(lib)
	LandmarkMeshes.build_all(lib)
	EntertainmentMeshes.build_all(lib)
	NatureMeshes.build_all(lib)
	CivicMeshes.build_all(lib)
	PublicMeshes.build_all(lib)
	MilitaryMeshes.build_all(lib)
	FarmMeshes.build_all(lib)
	ParkMeshes.build_all(lib)


func _start_city() -> void:
	if not library.baked:
		build_procedural(library)
	_mark("procedural meshes")
	NightWindows.apply(library)
	_mark("night lights")
	var ground := GroundLayer.new()
	ground.name = "Ground"
	add_child(ground)
	ground.build(cfg, data)
	# Elevation is now in a texture, the CPU copy is no longer needed.
	data.elevation = PackedByteArray()
	_mark("ground")

	streamer = ChunkStreamer.new()
	streamer.name = "City"
	add_child(streamer)
	streamer.setup(cfg, data, library, _baked_chunks)
	_baked_chunks = {}

	var fog_island := FogIsland.new()
	fog_island.name = "FogIsland"
	add_child(fog_island)
	fog_island.build(cfg, data, library)
	_mark("fog island")
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
	_mark("bridges, highway, roadblocks")

	var vehicles := MapVehicles.new()
	vehicles.name = "Vehicles"
	add_child(vehicles)
	vehicles.build(data, library)
	_mark("vehicles and props")

	var shops := MapShops.new()
	shops.name = "Shops"
	add_child(shops)
	shops.build(data, library)

	# Every building can be clicked: glow and information bubble.
	picker = BuildingPicker.new()
	picker.name = "BuildingPicker"
	add_child(picker)
	picker.setup(camera, data, library)
	# Vehicles, shops and roadblock pieces are not numbered buildings: clickable all the same.
	var props := picker.add_props(vehicles) + picker.add_props(shops) + picker.add_props(roadblocks)
	print("[Picker] %d vehicles, shops and roadblock pieces are clickable" % props)
	_mark("shops and picker")

	# Start on the centre of the city (zoom out to see the islands).
	var c := Vector2(data.size, data.size) * 0.5
	camera.setup(cfg, data.size, Vector3(c.x, 0, c.y), START_ZOOM)
	camera.set_bounds(Rect2(0, 0, data.fog.origin.x + FogIslandShaper.SIZE, data.size))
	_overlay.finish(data.city_name)

	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(_sun, _env, cfg.day_cycle_seconds, START_PHASE)
	day_night.fog_island = fog_island
	_phase = Phase.RUNNING
	_first_view_frames = 0
	_mark("the city is shown")


## Start-up timing in the log: milliseconds since launch.
func _mark(step: String) -> void:
	print("[Start] %6d ms  %s" % [Time.get_ticks_msec(), step])


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
