# Chat City (Godot 4.6)

**Chat City** is a procedural city on its own island, shown in an isometric view inspired by Voxurbis.
There is no gameplay: you can only **navigate** and **zoom**.
It runs on desktop, mobile and in the browser (GL Compatibility renderer).

*(Screenshots: run the game with `-- --capture <folder>`, see Tests and tools.)*

## Controls

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

Then open **http://localhost:8080**. This is the fast multi-threaded build, rendered by your GPU through WebGL 2.

* **From a phone or another PC on your network:** open `http://<your-pc-ip>:8080/lite/`. Browsers only allow the multi-threaded build on `localhost` or HTTPS, so `/lite/` is a single-threaded build. It is slower, but works everywhere.
* **First build:** it downloads Godot (~60 MB) and its export templates (~1.25 GB). Docker caches both, so later builds only re-export the project (about 1 minute).
* **After you change the code:** run the same command again.
* **Stop:** `Ctrl+C`, or `docker compose down`.

### Run the automated checks

```
docker compose run --build --rm tests
```

This runs the generation test, the chunk benchmark and a top-down map. It also takes 10 screenshots of key places (downtown, hospital, school, stadium, city hall, suburbs, industry) without needing a GPU.
Everything is written to `./docker-out/` (`map.png`, `shot_0.png` ... `shot_9.png`). The screenshots use software rendering, so this step takes a few minutes.

### Files

```
docker-compose.yml     services "web" (port 8080) and "tests"
docker/Dockerfile      stages: godot -> project (import) -> tests | templates -> export -> web (nginx)
docker/nginx.conf      adds the COOP/COEP headers needed by the threaded web build
docker/run-tests.sh    what the tests container runs
export_presets.cfg     "Web" (threads) and "Web Lite" (no threads) presets
```

## The island

Chat City is a 288×288-cell map with one big **rounded island**. The city of the earlier versions sits a little south of the
middle **exactly as it was** (same seed, same streets and buildings); the countryside and the new districts surround it.
On screen north-west is up. Special buildings are kept far from each other on purpose.

| Where (on screen) | District | What you find |
| --- | --- | --- |
| centre-top | **Downtown** | the only skyscraper district: Kenney towers outside, photo towers in the middle, and 7 New York landmarks (Empire State, Chrysler, One WTC, Woolworth, New York Times, MetLife, Flatiron), drawn much taller than the Kenney towers |
| just behind downtown (north) | **Poor district** | a small district of grey panel towers and slabs, garages and corner shops, and the one big urban ghetto block |
| left of downtown | **Little Las Vegas** | casino palaces, neon towers, resorts, small bars, wedding chapels and clubs of every size, the cinema and the mall (a big supermarket) |
| west of Vegas | **West desert** | the secret base ("area 51": airbase with runway, hangar, tower and jets, bunker, radio station), mesas, ranches and oil pumps |
| south-west, between the desert and Vegas | **Industrial zone** | exactly 8 different buildings (concrete factory, brick works, ruin, garage and four Kenney factories) with a few yards of containers, barrels and trucks |
| centre | **Central park** | a large wood with a lake, a fountain and two crossing paths, ring roads all around |
| north-east of the park | **Mountain forest** | a forest with one tall snow-capped mountain in the middle |
| below the park | **Civic center** | the main city hall and the police headquarters (each on its own plot), bank (from the cartoon pack, with its sign), fire station, post office |
| right of the park | **United Nations** | the U.N. tower with its emblem (no text), on its own plot where everyone sees it |
| left of the park | **Shopping streets** | the main hospital, the shopping center, the pharmacy, two big hotels, New York street buildings, mini hotels, cartoon shops (burgers and pizzerias drawn extra big, pizzerias rare) |
| right / bottom | **Residential** | houses with gardens (Kenney, cartoon, French red and blue), the main school with its sports ground, the big church, the cemetery, gas stations |
| south | **Colourful quarter** | white and red low-rise town, bigger than before, mixed with French villas and colourful houses; the drive-in cinema, the construction crane, and by the beach the big ferris wheel and ice cream stalls |
| left | **Sports corner** | the big stadium (own plot, floodlit at night) |
| all around the city | **Farmland** | eight patches of crop fields (wheat, corn, plowed soil, green rows) with farms and country roads, spread over the whole island, none near the desert; forests and meadows between them |
| coast | **Beaches and rocky shores** | lighthouses and palm islets |
| far north-west, at sea | **Prison island** | a long rocky island far from the coast: a big cellhouse (no sign), stone blocks, a villa, a workshop, lighthouses |
| east, across the Golden Gate | **The fog island** | a second island hidden in a thick bank of fog and smoke. A three-lane highway leads to the bridge, closed by orange triangle barriers and cones. "ZONE UNLOCKED ON SEASON 2, COMING SOON" |

