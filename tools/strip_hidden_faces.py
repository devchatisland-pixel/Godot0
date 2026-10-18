"""Removes the triangles of a model that the game can never show (lighter mesh, same look).

    python tools/strip_hidden_faces.py <in.glb> <out.glb> <node> [<node> ...] [-<node> ...]

A node written -NAME (a part inside a model, e.g. -Cube_240) is taken out of the file first.

The city camera is fixed: orthographic, 30 degrees down, only pan and zoom. The sun is fixed
too (52 degrees down). A building can face any way, so every yaw is tried. A triangle is kept
when a point of it is seen from one of these directions (pitch 20 to 60 degrees, every 5
degrees of yaw): a ray from the point towards the camera (or the sun) leaves the model
without hitting anything. The others are hidden for good: undersides, backs of the window
frames pressed against the glass, faces buried inside other parts, walls under roofs. The
material is double sided, so a face counts from both of its sides.

Also drops degenerate and duplicate triangles, then vertices no longer used. Only the meshes
of the named nodes (curated name, e.g. "school") change; the rest of the file is copied.
Needs numpy, trimesh and embreex (pip install trimesh embreex).
"""
import json
import struct
import sys

import numpy as np
import trimesh
from trimesh.ray.ray_pyembree import RayMeshIntersector

PITCHES = (20, 30, 40, 52, 60)
YAW_STEP = 5
# Sample spacing on a triangle, share of the model's size: ~1 pixel at the closest zoom.
SPACING_SHARE = 1 / 1600
SPACING = 0.02
MAX_SAMPLES = 4000
EPS_SHARE = 3e-6
EPS = 1e-4

COMP = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path):
    d = open(path, "rb").read()
    n = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + n])
    off = 20 + n
    bn = struct.unpack("<I", d[off:off + 4])[0]
    return j, d[off + 8:off + 8 + bn]


def view_bytes(j, b, i):
    bv = j["bufferViews"][i]
    o = bv.get("byteOffset", 0)
    return b[o:o + bv["byteLength"]]


