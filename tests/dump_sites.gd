extends SceneTree
## Prints the hotels and the buildings of the industrial zone and port (kind, cell, size, seed,
## model): godot --headless --script res://tests/dump_sites.gd

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone


func _init() -> void:
	var data := CityGenerator.new(CityConfig.create()).generate()
	var yards := 0
	var yard_box := Rect2i()
	for b in data.building_count():
		var k: int = data.b_kind[b]
		var r := data.building_rect(b)
		var z: int = data.zone_at(r.position.x, r.position.y)
		var name: String = Kind.keys()[k]
		if k == Kind.INDUSTRIAL_YARD and z == Zone.INDUSTRIAL:
			yards += 1
			yard_box = r if yard_box.size == Vector2i.ZERO else yard_box.merge(r)
			continue
		if k == Kind.HOTEL or z == Zone.INDUSTRIAL or k == Kind.CRANE or data.b_model.has(b):
			print("[Site] #%d %s zone=%s at=%s size=%s seed=%d facing=%d model=%s" % [b, name, Zone.keys()[z],
					r.position, r.size, data.b_seed[b], data.b_facing[b], data.b_model.get(b, "")])
	print("[Site] industrial yards: %d in %s" % [yards, yard_box])
	# The blockade of the fog island must stand on land, the bridge landing west of it.
	var fog := data.fog
	var at := FogBaseSites.BLOCKADE_AT
	var wet := 0
	for y in range(int(at.y) - 4, int(at.y) + 5):
		for x in range(int(at.x) - 4, int(at.x) + 8):
			if fog.elevation[y * FogIslandShaper.SIZE + x] <= 128:
				wet += 1
	print("[Site] bridge lands at fog x %.1f; blockade at %s, %d cells of its box in the sea" % [
			fog.bridge_land_x - fog.origin.x, at, wet])
	quit(0)
