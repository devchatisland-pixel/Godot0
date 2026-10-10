# All models inventory

Everything found as a `.glb`: the Downloads folder (92 files) and the project repo (383 GLB files). Documentation only; nothing was moved, imported or changed.

Companion catalogs: [misc props](CATALOG.md), [beach](beach/CATALOG.md), [military](military/CATALOG.md), [city street pack](city_street_pack/CATALOG.md). Existing project catalogs: `vehicles/CATALOG.md`, `shops/CATALOG.md`.

Machine-readable data: [`all_models.json`](all_models.json). Chart of the heaviest models: [`heaviest_models.png`](heaviest_models.png).

## How "heavy" is measured

- **Tris**: triangle count over all meshes. Flagged at 100,000 or more.
- **Tex VRAM**: decoded memory of every embedded image (including unused PBR maps), estimated as width x height x 4 bytes x 1.33 (mipmaps), summed over embedded images. Flagged at 64 MB or more. It is what the GPU pays, not the download size.
- **File**: size of the .glb on disk. Flagged at 15 MB or more.
- **Score** = tris/100k + VRAM/64 MB + file/15 MB. Higher means more expensive; use it for ranking only.

## Summary

- Downloads: 92 GLBs, 440.2 MB total, 2,582,818 triangles.
- Heavy (at least one flag) in Downloads: 17.
- Exact duplicates inside Downloads: 4 groups (see below).
- Downloads files with no identical copy in the repo and not referenced by a curate spec: 57.

## Heaviest models in Downloads (avoid or decimate)

| # | File | Tris | Tex VRAM | Max tex | File MB | Flags | Status |
|---|---|---|---|---|---|---|---|
| 1 | `ibis150_air_defense_radar.glb` | 369,115 | 16.0 MB | 1024 | 19.9 | tris, file | **not in repo** |
| 2 | `low_poly_city__cartocity_pack__cartoonsih_city.glb` | 15,618 | 191.2 MB | 1024 | 27.5 | textures, file | **not in repo** |
| 3 | `city_buildings_-_blackthornprod_video.glb` | 2,648 | 164.9 MB | 1024 | 27.1 | textures, file | **not in repo** |
| 4 | `lowpoly_city_street_pack_buildings_stylized.glb` | 73,045 | 118.8 MB | 1024 | 10.1 | textures | **not in repo** |
| 5 | `tent_14_mb.glb` | 188,490 | 31.9 MB | 1024 | 12.2 | tris | **not in repo** |
| 6 | `bus_stop_shelters__sign_pack__brisbane.glb` | 3,580 | 106.4 MB | 1024 | 20.2 | textures, file | curated into: bus_shelter |
| 7 | `uss_enterprise_cvn-65_aircraft_carrier.glb` | 73,321 | 57.5 MB | 1024 | 15.2 | file | **not in repo** |
| 8 | `european_building_facades.glb` | 34,192 | 85.1 MB | 2048 | 14.4 | textures | in repo (identical): european_building_facades.glb |
| 9 | `pack_-_low_poly_-_15_building.glb` | 85,313 | 46.5 MB | 1024 | 14.4 | - | **not in repo** |
| 10 | `city_pack_7.glb` | 30,331 | 82.2 MB | 1024 | 13.6 | textures | in repo (identical): city_pack_7.glb; curated into: towers_a |
| 11 | `new_york_buildings.glb` | 5,142 | 69.8 MB | 2048 | 19.5 | textures, file | in repo (identical): new_york_buildings.glb; curated into: ny_buildings |
| 12 | `low_poly_night_city_building_skyline.glb` | 6,076 | 106.4 MB | 2048 | 9.5 | textures | in repo (identical): night_city_skyline.glb; curated into: night_skyline |
| 13 | `city_pack_8.glb` | 35,096 | 73.4 MB | 1024 | 12.7 | textures | in repo (identical): city_pack_8.glb; curated into: towers_b |
| 14 | `54_vehicle_pack.glb` | 52,849 | 68.8 MB | 512 | 9.8 | textures | **not in repo** |
| 15 | `buildings_pack.glb` | 51,191 | 65.8 MB | 4096 | 8.1 | textures | in repo (identical): buildings_pack.glb |
| 16 | `xxx_neon_sign.glb` | 76,268 | 58.5 MB | 1024 | 4.9 | - | **not in repo** |
| 17 | `golden_gate_bridge (1).glb` | 159,902 | 0.0 MB | - | 3.9 | tris | in repo (identical): golden_gate_bridge.glb |
| 18 | `golden_gate_bridge.glb` | 159,902 | 0.0 MB | - | 3.9 | tris | in repo (identical): golden_gate_bridge.glb |
| 19 | `low-poly_city_street_buildings_asset_pack (1).glb` | 19,247 | 55.9 MB | 1024 | 9.1 | - | **not in repo** |
| 20 | `low-poly_city_street_buildings_asset_pack.glb` | 19,247 | 55.9 MB | 1024 | 9.1 | - | **not in repo** |
| 21 | `100_lowpoly_buildings__buildings_pack.glb` | 110,420 | 0.0 MB | - | 6.2 | tris | in repo (identical): 100_lowpoly_buildings__buildings_pack.glb; curated into: quarter |
| 22 | `detailed_12_storey_panel_apartment_building.glb` | 3,434 | 48.5 MB | 2048 | 9.1 | - | in repo (identical): detailed_12_storey_panel_apartment_building.glb |
| 23 | `low_poly_accommodations_buildings.glb` | 97,204 | 0.3 MB | 256 | 5.6 | - | **not in repo** |
| 24 | `jungle_tent.glb` | 958 | 63.8 MB | 1024 | 4.3 | - | **not in repo** |
| 25 | `european_buildings_asset_pack_1.glb` | 19,129 | 36.7 MB | 2048 | 6.1 | - | in repo (identical): european_buildings_asset_pack_1.glb |

