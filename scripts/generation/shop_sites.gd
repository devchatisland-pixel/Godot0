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
	"shop-coffee-a": 0.5, "shop-general-mini": 1.85,
	"shop-general-brick": 2.0, "shop-flower-a": 1.15, "shop-general-orange-a": 1.15,
	"shop-business": 1.3, "shop-steel-glass": 1.6,
}
## The shops of the development island are all drawn the same height (HEIGHT cells), each scaled evenly
## so that it keeps its own proportions (nothing is stretched). Their widths therefore differ; every
## emplacement is as wide as the widest shop of the island plus SLOT_MARGIN, so a shop chosen later by a
## player always fits, and a narrower one stands in the middle of its slot.
const HEIGHT := 1.3
const SLOT_MARGIN := 0.6
## The tall and narrow look of the shops of the city and the fog island (see scale_of, stretch_of): the longer
## footprint side is FOOTPRINT cells, and a lower model is stretched upwards (at most MAX_STRETCH).
const FOOTPRINT := 1.2
const TALL_RATIO := 1.35
const MAX_STRETCH := 2.6
## Empty cells between two neighbours in the row (the slots already hold the margins).
const GAP := 0.0
## Empty cells between the street and the fronts of a row.
const FRONT_GAP := 0.4
## Rows of cells between the street and the line a row is measured on.
const ROW_SAMPLE := 2
## Catalog ids of the modular buildings (tools/build_modular_buildings.py): the south row.
const MODULAR_PREFIX := "modular-"
## Shops taken off the island, on request (S-01, the brick shop with a balcony).
## Suffix of the copies without lights (MapShops): they stand in the south row.
const UNLIT_SUFFIX := "-unlit"
const REMOVED := ["shop-general-brick"]


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
	var removed_base := func(id: String) -> bool:
		return REMOVED.has(id.trim_suffix(UNLIT_SUFFIX))
	for s in shops:
		var id := String(s["id"])
		if id.begins_with("container-") or removed_base.call(id):
			continue
		# The modular buildings (S-16 .. S-21) are gone from the island, on request.
		if id.begins_with(MODULAR_PREFIX):
			continue
		if id.ends_with(UNLIT_SUFFIX):
			south.append(s)
		else:
			north.append(s)
	# North of the street the shops, their fronts south; south of it the modular buildings,
	# their fronts north. Each row is centred on the dry land of a line ROW_SAMPLE cells off
	# the street.
	var slot := 0.0
	for s in north + south:
		slot = maxf(slot, float(s["width"]) * island_scale(s))
	slot += SLOT_MARGIN
	_row(data, north, street - ROW_SAMPLE, data.size, float(street) - FRONT_GAP, PI, -1.0, slot, out)
	# All the shops face south: the south row has its back to the street.
	_row(data, south, street + DevIsland.STREET_LANES + ROW_SAMPLE, port_x - 1,
			float(street + DevIsland.STREET_LANES) + FRONT_GAP, PI, 1.0, slot, out)
	return out


## One row: `front` is the line of the fronts, `back` the side (-1 north, +1 south) the
## buildings stand on, `limit` the first x the row may not reach.
static func _row(data: CityData, order: Array, line: int, limit: int, front: float, yaw: float,
		back: float, slot: float, out: Array[Dictionary]) -> void:
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
	var total := GAP * float(order.size() - 1) + slot * float(order.size())
	var avail := float(x1 - x0 + 1)
	if total > avail:
		push_warning("[Shops] the row (%.1f cells) is wider than the island (%.1f)" % [total, avail])
	var x := float(x0) + avail * 0.5 - total * 0.5
	for s in order:
		var k := island_scale(s)
		var w := float(s["width"]) * k
		var dep := float(s["depth"]) * k
		# Centred in the slot along the street; the back on the street side for the south row
		# (the front side for the north row, as before): the slot is as deep as it is wide.
		var z := front + back * dep * 0.5
		out.append({
			"id": s["id"], "at": Vector2(x + slot * 0.5, z),
			"yaw": yaw, "height": float(s["height"]), "scale": k, "stretch": 1.0,
		})
		x += slot + GAP


## Cells per metre of shop `s` ({"height" in metres}) on the development island: all the same height.
static func island_scale(s: Dictionary) -> float:
	return HEIGHT / maxf(float(s["height"]), 0.01)


## Extra height factor that makes a shop of w x d x h metres tall (see TALL_RATIO).
static func stretch_for(w: float, d: float, h: float) -> float:
	var k := FOOTPRINT / maxf(w, d)
	return clampf(FOOTPRINT * TALL_RATIO / maxf(h * k, 0.01), 1.0, MAX_STRETCH)


## Cells per metre / height factor of catalog shop `id` wherever it stands (the city, the fog
## island, the development island): one rule for every shop of the map.
static func scale_of(id: String) -> float:
	var e := MapShops.entry(id)
	if e.is_empty():
		return CELLS_PER_METRE
	return FOOTPRINT / maxf(float(e["width"]), float(e["depth"]))


static func stretch_of(id: String) -> float:
	var e := MapShops.entry(id)
	if e.is_empty():
		return 1.0
	return stretch_for(float(e["width"]), float(e["depth"]), float(e["height"]))
