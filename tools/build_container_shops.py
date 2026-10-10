#!/usr/bin/env python3
"""Splits the "Low-poly Container" pack (Sketchfab, CC-BY-4.0) into one GLB per container.

    python tools/build_container_shops.py <low-poly_container.glb> [shops_dir]

The pack holds 16 identical boxes (12 triangles) in 8 textures (two UV layouts each, so
16 different looks). Each output GLB has one box and its texture (halved to 512 px), turned
upright (the source is Z-up, in 1/0.305 m units) with front = -Z, base on the ground, centre of
the footprint at the origin. Writes <shops_dir>/models/container-NN.glb and adds the
`container-NN` entries to <shops_dir>/catalog.json (category "Container").
"""
import io
import json
import os
import struct
import sys

from PIL import Image

SCALE = 0.305  # source units -> metres (a 20 ft container is 20 units long)
CREDIT = {
    "title": "Low-poly Container",
    "author": "Muhammad Awais Gul",
    "url": "https://sketchfab.com/3d-models/low-poly-container-044a9b7d5046496b9de3b22ee60bfaa7",
    "license": "CC-BY-4.0",
}


def read_glb(path):
    d = open(path, "rb").read()
    jl = struct.unpack("<I", d[12:16])[0]
    return json.loads(d[20:20 + jl]), d[28 + jl:]


def write_glb(path, j, blob):
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    blob += b"\0" * ((4 - len(blob) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(blob)
    with open(path, "wb") as f:
        f.write(b"glTF" + struct.pack("<II", 2, total))
        f.write(struct.pack("<I", len(js)) + b"JSON" + js)
        f.write(struct.pack("<I", len(blob)) + b"BIN\0" + blob)


def accessor_bytes(j, blob, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    size = a["count"] * {"VEC3": 12, "VEC2": 8, "SCALAR": 4 if a["componentType"] == 5125 else 2}[a["type"]]
    return blob[off:off + size]


def main():
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "shops"
    j, blob = read_glb(src)
    os.makedirs(os.path.join(out, "models"), exist_ok=True)
    cat_path = os.path.join(out, "catalog.json")
    cat = json.load(open(cat_path, encoding="utf-8"))
    cat["shops"] = [s for s in cat["shops"] if not s["id"].startswith("container-")]
    for n, mesh in enumerate(j["meshes"], 1):
        prim = mesh["primitives"][0]
        mat = j["materials"][prim["material"]]
        tex = j["textures"][mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
        im = j["images"][tex["source"]]
        bv = j["bufferViews"][im["bufferView"]]
        img = Image.open(io.BytesIO(blob[bv["byteOffset"]:bv["byteOffset"] + bv["byteLength"]])).convert("RGB")
        img = img.resize((512, 512), Image.LANCZOS)
        jpg = io.BytesIO()
        img.save(jpg, "JPEG", quality=88)
        jpg = jpg.getvalue()
        parts = []

        def add(data):
            while sum(len(p) for p in parts) % 4:
                parts.append(b"\0")
            start = sum(len(p) for p in parts)
            parts.append(data)
            return start, len(data)

        att = prim["attributes"]
        views, accs = [], []
        for key, typ in (("POSITION", "VEC3"), ("NORMAL", "VEC3"), ("TEXCOORD_0", "VEC2")):
            a = j["accessors"][att[key]]
            o, ln = add(accessor_bytes(j, blob, att[key]))
            views.append({"buffer": 0, "byteOffset": o, "byteLength": ln, "target": 34962})
            acc = {"bufferView": len(views) - 1, "componentType": 5126, "count": a["count"], "type": typ}
            if "min" in a:
                acc["min"], acc["max"] = a["min"], a["max"]
            accs.append(acc)
        ia = j["accessors"][prim["indices"]]
        io_, il = add(accessor_bytes(j, blob, prim["indices"]))
        views.append({"buffer": 0, "byteOffset": io_, "byteLength": il, "target": 34963})
        accs.append({"bufferView": len(views) - 1, "componentType": ia["componentType"], "count": ia["count"], "type": "SCALAR"})
        jo, jl = add(jpg)
        views.append({"buffer": 0, "byteOffset": jo, "byteLength": jl})
        data = b"".join(parts)
        name = "container-%02d" % n
        g = {
            "asset": {"version": "2.0", "generator": "tools/build_container_shops.py",
                      "extras": {"author": CREDIT["author"], "license": CREDIT["license"], "source": CREDIT["url"]}},
            "scene": 0, "scenes": [{"nodes": [0]}],
            "nodes": [{"name": name, "mesh": 0, "rotation": [-0.70710678, 0, 0, 0.70710678],
                       "scale": [SCALE] * 3}],
            "meshes": [{"name": name, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
                                                      "indices": 3, "material": 0}]}],
            "materials": [{"name": name, "doubleSided": True,
                           "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0,
                                                    "roughnessFactor": 0.9}}],
            "textures": [{"sampler": 0, "source": 0}],
            "images": [{"bufferView": len(views) - 1, "mimeType": "image/jpeg"}],
            "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
            "bufferViews": views, "accessors": accs, "buffers": [{"byteLength": len(data)}],
        }
        write_glb(os.path.join(out, "models", name + ".glb"), g, data)
        cat["shops"].append({
            "id": name, "file": "res://shops/models/%s.glb" % name, "category": "Container",
            "name": "Container %02d (texture %s)" % (n, mat["name"]), "credit": CREDIT,
            "size_m": {"width": 6.1, "depth": 2.44, "height": 2.65}, "triangles": 12,
            "notes": "20 ft shipping container, 12 triangles, one 512 px texture.",
        })
    json.dump(cat, open(cat_path, "w", encoding="utf-8", newline="\n"), indent=1, ensure_ascii=False)
    open(cat_path, "a", encoding="utf-8").write("\n")
    print("%d containers written to %s" % (len(j["meshes"]), out))


if __name__ == "__main__":
    main()
