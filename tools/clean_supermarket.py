"""Strips the text off the "Supermarket building" model (Randonavt, CC-BY-4.0,
https://sketchfab.com/3d-models/supermarket-building-09133ba8b8a149cf9590d747c45c5f16).

    python tools/clean_supermarket.py <supermarket_building.glb> <out.glb>

Keeps the building, the glass front doors and the lamps; removes the "OKO MARKET" sign (its
box, every face) and the four promo posters on the side wall. They are faces of the one mesh
that sample their own regions of the texture atlas, so they are found by their texture
coordinates (and the sign box by its place). The posters fill openings of the wall, so their
faces stay: their part of the atlas is painted with the white wall tiles, at the scale of the
wall, and they read as plain wall. The sign's part of the atlas is painted over too, so no
text is left in the texture (a small lettering in a photo of the shop inside is blurred).
"""
import io
import json
import struct
import sys

import numpy as np
from PIL import Image, ImageFilter

# Atlas regions (u0, v0, u1, v1, glTF uv: v grows downwards) holding text.
POSTERS = (0.19, 0.71, 1.0, 1.0)
SIGN = (0.49, 0.0, 0.65, 0.155)
# A small "COFFEE" lettering on the wall of a shop interior photo: blurred away.
BLUR = (0.615, 0.565, 0.65, 0.6)
# A plain stretch of the white wall tiles, painted over the text regions.
WALL_TILE = (0.0, 0.0, 0.24, 0.24)


def read_glb(path):
    d = open(path, "rb").read()
    n = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + n])
    off = 20 + n
    bn = struct.unpack("<I", d[off:off + 4])[0]
    return j, bytearray(d[off + 8:off + 8 + bn])


def accessor(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[a["componentType"]]
    k = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 0) or k * np.dtype(dt).itemsize
    raw = np.frombuffer(bytes(b), np.uint8, count=stride * (a["count"] - 1) + k * np.dtype(dt).itemsize, offset=off)
    rows = [raw[s * stride:s * stride + k * np.dtype(dt).itemsize].view(dt) for s in range(a["count"])]
    return np.array(rows).reshape(a["count"], k)


def inside(uv, r):
    return (uv[:, 0] > r[0]) & (uv[:, 0] < r[2]) & (uv[:, 1] > r[1]) & (uv[:, 1] < r[3])


