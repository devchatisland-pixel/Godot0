class_name ShopSites
extends RefCounted
## Where the shops of the catalog (res://shops) stand: one of each on the development island
## (Zone.DEV), in two rows along its street (DevIsland): the shops north of it, fronts south,
## the modular buildings south of it, fronts north. Pure data in, a list of
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
	"shop-business": 1.3,
}
## Empty cells between two neighbours in the row.
const GAP := 1.5
## Empty cells between the street and the fronts of a row.
const FRONT_GAP := 0.4
## Rows of cells between the street and the line a row is measured on.
const ROW_SAMPLE := 2
## Catalog ids of the modular buildings (tools/build_modular_buildings.py): the south row.
const MODULAR_PREFIX := "modular-"


## `shops`: [{"id", "width", "depth", "height"} in metres].
static func plan(data: CityData, shops: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# The street of the island (DevIsland): the row of DEV land with the most road cells.
	var street := -1
	var best := 0
	for y in data.size:
		var n := 0
		for x in data.size:
			var i := data.idx(x, y)
			if data.zone[i] == Zone.DEV and data.road[i] != 0:
				n += 1
		if n > best:
			best = n
			street = y
	if street < 0:
		push_warning("[Shops] no street on the development island")
		return out
	# The port road leaves the street southwards: the south row stops before it.
	var port_x := data.size
	for x in data.size:
		var i := data.idx(x, street + DevIsland.STREET_LANES)
		if data.zone[i] == Zone.DEV and data.road[i] != 0:
			port_x = mini(port_x, x)

	# Shipping containers (ids "container-NN") are left out: only the shops stand on the island.
	var north := []
	var south := []
	for s in shops:
		var id := String(s["id"])
		if id.begins_with("container-"):
			continue
		(south if id.begins_with(MODULAR_PREFIX) else north).append(s)
	# North of the street the shops, their fronts south; south of it the modular buildings,
	# their fronts north. Each row is centred on the dry land of a line ROW_SAMPLE cells off
	# the street.
	_row(data, north, street - ROW_SAMPLE, data.size, float(street) - FRONT_GAP, PI, -1.0, out)
	_row(data, south, street + DevIsland.STREET_LANES + ROW_SAMPLE, port_x - 1,
			float(street + DevIsland.STREET_LANES) + FRONT_GAP, 0.0, 1.0, out)
	return out


## One row: `front` is the line of the fronts, `back` the side (-1 north, +1 south) the
## buildings stand on, `limit` the first x the row may not reach.
static func _row(data: CityData, order: Array, line: int, limit: int, front: float, yaw: float,
		back: float, out: Array[Dictionary]) -> void:
	var x0 := data.size
	var x1 := -1
	for x in mini(limit, data.size):
		var i := data.idx(x, line)
		if data.zone[i] == Zone.DEV and data.terrain[i] == CityTypes.Terrain.LAND and data.road[i] == 0:
			x0 = mini(x0, x)
			x1 = maxi(x1, x)
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
	for s in order:
		var k := CELLS_PER_METRE * float(SCALE.get(s["id"], 1.0))
		var w := float(s["width"]) * k
		var dep := float(s["depth"]) * k
		out.append({
			"id": s["id"], "at": Vector2(x + w * 0.5, front + back * dep * 0.5),
			"yaw": yaw, "height": float(s["height"]), "scale": k,
		})
		x += w + GAP
