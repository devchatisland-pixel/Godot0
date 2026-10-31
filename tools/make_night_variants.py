"""Night-lit duplicates of some models: the same model by day, plus a night map (glTF
emissiveTexture) that holds its lights. No object is added. The model they come from is left
as it is (a backup); only the lists the game reads (.models.json) point to the duplicate.

  FREEMODELS/curated/pharmacy_night.glb      the pharmacy of public_main.glb alone; its big
                                             green cross glows green, the facade is softly lit
  FREEMODELS/curated/cinema_night.glb        the cinema of cinema2.glb; the word CINEMA glows red
  FREEMODELS/curated/hotel_small_night.glb   hotel_small of hotels.glb; the word HOTEL glows green
  FREEMODELS/curated/hotel_stars_night.glb   hotel_stars of hotels.glb; its five stars glow yellow
  FREEMODELS/curated/police_hq_night.glb     police_hq of public_main.glb; the word POLICE and the
                                             round sign on the roof glow blue
  FREEMODELS/curated/bank_minimalist_night.glb  bank_minimalist of bank_min.glb; the letters BANK $ glow white
  FREEMODELS/curated/school_night.glb        school of public_main.glb; the word SCHOOL glows coral red
  FREEMODELS/curated/hospital_night.glb      hospital of public_main.glb; the blue cross of the front and
                                             the word HOSPITAL on the roof glow strong blue (the lit H of the helipad is added by
                                             the game, BuildingExtras)
  FREEMODELS/curated/city_hall_night.glb     city_hall of public_main.glb; the words CITY HALL glow
                                             coral red, the colour of the letters
  FREEMODELS/curated/stadium_night.glb       the stadium; only the inside (pitch, stands) is lit, the
                                             outer walls stay dark (its floodlights: BuildingExtras)
  shops/models/<shop>_night.glb              the 14 shops of the development island, each with its
                                             SHOP sign glowing (the sign of shop-general-generic on the
                                             roof, or its own word turned into SHOP); the game puts each
                                             copy in front of its original (python tools/make_night_variants.py shops)
  vehicles/.../police_us_cruiser_night.glb   the red and the blue lens of the light bar glow
  vehicles/.../police_jp_black_night.glb     the red roof beacon glows

The night map does not use the texture coordinates of the model (several faces of these models
share the same texels, so a light painted there would show in the wrong places too). It has its
own, TEXCOORD_1: every triangle gets a little patch of its own in the map, neighbours in space
being neighbours in the map (so the map still makes sense when it is seen from far and
averaged). What is painted in it:
  - the lamps themselves, in their colour;
  - the light they throw on the faces around them (by distance in space, a little less on the
    faces that look away), tinted by the colour of the face;
  - for the pharmacy, the hotels and the police, the whole facade softly lit like the other
    public buildings.

The game (NightWindows.light_own) keeps the map dark by day and multiplies it by
NightWindows.OWN_NIGHT (3.0) at night, so the map stores a third of the final light. The
lamps alone are stored brighter (their main colour channel at 1.0): seen from near they stay
their pure colour (the other channels still end below 1.0), seen from far they keep showing
when the map is averaged with the dark faces around them.

Usage:  python tools/make_night_variants.py          (everything)
        python tools/make_night_variants.py signs    (the cinema, the hotels, the police, the
                                                      hospital and the city hall only)
        python tools/make_night_variants.py bank_school   (the bank and the school only)
        python tools/make_night_variants.py police   (the police HQ only)
        python tools/make_night_variants.py gas      (the gas station of free_mini only)
        python tools/make_night_variants.py shops    (the night copies of the shops only)
        python tools/make_night_variants.py stadium  (the stadium only)
Needs:  numpy, Pillow.
"""
import io, json, os, struct
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VEH = os.path.join(ROOT, 'vehicles', 'models', 'municipal_emergency')
CUR = os.path.join(ROOT, 'FREEMODELS', 'curated')
SHOPS = os.path.join(ROOT, 'shops', 'models')
OWN_NIGHT = 3.0
## Night colours of the lamps, as they look at night (linear).
CROSS_GREEN = (0.0, 1.0, 0.25)
CROSS_RIM = (0.45, 1.0, 0.5)
LAMP_RED = (1.0, 0.08, 0.05)
LAMP_BLUE = (0.06, 0.3, 1.0)
## Night colours of the lit letters and stars of the signs (linear).
CINEMA_RED = (1.0, 0.04, 0.03)
HOTEL_GREEN = (0.3, 1.0, 0.3)
STAR_YELLOW = (1.0, 0.8, 0.0)
POLICE_BLUE = (0.08, 0.35, 1.0)
HOSPITAL_BLUE = (0.04, 0.4, 1.0)
CITY_HALL_CORAL = (1.0, 0.25, 0.15)
BANK_WHITE = (1.0, 0.95, 0.85)
SCHOOL_RED = (1.0, 0.2, 0.12)
SHOP_RED = (1.0, 0.04, 0.03)
SHOP_WHITE = (1.0, 0.92, 0.75)
CANDY_PINK = (1.0, 0.1, 0.5)
SIGN_BLUE = (0.05, 0.4, 1.0)
SIGN_ORANGE = (1.0, 0.4, 0.0)
SIGN_GREEN = (0.1, 1.0, 0.2)
SIGN_BLUE_BRIGHT = (0.3, 0.65, 1.0)
SIGN_RED = (1.0, 0.04, 0.03)
SIGN_PINK = CANDY_PINK
SIGN_MAUVE = (0.85, 0.6, 1.0)
SIGN_PURPLE = (0.6, 0.25, 1.0)
## Pharmacy facade at night: the share of its own colour it glows with (a little brighter
## than the public buildings around it, far from white).
FACADE = 0.25
## Size of the night maps (pixels); doubled for the models with many triangles.
MAP_SIZE = 512

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