def accessor(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    dt = COMP[a["componentType"]]
    k = WIDTH[a["type"]]
    assert bv.get("byteStride", 0) in (0, k * np.dtype(dt).itemsize), "interleaved buffers not handled"
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(b, dt, count=a["count"] * k, offset=o).reshape(a["count"], k).copy()


def directions():
    out = []
    for p in PITCHES:
        for y in range(0, 360, YAW_STEP):
            pr, yr = np.radians(p), np.radians(y)
            out.append((np.cos(pr) * np.cos(yr), np.sin(pr), np.cos(pr) * np.sin(yr)))
    return np.array(out)


def samples(tri, n):
    """Points spread over a triangle (barycentric grid of n steps, inset from the edges)."""
    a, b, c = tri
    i, k = np.meshgrid(np.arange(n + 1), np.arange(n + 1))
    m = i + k <= n
    u = (i[m] + 1 / 3) / (n + 1)
    v = (k[m] + 1 / 3) / (n + 1)
    return a + np.outer(u, b - a) + np.outer(v, c - a)


def look(ray, pos, tris, which, steps, seen):
    """Marks as seen the triangles `which` with a sample point seen from a direction."""
    if len(which) == 0:
        return
    pts, owner = [], []
    for t in which:
        s = samples(pos[tris[t]], steps(pos[tris[t]]))
        pts.append(s)
        owner.append(np.full(len(s), t))
    pts = np.concatenate(pts)
    owner = np.concatenate(owner)
    for d in directions():
        todo = ~seen[owner]
        if not todo.any():
            break
        origin = pts[todo] + d * EPS
        hit = ray.intersects_any(origin, np.tile(d, (len(origin), 1)))
        seen[np.unique(owner[todo][~hit])] = True


def dense(tri):
    """Grid steps so that samples are ~SPACING apart (by area, capped)."""
    a, b, c = tri
    area = 0.5 * np.linalg.norm(np.cross(b - a, c - a))
    longest = max(np.linalg.norm(b - a), np.linalg.norm(c - b), np.linalg.norm(a - c))
    n = max(np.sqrt(2 * area) / SPACING, longest / SPACING / 4)
    return int(np.clip(np.ceil(n), 2, np.sqrt(2 * MAX_SAMPLES)))


def visible_triangles(pos, tris):
    ray = RayMeshIntersector(trimesh.Trimesh(pos, tris, process=False))
    seen = np.zeros(len(tris), bool)
    # Coarse passes (6, then 28 points per triangle) settle most; the rest is sampled densely.
    look(ray, pos, tris, np.arange(len(tris)), lambda t: 2, seen)
    look(ray, pos, tris, np.flatnonzero(~seen), lambda t: 6, seen)
    print(f"  {len(tris) - seen.sum()} triangles left for the dense pass", flush=True)
    look(ray, pos, tris, np.flatnonzero(~seen), dense, seen)
    return seen


def clean(pos, tris):
    q = np.round(pos * 1e5).astype(np.int64)
    _, weld = np.unique(q, axis=0, return_inverse=True)
    w = weld.ravel()[tris]
    keep = (w[:, 0] != w[:, 1]) & (w[:, 1] != w[:, 2]) & (w[:, 0] != w[:, 2])
    v0, v1, v2 = pos[tris[:, 0]], pos[tris[:, 1]], pos[tris[:, 2]]
    keep &= np.linalg.norm(np.cross(v1 - v0, v2 - v0), axis=1) > 1e-9
    _, first = np.unique(np.sort(w, axis=1), axis=0, return_index=True)
    unique = np.zeros(len(tris), bool)
    unique[first] = True
    return keep & unique


def local_matrix(n):
    if "matrix" in n:
        return np.array(n["matrix"], float).reshape(4, 4).T
    x, y, z, w = n.get("rotation", (0, 0, 0, 1))
    r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                  [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                  [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    m = np.eye(4)
    m[:3, :3] = r * np.array(n.get("scale", (1, 1, 1)))
    m[:3, 3] = n.get("translation", (0, 0, 0))
    return m


def main():
    src, dst = sys.argv[1], sys.argv[2]
    names = [a for a in sys.argv[3:] if not a.startswith("-")]
    j, b = read_glb(src)
    index = {n.get("name"): i for i, n in enumerate(j["nodes"])}
    for a in sys.argv[3:]:
        if a.startswith("-"):
            gone = index[a[1:]]
            for n in j["nodes"]:
                if gone in n.get("children", []):
                    n["children"].remove(gone)
            print(f"{a[1:]} taken out")
    # Mesh -> its matrix in the model's frame (the model's own yaw and scale do not matter).
    meshes = {}
    for name in names:
        stack = [(index[name], np.eye(4))]
        while stack:
            i, parent = stack.pop()
            n = j["nodes"][i]
            m = parent @ local_matrix(n) if i != index[name] else parent
            if "mesh" in n:
                meshes.setdefault(n["mesh"], (m, name))
            stack += [(c, m) for c in n.get("children", [])]

    size = {}
    for mi, (mat, name) in meshes.items():
        for prim in j["meshes"][mi]["primitives"]:
            a = j["accessors"][prim["attributes"]["POSITION"]]
            corners = np.array([[x, y, z] for x in (a["min"][0], a["max"][0])
                    for y in (a["min"][1], a["max"][1]) for z in (a["min"][2], a["max"][2])])
            w = corners @ mat[:3, :3].T + mat[:3, 3]
            lo, hi = size.get(name, (w.min(0), w.max(0)))
            size[name] = (np.minimum(lo, w.min(0)), np.maximum(hi, w.max(0)))
    global SPACING, EPS
    uses = {}
    for mesh in j["meshes"]:
        for prim in mesh["primitives"]:
            for a in set(list(prim["attributes"].values()) + [prim["indices"]]):
                uses[a] = uses.get(a, 0) + 1
    views = [view_bytes(j, b, i) for i in range(len(j["bufferViews"]))]
    for mi, (mat, name) in sorted(meshes.items()):
        diag = np.linalg.norm(size[name][1] - size[name][0])
        SPACING, EPS = diag * SPACING_SHARE, diag * EPS_SHARE
        for prim in j["meshes"][mi]["primitives"]:
            att = prim["attributes"]
            if any(uses[a] > 1 for a in list(att.values()) + [prim["indices"]]):
                continue # data shared with another part: left as it is
            pos = accessor(j, b, att["POSITION"]).astype(np.float64)
            tris = accessor(j, b, prim["indices"]).reshape(-1, 3).astype(np.int64)
            before = len(tris)
            world = pos @ mat[:3, :3].T + mat[:3, 3]
            tris = tris[clean(world, tris)]
            cleaned = len(tris)
            tris = tris[visible_triangles(world, tris)]
            used = np.unique(tris)
            remap = np.full(len(pos), -1)
            remap[used] = np.arange(len(used))
            for ai in set(att.values()):
                data = accessor(j, b, ai)[used]
                a = j["accessors"][ai]
                views[a["bufferView"]] = data.tobytes()
                a["count"] = len(data)
                a.pop("byteOffset", None)
                if "min" in a:
                    a["min"] = data.min(0).tolist()
                    a["max"] = data.max(0).tolist()
            idx = remap[tris].astype(np.uint16 if len(used) < 65536 else np.uint32).ravel()
            a = j["accessors"][prim["indices"]]
            views[a["bufferView"]] = idx.tobytes()
            a["count"] = len(idx)
            a["componentType"] = 5123 if idx.dtype == np.uint16 else 5125
            a.pop("byteOffset", None)
            a["min"], a["max"] = [int(idx.min())], [int(idx.max())]
            print(f"{j['meshes'][mi].get('name')}: {before} -> {cleaned} (clean) -> {len(tris)} triangles,"
                  f" {len(pos)} -> {len(used)} vertices")

    blob = bytearray()
    for i, v in enumerate(views):
        bv = j["bufferViews"][i]
        bv["byteOffset"] = len(blob)
        bv["byteLength"] = len(v)
        blob += v
        blob += b"\0" * (-len(blob) % 4)
    j["buffers"][0]["byteLength"] = len(blob)
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    total = 12 + 8 + len(js) + 8 + len(blob)
    with open(dst, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(blob), 0x004E4942) + bytes(blob))


if __name__ == "__main__":
    main()
