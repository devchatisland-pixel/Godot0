extends SceneTree
## ASCII view of a region: godot --headless --script res://tests/dump_region.gd -- x0 y0 x1 y1 [more boxes]
## '#' road, '~' not land, digit/letter = building (last char of its number), '.' free land,
## 'T' forest.


func _init() -> void:
	var data := CityGenerator.new(CityConfig.create()).generate()
	var a := OS.get_cmdline_user_args()
	var owner := {}
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				owner[Vector2i(x, y)] = b
	for i in range(0, a.size() - 3, 4):
		var x0 := int(a[i])
		var y0 := int(a[i + 1])
		var x1 := int(a[i + 2])
		var y1 := int(a[i + 3])
		print("[Region] %d,%d to %d,%d" % [x0, y0, x1, y1])
		for y in range(y0, y1 + 1):
			var line := "%4d " % y
			for x in range(x0, x1 + 1):
				var c := "."
				var j := data.idx(x, y)
				if data.terrain[j] != CityTypes.Terrain.LAND:
					c = "~"
				elif data.road[j] != 0:
					c = "#"
				elif owner.has(Vector2i(x, y)):
					c = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"[owner[Vector2i(x, y)] % 26]
				elif data.forest[j] != 0:
					c = "T"
				line += c
			print(line)
		print("[Region] x from %d" % x0)
	quit(0)