class GLB:
    def __init__(s, path):
        b = open(path, 'rb').read()
        n = struct.unpack_from('<I', b, 12)[0]
        s.j = json.loads(b[20:20 + n])
        o = 20 + n
        s.bin = bytearray(b[o + 8:o + 8 + struct.unpack_from('<I', b, o)[0]])

    def view(s, i):
        bv = s.j['bufferViews'][i]
        o = bv.get('byteOffset', 0)
        return bytes(s.bin[o:o + bv['byteLength']])

    def acc(s, i):
        a = s.j['accessors'][i]
        bv = s.j['bufferViews'][a['bufferView']]
        dt, n = np.dtype(CT[a['componentType']]), NC[a['type']]
        off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
        stride = bv.get('byteStride', 0) or dt.itemsize * n
        raw = np.frombuffer(bytes(s.bin[off:off + stride * (a['count'] - 1) + dt.itemsize * n]).ljust(stride * a['count'], b'\0'),
                            np.uint8).reshape(a['count'], stride)
        arr = np.frombuffer(raw[:, :dt.itemsize * n].tobytes(), dt)
        return arr.reshape(a['count'], n) if n > 1 else arr

    def image(s, i=0):
        return Image.open(io.BytesIO(s.view(s.j['images'][i]['bufferView']))).convert('RGB')

    def append(s, data, target=None):
        while len(s.bin) % 4:
            s.bin.append(0)
        bv = {'buffer': 0, 'byteOffset': len(s.bin), 'byteLength': len(data)}
        if target:
            bv['target'] = target
        s.j['bufferViews'].append(bv)
        s.bin += data
        return len(s.j['bufferViews']) - 1

    def add_accessor(s, arr, typ, minmax=False):
        index = typ == 'SCALAR'
        arr = arr.astype(np.uint32 if index else np.float32)
        a = {'bufferView': s.append(arr.tobytes(), 34963 if index else 34962),
             'componentType': 5125 if index else 5126, 'count': len(arr), 'type': typ}
        if minmax:
            a['min'], a['max'] = arr.min(0).tolist(), arr.max(0).tolist()
        s.j['accessors'].append(a)
        return len(s.j['accessors']) - 1

    def set_geometry(s, prim, pos, nrm, uv, uv2):
        """Gives `prim` new vertices, three per triangle (no index is shared; without `uv2`
        the equal vertices are shared again, which keeps the file small)."""
        if uv2 is None:
            rows = np.concatenate([pos, nrm, uv], 1).astype(np.float32)
            rows, index = np.unique(rows, axis=0, return_inverse=True)
            pos, nrm, uv = rows[:, 0:3], rows[:, 3:6], rows[:, 6:8]
            prim['attributes'] = {'POSITION': s.add_accessor(pos, 'VEC3', True), 'NORMAL': s.add_accessor(nrm, 'VEC3'),
                                  'TEXCOORD_0': s.add_accessor(uv, 'VEC2')}
            prim['indices'] = s.add_accessor(index.reshape(-1), 'SCALAR')
            return
        prim['attributes'] = {'POSITION': s.add_accessor(pos, 'VEC3', True), 'NORMAL': s.add_accessor(nrm, 'VEC3'),
                              'TEXCOORD_0': s.add_accessor(uv, 'VEC2')}
        if uv2 is not None:
            prim['attributes']['TEXCOORD_1'] = s.add_accessor(uv2, 'VEC2')
        prim['indices'] = s.add_accessor(np.arange(len(pos)), 'SCALAR')

    def add_texture(s, img, name):
        b = io.BytesIO()
        img.save(b, 'PNG', optimize=True)
        s.j.setdefault('images', []).append({'bufferView': s.append(b.getvalue()), 'mimeType': 'image/png', 'name': name})
        tex = s.j.setdefault('textures', [])
        if not s.j.get('samplers'):
            s.j['samplers'] = [{}]
        tex.append({'sampler': tex[0].get('sampler', 0) if tex else 0, 'source': len(s.j['images']) - 1})
        return len(s.j['textures']) - 1

    def root(s):
        return s.j['scenes'][s.j.get('scene', 0)]['nodes'][0]

    def drop_unused_materials(s):
        """Keeps only the materials the meshes use, and their textures and images (a model cut
        out of a pack would carry the textures of the whole pack)."""
        j = s.j
        j.setdefault('images', [])
        j.setdefault('textures', [])
        used = sorted({p['material'] for m in j['meshes'] for p in m['primitives'] if 'material' in p})
        mmap = {o: n for n, o in enumerate(used)}
        j['materials'] = [j['materials'][o] for o in used]
        for m in j['meshes']:
            for p in m['primitives']:
                if 'material' in p:
                    p['material'] = mmap[p['material']]
        refs = []
        def find(d):
            for k, v in d.items():
                if isinstance(v, dict):
                    if k.endswith('Texture') and 'index' in v:
                        refs.append(v)
                    else:
                        find(v)
        for m in j['materials']:
            find(m)
        tex = sorted({r['index'] for r in refs})
        tmap = {o: n for n, o in enumerate(tex)}
        for r in refs:
            r['index'] = tmap[r['index']]
        j['textures'] = [j['textures'][o] for o in tex]
        imgs = sorted({t['source'] for t in j['textures']})
        imap = {o: n for n, o in enumerate(imgs)}
        for t in j['textures']:
            t['source'] = imap[t['source']]
        j['images'] = [j['images'][o] for o in imgs]

    def keep_only(s, root_children):
        """Drops every node outside `root_children` (and the unused data), repacking the buffer."""
        j = s.j
        j.setdefault('images', [])
        keep_nodes = []
        def walk(i):
            keep_nodes.append(i)
            for c in j['nodes'][i].get('children', []):
                walk(c)
        keep_nodes.append(s.root())
        for c in root_children:
            walk(c)
        nmap = {o: n for n, o in enumerate(keep_nodes)}
        meshes = sorted({j['nodes'][i]['mesh'] for i in keep_nodes if 'mesh' in j['nodes'][i]})
        mmap = {o: n for n, o in enumerate(meshes)}
        accs = sorted({a for m in meshes for p in j['meshes'][m]['primitives']
                       for a in list(p['attributes'].values()) + ([p['indices']] if 'indices' in p else [])})
        amap = {o: n for n, o in enumerate(accs)}
        views = sorted({j['accessors'][a]['bufferView'] for a in accs} | {im['bufferView'] for im in j['images']})
        vmap, nb = {}, bytearray()
        new_views = []
        for v in views:
            while len(nb) % 4:
                nb.append(0)
            bv = dict(j['bufferViews'][v])
            data = s.view(v)
            bv['byteOffset'] = len(nb)
            nb += data
            vmap[v] = len(new_views)
            new_views.append(bv)
        nodes = []
        for o in keep_nodes:
            nd = dict(j['nodes'][o])
            if 'children' in nd:
                nd['children'] = [nmap[c] for c in nd['children'] if c in nmap]
            if 'mesh' in nd:
                nd['mesh'] = mmap[nd['mesh']]
            nodes.append(nd)
        new_meshes = []
        for m in meshes:
            mesh = json.loads(json.dumps(j['meshes'][m]))
            for p in mesh['primitives']:
                p['attributes'] = {k: amap[a] for k, a in p['attributes'].items()}
                if 'indices' in p:
                    p['indices'] = amap[p['indices']]
            new_meshes.append(mesh)
        new_accs = []
        for a in accs:
            acc = dict(j['accessors'][a])
            acc['bufferView'] = vmap[acc['bufferView']]
            new_accs.append(acc)
        for im in j['images']:
            im['bufferView'] = vmap[im['bufferView']]
        j['nodes'], j['meshes'], j['accessors'], j['bufferViews'] = nodes, new_meshes, new_accs, new_views
        j['scenes'] = [{'nodes': [0]}]
        j['scene'] = 0
        s.bin = nb

    def save(s, path):
        # Only what the nodes still use is written (the old vertices are left out).
        s.keep_only(list(s.j['nodes'][s.root()].get('children', [])))
        while len(s.bin) % 4:
            s.bin.append(0)
        s.j['buffers'] = [{'byteLength': len(s.bin)}]
        js = json.dumps(s.j, separators=(',', ':')).encode()
        js += b' ' * (-len(js) % 4)
        with open(path, 'wb') as f:
            f.write(struct.pack('<III', 0x46546C67, 2, 28 + len(js) + len(s.bin)))
            f.write(struct.pack('<II', len(js), 0x4E4F534A) + js)
            f.write(struct.pack('<II', len(s.bin), 0x004E4942) + bytes(s.bin))
        print('wrote', os.path.relpath(path, ROOT), '%.0f KB' % (os.path.getsize(path) / 1024))


def to_srgb(lin):
    lin = np.clip(lin, 0.0, 1.0)
    return np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)


def to_linear(srgb):
    return np.where(srgb <= 0.04045, srgb / 12.92, np.power((srgb + 0.055) / 1.055, 2.4))


def lamp_value(rgb):
    """What the map stores for a lamp of colour `rgb`: a third of it (the game gives it
    back), but its main channel at full, so the lamp still shows when the map is averaged."""
    rgb = np.array(rgb, dtype=np.float64)
    return np.where(rgb >= rgb.max() - 1e-6, 1.0, rgb / OWN_NIGHT)


