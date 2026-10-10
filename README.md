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

* **From a phone or another PC on your network:** open `http://<your-pc-ip>:8080/lite/`. Browsers only allow the multi-threaded build on `localhost` or HTTPS, so `/lite/` is a single-threaded build. It is slower, but works everywhere.
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
export_presets.cfg     "Web" (threads) and "Web Lite" (no threads) presets
```

## The island

Chat City is a 384×384-cell map: one big **rounded main island**, the **urban island** to the west and the
**fog island** to the east. It is the first map (272 cells) rebuilt 1.41 times longer on every side: the
islands have twice the area, with the same number of buildings of every kind and the same number of
trees, the same zones touching each other, and roads that form one clean network. The city sits in the
west part of the main island; the districts around it are round blobs, not squares. On screen north-west is up. Special buildings are kept far from each other on purpose.

| Where (on screen) | District | What you find |
| --- | --- | --- |
| centre-top | **Downtown** | the only skyscraper district: Kenney towers outside, photo towers in the middle, and 7 New York landmarks (Empire State, Chrysler, One WTC, Woolworth, New York Times, MetLife, Flatiron), drawn much taller than the Kenney towers |
| just behind downtown (north) | **Poor district** | a small district of grey panel towers and slabs, garages and corner shops, and the one big urban ghetto block |
| left of downtown | **Little Las Vegas** | casino palaces, neon towers, resorts, small bars, wedding chapels and clubs of every size, the cinema and the shopping center; the neon signs are all on the roofs, none at street level |
| west coast | **West desert** | reaches the sea without a beach: the secret base ("area 51": airbase with runway, hangar, tower and jets, bunker, radio station), mesas, ranches and oil pumps |
| south-west coast, next to the desert and Vegas | **Industrial zone and port** | exactly 8 different buildings (concrete factory, brick works, ruin, garage and four Kenney factories), container yards and cranes on a quay (no beach) |
| centre | **Central park** | a large wood with a lake, a fountain and two crossing paths, ring roads all around |
| north-east | **Mountain forest** | a forest with three snow-capped mountains standing together far from the city (the one of the core is the biggest), and a wide sand beach on its coast; the forest thins to meadow at its edge |
| below the park | **Civic center** | the main city hall and the police headquarters (each on its own plot), the bank, fire station, post office |
| right of the park | **United Nations** | the U.N. tower (half the size it was) with a small emblem, on its own plot where everyone sees it |
| left of the park | **Shopping streets** | the main hospital, the shopping center, hotels, New York street buildings, mini hotels, cartoon shops and restaurants (half of them replaced by normal shops, burgers and pizzerias drawn extra big, pizzerias rare); three pharmacies and many more shops, all facing the camera |
| right / bottom | **Residential** | houses with gardens (Kenney, cartoon), the main school with its sports ground, the big church (far from the U.N.), the cemetery, gas stations |
| south | **Red district** | white and red low-rise town, bigger than before, mixed with colourful houses; the drive-in cinema, a crane, McDonald's and Burger King, the big ferris wheel at the beach, and one of each food stall (ice cream kiosks, and half-size food trucks) |
| left | **Sports corner** | the big stadium (own plot, floodlit at night) |
| south-east | **Farmland** | the one farming district: crop fields (wheat, corn, plowed soil, green rows) with farms and a country road |
| everywhere | **Hotels** | nine different hotels, one of each model: four in the city, five in the red district |
| far west, across the metal bridge | **Urban island** | the third island, long from north to south, planned end to end (`urban_island_planner.gd`): the **airport** at the south end (the left end on screen) with nothing built in front of it, the **tower city** in the middle (towers of three packs, all showing their front to the camera, a few futuristic ones in the centre), and the **nuclear plant** at the north end (the right end) with its cooling towers and hall beside it, a small yard and only low industry in front. No trees |
| just south of the urban island | **BT tower islet** | a tiny industrial islet with the BT tower in its middle and three satellite dishes round it |
| the two forests | **Watchtowers** | two simplified wooden lookouts, one in the north-east forest and one in the forest of the old city |
| far north-west, at sea | **Prison island** | a long rocky island far from the coast: a very big cellhouse (no sign), stone blocks, a villa, a workshop, lighthouses |
| east, across the Golden Gate | **The fog island** | a second island hidden in a thick bank of fog and smoke (twice the area of before, same buildings). A three-lane highway leads to the Golden Gate (no roadblocks, the deck is level with the road; the fog stays clear only over the bridge itself and covers the island from its coast). "SEASON 2" floats over it |
| coast | **Beaches, rocky shores, islets** | six lighthouses, each on a real coast cell (four round the main island, two on the prison island), and palm islets; on the smallest one a pirate grave, with the pirate ship anchored off its coast |

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

Which family of models a building uses (Kenney, photo towers, New York, cartoon shops, the quarter...) is decided per district in `scripts/world/model_pools.gd`.

To move a district or change its size, edit `ANCHORS`, `PARK_AREA`, `FOREST_AREA`, `PLOTS` or `HINTS` in `district_planner.gd` (core city), or the blobs at the top of `extension_planner.gd` and `extension_features.gd`, and `MAIN` / `URBAN` / `URBAN_NORTH` / `TOWER_ISLET` / `PRISON` in `extension_island.gd` (everything around). The plots of the airport and the nuclear plant are at the top of `urban_island_planner.gd`. The size of the fog island is `FogIslandShaper.SIZE`.

### The fog island

East of Chat City, a metal bridge (the same model as the west one) leaves the east coast and disappears into the fog (`scripts/world/fog_island.gd`).
The island itself lies next to the city map and costs very little: it is not streamed, it has no streets and it is drawn with a few MultiMeshes.
The fog is made of pictures, not 3D volumes:

* four sheets of drifting cloud texture at different heights (`shaders/fog_layer.gdshader`), whose holes open and close over the buildings;
* about 50 big painted billows and two smoke plumes on camera-facing quads (`shaders/fog_puff.gdshader`);
* the "SEASON 2" title, always on top.

The textures (`textures/fog_noise.png`, `fog_puffs.png`, `season2.png`) are drawn by `tools/make_fog_textures.py` from fractal noise.
At night the fog turns dark blue-grey and the night skyline model shows its city lights through it.

## Beaches, park and borders

* **Beach huts and piers** (`beach_sites.gd`): five thatched huts on sandy beaches of the main island,
  three of them with a wooden pier running into the sea (`pirate_huts`, `pier_old` packs).
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

## Props, fences, bus stops

* **`prop_sites.gd`** (end of the building list): the forest fire truck (CCF), one billboard in every zone, the
  hot air balloon over the north-east, buildings behind the main cinema and a fountain in front of it, many
  container stacks round the cranes of the port and on the BT tower islet (with a crane), two more post offices
  (poor and red districts: the closest lot becomes one), the UFO and two tanks at the secret base, and more
  Kenney commercial buildings in Las Vegas.
* **Fences** (`amenities_planner.gd`, `deco` layer): round the secret base (two gates, a tank outside each) and
  round the facility of the BT tower islet.
* **Bus stops** (`bus_stops.gd`): the second (green) shelter of the Brisbane pack, mostly along the two
  highways, a few on the avenues of the country and in the city.
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
* The stadium has floodlight masts, the drive-in shows its film and lights its lot, the airbase lights its runway.
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
| `towers_a`, `towers_b` | city pack 7 / 8 | TOWER_PHOTO | 16 towers for the middle of downtown |
| `quarter` | 100 low-poly buildings | QUARTER_LOW / MID / TALL | the colourful quarter (87 buildings) |
| `business` | low-poly business pack | BIZ_SHOP, CINEMA, MALL | diners and shops, the cinema, the shopping center |
| `outpost` | low-poly buildings | OUTPOST | the desert outpost |
| `police` | low-poly police station | POLICE | (kept; the same model as the main police station) |
| `stadium` | low-poly stadium (+ its pitch) | STADIUM | the stadium |
| `public_main` | low-poly public buildings pack | POLICE_MAIN, CITY_HALL_MAIN, HOSPITAL_MAIN, SCHOOL_MAIN, PHARMACY, GAS_STATION | the main public buildings, one of each, drawn big |
| `un_tower` | building 3 | UN_TOWER | the United Nations tower |
| `crane` | building crane | CRANE | one crane in the colourful quarter |
| `night_skyline` | low-poly night city skyline (keeps its light map) | SKYLINE | the hidden city of the fog island, a block of the urban island |
| `skyline2` | second low-poly night skyline (keeps its light map) | SKYLINE2 | the second skyline block of the urban island |
| `urban` | City Buildings - BlackThornProd | URBAN | the towers of the urban island |
| `city_night` | Low-poly City Night (keeps its light map; 17 of its buildings) | URBAN2 | more towers of the urban island |
| `night_towers` | city at night low poly skyscrapers (9 towers, keeps its light map) | NIGHT_TOWER | the tallest towers of the urban island |
| `cooling` | Cooling Tower (Background) | COOLING, COOLING_HALL | the cooling towers and hall of the nuclear plant |
| `neon_controller` | Neon game controller | NEON_CONTROLLER | a neon roof sign, very bright at night (on shop B-00257) |
| `neon_pacman` | Neon Pac-Man (rest pose, no animation) | NEON_PACMAN | a neon roof sign (on the police station B-00685) |
| `pirate_huts` | Stylized Pirate Island Pack (huts and pavilions only, no boats) | BEACH_HUT | huts on the beaches |
| `pier_old` | Old pier | PIER | piers beside the huts |
| `boat_simple`, `boat_wooden`, `boat_fishing`, `boat_cargo`, `boat_sub` | the five boat files | BOAT_* | one boat of each at sea |
| `watchtower` | low poly Watchtower (without fences, rails, lamps and trees) | WATCHTOWER | the two forest lookouts |
| `mcdonalds` | McDonald's building | MCDONALDS | the McDonald's of the red district (with procedural golden arches) |
| `hungry` | Hungry Jack's restaurant | BURGER_KING | the Burger King of the red district |
| `metal_bridge` | stylised metal bridge | METAL_BRIDGE | the bridge to the urban island |
| `future` | night skyline pack, cut into 11 towers | FUTURE | the futuristic towers of the urban island |
| `pirate` | pirate ship | PIRATE_SHIP | anchored beside the smallest islet |
| `carto` | CartoCity pack | BANK_PACK, HOUSE2, TOWN2, SHOP2, HOTEL_SMALL, BARRIER, CONE, TRUCK, CONTAINER, BARREL | the bank, colourful houses and shops, mini hotels, the orange barriers and cones of the bridge, industrial props |
| `accommodations` | low poly accommodations buildings | HOTEL_PACK, HOUSE2, TOWN2 | the two big hotels, villas, small apartment blocks |
| `free_mini` | free low-poly buildings (cut by position) | CHURCH_PACK, GAS_PACK, SHOP2, HOTEL_SMALL, TOWN2 | the big church, a gas station, bars, boutiques, mini hotels |
| `street` | low-poly city street buildings | SHOP2, STALL | textured shop blocks, ice cream stalls and food trucks |
| `euro` | somewhat low-poly buildings | TOWN2, HOUSE2, WAREHOUSE, FACTORY, FIELD | tall town houses, a garage, the brick works, a crop field |
| `poor` | buildings pack (cut by position) | POOR_SLAB, POOR_BLOCK | grey panel towers and slabs of the poor district |
| `russian` | Russian building | RUSSIAN | the one big urban ghetto block |
| `industrial` | low-poly industrial building | FACTORY, RUIN | the concrete factory (industrial zone) |

Two packs (`free_mini`, `poor`) store one object per material for the whole town, so `curate_models.gd` can cut them with a `"region": [x0, z0, x1, z1]` rectangle (world space, optional `ymin` / `ymax`) instead of a node name.
Pizzerias of the business pack are their own category (BIZ_PIZZA) and stay rare.

Not used:

* **Kit parts, not whole buildings**: buildings pack, European asset pack, European facades, `building.glb`.
* **Duplicate**: the school (the procedural school is used).
* **Licence not confirmed**: Half-Life 2 buildings.
* **Skipped on request**: the neon woman sign.
* **Not placed**: the train station and the gym of the CartoCity pack, the police car and solid roadblocks (removed on request), the museums of the European pack (the museum was replaced by the U.N.).

### Credits of the latest models

* "Low-poly Container" by Muhammad Awais Gul, CC BY 4.0 (shops/, development island)
* "building 3" by geniusrahman155, CC BY 4.0
* "Low Poly Night City Building Skyline" by 99.Miles, CC BY 4.0
* "Building Crane (low poly)" by jmarco2000, CC BY 4.0
* "Low Poly City | CartoCity Pack | Cartoonsih City" by DevPoly3D, CC BY 4.0
* "City Buildings - BlackThornProd Video" by Tiko, CC BY 4.0
* "Low Poly Game Ready McDonalds Building" by costoWRLD, CC BY 4.0
* "Low-poly-night-city-building-skyline" by willis123, CC BY 4.0
* "Stylised Low Poly - City Metal Bridge" by remidoes3d, CC BY 4.0
* "Pirate Ship" by Oleg Muzyka, CC BY 4.0
* "Simple Low poly Boat" by Jewel John, "Wooden Boat" by sumitmangela, "Low Poly Cargo Ship" by Javier_Fernandez and "The Project 941 / Akula / Typhoon submarine" by yakudami, CC BY 4.0; "Fishing Boat (low poly style)" by liborv, Sketchfab Standard licence (raw file kept out of git)
* "Low Poly UFO Scene" by EdwinRC (CC BY 4.0), "Highway" by Genkidonky (CC BY 4.0), "Bus Stop Shelters & Sign Pack | Brisbane" by Jotrain Models (Sketchfab Standard licence: raw file kept out of git)
* "Pier (Game ready model)" by BlackBox613, "Old pier" by smitecraft.swe and "Stylized Pirate Island Pack" by CG Lads, CC BY 4.0
* "neon game controller" by alina_dreiman and "Neon Pac-Man" by patrakeevasveta, CC BY 4.0
* "Low-poly City Night" by smooth998, "city at night low poly skyscrapers" by dasy444, "Cooling Tower (Background)" by trashbinkr, "BT TOWER" by PeeJaa and "low poly Watchtower" by Cebrail Yildiz: Sketchfab Standard licence (raw files kept out of git, only the curated copies are committed)
* "XXX Neon Sign" by Jimmy Johansson, CC BY 4.0 (only a front render of it is used, as the XXX texture of the sign atlas)
* "Pack - Low Poly - 15 Building" by Islide, CC BY 4.0
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
