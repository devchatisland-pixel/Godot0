"""Lighter metal bridge (metal_bridge.glb): the same truss bridge, far fewer triangles.

    python tools/simplify_bridge.py <in.glb> <out.glb> [min_tris]

- the roof of the truss (the overhead bracing "Pont3" and the end portals "Pont2") is taken away;
- every part of the side mesh with at least `min_tris` triangles (default 500: the slatted
  fences along the deck, thousands of triangles for a barrier seen from far away) becomes a
  plain box of its size, in the colour of the texture where the fence sampled it;
- what is left (the side trusses, the deck) is untouched.
The bridge keeps its size and its deck, so WestBridge and the fog bridge place it the same.
Needs numpy.
"""
import json
import struct
import sys

import numpy as np

REMOVED_NODES = ("Pont_001_Pont2_0", "Pont_001_Pont3_0")
SIDE_NODE = "Pont_001_Pont1_0"
COMP = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path):
    d = open(path, "rb").read()
    n = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + n])
    off = 20 + n
    bn = struct.unpack("<I", d[off:off + 4])[0]
    return j, d[off + 8:off + 8 + bn]


def accessor(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    dt = COMP[a["componentType"]]
    k = WIDTH[a["type"]]
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(b, dt, count=a["count"] * k, offset=o).reshape(a["count"], k).copy()


def components(pos, tris):
    q = np.round(pos * 1e4).astype(np.int64)
    _, weld = np.unique(q, axis=0, return_inverse=True)
    w = weld.ravel()[tris]
    parent = np.arange(w.max() + 1)

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    for a, b, c in w:
        parent[find(b)] = find(a)
        parent[find(c)] = find(a)
    return np.array([find(t[0]) for t in w])


def box(lo, hi, uv):
    """24 vertices, 12 triangles of an axis aligned box, all sampling one texel."""
    pos, nor, idx = [], [], []
    for axis in range(3):
        u, v = [k for k in range(3) if k != axis]
        for sign in (-1, 1):
            n = np.zeros(3)
            n[axis] = sign
            base = len(pos)
            for du, dv in ((0, 0), (1, 0), (1, 1), (0, 1)):
                p = np.zeros(3)
                p[axis] = hi[axis] if sign > 0 else lo[axis]
                p[u] = hi[u] if du else lo[u]
                p[v] = hi[v] if dv else lo[v]
                pos.append(p)
                nor.append(n)
            quad = [base, base + 1, base + 2, base, base + 2, base + 3]
            idx += quad if sign > 0 else quad[::-1]
    # Counter-clockwise from outside, whatever the handedness of (u, v).
    pos = np.array(pos)
    idx = np.array(idx).reshape(-1, 3)
    centre = (lo + hi) / 2
    for t in idx:
        a, b, c = pos[t]
        if np.dot(np.cross(b - a, c - a), a - centre) < 0:
            t[1], t[2] = t[2], t[1]
    return pos, np.array(nor), np.tile(uv, (24, 1)), idx


def main():
    src, dst = sys.argv[1], sys.argv[2]
    min_tris = int(sys.argv[3]) if len(sys.argv) > 3 else 500
    j, b = read_glb(src)
    node = {n.get("name"): i for i, n in enumerate(j["nodes"])}
    for name in REMOVED_NODES:
        for n in j["nodes"]:
            if node[name] in n.get("children", []):
                n["children"].remove(node[name])
    mesh = j["nodes"][node[SIDE_NODE]]["mesh"]
    prim = j["meshes"][mesh]["primitives"][0]
    att = prim["attributes"]
    pos = accessor(j, b, att["POSITION"]).astype(np.float64)
    nor = accessor(j, b, att["NORMAL"])
    tan = accessor(j, b, att["TANGENT"])
    uv = accessor(j, b, att["TEXCOORD_0"])
    tris = accessor(j, b, prim["indices"]).reshape(-1, 3).astype(np.int64)
    comp = components(pos, tris)
    keep = np.ones(len(tris), bool)
    new_pos, new_nor, new_uv, new_idx = [], [], [], []
    offset = 0
    big = [c for c in np.unique(comp) if (comp == c).sum() >= min_tris]
    # One texel for all the boxes, so that the halves of a fence do not differ in tone.
    texel = np.mean([uv[np.unique(tris[comp == c])].mean(0) for c in big], axis=0)
    for c in big:
        m = comp == c
        verts = np.unique(tris[m])
        keep &= ~m
        p, n, u, i = box(pos[verts].min(0), pos[verts].max(0), texel)
        new_pos.append(p)
        new_nor.append(n)
        new_uv.append(u)
        new_idx.append(i + offset)
        offset += len(p)
        print(f"{m.sum()} triangles -> 12 (box {np.round(pos[verts].max(0) - pos[verts].min(0), 2)})")
    kept = tris[keep]
    used = np.unique(kept)
    remap = np.full(len(pos), -1)
    remap[used] = np.arange(len(used))
    out_pos = np.concatenate([pos[used]] + new_pos).astype(np.float32)
    out_nor = np.concatenate([nor[used]] + [n.astype(np.float32) for n in new_nor])
    out_tan = np.concatenate([tan[used]] + [np.tile([1, 0, 0, 1], (len(p), 1)).astype(np.float32) for p in new_pos])
    out_uv = np.concatenate([uv[used]] + [u.astype(np.float32) for u in new_uv])
    out_idx = np.concatenate([remap[kept].ravel()] + [(i + len(used)).ravel() for i in new_idx]).astype(np.uint16)
    print(f"side mesh: {len(tris)} -> {len(out_idx) // 3} triangles")

    views = []
    for i, bv in enumerate(j["bufferViews"]):
        o = bv.get("byteOffset", 0)
        views.append(b[o:o + bv["byteLength"]])
    for name, data in (("POSITION", out_pos), ("NORMAL", out_nor), ("TANGENT", out_tan), ("TEXCOORD_0", out_uv)):
        a = j["accessors"][att[name]]
        views[a["bufferView"]] = data.tobytes()
        a["count"] = len(data)
        a.pop("byteOffset", None)
        if "min" in a:
            a["min"], a["max"] = data.min(0).tolist(), data.max(0).tolist()
    a = j["accessors"][prim["indices"]]
    views[a["bufferView"]] = out_idx.tobytes()
    a["count"] = len(out_idx)
    a["componentType"] = 5123
    a.pop("byteOffset", None)
    a["min"], a["max"] = [int(out_idx.min())], [int(out_idx.max())]

    # The removed parts leave the file: their nodes, meshes, accessors and buffer views.
    gone = {node[n] for n in REMOVED_NODES}
    gone_meshes = {j["nodes"][i]["mesh"] for i in gone}
    gone_acc = set()
    for mi in gone_meshes:
        for p in j["meshes"][mi]["primitives"]:
            gone_acc |= set(p["attributes"].values()) | {p["indices"]}
    new_node = {}
    for i in range(len(j["nodes"])):
        if i not in gone:
            new_node[i] = len(new_node)
    new_mesh = {i: k for k, i in enumerate(i for i in range(len(j["meshes"])) if i not in gone_meshes)}
    new_acc = {i: k for k, i in enumerate(i for i in range(len(j["accessors"])) if i not in gone_acc)}
    gone_views = {j["accessors"][i]["bufferView"] for i in gone_acc}
    new_view = {i: k for k, i in enumerate(i for i in range(len(j["bufferViews"])) if i not in gone_views)}
    j["nodes"] = [n for i, n in enumerate(j["nodes"]) if i in new_node]
    for n in j["nodes"]:
        if "children" in n:
            n["children"] = [new_node[c] for c in n["children"]]
        if "mesh" in n:
            n["mesh"] = new_mesh[n["mesh"]]
    j["scenes"][0]["nodes"] = [new_node[i] for i in j["scenes"][0]["nodes"]]
    j["meshes"] = [m for i, m in enumerate(j["meshes"]) if i in new_mesh]
    for m in j["meshes"]:
        for p in m["primitives"]:
            p["attributes"] = {k: new_acc[v] for k, v in p["attributes"].items()}
            p["indices"] = new_acc[p["indices"]]
    j["accessors"] = [a for i, a in enumerate(j["accessors"]) if i in new_acc]
    for a in j["accessors"]:
        a["bufferView"] = new_view[a["bufferView"]]
    for img in j.get("images", []):
        if "bufferView" in img:
            img["bufferView"] = new_view[img["bufferView"]]
    keep_views = [views[i] for i in range(len(views)) if i in new_view]
    j["bufferViews"] = [bv for i, bv in enumerate(j["bufferViews"]) if i in new_view]
    blob = bytearray()
    for bv, v in zip(j["bufferViews"], keep_views):
        bv["byteOffset"] = len(blob)
        bv["byteLength"] = len(v)
        blob += v
        blob += bytes(-len(blob) % 4)
    j["buffers"][0]["byteLength"] = len(blob)
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    with open(dst, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(blob), 0x004E4942) + bytes(blob))


if __name__ == "__main__":
    main()
