"""Split a curated multi-node .glb pack into one .glb (+ .models.json) per model node.

  python tools/split_glb_pack.py FREEMODELS/curated/neon_vegas.glb [--keep]

Each child node of the root becomes <node>.glb with only the mesh, material, textures and
images it uses; <node>.models.json is written from the pack's own .models.json entry.
The original pack and its manifest are deleted unless --keep is given.
"""
import json, struct, sys, os, copy

def read_glb(path):
    d = open(path, "rb").read()
    jl, _ = struct.unpack("<II", d[12:20])
    j = json.loads(d[20:20 + jl])
    off = 20 + jl
    bl, _ = struct.unpack("<II", d[off:off + 8])
    return j, d[off + 8:off + 8 + bl]

def write_glb(path, j, binary):
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    binary += b"\0" * (-len(binary) % 4)
    total = 12 + 8 + len(js) + 8 + len(binary)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(binary), 0x004E4942) + binary)

def split(src, keep):
    j, binary = read_glb(src)
    root = j["nodes"][j["scenes"][0]["nodes"][0]]
    names = [j["nodes"][i]["name"] for i in root["children"]]
    base = os.path.dirname(src)
    manifest = json.load(open(src.replace(".glb", ".models.json")))
    cats = {m["node"]: m["cat"] for m in manifest["models"]}
    for ci in root["children"]:
        node = copy.deepcopy(j["nodes"][ci])
        mesh = copy.deepcopy(j["meshes"][node["mesh"]])
        # collect accessors -> bufferViews
        acc_ids, mats = [], []
        def acc(i):
            if i not in acc_ids: acc_ids.append(i)
            return acc_ids.index(i)
        for p in mesh["primitives"]:
            p["attributes"] = {k: acc(v) for k, v in p["attributes"].items()}
            if "indices" in p: p["indices"] = acc(p["indices"])
            if "material" in p:
                if p["material"] not in mats: mats.append(p["material"])
                p["material"] = mats.index(p["material"])
        materials = [copy.deepcopy(j["materials"][m]) for m in mats]
        tex_ids = []
        def walk(o):
            if isinstance(o, dict):
                for k, v in o.items():
                    if k == "index" and isinstance(v, int) and "texCoord" in o or k == "index" and isinstance(v, int):
                        if v not in tex_ids: tex_ids.append(v)
                        o[k] = tex_ids.index(v)
                    else: walk(v)
            elif isinstance(o, list):
                for v in o: walk(v)
        walk(materials)
        img_ids, textures = [], []
        for t in tex_ids:
            tx = copy.deepcopy(j["textures"][t])
            if "source" in tx:
                if tx["source"] not in img_ids: img_ids.append(tx["source"])
                tx["source"] = img_ids.index(tx["source"])
            textures.append(tx)
        # rebuild binary
        out_bin, views, accessors = bytearray(), [], []
        def add_view(vi):
            v = copy.deepcopy(j["bufferViews"][vi])
            start = v.get("byteOffset", 0)
            chunk = binary[start:start + v["byteLength"]]
            out_bin.extend(b"\0" * (-len(out_bin) % 4))
            v["byteOffset"] = len(out_bin); v["buffer"] = 0
            out_bin.extend(chunk); views.append(v)
            return len(views) - 1
        for a in acc_ids:
            ac = copy.deepcopy(j["accessors"][a])
            if "bufferView" in ac: ac["bufferView"] = add_view(ac["bufferView"])
            accessors.append(ac)
        images = []
        for im in img_ids:
            img = copy.deepcopy(j["images"][im])
            if "bufferView" in img: img["bufferView"] = add_view(img["bufferView"])
            images.append(img)
        node["mesh"] = 0
        out = {"asset": j["asset"], "scene": 0, "scenes": [{"nodes": [0]}],
               "nodes": [node], "meshes": [mesh], "accessors": accessors,
               "bufferViews": views, "buffers": [{"byteLength": len(out_bin)}]}
        if materials: out["materials"] = materials
        if textures: out["textures"] = textures
        if images: out["images"] = images
        if "samplers" in j: out["samplers"] = j["samplers"]
        name = node["name"]
        write_glb(os.path.join(base, name + ".glb"), out, bytes(out_bin))
        with open(os.path.join(base, name + ".models.json"), "w") as f:
            json.dump({"file": name + ".glb", "models": [{"cat": cats[name], "node": name}]}, f, indent="\t")
            f.write("\n")
        print("wrote", name + ".glb", cats[name])
    if not keep:
        os.remove(src); os.remove(src.replace(".glb", ".models.json"))
        imp = src + ".import"
        if os.path.exists(imp): os.remove(imp)

if __name__ == "__main__":
    split(sys.argv[1], "--keep" in sys.argv)
