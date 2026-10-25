"""The dollar buildings of Las Vegas, made from Kenney's commercial building-n (an office block
with the green cross of a pharmacy on its side):

  FREEMODELS/curated/building_n_dollar.glb             building-n, the green cross swapped for a
                                                       golden dollar sign (on a dark panel, in
                                                       the frame of the old sign)
  FREEMODELS/curated/building_n_dollar_tall.glb        the same building twice as high, built
                                                       as one: the ground floor (door, awnings)
                                                       once, nine floors above it, one roof, and
                                                       one bigger dollar sign at the top
  FREEMODELS/curated/building_n_dollar_light.glb       the night models: the same by day, plus a
  FREEMODELS/curated/building_n_dollar_tall_light.glb  night map (glTF emissiveTexture on its own
                                                       TEXCOORD_1, see make_night_variants.py):
                                                       the dollar sign glows gold, about two
                                                       windows in three are lit (warm or cool
                                                       light, the shop windows of the ground
                                                       floor always)

The game reads only the night models (their .models.json, category VEGAS_DOLLAR); the two others
are kept as the day models they come from.

Usage:  python tools/make_dollar_building.py
Needs:  numpy, Pillow.
"""
import io, json, os
import numpy as np
from PIL import Image
from make_night_variants import (GLB, Triangles, CUR, OWN_NIGHT, box_tris, night_map, write_geometry,
                                 write_night)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT = os.path.join(ROOT, 'FREEMODELS', 'kenney_city-kit-commercial_2.1', 'Models', 'GLB format')
CAT = 'VEGAS_DOLLAR'
## Floors of building-n (cut planes, y): ground floor below 0.4, then a floor 0.4 high up to
## 1.2, then the dark floor and the top floor (the sign across both) up to 2.0, the roof above.
FLOOR = 0.4
CUT_A, CUT_B, CUT_C, CUT_ROOF = 0.4, 0.8, 1.2, 2.0
## The old sign: its frame lies on the wall x -0.46, its panel at x -0.485, centred here (y, z).
WALL_X = -0.46
PANEL_X = -0.485
SIGN_CENTRE = (1.6, -0.31)
## The tall building: floors of the middle kind added above the top floor of the first five, so
## that the top (dark floor, top floor, roof) goes this much higher; its sign is this much bigger.
TALL_EXTRA = 3
TALL_SIGN = 1.75
## Dollar sign: height (with its bar) and depth on the 0.336 m panel of the old sign.
DOLLAR_H = 0.3
DOLLAR_D = 0.03
## Gold (linear) by day; the colour it glows with at night.
GOLD = (1.0, 0.6, 0.1)
GOLD_NIGHT = (1.0, 0.62, 0.08)
## Night windows: share lit, light (linear) and brightness (like the lit windows of the Kenney
## kits, NightWindows: WINDOW_LIGHT at 1.3).
WINDOW_LIT = 0.62
WINDOW_TINTS = [((1.0, 0.78, 0.45), 0.55), ((1.0, 0.9, 0.7), 0.3), ((0.7, 0.85, 1.0), 0.15)]
WINDOW_GLOW = 1.4
## Share of its own colour every face glows with at night (the facade barely shows).
FACADE = 0.02


def kenney(model_node):
    """building-n as a pack of one: root node -> `model_node` (the mesh), its palette texture
    put inside the file."""
    g = GLB(os.path.join(KIT, 'building-n.glb'))
    j = g.j
    img = Image.open(os.path.join(KIT, 'Textures', 'colormap.png')).convert('RGB')
    b = io.BytesIO()
    img.save(b, 'PNG', optimize=True)
    j['images'] = [{'bufferView': g.append(b.getvalue()), 'mimeType': 'image/png', 'name': 'colormap'}]
    for m in j['materials']:
        m['pbrMetallicRoughness']['baseColorTexture'].pop('extensions', None)
    for k in ('extensionsUsed', 'extensionsRequired'):
        if k in j:
            j[k] = [e for e in j[k] if e != 'KHR_texture_transform']
            if not j[k]:
                del j[k]
    # The root node is the root of the scene Godot imports (the game looks for `model_node` in it).
    j['extensionsUsed'] = j.get('extensionsUsed', []) + ['GODOT_single_root']
    j['nodes'] = [{'name': model_node, 'children': [1]}, {'name': model_node, 'mesh': 0}]
    j['scenes'] = [{'nodes': [0]}]
    j['scene'] = 0
    return g