## Downloads folder: all 92 GLBs

| File | Title | Tris | Meshes | Mats | Tex VRAM | Max tex | File MB | Anim | License | Author | Flags | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `100_lowpoly_buildings__buildings_pack.glb` | 100 Lowpoly Buildings / Buildings Pack | 110,420 | 389 | 4 | 0.0 MB | - | 6.2 | - | CC-BY-4.0 | Fridqeir | tris | in repo (identical): 100_lowpoly_buildings__buildings_pack.glb; curated into: quarter |
| `54_vehicle_pack.glb` | 54 Vehicle Pack | 52,849 | 59 | 59 | 68.8 MB | 512 | 9.8 | - | CC-BY-4.0 | PorscheAaron | textures | **not in repo** |
| `beach_ball_-_low_poly.glb` | Beach Ball - Low Poly | 216 | 1 | 1 | 16.0 MB | 1024 | 0.6 | - | CC-BY-4.0 | raduursache9 | - | **not in repo** |
| `bridge to island 2.glb` | Stylised Low Poly - City Metal Bridge | 7,384 | 4 | 4 | 21.3 MB | 1024 | 2.6 | - | CC-BY-4.0 | remidoes3d | - | **not in repo** |
| `building.glb` | Building | 604 | 5 | 5 | 17.3 MB | 2048 | 1.8 | - | CC-BY-4.0 | Arif | - | in repo (identical): building.glb |
| `building_3.glb` | building 3 | 36 | 1 | 1 | 5.3 MB | 1024 | 0.4 | - | CC-BY-4.0 | geniusrahman155 | - | in repo (identical): building_3.glb; curated into: un_tower |
| `building_crane_low_poly.glb` | Building Crane (low poly) | 9,423 | 1 | 1 | 5.3 MB | 1024 | 1.4 | - | CC-BY-4.0 | jmarco2000 | - | in repo (identical): building_crane.glb; curated into: crane |
| `buildings.glb` | Buildings | 2,468 | 72 | 52 | 35.6 MB | 1024 | 6.8 | - | CC-BY-4.0 | Elbolillo | - | in repo (identical): buildings.glb; curated into: ny_street |
| `buildings_pack (1).glb` | Buildings Pack | 51,191 | 118 | 7 | 10.0 MB | 1024 | 4.4 | - | CC-BY-4.0 | maxk3 | - | **not in repo** |
| `buildings_pack.glb` | Buildings Pack | 51,191 | 118 | 7 | 65.8 MB | 4096 | 8.1 | - | CC-BY-4.0 | maxk3 | textures | in repo (identical): buildings_pack.glb |
| `bus_stop_shelters__sign_pack__brisbane.glb` | Bus Stop Shelters & Sign Pack / Brisbane | 3,580 | 17 | 7 | 106.4 MB | 1024 | 20.2 | - | SKETCHFAB Standard | Jotrain Models | textures, file | curated into: bus_shelter |
| `carrier.glb` | Carrier | 1,318 | 4 | 4 | 1.5 MB | 512 | 0.3 | - | CC-BY-4.0 | victorberdugo1 | - | **not in repo** |
| `ccf.glb` | CCF | 7,753 | 7 | 2 | 21.3 MB | 1024 | 2.0 | - | CC-BY-4.0 | ArcheoteryxFr | - | curated into: truck_ccf |
| `city_buildings_-_blackthornprod_video.glb` | City Buildings - BlackThornProd Video | 2,648 | 7 | 7 | 164.9 MB | 1024 | 27.1 | - | CC-BY-4.0 | Tiko | textures, file | **not in repo** |
| `city_pack_7.glb` | City pack 7 | 30,331 | 104 | 100 | 82.2 MB | 1024 | 13.6 | - | CC-BY-4.0 | Pasha | textures | in repo (identical): city_pack_7.glb; curated into: towers_a |
| `city_pack_8.glb` | City pack 8 | 35,096 | 105 | 100 | 73.4 MB | 1024 | 12.7 | - | CC-BY-4.0 | Pasha | textures | in repo (identical): city_pack_8.glb; curated into: towers_b |
| `coliseum_from_poly_by_google.glb` | Coliseum from Poly by Google | 24,154 | 2 | 1 | 0.0 MB | - | 1.4 | - | CC-BY-4.0 | IronEqual | - | in repo (identical): coliseum_from_poly_by_google.glb |
| `deck_chair.glb` | deck chair | 1,576 | 2 | 1 | 16.0 MB | 1024 | 1.7 | - | CC-BY-4.0 | MaX3Dd | - | **not in repo** |
| `detailed_12_storey_panel_apartment_building.glb` | Detailed 12 storey panel apartment building | 3,434 | 4 | 2 | 48.5 MB | 2048 | 9.1 | - | CC-BY-4.0 | bean(alwayshasbean) | - | in repo (identical): detailed_12_storey_panel_apartment_building.glb |
| `european_building_facades.glb` | European building facades | 34,192 | 19 | 5 | 85.1 MB | 2048 | 14.4 | - | CC-BY-4.0 | bean(alwayshasbean) | textures | in repo (identical): european_building_facades.glb |
| `european_buildings_asset_pack_1.glb` | European Buildings Asset Pack 1 | 19,129 | 764 | 95 | 36.7 MB | 2048 | 6.1 | - | CC-BY-4.0 | EddyNL | - | in repo (identical): european_buildings_asset_pack_1.glb |
| `fishing_boat_low_poly_style.glb` | Fishing Boat (low poly style) | 4,715 | 31 | 13 | 0.0 MB | - | 0.3 | - | SKETCHFAB Standard | liborv | - | curated into: boat_fishing |
| `free_buildings_low_poly.glb` | [Free] Buildings Low Poly | 44,569 | 44 | 44 | 0.0 MB | - | 2.7 | - | CC-BY-4.0 | GraphOrigin | - | **not in repo** |
| `golden_gate_bridge (1).glb` | Golden Gate Bridge | 159,902 | 2 | 1 | 0.0 MB | - | 3.9 | - | CC-BY-4.0 | JuanG3D | tris | in repo (identical): golden_gate_bridge.glb |
| `golden_gate_bridge.glb` | Golden Gate Bridge | 159,902 | 2 | 1 | 0.0 MB | - | 3.9 | - | CC-BY-4.0 | JuanG3D | tris | in repo (identical): golden_gate_bridge.glb |
| `half-life_2_-_complete_city-17_buildings.glb` | Half-life 2 - complete city-17 buildings | 4,930 | 3 | 3 | 8.0 MB | 1024 | 1.5 | - | CC-BY-NC-4.0 | Mason | - | **not in repo** |
| `highway.glb` | Highway | 2 | 1 | 1 | 0.7 MB | 512 | 0.1 | - | CC-BY-4.0 | Genkidonky | - | **not in repo** |
| `highway_road.glb` | Highway Road | 17,920 | 1 | 1 | 16.0 MB | 1024 | 4.5 | - | CC-BY-4.0 | miopass | - | **not in repo** |
| `hot_air_balloon_low_poly_optimized_game_ready.glb` | Hot Air Balloon Low Poly Optimized Game Ready | 258 | 1 | 1 | 0.3 MB | 256 | 0.0 | - | CC-BY-4.0 | shafieen | - | curated into: balloon |
| `hungry_jacks_restaurant_low_poly.glb` | Hungry Jack's Restaurant (low Poly) | 4,417 | 5 | 5 | 39.9 MB | 1024 | 2.9 | - | SKETCHFAB Standard | Jotrain Models | - | **not in repo** |
| `ibis150_air_defense_radar.glb` | IBIS150 air defense radar | 369,115 | 4 | 1 | 16.0 MB | 1024 | 19.9 | - | CC-BY-4.0 | 42manako | tris, file | **not in repo** |
| `japanese_police_car_low_poly.glb` | Japanese Police Car low poly | 8,446 | 18 | 11 | 5.3 MB | 1024 | 0.6 | - | CC-BY-4.0 | SPixy01 | - | **not in repo** |
| `jungle_tent.glb` | Jungle Tent | 958 | 7 | 4 | 63.8 MB | 1024 | 4.3 | - | CC-BY-4.0 | SyntheticMN | - | **not in repo** |
| `kto_rosomak_old_version.glb` | KTO Rosomak (old version) | 14,194 | 12 | 2 | 21.3 MB | 1024 | 4.4 | - | CC-BY-4.0 | Stachwel | - | **not in repo** |
| `low-poly-night-city-building-skyline.glb` | Low-poly-night-city-building-skyline | 6,076 | 1 | 1 | 26.6 MB | 1024 | 4.0 | - | CC-BY-4.0 | willis123 | - | **not in repo** |
| `low-poly_city_street_buildings_asset_pack (1).glb` | Low-Poly City Street Buildings Asset Pack | 19,247 | 30 | 20 | 55.9 MB | 1024 | 9.1 | - | CC-BY-4.0 | treasureimpact | - | **not in repo** |
| `low-poly_city_street_buildings_asset_pack.glb` | Low-Poly City Street Buildings Asset Pack | 19,247 | 30 | 20 | 55.9 MB | 1024 | 9.1 | - | CC-BY-4.0 | treasureimpact | - | **not in repo** |
| `low-poly_container.glb` | Low-poly Container | 192 | 16 | 8 | 42.6 MB | 1024 | 7.3 | - | CC-BY-4.0 | Muhammad Awais Gul | - | **not in repo** |
| `low-poly_industrial_building.glb` | Low-Poly Industrial Building | 11,566 | 5 | 5 | 1.0 MB | 256 | 1.0 | - | SKETCHFAB Standard | FlunkedPunk | - | **not in repo** |
| `low-poly_radar_dish.glb` | Low-Poly Radar Dish | 2,514 | 1 | 1 | 16.0 MB | 1024 | 3.0 | - | CC-BY-4.0 | joe_carrot | - | **not in repo** |
| `low-poly_tank.glb` | Low-poly tank | 1,636 | 13 | 5 | 0.0 MB | - | 0.1 | - | CC-BY-4.0 | Deyama | - | curated into: tank |
| `low_poly_accommodations_buildings.glb` | Low poly accommodations buildings | 97,204 | 20 | 2 | 0.3 MB | 256 | 5.6 | - | SKETCHFAB Standard | assetfactory | - | **not in repo** |
| `low_poly_billboard_sign_-_standard.glb` | Low Poly Billboard Sign - Standard | 340 | 2 | 2 | 8.0 MB | 1024 | 0.6 | - | CC-BY-4.0 | JeffK | - | curated into: billboard |
| `low_poly_bridge.glb` | Low Poly Bridge | 862 | 1 | 1 | 5.3 MB | 1024 | 0.4 | - | CC-BY-4.0 | brizarniko | - | **not in repo** |
| `low_poly_business_buildings_pack.glb` | Low poly business buildings pack | 70,706 | 17 | 2 | 0.3 MB | 256 | 4.2 | - | SKETCHFAB Standard | assetfactory | - | in repo (identical): low_poly_business_buildings_pack.glb; curated into: business |
| `low_poly_cargo_ship.glb` | Low Poly Cargo Ship | 2,384 | 1 | 1 | 16.0 MB | 1024 | 1.0 | - | CC-BY-4.0 | Javier_Fernandez | - | curated into: boat_cargo |
| `low_poly_church.glb` | Low Poly Church | 1,274 | 7 | 7 | 27.3 MB | 1024 | 2.6 | - | CC-BY-4.0 | Anthony Yanez | - | **not in repo** |
| `low_poly_city__cartocity_pack__cartoonsih_city.glb` | Low Poly City / CartoCity Pack / Cartoonsih City | 15,618 | 61 | 55 | 191.2 MB | 1024 | 27.5 | - | CC-BY-4.0 | DevPoly3D | textures, file | **not in repo** |
| `low_poly_f-111_aardvark.glb` | Low poly F-111 Aardvark | 12,108 | 96 | 10 | 0.5 MB | 256 | 0.8 | yes | CC-BY-4.0 | SIpriv | - | curated into: jet_f111 |
| `low_poly_f14_tomcat.glb` | Low poly F14 Tomcat | 6,985 | 81 | 9 | 0.1 MB | 128 | 0.5 | yes | CC-BY-4.0 | SIpriv | - | **not in repo** |
| `low_poly_game_ready_mcdonalds_building.glb` | Low Poly Game Ready McDonalds Building | 3,584 | 9 | 9 | 0.0 MB | - | 0.3 | - | CC-BY-4.0 | costoWRLD | - | **not in repo** |
| `low_poly_night_city_building_skyline.glb` | Low Poly Night City Building Skyline | 6,076 | 1 | 1 | 106.4 MB | 2048 | 9.5 | - | CC-BY-4.0 | 99.Miles | textures | in repo (identical): night_city_skyline.glb; curated into: night_skyline |
| `low_poly_police_station.glb` | Low poly police station | 5,707 | 2 | 2 | 0.3 MB | 256 | 0.4 | - | SKETCHFAB Standard | assetfactory | - | in repo (identical): low_poly_police_station.glb; curated into: police |
| `low_poly_public_buildings_pack.glb` | Low poly public buildings pack | 48,827 | 14 | 2 | 0.3 MB | 256 | 2.6 | - | SKETCHFAB Standard | assetfactory | - | **not in repo** |
| `low_poly_silo.glb` | Low Poly Silo | 6,982 | 3 | 3 | 0.0 MB | - | 0.3 | - | CC-BY-4.0 | CevoCreative | - | **not in repo** |
| `low_poly_ufo_scene.glb` | Low Poly UFO Scene | 40,502 | 155 | 22 | 0.0 MB | - | 2.6 | - | CC-BY-4.0 | EdwinRC | - | curated into: ufo |
| `low_poly_vehicle_mini_pack_8.glb` | Low Poly Vehicle Mini Pack 8 | 82,152 | 90 | 1 | 0.3 MB | 256 | 3.9 | - | CC-BY-4.0 | Vladek | - | **not in repo** |
| `lowpoly_buildings.glb` | Lowpoly Buildings | 2,336 | 45 | 1 | 21.3 MB | 2048 | 6.4 | - | SKETCHFAB Standard | l0wpoly | - | in repo (identical): lowpoly_buildings.glb; curated into: outpost |
| `lowpoly_city_street_pack_buildings_stylized.glb` | LOWPOLY CITY STREET PACK BUILDINGS STYLIZED | 73,045 | 181 | 64 | 118.8 MB | 1024 | 10.1 | - | CC-BY-4.0 | haykel-shaba | textures | **not in repo** |
| `nasams_1_surface-to-air_missile_system.glb` | Nasams 1 Surface-to-Air Missile System | 3,114 | 1 | 1 | 21.3 MB | 1024 | 2.8 | - | CC-BY-4.0 | Muhamad Mirza Arrafi | - | **not in repo** |
| `neon_sign_-_woman.glb` | Neon Sign - Woman | 3,104 | 3 | 2 | 10.6 MB | 1024 | 0.4 | - | CC-BY-4.0 | Kira Khaos | - | **not in repo** |
| `nes_-_wheres_waldo_-waldo.glb` | NES - Wheres Waldo -Waldo | 2,392 | 1 | 1 | 0.0 MB | 256 | 0.1 | - | CC-BY-4.0 | Carl.Kirsch | - | **not in repo** |
| `new hospital and shop fr island 2.glb` | Low Poly City Asset Pack | 14,696 | 66 | 34 | 0.0 MB | - | 0.9 | - | CC-BY-4.0 | Calipo | - | **not in repo** |
| `new_york_buildings.glb` | New York Buildings | 5,142 | 22 | 22 | 69.8 MB | 2048 | 19.5 | - | CC-BY-4.0 | sumitmangela | textures, file | in repo (identical): new_york_buildings.glb; curated into: ny_buildings |
| `nuclear_power_plant_game_asset.glb` | Nuclear Power Plant [Game Asset] | 6,758 | 8 | 8 | 5.3 MB | 1024 | 1.2 | - | CC-BY-4.0 | Jen S Abbott | - | **not in repo** |
| `old_pier (1).glb` | Old pier | 4,232 | 2 | 2 | 31.9 MB | 1024 | 7.6 | - | CC-BY-4.0 | smitecraft.swe | - | **not in repo** |
| `old_pier.glb` | Old pier | 4,232 | 2 | 2 | 31.9 MB | 1024 | 7.6 | - | CC-BY-4.0 | smitecraft.swe | - | curated into: pier_old |
| `pack_-_low_poly_-_15_building.glb` | Pack - Low Poly - 15 Building | 85,313 | 12 | 9 | 46.5 MB | 1024 | 14.4 | - | CC-BY-4.0 | Islide | - | **not in repo** |
| `pier__game_ready_model.glb` | Pier / Game ready model | 5,982 | 4 | 4 | 0.0 MB | - | 0.3 | - | CC-BY-4.0 | BlackBox613 | - | **not in repo** |
| `pirate_ship.glb` | Pirate Ship | 74,146 | 13 | 12 | 0.0 MB | - | 4.7 | - | CC-BY-4.0 | Oleg Muzyka | - | **not in repo** |
| `police_car_-_low_poly.glb` | POLICE CAR - LOW POLY | 3,942 | 1 | 1 | 5.3 MB | 1024 | 0.5 | - | CC-BY-4.0 | Jasmin Daniel | - | **not in repo** |
| `radar.glb` | Radar | 264 | 2 | 1 | 16.0 MB | 1024 | 1.0 | yes | CC-BY-4.0 | Calibians | - | **not in repo** |
| `red_beach_umbrella.glb` | Red beach umbrella | 3,996 | 3 | 1 | 10.6 MB | 1024 | 1.8 | yes | SKETCHFAB Standard | assetfactory | - | **not in repo** |
| `russian_building_4k_texture_low-poly_game_model.glb` | Russian Building 4k texture low-poly game model | 34 | 2 | 2 | 10.6 MB | 1024 | 2.8 | - | CC-BY-4.0 | BlackMonolith | - | **not in repo** |
| `school_building.glb` | school building | 20,386 | 9 | 9 | 19.9 MB | 1024 | 3.1 | - | CC-BY-4.0 | swjeta | - | in repo (identical): school_building.glb |
| `simple_low_poly_boat.glb` | Simple Low poly Boat | 792 | 4 | 4 | 11.0 MB | 1024 | 0.2 | - | CC-BY-4.0 | Jewel John | - | curated into: boat_simple |
| `somewhat_low-poly_buildings.glb` | Somewhat Low-poly Buildings | 60,965 | 11 | 10 | 0.7 MB | 1024 | 4.2 | - | CC-BY-4.0 | Calne | - | **not in repo** |
| `stadium_low_poly.glb` | Stadium Low Poly | 725 | 6 | 6 | 0.8 MB | 512 | 0.1 | - | CC-BY-4.0 | Supra | - | in repo (identical): stadium_low_poly.glb; curated into: stadium |
| `strike_fighters_apcifv_pack.glb` | Strike Fighters APC/IFV pack | 16,274 | 48 | 29 | 4.7 MB | 256 | 1.3 | - | CC-BY-NC-4.0 | 42manako | - | **not in repo** |
| `strike_fighters_radar_pack.glb` | Strike Fighters radar pack | 14,264 | 57 | 40 | 6.4 MB | 256 | 1.3 | - | CC-BY-NC-4.0 | 42manako | - | **not in repo** |
| `strike_fighters_tanks_pack.glb` | Strike Fighters tanks pack | 36,975 | 84 | 47 | 9.0 MB | 256 | 2.8 | - | CC-BY-NC-4.0 | 42manako | - | **not in repo** |
| `stylised_low_poly_-_city_metal_bridge.glb` | Stylised Low Poly - City Metal Bridge | 7,384 | 4 | 4 | 21.3 MB | 1024 | 2.6 | - | CC-BY-4.0 | remidoes3d | - | **not in repo** |
| `stylized_pirate_island_pack__low_poly_3d_assets.glb` | Stylized Pirate Island Pack – Low Poly 3D Assets | 10,681 | 25 | 1 | 16.0 MB | 1024 | 3.2 | - | CC-BY-4.0 | CG Lads | - | curated into: pirate_huts |
| `tent_14_mb.glb` | Tent_14_MB | 188,490 | 2 | 2 | 31.9 MB | 1024 | 12.2 | - | CC-BY-4.0 | Mehdi Shahsavan | tris | **not in repo** |
| `the_project_941__akula__typhoon_submarine.glb` | The Project 941 / Akula / Typhoon submarine | 2,421 | 2 | 2 | 10.6 MB | 1024 | 1.1 | - | CC-BY-4.0 | yakudami | - | curated into: boat_sub |
| `uss_enterprise_cvn-65_aircraft_carrier.glb` | USS Enterprise CVN-65 Aircraft Carrier | 73,321 | 18 | 11 | 57.5 MB | 1024 | 15.2 | - | CC-BY-4.0 | Muhamad Mirza Arrafi | file | **not in repo** |
| `vehicule_de_pompiers.glb` | Véhicule de pompiers | 64,492 | 1 | 1 | 5.3 MB | 1024 | 2.6 | - | CC-BY-4.0 | GÉOSMARTIC® | - | **not in repo** |
| `windows_logo_2001-2012_in_3d.glb` | Windows Logo (2001-2012) in 3D | 1,136 | 4 | 4 | 0.0 MB | - | 0.1 | - | CC-BY-4.0 | ZoeError Remakes | - | **not in repo** |
| `wooden_boat.glb` | Wooden Boat | 4,396 | 8 | 7 | 21.3 MB | 1024 | 1.6 | - | CC-BY-4.0 | sumitmangela | - | curated into: boat_wooden |
| `wwii_medical_tent.glb` | WWII Medical Tent | 7,014 | 1 | 1 | 16.0 MB | 1024 | 3.2 | - | CC-BY-4.0 | creationwasteland | - | **not in repo** |
| `xxx_neon_sign.glb` | XXX Neon Sign | 76,268 | 3 | 3 | 58.5 MB | 1024 | 4.9 | - | CC-BY-4.0 | Jimmy Johansson | - | **not in repo** |
| `yellow_beach_umbrella.glb` | Yellow beach umbrella | 3,996 | 3 | 1 | 10.6 MB | 1024 | 1.8 | yes | SKETCHFAB Standard | assetfactory | - | **not in repo** |

