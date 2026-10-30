"""The clubs and casinos of Las Vegas, built from boxes (own models, CC0):

  FREEMODELS/curated/vegas_buildings.glb   one pack, one node per building:
      vegas_casino_a     wide casino, marquee canopy, CASINO in bulbs on the roof
      vegas_casino_b     casino with a hotel tower above it, CASINO and ROYAL in bulbs
      vegas_casino_c     purple and gold casino, the four card suits, POKER on the roof
      vegas_club_a       black club, pink neon outline, CLUB
      vegas_club_b       club with a blade sign, DISCO
      vegas_club_c       low red lounge, LOUNGE
      vegas_club_low     one storey, DANCE
      vegas_bar_low      one storey, BAR

Kenney scale and orientation, like the commercial kit next to them: a storey is about 0.4, a door
0.27, the front faces -Z, every building stands on y = 0 centred on x / z. Plain colours only
(baseColorFactor), the bulbs, neons and lit windows glow with their emissiveFactor, so Godot and
Chat City (whose build script palettes the colours) both read them as they are.

Usage:  python tools/make_vegas_buildings.py
Needs:  numpy.
"""
import json, os, struct
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CUR = os.path.join(ROOT, 'FREEMODELS', 'curated')
PACK = 'vegas_buildings'

## name: (base colour (linear), emissive, metallic, roughness)
MATERIALS = {
    'cream': ((0.62, 0.5, 0.36), None, 0.0, 0.8),
    'red': ((0.4, 0.035, 0.045), None, 0.0, 0.7),
    'purple': ((0.16, 0.04, 0.28), None, 0.0, 0.7),
    'black': ((0.025, 0.025, 0.03), None, 0.0, 0.6),
    'navy': ((0.03, 0.05, 0.12), None, 0.0, 0.6),
    'concrete': ((0.3, 0.3, 0.32), None, 0.0, 0.9),
    'gold': ((1.0, 0.6, 0.12), (0.12, 0.07, 0.01), 0.6, 0.35),
    'glass': ((0.02, 0.03, 0.05), None, 0.3, 0.1),
    'sign': ((0.06, 0.005, 0.01), None, 0.0, 0.8),
    'window': ((1.0, 0.8, 0.5), (0.5, 0.37, 0.2), 0.0, 0.9),
    'window_cool': ((0.75, 0.88, 1.0), (0.3, 0.38, 0.5), 0.0, 0.9),
    'bulb': ((1.0, 0.85, 0.45), (1.0, 0.78, 0.32), 0.0, 0.9),
    'pink': ((1.0, 0.12, 0.6), (1.0, 0.08, 0.5), 0.0, 0.9),
    'cyan': ((0.1, 0.9, 1.0), (0.05, 0.75, 1.0), 0.0, 0.9),
    'neon_red': ((1.0, 0.06, 0.06), (1.0, 0.04, 0.04), 0.0, 0.9),
    'violet': ((0.65, 0.25, 1.0), (0.55, 0.18, 1.0), 0.0, 0.9),
    'green': ((0.2, 1.0, 0.35), (0.12, 0.95, 0.25), 0.0, 0.9),
}

## 5 x 7 dot letters (rows top to bottom), and 7 x 7 card suits.
FONT = {
    'A': ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
    'B': ['11110', '10001', '10001', '11110', '10001', '10001', '11110'],
    'C': ['01111', '10000', '10000', '10000', '10000', '10000', '01111'],
    'D': ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
    'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
    'G': ['01111', '10000', '10000', '10011', '10001', '10001', '01111'],
    'I': ['11111', '00100', '00100', '00100', '00100', '00100', '11111'],
    'K': ['10001', '10010', '10100', '11000', '10100', '10010', '10001'],
    'L': ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
    'N': ['10001', '11001', '10101', '10101', '10011', '10001', '10001'],
    'O': ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
    'P': ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
    'R': ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
    'S': ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
    'U': ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
    'Y': ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
    'heart': ['0110110', '1111111', '1111111', '1111111', '0111110', '0011100', '0001000'],
    'spade': ['0001000', '0011100', '0111110', '1111111', '1111111', '0101010', '0011100'],
    'diamond': ['0001000', '0011100', '0111110', '1111111', '0111110', '0011100', '0001000'],
    'club': ['0011100', '0011100', '1101011', '1111111', '1101011', '0001000', '0011100'],
}


