# Shop catalog

15 shop models, imported for later use. **Nothing here is wired into the map or `builder.gd`** - each shop has a model (`models/shops/`) and a ready-made `Structure` resource (`structures/shops/`, placeholder `price = 100`) you can drag into the Builder's `structures` array when you want it.

![Shop catalog](CATALOG.png)

Preview them all in the editor: open `scenes/shop_catalog.tscn` (shops are auto-scaled to ~1 tile and labelled). Machine-readable data: [`catalog.json`](catalog.json).

> Categories, names and sub-models are derived from the files' titles, node and material names - not from looking at renders. Confirm visually in the preview scene.

## Overview

| # | ID | Category | Name | Tris | Size (x,y,z) | 1-tile scale | Author | License |
|---|---|---|---|---:|---|---:|---|---|
| 1 | `shop-candy-a` | Candy | Candy Shop (canopy) | 1,895 | 5.04 x 5.466 x 4.406 | 0.1984 | Ivan Norman | CC-BY-4.0 |
| 2 | `shop-candy-b` | Candy | Low Poly Candy Shop | 1,363 | 6.098 x 5.47 x 4.237 | 0.164 | Anggo Ari Wibowo | CC-BY-4.0 |
| 3 | `shop-coffee-a` | Coffee | Coffee Shop (stall) | 17,333 | 20.5 x 6.018 x 9.599 | 0.0488 | mohdrafey2207 | CC-BY-4.0 |
| 4 | `shop-flower-a` | Flower | Flower Shop (game asset) | 9,261 | 4.05 x 2.457 x 6.269 | 0.1595 | maloy02 | CC-BY-4.0 |
| 5 | `shop-convenience-quickstop` | Convenience | Jay and Silent Bob Quick Stop | 64,834 | 10.264 x 6.213 x 12.015 | 0.0832 | Kris Kovac | CC-BY-4.0 |
| 6 | `shop-general-orange-a` | General | Low Poly Shop (orange awning) | 1,789 | 3.894 x 3.335 x 7.665 | 0.1304 | Virginia Vidonis | CC-BY-4.0 |
| 7 | `shop-general-orange-b` | General | 2nd Low Poly Shop (orange awning) | 1,799 | 4.372 x 3.307 x 5.89 | 0.1698 | Virginia Vidonis | CC-BY-4.0 |
| 8 | `shop-general-generic` | General | Low Poly Generic Shop | 5,026 | 3.694 x 2.645 x 2.488 | 0.2707 | assetfactory | SKETCHFAB Standard |
| 9 | `shop-general-brick` | General | Low Poly Shop (brick, balcony) | 6,002 | 7.253 x 2.096 x 7.253 | 0.1379 | Natisis94 | CC-BY-4.0 |
| 10 | `shop-general-mini` | General | Low-Poly Shop (mini) | 1,362 | 0.17 x 0.079 x 0.151 | 5.8824 | reginald7 | CC-BY-4.0 |
| 11 | `shop-townhouse-gabled` | Townhouse | Shop (gabled townhouse) | 170 | 2.297 x 2.48 x 2.741 | 0.3648 | linus1178 | CC-BY-4.0 |
| 12 | `shop-steel-glass` | General | Shop (steel & glass) | 448 | 3.91 x 3.415 x 4.9 | 0.2041 | bystryakov.yuriy | CC-BY-4.0 |
| 13 | `shop-coffee-b` | Coffee | Shop - Free model (coffee shop) | 12,366 | 8.048 x 6.861 x 8.913 | 0.1122 | Astro0960 | CC-BY-4.0 |
| 14 | `shop-townhouse-belgium` | Townhouse | Nivelles Shop 1 (Belgium) | 543 | 8.005 x 12.514 x 9.3 | 0.1075 | Lost Gecko | CC-BY-4.0 |
| 15 | `shop-building-multi` | Building | Building (multi-part cubes) | 1,060 | 6.838 x 6.748 x 4.501 | 0.1462 | Codracer13 | CC-BY-4.0 |

*1-tile scale* = uniform scale that makes the model's longest ground side 1.0, matching the kit's 1x1 tiles (e.g. `building-small-a` is 1 x 0.95 x 1, centred on origin, base on y=0).

## By category

