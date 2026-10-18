"""Lighter Eiffel tower (eiffel_tower.glb): the thin beams of the lattice become flat ribbons.

    python tools/simplify_eiffel.py <in.glb> <out.glb>

The tower is 671 little box beams (12 triangles each, about 0.09 thick: 2 to 3 pixels at the
closest zoom, under one at the usual one) and some plates. The city camera never turns (orthographic,
30 degrees down, looking along -x -z), and the tower faces south (no turn), so a beam seen from
there is a strip of the width its box shows to the camera: each thin beam is replaced by that
strip, 2 triangles instead of 12 (the material is made double sided so that the strip is
drawn from both sides, and the shadow pass sees it too). Plates and big parts are kept.
Needs numpy.
"""
import json
import struct
import sys
from collections import Counter

import numpy as np

# Direction from the tower to the camera (model space, the tower facing south: no turn).
PITCH, YAW = np.radians(30), np.radians(45)
VIEW = np.array([np.cos(PITCH) * np.sin(YAW), np.sin(PITCH), np.cos(PITCH) * np.cos(YAW)])
BEAM_TRIS = 12
# Share kept of the upward lean of the shading normal (the strips would look brighter than the boxes).
SHADE_UP = float(__import__('os').environ.get('SHADE_UP', '0.0'))
MAX_THICKNESS = 0.16
COMP = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}
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


def ribbon(pts, shade):
    """The strip a beam shows to the camera, or None when it is not a thin beam. `shade` is the
    mean normal of the faces of the box that the camera sees: the strip is lit like them."""
    c = pts - pts.mean(0)
    _, _, vt = np.linalg.svd(c, full_matrices=False)
    axis = vt[0]
    along = c @ axis
    side = c - np.outer(along, axis)
    if np.linalg.norm(side, axis=1).max() * 2 > MAX_THICKNESS * 1.6:
        return None
    w = np.cross(axis, VIEW)
    if np.linalg.norm(w) < 0.15:
        return None   # a beam pointing at the camera: the box stays
    w /= np.linalg.norm(w)
    across = c @ w
    n = np.cross(w, axis)
    n /= np.linalg.norm(n)
    if np.dot(n, VIEW) < 0:
        n = -n
    mid = pts.mean(0)
    a0, a1 = along.min(), along.max()
    h0, h1 = across.min(), across.max()
    # The strip is centred on the beam axis, as wide as the beam shows.
    half = (h1 - h0) / 2
    centre = mid + w * (h0 + h1) / 2
    corners = np.array([centre + axis * a0 - w * half, centre + axis * a1 - w * half,
                        centre + axis * a1 + w * half, centre + axis * a0 + w * half])
    return corners, shade


def main():
    src, dst = sys.argv[1], sys.argv[2]
    j, b = read_glb(src)
    prim = j["meshes"][0]["primitives"][0]
    pos = accessor(j, b, prim["attributes"]["POSITION"]).astype(np.float64)
    nor = accessor(j, b, prim["attributes"]["NORMAL"])
    tris = accessor(j, b, prim["indices"]).reshape(-1, 3).astype(np.int64)
    comp = components(pos, tris)
    sizes = Counter(comp)
    keep = np.ones(len(tris), bool)
    strips = []
    for c, n in sizes.items():
        if n != BEAM_TRIS:
            continue
        m = comp == c
        mine = tris[m]
        face_n = nor[mine[:, 0]].astype(np.float64)
        seen = face_n[face_n @ VIEW > 0.05]
        shade = seen.sum(0) if len(seen) else VIEW
        shade = shade * np.array([1.0, SHADE_UP, 1.0])
        shade = shade / max(np.linalg.norm(shade), 1e-6)
        r = ribbon(pos[np.unique(mine)], shade)
        if r is not None:
            keep &= ~m
            strips.append(r)
    used = np.unique(tris[keep])
    remap = np.full(len(pos), -1)
    remap[used] = np.arange(len(used))
    out_pos = [pos[used]]
    out_nor = [nor[used]]
    out_idx = [remap[tris[keep]].ravel()]
    base = len(used)
    for corners, n in strips:
        out_pos.append(corners)
        out_nor.append(np.tile(n, (4, 1)))
        quad = np.array([0, 1, 2, 0, 2, 3]) + base
        # Front side towards the camera.
        a, b_, c_ = corners[0], corners[1], corners[2]
        if np.dot(np.cross(b_ - a, c_ - a), VIEW) < 0:
            quad = quad.reshape(2, 3)[:, ::-1].ravel()
        out_idx.append(quad)
        base += 4
    P = np.concatenate(out_pos).astype(np.float32)
    N = np.concatenate(out_nor).astype(np.float32)
    I = np.concatenate(out_idx).astype(np.uint32 if len(P) > 65535 else np.uint16)
    print(f"{len(tris)} -> {len(I) // 3} triangles ({len(strips)} beams as strips), "
          f"{len(pos)} -> {len(P)} vertices")

    views = [P.tobytes(), N.tobytes(), I.tobytes()]
    j["bufferViews"] = []
    blob = bytearray()
    for v in views:
        j["bufferViews"].append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(v)})
        blob += v
        blob += bytes(-len(blob) % 4)
    j["buffers"][0]["byteLength"] = len(blob)
    j["accessors"] = [
        {"bufferView": 0, "componentType": 5126, "count": len(P), "type": "VEC3",
         "min": P.min(0).tolist(), "max": P.max(0).tolist()},
        {"bufferView": 1, "componentType": 5126, "count": len(N), "type": "VEC3"},
        {"bufferView": 2, "componentType": 5125 if I.dtype == np.uint32 else 5123, "count": len(I),
         "type": "SCALAR"},
    ]
    prim["attributes"] = {"POSITION": 0, "NORMAL": 1}
    prim["indices"] = 2
    for m in j["materials"]:
        m["doubleSided"] = True
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    with open(dst, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(blob), 0x004E4942) + bytes(blob))


if __name__ == "__main__":
    main()