class Model:
    """Triangles of one building, by material."""

    def __init__(self, name):
        self.name = name
        self.parts = {}

    def tris(self, mat, pos, nrm):
        p, n = self.parts.setdefault(mat, ([], []))
        p.append(np.asarray(pos, float).reshape(-1, 3, 3))
        n.append(np.asarray(nrm, float).reshape(-1, 3, 3))

    def box(self, mat, lo, hi, faces='xXyYzZ'):
        """An axis box from corner `lo` to corner `hi`; `faces` keeps only some sides (x = -X)."""
        (x0, y0, z0), (x1, y1, z1) = lo, hi
        sides = {
            'x': ([(x0, y0, z1), (x0, y1, z1), (x0, y1, z0), (x0, y0, z0)], (-1, 0, 0)),
            'X': ([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], (1, 0, 0)),
            'y': ([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], (0, -1, 0)),
            'Y': ([(x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)], (0, 1, 0)),
            'z': ([(x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0)], (0, 0, -1)),
            'Z': ([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], (0, 0, 1)),
        }
        for f in faces:
            q, n = sides[f]
            self.tris(mat, [q[0], q[1], q[2], q[0], q[2], q[3]], [n] * 6)

    def front_quad(self, mat, x0, x1, y0, y1, z):
        """A flat panel on a -Z wall (seen from -Z)."""
        self.box(mat, (x0, y0, z), (x1, y1, z), 'z')

    def size(self):
        p = np.concatenate([np.concatenate(v[0]) for v in self.parts.values()]).reshape(-1, 3)
        return p.min(0), p.max(0)


def dots(word, pitch, gap=1):
    """Centres (u, v) of the bulbs of `word`: u to the right, v up, centred on (0, 0)."""
    glyphs = [FONT[word]] if word in FONT else [FONT[c] for c in word]
    out, u = [], 0
    for rows in glyphs:
        for r, row in enumerate(rows):
            for c, on in enumerate(row):
                if on == '1':
                    out.append((u + c, len(rows) - 1 - r))
        u += len(rows[0]) + gap
    a = np.array(out, float)
    width = u - gap - 1
    a[:, 0] -= width / 2.0
    a[:, 1] -= (len(glyphs[0]) - 1) / 2.0
    return a * pitch


def bulbs_front(m, mat, uv, cx, cy, z, size):
    """Bulbs on a -Z wall at depth z (they stick out toward -Z); u runs to the viewer's right,
    which is -X for someone looking at a -Z front."""
    h = size / 2.0
    for u, v in uv:
        x, y = cx - u, cy + v
        m.box(mat, (x - h, y - h, z - size), (x + h, y + h, z), 'xXyYz')


def bulbs_side(m, mat, uv, x, cy, cz, size, toward):
    """Bulbs on a wall facing `toward` (-1: -X, +1: +X), centred on (cy, cz). Seen from -X the
    viewer's right is +Z, seen from +X it is -Z."""
    h = size / 2.0
    for u, v in uv:
        z, y = cz + u * -toward, cy + v
        x0, x1 = (x - size, x) if toward < 0 else (x, x + size)
        m.box(mat, (x0, y - h, z - h), (x1, y + h, z + h), 'xXyYzZ'.replace('X' if toward < 0 else 'x', ''))


def border(m, mat, x0, x1, y0, y1, z, pitch, size):
    """Chaser bulbs round a front sign."""
    pts = []
    nx = max(2, int(round((x1 - x0) / pitch)))
    ny = max(2, int(round((y1 - y0) / pitch)))
    for i in range(nx + 1):
        x = x0 + (x1 - x0) * i / nx
        pts += [(x, y0), (x, y1)]
    for j in range(1, ny):
        y = y0 + (y1 - y0) * j / ny
        pts += [(x0, y), (x1, y)]
    h = size / 2.0
    for x, y in pts:
        m.box(mat, (x - h, y - h, z - size), (x + h, y + h, z), 'xXyYz')