- **Candy**: `shop-candy-a`, `shop-candy-b`
- **Coffee**: `shop-coffee-a`, `shop-coffee-b`
- **Flower**: `shop-flower-a`
- **Convenience**: `shop-convenience-quickstop`
- **General**: `shop-general-orange-a`, `shop-general-orange-b`, `shop-general-generic`, `shop-general-brick`, `shop-general-mini`, `shop-steel-glass`
- **Townhouse**: `shop-townhouse-gabled`, `shop-townhouse-belgium`
- **Building**: `shop-building-multi`

## Details

### Candy Shop (canopy) - `shop-candy-a`

- **Category:** Candy
- **Model:** `res://models/shops/shop-candy-a.glb` (original: `candy_shop.glb`)
- **Structure resource:** `res://structures/shops/shop-candy-a.tres`
- **Stats:** 1,895 tris, 10 meshes, 9 materials, size 5.04 x 5.466 x 4.406, bbox y -0..5.466
- **Notes:** Ice-cream/candy stall with pink & yellow canopy.
- **Front faces (native axes):** +X
- **Credit:** "Candy Shop" by Ivan Norman - CC-BY-4.0 - https://sketchfab.com/3d-models/candy-shop-51411d40093346b8ac1b6d1224fd8b25
- **Sub-models (node groups):** `Object`
- **Materials:** `Canopy_pink`, `Canopy_yellow`, `Glass`, `Ice_cream_cup_1`, `Ice_cream_cup_2`, `Orange`, `Pink`, `Violet`, `White`

### Low Poly Candy Shop - `shop-candy-b`

- **Category:** Candy
- **Model:** `res://models/shops/shop-candy-b.glb` (original: `low_poly_candy_shop.glb`)
- **Structure resource:** `res://structures/shops/shop-candy-b.tres`
- **Stats:** 1,363 tris, 16 meshes, 16 materials, size 6.098 x 5.47 x 4.237, bbox y -1.715..3.755
- **Notes:** Candy shop with candy_1 prop; origin is off-centre (bbox x -2.3..3.8).
- **Front faces (native axes):** +Z
- **Credit:** "Low Poly Candy Shop" by Anggo Ari Wibowo - CC-BY-4.0 - https://sketchfab.com/3d-models/low-poly-candy-shop-d9cd96eb8e2249eea112d7f9b13e3425
- **Sub-models (node groups):** `Cube`, `Cube.001`, `Cube.002`, `Cylinder`, `Cylinder.002`, `Cylinder.003`, `Circle`, `Cube.003`
- **Materials:** `Material.014`, `Material.006`, `Material.007`, `candy_1`, `Material`, `Material.001`, `Material.002`, `Material.005`, `Material.013`, `Material.003`, `Material.004`, `Material.012`, `Material.008`, `Material.009`, `Material.010`, `Material.011`

### Coffee Shop (stall) - `shop-coffee-a`

- **Category:** Coffee
- **Model:** `res://models/shops/shop-coffee-a.glb` (original: `coffee_shop.glb`)
- **Structure resource:** `res://structures/shops/shop-coffee-a.tres`
- **Stats:** 17,333 tris, 30 meshes, 21 materials, size 20.5 x 6.018 x 9.599, bbox y -0.018..6
- **Notes:** Coffee stall between two dark blocks. The original 70x70 ground plane (mesh Object_20) was removed from this copy; bbox is now 20.5 x 6 x 9.6.
- **Front faces (native axes):** +Z
- **Credit:** "Coffee Shop" by mohdrafey2207 - CC-BY-4.0 - https://sketchfab.com/3d-models/coffee-shop-fa7e884d363847619f89f8ee21fa8742
- **Sub-models (node groups):** `Cube`, `Object`, `Cube.004`, `Plane`, `Cylinder`, `Cylinder.001`, `Cube.001`, `Cube.002`, `Cube.003`, `Cube.005`, `Cube.006`, `Cube.007`, `Cube.008`, `Cube.009`, `Cube.010`, `Cube.011`
- **Materials:** `material_0`, `Material.003`, `Material.009`, `Material.001`, `Material.002`, `Material.013`, `Material.004`, `Material.008`, `Material.005`, `Material.006`, `Material.007`, `Material.011`, `Material.010`, `Material.012`, `Material.023`, `Material.014`, `gOLD`, `Material.022`, `Material.020`, `Material.024` ... (+1)

### Flower Shop (game asset) - `shop-flower-a`

