extends SceneTree
## Checks that every hand edit of ManualEdits is applied (none skipped), in particular the
## 21 buildings deleted by hand: each one must be Kind.EMPTY after the generation.
## Run: godot --headless --script res://tests/test_deleted_buildings.gd

var _fails := 0


func _init() -> void:
	var cfg := CityConfig.create()
	var data := CityGenerator.new(cfg).generate()
	var applied := ManualEdits.resolved.size()
	print("[Test] %d of %d hand edits resolved" % [applied, ManualEdits.EDITS.size()])
	var deleted := 0
	for n in ManualEdits.EDITS.size():
		var e: Dictionary = ManualEdits.EDITS[n]
		if not ManualEdits.resolved.has(n):
			_fail("edit %d (%s at %s) was skipped" % [n, e["kind"], e["at"]])
			continue
		if e.get("delete", false):
			var id: int = ManualEdits.resolved[n]
			if data.b_kind[id] != CityTypes.Kind.EMPTY:
				_fail("B-%05d (%s) is still there" % [id, e["kind"]])
			deleted += 1
	print("[Test] %d deletions checked" % deleted)
	print("[Test] %s" % ("FAILED: %d" % _fails if _fails > 0 else "all hand edits applied"))
	quit(1 if _fails > 0 else 0)


func _fail(msg: String) -> void:
	_fails += 1
	push_error("[Test] " + msg)
	print("[Test] FAIL: ", msg)