How it is built (`scripts/generation/`, one seed in `CityConfig.seed`, the same map on every device):

**1. The core city** (the original pipeline, on a 128×128 grid):

1. **`island_shaper.gd`**: an elliptical island with a little noise, sandy and rocky shores.
2. **`district_planner.gd`**: the district layout (anchors, hints and the park, mountain forest and big-building plots, in island units).
3. **`road_planner.gd`**: recursive splitting (BSP) into blocks. The borders of the park, the forest and the plots of the big buildings (stadium, mall, city hall, police HQ, U.N., main school, cemetery) are cut first, so they become ring roads. The first splits are avenues with street lights.
4. **`lot_planner.gd`**: blocks cut into lots, every building facing its street.
5. **`service_planner.gd`**: the big buildings fill their plots; every main public building once, in the block closest to its district, never two close together; then the small services of each district.
6. **`landmark_planner.gd`**: the park lake and paths, the mountain, the road to the bridge, the lighthouses.

**2. Everything around it** (`core_embed.gd`, `extension_island.gd`, `extension_planner.gd`):

7. **`core_embed.gd`** copies the finished core city into the 288×288 map.
8. **`extension_island.gd`** raises the big rounded island around it (the core keeps its own streets, shores and forests), plus palm islets and the prison island.
9. **`extension_planner.gd`** works only on free land: the three-lane highway to the bridge; the small poor district and the south part of the red quarter (BSP streets and lots); the desert with the base, the industrial zone, the farmland patches, forests, beach stalls and the prison compound. Everything is linked to the old city by the shortest road.
10. **`fog_island_shaper.gd`**: the island in the fog, placed right after the end of the highway.

Which family of models a building uses (Kenney, photo towers, New York, cartoon shops, the quarter...) is decided per district in `scripts/world/model_pools.gd`.

To move a district or change its size, edit `ANCHORS`, `PARK_AREA`, `FOREST_AREA`, `PLOTS` or `HINTS` in `district_planner.gd` (core city), or the rectangles at the top of `extension_planner.gd` and `MAIN` / `PRISON` in `extension_island.gd` (everything around).

### The fog island

East of Chat City, the Golden Gate bridge leaves the east coast and disappears into the fog (`scripts/world/fog_island.gd`).
The island itself lies next to the city map and costs very little: it is not streamed, it has no streets and it is drawn with a few MultiMeshes.
The fog is made of pictures, not 3D volumes:

* four sheets of drifting cloud texture at different heights (`shaders/fog_layer.gdshader`), whose holes open and close over the buildings;
* about 50 big painted billows and two smoke plumes on camera-facing quads (`shaders/fog_puff.gdshader`);
* the "SEASON 2" title, always on top.

The textures (`textures/fog_noise.png`, `fog_puffs.png`, `season2.png`) are drawn by `tools/make_fog_textures.py` from fractal noise.
At night the fog turns dark blue-grey and the night skyline model shows its city lights through it.

## Day and night

The city runs an automatic day and night cycle (`CityConfig.day_cycle_seconds`, 4 minutes by default; `scripts/world/day_night.gd`).
At night:

* Kenney windows glow. An emission mask is built from their colour palette, so only the glass lights up.
* The windows of the procedural buildings glow too.
* The buildings of the curated packs (New York, photo towers, stadium, coliseum, main public buildings...) are softly lit, like floodlit facades.
* The stadium has floodlight masts, the drive-in shows its film and lights its lot, the airbase lights its runway.
* The new packs (supermarket, bank, hotels, houses, factories, prison blocks...) are softly lit too.
* The red H and cross of the hospitals are neon, so they stay bright red.
* Street lamps get bulbs.
* Signs shine, and the neon stays bright.

No real lights are added, so night costs the same as day, on phones too.

## Signs

All signs are on one 1024×1024 texture, `textures/signs.png`:

* the U.N. emblem (the name is not used any more)
* the gold "$" coin (procedural bank, now only a fallback)
* neon "XXX", "CASINO", "BAR" and "CLUB"
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
| `panel_block` | 12-storey panel block | PANEL | some apartment lots |
| `quarter` | 100 low-poly buildings | QUARTER_LOW / MID / TALL | the colourful quarter (87 buildings) |
| `business` | low-poly business pack | BIZ_SHOP, CINEMA, MALL | diners and shops, the cinema, the shopping center |
| `outpost` | low-poly buildings | OUTPOST | the desert outpost |
| `police` | low-poly police station | POLICE | (kept; the same model as the main police station) |
| `stadium` | low-poly stadium (+ its pitch) | STADIUM | the stadium |
| `public_main` | low-poly public buildings pack | POLICE_MAIN, CITY_HALL_MAIN, HOSPITAL_MAIN, SCHOOL_MAIN, PHARMACY, GAS_STATION | the main public buildings, one of each, drawn big |
| `un_tower` | building 3 | UN_TOWER | the United Nations tower |
| `crane` | building crane | CRANE | one crane in the colourful quarter |
| `golden_gate` | Golden Gate bridge | BRIDGE | the bridge to the fog island |
| `night_skyline` | low-poly night city skyline (keeps its light map) | SKYLINE | the hidden city of the fog island |
| `carto` | CartoCity pack | MEGA_MALL, BANK_PACK, HOUSE2, TOWN2, SHOP2, HOTEL_SMALL, BARRIER, CONE, TRUCK, CONTAINER, BARREL | the supermarket (the mall), the bank, colourful houses and shops, mini hotels, the orange barriers and cones of the bridge, industrial props |
| `france` | 15 low-poly buildings (cut by position) | HOUSE2, MANSION, PRISON_BLOCK | French red and blue houses, stone blocks and villas of the prison island |
| `accommodations` | low poly accommodations buildings | HOTEL_PACK, HOUSE2, TOWN2 | the two big hotels, villas, small apartment blocks |
| `free_mini` | free low-poly buildings (cut by position) | CHURCH_PACK, GAS_PACK, SHOP2, HOTEL_SMALL, TOWN2 | the big church, a gas station, bars, boutiques, mini hotels |
| `street` | low-poly city street buildings | SHOP2, STALL | textured shop blocks, ice cream stalls and food trucks |
| `euro` | somewhat low-poly buildings | TOWN2, HOUSE2, WAREHOUSE, FACTORY, FIELD | tall town houses, a garage, the brick works, a crop field |
| `poor` | buildings pack (cut by position) | POOR_SLAB, POOR_BLOCK | grey panel towers and slabs of the poor district |
| `russian` | Russian building | RUSSIAN | the one big urban ghetto block |
| `industrial` | low-poly industrial building | FACTORY, RUIN | the concrete factory (industrial zone) |

Three packs (`france`, `free_mini`, `poor`) store one object per material for the whole town, so `curate_models.gd` can cut them with a `"region": [x0, z0, x1, z1]` rectangle (world space, optional `ymin` / `ymax`) instead of a node name.
Pizzerias of the business pack are their own category (BIZ_PIZZA) and stay rare.

Not used:

* **Kit parts, not whole buildings**: buildings pack, European asset pack, European facades, `building.glb`.
* **Duplicate**: the school (the procedural school is used).
* **Licence not confirmed**: Half-Life 2 buildings.
* **Skipped on request**: the neon woman sign.
* **Not placed**: the train station and the gym of the CartoCity pack, the police car and solid roadblocks (removed on request), the museums of the European pack (the museum was replaced by the U.N.).

### Credits of the latest models

* "Golden Gate Bridge" by JuanG3D, CC BY 4.0
* "building 3" by geniusrahman155, CC BY 4.0
* "Low Poly Night City Building Skyline" by 99.Miles, CC BY 4.0
* "Building Crane (low poly)" by jmarco2000, CC BY 4.0
* "Low Poly City | CartoCity Pack | Cartoonsih City" by DevPoly3D, CC BY 4.0
* "Pack - Low Poly - 15 Building" by Islide, CC BY 4.0
* "[Free] Buildings Low Poly" by GraphOrigin, CC BY 4.0
* "Somewhat Low-poly Buildings" by Calne, CC BY 4.0
* "Low-Poly City Street Buildings Asset Pack" by treasureimpact, CC BY 4.0
* "Buildings Pack" by maxk3, CC BY 4.0
* "Russian Building 4k texture low-poly game model" by BlackMonolith, CC BY 4.0
* "Low poly public buildings pack" and "Low poly accommodations buildings" by assetfactory, and "Low-Poly Industrial Building" by FlunkedPunk: Sketchfab Standard licence. They may be used in the game, but the raw files must not be shared on their own, so they are kept out of git; only the curated copies the game needs are committed.

All from sketchfab.com. CC BY 4.0 needs this credit wherever the game is shown.
The raw files of the two latest waves are not in the repository either (they are heavy):
put them back in `FREEMODELS/_incoming/` to rebuild the curated packs.

**Rebuild after changing the spec** (needs a display, or `xvfb-run` on Linux):

```
godot --rendering-driver opengl3 --script res://tools/curate_models.gd                # all packs
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
                                  extension_island, extension_planner, fog_island_shaper
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

```
godot --headless --import                                         # first import of the models
godot --headless --script res://tests/test_generation.gd          # generation smoke test
godot --headless --script res://tests/debug_map.gd -- map.png     # top-down zoning map
godot --headless --script res://tests/bench_chunks.gd             # chunk build cost / draw calls
godot -- --capture <dir>                                          # screenshots of key places
```