# --- The model as loose triangles ------------------------------------------------------
class Triangles:
    """Every triangle of every mesh node of a file: corners in the space of the scene."""

    def __init__(s, g):
        s.g = g
        s.prims = []            # (primitive, first triangle, number of triangles)
        pos, nrm, uv, local, lnrm, mat = [], [], [], [], [], []
        j = g.j
        count = [0]

        def walk(i, parent):
            node = j['nodes'][i]
            world = parent @ node_matrix(node)
            if 'mesh' in node:
                turn = np.linalg.inv(world[:3, :3]).T
                for p in j['meshes'][node['mesh']]['primitives']:
                    P = g.acc(p['attributes']['POSITION']).astype(np.float64)
                    N = g.acc(p['attributes']['NORMAL']).astype(np.float64)
                    U = (g.acc(p['attributes']['TEXCOORD_0']).astype(np.float64) if 'TEXCOORD_0' in p['attributes']
                         else np.zeros((len(P), 2)))
                    I = g.acc(p['indices']).reshape(-1, 3) if 'indices' in p else np.arange(len(P)).reshape(-1, 3)
                    s.prims.append((p, count[0], len(I)))
                    count[0] += len(I)
                    local.append(P[I])
                    lnrm.append(N[I])
                    pos.append(P[I] @ world[:3, :3].T + world[:3, 3])
                    n = N[I] @ turn.T
                    nrm.append(n / (np.linalg.norm(n, axis=2, keepdims=True) + 1e-12))
                    uv.append(U[I])
                    mat.append(np.full(len(I), p.get('material', 0)))
            for c in node.get('children', []):
                walk(c, world)
        walk(g.root(), np.eye(4))
        s.local = np.concatenate(local)   # (T, 3, 3) in the space of the mesh
        s.local_nrm = np.concatenate(lnrm)
        s.pos = np.concatenate(pos)       # (T, 3, 3) in the space of the scene
        s.nrm = np.concatenate(nrm)
        s.uv = np.concatenate(uv)
        s.mat = np.concatenate(mat)
        s.mesh = np.concatenate([np.full(n, k) for k, (_, _, n) in enumerate(s.prims)])

    def colours(s):
        """Colour (linear) of every triangle: its material's texture at the middle of the
        triangle (the colour of the material when it has no texture)."""
        j = s.g.j
        out = np.zeros((len(s.pos), 3))
        c = s.uv.mean(1) % 1.0
        for m in np.unique(s.mat):
            sel = s.mat == m
            pbr = j['materials'][m].get('pbrMetallicRoughness', {})
            factor = np.array(pbr.get('baseColorFactor', [1, 1, 1, 1])[:3], dtype=np.float64)
            if 'baseColorTexture' in pbr:
                img = np.asarray(s.g.image(j['textures'][pbr['baseColorTexture']['index']]['source'])).astype(np.float64) / 255.0
                h, w = img.shape[:2]
                out[sel] = to_linear(img[np.minimum((c[sel, 1] * h).astype(int), h - 1),
                                         np.minimum((c[sel, 0] * w).astype(int), w - 1)]) * factor
            else:
                out[sel] = factor
        return out

    def islands(s):
        """Island id of every triangle (corners at the same place are welded)."""
        _, weld = np.unique(np.round(s.pos.reshape(-1, 3), 4), axis=0, return_inverse=True)
        weld = weld.reshape(-1, 3)
        parent = np.arange(weld.max() + 1)
        def find(a):
            while parent[a] != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a
        for t in weld:
            a = find(t[0])
            for v in t[1:]:
                parent[find(v)] = a
        return np.array([find(t[0]) for t in weld])


def node_matrix(n):
    if 'matrix' in n:
        return np.array(n['matrix'], dtype=np.float64).reshape(4, 4).T
    m = np.eye(4)
    if 'scale' in n:
        m = np.diag(list(n['scale']) + [1.0]) @ m
    if 'rotation' in n:
        x, y, z, w = n['rotation']
        r = np.eye(4)
        r[:3, :3] = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
        m = r @ m
    if 'translation' in n:
        t = np.eye(4)
        t[:3, 3] = n['translation']
        m = t @ m
    return m


def morton(points):
    """Order that keeps points close in space close in the list."""
    lo, hi = points.min(0), points.max(0)
    q = ((points - lo) / np.maximum(hi - lo, 1e-9) * 1023).astype(np.int64)
    code = np.zeros(len(points), dtype=np.int64)
    for bit in range(10):
        for axis in range(3):
            code |= ((q[:, axis] >> bit) & 1) << (3 * bit + axis)
    return np.argsort(code, kind='stable')


