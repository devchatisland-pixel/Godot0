extends SceneTree
## Audit of the generated map against tests/baseline/map_snapshot.json (see MapAudit).
## Run: godot --headless --script res://tests/test_map_audit.gd
##      godot --headless --script res://tests/test_map_audit.gd -- --write   (new baseline)
##      ... -- --details   also lists where the road problems are
##      ... -- --write-roads   renews only the road counters and the map hash of the baseline
##      ... -- --hash      only prints the hash of the whole map (MapAudit.data_hash)
##      ... -- --same      fails unless the map is exactly the baseline map (for refactorings)
## What must be kept (fails when it changes): buildings per kind, trees on the ground, the
## zones that touch each other, the fog island. The road problems are printed with the
## baseline value beside them; a problem that gets worse fails, and the rebuilt map must
## bring them all to zero (STRICT below).

const BASELINE := "res://tests/baseline/map_snapshot.json"
## Set to true once the roads are rebuilt: every road problem then fails the test.
const STRICT := true
## Road counters that are problems (lower is better, zero is the goal).
const PROBLEMS: Array[String] = [
	"cells_off_network", "on_water", "under_buildings", "overlapping_buildings",
	"lots_without_road", "stubs", "diagonal_gaps", "fat_roads",
]

## Buildings of a kind may differ from the baseline by this many, or this share, until the
## budgets of phase 3 set the counts (docs/map_rebuild_plan.md).
const KIND_SLACK := 4
const KIND_SLACK_SHARE := 0.08

var _fails := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var cfg := CityConfig.create()
	var data := CityGenerator.new(cfg).generate()
	var map_hash := MapAudit.data_hash(data)
	print("[Audit] map hash ", map_hash)
	if args.has("--hash"):
		quit(0)
		return
	if args.has("--same"):
		var old = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
		var same: bool = old is Dictionary and old.get("map_hash", "") == map_hash
		print("[Test] %s" % ("the map is the same as the baseline" if same else "FAILED: the map is not the baseline map"))
		quit(0 if same else 1)
		return
	var snap := MapAudit.snapshot(data)
	snap["map_hash"] = map_hash
	snap["ground_trees"] = _ground_trees(cfg, data)
	if args.has("--details"):
		_details(data)
	if args.has("--write-roads"):
		# The roads changed on purpose: only their counters and the hash of the map are renewed.
		var kept = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
		kept["roads"] = snap["roads"]
		kept["map_hash"] = snap["map_hash"]
		kept["size"] = snap["size"]
		var fw := FileAccess.open(BASELINE, FileAccess.WRITE)
		fw.store_string(JSON.stringify(kept, "\t") + "\n")
		fw.close()
		print("[Audit] roads of the baseline renewed in ", BASELINE)
		quit(0)
		return
	if args.has("--write"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASELINE.get_base_dir()))
		var f := FileAccess.open(BASELINE, FileAccess.WRITE)
		f.store_string(JSON.stringify(snap, "\t") + "\n")
		f.close()
		print("[Audit] baseline written to ", BASELINE)
		quit(0)
		return
	var base = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	if not base is Dictionary:
		_fail("no baseline at %s (run with -- --write)" % BASELINE)
		quit(1)
		return
	_compare(snap, base)
	print("[Test] %s" % ("FAILED: %d" % _fails if _fails > 0 else "all map audit checks passed"))
	quit(1 if _fails > 0 else 0)


## Trees, palms and cacti that GroundPlacer puts on the whole map.
func _ground_trees(cfg: CityConfig, data: CityData) -> int:
	var lib := ModelLibrary.new()
	lib.begin(cfg)
	while lib.load_next(40) < 1.0:
		pass
	NatureMeshes.build_all(lib)
	var wanted := {}
	for id in lib.ids(ModelCatalog.Cat.TREE):
		wanted[id] = true
	for n: String in ["tree", "palm", "cactus"]:
		if lib.named_id(n) >= 0:
			wanted[lib.named_id(n)] = true
	var total := 0
	var side := data.chunks_per_side()
	for cy in side:
		for cx in side:
			var batch := InstanceBatch.new()
			GroundPlacer.place_cells(data, lib, data.chunk_rect(cx, cy), batch)
			for id in batch.transforms:
				if wanted.has(id):
					total += batch.transforms[id].size() / 12
	return total