## Licenses to watch

Counts: CC-BY-4.0: 77, SKETCHFAB Standard: 11, CC-BY-NC-4.0: 4

Non-commercial, no-derivatives or Sketchfab Standard (check before shipping): `bus_stop_shelters__sign_pack__brisbane.glb`, `fishing_boat_low_poly_style.glb`, `half-life_2_-_complete_city-17_buildings.glb`, `hungry_jacks_restaurant_low_poly.glb`, `low-poly_industrial_building.glb`, `low_poly_accommodations_buildings.glb`, `low_poly_business_buildings_pack.glb`, `low_poly_police_station.glb`, `low_poly_public_buildings_pack.glb`, `lowpoly_buildings.glb`, `red_beach_umbrella.glb`, `strike_fighters_apcifv_pack.glb`, `strike_fighters_radar_pack.glb`, `strike_fighters_tanks_pack.glb`, `yellow_beach_umbrella.glb`

No license metadata (source unknown): none

## Duplicates inside Downloads (identical bytes)

- `bridge to island 2.glb`, `stylised_low_poly_-_city_metal_bridge.glb`
- `golden_gate_bridge (1).glb`, `golden_gate_bridge.glb`
- `low-poly_city_street_buildings_asset_pack (1).glb`, `low-poly_city_street_buildings_asset_pack.glb`
- `old_pier (1).glb`, `old_pier.glb`

