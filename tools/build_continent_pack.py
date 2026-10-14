#!/usr/bin/env python3
"""Builds the "Continent" building pack from procedural_city_7.glb (Sketchfab, abhayexe).

Usage:  python tools/build_continent_pack.py [--src <procedural_city_7.glb>] [--tex 512]
Needs:  numpy, scipy, Pillow.

The source is one big city: the ground, roads, sidewalks, street props and trees are in the
first group, the buildings are in the three "CityGen Buildings" groups, merged by material over
the whole city. Only the buildings are kept (no roads, no ground, no street props). They are
split back into single buildings:

  1. the triangles are welded and cut into connected pieces;
  2. every big piece is an anchor, anchors that overlap on the ground (towers stacked on their
     podium, roof levels) form one building;
  3. the small pieces (roof units, balconies, fire escapes) go to the building whose footprint
     contains them.

Output:
  FREEMODELS/curated/continent_buildings.glb + .models.json: the whole pack, full detail (cat
  "CONTINENT_PACK", which is no game category: the game ignores this file);
  FREEMODELS/curated/continent_city.glb + .models.json: the buildings of the continent
  (GAME_IDS), lighter for the game: small rooftop units, fire escapes and the like dropped,
  vertices welded, small textures. Two categories (CONTINENT, CONTINENT2): the library keeps at
  most 24 models per category.
"""
import json, os, sys
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_wave16_models as B

ROOT = B.ROOT
SRC = os.path.join(os.path.expanduser("~"), "Downloads", "procedural_city_7.glb")
UNIT = 16.0          # source units per cell: one scale for the whole pack, so sizes stay relative
GAME_IDS = [1, 2, 3, 4, 5, 6, 7, 8, 12, 14, 15, 16, 18, 19, 20, 21, 22, 23, 24, 28, 29, 30, 31, 32, 34, 36]
GAME_DROP = ["CityGenAC", "firescape", "rooftop_tank", "solar", "CityGenVent", "CityGenbasic_rough_metal_dark"]
GAME_WELD = 0.012    # cells
GAME_TEX = 256
ANCHOR_TRIS = 300    # a piece with at least this many triangles decides the buildings
OVERLAP = 0.6        # share of the smaller footprint two anchors must share to be one building


def clusters(parts):
    """Per part: the building number of every triangle (-1: dropped)."""
    allp = np.concatenate([p["pos"] for p in parts])
    off = np.cumsum([0] + [len(p["pos"]) for p in parts])
    key = np.round(allp / 0.02).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.ravel()
    tri = np.concatenate([p["idx"] + o for p, o in zip(parts, off)])
    tw = inv[tri]
    n = inv.max() + 1
    m = coo_matrix((np.ones(len(tw) * 2), (np.concatenate([tw[:, 0], tw[:, 1]]),
                                           np.concatenate([tw[:, 1], tw[:, 2]]))), shape=(n, n))
    k, lab = connected_components(m, directed=False)
    piece = lab[tw[:, 0]]
    count = np.bincount(piece, minlength=k)
    lo = np.full((k, 3), 1e9)
    hi = np.full((k, 3), -1e9)
    vi, pc = tri.ravel(), np.repeat(piece, 3)
    for d in range(3):
        np.minimum.at(lo[:, d], pc, allp[vi, d])
        np.maximum.at(hi[:, d], pc, allp[vi, d])
    anchors = np.where(count >= ANCHOR_TRIS)[0]
    a_lo, a_hi = lo[anchors][:, [0, 2]], hi[anchors][:, [0, 2]]
    area = np.prod(a_hi - a_lo, 1)
    par = list(range(len(anchors)))

    def find(a):
        while par[a] != a:
            par[a] = par[par[a]]
            a = par[a]
        return a
    for i in range(len(anchors)):
        ix = np.minimum(a_hi[i, 0], a_hi[:, 0]) - np.maximum(a_lo[i, 0], a_lo[:, 0])
        iz = np.minimum(a_hi[i, 1], a_hi[:, 1]) - np.maximum(a_lo[i, 1], a_lo[:, 1])
        ov = np.clip(ix, 0, None) * np.clip(iz, 0, None)
        for j in np.where(ov / np.minimum(area[i], area) > OVERLAP)[0]:
            par[find(i)] = find(j)
    roots = sorted(set(find(i) for i in range(len(anchors))))
    # Building footprints, then every piece goes to the smallest footprint holding its middle.
    b_lo = np.array([a_lo[[i for i in range(len(anchors)) if find(i) == r]].min(0) for r in roots])
    b_hi = np.array([a_hi[[i for i in range(len(anchors)) if find(i) == r]].max(0) for r in roots])
    b_area = np.prod(b_hi - b_lo, 1)
    owner = np.full(k, -1)
    for i, a in enumerate(anchors):
        owner[a] = roots.index(find(i))
    mid = (lo + hi) * 0.5
    for p in np.where(owner < 0)[0]:
        x, z = mid[p, 0], mid[p, 2]
        inside = np.where((b_lo[:, 0] <= x) & (x <= b_hi[:, 0]) & (b_lo[:, 1] <= z) & (z <= b_hi[:, 1]))[0]
        if len(inside):
            owner[p] = inside[np.argmin(b_area[inside])]
    tri_owner = owner[piece]
    res, o = [], 0
    for p in parts:
        res.append(tri_owner[o:o + len(p["idx"])])
        o += len(p["idx"])
    return res, len(roots)


