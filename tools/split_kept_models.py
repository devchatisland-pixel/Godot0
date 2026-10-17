"""Model replacements and split of the kept models out of their curated packs.

  python tools/split_kept_models.py

1. REPLACE: the slot of a pack model (its entry in the pack's .models.json) draws another model
   instead: the entry gets the other "node" and the "file" holding it, its category stays.
2. SPLIT: each kept model of a pack is written to its own <node>.glb (no manifest of its own),
   the pack keeps the rest, and every manifest entry drawing that model points at the new file.
Entries never move, so the list of each category keeps its order and the city keeps its layout;
once nothing points at a pack any more, the pack .glb can be deleted.
"""
import json, os, sys, glob
sys.path.insert(0, os.path.dirname(__file__))
import copy
from split_glb_pack import read_glb, write_glb

def build(j, binary, top_ids, root=None):
    """A glb json + binary holding the node trees `top_ids` (children included) with only the
    meshes, accessors, materials, textures and images they use; `root` wraps them when given."""
    order, newi = [], {}
    def visit(i):
        newi[i] = len(order); order.append(i)
        for c in j["nodes"][i].get("children", []): visit(c)
    base = 1 if root is not None else 0
    for t in top_ids: visit(t)
    nodes, meshes, mesh_map, acc_ids, mats = [], [], {}, [], []
    def acc(i):
        if i not in acc_ids: acc_ids.append(i)
        return acc_ids.index(i)
    for i in order:
        n = copy.deepcopy(j["nodes"][i])
        if "children" in n: n["children"] = [newi[c] + base for c in n["children"]]
        for k in ("skin", "camera"): n.pop(k, None)
        if "mesh" in n:
            if n["mesh"] not in mesh_map:
                mesh = copy.deepcopy(j["meshes"][n["mesh"]])
                for p in mesh["primitives"]:
                    p["attributes"] = {k: acc(v) for k, v in p["attributes"].items()}
                    if "indices" in p: p["indices"] = acc(p["indices"])
                    for t in p.get("targets", []):
                        for k in t: t[k] = acc(t[k])
                    if "material" in p:
                        if p["material"] not in mats: mats.append(p["material"])
                        p["material"] = mats.index(p["material"])
                mesh_map[n["mesh"]] = len(meshes); meshes.append(mesh)
            n["mesh"] = mesh_map[n["mesh"]]
        nodes.append(n)
    materials = [copy.deepcopy(j["materials"][m]) for m in mats]
    tex_ids = []
    def walk(o):
        if isinstance(o, dict):
            for k, v in o.items():
                if k == "index" and isinstance(v, int):
                    if v not in tex_ids: tex_ids.append(v)
                    o[k] = tex_ids.index(v)
                else: walk(v)
        elif isinstance(o, list):
            for v in o: walk(v)
    walk(materials)
    img_ids, textures = [], []
    for t in tex_ids:
        tx = copy.deepcopy(j["textures"][t])
        for holder in [tx] + list(tx.get("extensions", {}).values()):
            if "source" in holder:
                if holder["source"] not in img_ids: img_ids.append(holder["source"])
                holder["source"] = img_ids.index(holder["source"])
        textures.append(tx)
    out_bin, views, accessors = bytearray(), [], []
    def add_bytes(chunk, extra):
        out_bin.extend(b"\0" * (-len(out_bin) % 4))
        v = {"buffer": 0, "byteOffset": len(out_bin), "byteLength": len(chunk)}
        v.update(extra); out_bin.extend(chunk); views.append(v)
        return len(views) - 1
    sizes = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}
    widths = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
    for a in acc_ids:
        ac = copy.deepcopy(j["accessors"][a])
        if "sparse" in ac: sys.exit("sparse accessor, split by hand")
        if "bufferView" in ac:
            v = j["bufferViews"][ac["bufferView"]]
            elem = sizes[ac["type"]] * widths[ac["componentType"]]
            stride = v.get("byteStride", elem)
            start = v.get("byteOffset", 0) + ac.get("byteOffset", 0)
            chunk = binary[start:start + stride * (ac["count"] - 1) + elem]
            extra = {k: v[k] for k in ("byteStride", "target") if k in v}
            ac["bufferView"] = add_bytes(chunk, extra); ac.pop("byteOffset", None)
        accessors.append(ac)
    images = []
    for im in img_ids:
        img = copy.deepcopy(j["images"][im])
        if "bufferView" in img:
            v = j["bufferViews"][img["bufferView"]]
            st = v.get("byteOffset", 0)
            img["bufferView"] = add_bytes(binary[st:st + v["byteLength"]], {})
        images.append(img)
    if root is not None:
        r = copy.deepcopy(root)
        r["children"] = [newi[t] + 1 for t in top_ids]
        nodes = [r] + nodes
    out = {"asset": j["asset"], "scene": 0, "scenes": [{"nodes": [0] if root is not None else [newi[t] for t in top_ids]}],
           "nodes": nodes, "accessors": accessors, "bufferViews": views,
           "buffers": [{"byteLength": len(out_bin)}]}
    if meshes: out["meshes"] = meshes
    if materials: out["materials"] = materials
    if textures: out["textures"] = textures
    if images: out["images"] = images
    if "samplers" in j: out["samplers"] = j["samplers"]
    for k in ("extensionsUsed", "extensionsRequired"):
        if k in j: out[k] = j[k]
    return out, bytes(out_bin)

