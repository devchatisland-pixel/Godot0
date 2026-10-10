"""Draws the map with the grid of cells the game uses, from the data of tools/grid_map.gd.

    godot --headless --script res://tools/grid_map.gd -- grid_map.json
    python tools/grid_map.py grid_map.json [grid_map.png] [pixels per cell, default 8]

A cell (x, y) is what the information bubble of a building shows as "cell x,y": x grows to
the east (right), y to the south (down). Thin lines every 10 cells, thick lines every 50,
numbers on the four sides and at the thick crossings. Buildings are outlined; the ones that
are few of their kind carry their name. Needs numpy and Pillow.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONTS = [("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
         ("C:/Windows/Fonts/arial.ttf", "C:/Windows/Fonts/arialbd.ttf")]
FONT, BOLD = next(((a, b) for a, b in FONTS if os.path.exists(a)), FONTS[0])

# By zone name (CityTypes.Zone); soft colours so that the grid and the labels stay readable.
ZONE_COLORS = {
    "NONE": "#cfe3f1", "NATURE": "#b9dba8", "PARK": "#8fcf86", "DOWNTOWN": "#c9bbe6",
    "COMMERCIAL": "#e7c7da", "APARTMENT": "#ecd9c2", "SUBURBAN": "#d6ecc8", "INDUSTRIAL": "#cfc7b8",
    "CIVIC": "#f3f3f3", "DESERT": "#efd7a6", "ENTERTAINMENT": "#e9a6e0", "ISLET": "#a6e8c4",
    "QUARTER": "#ffc0ae", "PRISON": "#b5b5b5", "POOR": "#c9bdb1", "FARM": "#dede9a",
    "URBAN": "#c3c7cf", "SAND": "#f5ecc4", "DEV": "#ffffff",
}
DEEP, SHALLOW, BEACH_C = "#9cc4e0", "#b9d8ec", "#f0e2b0"
STREET, AVENUE = "#6b6f78", "#33363d"
INK, MUTED = (25, 28, 34), (95, 100, 110)
GRID_10, GRID_50 = (0, 0, 0, 38), (0, 0, 0, 120)
# Kinds drawn as plain lots without a name, however few they are.
NO_NAME = {"PLAZA", "GARDEN", "INDUSTRIAL_YARD", "FIELD", "BOAT", "PIER", "BUS_STOP", "BILLBOARD",
           "OIL_PUMP", "SAT_DISH", "TANK", "BALLOON"}
NAME_MAX = 12  # kinds with at most this many buildings get their name written


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "grid_map.json"
    out = sys.argv[2] if len(sys.argv) > 2 else "grid_map.png"
    px = int(sys.argv[3]) if len(sys.argv) > 3 else 8
    d = json.load(open(src))
    n = d["size"]
    fog = d.get("fog") or {}
    cols = max(n, fog["x"] + fog["size"]) if fog else n
    rows = n
    terrain = np.array(d["terrain"], dtype=np.uint8).reshape(n, n)
    zone = np.array(d["zone"], dtype=np.uint8).reshape(n, n)
    road = np.array(d["road"], dtype=np.uint8).reshape(n, n)
    zones = d["zones"]

    cell = np.zeros((rows, cols, 3), dtype=np.uint8)
    cell[:, :] = rgb(DEEP)
    for zi, name in enumerate(zones):
        cell[:, :n][zone == zi] = rgb(ZONE_COLORS.get(name, "#dddddd"))
    cell[:, :n][terrain == 2] = rgb(BEACH_C)
    cell[:, :n][terrain == 1] = rgb(SHALLOW)
    cell[:, :n][terrain == 0] = rgb(DEEP)
    cell[:, :n][(road & 3) == 1] = rgb(STREET)
    cell[:, :n][(road & 3) == 2] = rgb(AVENUE)
    if fog:
        land = np.array(fog["land"], dtype=np.uint8).reshape(fog["size"], fog["size"])
        for y in range(fog["size"]):
            gy = fog["y"] + y
            if 0 <= gy < rows:
                for x in range(fog["size"]):
                    gx = fog["x"] + x
                    if 0 <= gx < cols and land[y, x] and (gx >= n or terrain[gy, gx] < 2):
                        cell[gy, gx] = (205, 208, 214)

    left, top, right, bottom = 56, 96, 380, 44
    w, h = cols * px, rows * px
    img = Image.new("RGB", (left + w + right, top + h + bottom), (255, 255, 255))
    img.paste(Image.fromarray(cell).resize((w, h), Image.NEAREST), (left, top))
    dr = ImageDraw.Draw(img, "RGBA")
    f_axis = ImageFont.truetype(FONT, 13)
    f_axis_b = ImageFont.truetype(BOLD, 14)
    f_name = ImageFont.truetype(BOLD, max(9, px + 2))
    f_title = ImageFont.truetype(BOLD, 28)
    f_text = ImageFont.truetype(FONT, 15)
    f_head = ImageFont.truetype(BOLD, 17)

    # Buildings: an outline for every lot, a name for the rare kinds.
    count = {}
    for b in d["buildings"]:
        count[b[1]] = count.get(b[1], 0) + 1
    labels = []
    for bid, kind, x, y, bw, bh in d["buildings"]:
        if kind in ("BOAT", "BALLOON"):
            continue
        x0, y0 = left + x * px, top + y * px
        dr.rectangle([x0, y0, x0 + bw * px - 1, y0 + bh * px - 1], outline=(40, 40, 40, 150))
        if count[kind] <= NAME_MAX and kind not in NO_NAME:
            labels.append((kind.replace("_", " ").lower(), x0 + bw * px / 2, y0 + bh * px / 2))

    # Grid.
    for gx in range(0, cols + 1, 10):
        big = gx % 50 == 0
        dr.line([left + gx * px, top, left + gx * px, top + h], fill=GRID_50 if big else GRID_10, width=2 if big else 1)
    for gy in range(0, rows + 1, 10):
        big = gy % 50 == 0
        dr.line([left, top + gy * px, left + w, top + gy * px], fill=GRID_50 if big else GRID_10, width=2 if big else 1)
    dr.rectangle([left, top, left + w, top + h], outline=INK + (255,), width=2)
    # The end of the city grid (the fog island lies beyond it).
    if cols > n:
        dr.line([left + n * px, top, left + n * px, top + h], fill=(200, 60, 60, 200), width=2)

    # Numbers on the four sides, and at the thick crossings inside the map.
    for gx in range(0, cols + 1, 10):
        s = str(gx)
        f = f_axis_b if gx % 50 == 0 else f_axis
        tw = dr.textlength(s, font=f)
        dr.text((left + gx * px - tw / 2, top - 20), s, font=f, fill=INK)
        dr.text((left + gx * px - tw / 2, top + h + 6), s, font=f, fill=INK)
    for gy in range(0, rows + 1, 10):
        s = str(gy)
        f = f_axis_b if gy % 50 == 0 else f_axis
        tw = dr.textlength(s, font=f)
        dr.text((left - tw - 8, top + gy * px - 8), s, font=f, fill=INK)
        dr.text((left + w + 8, top + gy * px - 8), s, font=f, fill=INK)
    for gx in range(50, cols, 50):
        for gy in range(50, rows, 50):
            s = "%d,%d" % (gx, gy)
            tw = dr.textlength(s, font=f_axis)
            x0, y0 = left + gx * px + 3, top + gy * px + 2
            dr.rectangle([x0 - 2, y0 - 1, x0 + tw + 2, y0 + 15], fill=(255, 255, 255, 190))
            dr.text((x0, y0), s, font=f_axis, fill=INK)

    for text, cx, cy in labels:
        tw = dr.textlength(text, font=f_name)
        x0, y0 = cx - tw / 2, cy - (px + 2) / 2 - 1
        dr.rectangle([x0 - 2, y0 - 1, x0 + tw + 2, y0 + px + 5], fill=(255, 255, 255, 215))
        dr.text((x0, y0), text, font=f_name, fill=INK)
    if fog:
        s = "fog island (not on the city grid)"
        dr.text((left + (fog["x"] + fog["size"] * 0.35) * px, top + (fog["y"] + fog["size"] * 0.5) * px), s, font=f_head, fill=MUTED)

    dr.text((left, 14), "Chat City - grid of cells", font=f_title, fill=INK)
    dr.text((left, 52), "A position is \"cell x,y\": x to the east (right), y to the south (down), the same numbers as in the "
            "information bubble of a building. Thin lines every 10 cells, thick lines every 50. "
            "The city grid is %d x %d cells." % (n, n), font=f_text, fill=MUTED)

    # Legend.
    sx, y = left + w + 70, top
    dr.text((sx, y), "Ground", font=f_head, fill=INK)
    y += 28
    used = sorted({zones[z] for z in np.unique(zone)} - {"NONE"})
    for name, col in [(zn.lower().replace("_", " "), ZONE_COLORS.get(zn, "#dddddd")) for zn in used] + [
            ("beach", BEACH_C), ("shallow sea", SHALLOW), ("deep sea", DEEP), ("street", STREET),
            ("avenue / highway", AVENUE), ("fog island", "#cdd0d6")]:
        dr.rectangle([sx, y, sx + 22, y + 15], fill=rgb(col) + (255,), outline=(120, 120, 120, 255))
        dr.text((sx + 32, y - 1), name, font=f_text, fill=INK)
        y += 22
    y += 14
    dr.text((sx, y), "How to give a place", font=f_head, fill=INK)
    y += 26
    for line in ["one cell: \"cell 190,170\"", "an area: \"from 180,160 to 200,175\"",
                 "a building: its B-number and its cell,", "as the bubble shows them",
                 "red line: east edge of the city grid"]:
        dr.text((sx, y), line, font=f_text, fill=MUTED)
        y += 21
    img.save(out)
    print(out, img.size)


if __name__ == "__main__":
    main()
