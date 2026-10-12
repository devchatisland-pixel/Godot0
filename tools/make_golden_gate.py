"""Builds FREEMODELS/curated/golden_gate.glb: a hand-modelled low-poly Golden Gate bridge
(replaces the 160k-triangle scan). Size 30 x 5.83 x 2.57, deck 1.98 wide with its top at
0.343 of the height (see FogIsland). One mesh, one material, flat-shaded.
Run: python tools/make_golden_gate.py"""
import json, struct, math, os
import numpy as np

V, N, I = [], [], []

def quad(a, b, c, d):
    a, b, c, d = map(np.array, (a, b, c, d))
    n = np.cross(b - a, c - a)
    n = n / (np.linalg.norm(n) or 1)
    base = len(V)
    V.extend([a, b, c, d]); N.extend([n] * 4)
    I.extend([base, base + 1, base + 2, base, base + 2, base + 3])

def frustum(cx, cz, y0, y1, b, t):
    """b / t = (half x, half z) at the bottom / top."""
    p = lambda y, h, sx, sz: (cx + sx * h[0], y, cz + sz * h[1])
    bot = [p(y0, b, sx, sz) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    top = [p(y1, t, sx, sz) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    quad(bot[0], bot[3], bot[2], bot[1])      # bottom
    quad(top[0], top[1], top[2], top[3])      # top
    for i in range(4):
        j = (i + 1) % 4
        quad(bot[i], bot[j], top[j], top[i])

def box(x0, x1, y0, y1, z0, z1):
    frustum((x0 + x1) / 2, (z0 + z1) / 2, y0, y1, ((x1 - x0) / 2, (z1 - z0) / 2), ((x1 - x0) / 2, (z1 - z0) / 2))

def tube(pts, r, sides=5):
    pts = [np.array(p, float) for p in pts]
    rings = []
    for k, p in enumerate(pts):
        d = pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]
        d /= np.linalg.norm(d)
        u = np.cross(d, (0, 0, 1)); u /= np.linalg.norm(u)
        w = np.cross(d, u)
        rings.append([p + r * (math.cos(a) * u + math.sin(a) * w)
                      for a in (2 * math.pi * i / sides for i in range(sides))])
    for k in range(len(pts) - 1):
        for i in range(sides):
            j = (i + 1) % sides
            quad(rings[k][i], rings[k + 1][i], rings[k + 1][j], rings[k][j])

L, H = 15.0, 5.83
DECK = 0.343 * H            # deck top
TX = 9.75                   # tower x
CZ = 1.06                   # cable / tower-leg z
TOP = 5.54                  # cable height at the tower top
MID = DECK + 0.32           # cable height at mid-span
END = DECK + 0.1            # cable height at the anchorages

# deck: slab, stiffening girder, kerb rails
box(-L, L, DECK - 0.07, DECK, -0.99, 0.99)
box(-L, L, DECK - 0.30, DECK - 0.07, -0.80, 0.80)
for s in (-1, 1):
    box(-L, L, DECK, DECK + 0.07, s * 0.95 - 0.025, s * 0.95 + 0.025)
for s in (-1, 1):
    box(s * L - (0.5 if s > 0 else -0.5) * 1, s * L, 0.9, DECK - 0.30, -0.8, 0.8) if False else None

for s in (-1, 1):
    x = s * TX
    # pier + stepped base
    box(x - 0.6, x + 0.6, 0.0, 0.45, -1.285, 1.285)
    frustum(x, 0, 0.45, DECK - 0.30, (0.5, 1.15), (0.38, 0.95))
    for z in (-CZ, CZ):
        frustum(x, z, 0.45, TOP + 0.2, (0.17, 0.15), (0.10, 0.10))     # tower leg
        box(x - 0.14, x + 0.14, TOP + 0.2, TOP + 0.29, z - 0.13, z + 0.13)  # saddle cap
    for y, h in ((DECK + 0.45, 0.1), (3.9, 0.09), (4.8, 0.09), (TOP + 0.1, 0.09)):   # portal struts
        box(x - 0.1, x + 0.1, y, y + h * 1.4, -CZ, CZ)
    # side-span anchorage block
    box(s * L - (0.45 if s > 0 else 0), s * L + (0 if s > 0 else 0.45), DECK - 0.7, DECK - 0.30, -0.8, 0.8)

def cable_y(x):
    ax = abs(x)
    if ax <= TX:
        return TOP - (TOP - MID) * (1 - (ax / TX) ** 2)
    t = (ax - TX) / (L - TX)
    return TOP + (END - TOP) * t - 0.12 * math.sin(math.pi * t)

xs = [-L + i * 0.5 for i in range(int(2 * L / 0.5) + 1)]
main_xs = [-TX + i * 0.8125 for i in range(25)]
for z in (-CZ, CZ):
    for seg in ([x for x in np.linspace(-L, -TX, 7)], main_xs, [x for x in np.linspace(TX, L, 7)]):
        tube([(x, cable_y(x), z) for x in seg], 0.045)
    # suspenders
    for x in list(np.arange(-L + 0.6, -TX - 0.2, 0.6)) + list(np.arange(-TX + 0.4, TX - 0.3, 0.8)) + list(np.arange(TX + 0.4, L - 0.3, 0.6)):
        if abs(abs(x) - TX) < 0.3:
            continue
        y1 = cable_y(x)
        box(x - 0.012, x + 0.012, DECK, y1, z - 0.012, z + 0.012)

V = np.array(V, np.float32); Nn = np.array(N, np.float32); I = np.array(I, np.uint32)
# centre on x/z, bottom at y = 0
V[:, 0] -= (V[:, 0].min() + V[:, 0].max()) / 2
V[:, 2] -= (V[:, 2].min() + V[:, 2].max()) / 2
V[:, 1] -= V[:, 1].min()
print("tris", len(I) // 3, "size", V.max(0) - V.min(0))

blob = V.tobytes() + Nn.tobytes() + I.tobytes()
j = {
    "asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}],
    "nodes": [{"name": "golden_gate", "mesh": 0}],
    "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1}, "indices": 2, "material": 0}]}],
    "materials": [{"name": "gate_red", "doubleSided": True, "pbrMetallicRoughness": {
        "baseColorFactor": [0.56, 0.035, 0.012, 1], "metallicFactor": 0.0, "roughnessFactor": 0.7}}],
    "buffers": [{"byteLength": len(blob)}],
    "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": V.nbytes},
                    {"buffer": 0, "byteOffset": V.nbytes, "byteLength": Nn.nbytes},
                    {"buffer": 0, "byteOffset": V.nbytes + Nn.nbytes, "byteLength": I.nbytes}],
    "accessors": [
        {"bufferView": 0, "componentType": 5126, "count": len(V), "type": "VEC3", "min": V.min(0).tolist(), "max": V.max(0).tolist()},
        {"bufferView": 1, "componentType": 5126, "count": len(V), "type": "VEC3"},
        {"bufferView": 2, "componentType": 5125, "count": len(I), "type": "SCALAR"}],
}
js = json.dumps(j).encode(); js += b" " * (-len(js) % 4); blob += b"\0" * (-len(blob) % 4)
out = struct.pack("<III", 0x46546C67, 2, 28 + len(js) + len(blob)) + struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(blob), 0x004E4942) + blob
open(os.path.join(os.path.dirname(__file__), "..", "FREEMODELS", "curated", "golden_gate.glb"), "wb").write(out)
