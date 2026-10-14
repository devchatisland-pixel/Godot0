# Chat City (Godot 4.6)

**Chat City** is a procedural city on its own island, shown in an isometric view inspired by Voxurbis.
There is no gameplay: you can only **navigate** and **zoom**.
It runs on desktop, mobile and in the browser (GL Compatibility renderer).

*(Screenshots: run the game with `-- --capture <folder>`, see Tests and tools.)*

## Controls

The game starts on the centre of the city; zoom out to see the islands.

| Action | Mouse / keyboard | Touch / trackpad |
| --- | --- | --- |
| Navigate | drag with any mouse button, `WASD` / arrows | one finger drag, two-finger scroll |
| Zoom | mouse wheel (zooms at the cursor), `Q` / `E`, `-` / `+` | pinch |

## Test it with Docker

Requirements: Docker Desktop (Windows / macOS) or Docker Engine (Linux).
The images use **Godot 4.6.3**. Set `GODOT_VERSION` in `docker-compose.yml` to use another version.

### Play it in your browser

```
docker compose up --build web
```

Then open **http://localhost:8080**. If that port is already used (an older build still running), pick another one: `WEB_PORT=8081 docker compose up --build web` (PowerShell: `$env:WEB_PORT=8081; docker compose up --build web`). This is the fast multi-threaded build, rendered by your GPU through WebGL 2.

* **First build:** it downloads Godot (~60 MB) and its export templates (~1.25 GB). Docker caches both, so later builds only re-export the project (about 1 minute).
* **After you change the code:** run the same command again.
* **Stop:** `Ctrl+C`, or `docker compose down`.

### Run the automated checks

```
docker compose run --build --rm tests
```