- **Category:** Flower
- **Model:** `res://models/shops/shop-flower-a.glb` (original: `flower_shop_-_game_asset.glb`)
- **Structure resource:** `res://structures/shops/shop-flower-a.tres`
- **Stats:** 9,261 tris, 255 meshes, 17 materials, size 4.05 x 2.457 x 6.269, bbox y -0.012..2.445
- **Notes:** 255 small meshes (plants/flowers). Contains a Camera node and a pavement mesh.
- **Front faces (native axes):** +X
- **Credit:** "Flower Shop - Game Asset" by maloy02 - CC-BY-4.0 - https://sketchfab.com/3d-models/flower-shop-game-asset-f1eaee257ef5422eb896a08541b4e821
- **Sub-models (node groups):** `Object`, `Icosfera`, `Icosfera.001_verde.001`, `Icosfera.002_verde.001`, `Icosfera.003_verde.001`, `Icosfera.004_verde.001`, `Icosfera.005_verde.001`, `Icosfera.006_verde.001`, `Icosfera.007_verde.001`, `Icosfera.008_verde.001`, `Icosfera.009_verde.001`, `Icosfera.010_verde.001`, `Icosfera.011_verde.001`, `Icosfera.012_verde.001`
- **Materials:** `.183__0`, `casa`, `grigio`, `pavimento`, `marrone_terra`, `marrone.001`, `bianco.002`, `blu1`, `material`, `verde.001`, `verde.002`, `giallo`, `marrone_terra.001`, `bianco.001`, `marrone`, `marrone_chiaro`, `nero`

### Jay and Silent Bob Quick Stop - `shop-convenience-quickstop`

- **Category:** Convenience
- **Model:** `res://models/shops/shop-convenience-quickstop.glb` (original: `jay_and_silent_bob_quick_stop.glb`)
- **Structure resource:** `res://structures/shops/shop-convenience-quickstop.tres`
- **Stats:** 64,834 tris, 84 meshes, 54 materials, size 10.264 x 6.213 x 12.015, bbox y 0.624..6.838
- **Notes:** Biggest file (6.3 MB, 65k tris). Includes asphalt slab + parked car; origin far from 0 (x 2..12). Heavy for a city tile.
- **Front faces (native axes):** +X
- **Credit:** "Jay And Silent Bob Quick Stop" by Kris Kovac - CC-BY-4.0 - https://sketchfab.com/3d-models/jay-and-silent-bob-quick-stop-49e19755f4ae4688b9b07c82cf4e0699
- **Sub-models (node groups):** `asfalt`, `Object`, `Car`, `Cylinder.022`, `Cylinder.031`, `Cylinder.032`, `Cylinder.026`, `Plane.003`, `Plane.001`, `Plane.005`, `Zatvor2`, `Zatvor.001`, `Zatvor`, `ELEK`, `pLAKAT2`, `Cylinder.192`, `Krisha`, `Vitrina2`, `Steklo4`, `Magazin`, `Cube.029`, `Cube.031`, `Konder`, `Plakat`, `Cube.036`, `Viveska3`, `musorka`, `Zatvor2.001`, `Plakat.001`
- **Materials:** `material`, `material_1`, `material_2`, `material_3`, `material_4`, `material_5`, `Material.006`, `Chrome`, `material_8`, `material_9`, `material_10`, `material_11`, `material_12`, `listva3`, `listva02`, `material_15`, `zamok`, `material_17`, `trava`, `listva` ... (+34)

### Low Poly Shop (orange awning) - `shop-general-orange-a`