CURATED = "FREEMODELS/curated"

# (pack, node) drawn by (file, node) from now on.
REPLACE = [
    (("quarter.glb", "quarter_46_b"), ("quarter.glb", "quarter_48_b")),
    (("quarter.glb", "quarter_35_b"), ("quarter.glb", "quarter_40_b")),
    (("port_halls.glb", "hall_factory_2"), ("port_halls.glb", "hall_factory_1")),
    (("hotel_low.glb", "hotel_orange"), ("hotel_small_night.glb", "hotel_small")),
    (("carto.glb", "hotel1"), ("hotel_small_night.glb", "hotel_small")),
    (("hotels.glb", "hotel_tower"), ("hotel_stars_night.glb", "hotel_stars")),
    (("hungry.glb", "burger_king"), ("hotel_stars_night.glb", "hotel_stars")),
    (("port_halls.glb", "hall_powerplant"), ("port_sheds.glb", "shed_warehouse_3")),
    (("port_halls.glb", "hall_terminal"), ("port_sheds.glb", "shed_warehouse_3")),
    (("port_halls.glb", "hall_warehouse_5"), ("port_sheds.glb", "shed_warehouse_3")),
    (("port_sheds.glb", "shed_generic_3"), ("port_sheds.glb", "shed_trailer")),
    (("port_sheds.glb", "shed_loadbay"), ("port_sheds.glb", "shed_trailer")),
    (("port_sheds.glb", "shed_works_1"), ("port_sheds.glb", "shed_trailer")),
    (("quarter.glb", "quarter_22_b"), ("quarter.glb", "quarter_25_b")),
    (("quarter.glb", "quarter_56_b"), ("quarter.glb", "quarter_25_b")),
    (("quarter.glb", "quarter_78_b"), ("quarter.glb", "quarter_25_b")),
    (("outpost.glb", "barrack_b"), ("outpost.glb", "ranch_c")),
    (("quarter.glb", "quarter_59_b"), ("quarter.glb", "quarter_98_b")),
    (("quarter.glb", "quarter_61_b"), ("quarter.glb", "quarter_95_b")),
    (("urban.glb", "tower5"), ("urban.glb", "tower0")),
    (("urban.glb", "tower6"), ("urban.glb", "tower0")),
    (("port_halls.glb", "hall_hangar"), ("port_halls.glb", "hall_factory_1")),
    (("port_halls.glb", "hall_warehouse_4"), ("port_halls.glb", "hall_factory_1")),
    (("port_tanks.glb", "tank_rusty"), ("port_tanks.glb", "tank_oil")),
    (("port_towers.glb", "tower_silo"), ("port_tanks.glb", "tank_big")),
    (("street.glb", "shop_coffee"), ("business.glb", "shop")),
    (("free_mini.glb", "m10"), ("business.glb", "shop")),
]

