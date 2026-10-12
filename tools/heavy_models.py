"""Draws the performance sheets of docs/new_models/themes from tools/heavy_models.gd.

Run from the project folder, after the Godot tool:
    python tools/heavy_models.py <dir written by heavy_models.gd> [out folder]
Three sheets, a thumbnail per model with what it costs:
    perf-1-most-triangles-drawn.png   triangles x uses: what weighs on the screen
    perf-2-heaviest-models.png        triangles of one model (with how many times it is used)
    perf-3-heaviest-textures.png      pixels of its textures (they are decoded at every start)
Needs Pillow.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

FONTS = ["C:/Windows/Fonts/arial.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]
BOLDS = ["C:/Windows/Fonts/arialbd.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]
FONT = next((f for f in FONTS if os.path.exists(f)), None)
BOLD = next((f for f in BOLDS if os.path.exists(f)), FONT)
CELL = 256
LABEL = 78
COLS = 6
PICK = 24
INK = (30, 34, 40)
MUTED = (100, 106, 116)
HOT = (196, 58, 48)

SHEETS = [
    ("perf-1-most-triangles-drawn.png", "total", "Most triangles drawn (one model x every place it stands)",
     "What weighs most on the screen. Lighter models here help the frame rate everywhere they stand."),
    ("perf-2-heaviest-models.png", "tris", "Heaviest single models (triangles)",
     "A heavy model used once or twice costs little on the whole map, but much where it stands."),
    ("perf-3-heaviest-textures.png", "tex_px", "Heaviest textures (pixels decoded at every start)",
     "Every texture of a drawn model is downloaded and decoded at start. Big ones on small objects are waste."),
]


def font(size, bold=False):
    path = BOLD if bold else FONT
    return ImageFont.truetype(path, size) if path else ImageFont.load_default()


def human(n):
    return "%.1fM" % (n / 1e6) if n >= 1e6 else ("%.1fk" % (n / 1e3) if n >= 1e3 else str(n))


def sheet(rows, thumbs, key, title, sub, out):
    rows = sorted(rows, key=lambda r: -r[key])[:PICK]
    lines = (len(rows) + COLS - 1) // COLS
    top = 96
    img = Image.new("RGB", (COLS * CELL, top + lines * (CELL + LABEL)), (255, 255, 255))
    d = ImageDraw.Draw(img)
    d.text((16, 14), title, fill=INK, font=font(30, True))
    d.text((16, 56), sub, fill=MUTED, font=font(17))
    for k, r in enumerate(rows):
        x = (k % COLS) * CELL
        y = top + (k // COLS) * (CELL + LABEL)
        p = os.path.join(thumbs, "%d.png" % r["id"])
        if os.path.exists(p):
            img.paste(Image.open(p).convert("RGB").resize((CELL, CELL)), (x, y))
        d.rectangle([x, y, x + CELL - 1, y + CELL + LABEL - 1], outline=(220, 224, 230))
        d.text((x + 8, y + 6), "%d" % (k + 1), fill=HOT, font=font(20, True))
        name = r["name"] if len(r["name"]) <= 34 else r["name"][:33] + "…"
        d.text((x + 8, y + CELL + 6), name, fill=INK, font=font(15, True))
        d.text((x + 8, y + CELL + 28), "%s tris x %d = %s" % (human(r["tris"]), r["uses"], human(r["total"])),
               fill=HOT if key != "tex_px" else MUTED, font=font(14))
        d.text((x + 8, y + CELL + 50), "textures %s px" % human(r["tex_px"]),
               fill=HOT if key == "tex_px" else MUTED, font=font(14))
    img.save(out)
    return rows


def main():
    src = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else "docs/new_models/themes"
    data = json.load(open(os.path.join(src, "heavy_models.json"), encoding="utf-8"))
    rows = data["models"]
    for name, key, title, sub in SHEETS:
        top = sheet(rows, os.path.join(src, "thumbs"), key, title, sub, os.path.join(out_dir, name))
        print(name, [r["name"] for r in top[:5]])


if __name__ == "__main__":
    main()