- **Category:** General
- **Model:** `res://models/shops/shop-general-orange-a.glb` (original: `low_poly_shop.glb`)
- **Structure resource:** `res://structures/shops/shop-general-orange-a.tres`
- **Stats:** 1,789 tris, 35 meshes, 14 materials, size 3.894 x 3.335 x 7.665, bbox y 0.002..3.337
- **Notes:** Same author/style as shop-general-orange-b. Italian node names.
- **Front faces (native axes):** -X
- **Credit:** "Low Poly Shop" by Virginia Vidonis - CC-BY-4.0 - https://sketchfab.com/3d-models/low-poly-shop-0013cf5979c846449c817a2439fd8705
- **Sub-models (node groups):** `base`, `base.001_base`, `tetto`, `tetto_casa base`, `casa base`, `casa base_casa base`, `finestra frontale sx`, `finestra frontale sx_porta e serramenti`, `finestra frontale sx_vetri`, `finestra facciata dx`, `finestra facciata dx_porta e serramenti`, `finestra facciata dx_vetri`, `finestra dx`, `finestra dx_vetri`, `finestra dx_porta e serramenti`, `finestra sx`, `finestra sx_vetri`, `finestra sx_porta e serramenti`, `porta`, `porta_porta e serramenti`, `porta_vetri`, `tenda frontale`, `tenda frontale_bianco`, `tenda frontale_porta e serramenti`, `tenda frontale.001_bianco`, `tenda frontale.001_porta e serramenti`, `tenda frontale piccola`, `tenda frontale piccola_bianco`, `tenda frontale piccola_porta e serramenti`, `tenda frontale facciata dx` ... (+22 more)
- **Materials:** `base`, `casa_base`, `porta_e_serramenti`, `vetri`, `bianco`, `nero`, `base_condizionatore`, `tubo`, `CESPUGLI`, `VASI`, `TERRA`, `CESPUGLI.001`, `VASI.002`, `TERRA.002`

### 2nd Low Poly Shop (orange awning) - `shop-general-orange-b`

- **Category:** General
- **Model:** `res://models/shops/shop-general-orange-b.glb` (original: `2nd__low_poly_shop.glb`)
- **Structure resource:** `res://structures/shops/shop-general-orange-b.tres`
- **Stats:** 1,799 tris, 22 meshes, 12 materials, size 4.372 x 3.307 x 5.89, bbox y -0.001..3.306
- **Notes:** Variant of shop-general-orange-a (adds AC unit, plants, extra awnings).
- **Front faces (native axes):** -X
- **Credit:** "2nd  Low Poly Shop" by Virginia Vidonis - CC-BY-4.0 - https://sketchfab.com/3d-models/2nd-low-poly-shop-bc65e31bcdd24d2392e7ea4babebcdc2
- **Sub-models (node groups):** `base`, `base_vasi`, `porta`, `porta_arancio`, `tetto`, `tetto_arancio`, `casa base`, `casa base_casa base.001`, `casa base_arancio`, `base.002_base condizionatore.001`, `base tubo`, `base tubo.001_tubo.001`, `cassetta`, `cassetta.001_bianco.003`, `cassetta.001_nero.001`, `tubo`, `tubo.001_tubo.001`, `Cylinder`, `Cylinder_nero.002`, `tenda frontale`, `tenda frontale.001_bianco`, `tenda frontale.001_arancio`, `tenda frontale piccola`, `tenda frontale piccola_arancio`, `tenda frontale piccola_bianco`, `vetri porta`, `vetri porta_vetri`, `vetro dx`, `vetro dx_vetri`, `vetro facciata sxx` ... (+8 more)
- **Materials:** `vasi`, `arancio`, `casa_base.001`, `base_condizionatore.001`, `tubo.001`, `bianco.003`, `nero.001`, `nero.002`, `bianco`, `vetri`, `terra`, `foglie`

### Low Poly Generic Shop - `shop-general-generic`

- **Category:** General
- **Model:** `res://models/shops/shop-general-generic.glb` (original: `low_poly_generic_shop.glb`)
- **Structure resource:** `res://structures/shops/shop-general-generic.tres`
- **Stats:** 5,026 tris, 4 meshes, 2 materials, size 3.694 x 2.645 x 2.488, bbox y -0..2.645
- **Notes:** Single textured mesh 'ShopBuilding' + a Collider mesh (hide/remove Collider). License is Sketchfab Standard, not CC-BY.
- **Front faces (native axes):** +Z
- **Credit:** "Low poly generic shop" by assetfactory - SKETCHFAB Standard - https://sketchfab.com/3d-models/low-poly-generic-shop-58797c167b834d7ab982afa82f693415
- **Sub-models (node groups):** `ShopBuilding`, `ShopBuilding_Texture_buildings1`, `ShopBuilding.001_Texture_buildings1`, `ShopBuilding.002_Texture_buildings1`, `Collider`, `Collider_Collider`
- **Materials:** `Texture_buildings1`, `Collider`

### Low Poly Shop (brick, balcony) - `shop-general-brick`

