extends SceneTree
## Loads every model of the catalog and reports the ones that fail (headless):
##   & .\tools\run_test.ps1 res://tests/check_model_slots.gd


func _init() -> void:
	var cat := ModelCatalog.new()
	cat.scan("res://FREEMODELS")
	var lib := ModelLibrary.new()
	var bad := 0
	for e in cat.entries:
		var m: Mesh = lib._load_pack_mesh(e["path"], e["node"]) if e.has("node") else lib._load_mesh(e["path"])
		if m == null:
			bad += 1
			print("FAILED %s %s" % [e["path"], e.get("node", "")])
	lib._close_pack()
	print("%d slots, %d failed" % [cat.entries.size(), bad])
	quit()
