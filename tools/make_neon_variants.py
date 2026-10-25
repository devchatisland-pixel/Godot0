#!/usr/bin/env python3
"""Neon sign variants, made from the curated neon packs (their raw files are not needed) and from
shapes drawn here (words, tubes), traced and extruded into smooth solids.

Usage:  python tools/make_neon_variants.py [--preview <folder>] [name ...]
Needs:  numpy, scipy, Pillow, opencv (cv2), and the Windows fonts (Arial Black, Arial Bold).

  neon_club_bold, neon_club_xxx, neon_club_open, neon_club_prive, neon_club_live
                 the kicking legs of vegas_club (neon_vegas pack) beside one bold red word, drawn
                 solid: the club sign had a hollow red tube on a dark letter, so the word read doubled
  neon_heart     vegas_love without its words "love 24hrs": the heart alone
  neon_woman     the woman of the sign without her blue frame
  neon_palm      the palm tree without its sand and its waves
  neon_bar       the bar sign drawn again with smooth tubes and letters (the original was pixel art)

The woman, the palm and the bar replace their pack in FREEMODELS/curated; running the tool again
gives the same files. With names after the options only those outputs are made.
"""
import os, sys, json
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_wave16_models import Glb, box, merged, preview, triangles, write_glb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CURATED = os.path.join(ROOT, "FREEMODELS", "curated")
FONTS = os.path.join(os.environ.get("WINDIR", "C:/Windows"), "Fonts")
BOLD_FONT = os.path.join(FONTS, "ariblk.ttf")
BAR_FONT = os.path.join(FONTS, "arialbd.ttf")
## Pixels to the cell when a shape is drawn before it is traced.
PPM = 800
## Largest gap (in pixels) between a traced outline and the shape it follows.
TRACE_EPS = 1.2
## Room between two letters of a word, a share of the font size.
LETTER_GAP = 0.06

RED = (1.0, 0.13, 0.16)
RED_SIDE = (0.55, 0.04, 0.06)
## The words of the club sign: they stand where CLUB stood (left of the legs, x -1.5 .. 0.8, y 0
## .. 0.56 in the pack), right-aligned against the legs, as high as CLUB or narrower to fit.
CLUB_WORDS = {"neon_club_bold": ("club_bold", "NEON_CLUB_BOLD", "CLUB"),
              "neon_club_xxx": ("club_xxx", "NEON_CLUB_XXX", "XXX"),
              "neon_club_open": ("club_open", "NEON_CLUB_OPEN", "OPEN"),
              "neon_club_prive": ("club_prive", "NEON_CLUB_PRIVE", "PRIVE"),
              "neon_club_live": ("club_live", "NEON_CLUB_LIVE", "LIVE")}
CLUB_WORD_BOX = (-1.5, 0.0, 0.8, 0.56)
## The legs of the club sign: every triangle right of this x.
CLUB_LEGS_X = 0.86
CLUB_DEPTH = (-0.04, 0.04)
## Sign widths (cells), as in tools/build_wave16_models.py.
CLUB_WIDTH = 3.0
PALM_HEIGHT = 3.0
BAR_WIDTH = 3.0


# --- Tracing and extruding ------------------------------------------------------------------------
def _material(name, rgb):
    return {"name": name, "key": ("neon_variant", name), "color": list(rgb) + [1.0], "emissive": list(rgb)}


def _area(ring):
    x, y = ring[:, 0], ring[:, 1]
    return 0.5 * float(np.sum(x * np.roll(y, -1) - np.roll(x, -1) * y))


def _crosses(a, b, ring_list):
    """True when segment a-b cuts an edge of the rings (edges touching a or b do not count)."""
    for r in ring_list:
        p, q = r, np.roll(r, -1, 0)
        touch = (np.all(np.isclose(p, a), 1) | np.all(np.isclose(q, a), 1) |
                 np.all(np.isclose(p, b), 1) | np.all(np.isclose(q, b), 1))
        d = b - a
        e = q - p
        den = d[0] * e[:, 1] - d[1] * e[:, 0]
        ok = np.abs(den) > 1e-12
        w = p - a
        t = np.where(ok, (w[:, 0] * e[:, 1] - w[:, 1] * e[:, 0]) / np.where(ok, den, 1), -1)
        u = np.where(ok, (w[:, 0] * d[1] - w[:, 1] * d[0]) / np.where(ok, den, 1), -1)
        if np.any(ok & ~touch & (t > 1e-9) & (t < 1 - 1e-9) & (u > 1e-9) & (u < 1 - 1e-9)):
            return True
    return False


