"""Night-lit duplicates of three models: the same model by day, plus a night map (glTF
emissiveTexture) that holds its lights. No object is added.

  FREEMODELS/curated/pharmacy_night.glb      the pharmacy of public_main.glb alone; its big
                                             green cross glows green, the facade is softly lit
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
  - for the pharmacy, its whole facade softly lit like the other public buildings.

The game (NightWindows.light_own) keeps the map dark by day and multiplies it by
NightWindows.OWN_NIGHT (3.0) at night, so the map stores a third of the final light. The
lamps alone are stored brighter (their main colour channel at 1.0): seen from near they stay
their pure colour (the other channels still end below 1.0), seen from far they keep showing
when the map is averaged with the dark faces around them.

Usage:  python tools/make_night_variants.py
Needs:  numpy, Pillow.
"""
import io, json, os, struct
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VEH = os.path.join(ROOT, 'vehicles', 'models', 'municipal_emergency')
CUR = os.path.join(ROOT, 'FREEMODELS', 'curated')
OWN_NIGHT = 3.0
## Night colours of the lamps, as they look at night (linear).
CROSS_GREEN = (0.0, 1.0, 0.3)
CROSS_RIM = (0.55, 1.0, 0.7)
LAMP_RED = (1.0, 0.08, 0.05)
LAMP_BLUE = (0.06, 0.3, 1.0)
## Pharmacy facade at night, like the other public buildings (NightWindows.PACK_GLOW).
FACADE = 0.55
## Size of the night maps (pixels).
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
        """Gives `prim` new vertices, three per triangle (no index is shared)."""
        prim['attributes'] = {'POSITION': s.add_accessor(pos, 'VEC3', True), 'NORMAL': s.add_accessor(nrm, 'VEC3'),
                              'TEXCOORD_0': s.add_accessor(uv, 'VEC2'), 'TEXCOORD_1': s.add_accessor(uv2, 'VEC2')}
        prim['indices'] = s.add_accessor(np.arange(len(pos)), 'SCALAR')

    def add_texture(s, img, name):
        b = io.BytesIO()
        img.save(b, 'PNG', optimize=True)
        s.j['images'].append({'bufferView': s.append(b.getvalue()), 'mimeType': 'image/png', 'name': name})
        s.j['textures'].append({'sampler': s.j['textures'][0].get('sampler', 0), 'source': len(s.j['images']) - 1})
        return len(s.j['textures']) - 1

    def root(s):
        return s.j['scenes'][s.j.get('scene', 0)]['nodes'][0]

    def keep_only(s, root_children):
        """Drops every node outside `root_children` (and the unused data), repacking the buffer."""
        j = s.j
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
                    U = g.acc(p['attributes']['TEXCOORD_0']).astype(np.float64)
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


def night_map(tri, lamps, reach, strength, base=0.0, size=MAP_SIZE):
    """Paints the night map of the triangles `tri` and returns (TEXCOORD_1 per corner (T, 3, 2),
    the map as an image).
    `lamps`: [(triangles of the lamp (bool per triangle), colour)]; `reach`: distance at which
    the light a lamp throws has fallen to a fifth; `strength`: that light right beside the lamp
    (1 = as bright as the lamp); `base`: share of its own colour every face glows with."""
    T = len(tri.pos)
    order = morton(tri.pos.mean(1))
    grid = int(np.ceil(np.sqrt(np.ceil(T / 2.0))))
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
    for mask, rgb in lamps:
        own[mask] = lamp_value(rgb)
        is_lamp |= mask
        p = tri.pos[mask]
        pts = np.concatenate([p.reshape(-1, 3), p.mean(1), (p[:, [0, 1, 2]] + p[:, [1, 2, 0]]).reshape(-1, 3) / 2.0])
        sources.append((np.unique(np.round(pts, 3), axis=0), np.array(rgb, dtype=np.float64)))
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
            value = np.zeros((int(sel.sum()), 3)) + base * colour[k]
            u, v = bary[half]
            w = np.stack([1.0 - u - v, u, v], 1)
            pos = w @ tri.pos[k]
            nrm = w @ tri.nrm[k]
            nrm /= np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-9
            for pts, rgb in sources:
                if np.linalg.norm(pts - centre[k], axis=1).min() > reach * 4.0 + radius[k]:
                    continue
                d = np.linalg.norm(pos[:, None, :] - pts[None, :, :], axis=2)
                near = d.argmin(1)
                dist = d[np.arange(len(pos)), near]
                to = (pts[near] - pos) / (dist[:, None] + 1e-9)
                facing = 0.35 + 0.65 * np.clip((nrm * to).sum(1), 0.0, 1.0)
                # A face touching the lamp is lit whatever way it looks.
                facing = np.where(dist < reach * 0.25, 1.0, facing)
                fall = strength / (1.0 + 4.0 * (dist / reach) ** 2)
                value = value + (fall * facing)[:, None] * rgb * (0.4 + 0.6 * colour[k]) / OWN_NIGHT
        block = img[cy:cy + cell, cx:cx + cell]
        block[sel] = value
    return uv2, Image.fromarray((to_srgb(img) * 255).round().astype(np.uint8))


def write_night(g, tri, uv2, img, name):
    """The triangles get their new coordinates, every material the night map."""
    for p, start, count in tri.prims:
        sl = slice(start, start + count)
        g.set_geometry(p, tri.local[sl].reshape(-1, 3), tri.local_nrm[sl].reshape(-1, 3), tri.uv[sl].reshape(-1, 2),
                       uv2[sl].reshape(-1, 2))
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
                         base=FACADE / OWN_NIGHT)
    write_night(g, tri, uv2, img, 'pharmacy_night')
    g.save(os.path.join(CUR, 'pharmacy_night.glb'))
    with open(os.path.join(CUR, 'pharmacy_night.models.json'), 'w', newline='\n') as f:
        json.dump({'file': 'pharmacy_night.glb', 'models': [{'cat': 'PHARMACY', 'node': 'pharmacy'}]}, f, indent='\t')
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


def fire_truck_lights(tri):
    # The bar across the front of the cab roof (left red, right blue) and the two red
    # beacons behind it.
    bar = island_where(tri, lambda lo, hi, n: lo[1] > 2.7 and hi[2] < -4.0 and hi[0] - lo[0] > 1.5)
    boxes = island_where(tri, lambda lo, hi, n: lo[1] > 2.7 and -4.0 < lo[2] and hi[2] < -3.3 and hi[0] - lo[0] < 0.5)
    red, blue = left_right(tri, bar)
    return red | boxes, blue


def ccf_beacons(tri):
    # The two blue beacons on the roof of the cab: the blue faces of the top fifth.
    col = to_srgb(tri.colours())
    top = tri.pos[..., 1].max()
    high = tri.pos.mean(1)[:, 1] > top * 0.8
    blue = high & (col[:, 2] > 0.25) & (col[:, 2] > col[:, 0] * 1.4) & (col[:, 2] > col[:, 1] * 1.2)
    return np.zeros(len(col), bool), blue


if __name__ == '__main__':
    pharmacy()
    vehicle(VEH, 'police_us_cruiser', cruiser_bar)
    vehicle(VEH, 'police_jp_black', jp_beacon)
    vehicle(VEH, 'p54_11_ambulance', ambulance_bar, reach=0.7)
    vehicle(VEH, 'p54_33_fire_truck', fire_truck_lights, reach=0.8)
    # The forest fire truck is a curated model, two cells long.
    vehicle(CUR, 'truck_ccf', ccf_beacons, reach=0.16, manifest=('truck_ccf', 'TRUCK_CCF'))