# Pack -> models taken out into their own file. lighthouse_club.glb keeps the club itself
# (its kept model has the pack's name), so the neon sign is the one taken out.
SPLIT = {
    "concert.glb": ["concert_stage"],
    "lighthouse_club.glb": ["lighthouse_club_neon"],
    "outpost.glb": ["ranch_b", "ranch_c", "trailer_b", "barn_a", "water_tank"],
    "port_tanks.glb": ["tank_spheres", "tank_old", "tank_big", "tank_oil"],
    "public_main.glb": ["gas_station", "school"],
    "towers_a.glb": ["towers_a_17_b", "towers_a_33_b", "towers_a_51_b"],
    "ny_street.glb": ["ny_street_08_b"],
    "port_towers.glb": ["tower_radio", "tower_water", "tower_crane"],
    "fog_homes.glb": ["home-bungalow"],
    "quarter.glb": ["quarter_48_b", "quarter_40_b", "quarter_25_b", "quarter_98_b", "quarter_95_b"],
    "port_halls.glb": ["hall_factory_1"],
    "port_sheds.glb": ["shed_warehouse_3", "shed_trailer"],
    "urban.glb": ["tower0"],
}

def load_manifests():
    out = {}
    for p in glob.glob(os.path.join(CURATED, "*.models.json")):
        out[p] = json.load(open(p))
    return out

def save(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent="\t")
        f.write("\n")

def main():
    mans = load_manifests()
    by_file = {d["file"]: p for p, d in mans.items()}
    # 1. replacements
    for (pack, node), (file, new) in REPLACE:
        d = mans[by_file[pack]]
        hit = [m for m in d["models"] if m["node"] == node and m.get("file", pack) == pack]
        if not hit:
            sys.exit("no slot %s: %s" % (pack, node))
        for m in hit:
            m["node"] = new
            if file != pack: m["file"] = file
            print("slot %s: %s -> %s: %s" % (pack, node, file, new))
    # 2. splits
    for pack, nodes in SPLIT.items():
        src = os.path.join(CURATED, pack)
        j, binary = read_glb(src)
        root = j["nodes"][j["scenes"][0]["nodes"][0]]
        names = {c: j["nodes"][c]["name"] for c in root["children"]}
        for n in nodes:
            if n not in names.values():
                sys.exit("%s has no %s" % (pack, n))
            if os.path.exists(os.path.join(CURATED, n + ".glb")):
                sys.exit("%s.glb already exists" % n)
        take = [c for c in root["children"] if names[c] in nodes]
        for c in take:
            # The node keeps its own transform and its children (baked into one mesh by the library).
            # Wrapped in a bare root of the same name (the pack is GODOT_single_root): the
            # library merges from that root, so the model's own transform is kept as in the pack.
            out, out_bin = build(j, binary, [c], {"name": names[c]})
            write_glb(os.path.join(CURATED, names[c] + ".glb"), out, out_bin)
            print("wrote", names[c] + ".glb")
        rest = [c for c in root["children"] if c not in take]
        out, out_bin = build(j, binary, rest, root)
        write_glb(src, out, out_bin)
        for d in mans.values():
            for m in d["models"]:
                if m.get("file", d["file"]) == pack and m["node"] in nodes:
                    m["file"] = m["node"] + ".glb"
        print(pack, "keeps", len(rest))
    for p, d in mans.items():
        for m in d["models"]:
            if m.get("file") == d["file"]: del m["file"]
        save(p, d)

if __name__ == "__main__":
    main()
