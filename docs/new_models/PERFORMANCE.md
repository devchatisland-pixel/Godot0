# Start-up and model weight report

Measured on the web build (Chrome, visible tab, localhost) and natively in Docker.

## What changed at start

| Step | Before | After |
|---|---|---|
| Download (`index.pck`) | 89.8 MB | 18.2 MB |
| Engine started | 22.3 s | 5.4 s |
| City ready | 61.9 s (generated, 36 s) | 9.1 s (read in 0.4 s) |
| City on screen | **70.0 s** | **17.9 s** |
| First view complete | later still | 23.3 s |

How:

- **Baked city** (`baked/city.bin`, 226 KB): the seed is fixed, so the city, its vehicle and prop
  plans are generated once when the image is built (`tools/bake.gd`), not at every start.
- **Baked model library** (`baked/models.res`, 8 MB): every model file loaded and merged once,
  procedural meshes included. Meshes the map never draws are saved empty (126 of 395). Drawn
  models lose tangents, second UVs and normal/roughness/metal/AO maps, and are compressed
  (vertex data 44 MB → 19 MB).
- **Baked chunk lists** (`baked/chunks.bin`, 239 KB): what every 32-cell chunk draws.
- **Export**: the 575 model files and textures the baked library does not use are left out;
  textures are lossy WebP, the ones extracted from vehicles, shops and props at most 256 px.
- **Server**: the engine is gzipped once at build (`gzip_static`), the pck is sent as it is.
- **Start zoom** 62 → 32: 12 chunks to build instead of 24.
- **Fog island**: half its trees (it held 20 % of the triangles of the map, under the fog).

Nothing changes when you run the project without the bake: the game then generates and loads
as before. The bake is redone by every Docker build, so it always matches the code.

## Where the time still goes (after)

- About 7 s to read the model library in the browser: half texture decoding (222 textures,
  20.6 Mpx), half mesh data.
- About 5 s between "city on screen" and "first view complete": the browser compiles the shaders
  of every new material the first time it is drawn.
- The map size is not a problem: no need to shrink the islands.

## The sheets (to choose what to keep)

In `docs/new_models/themes/`, one thumbnail per model with its cost:

- `perf-1-most-triangles-drawn.png`: triangles × number of uses. The top: `accommodations: flat8`
  (4.9k × 41 = 200k), road straight (192k), wooden fences (88 × 2003 = 176k), Kenney trees
  (140k each), Kenney `building-n` (4.4k × 28), `poor: slab` (3.1k × 36), `building-k`, and the
  mustard sedan (5.3k × 16 = 85k: the m8 cars are 5–6k triangles each).
- `perf-2-heaviest-models.png`: one model. Pac-Man sign 27.4k (plus its glow copy), coffee shops
  of the dev island 17.3k and 12.4k, `flat10` 16.1k (2 uses), Rosomak 14.2k, F-111 jets 11.8k × 4,
  school, concert stage, gas station 11–12k.
- `perf-3-heaviest-textures.png`: pixels of the textures of a model. The futuristic towers share
  two 1024 px atlases; the nuclear plant and the metal bridge use four 512 px textures each.
  Shared atlases count for every model that uses them.

Cheapest wins if you want more: the m8 cars (or fewer of them), `flat8`/`flat10`, the Pac-Man
sign, the coffee shops, and a lighter fence model.

Tools: `tools/profile_startup.gd` (timings), `tools/heavy_models.gd` + `tools/heavy_models.py`
(these sheets), `tools/poly_heatmap.gd` (triangles per chunk).
