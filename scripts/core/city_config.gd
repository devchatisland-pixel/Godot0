class_name CityConfig
extends RefCounted
## All tunable values in one place. Values adapt to the platform so that
## mobile devices keep a smaller memory and draw-call budget.

# --- World ------------------------------------------------------------------
## Seed of the whole city. Same seed = same city on every device.
var seed: int = 20240611
## Island grid size in cells (1 cell = 1 Kenney road tile ~ 12 m).
var map_size: int = 640
## Cells per streaming chunk (the unit of loading / unloading).
var chunk_size: int = 48
## Folder scanned recursively for .glb / .gltf models.
var models_root: String = "res://FREEMODELS"

# --- Island shape -------------------------------------------------------------
var island_radius := 0.86       # fraction of half map size
var coast_noise := 0.75         # how ragged the coastline is
var beach_width := 0.035
var shallow_width := 0.10

# --- City layout ----------------------------------------------------------------
var sub_centers := 4            # secondary town centers around downtown
var urban_threshold := 0.16     # density under this stays nature
var park_chance := 0.05         # random extra parks among residential blocks

# --- Streaming / LOD --------------------------------------------------------------
## Camera ortho size under which full models are shown.
var near_lod_size := 90.0
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
var is_mobile := false


static func create() -> CityConfig:
	var c := CityConfig.new()
	c.is_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") \
			or OS.has_feature("web_ios")
	if c.is_mobile:
		c.map_size = 512
		c.near_lod_size = 60.0
		c.max_near_chunks = 20
		c.max_far_chunks = 160
		c.max_jobs = 2
		c.applies_per_frame = 1
		c.max_variants = 10
	if c.max_zoom <= 0.0:
		c.max_zoom = float(c.map_size) * 0.75
	return c


func chunk_count() -> int:
	return ceili(float(map_size) / float(chunk_size))
