class_name CityConfig
extends RefCounted
## All tunable values in one place. Values adapt to the platform so that
## mobile devices keep a smaller memory and draw-call budget.

# --- World ------------------------------------------------------------------
## Name shown on screen.
var city_name := "Chat City"
## Seed of the whole city. Same seed = same city on every device.
var seed: int = 20240611
## Island grid size in cells (1 cell = 1 Kenney road tile ~ 12 m).
var map_size: int = 128
## Cells per streaming chunk (the unit of loading / unloading).
var chunk_size: int = 32
## Folder scanned recursively for .glb / .gltf models.
var models_root: String = "res://FREEMODELS"

# --- Island shape -------------------------------------------------------------
var island_radius := Vector2(0.8, 0.7) # fraction of half map size (x, y)
var coast_noise := 0.45         # how ragged the coastline is
var beach_width := 0.05
var shallow_width := 0.12

# --- Streaming / LOD --------------------------------------------------------------
## Camera ortho size under which full models are shown.
var near_lod_size := 140.0
## Max chunks with full models kept in memory (LRU).
var max_near_chunks := 48
## Max chunks with box LOD kept in memory.
var max_far_chunks := 400
## Worker jobs running at the same time.
var max_jobs := 4
## Chunk results turned into nodes per frame.
var applies_per_frame := 2
## Max model variants loaded per category (memory guard).
var max_variants := 24

# --- Camera ---------------------------------------------------------------------
var min_zoom := 8.0
var max_zoom := 0.0             # 0 = computed from the map size
var camera_pitch_deg := -30.0
var camera_yaw_deg := 45.0

# --- Rendering ------------------------------------------------------------------
var shadows := false
## Length of a full day and night cycle, in seconds.
var day_cycle_seconds := 240.0
var is_mobile := false
## False on single-threaded web builds: work then runs on the main thread.
var use_threads := true


static func create() -> CityConfig:
	var c := CityConfig.new()
	c.is_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") \
			or OS.has_feature("web_ios")
	if c.is_mobile:
		c.near_lod_size = 80.0
		c.max_near_chunks = 20
		c.max_jobs = 2
		c.applies_per_frame = 1
		c.max_variants = 10
	c.use_threads = not (OS.has_feature("web") and not OS.has_feature("threads"))
	if c.max_zoom <= 0.0:
		c.max_zoom = float(c.map_size) * 1.1
	return c


func chunk_count() -> int:
	return ceili(float(map_size) / float(chunk_size))