def front_sign(m, word, cx, y0, z, width, letter_mat, panel='sign', frame='gold', chaser='bulb', pad=0.06):
    """A roof or wall sign: a dark panel with a gold frame, `word` in bulbs, chaser bulbs round
    it. Its pitch fills `width`; returns the top of the sign."""
    n = len(word)
    cols = n * 6 - 1
    pitch = (width - 2 * pad) / cols
    height = 7 * pitch + 2 * pad
    x0, x1, y1 = cx - width / 2.0, cx + width / 2.0, y0 + height
    m.box(panel, (x0, y0, z), (x1, y1, z + 0.05))
    t = 0.015
    for a, b in (((x0 - t, y0 - t), (x1 + t, y0)), ((x0 - t, y1), (x1 + t, y1 + t)),
                 ((x0 - t, y0), (x0, y1)), ((x1, y0), (x1 + t, y1))):
        m.box(frame, (a[0], a[1], z - 0.01), (b[0], b[1], z + 0.05))
    bulbs_front(m, letter_mat, dots(word, pitch), cx, (y0 + y1) / 2.0, z, pitch * 0.72)
    if chaser:
        border(m, chaser, x0 + pad * 0.4, x1 - pad * 0.4, y0 + pad * 0.4, y1 - pad * 0.4, z, pitch * 1.5, pitch * 0.45)
    return y1


def windows(m, rng, x0, x1, y0, y1, cols, rows, z=0.0, lit=0.6, gap=0.3, face='z', other=0.0):
    """A grid of window panes on a wall (z: the -Z front; x / X: the side walls at `other`)."""
    cw = (x1 - x0) / cols
    rh = (y1 - y0) / rows
    for r in range(rows):
        for c in range(cols):
            a0, a1 = x0 + c * cw + cw * gap / 2.0, x0 + (c + 1) * cw - cw * gap / 2.0
            b0, b1 = y0 + r * rh + rh * gap / 2.0, y0 + (r + 1) * rh - rh * gap / 2.0
            roll = rng.random()
            mat = ('window' if rng.random() < 0.75 else 'window_cool') if roll < lit else 'glass'
            if face == 'z':
                m.box(mat, (a0, b0, z - 0.004), (a1, b1, z), 'z')
            else:
                x = other + (-0.004 if face == 'x' else 0.004)
                lo, hi = sorted((other, x))
                m.box(mat, (lo, b0, a0), (hi, b1, a1), face)


def canopy(m, x0, x1, y, z_wall, depth, top='gold', strip='bulb'):
    """A marquee canopy over a door, bulbs along its three outer edges."""
    zf = z_wall - depth
    m.box(top, (x0, y, zf), (x1, y + 0.05, z_wall))
    s = 0.022
    n = int((x1 - x0) / 0.05)
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        m.box(strip, (x - s / 2, y - s, zf - s), (x + s / 2, y, zf))
    k = int(depth / 0.05)
    for j in range(k + 1):
        z = zf + depth * j / k
        for x in (x0, x1):
            m.box(strip, (x - s / 2, y - s, z - s / 2), (x + s / 2, y, z + s / 2))


def door(m, cx, z, w=0.3, h=0.27, mat='window', frame='gold'):
    m.box(frame, (cx - w / 2 - 0.02, 0.0, z - 0.012), (cx + w / 2 + 0.02, h + 0.02, z))
    m.box(mat, (cx - w / 2, 0.0, z - 0.016), (cx + w / 2, h, z - 0.012), 'z')


def neon_outline(m, mat, x0, x1, y0, y1, z, t=0.018):
    """Neon tubes along the edges of a -Z front."""
    for a, b in (((x0, y0), (x1, y0 + t)), ((x0, y1 - t), (x1, y1)), ((x0, y0), (x0 + t, y1)), ((x1 - t, y0), (x1, y1))):
        m.box(mat, (a[0], a[1], z - t), (b[0], b[1], z))


