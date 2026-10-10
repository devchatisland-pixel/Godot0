class_name ShopSites
extends RefCounted
## Where the shops of the catalog (res://shops) stand: one of each, in a row on the
## development island (Zone.DEV), their fronts towards the south. Pure data in, a list of
## placements out, so it can be checked headless (tests/test_shops.gd).
## Each placement: {"id": catalog id, "at": Vector2 (cells, x/z), "yaw": radians, "height": metres,
## "scale": cells per metre of this shop}.
## The shop models face -Z; MapShops turns them with `yaw`.

const Zone := CityTypes.Zone

## Cells per metre: twice the scale of the vehicles (0.17), so that the shops are easy to see.
const CELLS_PER_METRE := 0.34
## Hand-made size factors per catalog id (on top of CELLS_PER_METRE).
const SCALE := {
	"shop-candy-b": 2.0, "shop-candy-a": 1.3, "shop-townhouse-gabled": 2.0,
	"shop-general-generic": 2.0, "shop-coffee-a": 0.5, "shop-general-mini": 1.15,
	"shop-general-brick": 1.15, "shop-flower-a": 1.15, "shop-general-orange-a": 1.15,
}
## Empty cells between two neighbours in the row.
const GAP := 1.5
## Distance of the front line of the row south of the middle of the island (cells).
const FRONT_OFFSET := 1.5


## `shops`: [{"id", "width", "depth", "height"} in metres].
static func plan(data: CityData, shops: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lo := Vector2i(data.size, data.size)
	var hi := Vector2i(-1, -1)
	for y in data.size:
		for x in data.size:
			var i := data.idx(x, y)
			if data.zone[i] == Zone.DEV and data.terrain[i] == CityTypes.Terrain.LAND:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0:
		push_warning("[Shops] no development island on this map")
		return out
	# The row runs along the middle line of the island, over the land cells of that line.
	var yc := (lo.y + hi.y) / 2
	var x0 := data.size
	var x1 := -1
	for x in range(lo.x, hi.x + 1):
		var i := data.idx(x, yc)
		if data.zone[i] == Zone.DEV and data.terrain[i] == CityTypes.Terrain.LAND:
			x0 = mini(x0, x)
			x1 = maxi(x1, x)

	# Shipping containers (ids "container-NN") stand in rows south of the shops.
	var containers := []
	var order := []
	for s in shops:
		if String(s["id"]).begins_with("container-"):
			containers.append(s)
		else:
			order.append(s)
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(a["height"], b["height"]):
			return a["height"] < b["height"]
		return String(a["id"]) < String(b["id"]))
	var total := GAP * float(order.size() - 1)
	for s in order:
		total += float(s["width"]) * CELLS_PER_METRE * float(SCALE.get(s["id"], 1.0))
	var avail := float(x1 - x0 + 1)
	if total > avail:
		push_warning("[Shops] the row (%.1f cells) is wider than the island (%.1f)" % [total, avail])
	var x := float(x0) + avail * 0.5 - total * 0.5
	var front := float(yc) + FRONT_OFFSET
	for s in order:
		var k := CELLS_PER_METRE * float(SCALE.get(s["id"], 1.0))
		var w := float(s["width"]) * k
		var dep := float(s["depth"]) * k
		out.append({
			"id": s["id"], "at": Vector2(x + w * 0.5, front - dep * 0.5),
			"yaw": PI, "height": float(s["height"]), "scale": k,
		})
		x += w + GAP

	containers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	var cx := float(x0) + 1.5
	var row_front := front + 1.2
	var row_dep := 0.0
	for s in containers:
		var k := CELLS_PER_METRE * float(SCALE.get(s["id"], 1.0))
		var w := float(s["width"]) * k
		var dep := float(s["depth"]) * k
		if cx + w > float(x0) + avail - 1.5 and cx > float(x0) + 1.5:
			cx = float(x0) + 1.5
			row_front += row_dep + 0.8
			row_dep = 0.0
		row_dep = maxf(row_dep, dep)
		out.append({
			"id": s["id"], "at": Vector2(cx + w * 0.5, row_front + dep * 0.5),
			"yaw": PI, "height": float(s["height"]), "scale": k,
		})
		cx += w + 0.6
	return out
