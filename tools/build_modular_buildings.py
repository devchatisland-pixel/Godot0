"""Builds the six buildings of the development island from the modular "City Game ready free"
pack (CG Lads, CC-BY-4.0, https://sketchfab.com/3d-models/city-game-ready-free-9095f8bcff1e4c9088ea98a306d5887d).

    python tools/build_modular_buildings.py <city_game_ready_free.glb> [shops/models/modular-city.glb] [shops/catalog.json]

The pack is a sheet of storeys: shop ground floors, beige, pink and glass floors, flat roofs
with props, a tiled roof. Each building stacks them: a grid of `cols` x `rows` modules per storey
(the back row turned round, so both long sides have a front), one ground floor, `floors` upper
floors and a roof. Every module is stretched to the same pitch, so the joints close.
Output: one GLB, one top-level node per building (front -Z, up +Y, origin at the ground centre,
metres), read by MapShops through the "node" field of shops/catalog.json; the six entries of
the catalog are written (or replaced) too. ShopSites puts them in the south row of the island.
"""
import json
import struct
import sys

import numpy as np

# Pieces of the pack (glTF node names, without "_Atlas_0") and the props standing on them.
GROUPS = {
    "shop_clothes": ["Building.001"], "shop_sweets": ["Building.002"], "shop_sweets2": ["Building.013"],
    "beige": ["Cube"], "beige_b": ["Cube.002_Plate"], "beige_balcony": ["Cube.002_Plate.001"],
    "beige_balcony_b": ["Cube.002_Plate.002"], "glass": ["Cube.002_Plate.003"],
    "glass_wide": ["Cube.002_Plate.004"], "glass_round": ["Cube.003"], "pink": ["Cube.002_Plate.005"],
    "pink_b": ["Cube.002_Plate.006"], "pink_c": ["Cube.002_Plate.007"],
    "top_ac": ["Cube.002_Plate.011", "Object014", "Object015", "Object016", "Object017"],
    "roof_tiles": ["Cube.002_Plate.012"],
    "roof_garden": ["Object002", "Object009", "Object010", "Object011", "Object012", "Cube.013", "model_4.001"],
    "roof_dog": ["Object001", "Object013"],
    "roof_crates": ["Cube.002_Plate.009", "Cube.007", "Cube.008", "Cube.009"],
    "roof_dish": ["Cube.002_Plate.010", "Object006.002", "Object007", "Object008"],
}
# Metres per pack unit: a storey of the pack is 2 units, 3 m here.
SCALE = 1.5
# Pitch of the modules (pack units): every module is stretched to it.
PITCH = (4.2, 2.2)
STOREY = 2.0

NAMES = {
    "modular-house-small": "Little house", "modular-house-medium": "Middle house",
    "modular-house-big": "Big house", "modular-tower-small": "Little skyscraper",
    "modular-tower-medium": "Medium skyscraper", "modular-tower-big": "Big skyscraper",
}
CREDIT = {"title": "City Game ready free", "author": "CG Lads",
          "url": "https://sketchfab.com/3d-models/city-game-ready-free-9095f8bcff1e4c9088ea98a306d5887d",
          "license": "CC-BY-4.0"}

# id -> cols, rows, list of storeys from the ground up (a group name, or a list per column).
BUILDINGS = {
    "modular-house-small": (1, 1, ["pink", "roof_tiles"]),
    "modular-house-medium": (1, 1, ["shop_sweets2", "beige", "beige_balcony_b", "roof_garden"]),
    "modular-house-big": (2, 1, [["shop_clothes", "shop_sweets"], ["beige", "beige_b"],
                                 ["beige_balcony", "beige_balcony_b"], ["pink_b", "pink_c"],
                                 ["roof_dog", "roof_crates"]]),
    "modular-tower-small": (2, 1, [["shop_sweets", "shop_clothes"]] + ["glass"] * 6 + [["roof_dish", "roof_garden"]]),
    "modular-tower-medium": (2, 2, [["shop_clothes", "shop_sweets2"]] + ["glass_round"] * 10 + ["top_ac"]),
    "modular-tower-big": (3, 2, [["shop_sweets", "shop_clothes", "shop_sweets2"]] + ["glass_wide"] * 15
                          + [["top_ac", "roof_crates", "top_ac"]]),
}


def read_glb(path):
    d = open(path, "rb").read()
    n = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + n])
    off = 20 + n
    bn = struct.unpack("<I", d[off:off + 4])[0]
    return j, d[off + 8:off + 8 + bn]