def casino_a(rng):
    m = Model('vegas_casino_a')
    W, D, H = 2.4, 1.6, 1.0
    z = -D / 2
    m.box('cream', (-W / 2, 0, -D / 2), (W / 2, H, D / 2))
    m.box('red', (-W / 2 - 0.02, H, -D / 2 - 0.02), (W / 2 + 0.02, H + 0.06, D / 2 + 0.02))
    m.box('concrete', (-W / 2 + 0.02, H + 0.06, -D / 2 + 0.02), (W / 2 - 0.02, H + 0.061, D / 2 - 0.02), 'Y')
    # Ground floor: a glass front between gold pillars, the doors under the canopy.
    m.box('glass', (-W / 2 + 0.1, 0.02, z - 0.005), (W / 2 - 0.1, 0.34, z), 'z')
    for x in np.linspace(-W / 2 + 0.1, W / 2 - 0.1, 7):
        m.box('gold', (x - 0.025, 0, z - 0.03), (x + 0.025, H, z))
    door(m, -0.13, z - 0.005)
    door(m, 0.13, z - 0.005)
    canopy(m, -0.6, 0.6, 0.34, z, 0.4)
    windows(m, rng, -W / 2 + 0.12, W / 2 - 0.12, 0.42, 0.95, 12, 2, z=z, lit=0.7)
    for side, x in (('x', -W / 2), ('X', W / 2)):
        windows(m, rng, -D / 2 + 0.1, D / 2 - 0.1, 0.42, 0.95, 7, 2, lit=0.5, face=side, other=x)
    neon_outline(m, 'pink', -W / 2 - 0.02, W / 2 + 0.02, 0.36, 0.4, z - 0.03)
    front_sign(m, 'CASINO', 0.0, H + 0.06, z + 0.04, 1.9, 'bulb', panel='sign')
    return m


def casino_b(rng):
    m = Model('vegas_casino_b')
    W, D, P = 2.0, 1.6, 0.72
    z = -D / 2
    # The casino: two storeys, its name in bulbs above the canopy.
    m.box('red', (-W / 2, 0, -D / 2), (W / 2, P, D / 2))
    m.box('gold', (-W / 2 - 0.02, P, -D / 2 - 0.02), (W / 2 + 0.02, P + 0.04, D / 2 + 0.02))
    m.box('concrete', (-W / 2, P + 0.04, -D / 2), (W / 2, P + 0.041, D / 2), 'Y')
    m.box('glass', (-W / 2 + 0.1, 0.02, z - 0.005), (W / 2 - 0.1, 0.34, z), 'z')
    for x in (-W / 2 + 0.1, -0.3, 0.3, W / 2 - 0.1):
        m.box('gold', (x - 0.025, 0, z - 0.03), (x + 0.025, 0.36, z))
    door(m, 0.0, z - 0.005, w=0.4)
    canopy(m, -0.45, 0.45, 0.34, z, 0.35)
    front_sign(m, 'CASINO', 0.0, 0.4, z - 0.035, 1.5, 'bulb', chaser=None, pad=0.03)
    # The hotel tower on the back of the casino, lit windows all round, a gold crown, ROYAL.
    tx, tz0, tz1, top = 0.7, -0.3, 0.6, 3.6
    m.box('navy', (-tx, P, tz0), (tx, top, tz1))
    windows(m, rng, -tx + 0.05, tx - 0.05, P + 0.08, top - 0.08, 8, 14, z=tz0, lit=0.62, gap=0.35)
    for side, x in (('x', -tx), ('X', tx)):
        windows(m, rng, tz0 + 0.05, tz1 - 0.05, P + 0.08, top - 0.08, 5, 14, lit=0.55, gap=0.35, face=side, other=x)
    for x in (-tx, tx):
        m.box('gold', (x - 0.03, P, tz0 - 0.03), (x + 0.03, top, tz0 + 0.03))
    m.box('gold', (-tx - 0.03, top, tz0 - 0.03), (tx + 0.03, top + 0.12, tz1 + 0.03))
    neon_outline(m, 'violet', -tx - 0.03, tx + 0.03, top + 0.02, top + 0.1, tz0 - 0.03, t=0.02)
    front_sign(m, 'ROYAL', 0.0, top + 0.12, tz0 + 0.02, 1.3, 'bulb')
    return m