def _inside_corner(ring, j, p):
    """True when the direction from corner j of a counter-clockwise ring to p goes inside the ring
    (a corner that a cut already joins appears twice: only one of its copies opens on p)."""
    v = ring[j]
    e1, e2, d = ring[(j + 1) % len(ring)] - v, ring[j - 1] - v, p - v

    def cross(a, b):
        return a[0] * b[1] - a[1] * b[0]
    if cross(e1, e2) > 0:
        return cross(e1, d) > 0 and cross(d, e2) > 0
    return cross(e1, d) > 0 or cross(d, e2) > 0


def _bridge(outer, holes):
    """One ring from an outer ring (counter-clockwise) and its holes (clockwise): each hole is
    joined to the outer ring by a cut from its rightmost corner to a corner it sees."""
    for k in sorted(range(len(holes)), key=lambda k: -holes[k][:, 0].max()):
        hole = holes[k]
        i = int(np.argmax(hole[:, 0]))
        m = hole[i]
        rest = [h for j, h in enumerate(holes) if j != k]
        for j in np.argsort(np.hypot(*(outer - m).T)):
            if _inside_corner(outer, j, m) and not _crosses(m, outer[j], [outer, hole] + rest):
                break
        outer = np.concatenate([outer[:j + 1], np.roll(hole, -i, 0), hole[i:i + 1], outer[j:]])
        holes = [h if n != k else np.zeros((0, 2)) for n, h in enumerate(holes)]
    return outer


def _earclip(ring):
    """Triangles (index triples into `ring`, counter-clockwise) of a simple ring."""
    idx = list(range(len(ring)))
    tris = []
    k = 0
    stuck = 0
    while len(idx) > 3:
        n = len(idx)
        k %= n
        a, b, c = idx[k - 1], idx[k], idx[(k + 1) % n]
        pa, pb, pc = ring[a], ring[b], ring[c]
        cross = (pb[0] - pa[0]) * (pc[1] - pb[1]) - (pb[1] - pa[1]) * (pc[0] - pb[0])
        ear = cross > 1e-12
        if ear:
            others = ring[[i for i in idx if i not in (a, b, c)]]
            v0, v1, v2 = pc - pa, pb - pa, others - pa
            d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
            d02, d12 = v2 @ v0, v2 @ v1
            inv = 1.0 / (d00 * d11 - d01 * d01)
            u = (d11 * d02 - d01 * d12) * inv
            v = (d00 * d12 - d01 * d02) * inv
            ear = not np.any((u > 1e-9) & (v > 1e-9) & (u + v < 1 - 1e-9))
        if ear or stuck > n:
            if cross > 1e-12:
                tris.append((a, b, c))
            idx.pop(k)
            stuck = 0
        else:
            k += 1
            stuck += 1
    if len(idx) == 3 and _area(ring[idx]) > 0:
        tris.append(tuple(idx))
    return tris


def trace(mask, origin):
    """Rings of a drawn mask, in cells: [(outer, [holes])], outer counter-clockwise and holes
    clockwise. `origin`: the place of the bottom-left pixel."""
    cs, hier = cv2.findContours(mask.astype(np.uint8), cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE)
    if hier is None:
        return []
    h = mask.shape[0]

    def ring(c):
        c = cv2.approxPolyDP(c, TRACE_EPS, True).reshape(-1, 2).astype(float)
        if len(c) < 3:
            return None
        r = np.stack([origin[0] + c[:, 0] / PPM, origin[1] + (h - c[:, 1]) / PPM], 1)
        return r if abs(_area(r)) * PPM * PPM > 8 else None

    out = []
    for i, c in enumerate(cs):
        if hier[0][i][3] != -1:
            continue
        outer = ring(c)
        if outer is None:
            continue
        if _area(outer) < 0:
            outer = outer[::-1]
        holes = []
        j = hier[0][i][2]
        while j != -1:
            hole = ring(cs[j])
            if hole is not None:
                holes.append(hole[::-1] if _area(hole) > 0 else hole)
            j = hier[0][j][0]
        out.append((outer, holes))
    return out