def set_triangles(tri, pos, nrm, uv):
    """`tri` (one primitive, root without transform) now holds these triangles."""
    tri.local, tri.pos = pos, pos.copy()
    tri.local_nrm, tri.nrm = nrm, nrm.copy()
    tri.uv = uv
    tri.mat = np.zeros(len(pos), int)
    tri.mesh = np.zeros(len(pos), int)
    tri.prims = [(tri.prims[0][0], 0, len(pos))]


def sign_parts(tri):
    """(the whole old sign, its green cross, its light panel): the sign is the island of the
    green cross (the only green of the model)."""
    isl = tri.islands()
    col = tri.colours()
    green = col[:, 1] > col[:, 0] + 0.2
    sign = np.isin(isl, np.unique(isl[green]))
    assert tri.pos[sign][..., 0].max() < WALL_X + 0.001, 'the sign island reaches into the wall'
    cross = sign & green
    panel = sign & ~cross & (np.abs(tri.pos[..., 0] - PANEL_X) < 1e-3).all(1)
    assert cross.sum() == 34 and panel.sum() == 16, (cross.sum(), panel.sum())
    return sign, cross, panel


def dollar(height, depth):
    """Triangles (pos, nrm: (T, 3, 3)) of a dollar sign in its own space: u to the right, v up,
    d out of the wall (from 0 to `depth`); centred on u = v = 0, `height` high with its bar."""
    body = 0.8 * height            # the S alone
    w = 0.15 * height              # its stroke
    ry, rx = (body - w) / 4.0, 0.26 * height
    # The S: the upper bow from its end (upper right) round the top and the left down to the
    # middle, then the lower bow round the right and the bottom to its end (lower left).
    up = np.radians(np.linspace(25.0, 270.0, 15))
    low = np.radians(np.linspace(90.0, -155.0, 15))[1:]
    c = np.concatenate([np.stack([rx * np.cos(up), ry + ry * np.sin(up)], 1),
                        np.stack([rx * np.cos(low), -ry + ry * np.sin(low)], 1)])
    t = np.gradient(c, axis=0)
    t /= np.linalg.norm(t, axis=1, keepdims=True)
    n = np.stack([-t[:, 1], t[:, 0]], 1)
    L, R = c + n * w / 2.0, c - n * w / 2.0
    pos, nrm = [], []

    def quad(a, b, cc, d, normal):
        for tr in ((a, b, cc), (a, cc, d)):
            pos.append(tr)
            nrm.append([normal] * 3)

    def p3(p2, d):
        return np.array([p2[0], p2[1], d])
    for i in range(len(c) - 1):
        quad(p3(L[i], depth), p3(R[i], depth), p3(R[i + 1], depth), p3(L[i + 1], depth), (0.0, 0.0, 1.0))
        for E, sgn in ((L, 1.0), (R, -1.0)):
            m = (n[i] + n[i + 1]) * sgn
            m /= np.linalg.norm(m)
            quad(p3(E[i], 0.0), p3(E[i + 1], 0.0), p3(E[i + 1], depth), p3(E[i], depth), (m[0], m[1], 0.0))
    for i, sgn in ((0, -1.0), (len(c) - 1, 1.0)):
        quad(p3(L[i], 0.0), p3(R[i], 0.0), p3(R[i], depth), p3(L[i], depth), (t[i][0] * sgn, t[i][1] * sgn, 0.0))
    # The bar, a little less deep than the S (the S stays in front where they cross).
    bw = 0.09 * height
    bp, bn = box_tris((-bw / 2.0, -height / 2.0, 0.0), (bw / 2.0, height / 2.0, depth * 0.8))
    return np.concatenate([np.array(pos), bp]), np.concatenate([np.array(nrm, dtype=np.float64), bn])