def casino_c(rng):
    m = Model('vegas_casino_c')
    W, D, H = 2.0, 1.46, 1.2
    z = -D / 2
    m.box('purple', (-W / 2, 0, -D / 2), (W / 2, H, D / 2))
    m.box('gold', (-W / 2 - 0.02, H, -D / 2 - 0.02), (W / 2 + 0.02, H + 0.05, D / 2 + 0.02))
    m.box('concrete', (-W / 2, H + 0.05, -D / 2), (W / 2, H + 0.051, D / 2), 'Y')
    m.box('gold', (-W / 2 - 0.02, 0.36, z - 0.03), (W / 2 + 0.02, 0.4, z))
    m.box('glass', (-W / 2 + 0.08, 0.02, z - 0.005), (W / 2 - 0.08, 0.34, z), 'z')
    door(m, -0.15, z - 0.005)
    door(m, 0.15, z - 0.005)
    canopy(m, -0.55, 0.55, 0.34, z, 0.3)
    # The four suits across the first floor, in their colours, on black panels. u runs left to
    # right seen from the street, which is +X to -X.
    pitch = 0.05
    for k, (suit, mat) in enumerate((('spade', 'cyan'), ('heart', 'neon_red'), ('club', 'green'), ('diamond', 'neon_red'))):
        x = 0.69 - k * 0.46
        m.box('black', (x - 0.19, 0.5, z - 0.008), (x + 0.19, 0.95, z), 'xXyYz')
        bulbs_front(m, mat, dots(suit, pitch), x, 0.725, z - 0.008, pitch * 0.8)
    for x in np.linspace(-W / 2 + 0.04, W / 2 - 0.04, 5):
        m.box('gold', (x - 0.03, 0.4, z - 0.03), (x + 0.03, H, z))
    windows(m, rng, -W / 2 + 0.08, W / 2 - 0.08, 1.0, 1.17, 10, 1, z=z, lit=0.8)
    for side, x in (('x', -W / 2), ('X', W / 2)):
        windows(m, rng, -D / 2 + 0.1, D / 2 - 0.1, 0.45, 1.15, 6, 3, lit=0.5, face=side, other=x)
    neon_outline(m, 'violet', -W / 2 - 0.02, W / 2 + 0.02, 0.0, H + 0.05, z - 0.031)
    front_sign(m, 'POKER', 0.0, H + 0.05, z + 0.05, 1.5, 'pink')
    return m


def club_a(rng):
    m = Model('vegas_club_a')
    W, D, H = 1.2, 1.0, 0.85
    z = -D / 2
    m.box('black', (-W / 2, 0, -D / 2), (W / 2, H, D / 2))
    m.box('concrete', (-W / 2 + 0.03, H, -D / 2 + 0.03), (W / 2 - 0.03, H + 0.001, D / 2 - 0.03), 'Y')
    neon_outline(m, 'pink', -W / 2, W / 2, 0.0, H, z)
    for x in (-W / 2, W / 2):    # the side walls: a tube along the top
        m.box('pink', (x - 0.009, H - 0.018, -D / 2), (x + 0.009, H, D / 2))
    door(m, 0.0, z - 0.005, w=0.26, mat='pink', frame='black')
    canopy(m, -0.22, 0.22, 0.32, z, 0.22, top='black', strip='cyan')
    front_sign(m, 'CLUB', 0.0, 0.42, z - 0.01, 0.9, 'pink', panel='black', frame='pink', chaser=None, pad=0.04)
    return m


def club_b(rng):
    m = Model('vegas_club_b')
    W, D, H = 1.0, 1.0, 1.2
    z = -D / 2
    m.box('navy', (-W / 2, 0, -D / 2), (W / 2, H, D / 2))
    m.box('concrete', (-W / 2, H, -D / 2), (W / 2, H + 0.001, D / 2), 'Y')
    for y in (0.4, 0.7, 1.0):    # cyan bands round the building
        m.box('cyan', (-W / 2 - 0.012, y, -D / 2 - 0.012), (W / 2 + 0.012, y + 0.025, D / 2 + 0.012))
    door(m, -0.15, z - 0.005, w=0.28, mat='violet', frame='gold')
    canopy(m, -0.35, 0.05, 0.33, z, 0.22, top='navy', strip='cyan')
    windows(m, rng, -W / 2 + 0.08, W / 2 - 0.08, 0.45, 0.68, 4, 1, z=z, lit=0.6)
    windows(m, rng, -W / 2 + 0.08, W / 2 - 0.08, 0.75, 0.98, 4, 1, z=z, lit=0.6)
    # The blade sign out of the front, at its +X corner: DISCO top to bottom on both faces,
    # a cyan tube round it.
    bx, bz0, bz1, by0, by1 = W / 2 - 0.12, z - 0.34, z, 0.3, H + 0.25
    m.box('black', (bx - 0.02, by0, bz0), (bx + 0.02, by1, bz1))
    pitch = 0.027
    for i, ch in enumerate('DISCO'):
        cy = by1 - 0.05 - 3 * pitch - i * 8 * pitch
        for toward in (-1, 1):
            xx = bx - 0.02 if toward < 0 else bx + 0.02
            bulbs_side(m, 'pink', dots(ch, pitch), xx, cy, (bz0 + bz1) / 2, pitch * 0.75, toward)
    for toward in (-1, 1):
        xx = bx - 0.021 if toward < 0 else bx + 0.021
        x0, x1 = (xx - 0.012, xx) if toward < 0 else (xx, xx + 0.012)
        for a, b in (((by0, bz0), (by0 + 0.012, bz1)), ((by1 - 0.012, bz0), (by1, bz1)), ((by0, bz0), (by1, bz0 + 0.012))):
            m.box('cyan', (x0, a[0], a[1]), (x1, b[0], b[1]))
    return m