def take(part, mask):
    used, idx = np.unique(part["idx"][mask], return_inverse=True)
    q = dict(part)
    q["idx"] = idx.reshape(-1, 3)
    q["pos"] = part["pos"][used].copy()
    q["nrm"] = None if part["nrm"] is None else part["nrm"][used].copy()
    q["uv"] = part["uv"][used]
    return q


def main():
    args = sys.argv[1:]
    src, tex = SRC, 512
    if "--src" in args:
        src = args[args.index("--src") + 1]
    if "--tex" in args:
        tex = int(args[args.index("--tex") + 1])
    g = B.Glb(src)
    parts = [p for p in g.parts(tex) if "CityGen Buildings" in p["path"]]
    print("building parts:", len(parts), "triangles:", B.triangles(parts))
    owners, n = clusters(parts)
    items, rows = [], []
    for b in range(n):
        mine = [take(p, o == b) for p, o in zip(parts, owners) if (o == b).any()]
        if not mine or B.triangles(mine) < 200:
            continue
        lo, hi = B.box(mine)
        if min(hi[0] - lo[0], hi[2] - lo[2]) < 0.3 * UNIT:
            continue   # a flat facade panel, not a building
        rows.append({"centre": [(lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2], "size": (hi - lo).tolist(),
                     "parts": mine})
    # Names run row by row over the city map (north to south, then west to east).
    rows.sort(key=lambda r: (round(r["centre"][1] / 60.0), r["centre"][0]))
    manifest, info = [], []
    for i, r in enumerate(rows, 1):
        name = "continent_%02d" % i
        size = B.shape(r["parts"], {"scale": 1.0 / UNIT})
        merged = B.merged(r["parts"])
        items.append((name, merged))
        manifest.append({"cat": "CONTINENT_PACK", "node": name})
        info.append({"id": name, "cells": [round(float(x), 2) for x in size], "tris": B.triangles(merged)})
        print("%-14s %5.2f x %5.2f x %5.2f cells  %7d tris" % (name, *size, B.triangles(merged)))
    out = os.path.join(ROOT, "FREEMODELS", "curated", "continent_buildings")
    B.write_glb(out + ".glb", "continent_buildings", items)
    with open(out + ".models.json", "w", newline="\n") as f:
        json.dump({"file": "continent_buildings.glb", "models": manifest}, f, indent="\t")
        f.write("\n")
    print("wrote", out + ".glb", "%.1f MB" % (os.path.getsize(out + ".glb") / 1048576), len(items), "buildings")
    build_game(rows)


def build_game(rows):
    """continent_city.glb: GAME_IDS only, in the numbering of the full pack."""
    items, manifest, total = [], [], 0
    small = {}
    for i, r in enumerate(rows, 1):
        if i not in GAME_IDS:
            continue
        # The parts were already turned and stood on y = 0 by main(); keep what the game needs.
        parts = [p for p in r["parts"] if not any(p["mat"]["name"].startswith(d) for d in GAME_DROP)]
        parts = B.welded(parts, GAME_WELD)
        parts = [p for p in parts if len(p["idx"])]
        for p in parts:
            m = p["mat"]
            if m.get("image") is not None and max(m["image"].size) > GAME_TEX:
                m = dict(m)
                key = id(m["image"])
                small.setdefault(key, B._small(m["image"], GAME_TEX))
                m["image"] = small[key]
                p["mat"] = m
        parts = B.merged(parts)
        name = "continent_%02d" % i
        items.append((name, parts))
        manifest.append({"cat": "CONTINENT" if len(manifest) < 13 else "CONTINENT2", "node": name})
        total += B.triangles(parts)
        lo, hi = B.box(parts)
        print("game %-14s %6d tris   \"%s\": Vector3(%.2f, %.2f, %.2f)," % (name, B.triangles(parts), name,
              hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]))
    out = os.path.join(ROOT, "FREEMODELS", "curated", "continent_city")
    B.write_glb(out + ".glb", "continent_city", items)
    with open(out + ".models.json", "w", newline="\n") as f:
        json.dump({"file": "continent_city.glb", "models": manifest}, f, indent="\t")
        f.write("\n")
    print("wrote", out + ".glb", "%.1f MB" % (os.path.getsize(out + ".glb") / 1048576), len(items), "buildings,", total, "tris")


if __name__ == "__main__":
    main()
