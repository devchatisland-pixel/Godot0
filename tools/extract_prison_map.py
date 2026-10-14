"""Flattens the Sketchfab prison map (map_-_prison_breakout_sniper_escape.glb) into one glb holding
only the prison itself: every mesh whose material is not the sky or the terrain, with its world
transform baked into a flat node. Output: FREEMODELS/curated/prison_map.glb (one root node "prison_map").
  python tools/extract_prison_map.py <input.glb> <output.glb>
"""
import json, sys, copy
import numpy as np
sys.path.insert(0, __file__.rsplit("tools", 1)[0] + "tools")
from split_glb_pack import read_glb, write_glb, build

DROP = {"desert_skybox", "terrain_grass_dirt"}

def local(n):
    if "matrix" in n:
        return np.array(n["matrix"]).reshape(4, 4).T
    x, y, z, w = n.get("rotation", [0, 0, 0, 1])
    R = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                  [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                  [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
    T = np.eye(4)
    T[:3, :3] = R * np.array(n.get("scale", [1, 1, 1]))
    T[:3, 3] = n.get("translation", [0, 0, 0])
    return T

def main(src, dst):
    j, binary = read_glb(src)
    flat = []
    def walk(i, M):
        n = j["nodes"][i]
        M = M @ local(n)
        if "mesh" in n:
            prims = j["meshes"][n["mesh"]]["primitives"]
            keep = [p for p in prims if j["materials"][p["material"]]["name"] not in DROP]
            # Only the walled compound (about +-76 units round its middle): the road and the outbuilding to the east are left out.
            pts = [(M @ np.array([*c, 1.0]))[:3] for p in prims for c in
                   [tuple((j["accessors"][p["attributes"]["POSITION"]]["min"][k] + j["accessors"][p["attributes"]["POSITION"]]["max"][k]) / 2 for k in range(3))]]
            cx, cz = pts[0][0], pts[0][2]
            if keep and len(keep) == len(prims) and abs(cx) <= 76 and abs(cz) <= 76:
                flat.append({"name": n.get("name", "m%d" % i), "mesh": n["mesh"],
                             "matrix": [float(v) for v in M.T.flatten()]})
        for c in n.get("children", []):
            walk(c, M)
    for r in j["scenes"][0]["nodes"]:
        walk(r, np.eye(4))
    base = len(j["nodes"])
    j["nodes"] = j["nodes"] + flat
    out, out_bin = build(j, binary, list(range(base, base + len(flat))), {"name": "prison_map"})
    write_glb(dst, out, out_bin)
    print("nodes kept", len(flat), "bytes", len(out_bin))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
