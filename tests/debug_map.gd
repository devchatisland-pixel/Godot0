extends SceneTree
## Writes a top-down PNG of the generated city (zones, roads, buildings).
## Run: godot --headless --script res://tests/debug_map.gd -- <output.png>

## Indexed by CityTypes.Zone.
const ZONE_COLORS := [
	Color("2a6fa0"), Color("6fae5a"), Color("3f9a3a"), Color("8a6fc0"), Color("c48fb0"),
	Color("d9b38a"), Color("a7d38f"), Color("9a8f7a"), Color("f0f0f0"), Color("e3b56a"),
	Color("d040c0"), Color("40d080"), Color("ff8060"), Color("606060"), Color("8a7a6a"), Color("c0c040"),
]

func _init() -> void:
	var out := "user://debug_map.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var cfg := CityConfig.create()
	var data := CityGenerator.new(cfg).generate()
	var img := Image.create(data.size, data.size, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	for y in data.size:
		for x in data.size:
			var i := data.idx(x, y)
			var c: Color = ZONE_COLORS[data.zone[i]]
			if data.terrain[i] == CityTypes.Terrain.BEACH:
				c = Color("e8d39a")
			elif data.terrain[i] < CityTypes.Terrain.BEACH:
				c = Color("1f5f8f") if data.terrain[i] == CityTypes.Terrain.DEEP else Color("3f8fbf")
			if data.road[i] != 0:
				c = Color("303030") if (data.road[i] & 3) == 2 else Color("606060")
			img.set_pixel(x, y, c)
	for b in data.building_count():
		var r := data.building_rect(b)
		if CityTypes.is_service(data.b_kind[b]):
			img.fill_rect(r, Color.RED if data.b_kind[b] == CityTypes.Kind.HOSPITAL else Color.YELLOW)
	img.set_pixel(0, 0, Color.BLACK)
	img.resize(data.size * 4, data.size * 4, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	quit()