- **Category:** General
- **Model:** `res://models/shops/shop-general-brick.glb` (original: `low_poly_shop (1).glb`)
- **Structure resource:** `res://structures/shops/shop-general-brick.tres`
- **Stats:** 6,002 tris, 13 meshes, 13 materials, size 7.253 x 2.096 x 7.253, bbox y -0.098..1.998
- **Notes:** Brick shop with balcony on a large white ground plane (remove it); contains Camera, Sun, Plane, Text nodes.
- **Front faces (native axes):** +Z
- **Credit:** "low poly shop" by Natisis94 - CC-BY-4.0 - https://sketchfab.com/3d-models/low-poly-shop-0c0665681ce6471c9393795e8a13fa88
- **Sub-models (node groups):** `Object`, `Cube`, `Cube_bricks`, `Cube_wall1`, `Cube_woods`, `Cube_orange wood`, `Cube_door`, `Cube_window`, `Cube_metal`, `Cube_Material.001`, `Cube_WHITE `, `Cube_balcony floor`, `Cube_airhole`, `Plane`, `Plane_`, `Text`, `Text_Material.005`
- **Materials:** `Plane__0`, `bricks`, `wall1`, `woods`, `orange_wood`, `door`, `window`, `metal`, `Material.001`, `WHITE`, `balcony_floor`, `airhole`, `Material.005`

### Low-Poly Shop (mini) - `shop-general-mini`

- **Category:** General
- **Model:** `res://models/shops/shop-general-mini.glb` (original: `low-poly_shop.glb`)
- **Structure resource:** `res://structures/shops/shop-general-mini.tres`
- **Stats:** 1,362 tris, 19 meshes, 13 materials, size 0.17 x 0.079 x 0.151, bbox y 0.004..0.082
- **Notes:** Corner shop with blue awning and glass front. Authored tiny: 0.17 units wide, needs ~6x scale-up just to be 1 tile.
- **Front faces (native axes):** +Z
- **Credit:** "Low-Poly Shop" by reginald7 - CC-BY-4.0 - https://sketchfab.com/3d-models/low-poly-shop-e41e8060496a4693a9f62f5a4dd5b252
- **Sub-models (node groups):** `pCube1`, `pCube1_lambert6`, `pCube1_lambert8`, `pCube1_lambert1`, `pCube1_lambert7`, `pCube1_lambert13`, `pCube1_lambert11`, `pCube1_lambert12`, `pCube1_lambert10`, `pCube1_lambert9`, `pCube3`, `pCube3_lambert5`, `pCube3_lambert4`, `pCube3_lambert3`, `pPlatonic1`, `pPlatonic1_lambert2`, `pPlatonic2`, `pPlatonic2_lambert2`, `pPlatonic3`, `pPlatonic3_lambert2`, `pPlatonic4`, `pPlatonic4_lambert2`, `pCube5`, `pCube5_lambert8`, `pCube5_lambert6`, `pCube5_lambert1`
- **Materials:** `lambert6`, `lambert8`, `lambert1`, `lambert7`, `lambert13`, `lambert11`, `lambert12`, `lambert10`, `lambert9`, `lambert5`, `lambert4`, `lambert3`, `lambert2`

### Shop (gabled townhouse) - `shop-townhouse-gabled`

- **Category:** Townhouse
- **Model:** `res://models/shops/shop-townhouse-gabled.glb` (original: `shop (1).glb`)
- **Structure resource:** `res://structures/shops/shop-townhouse-gabled.tres`
- **Stats:** 170 tris, 1 meshes, 1 materials, size 2.297 x 2.48 x 2.741, bbox y 0..2.48
- **Notes:** Step-gabled house with red roof and hanging SHOP sign. 170 tris, single material - cheapest model.
- **Front faces (native axes):** +Z
- **Credit:** "shop" by linus1178 - CC-BY-4.0 - https://sketchfab.com/3d-models/shop-e89a9be0af324355b85278feb4f9da8f
- **Sub-models (node groups):** `shop`, `Object`
- **Materials:** `Material`

### Shop (steel & glass) - `shop-steel-glass`

