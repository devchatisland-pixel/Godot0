# Map rebuild plan

Goal: a main island of twice the area (each side x 1.41) with the same buildings and trees,
the same structure between the zones, and roads built as a real network: proper junctions,
no texture bugs, highways that start and end at a big perpendicular road (or a bridge).
The fog island and the development island are not touched. Building numbers change.

## Target structure

1. `MapLayout` (data only): every island and zone as a shape in map units, with one `scale`,
   and which zones touch. No planner holds cell coordinates any more.
2. One pass on one grid: land, zones, roads, blocks, lots, services, props (the
   core-then-embed stage goes away).
3. `RoadNetwork`: one pass after the planners that turns what they drew into a clean network
   and enforces its rules (no roads side by side, no corner contacts, no stubs, no loose
   groups, highways closed by a bridge or by an avenue that crosses their whole width).
   Phase 3 moves the planners to one grid; the rules stay in this one place.
4. `BuildingBudget`: buildings per kind and trees of the baseline; lots are filled up to the
   quota, so a bigger island means more room, not more buildings.
5. Anchors: props, vehicles and hand edits name a place ("the stadium"), not a cell.

## Guarantees (tests/test_map_audit.gd, MapAudit)

Kept, against `tests/baseline/map_snapshot.json`: buildings per kind, trees on the ground
(5 %), the zones that touch, the hash of the fog island.
Road problems, all at zero since phase 2 (`STRICT` in the test): cells off the main network,
roads on water, roads under buildings, overlapping buildings, street lots without a road
(the compound of the nuclear plant has none on purpose), stubs (dead ends shorter than 3
cells), diagonal gaps, fat roads (two roads side by side), highway ends that are not a
junction with an avenue or a bridge. Dead ends of 3 cells or more are cul-de-sacs: kept and
counted (14).

Baseline of the old map: 4 road groups (544 cells off the main one: the urban island is not
joined by road cells), 138 dead ends, 57 fat road squares, 3 diagonal gaps, 18 street lots
without a road, 3 highway ends that just stop.

## Phases (one pull request each)

0. Audit, baseline and this plan. (done)
1. `MapLayout` at scale 1: the same map as before, coordinates in one place. (done; `test_map_audit.gd -- --same` proves it)
2. `RoadNetwork` at scale 1: the road problems go to zero. (done; building counts drift by a
   few until the budgets of phase 3)
3. Scale 1.41 with the budgets.
4. Anchors for props, vehicles and hand edits.
5. Tuning, polygon heatmap and streaming checks on the bigger map.
