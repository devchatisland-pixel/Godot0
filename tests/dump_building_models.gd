extends SceneTree
## Counts, per zone, how many buildings are drawn with each model (vehicles left out):
## godot --headless --path . --script res://tests/dump_building_models.gd -- <out.tsv>
## Columns: zone, kind, model, count.

## Kinds that are vehicles or flying things, not buildings.
const VEHICLE_KINDS := ["BOAT", "FIRE_TRUCK", "BALLOON", "UFO", "TANK", "PIRATE_SHIP"]


func _init() -> void:
	var out := "user://building_models.tsv"
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
	var counts := {}
	for b in data.building_count():
		var kind_name: String = CityTypes.Kind.keys()[data.b_kind[b]]
		if VEHICLE_KINDS.has(kind_name) or kind_name == "EMPTY":
			continue
		var info := BuildingInfo.describe(data, lib, b)
		var key := "%s\t%s\t%s" % [info["zone"], kind_name, info["model"]]
		counts[key] = counts.get(key, 0) + 1
	var keys := counts.keys()
	keys.sort()
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_line("zone\tkind\tmodel\tcount")
	for k in keys:
		f.store_line("%s\t%d" % [k, counts[k]])
	f.close()
	print("[Models] ", keys.size(), " rows, ", data.building_count(), " buildings -> ", ProjectSettings.globalize_path(out))
	quit(0)