def club_c(rng):
    m = Model('vegas_club_c')
    W, D, H = 1.4, 1.0, 0.72
    z = -D / 2
    m.box('red', (-W / 2, 0, -D / 2), (W / 2, H, D / 2))
    m.box('gold', (-W / 2 - 0.02, H, -D / 2 - 0.02), (W / 2 + 0.02, H + 0.04, D / 2 + 0.02))
    m.box('concrete', (-W / 2, H + 0.04, -D / 2), (W / 2, H + 0.041, D / 2), 'Y')
    m.box('glass', (-W / 2 + 0.08, 0.02, z - 0.005), (W / 2 - 0.08, 0.3, z), 'z')
    door(m, 0.0, z - 0.005, w=0.3)
    # A gold awning the whole width, bulbs under its edge.
    canopy(m, -W / 2 + 0.04, W / 2 - 0.04, 0.32, z, 0.18)
    front_sign(m, 'LOUNGE', 0.0, 0.4, z - 0.01, 1.2, 'cyan', frame='violet', chaser=None, pad=0.035)
    neon_outline(m, 'violet', -W / 2, W / 2, 0.0, H, z - 0.001)
    for side, x in (('x', -W / 2), ('X', W / 2)):
        windows(m, rng, -D / 2 + 0.1, D / 2 - 0.1, 0.4, 0.66, 4, 1, lit=0.6, face=side, other=x)
    return m


def club_low(rng):
    m = Model('vegas_club_low')
    W, D, H = 0.9, 0.9, 0.42
    z = -D / 2
    m.box('purple', (-W / 2, 0, -D / 2), (W / 2, H, D / 2))
    m.box('concrete', (-W / 2, H, -D / 2), (W / 2, H + 0.001, D / 2), 'Y')
    door(m, 0.0, z - 0.005, w=0.28, mat='cyan', frame='black')
    neon_outline(m, 'cyan', -W / 2, W / 2, 0.0, H, z)
    front_sign(m, 'DANCE', 0.0, H - 0.02, z + 0.03, 0.8, 'pink', pad=0.035)
    return m


def bar_low(rng):
    m = Model('vegas_bar_low')
    W, D, H = 0.9, 0.8, 0.42
    z = -D / 2
    m.box('black', (-W / 2, 0, -D / 2), (W / 2, H, D / 2))
    m.box('gold', (-W / 2 - 0.015, H, -D / 2 - 0.015), (W / 2 + 0.015, H + 0.03, D / 2 + 0.015))
    m.box('concrete', (-W / 2, H + 0.03, -D / 2), (W / 2, H + 0.031, D / 2), 'Y')
    m.box('glass', (-W / 2 + 0.06, 0.04, z - 0.005), (-0.2, 0.3, z), 'z')
    m.box('window', (0.2, 0.04, z - 0.005), (W / 2 - 0.06, 0.3, z), 'z')
    door(m, 0.0, z - 0.005, w=0.26, mat='window', frame='gold')
    front_sign(m, 'BAR', 0.0, H + 0.03, z + 0.03, 0.55, 'neon_red', pad=0.035)
    neon_outline(m, 'neon_red', -W / 2, W / 2, 0.0, H, z - 0.001, t=0.014)
    return m


