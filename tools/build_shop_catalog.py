#!/usr/bin/env python3
"""Builds res://shops from the 15 raw shop GLBs (see shops/CATALOG.md).

    python tools/build_shop_catalog.py <src_dir> [out_dir]

<src_dir> holds the raw files named <id>.glb plus the catalog.json written when the
shops were first catalogued (front side, bbox, credits). Every output GLB is normalised
like the vehicles: front = -Z, up = +Y, origin at the centre of the footprint on the
ground, 1 unit = 1 metre. The change is one wrapper node on top of the scene, so the
mesh data itself is untouched. Helper junk (cameras, collider boxes, flat ground slabs)
is dropped. Writes <out_dir>/models/<id>.glb and <out_dir>/catalog.json.
"""
import itertools
import json
import math
import os
import struct
import sys

from shop_catalog_outputs import write_island, write_markdown

# Rotation (degrees about +Y) that turns a model whose front looks along the key to -Z.
FRONT_YAW = {"-Z": 0.0, "+X": 90.0, "-X": -90.0, "+Z": 180.0}

# Uniform scale on top of the native units (the mini shop was authored 0.17 units wide).
SCALE = {"shop-general-mini": 25.0}

def read_glb(path):
    d = open(path, "rb").read()
    jl = struct.unpack("<I", d[12:16])[0]
    return json.loads(d[20:20 + jl]), d[20 + jl:]


def write_glb(path, j, rest):
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    out = b"glTF" + struct.pack("<II", 2, 20 + len(js) + len(rest)) + struct.pack("<I", len(js)) + b"JSON" + js + rest
    open(path, "wb").write(out)


def local_matrix(n):
    if "matrix" in n:
        m = n["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    t = n.get("translation", [0, 0, 0])
    x, y, z, w = n.get("rotation", [0, 0, 0, 1])
    s = n.get("scale", [1, 1, 1])
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return [[r[i][c] * s[c] for c in range(3)] + [t[i]] for i in range(3)] + [[0, 0, 0, 1]]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def mesh_boxes(j):
    """{node index: (min, max)} of the world box of every node that has a mesh."""
    acc, nodes, meshes = j["accessors"], j["nodes"], j["meshes"]
    ident = [[1 if a == b else 0 for b in range(4)] for a in range(4)]
    boxes = {}

    def walk(i, parent):
        n = nodes[i]
        m = mul(parent, local_matrix(n))
        if "mesh" in n:
            lo, hi = [1e18] * 3, [-1e18] * 3
            for pr in meshes[n["mesh"]]["primitives"]:
                a = acc[pr["attributes"]["POSITION"]]
                for c in itertools.product(*zip(a["min"], a["max"])):
                    v = [sum(m[r][k] * (tuple(c) + (1,))[k] for k in range(4)) for r in range(3)]
                    for k in range(3):
                        lo[k], hi[k] = min(lo[k], v[k]), max(hi[k], v[k])
            boxes[i] = (lo, hi)
        for c in n.get("children", []):
            walk(c, m)

    for r in j["scenes"][j.get("scene", 0)]["nodes"]:
        walk(r, ident)
    return boxes


def union(boxes):
    lo = [min(b[0][k] for b in boxes.values()) for k in range(3)]
    hi = [max(b[1][k] for b in boxes.values()) for k in range(3)]
    return lo, hi


def clean(j):
    """Drops cameras, collider meshes and flat slabs covering the whole footprint."""
    removed = []
    for n in j["nodes"]:
        n.pop("camera", None)
    boxes = mesh_boxes(j)
    for i in list(boxes):
        if j["nodes"][i].get("name", "").lower().startswith("collider"):
            j["nodes"][i].pop("mesh")
            removed.append(j["nodes"][i].get("name"))
            del boxes[i]
    lo, hi = union(boxes)
    area = (hi[0] - lo[0]) * (hi[2] - lo[2])
    for i, (a, b) in list(boxes.items()):
        thin = b[1] - a[1] < 0.05
        big = (b[0] - a[0]) * (b[2] - a[2]) > 0.9 * area
        if thin and big and len(boxes) > 1:
            removed.append(j["nodes"][i].get("name"))
            j["nodes"][i].pop("mesh")
            del boxes[i]
    return boxes, removed


def normalise(src, dst, front, scale):
    j, rest = read_glb(src)
    boxes, removed = clean(j)
    lo, hi = union(boxes)
    th = math.radians(FRONT_YAW[front])
    co, si = math.cos(th), math.sin(th)
    xs, zs = [], []
    for x in (lo[0], hi[0]):
        for z in (lo[2], hi[2]):
            xs.append((x * co + z * si) * scale)
            zs.append((-x * si + z * co) * scale)
    wrapper = {
        "name": "ShopRoot",
        "children": list(j["scenes"][j.get("scene", 0)]["nodes"]),
        "rotation": [0.0, math.sin(th / 2), 0.0, math.cos(th / 2)],
        "scale": [scale] * 3,
        "translation": [-(min(xs) + max(xs)) / 2, -lo[1] * scale, -(min(zs) + max(zs)) / 2],
    }
    j["nodes"].append(wrapper)
    j["scenes"][j.get("scene", 0)]["nodes"] = [len(j["nodes"]) - 1]
    write_glb(dst, j, rest)
    size = {"width": (max(xs) - min(xs)), "depth": (max(zs) - min(zs)), "height": (hi[1] - lo[1]) * scale}
    return {k: round(v, 2) for k, v in size.items()}, removed


def main():
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "shops"
    os.makedirs(out + "/models", exist_ok=True)
    cat = json.load(open(src + "/catalog.json", encoding="utf8"))
    shops = []
    for c in cat:
        i = c["id"]
        size, removed = normalise(f"{src}/models/shops/{i}.glb", f"{out}/models/{i}.glb", c["front"], SCALE.get(i, 1.0))
        shops.append({
            "id": i, "file": f"res://shops/models/{i}.glb", "category": c["category"], "name": c["name"],
            "credit": {"title": c["title"], "author": c["author"], "url": c["source_url"], "license": c["license"]}, "size_m": size, "triangles": c["triangles"],
            "notes": c["notes"],
        })
        print(f"{i:32s} {size} removed={removed}")
    data = {"version": 1, "orientation": "front=-Z, up=+Y, origin at ground centre, approx. metres",
            "shops": shops}
    os.makedirs(out + "/preview", exist_ok=True)
    write_markdown(data, out + "/CATALOG.md")
    write_island(data, out + "/preview/shop_island.tscn")
    json.dump(data, open(out + "/catalog.json", "w", encoding="utf8", newline="\n"), indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