def on_wall(pos, nrm, x, y, z):
    """Dollar space -> the -X wall: u along +z (to the right seen from -X), v up, d along -x."""
    turn = np.array([[0.0, 0.0, -1.0], [0.0, 1.0, 0.0], [1.0, 0.0, 0.0]])  # columns: u, v, d
    return pos @ turn.T + [x, y, z], nrm @ turn.T


def add_gold(g, pos, nrm):
    """The dollar sign: one more primitive of the building's mesh (so the game, which takes the
    node of the building, keeps it), in plain gold."""
    j = g.j
    j['materials'].append({'name': 'gold', 'doubleSided': True,
                           'pbrMetallicRoughness': {'baseColorFactor': list(GOLD) + [1.0],
                                                    'metallicFactor': 0.3, 'roughnessFactor': 0.35}})
    p = pos.reshape(-1, 3)
    j['meshes'][0]['primitives'].append({
        'attributes': {'POSITION': g.add_accessor(p, 'VEC3', True), 'NORMAL': g.add_accessor(nrm.reshape(-1, 3), 'VEC3'),
                       'TEXCOORD_0': g.add_accessor(np.zeros((len(p), 2)), 'VEC2')},
        'indices': g.add_accessor(np.arange(len(p)), 'SCALAR'), 'material': len(j['materials']) - 1})


def build(tall, model_node):
    """The building (tall or not) with its dollar sign: (glb, triangles, the gold triangles)."""
    g = kenney(model_node)
    tri = Triangles(g)
    sign, cross, panel = sign_parts(tri)
    # The panel of the sign takes the darkest colour of the palette (the gold shows on it).
    col = tri.colours()
    tri.uv[panel] = tri.uv[col.sum(1).argmin()].mean(0)
    pos, nrm, uv = tri.local, tri.local_nrm, tri.uv
    sign_y, sign_z = SIGN_CENTRE
    scale = 1.0
    if not tall:
        keep = ~cross
        pos, nrm, uv = pos[keep], nrm[keep], uv[keep]
    else:
        # Every face goes with the floor it belongs to (by its middle; a flat face lying on a
        # cut plane with the floor under it when it looks up, above it when it looks down).
        cy = pos[..., 1].mean(1) + nrm[..., 1].mean(1) * -1e-4
        ground = cy < CUT_B                       # ground floor and first floor (door, awnings)
        middle = (cy >= CUT_B) & (cy < CUT_C)     # a plain floor
        top = (cy >= CUT_C) & (cy < CUT_ROOF)     # dark floor and top floor
        roof = cy >= CUT_ROOF
        frame = sign & ~cross
        # The awnings reach into the plain floor: the added floors keep only what stands inside
        # the walls (the outline of the roof).
        R = pos[roof].reshape(-1, 3)
        c = pos.mean(1)
        inside = ((c[:, [0, 2]] > R.min(0)[[0, 2]] - 0.01) & (c[:, [0, 2]] < R.max(0)[[0, 2]] + 0.01)).all(1)
        # The top floors and the roof go up by a copy of themselves and the added floors.
        lift = (CUT_ROOF - CUT_C) + TALL_EXTRA * FLOOR
        parts = [(ground, 0.0), (middle, 0.0), (top & ~sign, 0.0)]
        parts += [(middle & inside, (CUT_ROOF - CUT_B) + k * FLOOR) for k in range(TALL_EXTRA)]
        parts += [(top & ~sign, lift), (roof, lift)]
        P = [pos[m] + [0.0, dy, 0.0] for m, dy in parts]
        N = [nrm[m] for m, _ in parts]
        U = [uv[m] for m, _ in parts]
        # One sign, bigger, across the dark floor and the top floor of the top half.
        scale = TALL_SIGN
        sign_y += lift
        anchor = np.array([WALL_X, SIGN_CENTRE[0], SIGN_CENTRE[1]])
        P.append((pos[frame] - anchor) * scale + [WALL_X, sign_y, sign_z])
        N.append(nrm[frame])
        U.append(uv[frame])
        pos, nrm, uv = np.concatenate(P), np.concatenate(N), np.concatenate(U)
    set_triangles(tri, pos, nrm, uv)
    write_geometry(g, tri)
    panel_x = WALL_X + (PANEL_X - WALL_X) * scale
    dp, dn = on_wall(*dollar(DOLLAR_H * scale, DOLLAR_D * scale), panel_x, sign_y, sign_z)
    add_gold(g, dp, dn)
    tri = Triangles(g)
    gold = tri.mat == len(g.j['materials']) - 1
    return g, tri, gold