## Models already in the repo

| Folder | GLBs | Total MB | Triangles | Heavy ones |
|---|---|---|---|---|
| `FREEMODELS/_incoming` | 20 | 129.3 | 591,458 | 8 |
| `FREEMODELS/curated` | 48 | 74.5 | 568,301 | 0 |
| `FREEMODELS/kenney_city-kit-commercial_2.1` | 41 | 3.6 | 44,682 | 0 |
| `FREEMODELS/kenney_city-kit-industrial_2.0` | 37 | 3.0 | 35,390 | 0 |
| `FREEMODELS/kenney_city-kit-roads` | 95 | 1.5 | 17,146 | 0 |
| `FREEMODELS/kenney_city-kit-suburban_20` | 40 | 2.5 | 30,035 | 0 |
| `shops/` | 29 | 5.3 | 60,066 | 0 |
| `vehicles/` | 73 | 16.8 | 161,583 | 0 |

### Curated packs (what the map actually loads), heaviest first

| Pack | Tris | Tex VRAM | File MB | Flags |
|---|---|---|---|---|
| `accommodations.glb` | 92,965 | 0.3 MB | 6.9 | - |
| `quarter.glb` | 61,786 | 0.0 MB | 4.9 | - |
| `poor.glb` | 44,828 | 1.5 MB | 6.8 | - |
| `free_mini.glb` | 44,565 | 0.0 MB | 6.5 | - |
| `euro.glb` | 45,570 | 0.2 MB | 4.1 | - |
| `public_main.glb` | 44,526 | 0.3 MB | 3.0 | - |
| `ny_street.glb` | 2,468 | 16.0 MB | 5.2 | - |
| `business.glb` | 40,634 | 0.3 MB | 3.1 | - |
| `street.glb` | 16,647 | 6.0 MB | 3.0 | - |
| `night_skyline.glb` | 6,076 | 10.6 MB | 2.6 | - |
| `skyline2.glb` | 6,076 | 10.6 MB | 2.5 | - |
| `future.glb` | 3,662 | 10.6 MB | 2.7 | - |
| `carto.glb` | 9,920 | 9.2 MB | 2.0 | - |
| `neon_pacman.glb` | 27,440 | 0.0 MB | 0.2 | - |
| `nuclear.glb` | 6,776 | 5.3 MB | 1.6 | - |
| `metal_bridge.glb` | 7,384 | 5.3 MB | 1.4 | - |
| `crane.glb` | 9,423 | 1.3 MB | 1.8 | - |
| `city_night.glb` | 6,257 | 5.3 MB | 1.3 | - |
| `industrial.glb` | 11,566 | 1.0 MB | 1.4 | - |
| `ny_buildings.glb` | 5,142 | 3.2 MB | 1.6 | - |
| `urban.glb` | 2,648 | 5.2 MB | 1.4 | - |
| `pier_old.glb` | 4,232 | 2.7 MB | 1.4 | - |
| `jet_f111.glb` | 11,848 | 0.5 MB | 0.6 | - |
| `boat_wooden.glb` | 4,396 | 2.7 MB | 1.0 | - |
| `truck_ccf.glb` | 7,753 | 0.7 MB | 0.7 | - |
| `hungry.glb` | 4,415 | 2.7 MB | 0.6 | - |
| `night_towers.glb` | 900 | 2.7 MB | 0.8 | - |
| `cinema2.glb` | 5,450 | 0.3 MB | 0.5 | - |
| `police.glb` | 5,131 | 0.3 MB | 0.4 | - |
| `outpost.glb` | 1,576 | 1.3 MB | 0.6 | - |
| `boat_fishing.glb` | 4,715 | 0.0 MB | 0.4 | - |
| `towers_a.glb` | 1,348 | 1.4 MB | 0.6 | - |
| `boat_cargo.glb` | 2,384 | 1.3 MB | 0.3 | - |
| `towers_b.glb` | 590 | 1.3 MB | 0.6 | - |
| `mcdonalds.glb` | 3,584 | 0.0 MB | 0.3 | - |
| `ufo.glb` | 2,631 | 0.0 MB | 0.3 | - |
| `boat_sub.glb` | 2,421 | 0.3 MB | 0.2 | - |
| `watchtower.glb` | 2,622 | 0.0 MB | 0.2 | - |
| `un_tower.glb` | 36 | 1.3 MB | 0.2 | - |
| `boat_simple.glb` | 792 | 1.0 MB | 0.1 | - |
| `cooling.glb` | 314 | 0.7 MB | 0.2 | - |
| `stadium.glb` | 725 | 0.8 MB | 0.1 | - |
| `tank.glb` | 1,636 | 0.0 MB | 0.1 | - |
| `pirate_huts.glb` | 795 | 0.3 MB | 0.2 | - |
| `bus_shelter.glb` | 702 | 0.3 MB | 0.2 | - |
| `billboard.glb` | 340 | 0.5 MB | 0.1 | - |
| `neon_controller.glb` | 348 | 0.0 MB | 0.0 | - |
| `balloon.glb` | 258 | 0.1 MB | 0.0 | - |

