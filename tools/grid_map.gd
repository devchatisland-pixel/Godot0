extends SceneTree
## Data for the grid map: the generated map as JSON (ground, zones, roads, buildings).
## Run: godot --headless --script res://tools/grid_map.gd -- <out.json>
## Then: python tools/grid_map.py <out.json> [grid_map.png]
## The cells are the ones the game uses everywhere: cell (x, y) covers world X in [x, x+1]
## and world Z in [y, y+1]; the information bubble of a building shows them as "cell x,y".

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://grid_map.json"
	var data := CityGenerator.new(CityConfig.create()).generate()
	var names := CityTypes.Kind.keys()
	var buildings := []
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		buildings.append([b, names[data.b_kind[b]], r.position.x, r.position.y, r.size.x, r.size.y])
	var fog := {}
	if data.fog != null:
		var land := PackedByteArray()
		land.resize(FogIslandShaper.SIZE * FogIslandShaper.SIZE)
		for i in land.size():
			land[i] = 1 if data.fog.elevation[i] > 128 else 0
		fog = {"x": int(data.fog.origin.x), "y": int(data.fog.origin.y), "size": FogIslandShaper.SIZE,
				"land": Array(land)}
	var doc := {
		"size": data.size, "chunk": data.chunk_size, "zones": CityTypes.Zone.keys(),
		"terrain": Array(data.terrain), "zone": Array(data.zone), "road": Array(data.road),
		"buildings": buildings, "fog": fog,
		"bridge": [data.bridge.x, data.bridge.y],
		"west_bridge": [data.west_bridge.x, data.west_bridge.y, data.west_bridge.z],
	}
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc))
	f.close()
	print("written ", out)
	quit()