- **Category:** General
- **Model:** `res://models/shops/shop-steel-glass.glb` (original: `shop.glb`)
- **Structure resource:** `res://structures/shops/shop-steel-glass.tres`
- **Stats:** 448 tris, 6 meshes, 6 materials, size 3.91 x 3.415 x 4.9, bbox y -1.608..1.807
- **Notes:** Grey flat roof, glass front, red louvres/shutters. Pivot is centred vertically (y -1.6..1.8): needs lifting to sit on ground.
- **Front faces (native axes):** -X
- **Credit:** "Shop" by bystryakov.yuriy - CC-BY-4.0 - https://sketchfab.com/3d-models/shop-23e3cdb766bd40ac9c63fddfd2d39856
- **Sub-models (node groups):** `SHOP`, `Object`
- **Materials:** `W_plast`, `R_steel`, `Gr_steel`, `Glass`, `Bord`, `Wall`

### Shop - Free model (coffee shop) - `shop-coffee-b`

- **Category:** Coffee
- **Model:** `res://models/shops/shop-coffee-b.glb` (original: `shop_-_free_model.glb`)
- **Structure resource:** `res://structures/shops/shop-coffee-b.tres`
- **Stats:** 12,366 tris, 28 meshes, 10 materials, size 8.048 x 6.861 x 8.913, bbox y 0.677..7.539
- **Notes:** Coffee shop with cup + COFFEE sign on roof, lamp post, fence, on a dark base slab. 12k tris; floats at y 0.68 min.
- **Front faces (native axes):** +Z
- **Credit:** "Shop - Free model" by Astro0960 - CC-BY-4.0 - https://sketchfab.com/3d-models/shop-free-model-a10e5b0977cc41c6b115a568ee18772b
- **Sub-models (node groups):** `Plane`, `Object`, `Plane.001`, `Plane.002`, `Plane.004`, `Circle`, `Circle.001`, `Plane.003`, `Text`, `Plane.005`, `Plane.006`, `Plane.007`, `Plane.008`, `Plane.011`, `Text.001`, `Plane.012`, `Text.002`, `Plane.013`, `Text.003`, `Plane.014`, `Text.004`, `Plane.015`, `Text.005`, `Plane.009`, `Plane.010`, `Circle.002`
- **Materials:** `material_0`, `Material.003`, `Material.005`, `Material.004`, `Material.007`, `Material.008`, `Material.009`, `Material.010`, `Material.006`, `Material.011`

### Nivelles Shop 1 (Belgium) - `shop-townhouse-belgium`

- **Category:** Townhouse
- **Model:** `res://models/shops/shop-townhouse-belgium.glb` (original: `nivelles_shop_1_belgium.glb`)
- **Structure resource:** `res://structures/shops/shop-townhouse-belgium.tres`
- **Stats:** 543 tris, 1 meshes, 1 materials, size 8.005 x 12.514 x 9.3, bbox y -0..12.514
- **Notes:** Tall grey townhouse, untextured single material, 543 tris, 12.5 tall.
- **Front faces (native axes):** +Z
- **Credit:** "Nivelles Shop 1 [Belgium]" by Lost Gecko - CC-BY-4.0 - https://sketchfab.com/3d-models/nivelles-shop-1-belgium-209c0097e5ab46fd8be7ca5d904479e9
- **Sub-models (node groups):** `MAIN`, `MAIN_main`
- **Materials:** `main`

### Building (multi-part cubes) - `shop-building-multi`

- **Category:** Building
- **Model:** `res://models/shops/shop-building-multi.glb` (original: `building (1).glb`)
- **Structure resource:** `res://structures/shops/shop-building-multi.tres`
- **Stats:** 1,060 tris, 36 meshes, 19 materials, size 6.838 x 6.748 x 4.501, bbox y -2.851..3.897
- **Notes:** Pink/grey multi-storey building with striped awning and green base. 36 Cube meshes, 19 materials; pivot centred (y -2.85..3.9).
- **Front faces (native axes):** +X
- **Credit:** "Building" by Codracer13 - CC-BY-4.0 - https://sketchfab.com/3d-models/building-6f57edbc41024402ac4035b6b89661e5
- **Sub-models (node groups):** `Cube`, `Lamp`
- **Materials:** `Material.009`, `Material.006`, `Material.011`, `Material.004`, `Material.005`, `Material.002`, `Material.003`, `Material.001`, `Material.008`, `Material.007`, `Material.012`, `Material.013`, `Material.014`, `Material.015`, `Material.016`, `Material.017`, `Material.018`, `Material.019`, `Material.020`