### Raw incoming packs in the repo (not loaded by the game)

| File | Tris | Tex VRAM | File MB |
|---|---|---|---|
| `european_building_facades.glb` | 34,192 | 85.1 MB | 14.4 |
| `city_pack_7.glb` | 30,331 | 82.2 MB | 13.6 |
| `new_york_buildings.glb` | 5,142 | 69.8 MB | 19.5 |
| `night_city_skyline.glb` | 6,076 | 106.4 MB | 9.5 |
| `city_pack_8.glb` | 35,096 | 73.4 MB | 12.7 |
| `buildings_pack.glb` | 51,191 | 65.8 MB | 8.1 |
| `golden_gate_bridge.glb` | 159,902 | 0.0 MB | 3.9 |
| `100_lowpoly_buildings__buildings_pack.glb` | 110,420 | 0.0 MB | 6.2 |
| `detailed_12_storey_panel_apartment_building.glb` | 3,434 | 48.5 MB | 9.1 |
| `european_buildings_asset_pack_1.glb` | 19,129 | 36.7 MB | 6.1 |
| `buildings.glb` | 2,468 | 35.6 MB | 6.8 |
| `low_poly_business_buildings_pack.glb` | 70,706 | 0.3 MB | 4.2 |
| `lowpoly_buildings.glb` | 2,336 | 21.3 MB | 6.4 |
| `school_building.glb` | 20,386 | 19.9 MB | 3.1 |
| `building.glb` | 604 | 17.3 MB | 1.8 |
| `coliseum_from_poly_by_google.glb` | 24,154 | 0.0 MB | 1.4 |
| `building_crane.glb` | 9,423 | 5.3 MB | 1.4 |
| `building_3.glb` | 36 | 5.3 MB | 0.4 |
| `low_poly_police_station.glb` | 5,707 | 0.3 MB | 0.4 |
| `stadium_low_poly.glb` | 725 | 0.8 MB | 0.1 |

Vehicles (73) and shops are listed in their own catalogs: `vehicles/CATALOG.md`, `shops/CATALOG.md`. Kenney kits are small standard pieces (see folder totals above).