def night_map(tri, lamps, reach, strength, base=0.0, size=MAP_SIZE, plain=False):
    """Paints the night map of the triangles `tri` and returns (TEXCOORD_1 per corner (T, 3, 2),
    the map as an image).
    `lamps`: [(triangles of the lamp (bool per triangle), colour)], each with an optional third
    item {'store': value stored for the lamp (instead of lamp_value), 'reach', 'strength': its
    own}; `reach`: distance at which
    the light a lamp throws has fallen to a fifth; `strength`: that light right beside the lamp
    (1 = as bright as the lamp); `base`: share of its own colour every face glows with (one
    number, or one per triangle).
    `plain`: the numbers are stored as they are, not through the sRGB curve. Measured on
    screen, the game shows a stored value times OWN_NIGHT as it is: a plain map comes out
    in the colours asked for, a curved one brighter and paler (blue creeps into a green).
    The vehicles keep the curved map (the wide glow round their lamps), the pharmacy is plain."""
    T = len(tri.pos)
    order = morton(tri.pos.mean(1))
    grid = int(np.ceil(np.sqrt(np.ceil(T / 2.0))))
    while size // grid < 8 and size < 2048:
        size *= 2
    cell = size // grid
    assert cell >= 8, 'too many triangles for a %d px night map' % size
    pad, far = 1.5, 3.75
    span = cell - pad - far
    # Texel centres of one cell; the lower left half belongs to the first triangle of the
    # cell, the upper right half to the second.
    ys, xs = np.mgrid[0:cell, 0:cell] + 0.5
    first = (xs + ys) < cell
    bary = []
    for half in (first, ~first):
        x, y = xs[half], ys[half]
        u, v = ((x - pad) / span, (y - pad) / span) if half is first else ((cell - pad - x) / span, (cell - pad - y) / span)
        bary.append((np.clip(u, -0.35, 1.35), np.clip(v, -0.35, 1.35)))
    corners = [np.array([[pad, pad], [pad + span, pad], [pad, pad + span]]),
               np.array([[cell - pad, cell - pad], [cell - pad - span, cell - pad], [cell - pad, cell - pad - span]])]
    colour = tri.colours()
    own = np.zeros((T, 3))
    is_lamp = np.zeros(T, bool)
    sources = []
    for lamp in lamps:
        mask, rgb = lamp[0], lamp[1]
        opt = lamp[2] if len(lamp) > 2 else {}
        own[mask] = opt.get('store', lamp_value(rgb))
        is_lamp |= mask
        if not mask.any():
            continue
        p = tri.pos[mask]
        pts = np.concatenate([p.reshape(-1, 3), p.mean(1), (p[:, [0, 1, 2]] + p[:, [1, 2, 0]]).reshape(-1, 3) / 2.0])
        sources.append((np.unique(np.round(pts, 3), axis=0), np.array(rgb, dtype=np.float64),
                        opt.get('reach', reach), opt.get('strength', strength)))
    img = np.zeros((size, size, 3))
    uv2 = np.zeros((T, 3, 2))
    centre = tri.pos.mean(1)
    radius = np.linalg.norm(tri.pos - centre[:, None, :], axis=2).max(1)
    for n, k in enumerate(order):
        cx, cy, half = (n // 2) % grid * cell, (n // 2) // grid * cell, n % 2
        uv2[k] = (corners[half] + [cx, cy]) / size
        sel = first if half == 0 else ~first
        if is_lamp[k]:
            value = np.broadcast_to(own[k], (int(sel.sum()), 3))
        else:
            b = base[k] if np.ndim(base) else base
            value = np.zeros((int(sel.sum()), 3)) + b * (to_srgb(colour[k]) if plain else colour[k])
            u, v = bary[half]
            w = np.stack([1.0 - u - v, u, v], 1)
            pos = w @ tri.pos[k]
            nrm = w @ tri.nrm[k]
            nrm /= np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-9
            for pts, rgb, lreach, lstrength in sources:
                if np.linalg.norm(pts - centre[k], axis=1).min() > lreach * 4.0 + radius[k]:
                    continue
                d = np.linalg.norm(pos[:, None, :] - pts[None, :, :], axis=2)
                near = d.argmin(1)
                dist = d[np.arange(len(pos)), near]
                to = (pts[near] - pos) / (dist[:, None] + 1e-9)
                facing = 0.35 + 0.65 * np.clip((nrm * to).sum(1), 0.0, 1.0)
                # A face touching the lamp is lit whatever way it looks.
                facing = np.where(dist < lreach * 0.25, 1.0, facing)
                fall = lstrength / (1.0 + 4.0 * (dist / lreach) ** 2)
                value = value + (fall * facing)[:, None] * rgb * (0.4 + 0.6 * colour[k]) / OWN_NIGHT
        block = img[cy:cy + cell, cx:cx + cell]
        block[sel] = value
    stored = np.clip(img, 0.0, 1.0) if plain else to_srgb(img)
    return uv2, Image.fromarray((stored * 255).round().astype(np.uint8))


def write_geometry(g, tri, uv2=None):
    """The triangles of `tri` become the vertices of their primitives (with the coordinates
    `uv2` as TEXCOORD_1 when given); a primitive left without any triangle goes, and its mesh
    with it when it was the last one."""
    for p, start, count in tri.prims:
        if count == 0:
            for k, mesh in enumerate(g.j['meshes']):
                if any(q is p for q in mesh['primitives']):
                    mesh['primitives'] = [q for q in mesh['primitives'] if q is not p]
                    if not mesh['primitives']:
                        for nd in g.j['nodes']:
                            if nd.get('mesh') == k:
                                del nd['mesh']
            continue
        sl = slice(start, start + count)
        g.set_geometry(p, tri.local[sl].reshape(-1, 3), tri.local_nrm[sl].reshape(-1, 3), tri.uv[sl].reshape(-1, 2),
                       None if uv2 is None else uv2[sl].reshape(-1, 2))


def write_night(g, tri, uv2, img, name):
    """The triangles get their new coordinates, every material the night map."""
    write_geometry(g, tri, uv2)
    tex = g.add_texture(img, name)
    for m in g.j['materials']:
        m['emissiveTexture'] = {'index': tex, 'texCoord': 1}
        m['emissiveFactor'] = [1.0, 1.0, 1.0]


# --- Pharmacy ------------------------------------------------------------------------
def pharmacy():
    g = GLB(os.path.join(CUR, 'public_main.glb'))
    j = g.j
    pharm = next(c for c in j['nodes'][g.root()]['children'] if j['nodes'][c]['name'] == 'pharmacy')
    g.keep_only([pharm])
    j['nodes'][0]['name'] = 'pharmacy_night'
    tri = Triangles(g)
    # The cross is the island that reaches the highest (140 triangles); its green faces are
    # the cross, the pale ones its rim.
    isl = tri.islands()
    tops = {k: tri.pos[isl == k][..., 1].max() for k in np.unique(isl)}
    cross = isl == max(tops, key=tops.get)
    col = tri.colours()
    green = cross & (col[:, 1] > col[:, 0] + 0.1)
    print('  pharmacy: %d green and %d rim triangles in the cross' % (green.sum(), (cross & ~green).sum()))
    uv2, img = night_map(tri, [(green, CROSS_GREEN), (cross & ~green, CROSS_RIM)], reach=0.22, strength=0.55,
                         base=FACADE / OWN_NIGHT, plain=True)
    write_night(g, tri, uv2, img, 'pharmacy_night')
    g.save(os.path.join(CUR, 'pharmacy_night.glb'))
    with open(os.path.join(CUR, 'pharmacy_night.models.json'), 'w', newline='\n') as f:
        json.dump({'file': 'pharmacy_night.glb', 'models': [{'cat': 'PHARMACY', 'node': 'pharmacy'}]}, f, indent='\t')
        f.write('\n')


# --- Lit signs: letters and stars ------------------------------------------------------
def lit_sign(pack, node, cat, pick, rgb, reach, strength, base, what):
    """`node` of the pack `pack`.glb alone, as <node>_night.glb: the faces `pick(tri)` glow
    `rgb`, the faces around them catch a little of it, every face glows with `base` of its own
    colour. The pack is not changed; its manifest no longer lists `node` (by hand).
    `pick` may also return [(faces, colour)] for lamps of several colours; `base` may be a
    function of the triangles (one value per triangle)."""
    g = GLB(os.path.join(CUR, pack + '.glb'))
    j = g.j
    keep = next(c for c in j['nodes'][g.root()]['children'] if j['nodes'][c]['name'] == node)
    g.keep_only([keep])
    g.drop_unused_materials()
    j['nodes'][0]['name'] = node + '_night'
    tri = Triangles(g)
    lamps = pick(tri)
    if isinstance(lamps, np.ndarray):
        lamps = [(lamps, rgb)]
    print('  %s: %s triangles in %s' % (node, ' + '.join(str(m.sum()) for m, _ in lamps), what))
    if callable(base):
        base = base(tri)
    uv2, img = night_map(tri, lamps, reach=reach, strength=strength, base=base, plain=True)
    write_night(g, tri, uv2, img, node + '_night')
    g.save(os.path.join(CUR, node + '_night.glb'))
    with open(os.path.join(CUR, node + '_night.models.json'), 'w', newline='\n') as f:
        json.dump({'file': node + '_night.glb', 'models': [{'cat': cat, 'node': node}]}, f, indent='\t')
        f.write('\n')


def islands_in(tri, lo_min, hi_max, count):
    """Faces of the islands that lie inside the box (lo_min, hi_max); there must be `count`."""
    lo_min, hi_max = np.array(lo_min), np.array(hi_max)
    found = [0]
    def test(lo, hi, n):
        inside = bool((lo >= lo_min).all() and (hi <= hi_max).all())
        found[0] += inside
        return inside
    out = island_where(tri, test)
    assert found[0] == count, 'found %d islands, not %d' % (found[0], count)
    return out


def cinema_letters(tri):
    # The six orange letters over the entrance, in front of the facade (z 0.22 to 0.30).
    return islands_in(tri, (-0.8, 0.79, 0.2), (0.8, 1.13, 0.31), 6)


def hotel_small_letters(tri):
    # The five green letters standing on the roof, along the side of the building (x -0.75).
    return islands_in(tri, (-0.8, 3.2, -0.8), (-0.7, 3.6, 0.8), 5)


def hotel_stars_stars(tri):
    # The five yellow stars under the word HOTEL, at the top of the front (z 0.95 to 0.99).
    return islands_in(tri, (-0.95, 3.5, 0.94), (0.95, 3.82, 1.0), 5)


def police_letters(tri):
    # The six blue letters on the board over the door (z 0.22 to 0.23).
    return islands_in(tri, (-0.3, 0.85, 0.21), (0.3, 0.99, 0.24), 6)


def police_badge(tri):
    # The gold badge in front of the round sign on the roof.
    return islands_in(tri, (-0.09, 1.23, 0.17), (0.09, 1.4, 0.19), 1)


def police_signs(tri):
    # The word POLICE over the door and the round sign on the roof (y 1.17 to 1.44, its
    # gold badge left out: it shows in its own colour on the blue disc).
    roof = islands_in(tri, (-0.14, 1.16, 0.15), (0.14, 1.45, 0.19), 2) & ~police_badge(tri)
    return police_letters(tri) | roof


def police_base(tri):
    out = np.full(len(tri.pos), FACADE / OWN_NIGHT)
    out[police_badge(tri)] = 0.6
    return out


def hospital_cross(tri):
    # The blue cross on the front, over the entrance (z 1.32 to 1.36).
    return islands_in(tri, (-0.17, 0.34, 1.31), (0.17, 0.69, 1.37), 1)


def hospital_sign(tri):
    # The word HOSPITAL and its two small crosses on the board over the roof (z 0.62 to 0.91).
    return islands_in(tri, (-0.7, 1.97, 0.6), (0.7, 2.17, 0.92), 9)


def hospital_lights(tri):
    return hospital_cross(tri) | hospital_sign(tri)


def city_hall_letters(tri):
    # The eight letters of CITY HALL on the front (z 0.463 to 0.472).
    return islands_in(tri, (-0.3, 0.81, 0.46), (0.32, 0.915, 0.475), 8)


def police():
    # The word POLICE and the shield on the roof glow the same blue (its gold star stays gold).
    lit_sign('public_main', 'police_hq', 'POLICE_MAIN', police_signs, POLICE_BLUE, 0.12, 0.5, police_base,
             'the word POLICE and the roof sign')


def bank_letters(tri):
    # The letters B, A, N, K and the dollar sign on the dark board over the roof (z 1.065 to 1.093).
    return islands_in(tri, (-0.5, 2.37, 1.06), (0.48, 2.62, 1.1), 5)


def school_letters(tri):
    # The six letters of SCHOOL over the entrance of the front (z 2.162 to 2.172).
    return islands_in(tri, (-0.27, 0.75, 2.15), (0.27, 0.87, 2.18), 6)


def bank_school():
    lit_sign('bank_min', 'bank_minimalist', 'BANK_MIN', bank_letters, BANK_WHITE, 0.1, 0.5, FACADE / OWN_NIGHT,
             'the letters BANK $')
    lit_sign('public_main', 'school', 'SCHOOL_MAIN', school_letters, SCHOOL_RED, 0.1, 0.5, FACADE / OWN_NIGHT,
             'the word SCHOOL')


def hospital():
    lit_sign('public_main', 'hospital', 'HOSPITAL_MAIN', hospital_lights, HOSPITAL_BLUE, 0.35, 0.8,
             FACADE / OWN_NIGHT, 'the blue cross and the word HOSPITAL')


def signs():
    # The cinema had no lit facade: only its letters (and what they light) show at night.
    lit_sign('cinema2', 'cinema', 'CINEMA2', cinema_letters, CINEMA_RED, 0.2, 0.5, 0.0, 'the word CINEMA')
    lit_sign('hotels', 'hotel_small', 'HOTEL_LOW', hotel_small_letters, HOTEL_GREEN, 0.25, 0.5, FACADE / OWN_NIGHT,
             'the word HOTEL')
    lit_sign('hotels', 'hotel_stars', 'HOTEL_LOW', hotel_stars_stars, STAR_YELLOW, 0.2, 0.5, FACADE / OWN_NIGHT,
             'the stars')
    police()
    hospital()
    lit_sign('public_main', 'city_hall', 'CITY_HALL_MAIN', city_hall_letters, CITY_HALL_CORAL, 0.04, 0.3,
             FACADE / OWN_NIGHT, 'the words CITY HALL')
    bank_school()


# --- Shops of the development island: night copies with a lit SHOP sign ---------------
# shops/models/<shop>_night.glb: the shop as it is, its SHOP sign glowing at night. The game
# puts the copy in front of the original (ShopSites, MapShops); the original stays as it is.
# The sign of shop-general-generic (an orange board with a red frame and the red word SHOP, on
# two posts) is the one put on the roofs, its colours changed to suit each shop.
GENERIC = 'shop-general-generic'
## Colours of the generic sign as the file has them (linear): frame, board.
GENERIC_FRAME = (1.0, 0.05, 0.01)
GENERIC_BOARD = (0.9, 0.58, 0.21)
## Width of the generic sign (frame), height of its word (metres).
GENERIC_SIGN_W = 1.45
GENERIC_WORD_H = 0.33
SHOP_ORANGE = (1.0, 0.35, 0.0)
SHOP_PINK = (1.0, 0.12, 0.55)
SHOP_PURPLE = (0.55, 0.15, 1.0)
SHOP_YELLOW = (1.0, 0.75, 0.15)
NIGHT_WHITE = (1.0, 0.95, 0.85)


def srgb(hexcode):
    """A colour picked by eye (sRGB hex) as the linear colour of a material."""
    return tuple(float(v) for v in to_linear(np.array([int(hexcode[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])))


def generic_letters(tri):
    # The four red letters of SHOP in front of the board (z -0.90 to -0.86).
    return islands_in(tri, (-0.6, 2.2, -0.92), (0.7, 2.6, -0.84), 4)


def generic_sign(tri):
    # The whole sign: frame, board, letters and posts, over the front of the roof.
    return island_where(tri, lambda lo, hi, n: lo[1] >= 1.95 and hi[2] < -0.6 and lo[0] > -0.7 and hi[0] < 0.85)


def add_prim(g, name, pos, nrm, colour, uv=None, material=None):
    """A new mesh node under the root: `pos`, `nrm` (T, 3, 3) in the space of the scene.
    Flat `colour` (linear), or `material` (a glTF material, or the index of one of the file)
    with the coordinates `uv`."""
    j = g.j
    root = j['nodes'][g.root()]
    M = node_matrix(root)
    inv = np.linalg.inv(M)
    lp = pos.reshape(-1, 3) @ inv[:3, :3].T + inv[:3, 3]
    ln = nrm.reshape(-1, 3) @ M[:3, :3]
    ln /= np.linalg.norm(ln, axis=1, keepdims=True) + 1e-12
    if material is None:
        material = flat_material(name, colour)
    if not isinstance(material, int):
        j['materials'].append(material)
        material = len(j['materials']) - 1
    prim = {'attributes': {'POSITION': g.add_accessor(lp, 'VEC3', True), 'NORMAL': g.add_accessor(ln, 'VEC3')},
            'indices': g.add_accessor(np.arange(len(lp)), 'SCALAR'), 'material': material}
    if uv is not None:
        prim['attributes']['TEXCOORD_0'] = g.add_accessor(uv.reshape(-1, 2), 'VEC2')
    j['meshes'].append({'name': name, 'primitives': [prim]})
    j['nodes'].append({'name': name, 'mesh': len(j['meshes']) - 1})
    root.setdefault('children', []).append(len(j['nodes']) - 1)


def flat_material(name, colour):
    return {'name': name, 'doubleSided': True,
            'pbrMetallicRoughness': {'baseColorFactor': [float(c) for c in colour] + [1.0],
                                     'metallicFactor': 0.0, 'roughnessFactor': 0.9}}


def glowing(g, material, glow, name):
    """`material` (a glTF material, changed in place) with the emission map `glow` (an RGB
    image as floats 0..1) on the texture coordinates of the model. Only the materials that
    carry such a map light up in the game (NightWindows.light_own): the shop around the sign
    stays dark, as it is."""
    img = Image.fromarray((np.clip(glow, 0, 1) * 255).round().astype(np.uint8))
    material['name'] = name
    material['emissiveTexture'] = {'index': g.add_texture(img, name), 'texCoord': 0}
    material['emissiveFactor'] = [1.0, 1.0, 1.0]
    return material


def plain_glow(rgb):
    """A small emission map all of the colour of a lamp `rgb` (lamp_value: x OWN_NIGHT in the
    game, where the main channel clips at full and the others come back as they are)."""
    return np.zeros((4, 4, 3)) + lamp_value(rgb)


def drop_triangles(tri, drop):
    """Takes the triangles `drop` (bool per triangle) out of `tri`, primitive by primitive."""
    keep = ~drop
    prims, first = [], 0
    for p, start, count in tri.prims:
        n = int(keep[start:start + count].sum())
        prims.append((p, first, n))
        first += n
    for name in ('local', 'local_nrm', 'pos', 'nrm', 'uv', 'mat', 'mesh'):
        setattr(tri, name, getattr(tri, name)[keep])
    tri.prims = prims


def split_glow(g, sel, glow_of, base):
    """The faces `sel` of `g` leave their primitives for new ones of their own, with copies of
    their materials that glow: `glow_of(material, image of its colour or None)` gives the
    emission map (floats 0..1, on the texture coordinates of the model)."""
    j = g.j
    tri = Triangles(g)
    sel = sel(tri) if callable(sel) else sel
    pieces = []
    for m in np.unique(tri.mat[sel]):
        part = sel & (tri.mat == m)
        mat = json.loads(json.dumps(j['materials'][int(m)]))
        pbr = mat.get('pbrMetallicRoughness', {})
        src = pbr.get('baseColorTexture', mat.get('emissiveTexture'))
        img = None if src is None else np.asarray(g.image(j['textures'][src['index']]['source'])).astype(np.float64) / 255.0
        pieces.append((tri.pos[part], tri.nrm[part], tri.uv[part], mat, img))
    drop_triangles(tri, sel)
    write_geometry(g, tri)
    for k, (pos, nrm, uv, mat, img) in enumerate(pieces):
        add_prim(g, 'sign_%d' % k, pos, nrm, None, uv=uv, material=glowing(g, mat, glow_of(mat, img), '%s_night_%d' % (base, k)))
    return int(sel.sum())


## Godot keeps at most 256 surfaces per mesh, and the game merges a shop into one mesh.
MAX_SURFACES = 256


def merge_by_material(g):
    """One primitive per material instead of one per small mesh (the flower shop has 255 of
    them, and its sign would not fit any more): the same faces, fewer surfaces."""
    j = g.j
    tri = Triangles(g)
    root = j['nodes'][g.root()]
    for nd in j['nodes']:
        nd.pop('mesh', None)
    root['children'] = []
    j['meshes'] = []
    for m in np.unique(tri.mat):
        sel = tri.mat == m
        add_prim(g, 'part_%d' % m, tri.pos[sel], tri.nrm[sel], None, uv=tri.uv[sel], material=int(m))


def save_night(g, base):
    """Saves shops/models/<base>_night.glb with its sign as the only light: the other materials
    lose the light of their own some of them bring (lamps, glass, the old lit word)."""
    for m in g.j['materials']:
        if not m.get('name', '').startswith(base + '_night'):
            m.pop('emissiveTexture', None)
            m.pop('emissiveFactor', None)
            m.get('extensions', {}).pop('KHR_materials_emissive_strength', None)
    if sum(len(m['primitives']) for m in g.j['meshes']) > MAX_SURFACES:
        merge_by_material(g)
    g.save(os.path.join(SHOPS, base + '_night.glb'))


def lit_letters(name, pick, rgb, what):
    """<name>_night.glb: the faces `pick(tri)` (the letters of its own sign) glow `rgb`."""
    g = GLB(os.path.join(SHOPS, name + '.glb'))
    n = split_glow(g, pick, lambda mat, img: plain_glow(rgb), name)
    print('  %s: %d triangles in %s' % (name, n, what))
    save_night(g, name)


def finish(g, base, groups, rgb):
    """Adds the flat-coloured `groups` [(pos, nrm, colour, name)], the first one being the
    word, drawn in `rgb` and glowing in it, and saves <base>_night.glb."""
    for k, (pos, nrm, c, nm) in enumerate(groups):
        if k == 0:
            mat = glowing(g, flat_material(nm, c), plain_glow(rgb), base + '_night')
            add_prim(g, nm, pos, nrm, None, uv=np.zeros(pos.shape[:2] + (2,)), material=mat)
        else:
            add_prim(g, nm, pos, nrm, c)
    print('  %s: %d letter triangles' % (base, len(groups[0][0])))
    save_night(g, base)


def add_sign(base, rgb, frame, board, xc, roof_y, z_front, width):
    """<base>_night.glb: the shop `base` with the SHOP sign of the generic shop on its roof,
    `width` metres wide, the foot of its posts at (`xc`, `roof_y`) and its front a little
    behind the front edge of the roof `z_front`. The word is drawn in `rgb` and glows in it;
    the frame and the board take the colours `frame` and `board` (linear)."""
    tb = Triangles(GLB(os.path.join(SHOPS, GENERIC + '.glb')))
    parts = generic_sign(tb)
    letters = generic_letters(tb) & parts
    col = tb.colours()
    scale = width / GENERIC_SIGN_W
    foot = np.array([0.075, 1.98, -0.9])
    target = np.array([xc, roof_y, z_front + 0.15])
    def place(sel):
        return (tb.pos[sel] - foot) * scale + target
    groups = [(place(letters), tb.nrm[letters], np.array(rgb), 'sign_letters')]
    rest = parts & ~letters
    swap = {GENERIC_FRAME: frame, GENERIC_BOARD: board}
    for k, c in enumerate(np.unique(np.round(col[rest], 2), axis=0)):
        sel = rest & (np.abs(np.round(col, 2) - c).sum(1) < 1e-6)
        new = next((v for old, v in swap.items() if np.abs(np.array(old) - c).max() < 0.03), c)
        groups.append((place(sel), tb.nrm[sel], np.array(new), 'sign_%d' % k))
    finish(GLB(os.path.join(SHOPS, base + '.glb')), base, groups, rgb)


def swap_letters(base, rgb, old_letters, centres, height):
    """<base>_night.glb: the faces `old_letters(tri)` (a word of the front) come off, the four
    letters SHOP of the generic shop, `height` metres high, glow `rgb` instead. `centres`: one
    (x, y, z) for the whole word (its middle, z of its front), or four, one per letter as seen
    from the front (S, H, O, P: x going down)."""
    tb = Triangles(GLB(os.path.join(SHOPS, GENERIC + '.glb')))
    letters = generic_letters(tb)
    isl = tb.islands()
    scale = height / GENERIC_WORD_H
    def box(sel):
        P = tb.pos[sel].reshape(-1, 3)
        return P.min(0), P.max(0)
    if len(centres) == 1:
        pieces = [(letters, centres[0])]
    else:
        ids = sorted({int(k) for k in isl[letters]}, key=lambda k: -box(isl == k)[0][0])
        assert len(ids) == len(centres), 'found %d letters' % len(ids)
        pieces = [(isl == k, c) for k, c in zip(ids, centres)]
    pos, nrm = [], []
    for sel, c in pieces:
        lo, hi = box(sel)
        mid = np.array([(lo[0] + hi[0]) / 2.0, (lo[1] + hi[1]) / 2.0, lo[2]])
        pos.append((tb.pos[sel] - mid) * scale + np.array(c))
        nrm.append(tb.nrm[sel])
    g = GLB(os.path.join(SHOPS, base + '.glb'))
    tri = Triangles(g)
    old = old_letters(tri)
    print('  %s: %d triangles of the old word removed' % (base, old.sum()))
    drop_triangles(tri, old)
    write_geometry(g, tri)
    finish(g, base, [(np.concatenate(pos), np.concatenate(nrm), np.array(rgb), 'sign_letters')], rgb)


def painted_sign(base, pick, letter_px, rgb, recolour=None):
    """<base>_night.glb for a shop whose word is painted in a texture: the faces `pick(tri)`
    get a material of their own whose emission map holds `rgb` where `letter_px(image as
    floats 0..1)` is true, black elsewhere. `recolour(image) -> image`: new base colours of
    the sign (None: the texture as it is)."""
    g = GLB(os.path.join(SHOPS, base + '.glb'))
    def glow_of(mat, img):
        mask = letter_px(img)
        print('  %s: %d letter pixels' % (base, mask.sum()))
        if recolour is not None:
            day = Image.fromarray((np.clip(recolour(img), 0, 1) * 255).round().astype(np.uint8))
            pbr = mat.setdefault('pbrMetallicRoughness', {})
            pbr['baseColorTexture'] = {'index': g.add_texture(day, base + '_sign')}
            pbr['baseColorFactor'] = [1.0, 1.0, 1.0, 1.0]
        out = np.zeros_like(img)
        out[mask] = lamp_value(rgb)
        return out
    n = split_glow(g, pick, glow_of, base)
    print('  %s: %d triangles on the sign' % (base, n))
    save_night(g, base)


def brick_letters(tri):
    # The four white letters of SHOP on the brown board (z -2.44 to -2.36).
    return islands_in(tri, (0.2, 1.7, -2.46), (1.35, 2.1, -2.34), 4)


def candy_a_letters(tri):
    # The five letters of CANDY on the pink board over the front (z -1.60 to -1.38).
    return islands_in(tri, (-1.4, 2.7, -1.62), (1.25, 3.4, -1.36), 5)


def coffee_a_letters(tri):
    # The ten purple letters of COFFEE SHOP over the awning (y 4.82 to 5.54).
    return island_where(tri, lambda lo, hi, n: lo[1] >= 4.8 and hi[1] < 5.6 and hi[2] < -1.2)


def coffee_b_letters(tri):
    # The six tan letters of COFFEE, each on its own dark tile (y 5.15 to 5.7, z -1.94 to -1.74).
    return islands_in(tri, (-2.1, 5.1, -2.0), (3.4, 5.75, -1.7), 6)


def no_letters(tri):
    return np.zeros(len(tri.pos), bool)


def steel_board(tri):
    # The red board over the glass front, the only faces of the material Bord.
    names = [m.get('name') for m in tri.g.j['materials']]
    return tri.mat == names.index('Bord')


def steel_letters(img):
    return img.min(2) > 0.7  # white letters on the red board


def steel_recolour(img):
    # Dark grey board (the grey steel of the shop), the letters red.
    out = np.empty_like(img)
    out[:] = np.array([0.16, 0.17, 0.19])
    out[steel_letters(img)] = np.array([0.95, 0.15, 0.1])
    return out


def gabled_board(tri):
    # The hanging board on the left of the door (x -0.62 to -0.59).
    return island_where(tri, lambda lo, hi, n: lo[0] > -0.63 and hi[0] < -0.58 and lo[1] > 1.0 and hi[1] < 1.3)


def gabled_letters(img):
    # The yellow letters inside the brown board of the texture (its yellow frame left out).
    h, w = img.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w]
    inside = (xs > 0.016 * w) & (xs < 0.295 * w) & (ys > 0.852 * h) & (ys < 0.985 * h)
    return inside & (img[..., 0] > 0.7) & (img[..., 1] > 0.5) & (img[..., 2] < 0.4)


def night_shops():
    # The SHOP sign of the generic shop on the roof:
    # (shop, word, frame, board, middle x, roof height, front of the roof, sign width in metres)
    add_sign('shop-general-mini', SIGN_BLUE, srgb('2060b0'), srgb('f2f2ee'), 0.0, 1.76, -1.34, 2.0)
    add_sign('shop-flower-a', SIGN_GREEN, srgb('2f7d32'), srgb('f3e6c4'), 0.0, 2.40, -2.14, 2.6)
    add_sign('shop-general-orange-b', SHOP_ORANGE, srgb('c8451c'), srgb('f2f2ee'), -0.27, 3.31, -1.61, 2.35)
    add_sign('shop-general-orange-a', SIGN_BLUE_BRIGHT, srgb('2060b0'), srgb('f2f2ee'), 0.0, 3.3, -1.27, 2.6)
    add_sign('shop-building-multi', SHOP_PINK, srgb('6d7686'), srgb('f4dede'), 0.0, 6.37, -2.2, 3.3)
    add_sign('shop-townhouse-blue', SHOP_PURPLE, srgb('f2f2ee'), srgb('2b3f73'), -1.35, 8.3, -2.98, 3.3)
    # Their own sign lit.
    lit_letters(GENERIC, generic_letters, SIGN_RED, 'the word SHOP')
    lit_letters('shop-general-brick', brick_letters, SIGN_RED, 'the word SHOP')
    painted_sign('shop-steel-glass', steel_board, steel_letters, SIGN_RED, steel_recolour)
    painted_sign('shop-townhouse-gabled', gabled_board, gabled_letters, SHOP_YELLOW)
    # Another word turned into SHOP, or SHOP added on the front.
    swap_letters('shop-candy-a', SHOP_PINK, candy_a_letters, [(-0.05, 3.03, -1.57)], 0.6)
    swap_letters('shop-candy-b', SHOP_ORANGE, no_letters, [(0.2, 2.4, -1.73)], 0.75)
    swap_letters('shop-coffee-a', SIGN_RED, coffee_a_letters, [(-0.05, 5.18, -1.47)], 0.85)
    # Coffee-b: one letter per tile, on the four middle tiles (x 2.07, 1.09, 0.11, -0.86).
    swap_letters('shop-coffee-b', NIGHT_WHITE, coffee_b_letters, [(x, 5.42, -1.95) for x in (2.07, 1.09, 0.11, -0.86)],
                 0.45)


# --- Gas station m11 of free_mini: stripes of low orange light ---------------------------
GAS_ORANGE = (1.0, 0.45, 0.05)
## Share of its own colour the stripes glow with at night (a low light).
GAS_GLOW = 0.5


def box_tris(lo, hi):
    """The 12 triangles (pos, nrm: (12, 3, 3)) of the box between the corners `lo` and `hi`."""
    lo, hi = np.array(lo, dtype=np.float64), np.array(hi, dtype=np.float64)
    c = [np.array([x, y, z]) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]
    quads = [((0, 1, 3, 2), (-1, 0, 0)), ((4, 6, 7, 5), (1, 0, 0)), ((0, 4, 5, 1), (0, -1, 0)),
             ((2, 3, 7, 6), (0, 1, 0)), ((0, 2, 6, 4), (0, 0, -1)), ((1, 5, 7, 3), (0, 0, 1))]
    pos, nrm = [], []
    for q, n in quads:
        for tri in ((q[0], q[1], q[2]), (q[0], q[2], q[3])):
            pos.append([c[i] for i in tri])
            nrm.append([n] * 3)
    return np.array(pos), np.array(nrm, dtype=np.float64)


def gas_station():
    """gas_station_night.glb: m11 of free_mini.glb with two stripes of low orange light running
    round the building: one on the roof band, one over the foot of the walls."""
    g = GLB(os.path.join(CUR, 'free_mini.glb'))
    j = g.j
    keep = next(c for c in j['nodes'][g.root()]['children'] if j['nodes'][c]['name'] == 'm11')
    g.keep_only([keep])
    g.drop_unused_materials()
    j['nodes'][0]['name'] = 'm11_night'
    x0, x1, z0, z1, e = -0.63, 0.63, -0.88, -0.07, 0.008
    pos, nrm = [], []
    for y0, y1 in ((0.300, 0.318), (0.062, 0.078)):
        for lo, hi in (((x0 - e, y0, z0 - e), (x1 + e, y1, z0)),      # back
                       ((x0 - e, y0, z1), (x1 + e, y1, z1 + e)),      # front
                       ((x0 - e, y0, z0), (x0, y1, z1)),              # west
                       ((x1, y0, z0), (x1 + e, y1, z1))):             # east
            p, n = box_tris(lo, hi)
            pos.append(p)
            nrm.append(n)
    add_prim(g, 'gas_stripes', np.concatenate(pos), np.concatenate(nrm), np.array(GAS_ORANGE))
    tri = Triangles(g)
    start, count = tri.prims[-1][1:]
    base = np.zeros(len(tri.pos))
    base[start:start + count] = GAS_GLOW / OWN_NIGHT
    print('  gas station: %d stripe triangles' % count)
    uv2, img = night_map(tri, [], reach=1.0, strength=0.0, base=base, plain=True)
    write_night(g, tri, uv2, img, 'gas_station_night')
    g.save(os.path.join(CUR, 'gas_station_night.glb'))
    for file, models in (('gas_station_night', [{'cat': 'GAS_PACK', 'node': 'm11'}]),):
        with open(os.path.join(CUR, file + '.models.json'), 'w', newline='\n') as f:
            json.dump({'file': file + '.glb', 'models': models}, f, indent='\t')
            f.write('\n')


# --- Stadium: the inside floodlit, the facade dark --------------------------------------
## Share of their own colour the pitch, the stands and the outside (roof, walls) glow with.
STADIUM_PITCH = 1.0
STADIUM_STANDS = 0.9
STADIUM_OUTSIDE = 0.04
## The inner rim of the roof (share of the box from its centre): the bowl lies inside it.
STADIUM_RIM = 0.62


def stadium():
    """stadium_night.glb: no lamp of its own (the floodlights stand at the corners of the
    plot, BuildingExtras), but the bowl (the pitch and the stands) is floodlit, while the roof
    over the stands and the outer walls stay almost dark. A face is outside when its middle
    lies in the outer tenth of the box (a box metric: the stadium is a rounded rectangle), when
    it looks down, when it is the entrance block at ground level before the front, or when it
    looks up out of the inner rim of the roof (the roof itself)."""
    g = GLB(os.path.join(CUR, 'stadium.glb'))
    tri = Triangles(g)
    V = tri.pos.reshape(-1, 3)
    half = (V.max(0) - V.min(0)) / 2.0
    mid = (V.max(0) + V.min(0)) / 2.0
    c = tri.pos.mean(1) - mid
    n = tri.nrm.mean(1)
    n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-9
    edge = np.maximum(np.abs(c[:, 0]) / half[0], np.abs(c[:, 2]) / half[2])
    # How much a face looks out of the stadium (its normal along its direction from the centre):
    # the outer walls of the rounded corners lie inside the outer tenth of the box but look out.
    away = np.hypot(c[:, 0] / half[0], c[:, 2] / half[2]) + 1e-9
    outward = (n[:, 0] * c[:, 0] / half[0] + n[:, 2] * c[:, 2] / half[2]) / away
    outside = ((edge >= 0.9) | (n[:, 1] < -0.5) | ((edge >= 0.75) & (tri.pos[..., 1].max(1) < 0.2))
               | ((edge >= STADIUM_RIM) & (n[:, 1] > 0.5)) | ((edge >= 0.75) & (outward > 0.5)))
    bowl = ~outside
    pitch = bowl & (edge < 0.35) & (n[:, 1] > 0.5)
    base = np.where(pitch, STADIUM_PITCH, np.where(bowl, STADIUM_STANDS, STADIUM_OUTSIDE)) / OWN_NIGHT
    print('  stadium: %d outside, %d pitch, %d stand triangles' % ((~bowl).sum(), pitch.sum(), (bowl & ~pitch).sum()))
    uv2, img = night_map(tri, [], reach=1.0, strength=0.0, base=base, plain=True)
    write_night(g, tri, uv2, img, 'stadium_night')
    g.save(os.path.join(CUR, 'stadium_night.glb'))
    for file, models in (('stadium_night', [{'cat': 'STADIUM', 'node': 'stadium'}]), ('stadium', [])):
        with open(os.path.join(CUR, file + '.models.json'), 'w', newline='\n') as f:
            json.dump({'file': file + '.glb', 'models': models}, f, indent='\t')
            f.write('\n')


# --- Vehicles ------------------------------------------------------------------------
def red_blue(tri, unit):
    """The red and the blue lenses among the faces `unit`, by their colour."""
    col = to_srgb(tri.colours())
    r, gr, b = col[:, 0], col[:, 1], col[:, 2]
    red = unit & (r > 0.2) & (r > gr * 2.0) & (r > b * 2.0)
    blue = unit & (b > 0.2) & (b > r * 1.6) & (b > gr * 1.2)
    return red, blue


def left_right(tri, unit):
    """A light bar without separate lenses: its left half red, its right half blue."""
    x = tri.pos.mean(1)[:, 0]
    mid = (tri.pos[unit][..., 0].min() + tri.pos[unit][..., 0].max()) / 2.0
    return unit & (x < mid), unit & (x >= mid)


def vehicle(folder, name, pick, reach=0.55, strength=0.8, manifest=None):
    """`pick(tri)` -> (red faces, blue faces) of the lamps (bool per triangle)."""
    g = GLB(os.path.join(folder, name + '.glb'))
    tri = Triangles(g)
    red, blue = pick(tri)
    print('  %s: %d red and %d blue lamp triangles' % (name, red.sum(), blue.sum()))
    assert red.any() or blue.any()
    lamps = [(m, c) for m, c in ((red, LAMP_RED), (blue, LAMP_BLUE)) if m.any()]
    uv2, img = night_map(tri, lamps, reach=reach, strength=strength)
    write_night(g, tri, uv2, img, name + '_lamps')
    if manifest is None:
        g.j['nodes'][g.root()]['name'] = name + '_night'
    g.save(os.path.join(folder, name + '_night.glb'))
    if manifest is not None:
        # A curated pack: the night model takes the place of the model in the lists the game reads.
        node, cat = manifest
        for file, models in ((name + '_night', [{'cat': cat, 'node': node}]), (name, [])):
            with open(os.path.join(folder, file + '.models.json'), 'w', newline='\n') as f:
                json.dump({'file': file + '.glb', 'models': models}, f, indent='\t')
                f.write('\n')


def island_where(tri, test):
    """Faces of the islands whose box (lo, hi) passes `test`."""
    isl = tri.islands()
    out = np.zeros(len(isl), bool)
    for k in np.unique(isl):
        sel = isl == k
        V = tri.pos[sel].reshape(-1, 3)
        if test(V.min(0), V.max(0), int(sel.sum())):
            out |= sel
    return out


def cruiser_bar(tri):
    # The light bar is the island on the roof that spans the car's width.
    isl = tri.islands()
    def score(k):
        V = tri.pos[isl == k].reshape(-1, 3)
        return V[:, 1].min() if (V[:, 0].max() - V[:, 0].min()) > 1.0 else -1e9
    return red_blue(tri, isl == max(np.unique(isl), key=score))


def jp_beacon(tri):
    # The red beacon is its own part, "Cube", on the roof (the seventh mesh).
    return red_blue(tri, tri.mesh == 6)


def ambulance_bar(tri):
    # The light bar over the cab: the wide island above 2.1 m, in front of the box.
    return left_right(tri, island_where(tri, lambda lo, hi, n: lo[1] > 2.12 and hi[0] - lo[0] > 1.2 and n > 12))


def ccf_beacons(tri):
    # The two blue beacons on the roof of the cab: the blue faces of the top fifth.
    col = to_srgb(tri.colours())
    top = tri.pos[..., 1].max()
    high = tri.pos.mean(1)[:, 1] > top * 0.8
    blue = high & (col[:, 2] > 0.25) & (col[:, 2] > col[:, 0] * 1.4) & (col[:, 2] > col[:, 1] * 1.2)
    return np.zeros(len(col), bool), blue


if __name__ == '__main__':
    import sys
    if sys.argv[1:] == ['signs']:
        signs()
        sys.exit()
    if sys.argv[1:] == ['hospital']:
        hospital()
        sys.exit()
    if sys.argv[1:] == ['bank_school']:
        bank_school()
        sys.exit()
    if sys.argv[1:] == ['police']:
        police()
        sys.exit()
    if sys.argv[1:] == ['gas']:
        gas_station()
        sys.exit()
    if sys.argv[1:] == ['shops']:
        night_shops()
        sys.exit()
    if sys.argv[1:] == ['stadium']:
        stadium()
        sys.exit()
    pharmacy()
    signs()
    night_shops()
    stadium()
    vehicle(VEH, 'police_us_cruiser', cruiser_bar)
    vehicle(VEH, 'police_jp_black', jp_beacon)
    vehicle(VEH, 'p54_11_ambulance', ambulance_bar, reach=0.7)
    # The forest fire truck is a curated model, two cells long.
    vehicle(CUR, 'truck_ccf', ccf_beacons, reach=0.16, manifest=('truck_ccf', 'TRUCK_CCF'))