def window_panes(tri):
    """Window glass grouped by pane (glass triangles that share a corner): [bool per triangle]."""
    col = tri.colours()
    glass = np.flatnonzero(col[:, 2] > col[:, 0] + 0.25)
    _, weld = np.unique(np.round(tri.pos[glass].reshape(-1, 3), 4), axis=0, return_inverse=True)
    weld = weld.reshape(-1, 3)
    parent = list(range(len(glass)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    first = {}
    for k, t in enumerate(weld):
        for v in t:
            if v in first:
                parent[find(k)] = find(first[v])
            else:
                first[v] = k
    roots = np.array([find(k) for k in range(len(glass))])
    panes = []
    for r in np.unique(roots):
        m = np.zeros(len(tri.pos), bool)
        m[glass[roots == r]] = True
        panes.append(m)
    return panes


def night(g, tri, gold, name, tall):
    """The night map: the gold sign, the lit windows (chosen at random, the same every run)."""
    rng = np.random.default_rng(17 if tall else 7)
    lit = [np.zeros(len(tri.pos), bool) for _ in WINDOW_TINTS]
    panes = window_panes(tri)
    weights = np.array([w for _, w in WINDOW_TINTS])
    for m in panes:
        shop = tri.pos[m][..., 1].max() < CUT_A
        if shop:
            lit[1] |= m
        elif rng.random() < WINDOW_LIT:
            lit[rng.choice(len(WINDOW_TINTS), p=weights / weights.sum())] |= m
    scale = TALL_SIGN if tall else 1.0
    # The gold is stored in its own proportions (lamp_value would keep only its red at full,
    # which turns the far, averaged map red round every window).
    lamps = [(gold, GOLD_NIGHT, {'store': np.array(GOLD_NIGHT) * 0.85, 'reach': 0.18 * scale, 'strength': 0.6})]
    # The windows light only their glass: the light they would throw on their dark frames comes
    # out as a red rim.
    for m, (rgb, _) in zip(lit, WINDOW_TINTS):
        lamps.append((m, rgb, {'store': np.array(rgb) * WINDOW_GLOW / OWN_NIGHT, 'reach': 0.01, 'strength': 0.0}))
    print('  %s: %d gold triangles, %d of %d windows lit' % (name, gold.sum(), sum(int(any((m & l).any() for l in lit)) for m in panes), len(panes)))
    uv2, img = night_map(tri, lamps, reach=0.18, strength=0.6, base=FACADE / OWN_NIGHT, plain=True)
    write_night(g, tri, uv2, img, name)


def make(tall):
    node = 'building_n_dollar_tall' if tall else 'building_n_dollar'
    g, tri, gold = build(tall, node)
    g.save(os.path.join(CUR, node + '.glb'))
    g, tri, gold = build(tall, node)
    g.j['nodes'][0]['name'] = node + '_light'
    night(g, tri, gold, node + '_light', tall)
    g.save(os.path.join(CUR, node + '_light.glb'))
    with open(os.path.join(CUR, node + '_light.models.json'), 'w', newline='\n') as f:
        json.dump({'file': node + '_light.glb', 'models': [{'cat': CAT, 'node': node}]}, f, indent='\t')
        f.write('\n')


if __name__ == '__main__':
    make(False)
    make(True)
