"""Draws the ZONES of the map (CityTypes.Zone) on their own, to see which zone is where.

    godot --headless --script res://tools/grid_map.gd -- grid_map.json
    python tools/zone_map.py grid_map.json [docs/zone_map.png] [pixels per cell, default 6]

One vivid colour per zone, the name of each zone written on its areas, the cell grid (every
10 cells, thick every 50: the same "cell x,y" numbers as the information bubble of a building),
and a legend with what each zone is and how many cells it covers. Roads are drawn thin and
dark so the shape of the blocks shows; buildings are left out on purpose.
A zone is the ground a block was given when the map was made: it decides which buildings are
drawn there (see DistrictPlanner). Needs numpy, scipy and Pillow.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

FONTS = [("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
         ("C:/Windows/Fonts/arial.ttf", "C:/Windows/Fonts/arialbd.ttf")]
FONT, BOLD = next(((a, b) for a, b in FONTS if os.path.exists(a)), FONTS[0])

# name -> (colour, what it is). Vivid and far apart from each other.
ZONES = {
    "DOWNTOWN": ("#7b4bd6", "downtown: skyscrapers and offices"),
    "COMMERCIAL": ("#f2559b", "commercial: shops, mid-rise, hotels (shopping streets, civic centre)"),
    "APARTMENT": ("#f5a623", "apartment: residential mid-rise (uptown, sports corner)"),
    "SUBURBAN": ("#7ed321", "suburban: detached houses"),
    "INDUSTRIAL": ("#8b6b4a", "industrial: factories, yards, warehouses"),
    "CIVIC": ("#e8e8e8", "civic: land kept for a public service (police, hospital, school...)"),
    "PARK": ("#1e9e4a", "park: the central park and green areas"),
    "ENTERTAINMENT": ("#d81bd8", "entertainment: the little Las Vegas, casinos, neon"),
    "QUARTER": ("#e53935", "quarter: the colourful low-rise town quarter = the RED DISTRICT"),
    "POOR": ("#6d5a50", "poor: run-down panel blocks behind downtown"),
    "PRISON": ("#37474f", "prison: the Alcatraz-like prison island"),
    "DESERT": ("#e8c35a", "desert: sand and oil pumps (west / airbase)"),
    "NATURE": ("#a5d66f", "nature: fields and forests outside the city"),
    "FARM": ("#c9c93a", "farm: fields and farms of the countryside"),
    "URBAN": ("#2f6fb0", "urban: the third island, massive urbanism, no trees"),
    "SAND": ("#fff1a8", "sand: wide beach strip round the mountain forest"),
    "ISLET": ("#26c6a6", "islet: small palm islands off the coast"),
    "DEV": ("#ffffff", "dev: the small development island (one of each shop)"),
    "NONE": ("#bcd9ee", "none: water / not buildable"),
}
DEEP, SHALLOW, BEACH_C = "#8fb9d8", "#b9d8ec", "#f0e2b0"
STREET, AVENUE = "#3a3d45", "#15171b"
INK, MUTED = (25, 28, 34), (95, 100, 110)
MIN_LABEL = 120  # areas smaller than this (cells) get no name, the biggest one of a zone always does


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "grid_map.json"
    out = sys.argv[2] if len(sys.argv) > 2 else "zone_map.png"
    px = int(sys.argv[3]) if len(sys.argv) > 3 else 6
    d = json.load(open(src))
    n = d["size"]
    fog = d.get("fog") or {}
    cols = max(n, fog["x"] + fog["size"]) if fog else n
    rows = n
    terrain = np.array(d["terrain"], dtype=np.uint8).reshape(n, n)
    zone = np.array(d["zone"], dtype=np.uint8).reshape(n, n)
    road = np.array(d["road"], dtype=np.uint8).reshape(n, n)
    names = d["zones"]

    cell = np.zeros((rows, cols, 3), dtype=np.uint8)
    cell[:, :] = rgb(DEEP)
    land = (terrain == 2) | ((zone != 0) & (terrain >= 2))
    for zi, name in enumerate(names):
        cell[:, :n][zone == zi] = rgb(ZONES.get(name, ("#dddddd", ""))[0])
    cell[:, :n][terrain == 1] = rgb(SHALLOW)
    cell[:, :n][terrain == 0] = rgb(DEEP)
    # Beach with no zone on it stays beach-coloured.
    cell[:, :n][(terrain == 2) & (zone == 0)] = rgb(BEACH_C)
    cell[:, :n][(road & 3) == 1] = rgb(STREET)
    cell[:, :n][(road & 3) == 2] = rgb(AVENUE)
    if fog:
        fl = np.array(fog["land"], dtype=np.uint8).reshape(fog["size"], fog["size"])
        for y in range(fog["size"]):
            gy = fog["y"] + y
            if 0 <= gy < rows:
                for x in range(fog["size"]):
                    gx = fog["x"] + x
                    if 0 <= gx < cols and fl[y, x] and (gx >= n or terrain[gy, gx] < 2):
                        cell[gy, gx] = (205, 208, 214)

    left, top, right, bottom = 56, 96, 640, 44
    w, h = cols * px, rows * px
    img = Image.new("RGB", (left + w + right, max(top + h + bottom, 1100)), (255, 255, 255))
    img.paste(Image.fromarray(cell).resize((w, h), Image.NEAREST), (left, top))
    dr = ImageDraw.Draw(img, "RGBA")
    f_axis = ImageFont.truetype(FONT, 12)
    f_axis_b = ImageFont.truetype(BOLD, 13)
    f_title = ImageFont.truetype(BOLD, 28)
    f_text = ImageFont.truetype(FONT, 15)
    f_head = ImageFont.truetype(BOLD, 17)

    # Grid.
    for gx in range(0, cols + 1, 10):
        big = gx % 50 == 0
        dr.line([left + gx * px, top, left + gx * px, top + h], fill=(0, 0, 0, 110) if big else (0, 0, 0, 40), width=2 if big else 1)
    for gy in range(0, rows + 1, 10):
        big = gy % 50 == 0
        dr.line([left, top + gy * px, left + w, top + gy * px], fill=(0, 0, 0, 110) if big else (0, 0, 0, 40), width=2 if big else 1)
    dr.rectangle([left, top, left + w, top + h], outline=INK + (255,), width=2)
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

    # The name of every zone on its areas (road cells count as part of the area they cross).
    counts = {}
    for zi, name in enumerate(names):
        mask = zone == zi
        counts[name] = int(mask.sum())
        if name == "NONE" or not mask.any():
            continue
        lab, k = ndimage.label(ndimage.binary_closing(mask, iterations=3) | mask)
        sizes = ndimage.sum(mask, lab, range(1, k + 1))
        biggest = int(np.argmax(sizes)) + 1
        for comp in range(1, k + 1):
            if comp != biggest and sizes[comp - 1] < MIN_LABEL:
                continue
            cm = (lab == comp) & mask
            ys, xs = np.nonzero(cm)
            # The point of the area farthest from its edge (the middle of a ring would be empty).
            dist = ndimage.distance_transform_edt(cm)
            cy, cx = np.unravel_index(int(np.argmax(dist)), dist.shape)
            size = max(11, min(22, int(dist.max() * px * 0.9)))
            f = ImageFont.truetype(BOLD, size)
            text = name.lower()
            tw = dr.textlength(text, font=f)
            x0, y0 = left + (cx + 0.5) * px - tw / 2, top + (cy + 0.5) * px - size / 2
            dr.rectangle([x0 - 3, y0 - 2, x0 + tw + 3, y0 + size + 3], fill=(255, 255, 255, 215))
            dr.text((x0, y0), text, font=f, fill=INK)
    if fog:
        dr.text((left + (fog["x"] + fog["size"] * 0.3) * px, top + (fog["y"] + fog["size"] * 0.5) * px),
                "fog island (not on the city grid)", font=f_head, fill=MUTED)

    dr.text((left, 14), "Chat City - zones of the map", font=f_title, fill=INK)
    dr.text((left, 52), "The ground a block was given decides which buildings stand on it. Cells: x to the east (right), "
            "y to the south (down), like the \"cell x,y\" of a building bubble. Grid every 10 cells, thick every 50. "
            "North-west is up.", font=f_text, fill=MUTED)

    # Legend: every zone with its colour, its cell count and what it is.
    sx, y = left + w + 40, top
    dr.text((sx, y), "Zones (cells covered)", font=f_head, fill=INK)
    y += 30
    order = sorted((nm for nm in names if counts.get(nm, 0) > 0 and nm != "NONE"), key=lambda nm: -counts[nm])
    for nm in order:
        col, desc = ZONES.get(nm, ("#dddddd", nm.lower()))
        dr.rectangle([sx, y, sx + 26, y + 18], fill=rgb(col) + (255,), outline=(90, 90, 90, 255))
        dr.text((sx + 36, y - 1), "%s  %d" % (nm, counts[nm]), font=f_head, fill=INK)
        dr.text((sx + 36, y + 19), desc, font=f_text, fill=MUTED)
        y += 48
    y += 6
    for label, col in [("beach", BEACH_C), ("shallow sea", SHALLOW), ("deep sea", DEEP), ("street", STREET),
                       ("avenue / highway", AVENUE), ("fog island", "#cdd0d6")]:
        dr.rectangle([sx, y, sx + 26, y + 16], fill=rgb(col) + (255,), outline=(90, 90, 90, 255))
        dr.text((sx + 36, y - 1), label, font=f_text, fill=INK)
        y += 24
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    img.save(out)
    print(out, img.size)
    for nm in order:
        print("%-14s %6d cells" % (nm, counts[nm]))


if __name__ == "__main__":
    main()