def write_pack(models, path):
    """One glTF binary: a root node `PACK` (GODOT_single_root) with one node and mesh per model,
    one primitive per material, the corners of each welded."""
    names = list(MATERIALS)
    j = {'asset': {'version': '2.0', 'generator': 'tools/make_vegas_buildings.py'},
         'extensionsUsed': ['GODOT_single_root'], 'scene': 0,
         'scenes': [{'nodes': [0]}], 'nodes': [{'name': PACK, 'children': list(range(1, len(models) + 1))}],
         'meshes': [], 'materials': [], 'accessors': [], 'bufferViews': []}
    for n in names:
        rgb, em, metal, rough = MATERIALS[n]
        mat = {'name': n, 'pbrMetallicRoughness': {'baseColorFactor': list(rgb) + [1.0],
                                                   'metallicFactor': metal, 'roughnessFactor': rough}}
        if em:
            mat['emissiveFactor'] = list(em)
        j['materials'].append(mat)
    blob = bytearray()

    def add(arr, kind, target, minmax=False):
        while len(blob) % 4:
            blob.append(0)
        j['bufferViews'].append({'buffer': 0, 'byteOffset': len(blob), 'byteLength': arr.nbytes, 'target': target})
        blob.extend(arr.tobytes())
        acc = {'bufferView': len(j['bufferViews']) - 1, 'componentType': 5126 if arr.dtype == np.float32 else 5125,
               'count': len(arr), 'type': kind}
        if minmax:
            acc['min'] = arr.min(0).tolist()
            acc['max'] = arr.max(0).tolist()
        j['accessors'].append(acc)
        return len(j['accessors']) - 1

    for m in models:
        prims = []
        for mat, (P, N) in m.parts.items():
            pos = np.concatenate(P).reshape(-1, 3)
            nrm = np.concatenate(N).reshape(-1, 3)
            uniq, idx = np.unique(np.round(np.hstack([pos, nrm]), 5), axis=0, return_inverse=True)
            prims.append({'attributes': {'POSITION': add(uniq[:, :3].astype(np.float32), 'VEC3', 34962, True),
                                         'NORMAL': add(uniq[:, 3:].astype(np.float32), 'VEC3', 34962)},
                          'indices': add(idx.reshape(-1).astype(np.uint32), 'SCALAR', 34963),
                          'material': names.index(mat)})
        j['meshes'].append({'name': m.name, 'primitives': prims})
        j['nodes'].append({'name': m.name, 'mesh': len(j['meshes']) - 1})
    while len(blob) % 4:
        blob.append(0)
    j['buffers'] = [{'byteLength': len(blob)}]
    js = json.dumps(j, separators=(',', ':')).encode()
    js += b' ' * (-len(js) % 4)
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob))
    out += struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(blob), 0x004E4942) + bytes(blob)
    with open(path, 'wb') as f:
        f.write(out)


## Model -> catalog category (scripts/assets/model_catalog.gd).
CATS = {'vegas_casino_a': 'VEGAS_CASINO', 'vegas_casino_b': 'VEGAS_CASINO', 'vegas_casino_c': 'VEGAS_CASINO',
        'vegas_club_a': 'VEGAS_CLUB', 'vegas_club_b': 'VEGAS_CLUB', 'vegas_club_c': 'VEGAS_CLUB',
        'vegas_club_low': 'VEGAS_CLUB', 'vegas_bar_low': 'VEGAS_CLUB'}


if __name__ == '__main__':
    rng = np.random.default_rng(2026)
    models = [f(rng) for f in (casino_a, casino_b, casino_c, club_a, club_b, club_c, club_low, bar_low)]
    write_pack(models, os.path.join(CUR, PACK + '.glb'))
    with open(os.path.join(CUR, PACK + '.models.json'), 'w', newline='\n') as f:
        json.dump({'file': PACK + '.glb', 'models': [{'cat': CATS[m.name], 'node': m.name} for m in models]}, f, indent='\t')
        f.write('\n')
    for m in models:
        lo, hi = m.size()
        tris = sum(len(np.concatenate(p)) for p, _ in m.parts.values())
        print('%-16s size %.3f x %.3f x %.3f  min x %.3f z %.3f  %5d triangles' % (m.name, *(hi - lo), lo[0], lo[2], tris))