func _compare(snap: Dictionary, base: Dictionary) -> void:
	# Kept: the buildings.
	var kinds: Dictionary = snap["kinds"]
	var base_kinds: Dictionary = base["kinds"]
	for k in base_kinds:
		var now := int(kinds.get(k, 0))
		var was := int(base_kinds[k])
		if now == was:
			continue
		print("[Audit]   %-18s %4d buildings (baseline %d)" % [k, now, was])
		if absi(now - was) > maxi(KIND_SLACK, int(was * KIND_SLACK_SHARE)) or (now == 0) != (was == 0):
			_fail("%s: %d buildings, the baseline has %d" % [k, now, was])
	for k in kinds:
		if not base_kinds.has(k):
			_fail("%s: %d buildings, none in the baseline" % [k, kinds[k]])
	print("[Audit] %d kinds of buildings checked" % base_kinds.size())
	# Kept: the trees (the forest is random: a few percent either way is the same forest).
	var trees := int(snap["ground_trees"])
	var base_trees := int(base["ground_trees"])
	print("[Audit] %d trees on the ground (baseline %d)" % [trees, base_trees])
	if absf(float(trees - base_trees)) > float(base_trees) * 0.05:
		_fail("%d trees on the ground, the baseline has %d" % [trees, base_trees])
	# Kept: which zones touch.
	var adj: Dictionary = snap["zone_adjacency"]
	var base_adj: Dictionary = base["zone_adjacency"]
	for pair in base_adj:
		if int(base_adj[pair]) >= 8 and not adj.has(pair):
			_fail("zones %s do not touch any more" % pair)
	for pair in adj:
		if int(adj[pair]) >= 8 and not base_adj.has(pair):
			_fail("zones %s touch now, they did not in the baseline" % pair)
	print("[Audit] %d zone contacts checked" % base_adj.size())
	# Kept: the fog island.
	if snap["fog_hash"] != base["fog_hash"]:
		_fail("the fog island changed")
	# Roads.
	var roads: Dictionary = snap["roads"]
	var base_roads: Dictionary = base["roads"]
	print("[Audit] roads: %d cells in %d group(s)" % [roads["cells"], roads["components"]])
	for p in PROBLEMS:
		var now := int(roads[p])
		var was := int(base_roads.get(p, 0))
		print("[Audit]   %-22s %5d   (baseline %d)" % [p, now, was])
		if now > was:
			_fail("roads: %s went from %d to %d" % [p, was, now])
		elif STRICT and now > 0:
			_fail("roads: %s is %d, must be 0" % [p, now])
	print("[Audit]   %-22s %5d   (kept: dead ends of 3 cells or more)" % ["cul_de_sacs", int(roads.get("cul_de_sacs", 0))])
	for h in roads["highways"]:
		print("[Audit]   highway row %d, x %d..%d: west end %s, east end %s" % [
				h["row"], h["from"], h["to"], h["west"], h["east"]])
		for side: String in ["west", "east"]:
			var how: String = h[side]
			if how != "open" and not (STRICT and how == "street"):
				continue
			if STRICT:
				_fail("the highway of row %d has no proper junction at its %s end (%s)" % [h["row"], side, how])
			else:
				print("[Audit]     -> to fix: %s end is '%s'" % [side, how])


func _details(data: CityData) -> void:
	print("[Audit] road groups: ", MapAudit.road_components(data).slice(0, 12))
	print("[Audit] roads on water: ", MapAudit.roads_on_water(data).slice(0, 40))
	print("[Audit] stubs: ", MapAudit.stubs(data).slice(0, 60))
	print("[Audit] dead ends: ", MapAudit.dead_ends(data).slice(0, 200))
	print("[Audit] diagonal gaps: ", MapAudit.diagonal_gaps(data).slice(0, 60))
	print("[Audit] fat roads: ", MapAudit.fat_roads(data).slice(0, 60))
	var names := CityTypes.Kind.keys()
	for title: String in ["under_buildings", "overlapping", "no_road"]:
		var ids := MapAudit.buildings_on_roads(data) if title == "under_buildings" \
				else (MapAudit.overlapping_buildings(data) if title == "overlapping" else MapAudit.lots_without_road(data))
		var lines := PackedStringArray()
		for b in ids.slice(0, 40):
			lines.append("B-%05d %s %s" % [b, names[data.b_kind[b]], data.building_rect(b)])
		print("[Audit] %s: %s" % [title, ", ".join(lines)])


func _fail(msg: String) -> void:
	_fails += 1
	push_error("[Test] " + msg)
	print("[Test] FAIL: ", msg)