def main():
    j, b = read_glb(sys.argv[1])
    prim = j["meshes"][0]["primitives"][0]
    pos = accessor(j, b, prim["attributes"]["POSITION"])
    uv = accessor(j, b, prim["attributes"]["TEXCOORD_0"])
    tris = accessor(j, b, prim["indices"]).reshape(-1, 3)
    cuv = uv[tris].mean(1)
    text = inside(cuv, SIGN)
    # Every face of the sign box (sides and back too), found by its place.
    sign_pts = pos[tris[inside(cuv, SIGN)]].reshape(-1, 3)
    lo, hi = sign_pts.min(0) - 0.05, sign_pts.max(0) + 0.05
    lo[0] -= 0.6  # the box is thin along x: take its back face as well
    cp = pos[tris]
    text |= np.all((cp > lo) & (cp < hi), axis=(1, 2))
    keep = tris[~text]
    print("faces removed: %d of %d" % (text.sum(), len(tris)))

    # New index buffer appended to the binary chunk.
    ia = j["accessors"][prim["indices"]]
    data = keep.astype(np.uint32).tobytes()
    b += b"\0" * (-len(b) % 4)
    j["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": len(data), "target": 34963})
    b += data
    j["accessors"].append({"bufferView": len(j["bufferViews"]) - 1, "componentType": 5125,
                           "count": int(keep.size), "type": "SCALAR"})
    prim["indices"] = len(j["accessors"]) - 1
    del ia

    # Wall tile density (atlas units per model unit along the wall height), from the faces
    # using the wall tile, and the atlas rect and size (model units) of each poster.
    wall = inside(cuv, WALL_TILE)
    dens = []
    for t in tris[wall]:
        p, q = pos[t], uv[t]
        for a, c in ((0, 1), (1, 2), (0, 2)):
            dp, du = np.linalg.norm(p[a] - p[c]), np.linalg.norm(q[a] - q[c])
            if dp > 1.0:
                dens.append(du / dp)
    density = float(np.median(dens))
    # Each poster: its atlas rect and how many atlas units one model unit takes along u and v
    # (from its edges that run along one atlas axis only).
    posters = []
    for t in tris[inside(cuv, POSTERS)]:
        p, q = pos[t], uv[t]
        rate = [0.0, 0.0]
        for a, c in ((0, 1), (1, 2), (0, 2)):
            dp = np.linalg.norm(p[a] - p[c])
            du = np.abs(q[a] - q[c])
            for k in (0, 1):
                if dp > 1e-6 and du[1 - k] < 1e-4 and du[k] > 1e-4:
                    rate[k] = du[k] / dp
        if rate[0] > 0 and rate[1] > 0:
            posters.append((q.min(0), q.max(0), rate))

    # Paint the text regions of every atlas image with the wall tile.
    for im in j["images"]:
        bv = j["bufferViews"][im["bufferView"]]
        o = bv.get("byteOffset", 0)
        img = Image.open(io.BytesIO(bytes(b[o:o + bv["byteLength"]]))).convert("RGBA")
        w, h = img.size
        px = lambda r: (int(r[0] * w), int(r[1] * h), int(r[2] * w), int(r[3] * h))
        tile = img.crop(px(WALL_TILE))
        for r in (POSTERS, SIGN):
            x0, y0, x1, y1 = px(r)
            for y in range(y0, y1, tile.height):
                for x in range(x0, x1, tile.width):
                    img.paste(tile.crop((0, 0, min(tile.width, x1 - x), min(tile.height, y1 - y))), (x, y))
        x0, y0, x1, y1 = px(BLUR)
        img.paste(img.crop((x0, y0, x1, y1)).filter(ImageFilter.GaussianBlur(8)), (x0, y0))
        # The posters: the wall tile repeats every `side / density` model units, as on the wall.
        side = WALL_TILE[2] - WALL_TILE[0]
        for lo_uv, hi_uv, rate in posters:
            x0, y0, x1, y1 = px((lo_uv[0], lo_uv[1], hi_uv[0], hi_uv[1]))
            tw = max(4, round(side / density * rate[0] * w))
            th = max(4, round(side / density * rate[1] * h))
            t2 = tile.resize((tw, th))
            for y in range(y0, y1, th):
                for x in range(x0, x1, tw):
                    img.paste(t2.crop((0, 0, min(tw, x1 - x), min(th, y1 - y))), (x, y))
        out = io.BytesIO()
        img.save(out, "PNG", optimize=True)
        data = out.getvalue()
        b += b"\0" * (-len(b) % 4)
        j["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": len(data)})
        b += data
        im["bufferView"] = len(j["bufferViews"]) - 1
        im["mimeType"] = "image/png"

    # Drop the buffer views nothing points at any more (old indices and images).
    used = sorted({a["bufferView"] for a in j["accessors"]} | {im["bufferView"] for im in j["images"]})
    nb = bytearray()
    remap = {}
    for k in used:
        bv = dict(j["bufferViews"][k])
        o = bv.get("byteOffset", 0)
        chunk = b[o:o + bv["byteLength"]]
        nb += b"\0" * (-len(nb) % 4)
        bv["byteOffset"] = len(nb)
        nb += chunk
        remap[k] = len(remap)
        j["bufferViews"][k] = bv
    j["bufferViews"] = [j["bufferViews"][k] for k in used]
    for a in j["accessors"]:
        a["bufferView"] = remap[a["bufferView"]]
    for im in j["images"]:
        im["bufferView"] = remap[im["bufferView"]]
    nb += b"\0" * (-len(nb) % 4)
    j["buffers"] = [{"byteLength": len(nb)}]

    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    with open(sys.argv[2], "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(nb)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(nb), 0x004E4942) + bytes(nb))


if __name__ == "__main__":
    main()
