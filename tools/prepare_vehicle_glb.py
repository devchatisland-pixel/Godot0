"""Turns a downloaded vehicle glb into a catalog vehicle (vehicles/CATALOG.md: front -Z, up +Y, origin
at the middle of the ground, metres): the node transforms are baked into flat nodes, the model is scaled,
moved onto the ground, centred and optionally turned half a circle.
  python tools/prepare_vehicle_glb.py <in.glb> <out.glb> <scale> [--turn]
"""
import sys, math
import numpy as np
sys.path.insert(0, __file__.rsplit("tools", 1)[0] + "tools")
from split_glb_pack import read_glb, write_glb, build
from extract_prison_map import local

def main(src, dst, scale, turn):
    j, binary = read_glb(src)
    flat = []
    def walk(i, M):
        n = j["nodes"][i]
        M = M @ local(n)
        if "mesh" in n:
            flat.append((n.get("name", "m%d" % i), n["mesh"], M))
        for c in n.get("children", []):
            walk(c, M)
    for r in j["scenes"][0]["nodes"]:
        walk(r, np.eye(4))
    S = np.diag([scale, scale, scale, 1.0])
    pts = []
    for _, m, M in flat:
        for p in j["meshes"][m]["primitives"]:
            a = j["accessors"][p["attributes"]["POSITION"]]
            for c in [(x, y, z) for x in (a["min"][0], a["max"][0]) for y in (a["min"][1], a["max"][1]) for z in (a["min"][2], a["max"][2])]:
                pts.append((S @ M @ np.array([*c, 1.0]))[:3])
    pts = np.array(pts)
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    T = np.eye(4)
    T[:3, 3] = [-(lo[0] + hi[0]) / 2, -lo[1], -(lo[2] + hi[2]) / 2]
    if turn:
        T = np.array([[-1, 0, 0, 0], [0, 1, 0, 0], [0, 0, -1, 0], [0, 0, 0, 1.0]]) @ T
    base = len(j["nodes"])
    for k, (name, m, M) in enumerate(flat):
        F = T @ S @ M
        j["nodes"].append({"name": name, "mesh": m, "matrix": [float(v) for v in F.T.flatten()]})
    out, out_bin = build(j, binary, list(range(base, base + len(flat))), {"name": "prison_van"})
    write_glb(dst, out, out_bin)
    print("size (m)", np.round(hi - lo, 2))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], float(sys.argv[3]), "--turn" in sys.argv)
