"""Builds FREEMODELS/curated/eiffel_tower.glb: only the tower of the Sketchfab scene
"LOW_POLY_EIFFEL_TOWER" by Benedico2001 (CC-BY-4.0), without its park (trees, benches, kiosks,
lamps, ground blocks). The scene transforms are baked into the vertices, the tower stands on
y = 0 centred on x / z. One mesh, one material. Size about 11.0 x 27.2 x 11.1.
Run: python tools/make_eiffel_tower.py [path to low_poly_eiffel_tower.glb]"""
import json, struct, sys, os
import numpy as np

SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Downloads/low_poly_eiffel_tower (1).glb")
OUT = os.path.join(os.path.dirname(__file__), "..", "FREEMODELS", "curated", "eiffel_tower.glb")
TOWER = "Tour_Eiffel"       # name prefix of the tower node

data = open(SRC, "rb").read()
json_len = struct.unpack_from("<I", data, 12)[0]
g = json.loads(data[20:20 + json_len])
BIN = 20 + json_len + 8

def local(nd):
    if "matrix" in nd:
        return np.array(nd["matrix"], float).reshape(4, 4).T
    m = np.eye(4)
    if "scale" in nd:
        m = np.diag(list(nd["scale"]) + [1.0])
    if "rotation" in nd:
        x, y, z, w = nd["rotation"]
        r = np.eye(4)
        r[:3, :3] = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
        m = r @ m
    if "translation" in nd:
        t = np.eye(4)
        t[:3, 3] = nd["translation"]
        m = t @ m
    return m

def read(acc_id):
    a = g["accessors"][acc_id]
    bv = g["bufferViews"][a["bufferView"]]
    dt = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}[a["componentType"]]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[a["type"]]
    off = BIN + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 0) or np.dtype(dt).itemsize * n
    raw = np.ndarray((a["count"],), dtype=np.dtype((np.void, stride)), buffer=data, offset=off)
    return np.frombuffer(raw.tobytes(), dtype=dt).reshape(a["count"], -1)[:, :n]

parent = {c: i for i, nd in enumerate(g["nodes"]) for c in nd.get("children", [])}
tower = next(i for i, nd in enumerate(g["nodes"]) if nd.get("name", "").startswith(TOWER))

# world matrix of the tower node, then down to its meshes
chain = [tower]
while chain[-1] in parent:
    chain.append(parent[chain[-1]])
world = np.eye(4)
for i in reversed(chain):
    world = world @ local(g["nodes"][i])

V, N, I = [], [], []
material = None

def collect(i, m):
    global material
    nd = g["nodes"][i]
    if "mesh" in nd:
        rot = np.linalg.inv(m[:3, :3]).T
        flip = np.linalg.det(m[:3, :3]) < 0
        for p in g["meshes"][nd["mesh"]]["primitives"]:
            pos = read(p["attributes"]["POSITION"]).astype(float)
            nrm = read(p["attributes"]["NORMAL"]).astype(float) @ rot.T
            idx = read(p["indices"]).reshape(-1, 3).astype(np.int64)
            if flip:
                idx = idx[:, ::-1]
            base = sum(len(v) for v in V)
            V.append(pos @ m[:3, :3].T + m[:3, 3])
            N.append(nrm / np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-12))
            I.append(idx + base)
            material = g["materials"][p["material"]]
    for c in nd.get("children", []):
        collect(c, m @ local(g["nodes"][c]))

collect(tower, world)
V, N, I = np.vstack(V), np.vstack(N), np.vstack(I)

# stand on y = 0, centred on x / z
lo, hi = V.min(0), V.max(0)
V -= [(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2]

V = V.astype(np.float32)
N = N.astype(np.float32)
I = I.astype(np.uint16 if len(V) < 65536 else np.uint32).reshape(-1)
blobs = [V.tobytes(), N.tobytes(), I.tobytes()]
blobs = [b + b"\0" * (-len(b) % 4) for b in blobs]
offs = [0, len(blobs[0]), len(blobs[0]) + len(blobs[1])]

pbr = material["pbrMetallicRoughness"]
out = {
    "asset": {"version": "2.0", "generator": "tools/make_eiffel_tower.py", "extras": g["asset"].get("extras", {})},
    "scene": 0,
    "scenes": [{"nodes": [0]}],
    "nodes": [{"name": "eiffel_tower", "mesh": 0}],
    "meshes": [{"name": "eiffel_tower", "primitives": [
        {"attributes": {"POSITION": 0, "NORMAL": 1}, "indices": 2, "material": 0}]}],
    "materials": [{"name": "eiffel_iron", "doubleSided": material.get("doubleSided", False),
                   "pbrMetallicRoughness": {"baseColorFactor": pbr["baseColorFactor"],
                                            "metallicFactor": pbr.get("metallicFactor", 1.0),
                                            "roughnessFactor": pbr.get("roughnessFactor", 1.0)}}],
    "buffers": [{"byteLength": sum(len(b) for b in blobs)}],
    "bufferViews": [
        {"buffer": 0, "byteOffset": offs[0], "byteLength": len(blobs[0]), "target": 34962},
        {"buffer": 0, "byteOffset": offs[1], "byteLength": len(blobs[1]), "target": 34962},
        {"buffer": 0, "byteOffset": offs[2], "byteLength": len(blobs[2]), "target": 34963}],
    "accessors": [
        {"bufferView": 0, "componentType": 5126, "count": len(V), "type": "VEC3",
         "min": V.min(0).tolist(), "max": V.max(0).tolist()},
        {"bufferView": 1, "componentType": 5126, "count": len(N), "type": "VEC3"},
        {"bufferView": 2, "componentType": 5123 if I.dtype == np.uint16 else 5125, "count": len(I), "type": "SCALAR"}],
}
js = json.dumps(out, separators=(",", ":")).encode()
js += b" " * (-len(js) % 4)
body = b"".join(blobs)
with open(OUT, "wb") as f:
    f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(body)))
    f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
    f.write(struct.pack("<II", len(body), 0x004E4942) + body)
size = V.max(0) - V.min(0)
print("eiffel_tower.glb: %d vertices, %d triangles, size %.2f x %.2f x %.2f, %d kB"
      % (len(V), len(I) // 3, size[0], size[1], size[2], os.path.getsize(OUT) // 1024))
