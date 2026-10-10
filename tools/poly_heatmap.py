"""Draws the polygon heatmap of the map from the data of tools/poly_heatmap.gd.

Run from the project folder, after the Godot tool:
    python3 tools/poly_heatmap.py [path/to/poly_heatmap.json] [out.png]
Each parcel (lot of a building) is filled by the triangles of everything placed on
it; cells without a parcel (roads, trees, fog island, bridges) by their own
triangles. Darker blue = more triangles. Thin lines: the 32-cell streaming chunks,
with their total in thousands of triangles. Needs numpy and Pillow.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

DEFAULT_JSON = next((p for p in (
    os.path.expanduser("~/.local/share/godot/app_userdata/Isometric Island City/poly_heatmap.json"),
    os.path.expandvars("%APPDATA%/Godot/app_userdata/Isometric Island City/poly_heatmap.json"))
    if os.path.exists(p)), "poly_heatmap.json")
FONTS = [("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
         ("C:/Windows/Fonts/arial.ttf", "C:/Windows/Fonts/arialbd.ttf")]
FONT, BOLD = next(((a, b) for a, b in FONTS if os.path.exists(a)), FONTS[0])
PX = 4
SIDE = 560
TOP = 70
SEA = (226, 233, 240)
LAND = (246, 244, 240)
INK = (30, 34, 40)
MUTED = (110, 116, 126)
GRID = (150, 158, 170)
# Sequential blue ramp, light -> dark (one hue).
RAMP = ["#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#256abf", "#184f95", "#0d366b"]
BINS = [250, 1000, 2500, 5000, 10000, 20000]
LABELS = ["< 250", "250 - 1k", "1k - 2.5k", "2.5k - 5k", "5k - 10k", "10k - 20k", "> 20k"]


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def color(t):
    return rgb(RAMP[int(np.searchsorted(BINS, t, side="right"))])


def k(n):
    return f"{n / 1000:.1f}k" if n < 100000 else f"{n / 1e6:.2f}M" if n >= 1e6 else f"{n / 1000:.0f}k"


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_JSON
    out = sys.argv[2] if len(sys.argv) > 2 else "poly_heatmap.png"
    d = json.load(open(src))
    w, h, chunk = d["width"], d["height"], d["chunk"]
    cells = np.array(d["cells"], dtype=np.float64).reshape(h, w)
    w_ = d["water"]
    land = np.array(json.loads(w_) if isinstance(w_, str) else w_, dtype=np.uint8).reshape(h, w)
    parcels = d["parcels"]
    owned = np.zeros((h, w), bool)
    for p in parcels:
        x, y, pw, ph = p["rect"]
        owned[y:y + ph, x:x + pw] = True

    f_small = ImageFont.truetype(FONT, 12)
    f_text = ImageFont.truetype(FONT, 15)
    f_head = ImageFont.truetype(BOLD, 17)
    f_title = ImageFont.truetype(BOLD, 24)
    img = Image.new("RGB", (w * PX + SIDE, h * PX + TOP), (255, 255, 255))
    dr = ImageDraw.Draw(img)

    # Background and the cells without a parcel.
    for y in range(h):
        for x in range(w):
            if owned[y, x]:
                continue
            t = cells[y, x]
            c = color(t) if t >= 1 else (LAND if land[y, x] else SEA)
            dr.rectangle([x * PX, TOP + y * PX, x * PX + PX - 1, TOP + y * PX + PX - 1], fill=c)
    # Parcels: one colour for the whole lot, by its total, with a 1px surface gap.
    for p in parcels:
        x, y, pw, ph = p["rect"]
        dr.rectangle([x * PX, TOP + y * PX, (x + pw) * PX - 2, TOP + (y + ph) * PX - 2], fill=color(p["tris"]))
    # Chunks and their totals.
    for cy in range(0, h, chunk):
        for cx in range(0, w, chunk):
            tot = cells[cy:cy + chunk, cx:cx + chunk].sum()
            x0, y0 = cx * PX, TOP + cy * PX
            dr.rectangle([x0, y0, min(cx + chunk, w) * PX - 1, TOP + min(cy + chunk, h) * PX - 1], outline=GRID)
            if tot > 0:
                label = k(tot)
                tw = dr.textlength(label, font=f_small)
                dr.rectangle([x0 + 2, y0 + 2, x0 + 6 + tw, y0 + 17], fill=(255, 255, 255))
                dr.text((x0 + 4, y0 + 3), label, font=f_small, fill=INK)
    # Ten heaviest parcels: numbered markers.
    top = sorted(parcels, key=lambda p: -p["tris"])[:15]
    for n, p in enumerate(top[:10], 1):
        x, y, pw, ph = p["rect"]
        cx, cy = (x + pw / 2) * PX, TOP + (y + ph / 2) * PX
        dr.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(255, 255, 255), outline=INK, width=2)
        s = str(n)
        dr.text((cx - dr.textlength(s, font=f_small) / 2, cy - 7), s, font=f_small, fill=INK)

    total = cells.sum()
    ex = d["extras"]
    bld = sum(p["tris"] for p in parcels)
    dr.text((12, 12), "Chat City - triangles per parcel", font=f_title, fill=INK)
    dr.text((12, 44), f"{k(total)} triangles in all (near detail, everything loaded). "
            "Darker = heavier. Numbers on the grid: total per 32-cell chunk.", font=f_text, fill=MUTED)

    # Sidebar.
    sx, y = w * PX + 24, TOP
    dr.text((sx, y), "Triangles in the patch", font=f_head, fill=INK)
    y += 28
    for c, lab in zip(RAMP, LABELS):
        dr.rounded_rectangle([sx, y, sx + 22, y + 16], 4, fill=rgb(c))
        dr.text((sx + 32, y), lab, font=f_text, fill=INK)
        y += 22
    y += 14
    dr.text((sx, y), "Where they are", font=f_head, fill=INK)
    y += 28
    for name, n in [("Buildings and props on parcels", bld), ("Roads, lights, trees, palms", ex["ground"]),
                    ("Fog island + Golden Gate", ex["fog_island"]), ("West metal bridge", ex["west_bridge"]),
                    ("Roadblocks", ex["roadblocks"])]:
        dr.text((sx, y), name, font=f_text, fill=INK)
        dr.text((sx + 330, y), f"{k(n):>8}  {n / total * 100:4.1f}%", font=f_text, fill=MUTED)
        y += 22
    y += 14
    dr.text((sx, y), "Heaviest parcels", font=f_head, fill=INK)
    y += 28
    for n, p in enumerate(top, 1):
        x0, y0 = p["rect"][:2]
        model = p["model"].split(": ")[-1] if p["model"] else "-"
        dr.text((sx, y), f"{n:>2}. {p['kind'].lower()} ({model})"[:40], font=f_text, fill=INK)
        dr.text((sx + 330, y), f"{k(p['tris']):>8}  {x0},{y0}", font=f_text, fill=MUTED)
        y += 21
    y += 14
    dr.text((sx, y), "Heaviest kinds (sum)", font=f_head, fill=INK)
    y += 28
    kinds = {}
    for p in parcels:
        kd = kinds.setdefault(p["kind"], [0, 0])
        kd[0] += p["tris"]
        kd[1] += 1
    for name, (t, cnt) in sorted(kinds.items(), key=lambda a: -a[1][0])[:10]:
        dr.text((sx, y), f"{name.lower()} x{cnt}", font=f_text, fill=INK)
        dr.text((sx + 330, y), f"{k(t):>8}  avg {k(t / cnt)}", font=f_text, fill=MUTED)
        y += 21
    img.save(out)
    print(out)


if __name__ == "__main__":
    main()