def extrude(rings, z0, z1, face, side):
    """Solid part(s) of traced rings between depths z0 and z1: the faces with material `face`,
    the edges with `side`."""
    fp, fi, sp, sn = [], [], [], []
    for outer, holes in rings:
        flat = _bridge(outer, holes)
        tris = np.array(_earclip(flat), dtype=np.int64).reshape(-1, 3)
        t = flat[tris]
        cover = 0.5 * np.abs((t[:, 1, 0] - t[:, 0, 0]) * (t[:, 2, 1] - t[:, 0, 1]) -
                             (t[:, 1, 1] - t[:, 0, 1]) * (t[:, 2, 0] - t[:, 0, 0])).sum()
        shape_area = _area(outer) + sum(_area(h) for h in holes)
        if abs(cover - shape_area) > 0.002 * shape_area:
            print("!! %s: the face covers %.4f, the shape %.4f" % (face["name"], cover, shape_area))
        base = len(fp) and sum(len(x) for x in fp)
        n = len(flat)
        fp.append(np.concatenate([np.c_[flat, np.full(n, z1)], np.c_[flat, np.full(n, z0)]]))
        fi.append(np.concatenate([tris + base, tris[:, ::-1] + n + base]))
        for r in [outer] + holes:
            q = np.roll(r, -1, 0)
            d = q - r
            nrm = np.c_[d[:, 1], -d[:, 0], np.zeros(len(r))]
            nrm /= np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-12
            for p0, p1, nn in zip(r, q, nrm):
                sp.append([[p0[0], p0[1], z1], [p0[0], p0[1], z0], [p1[0], p1[1], z0], [p1[0], p1[1], z1]])
                sn.append(nn)
    pos = np.concatenate(fp)
    nrm = np.concatenate([np.concatenate([np.tile([0, 0, 1.0], (len(x) // 2, 1)), np.tile([0, 0, -1.0], (len(x) // 2, 1))])
                          for x in fp])
    parts = [{"path": "/" + face["name"], "pos": pos, "nrm": nrm, "uv": np.zeros((len(pos), 2)),
              "idx": np.concatenate(fi), "mat": face}]
    if sp:
        quads = np.array(sp).reshape(-1, 3)
        sn = np.repeat(np.array(sn), 4, 0)
        k = np.arange(len(sp))[:, None] * 4
        # Corners 0 (top, p0), 1 (bottom, p0), 2 (bottom, p1), 3 (top, p1): seen from outside.
        idx = np.concatenate([k + [0, 1, 2], k + [0, 2, 3]])
        parts.append({"path": "/" + side["name"], "pos": quads, "nrm": sn, "uv": np.zeros((len(quads), 2)),
                      "idx": idx, "mat": side})
    return parts


class Canvas:
    """A drawing in cells (x right, y up) over the box `lo`..`hi`, traced into a mask."""

    def __init__(self, lo, hi):
        self.lo = np.array(lo, float)
        self.size = (int(np.ceil((hi[0] - lo[0]) * PPM)) + 1, int(np.ceil((hi[1] - lo[1]) * PPM)) + 1)
        self.img = Image.new("L", self.size, 0)
        self.draw = ImageDraw.Draw(self.img)

    def px(self, x, y):
        return ((x - self.lo[0]) * PPM, self.size[1] - 1 - (y - self.lo[1]) * PPM)

    def line(self, points, width):
        pts = [self.px(*p) for p in points]
        w = int(round(width * PPM))
        self.draw.line(pts, fill=255, width=w)
        for p in pts:
            self.draw.ellipse([p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2], fill=255)

    def rounded_frame(self, x0, y0, x1, y1, radius, width):
        a, b = self.px(x0, y1), self.px(x1, y0)
        self.draw.rounded_rectangle([a, b], radius=int(radius * PPM), outline=255, width=int(round(width * PPM)))

    def word(self, text, font, box):
        """`text` as large as it fits in box (x0, y0, x1, y1), on its bottom, against its right side.
        The letters are set apart by LETTER_GAP of the size (the X of Arial Black touch)."""
        f = ImageFont.truetype(font, 600)
        img = Image.new("L", (800 * (len(text) + 1), 900), 0)
        draw = ImageDraw.Draw(img)
        x = 100
        for ch in text:
            draw.text((x, 100), ch, font=f, fill=255)
            x += f.getlength(ch) + 600 * LETTER_GAP
        ys, xs = np.nonzero(np.asarray(img) > 127)
        img = img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
        s = min((box[2] - box[0]) / img.size[0], (box[3] - box[1]) / img.size[1])
        w, h = img.size[0] * s, img.size[1] * s
        img = img.resize((max(1, round(w * PPM)), max(1, round(h * PPM))), Image.LANCZOS)
        at = self.px(box[2] - w, box[1] + h)
        self.img.paste(255, (round(at[0]), round(at[1])), img.point(lambda v: 255 if v > 127 else 0))

    def rings(self):
        return trace(np.asarray(self.img) > 127, self.lo)


# --- Picking parts of the curated packs ------------------------------------------------------------
def pack_parts(pack, node=None, tex_max=4096):
    """The parts of model `node` of a curated pack (all of them for a pack of one model)."""
    return [p for p in Glb(os.path.join(CURATED, pack + ".glb")).parts(tex_max)
            if node is None or p["path"].split("/")[2] == node]


def keep_triangles(p, keep):
    used, idx = np.unique(p["idx"][keep], return_inverse=True)
    q = dict(p)
    q["idx"] = idx.reshape(-1, 3)
    q["pos"] = p["pos"][used]
    q["nrm"] = None if p["nrm"] is None else p["nrm"][used]
    q["uv"] = p["uv"][used]
    return q


def pieces(p, cell=0.002):
    """Number of the connected piece of every triangle (corners closer than `cell` are joined)."""
    key = np.round(p["pos"] / cell).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    idx = inv.reshape(-1)[p["idx"]]
    n = int(inv.max()) + 1
    a = np.concatenate([idx[:, 0], idx[:, 1]])
    b = np.concatenate([idx[:, 1], idx[:, 2]])
    _, lab = connected_components(coo_matrix((np.ones(len(a)), (a, b)), shape=(n, n)), directed=False)
    return lab[idx[:, 0]]


def place(parts, width=None, height=None):
    """Scaled to `width` (or `height`) if given, centred on x/z, standing on y = 0."""
    lo, hi = box(parts)
    size = hi - lo
    s = width / size[0] if width else (height / size[1] if height else 1.0)
    base = np.array([(lo[0] + hi[0]) * 0.5, lo[1], (lo[2] + hi[2]) * 0.5])
    for p in parts:
        p["pos"] = (p["pos"] - base) * s
    return size * s


# --- The variants ---------------------------------------------------------------------------------
def club_word(text):
    legs = [keep_triangles(p, p["pos"][p["idx"]].mean(1)[:, 0] > CLUB_LEGS_X) for p in pack_parts("neon_vegas", "vegas_club")]
    c = Canvas(CLUB_WORD_BOX[:2], CLUB_WORD_BOX[2:])
    c.word(text, BOLD_FONT, CLUB_WORD_BOX)
    word = extrude(c.rings(), *CLUB_DEPTH, _material("neon_red", RED), _material("neon_red_side", RED_SIDE))
    parts = word + legs
    return parts, place(parts, width=CLUB_WIDTH)


def heart():
    """The heart and its lower right stroke (the ring is open there); not the words inside it,
    nor the purple foot of the girl that the cut of the pack left at its tip."""
    out = []
    for p in pack_parts("neon_vegas", "vegas_love"):
        lab = pieces(p)
        tri = p["pos"][p["idx"]]
        keep = np.zeros(len(lab), bool)
        tex = np.asarray(p["mat"]["image"].convert("RGB"), float)
        uv = p["uv"][p["idx"]].mean(1)
        col = tex[(uv[:, 1] % 1 * (tex.shape[0] - 1)).astype(int), (uv[:, 0] % 1 * (tex.shape[1] - 1)).astype(int)]
        for i in np.unique(lab):
            s = lab == i
            lo = tri[s].reshape(-1, 3).min(0)
            hi = tri[s].reshape(-1, 3).max(0)
            r, g, b = col[s].mean(0)
            if lo[1] < 0.3 and hi[0] - lo[0] > 0.5 and r > 200 and b < 120:
                keep |= s
        out.append(keep_triangles(p, keep))
    return out, place(out)


def woman():
    parts = [p for p in pack_parts("neon_woman") if "/Links_1/" not in p["path"] and "/Frame_2/" not in p["path"]]
    return parts, place(parts)


def palm():
    parts = [p for p in pack_parts("neon_palm", "palm_tree")
             if not p["mat"]["name"].startswith(("Sonata_28_", "Sonata_3_"))]
    return parts, place(parts, height=PALM_HEIGHT)


def bar():
    """A rounded frame (purple), a martini glass with its pick (pink) over its left side, and
    the word BAR (cyan) in it; three depths, the glass in front."""
    tube = 0.09
    frame = Canvas((-1.3, -0.1), (1.6, 1.55))
    frame.rounded_frame(-1.22, 0.0, 1.5, 1.42, 0.3, tube)
    glass = Canvas((-1.6, 0.0), (0.4, 2.1))
    glass.line([(-1.48, 1.62), (0.12, 1.62)], tube)
    glass.line([(-1.48, 1.62), (-0.68, 0.86), (0.12, 1.62)], tube)
    glass.line([(-0.68, 0.86), (-0.68, 0.14)], tube)
    glass.line([(-1.02, 0.08), (-0.34, 0.08)], tube)
    glass.line([(-0.56, 1.0), (0.22, 1.92)], 0.055)
    word = Canvas((-0.3, 0.3), (1.35, 1.2))
    word.word("BAR", BAR_FONT, (-0.22, 0.34, 1.3, 1.12))
    parts = (extrude(frame.rings(), -0.04, 0.02, _material("neon_purple", (0.62, 0.16, 0.86)),
                     _material("neon_purple_side", (0.3, 0.06, 0.42))) +
             extrude(word.rings(), -0.02, 0.06, _material("neon_cyan", (0.12, 0.92, 1.0)),
                     _material("neon_cyan_side", (0.04, 0.42, 0.5))) +
             extrude(glass.rings(), 0.02, 0.09, _material("neon_pink", (1.0, 0.26, 0.92)),
                     _material("neon_pink_side", (0.5, 0.1, 0.45))))
    return parts, place(parts, width=BAR_WIDTH)


## Output name: (node, category, maker).
OUTPUTS = {name: (node, cat, (lambda t=text: club_word(t))) for name, (node, cat, text) in CLUB_WORDS.items()}
OUTPUTS.update({
    "neon_heart": ("vegas_heart", "NEON_HEART", heart),
    "neon_woman": ("neon_woman", "NEON_WOMAN", woman),
    "neon_palm": ("palm_tree", "NEON_PALM", palm),
    "neon_bar": ("bar_board", "NEON_BAR", bar),
})


def main():
    args = sys.argv[1:]
    shots = None
    if "--preview" in args:
        shots = args[args.index("--preview") + 1]
        del args[args.index("--preview"):args.index("--preview") + 2]
        os.makedirs(shots, exist_ok=True)
    only = [a for a in args if not a.startswith("--")]
    for name, (node, cat, make) in OUTPUTS.items():
        if only and name not in only:
            continue
        parts, size = make()
        parts = merged(parts)
        out = os.path.join(CURATED, name)
        write_glb(out + ".glb", name, [(node, parts)])
        with open(out + ".models.json", "w", newline="\n") as f:
            json.dump({"file": name + ".glb", "models": [{"cat": cat, "node": node}]}, f, indent="\t")
            f.write("\n")
        if shots:
            preview(parts, os.path.join(shots, name + ".png"))
        print("%-16s %-12s %.2f x %.2f x %.2f cells, %d triangles" % (name, node, *size, triangles(parts)))


if __name__ == "__main__":
    main()