def node_matrix(nd):
    if "matrix" in nd:
        return np.array(nd["matrix"], dtype=float).reshape(4, 4).T
    m = np.eye(4)
    if "scale" in nd:
        m = np.diag(list(nd["scale"]) + [1.0]) @ m
    if "rotation" in nd:
        x, y, z, w = nd["rotation"]
        r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                      [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                      [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
        rm = np.eye(4)
        rm[:3, :3] = r
        m = rm @ m
    if "translation" in nd:
        t = np.eye(4)
        t[:3, 3] = nd["translation"]
        m = t @ m
    return m


def world_meshes(j):
    """name -> (mesh index, world matrix, world bbox min, max) for every mesh node."""
    out = {}
    acc = j["accessors"]

    def walk(i, parent):
        nd = j["nodes"][i]
        m = parent @ node_matrix(nd)
        if "mesh" in nd:
            a = acc[j["meshes"][nd["mesh"]]["primitives"][0]["attributes"]["POSITION"]]
            lo, hi = np.array(a["min"]), np.array(a["max"])
            corners = np.array([[x, y, z, 1] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])])
            w = (m @ corners.T).T[:, :3]
            name = nd.get("name", "").removesuffix("_Atlas_0")
            out[name] = (nd["mesh"], m, w.min(0), w.max(0))
        for c in nd.get("children", []):
            walk(c, m)

    for r in j["scenes"][0]["nodes"]:
        walk(r, np.eye(4))
    return out


def group_parts(meshes, group):
    """The pieces of a group with matrices that put the base piece's bottom centre at the origin,
    stretched to the pitch (front +Z as in the pack), and the height of the base piece."""
    base = meshes[GROUPS[group][0]]
    lo, hi = base[2], base[3]
    size = hi - lo
    centre = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    s = np.diag([PITCH[0] / size[0], 1.0, PITCH[1] / size[2], 1.0])
    t = np.eye(4)
    t[:3, 3] = -centre
    parts = [(meshes[n][0], s @ t @ meshes[n][1]) for n in GROUPS[group]]
    return parts, size[1]


def main():
    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else "shops/models/modular-city.glb"
    j, binary = read_glb(src)
    meshes = world_meshes(j)
    nodes = []
    roots = []
    sizes = {}
    for bid, (cols, rows, storeys) in BUILDINGS.items():
        children = []
        y = 0.0
        for st in storeys:
            per_col = st if isinstance(st, list) else [st] * cols
            h_max = 0.0
            for r in range(rows):
                for c in range(cols):
                    parts, h = group_parts(meshes, per_col[c])
                    h_max = max(h_max, h)
                    place = np.eye(4)
                    z = (r - (rows - 1) / 2) * PITCH[1]
                    if r == 0:
                        # Front row: the pack fronts look +Z, the catalog wants -Z.
                        place[:3, :3] = np.diag([-1.0, 1.0, -1.0])
                    place[:3, 3] = [(c - (cols - 1) / 2) * PITCH[0], y, z]
                    for mesh, m in parts:
                        mm = np.diag([SCALE, SCALE, SCALE, 1.0]) @ place @ m
                        nodes.append({"mesh": mesh, "matrix": [float(v) for v in mm.T.reshape(-1)]})
                        children.append(len(nodes) - 1)
            top = y + h_max
            y += STOREY
        nodes.append({"name": bid, "children": children})
        roots.append(len(nodes) - 1)
        sizes[bid] = (cols * PITCH[0] * SCALE, rows * PITCH[1] * SCALE, round(top * SCALE, 2))
    out = dict(j)
    out["nodes"] = nodes
    out["scenes"] = [{"name": "modular-city", "nodes": roots}]
    out["scene"] = 0
    out["asset"] = {"version": "2.0", "generator": "tools/build_modular_buildings.py",
                    "copyright": "CG Lads, CC-BY-4.0 (City Game ready free, Sketchfab)"}
    js = json.dumps(out, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    binary += b"\0" * (-len(binary) % 4)
    total = 12 + 8 + len(js) + 8 + len(binary)
    with open(dst, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(binary), 0x004E4942) + binary)
    for bid, s in sizes.items():
        print(bid, "width %.2f depth %.2f height %.2f" % s)
    if len(sys.argv) > 3:
        cat_path = sys.argv[3]
        cat = json.load(open(cat_path, encoding="utf-8"))
        shops = [e for e in cat["shops"] if not e["id"].startswith("modular-")]
        for bid, (w, d, h) in sizes.items():
            shops.append({
                "id": bid, "file": "res://shops/models/modular-city.glb", "node": bid,
                "category": "Modular", "name": NAMES[bid], "credit": CREDIT,
                "size_m": {"width": round(w, 2), "depth": round(d, 2), "height": h},
                "notes": "Stacked from the modular pack by tools/build_modular_buildings.py.",
            })
        cat["shops"] = shops
        with open(cat_path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(cat, f, indent=1, ensure_ascii=False)
            f.write("\n")


if __name__ == "__main__":
    main()