This runs the generation test, the urban island test (airport, nuclear plant, BT tower islet, watchtowers; it prints a text map of the island), the chunk benchmark and a top-down map. It also takes 14 screenshots of key places (downtown, urban island, port, McDonald's, prison, mountain, airport, nuclear plant, BT tower at night, a watchtower, a Vegas club) without needing a GPU.
Everything is written to `./docker-out/` (`map.png`, `shot_0.png` ... `shot_13.png`). The screenshots use software rendering, so this step takes a few minutes.

### Files

```
docker-compose.yml     services "web" (port 8080) and "tests"
docker/Dockerfile      stages: godot -> project (import) -> tests | templates -> export -> web (nginx)
docker/nginx.conf      adds the COOP/COEP headers needed by the threaded web build
docker/run-tests.sh    what the tests container runs
export_presets.cfg     "Web" (threads) preset
```

## The island

Chat City is a 384×384-cell map: one big **rounded main island**, the **urban island** to the west and the
**fog island** to the east. It is the first map (272 cells) rebuilt 1.41 times longer on every side: the
islands have twice the area, with the same number of buildings of every kind and the same number of
trees, the same zones touching each other, and roads that form one clean network. The city sits in the
west part of the main island; the districts around it are round blobs, not squares. On screen north-west is up. Special buildings are kept far from each other on purpose.

**Drastic changes (`map_overhaul.gd`, and the removal of the code that drew them):** there are **no trees, palms or
fences** any more (cacti stay), the **urban island has no building** (its streets and ground stay), the **fog
island has no building**, and the map holds **12 more hot air balloons** floating at random places over land and
sea and **12 more submarines** at random places of the open sea. The text below still describes the districts as
they were planned: read the urban island, the fog island, the trees and the fences in it with these changes.

**Latest additions (`map_additions.gd`, `fog_base_sites.gd`, `fog_base.gd`):**

* **Fog island**: the "SEASON 2" title is switched off (`FogIsland.SHOW_TITLE`) and the fog is gone (clear sky,
  `FogIsland.SHOW_FOG`), because the island now holds a **military base**: an air base (runway and roads
  drawn with the highway texture, a row of F-14, staff building, radar, the helipad with the helicopter that
  stood on the prison island), a camp (rows of tents, medical tents, barracks, and a vehicle park where
  T-55, BMP-1, BRDM and EE-11 AA stand side by side in blocks of one kind) and the **nuclear power plant** the
  army protects, with air defence (NASAMS) and armoured cars round it. Everything is placed by hand in
  `FogBaseSites` (local cells of the island).
* **Main city**: three low poly churches; downtown is denser (its cleared and low lots are Kenney
  skyscrapers); the poor district has a ghetto look (the three blackthorn towers `tower0`, `tower5`, `tower6`
  and the ten buildings of the "Buildings" pack, each used a few times); one tall tower of Las Vegas carries
  the neon woman sign on its roof.
* **Vehicles** (`vehicle_sites.gd`): a harvester in a wheat field, a red pickup, a forwarder and a tractor
  with its trailer in the farmland, a water tanker next to the construction crane, a fuel tanker next to the
  oil barrels of the port.
* **Urban island** (`urban_skyline.gd`): 30 % longer and wider (`MapLayout.BLOBS`), and rebuilt with nothing
  but the 13 towers of the night skyline pack (`skyline_towers.glb`). Three parallel roads run its whole
  length and meet the road that comes from the metal bridge; the towers stand wall to wall in rows along
  them (each one is stretched over its whole lot), so the only gaps are the roads.
* **Prison**: the cellhouse is the school building model, inside a perimeter wall with razor wire, an inner
  fence and six guard towers (`CivicMeshes.prison`, `BuildingExtras`).
* **East bridge**: the Golden Gate model in one piece, its deck level with the highway (`FogIsland`).
* **Satellite dishes** are the low poly radar dish model.
* **More at sea**: 8 simple boats and 4 cargo ships at random places (`MapOverhaul`), 6 aircraft carriers
  round the fog island (`FogBase`).
* **Port**: three oil silos side by side next to the container yards, the fuel tanker beside them.
* **Secret base**: a helicopter parked on a helipad near the bunker.
* **Sky and beaches**: three F-111 fly in a V over the sea far north of the island; deck chairs and beach
  balls stand on six lonely beaches, away from the lighthouses and from everything else (`scenic_props.gd`).

**Sixteenth wave (`map_retouch.gd`, `map_fences.gd`, `tools/build_wave16_models.py`):**

* **Urban island**: four towers carry a sign on their east wall, a little narrower than the wall: the Windows
  logo, the white neon joystick, the woman in a martini glass and the "BAR" board (`MapRetouch.TOWER_SIGNS`,
  mount "face" of `BuildingExtras.SIGNS`). They glow at night like the other neon signs.
* **City**: ten more billboards and two basketball courts on bare ground beside a street; every hotel is the
  orange low poly hotel; the school bus is parked in front of the main school; a Burger King and two Las Vegas
  clubs are gone; the neon tower of Las Vegas faces east.
* **Prison**: a wire fence all round it, on dry ground only, with floodlights and bleachers in its yard.
* **Secret base**: 1.5 times bigger (its jets too), inside a wire fence. Ground helipads are the painted H of the
  hospital roof, and helicopters are a third bigger.
* **Fog island**: the jets and four of the carriers are turned about, the army and medical tents are mixed, half
  of the army vehicles are gone, the plant has no air defence any more and its barracks has the size of the
  others; jeeps stand by the tents, grey Humvees drive on the roads, a fire truck and a tow truck wait on the
  apron. A sand Humvee stands at the west end of the Golden Gate.
* **Farmland**: one harvester moved to another wheat field, the forwarder and a tractor turned.
* **Development island**: one more shop, the blue townhouse.

**Eighteenth wave (`port_rework.gd`, the last step of the generation; models from `tools/build_wave16_models.py`):**

* **Hotels**: each of the four hotels has its own model (`PortRework.HOTEL_MODELS`): the orange hotel, the small
  purple hotel, the five-star hotel with awnings and the glass twin tower with a rooftop pool. When there are
  fewer hotels than models, hotels are added on bare plots beside a street in the city.
* **Industrial zone and port**: the old factories (concrete factory, brick works, ruin, garage, Kenney
  factories and sheds) and the container yards far from the crane are gone (the 32 yards nearest the crane
  stay, with the oil silos). Each of the 37 models of `PortRework.PORT_MODELS` stands on its own lot, the big
  ones nearest the centre of the zone and beside a street: the industrial buildings set (halls, power plant,
  warehouses, sheds, a portal crane, a water tower, a radio mast and tanks), the storage tanks, three oil tanks
  and the brick factory.
* **Sea**: the offshore oil rig stands off the port, with open sea all round it.
* `tests/dump_sites.gd` prints the hotels and the buildings of the industrial zone with their cells and models.

**Nineteenth wave (`map_retouch.gd`, models from `tools/build_wave16_models.py`):**

* **Urban island**: Taiwan style signboards on the row of towers, on the same east side as the neon signs. A
  tower whose east wall is free carries its sign on that wall: the "Banasonic", McDonald's and Japanese
  Coca-Cola boards stick out of the wall from their brackets (mount "blade"), and an LED ticker band wraps the
  free south-east corner of a tower (mount "corner"). A tower with a lower one in front of it carries its board
  on the roof instead, seen over the other one: the Coca-Cola billboard and the LED safety board (mount "roof",
  `deep`). The neon bull moved from its wall to the roof of its tower. At night only the boards light up, in
  their own colours; the steel frames stay dark (`NightWindows.LOGO_PACKS`, `LOGO_DARK`).

| Where (on screen) | District | What you find |
| --- | --- | --- |
| centre-top | **Downtown** | the only skyscraper district: Kenney towers outside, photo towers in the middle, and 7 New York landmarks (Empire State, Chrysler, One WTC, Woolworth, New York Times, MetLife, Flatiron), drawn much taller than the Kenney towers |
| just behind downtown (north) | **Poor district** | a small district of grey panel towers and slabs, garages and corner shops, and the one big urban ghetto block |
| left of downtown | **Little Las Vegas** | casino palaces, neon towers, resorts, small bars, wedding chapels and clubs of every size, the cinema and the shopping center; the neon signs are all on the roofs, none at street level |
| west coast | **West desert** | reaches the sea without a beach: the secret base ("area 51": airbase with runway, hangar, tower and jets, bunker, radio station), mesas, ranches and oil pumps |
| south-west coast, next to the desert and Vegas | **Industrial zone and port** | 37 different industrial buildings and tanks (one of each model, eighteenth wave), container yards round the crane on the quay (no beach), the oil rig at sea |
| centre | **Central park** | a large wood with a lake, a fountain and two crossing paths, ring roads all around |
| north-east | **Mountain forest** | a forest with three snow-capped mountains standing together far from the city (the one of the core is the biggest), and a wide sand beach on its coast; the forest thins to meadow at its edge |
| below the park | **Civic center** | the main city hall and the police headquarters (each on its own plot), the bank, fire station, post office |
| right of the park | **United Nations** | the U.N. tower (half the size it was) with a small emblem, on its own plot where everyone sees it |
| left of the park | **Shopping streets** | the main hospital, the shopping center, hotels, New York street buildings, mini hotels; three pharmacies and many more shops, all facing the camera |
| right / bottom | **Residential** | houses with gardens (Kenney, cartoon), the main school with its sports ground, the big church (far from the U.N.), the cemetery, gas stations |
| south | **Red district** | white and red low-rise town, bigger than before, mixed with colourful houses; the drive-in cinema, a crane, McDonald's and Burger King, the big ferris wheel at the beach, and one of each food stall (ice cream kiosks, and half-size food trucks) |
| left | **Sports corner** | the big stadium (own plot, floodlit at night) |
| south-east | **Farmland** | the one farming district: crop fields (wheat, corn, plowed soil, green rows) with farms and a country road |
| everywhere | **Hotels** | four hotels, each with its own model (eighteenth wave) |
| far west, across the metal bridge | **Urban island** | the third island, long from north to south, planned end to end (`urban_island_planner.gd`): the **airport** at the south end (the left end on screen) with nothing built in front of it, the **tower city** in the middle (towers of three packs, all showing their front to the camera, a few futuristic ones in the centre), and the **nuclear plant** at the north end (the right end) with its cooling towers and hall beside it, a small yard and only low industry in front. No trees |
| just south of the urban island | **BT tower islet** | a tiny industrial islet with the BT tower in its middle and three satellite dishes round it |
| the two forests | **Watchtowers** | two simplified wooden lookouts, one in the north-east forest and one in the forest of the old city |
| far north-west, at sea | **Prison island** | a long rocky island far from the coast: a very big cellhouse (no sign), stone blocks, a villa, a workshop, lighthouses |
| east, across the Golden Gate | **The fog island** | a second island under a clear sky, with the military base and its nuclear plant (it was hidden in a thick bank of fog). A three-lane highway leads to the Golden Gate (no roadblocks, the deck is level with the road; the fog stays clear only over the bridge itself and covers the island from its coast). The "SEASON 2" title is switched off |
| coast | **Beaches, rocky shores, islets** | six lighthouses, each on a real coast cell (four round the main island, two on the prison island), and palm islets; on the smallest one a pirate grave |

How it is built (`scripts/generation/`, one seed in `CityConfig.seed`, the same map on every device):

**0. The layout** (`map_layout.gd`): every island, round district and single place of the big map, in
cells of the first map and scaled by `CityConfig.map_scale`. The planners ask for them by name.

**1. The core city** (on a 180×180 grid):

1. **`island_shaper.gd`**: an elliptical island with a little noise, sandy and rocky shores.
2. **`district_planner.gd`**: the district layout (anchors, hints and the park, mountain forest and big-building plots, in island units).
3. **`road_planner.gd`**: recursive splitting (BSP) into blocks. The borders of the park, the forest and the plots of the big buildings are cut first, so they become ring roads. The first splits are avenues with street lights.
4. **`lot_planner.gd`**: blocks cut into lots, every building facing its street.
5. **`service_planner.gd`**: the big buildings fill their plots; every main public building once, never two close together; then the small services of each district (4 hotels, 3 pharmacies...).
6. **`landmark_planner.gd`**: the park lake and paths, the first mountain, the road to the Golden Gate, the lighthouses.

**2. Everything around it** (`core_embed.gd`, `extension_island.gd`, `extension_planner.gd`):

7. **`core_embed.gd`** copies the finished core city into the 384×384 map.
8. **`extension_island.gd`** raises the rounded main island around it (the core keeps its own streets, shores and forests), the urban island, palm islets and the prison island.
9. **`extension_planner.gd`** works only on free land, with round blobs, and calls its helpers: `extension_roads.gd` (the two highways, east to the Golden Gate and west to the metal bridge, and the shortest-road links), `extension_spots.gd` (free plots and spots), `urban_island_planner.gd` (the urban island, with its own random numbers), `extension_features.gd` (the desert with the base, the industrial zone and port, the farmland, two more mountains, the watchtowers, the prison compound, the lighthouses). The poor and red districts get BSP streets and lots with round shapes. Everything is linked to the old city by the shortest road.
10. **`fog_island_shaper.gd`**: the island in the fog, placed right after the end of the east highway.

**3. The rules of the finished map**:

11. **`manual_edits.gd`**: hand-made corrections, each one named by a kind of building near a place (no cell, no building number).
12. **`road_network.gd`**: makes one clean network of the roads the planners drew: no two roads side by side, no corner contacts, no stubs, no loose groups; the highways end at a bridge or at an avenue that crosses their three lanes.
13. **`building_budget.gd`**: how many buildings of each kind the map holds, whatever its size. The surplus is cleared (bare ground), the few missing ones are added.
14. **`map_audit.gd`** measures all this; `tests/test_map_audit.gd` checks it against `tests/baseline/map_snapshot.json` (see `docs/map_rebuild_plan.md`).

Which family of models a building uses (Kenney, photo towers, New York, the quarter...) is decided per district in `scripts/world/model_pools.gd`.

To move a district or change its size, edit `ANCHORS`, `PARK_AREA`, `FOREST_AREA`, `PLOTS` or `HINTS` in `district_planner.gd` (core city), or the blobs at the top of `extension_planner.gd` and `extension_features.gd`, and `MAIN` / `URBAN` / `URBAN_NORTH` / `TOWER_ISLET` / `PRISON` in `extension_island.gd` (everything around). The plots of the airport and the nuclear plant are at the top of `urban_island_planner.gd`. The size of the fog island is `FogIslandShaper.SIZE`.

### The fog island

East of Chat City, a metal bridge (the same model as the west one) leaves the east coast and disappears into the fog (`scripts/world/fog_island.gd`).
The island itself lies next to the city map and costs very little: it is not streamed, it has no streets and it is drawn with a few MultiMeshes.
The fog is made of pictures, not 3D volumes:

* four sheets of drifting cloud texture at different heights (`shaders/fog_layer.gdshader`), whose holes open and close over the buildings;
* about 50 big painted billows and two smoke plumes on camera-facing quads (`shaders/fog_puff.gdshader`);
* the "SEASON 2" title, always on top (switched off: `FogIsland.SHOW_TITLE`).

The textures (`textures/fog_noise.png`, `fog_puffs.png`, `season2.png`) are drawn by `tools/make_fog_textures.py` from fractal noise.
At night the fog turns dark blue-grey.

**Nineteenth wave (`lighthouse_island.gd`, the last step of the generation; `FogBaseSites`, `MapFences`; models from
`tools/build_wave16_models.py`):**

* **Golden Gate blockade (fog island)**: the road leaves the bridge through a roadblock like the one of the east end
  (three barriers and cones across the lanes, `FogBaseSites.BLOCKADE_AT`), with the vehicles that guarded the old
  checkpoint behind it, noses to the bridge: the two T-55 and the two BRDM, and the grey Humvee parked beside the road.
* **Jail of the prison island** (`PrisonCompound`): the military post of the pack (`checkpoint.glb`: walls, two gates, guard
  posts, two watchtowers, the garage) is the wall of the prison, 1.5 to 1.9 times its size, round the cellhouse in its
  north yard, with a water tower in the south yard. The prison island is bigger (radii 20 x 13.5) and the wire fence is gone.
* **Development island**: the brick shop S-01 (`shop-general-brick`) is gone (`ShopSites.REMOVED`).
* The day and night cycle lasts one minute (`CityConfig.day_cycle_seconds`).
* **Red district**: every building that faced east faces west (`MapRetouch.RED_DISTRICT_KEEP` lists what is left alone).
* **Secret base**: a helicopter parked on a helipad near the bunker.
* **Sky and beaches**: three F-111 fly in a V over the sea far north of the island; deck chairs and beach
  balls stand on six lonely beaches, away from the lighthouses and from everything else (`scenic_props.gd`).

**Sixteenth wave (`map_retouch.gd`, `map_fences.gd`, `tools/build_wave16_models.py`):**

* **Urban island**: four towers carry a sign on their east wall, a little narrower than the wall: the Windows
  logo, the white neon joystick, the woman in a martini glass and the "BAR" board (`MapRetouch.TOWER_SIGNS`,
  mount "face" of `BuildingExtras.SIGNS`). They glow at night like the other neon signs.
* **City**: ten more billboards and two basketball courts on bare ground beside a street; every hotel is the
  orange low poly hotel; the school bus is parked in front of the main school; a Burger King and two Las Vegas
  clubs are gone; the neon tower of Las Vegas faces east.
* **Prison**: a wire fence all round it, on dry ground only, with floodlights and bleachers in its yard.
* **Secret base**: 1.5 times bigger (its jets too), inside a wire fence. Ground helipads are the painted H of the
  hospital roof, and helicopters are a third bigger.
* **Fog island**: the jets and four of the carriers are turned about, the army and medical tents are mixed, half
  of the army vehicles are gone, the plant has no air defence any more and its barracks has the size of the
  others; jeeps stand by the tents, grey Humvees drive on the roads, a fire truck and a tow truck wait on the
  apron. A sand Humvee stands at the west end of the Golden Gate.
* **Farmland**: one harvester moved to another wheat field, the forwarder and a tractor turned.
* **Development island**: one more shop, the blue townhouse.

**Eighteenth wave (`port_rework.gd`, the last step of the generation; models from `tools/build_wave16_models.py`):**

* **Hotels**: each of the four hotels has its own model (`PortRework.HOTEL_MODELS`): the orange hotel, the small
  purple hotel, the five-star hotel with awnings and the glass twin tower with a rooftop pool. When there are
  fewer hotels than models, hotels are added on bare plots beside a street in the city.
* **Industrial zone and port**: the old factories (concrete factory, brick works, ruin, garage, Kenney
  factories and sheds) and the container yards far from the crane are gone (the 32 yards nearest the crane
  stay, with the oil silos). Each of the 37 models of `PortRework.PORT_MODELS` stands on its own lot, the big
  ones nearest the centre of the zone and beside a street: the industrial buildings set (halls, power plant,
  warehouses, sheds, a portal crane, a water tower, a radio mast and tanks), the storage tanks, three oil tanks
  and the brick factory.
* **Sea**: the offshore oil rig stands off the port, with open sea all round it.
* `tests/dump_sites.gd` prints the hotels and the buildings of the industrial zone with their cells and models.

**Nineteenth wave (`map_retouch.gd`, models from `tools/build_wave16_models.py`):**

* **Urban island**: Taiwan style signboards on the row of towers, on the same east side as the neon signs. A
  tower whose east wall is free carries its sign on that wall: the "Banasonic", McDonald's and Japanese
  Coca-Cola boards stick out of the wall from their brackets (mount "blade"), and an LED ticker band wraps the
  free south-east corner of a tower (mount "corner"). A tower with a lower one in front of it carries its board
  on the roof instead, seen over the other one: the Coca-Cola billboard and the LED safety board (mount "roof",
  `deep`). The neon bull moved from its wall to the roof of its tower. At night only the boards light up, in
  their own colours; the steel frames stay dark (`NightWindows.LOGO_PACKS`, `LOGO_DARK`).

| Where (on screen) | District | What you find |
| --- | --- | --- |
| centre-top | **Downtown** | the only skyscraper district: Kenney towers outside, photo towers in the middle, and 7 New York landmarks (Empire State, Chrysler, One WTC, Woolworth, New York Times, MetLife, Flatiron), drawn much taller than the Kenney towers |
| just behind downtown (north) | **Poor district** | a small district of grey panel towers and slabs, garages and corner shops, and the one big urban ghetto block |
| left of downtown | **Little Las Vegas** | casino palaces, neon towers, resorts, small bars, wedding chapels and clubs of every size, the cinema and the shopping center; the neon signs are all on the roofs, none at street level |
| west coast | **West desert** | reaches the sea without a beach: the secret base ("area 51": airbase with runway, hangar, tower and jets, bunker, radio station), mesas, ranches and oil pumps |
| south-west coast, next to the desert and Vegas | **Industrial zone and port** | 37 different industrial buildings and tanks (one of each model, eighteenth wave), container yards round the crane on the quay (no beach), the oil rig at sea |
| centre | **Central park** | a large wood with a lake, a fountain and two crossing paths, ring roads all around |
| north-east | **Mountain forest** | a forest with three snow-capped mountains standing together far from the city (the one of the core is the biggest), and a wide sand beach on its coast; the forest thins to meadow at its edge |
| below the park | **Civic center** | the main city hall and the police headquarters (each on its own plot), the bank, fire station, post office |
| right of the park | **United Nations** | the U.N. tower (half the size it was) with a small emblem, on its own plot where everyone sees it |
| left of the park | **Shopping streets** | the main hospital, the shopping center, hotels, New York street buildings, mini hotels; three pharmacies and many more shops, all facing the camera |
| right / bottom | **Residential** | houses with gardens (Kenney, cartoon), the main school with its sports ground, the big church (far from the U.N.), the cemetery, gas stations |
| south | **Red district** | white and red low-rise town, bigger than before, mixed with colourful houses; the drive-in cinema, a crane, McDonald's and Burger King, the big ferris wheel at the beach, and one of each food stall (ice cream kiosks, and half-size food trucks) |
| left | **Sports corner** | the big stadium (own plot, floodlit at night) |
| south-east | **Farmland** | the one farming district: crop fields (wheat, corn, plowed soil, green rows) with farms and a country road |
| everywhere | **Hotels** | four hotels, each with its own model (eighteenth wave) |
| far west, across the metal bridge | **Urban island** | the third island, long from north to south, planned end to end (`urban_island_planner.gd`): the **airport** at the south end (the left end on screen) with nothing built in front of it, the **tower city** in the middle (towers of three packs, all showing their front to the camera, a few futuristic ones in the centre), and the **nuclear plant** at the north end (the right end) with its cooling towers and hall beside it, a small yard and only low industry in front. No trees |
| just south of the urban island | **BT tower islet** | a tiny industrial islet with the BT tower in its middle and three satellite dishes round it |
| the two forests | **Watchtowers** | two simplified wooden lookouts, one in the north-east forest and one in the forest of the old city |
| far north-west, at sea | **Prison island** | a long rocky island far from the coast: a very big cellhouse (no sign), stone blocks, a villa, a workshop, lighthouses |
| east, across the Golden Gate | **The fog island** | a second island under a clear sky, with the military base and its nuclear plant (it was hidden in a thick bank of fog). A three-lane highway leads to the Golden Gate (no roadblocks, the deck is level with the road; the fog stays clear only over the bridge itself and covers the island from its coast). The "SEASON 2" title is switched off |
| coast | **Beaches, rocky shores, islets** | six lighthouses, each on a real coast cell (four round the main island, two on the prison island), and palm islets; on the smallest one a pirate grave |

How it is built (`scripts/generation/`, one seed in `CityConfig.seed`, the same map on every device):

**0. The layout** (`map_layout.gd`): every island, round district and single place of the big map, in
cells of the first map and scaled by `CityConfig.map_scale`. The planners ask for them by name.

**1. The core city** (on a 180×180 grid):

1. **`island_shaper.gd`**: an elliptical island with a little noise, sandy and rocky shores.
2. **`district_planner.gd`**: the district layout (anchors, hints and the park, mountain forest and big-building plots, in island units).
3. **`road_planner.gd`**: recursive splitting (BSP) into blocks. The borders of the park, the forest and the plots of the big buildings are cut first, so they become ring roads. The first splits are avenues with street lights.
4. **`lot_planner.gd`**: blocks cut into lots, every building facing its street.
5. **`service_planner.gd`**: the big buildings fill their plots; every main public building once, never two close together; then the small services of each district (4 hotels, 3 pharmacies...).
6. **`landmark_planner.gd`**: the park lake and paths, the first mountain, the road to the Golden Gate, the lighthouses.

**2. Everything around it** (`core_embed.gd`, `extension_island.gd`, `extension_planner.gd`):

7. **`core_embed.gd`** copies the finished core city into the 384×384 map.
8. **`extension_island.gd`** raises the rounded main island around it (the core keeps its own streets, shores and forests), the urban island, palm islets and the prison island.
9. **`extension_planner.gd`** works only on free land, with round blobs, and calls its helpers: `extension_roads.gd` (the two highways, east to the Golden Gate and west to the metal bridge, and the shortest-road links), `extension_spots.gd` (free plots and spots), `urban_island_planner.gd` (the urban island, with its own random numbers), `extension_features.gd` (the desert with the base, the industrial zone and port, the farmland, two more mountains, the watchtowers, the prison compound, the lighthouses). The poor and red districts get BSP streets and lots with round shapes. Everything is linked to the old city by the shortest road.
10. **`fog_island_shaper.gd`**: the island in the fog, placed right after the end of the east highway.

**3. The rules of the finished map**:

11. **`manual_edits.gd`**: hand-made corrections, each one named by a kind of building near a place (no cell, no building number).
12. **`road_network.gd`**: makes one clean network of the roads the planners drew: no two roads side by side, no corner contacts, no stubs, no loose groups; the highways end at a bridge or at an avenue that crosses their three lanes.
13. **`building_budget.gd`**: how many buildings of each kind the map holds, whatever its size. The surplus is cleared (bare ground), the few missing ones are added.
14. **`map_audit.gd`** measures all this; `tests/test_map_audit.gd` checks it against `tests/baseline/map_snapshot.json` (see `docs/map_rebuild_plan.md`).

Which family of models a building uses (Kenney, photo towers, New York, the quarter...) is decided per district in `scripts/world/model_pools.gd`.

To move a district or change its size, edit `ANCHORS`, `PARK_AREA`, `FOREST_AREA`, `PLOTS` or `HINTS` in `district_planner.gd` (core city), or the blobs at the top of `extension_planner.gd` and `extension_features.gd`, and `MAIN` / `URBAN` / `URBAN_NORTH` / `TOWER_ISLET` / `PRISON` in `extension_island.gd` (everything around). The plots of the airport and the nuclear plant are at the top of `urban_island_planner.gd`. The size of the fog island is `FogIslandShaper.SIZE`.

### The fog island

East of Chat City, a metal bridge (the same model as the west one) leaves the east coast and disappears into the fog (`scripts/world/fog_island.gd`).
The island itself lies next to the city map and costs very little: it is not streamed, it has no streets and it is drawn with a few MultiMeshes.
The fog is made of pictures, not 3D volumes:

* four sheets of drifting cloud texture at different heights (`shaders/fog_layer.gdshader`), whose holes open and close over the buildings;
* about 50 big painted billows and two smoke plumes on camera-facing quads (`shaders/fog_puff.gdshader`);
* the "SEASON 2" title, always on top (switched off: `FogIsland.SHOW_TITLE`).

The textures (`textures/fog_noise.png`, `fog_puffs.png`, `season2.png`) are drawn by `tools/make_fog_textures.py` from fractal noise.
At night the fog turns dark blue-grey.

**Nineteenth wave (`lighthouse_island.gd`, the last step of the generation; `FogBaseSites`, `MapFences`; models from
`tools/build_wave16_models.py`):**

* **Golden Gate checkpoint (fog island)**: where the road leaves the bridge it runs through a military post
  (`checkpoint.glb`, the "military base asset pack" without its ground, tank, transformer and vehicle shelter): walls,
  a gate with barriers at each end, two guard posts, two watchtowers, the garage and road lights, on a concrete pad.
  The road narrows to 1.5 cells between its gates. The five vehicles that guarded the end of the bridge are parked
  inside (`FogBaseSites.CHECKPOINT_PARK`): the two T-55 and the two BRDM side by side in the north yard, their noses
  to the road, and the grey Humvee in the south yard beside the garage.
* **Secret base**: the "Danger" plate of the chainlink fence pack hangs on its fence beside the gate, facing out.
* **Lighthouse island**: a little island alone in the sea south-east of the main island, sandy beaches all round it
  and no tree; its coast is an ellipse cut by noise, so it is not round. The lighthouse stands in the middle, facing
  south, with the "Light House Club" sign of the night club sign pack jutting out of the east wall of its house
  (`lighthouse_club.glb`: the building, and the glowing part of the sign drawn with it, lit like a neon at night).

**Twenty-first wave (`museum_site.gd`, `map_retouch.gd`, `roadblocks.gd`, `scenic_props.gd`; models from
`tools/build_wave16_models.py`):**

* **Museum**: the city hall of Utrecht (`museum_hall.glb`, `Kind.MUSEUM`) stands on the biggest free square near the
  shop at (215, 203), its front to the east (`MuseumSite`, added last so no building number moves).
* **Neon woman**: the neon woman left the tower of Las Vegas for the east wall of the tower at (67, 195), as wide as
  the wall (it replaced the bar sign); the bull sign of the tower at (71, 204) is smaller (`BuildingExtras.SIGNS`).
* **Development island**: two more buildings in the row (`tools/build_wave16_models.py`, `SHOPS`): the shop of the
  business pack and the wooden house with a balcony and a tent.
* **Port**: the three tanks of the old tank row (two old tanks of three silos and the rusty one) moved into the
  walled empty square north of it (`PortRework.PORT_MOVED`, `PORT_ADDED`): two rows lying east-west, the rusty tank
  at their east end.
* **Golden Gate**: a second blockade (the barriers of the west checkpoint) stands near the sand Humvee, the
  tanks R-13 and R-14 are on the road just behind it, and a second sand Humvee is parked by the first cruiser. The black
  Japanese police car of the urban-island blockade stands on the road in front of the bridge entrance.
* **Props**: the deck chair of the pack looks along +X, so the popup gives its real facing (`front` of a prop). The lone
  chair looks north, one chair of the beach at (300, 129) and the chairs of the beach at (232, 61) look at their beach
  ball, those of the beach at (171, 62) look west. The red pickup of the field at (257, 282) faces south.
* **Fog island**: the two T-55 and the two BRDM of the checkpoint look south, at the road.

**Twenty-second wave (`fog_base_sites.gd`, `fog_base.gd`; the `fog_city` pack of `tools/build_wave16_models.py`):**

* **Fog island, inhabited**: the avenue from the Golden Gate crosses a capital (business centre of towers on both sides
  of the avenue, suburbs of houses all round it), Eastbay (a small centre of offices and shops, houses behind it), an
  industrial zone, houses south of the nuclear plant and farmland north and south (crop fields, barns, a tractor and a
  harvester). Cars are parked along the streets; a bus, a fire truck, an ambulance and trucks stand in the towns.
* **Army base**: very small, inside a wire fence north of the capital. Its landing zone is the model of the secret base,
  drawn exactly as big as on the main island, with a helipad, three tents, a barracks, a radar and five armoured vehicles.
  The nuclear plant has its own fence. The checkpoint at the end of the bridge stays.
* **Models**: the five models of `fog_city.glb` (office, office tower, night tower, house, and one storey of a block,
  stacked 2 to 6 high) are used all over both towns, mixed with the houses, shops and towers of the main island.

## Beaches, park and borders

* **Piers** (`beach_sites.gd`): wooden piers running into the sea from sandy beaches of the main island
  (`pier_old` pack). No beach huts: their pack was removed.
* **Central park** (`amenities_planner.gd`): wide paths from the streets through the lake, a ring path round
  it, diagonal paths to the corners, benches along the arms, flowerbeds and a playground.
* **Boardwalk** along the beach of the red district, with lamps that glow at night.
* **Desert border**: the grass turns patchy and dry over a few cells on both sides, with dry tufts and rocks.
* **Golden Gate checkpoint**: a police car beside the barriers, like the one on the west highway.

All of it is stored in two layers of `CityData` (`deco`, `edge`) and drawn by `GroundPlacer` / `GroundLayer`.

## Boats

`boat_sites.gd` puts one boat of each kind at sea (five packs `boat_*`, a boat is `Kind.BOAT`, its seed is the
kind): the cargo ship west of the industrial port, the submarine north of the Golden Gate bridge about 20 cells
away from the highway, a fishing boat and a wooden boat beside the piers, a simple boat off the red district.
The sea around each boat must be free, and the corridors of both bridges are kept clear.

## Props and fences

* **`prop_sites.gd`** (end of the building list): the forest fire truck (CCF), one billboard in every zone, the
  hot air balloon over the north-east, buildings behind the main cinema and a fountain in front of it, many
  container stacks round the cranes of the port and on the BT tower islet (with a crane), two more post offices
  (poor and red districts: the closest lot becomes one), the UFO and two tanks at the secret base, and more
  Kenney commercial buildings in Las Vegas.
* **Fences** (`amenities_planner.gd`, `deco` layer): round the secret base (two gates, a tank outside each) and
  round the facility of the BT tower islet.
* **Highway asphalt** (`highway_surface.gd`): a 75 KB texture (lanes, double yellow line) laid over the
  three-lane highways only. The 4.6 MB `highway_road.glb` (18,000 triangles) is not used: too heavy.
* The map starts at night; the city name is no longer shown.

## Hand edits

`scripts/generation/manual_edits.gd` lists single-building corrections made after the map is generated:
a facing, a size factor, a replacement kind (a hotel becomes a city hall, a shop a Burger King), a new
lot (`rect`, `move_to`), a neon `sign` or a deletion. The number is the one shown in the information bubble. A deleted building stays in the list
as `Kind.EMPTY`, so no number ever moves. Each entry also names the kind and the lot it expects: if the
generation changes and the numbers move, the entry is skipped with a warning instead of touching
another building. The test `tests/test_urban_island.gd` checks that all entries were applied.

## Selecting buildings

Click or tap (without dragging) any building: it glows, a frame and a wave appear on the
ground, an arrow bobs above it and an information bubble shows its ID (`B0042`), kind
(code name), model name, category, cell, world position, facing, zone and seed
(`scripts/world/building_info.gd`). "Copy info" puts it on the clipboard. Esc, the X or a
click elsewhere clears it. `BuildingPicker.building_selected(info)` is the hook for a
database or game logic later.

Other additions: burger joints (one per district), nuclear plant and airport on the urban
island, cinema in place of the east museum, highway roadblocks (`scripts/world/roadblocks.gd`).

## Day and night

The city runs an automatic day and night cycle (`CityConfig.day_cycle_seconds`, 4 minutes by default; `scripts/world/day_night.gd`).
At night:

* Kenney windows glow. An emission mask is built from their colour palette, so only the glass lights up.
* The windows of the procedural buildings glow too.
* The buildings of the curated packs (New York, photo towers, stadium, coliseum, main public buildings...) are softly lit, like floodlit facades.
* The stadium has four floodlights at its corners and only its pitch and stands are lit (its outer walls stay dark); boats carry a red (port) and a green (starboard) navigation light; the drive-in shows its film and lights its lot, the airbase lights its runway.
* The new packs (bank, hotels, houses, factories, prison blocks...) are softly lit too.
* The red H and cross of the hospitals are neon, so they stay bright red.
* Street lamps get bulbs.
* Signs shine, and the neon stays bright.

No real lights are added, so night costs the same as day, on phones too.

## Signs

All signs are on one 1024×1024 texture, `textures/signs.png`:

* the U.N. emblem (the name is not used any more)
* the gold "$" coin (procedural bank, now only a fallback)
* neon "XXX" (a render of the XXX Neon Sign model, a flat texture with glow instead of 40,000 polygons), "CASINO", "BAR" and "CLUB"
* the "POST OFFICE" and "MUSEUM" plates
* the film shown at the drive-in

`tools/make_sign_atlas.py` draws it with the free DejaVu fonts; the emblem source is `tools/sign_sources/un_emblem.png`.
Signs are flat panels placed with `MeshKit.panel()`, which always faces the reader, so text is never mirrored.
Landmarks also face a street on a side the camera sees, so their signs are in view.

## Memory and performance

* **Compact data**: the whole city is packed byte and int arrays, a few MB in total.
* **Ground and sea**: one plane and two small textures (one texel per cell) instead of thousands of tiles. The coastline comes from a shader.
* **Streaming chunks** (32×32 cells): only chunks inside the camera view are built.
  * **Far detail**: one coloured box per building, 1 draw call per chunk.
  * **Near detail**: the real Kenney models, roads, trees and lights. Each model is one `MultiMesh` per chunk, about 16 draw calls per chunk.
  * On desktop the whole island stays in near detail. Phones switch to boxes when zoomed far out.
* **Worker threads**: chunk contents are computed on `WorkerThreadPool`. The main thread only creates nodes, a few per frame.
* **LRU eviction** keeps at most `max_near_chunks` and `max_far_chunks` in memory.
* **Mobile profile** (`CityConfig.create()`): fewer detailed chunks, fewer threads, fewer model variants.
* **Curated models**: textures are reduced to 256 or 512 px and only the colour map is kept. Packs are opened once while loading, then freed.
* **Browser download**: about 45 MB of game data plus the 37 MB engine (cached by the browser).

## Models (FREEMODELS)

`FREEMODELS/` contains the GLB versions of the Kenney City Kits (CC0): Roads, Commercial, Suburban and Industrial.
`ModelCatalog` scans the folder recursively and sorts models by file name:

* skyscrapers, commercial buildings, houses, industrial buildings and props
* trees, street lights, and the 5 road tiles (straight, bend, T, crossroad, end)

The road tiles are rotated automatically from their measured connection masks.
Everything the kits do not have is modelled in code (`scripts/procedural/`) in the same style:

* **Public buildings**: hospital (red H on the helipad), school, fire station, church, city hall, the bank with its "$" signs, the United Nations, the prison. Fallbacks are kept for the police station, the stadium, the bank, the church and the hotels.
* **Las Vegas**: casinos, neon clubs, ferris wheel, drive-in. The neon is drawn unshaded, with no post effect.
* **Desert and coast**: telecom tower, satellite dishes, mesa, cactus, lighthouse, palm tree, park lake.
* **BT tower** (`LandmarkMeshes.bt_tower`): concrete shaft, two tiers of aerial horns and a lit cabin, 12 cells high, alone on its islet.

> If your local `FREEMODELS` also contains the `FBX format` / `OBJ format` / `Previews` folders from the zips,
> put an empty `.gdignore` file in each of them. Godot then skips importing duplicates (faster import, smaller export).

### Extra model packs (curated)

The packs you added are kept untouched in `FREEMODELS/_incoming/`. Its `.gdignore` stops Godot from importing them, and Docker skips them too.
`tools/curate_models.gd` builds `FREEMODELS/curated/` from them, following `tools/curate_spec.json`:

* **What is kept**: only complete buildings. Wall slabs, ground pieces and props are dropped, and the bad automatic picks are listed in `exclude`.
* **Scale**: every building is put at Kenney scale (1 unit = 1 road tile), centred, standing on the ground, front towards +Z.
* **Textures**: reduced, colour map only.
* **Output**: one `.glb` per pack plus a `.models.json` list (building name to category). The game reads these lists.

| Curated pack | From | Category | Used for |
| --- | --- | --- | --- |
| `ny_buildings` | New York buildings | LANDMARK, TOWER_PHOTO, NY_MIDRISE | 7 landmarks, glass towers, brick buildings |
| `ny_street` | buildings | NY_STREET | shop and office buildings in commercial streets |
| `towers_a` | city pack 7 | TOWER_PHOTO | 8 towers for the middle of downtown |
| `quarter` | 100 low-poly buildings | QUARTER_LOW / MID / TALL | the colourful quarter (87 buildings) |
| `outpost` | low-poly buildings | OUTPOST | the desert outpost |
| `police` | low-poly police station | POLICE | (kept; the same model as the main police station) |
| `stadium` | low-poly stadium (+ its pitch; kept as it was, unused) | - | - |
| `stadium_night` | `stadium` with a night map (`tools/make_night_variants.py`) | STADIUM | the stadium; at night only its pitch and stands are lit |
| `public_main` | low-poly public buildings pack | SCHOOL_MAIN, GAS_STATION | the main public buildings, one of each, drawn big |
| `pharmacy_night` | the pharmacy of `public_main`, with a night map (`tools/make_night_variants.py`) | PHARMACY | the pharmacy; its green cross glows at night |
| `police_hq_night` | the police station of `public_main`, with a night map (`tools/make_night_variants.py`) | POLICE_MAIN | the main police station; the word POLICE and the round sign on the roof glow blue at night |
| `hospital_night` | the hospital of `public_main`, with a night map | HOSPITAL_MAIN | the main hospital; the blue cross of its front glows strong blue at night (the red H of the helipad stays) |
| `city_hall_night` | the city hall of `public_main`, with a night map | CITY_HALL_MAIN | the city hall; the words CITY HALL glow coral red at night |
| `cinema_night` | the cinema of `cinema2` (kept as it was, unused), with a night map | CINEMA2 | the main cinema; the word CINEMA glows red at night |
| `hotel_small_night` | `hotel_small` of `hotels`, with a night map | HOTEL_LOW | the small purple hotel; the word HOTEL glows green at night |
| `hotel_stars_night` | `hotel_stars` of `hotels`, with a night map | HOTEL_LOW | the five-star hotel; its five stars glow yellow at night |
| `un_tower` | building 3 | UN_TOWER | the United Nations tower |
| `crane` | building crane | CRANE | one crane in the colourful quarter |
| `skyline2` | second low-poly night skyline (keeps its light map) | SKYLINE2 | the skyline blocks of the urban island |
| `urban` | City Buildings - BlackThornProd | URBAN | the towers of the urban island |
| `city_night` | Low-poly City Night (keeps its light map; 17 of its buildings) | URBAN2 | more towers of the urban island |
| `night_towers` | city at night low poly skyscrapers (9 towers, keeps its light map) | NIGHT_TOWER | the tallest towers of the urban island |
| `cooling` | Cooling Tower (Background) | COOLING, COOLING_HALL | the cooling towers and hall of the nuclear plant |
| `neon_controller` | Neon game controller | NEON_CONTROLLER | a neon roof sign, very bright at night (on shop B-00257) |
| `neon_pacman` | Neon Pac-Man (rest pose, no animation) | NEON_PACMAN | a neon roof sign (on the police station B-00685) |
| `pier_old` | Old pier | PIER | piers on the beaches |
| `boat_simple`, `boat_wooden`, `boat_fishing`, `boat_cargo`, `boat_sub` | the five boat files | BOAT_* | one boat of each at sea |
| `watchtower` | low poly Watchtower (without fences, rails, lamps and trees) | WATCHTOWER | the two forest lookouts |
| `mcdonalds` | McDonald's building | MCDONALDS | the McDonald's of the red district (with procedural golden arches) |
| `hungry` | Hungry Jack's restaurant | BURGER_KING | the Burger King of the red district |
| `metal_bridge` | stylised metal bridge | METAL_BRIDGE | the bridge to the urban island |
| `future` | night skyline pack, cut into 11 towers | FUTURE | the futuristic towers of the urban island |
| `carto` | CartoCity pack | BANK_PACK, HOUSE2, TOWN2, SHOP2, HOTEL_SMALL, BARRIER, CONE, TRUCK, CONTAINER, BARREL | the bank, colourful houses and shops, mini hotels, the orange barriers and cones of the bridge, industrial props |
| `accommodations` | low poly accommodations buildings | HOTEL_PACK, HOUSE2, TOWN2 | the two big hotels, villas, small apartment blocks |
| `free_mini` | free low-poly buildings (cut by position) | CHURCH_PACK, GAS_PACK, SHOP2, HOTEL_SMALL, TOWN2 | the big church, a gas station, bars, boutiques, mini hotels |
| `street` | low-poly city street buildings | SHOP2, STALL | textured shop blocks, ice cream stalls and food trucks |
| `euro` | somewhat low-poly buildings | TOWN2, HOUSE2, WAREHOUSE, FACTORY, FIELD | tall town houses, a garage, the brick works, a crop field |
| `poor` | buildings pack (cut by position) | POOR_SLAB, POOR_BLOCK | grey panel towers and slabs of the poor district |
| `russian` | Russian building | RUSSIAN | the one big urban ghetto block |
| `industrial` | low-poly industrial building | FACTORY, RUIN | the concrete factory (industrial zone) |

Two packs (`free_mini`, `poor`) store one object per material for the whole town, so `curate_models.gd` can cut them with a `"region": [x0, z0, x1, z1]` rectangle (world space, optional `ymin` / `ymax`) instead of a node name.

Not used:

* **Kit parts, not whole buildings**: buildings pack, European asset pack, `building.glb`.
* **Not placed**: the train station and the gym of the CartoCity pack, the police car and solid roadblocks (removed on request), the museums of the European pack (the museum was replaced by the U.N.).

### Credits of the latest models

* "Low Poly Night City Building Skyline" by 99.Miles (the towers of the urban island), "Golden Gate Bridge" by JuanG3D, "Low-Poly Radar Dish" by joe_carrot, "Carrier" by victorberdugo1 and "Low Poly Silo" by CevoCreative, CC BY 4.0
* Military base: "Low poly F14 Tomcat" by SIpriv, "Jungle Tent" by SyntheticMN, "WWII Medical Tent" by creationwasteland, "Nasams 1 Surface-to-Air Missile System" by Muhamad Mirza Arrafi, "Radar" by Calibians, "Nuclear Power Plant [Game Asset]" by Jen S Abbott and "school building" by swjeta (the barracks), CC BY 4.0
* "Strike Fighters tanks pack" and "Strike Fighters APC/IFV pack" by 42manako (T-55, BMP-1, BRDM, EE-11 AA): **CC BY-NC 4.0, non-commercial use only**
* "Low Poly Church" by Anthony Yanez and "Neon Sign - Woman" by Kira Khaos, CC BY 4.0

* Sixteenth wave: "Windows Logo (2001-2012) in 3D" by ZoeError Remakes, "Neon joysticks" by local.yany, "BAR sign board" by alina_dreiman, "SCHOOL BUS - low poly model" by Jasmin Daniel, "Jeep" by rajibkc and "Low Poly Building" by Ahmed Galeb, CC BY 4.0
* "Armored Vehicle-Test" and "Armored Vehicle+Animation" by Kapi777 (the two Humvees): **CC BY-NC 4.0, non-commercial use only**
* "Woman in Martini Neon Sign" by trashbinkr and "Low poly Hotel 1" by assetfactory: Sketchfab Standard licence (raw files kept out of git)
* Nineteenth wave: "GAME READY MILITARY BASE ASSET PACK" by Oxygen3D (the checkpoint), "Light House" by Oksana3D and
  "Night club sign" by Mantas Stankaitis, CC BY 4.0; "Simple Chainlink Fence" by trashbinkr (the "Danger" plate),
  Sketchfab Standard licence (raw files kept out of git)

* "Low-poly Container" by Muhammad Awais Gul, CC BY 4.0 (shops/, development island)
* "building 3" by geniusrahman155, CC BY 4.0
* "Building Crane (low poly)" by jmarco2000, CC BY 4.0
* "Low Poly City | CartoCity Pack | Cartoonsih City" by DevPoly3D, CC BY 4.0
* "City Buildings - BlackThornProd Video" by Tiko, CC BY 4.0
* "Low Poly Game Ready McDonalds Building" by costoWRLD, CC BY 4.0
* "Low-poly-night-city-building-skyline" by willis123, CC BY 4.0
* "Stylised Low Poly - City Metal Bridge" by remidoes3d, CC BY 4.0
* "Simple Low poly Boat" by Jewel John, "Wooden Boat" by sumitmangela, "Low Poly Cargo Ship" by Javier_Fernandez and "The Project 941 / Akula / Typhoon submarine" by yakudami, CC BY 4.0; "Fishing Boat (low poly style)" by liborv, Sketchfab Standard licence (raw file kept out of git)
* "Low Poly UFO Scene" by EdwinRC (CC BY 4.0), "Highway" by Genkidonky (CC BY 4.0)
* "Pier (Game ready model)" by BlackBox613 and "Old pier" by smitecraft.swe, CC BY 4.0
* "neon game controller" by alina_dreiman and "Neon Pac-Man" by patrakeevasveta, CC BY 4.0
* "Taiwan style Signboard (lowpoly)" by Solarliu, CC BY 4.0 (six of its boards, in `FREEMODELS/curated/taiwan_signs.glb`; raw file kept out of git)
* "LOWPOLY CITY STREET PACK BUILDINGS STYLIZED" by haykel-shaba, CC BY 4.0 (the stage, floodlights, bleachers and crowd barriers of the concert camp; raw file kept out of git)
* "Low-poly City Night" by smooth998, "city at night low poly skyscrapers" by dasy444, "Cooling Tower (Background)" by trashbinkr, "BT TOWER" by PeeJaa and "low poly Watchtower" by Cebrail Yildiz: Sketchfab Standard licence (raw files kept out of git, only the curated copies are committed)
* "XXX Neon Sign" by Jimmy Johansson, CC BY 4.0 (only a front render of it is used, as the XXX texture of the sign atlas)
* "[Free] Buildings Low Poly" by GraphOrigin, CC BY 4.0
* "Somewhat Low-poly Buildings" by Calne, CC BY 4.0
* "Low-Poly City Street Buildings Asset Pack" by treasureimpact, CC BY 4.0
* "Buildings Pack" by maxk3, CC BY 4.0
* "Russian Building 4k texture low-poly game model" by BlackMonolith, CC BY 4.0
* "Low poly public buildings pack" and "Low poly accommodations buildings" by assetfactory, "Low-Poly Industrial Building" by FlunkedPunk and "Hungry Jack's Restaurant (low Poly)" by Jotrain Models: Sketchfab Standard licence. They may be used in the game, but the raw files must not be shared on their own, so they are kept out of git; only the curated copies the game needs are committed.

All from sketchfab.com. CC BY 4.0 needs this credit wherever the game is shown.
The raw files of the two latest waves are not in the repository either (they are heavy):
put them back in `FREEMODELS/_incoming/` to rebuild the curated packs.

**Rebuild after changing the spec** (needs a display, or `xvfb-run` on Linux):

```
godot --rendering-driver opengl3 --script res://tools/curate_models.gd                # all packs (every tools/curate_spec*.json)
godot --rendering-driver opengl3 --script res://tools/curate_models.gd -- crane       # one pack
godot --rendering-driver opengl3 --script res://tools/model_sheet.gd -- FREEMODELS/curated/quarter.glb sheet.png
```

The second command renders a numbered contact sheet of a pack, to choose what to keep.

## Project structure

```
project.godot
scenes/main.tscn                  root scene (only the Main script)
shaders/ground.gdshader           island + sea colouring (and the fog island ground)
shaders/fog_layer.gdshader        drifting fog sheets
shaders/fog_puff.gdshader         fog billows on camera-facing quads
scripts/
  core/       main.gd (bootstrap, loading), city_config.gd (all settings), city_types.gd (enums, helpers)
  data/       city_data.gd        packed city layers + buildings + chunk index
  generation/ city_generator.gd   pipeline: island_shaper, district_planner, road_planner,
                                  lot_planner, service_planner, landmark_planner, core_embed,
                                  extension_island, extension_planner (+ extension_roads, extension_spots,
                                  extension_features, urban_island_planner), fog_island_shaper
  assets/     model_catalog.gd (scan + classify + curated lists), model_library.gd (load, merge, mesh ids),
              night_windows.gd (window glow of the Kenney kits)
  procedural/ mesh_kit.gd (low-poly builder), sign_atlas.gd (signs + night materials),
              service_meshes.gd, civic_meshes.gd (bank, U.N., prison), landmark_meshes.gd,
              entertainment_meshes.gd (Las Vegas), nature_meshes.gd (desert, coast),
              public_meshes.gd (post office, cemetery; museums and hotels as fallbacks), military_meshes.gd (bunker, airbase),
              farm_meshes.gd (crop fields)
  world/      chunk_streamer.gd (LOD + streaming), building_placer.gd, model_pools.gd, day_night.gd,
              ground_placer.gd, instance_batch.gd, ground_layer.gd, fog_island.gd
  camera/     iso_camera.gd (ortho iso camera), camera_input.gd (mouse/touch/keys)
  ui/         loading_overlay.gd
tests/        headless checks and the screenshot runner
tools/        curate_models.gd + curate_spec.json (model packs), model_sheet.gd (contact sheets),
              make_sign_atlas.py (signs texture), make_fog_textures.py (fog and title)
textures/     signs.png, fog_noise.png, fog_puffs.png, season2.png
```

## Tuning

* **General settings** (`scripts/core/city_config.gd`): `city_name`, `seed`, `map_size`, island shape, LOD threshold, memory budgets.
* **District layout**: `scripts/generation/district_planner.gd`.
* **Public buildings** (which ones, how many, in which district): `scripts/generation/service_planner.gd` (`SPECS`).

## Tests and tools

**Polygon heatmap:** `godot --path . --rendering-driver opengl3 --script res://tools/poly_heatmap.gd`
(not `--headless`: MultiMesh transforms need a renderer) then `python3 tools/poly_heatmap.py`
writes `poly_heatmap.png`: every parcel coloured by its triangles, chunk totals, heaviest
parcels and kinds.

```
godot --headless --import                                         # first import of the models
godot --headless --script res://tests/test_generation.gd          # generation smoke test
godot --headless --script res://tests/test_urban_island.gd        # urban island, BT islet, watchtowers; prints a text map
godot --headless --script res://tests/debug_map.gd -- map.png     # top-down zoning map
godot --headless --script res://tests/bench_chunks.gd             # chunk build cost / draw calls
godot -- --capture <dir>                                          # screenshots of key places
```
