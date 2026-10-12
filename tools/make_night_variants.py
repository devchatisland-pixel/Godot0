"""Night-lit duplicates of three models: same geometry, plus an emission map (glTF
emissiveTexture) that holds their night lights. No object is added.

  FREEMODELS/curated/pharmacy_night.glb      the pharmacy of public_main.glb alone; its big
                                             green cross glows green, the facade is softly lit
  vehicles/.../police_us_cruiser_night.glb   the red and the blue lens of the light bar glow
  vehicles/.../police_jp_black_night.glb     the red roof beacon glows

The game (NightWindows.light_own) keeps the map dark by day and multiplies it by
NightWindows.OWN_NIGHT (3.0) at night, so the map stores a third of the final light:
a lamp texel of 0.33 ends at 1.0 (full colour, no wash to white).

Usage:  python tools/make_night_variants.py
"""
import io, json, os, struct
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VEH = os.path.join(ROOT, 'vehicles', 'models', 'municipal_emergency')
CUR = os.path.join(ROOT, 'FREEMODELS', 'curated')
OWN_NIGHT = 3.0
## Night colours, as they should look at night (divided by OWN_NIGHT in the map).
CROSS_GREEN = (0.0, 1.0, 0.38)
CROSS_RIM = (0.62, 1.0, 0.78)
LAMP_RED = (1.0, 0.05, 0.04)
LAMP_BLUE = (0.08, 0.35, 1.0)
## Pharmacy facade at night, like the other public buildings (NightWindows.PACK_GLOW).
FACADE = 0.55

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
        raw = np.frombuffer(bytes(s.bin[off:off + stride * a['count']]), np.uint8).reshape(a['count'], stride)
        arr = np.frombuffer(raw[:, :dt.itemsize * n].tobytes(), dt)
        return arr.reshape(a['count'], n) if n > 1 else arr

    def image(s, i=0):
        return Image.open(io.BytesIO(s.view(s.j['images'][i]['bufferView']))).convert('RGB')

    def append(s, data):
        while len(s.bin) % 4:
            s.bin.append(0)
        s.j['bufferViews'].append({'buffer': 0, 'byteOffset': len(s.bin), 'byteLength': len(data)})
        s.bin += data
        return len(s.j['bufferViews']) - 1

    def set_uvs(s, prim, uv):
        """New TEXCOORD_0 accessor for `prim` (the old one may be shared)."""
        uv = uv.astype(np.float32)
        s.j['accessors'].append({'bufferView': s.append(uv.tobytes()), 'componentType': 5126,
                                 'count': len(uv), 'type': 'VEC2',
                                 'min': uv.min(0).tolist(), 'max': uv.max(0).tolist()})
        prim['attributes']['TEXCOORD_0'] = len(s.j['accessors']) - 1

    def add_texture(s, img, name):
        b = io.BytesIO()
        img.save(b, 'PNG', optimize=True)
        s.j['images'].append({'bufferView': s.append(b.getvalue()), 'mimeType': 'image/png', 'name': name})
        s.j['textures'].append({'sampler': s.j['textures'][0].get('sampler', 0), 'source': len(s.j['images']) - 1})
        return len(s.j['textures']) - 1

    def keep_only(s, root_children):
        """Drops every node outside `root_children` (and the unused data), repacking the buffer."""
        j = s.j
        keep_nodes = []
        def walk(i):
            keep_nodes.append(i)
            for c in j['nodes'][i].get('children', []):
                walk(c)
        root = j['scenes'][j.get('scene', 0)]['nodes'][0]
        keep_nodes.append(root)
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


def prims(g, mesh):
    for p in g.j['meshes'][mesh]['primitives']:
        P = g.acc(p['attributes']['POSITION']).astype(np.float64)
        U = g.acc(p['attributes']['TEXCOORD_0']).astype(np.float64)
        I = g.acc(p['indices']).reshape(-1, 3) if 'indices' in p else np.arange(len(P)).reshape(-1, 3)
        yield p, P, U, I


def islands(P, I):
    """Island id of every triangle (vertices at the same position are welded)."""
    _, weld = np.unique(np.round(P, 4), axis=0, return_inverse=True)
    weld = weld.reshape(-1)
    parent = np.arange(weld.max() + 1)
    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for t in I:
        a = find(weld[t[0]])
        for v in t[1:]:
            parent[find(weld[v])] = a
    return np.array([find(weld[t[0]]) for t in I])


def uv_mask(size, U, tris):
    m = Image.new('L', size, 0)
    d = ImageDraw.Draw(m)
    for t in tris:
        d.polygon([(U[i, 0] * size[0], U[i, 1] * size[1]) for i in t], fill=255, outline=255)
    return np.asarray(m) > 0


def to_srgb(lin):
    lin = np.clip(lin, 0.0, 1.0)
    return np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)


def to_linear(srgb):
    return np.where(srgb <= 0.04045, srgb / 12.92, np.power((srgb + 0.055) / 1.055, 2.4))


def to_map(rgb):
    """Night colour (linear) -> emission map value: the map is sRGB, and the game
    multiplies the decoded value by OWN_NIGHT."""
    return to_srgb(np.array(rgb, dtype=np.float64) / OWN_NIGHT)


def emissive(g, mats, tex):
    for m in mats:
        g.j['materials'][m]['emissiveTexture'] = {'index': tex}
        g.j['materials'][m]['emissiveFactor'] = [1.0, 1.0, 1.0]


# --- Pharmacy ------------------------------------------------------------------------
def pharmacy():
    g = GLB(os.path.join(CUR, 'public_main.glb'))
    j = g.j
    root = j['scenes'][j.get('scene', 0)]['nodes'][0]
    pharm = next(c for c in j['nodes'][root]['children'] if j['nodes'][c]['name'] == 'pharmacy')
    g.keep_only([pharm])
    j['nodes'][0]['name'] = 'pharmacy_night'
    albedo = g.image()
    a = np.asarray(albedo).astype(np.float64) / 255.0
    h, w = a.shape[:2]
    (p, P, U, I), = list(prims(g, 0))
    # The cross is the island in the upper corner (the highest one, 140 triangles).
    isl = islands(P, I)
    tops = {k: P[I[isl == k].reshape(-1), 1].max() for k in np.unique(isl)}
    cross = isl == max(tops, key=tops.get)
    verts = np.unique(I[cross].reshape(-1))
    assert not np.isin(verts, I[~cross].reshape(-1)).any(), 'cross shares vertices with the walls'
    # Each face of this flat-coloured kit points at one atlas texel; the cross shares them
    # with the trim, so its faces move to new texels (same colours) in a free corner.
    used = uv_mask((w, h), U, I)
    px = np.floor(np.clip(U[verts] % 1.0, 0, 0.9999) * [w, h]).astype(int)
    texels = sorted({tuple(t) for t in px})
    cell, slot = 16, 0  # the atlas grid, so the mipmaps keep the colours apart
    new_uv = U.copy()
    lights = {}
    for tx in texels:
        while True:  # next free cell of the empty white band of the atlas
            cx, cy = 16 + (slot % 12) * cell, 32 + (slot // 12) * cell
            slot += 1
            if not used[cy:cy + cell, cx:cx + cell].any():
                break
        colour = a[tx[1], tx[0]]
        a[cy:cy + cell, cx:cx + cell] = colour
        sel = (px == tx).all(1)
        new_uv[verts[sel]] = [(cx + cell / 2) / w, (cy + cell / 2) / h]
        green = colour[1] > colour[0] + 0.25
        lights[(cx, cy)] = CROSS_GREEN if green else CROSS_RIM
        print('  cross texel', tx, (colour * 255).astype(int), '->', (cx, cy), 'green' if green else 'rim')
    g.set_uvs(p, new_uv)
    em = to_srgb(to_linear(a) * FACADE / OWN_NIGHT)  # the facade, softly lit
    for (cx, cy), rgb in lights.items():
        em[cy:cy + cell, cx:cx + cell] = to_map(rgb)
    # The new albedo goes in place of the old one (same image index).
    old = j['images'][0]
    b = io.BytesIO()
    Image.fromarray((a * 255).round().astype(np.uint8)).save(b, 'PNG', optimize=True)
    old['bufferView'] = g.append(b.getvalue())
    emissive(g, [0], g.add_texture(Image.fromarray((em * 255).round().astype(np.uint8)), 'pharmacy_night'))
    g.save(os.path.join(CUR, 'pharmacy_night.glb'))
    with open(os.path.join(CUR, 'pharmacy_night.models.json'), 'w', newline='\n') as f:
        json.dump({'file': 'pharmacy_night.glb', 'models': [{'cat': 'PHARMACY', 'node': 'pharmacy'}]}, f, indent='\t')
        f.write('\n')


# --- Police cars ---------------------------------------------------------------------
def lamp_masks(a, threshold):
    r, g_, b = a[..., 0], a[..., 1], a[..., 2]
    red = (r > threshold) & (r > g_ * 2.0) & (r > b * 2.0)
    blue = (b > threshold) & (b > r * 1.6) & (b > g_ * 1.2)
    return red, blue


def police(name, pick):
    """`pick(mesh_index, P, I)` -> bool per triangle: the faces of the lamps."""
    g = GLB(os.path.join(VEH, name + '.glb'))
    albedo = g.image()
    a = np.asarray(albedo).astype(np.float64) / 255.0
    size = albedo.size
    lamps, others, mats = np.zeros(a.shape[:2], bool), np.zeros(a.shape[:2], bool), set()
    for mi in range(len(g.j['meshes'])):
        for p, P, U, I in prims(g, mi):
            sel = pick(mi, P, I)
            lamps |= uv_mask(size, U, I[sel])
            others |= uv_mask(size, U, I[~sel])
            if sel.any():
                mats.add(p['material'])
    red, blue = lamp_masks(a, 0.2)
    red &= lamps
    blue &= lamps
    assert not ((red | blue) & others).any(), 'lamp texels shared with the body'
    em = np.zeros_like(a)
    em[red] = to_map(LAMP_RED)
    em[blue] = to_map(LAMP_BLUE)
    print('  %s: %d red, %d blue lamp texels' % (name, red.sum(), blue.sum()))
    emissive(g, sorted(mats), g.add_texture(Image.fromarray((em * 255).round().astype(np.uint8)), name + '_lamps'))
    g.j['nodes'][g.j['scenes'][g.j.get('scene', 0)]['nodes'][0]]['name'] = name + '_night'
    g.save(os.path.join(VEH, name + '_night.glb'))


def light_bar(mi, P, I):
    # The light bar is the island on the roof that spans the car's width.
    isl = islands(P, I)
    def score(k):
        V = P[I[isl == k].reshape(-1)]
        return V[:, 1].min() if (V[:, 0].max() - V[:, 0].min()) > 1.0 else -1e9
    return isl == max(np.unique(isl), key=score)


def beacon(mi, P, I):
    # The red beacon is its own part, "Cube", on the roof.
    return np.full(len(I), mi == 6)


if __name__ == '__main__':
    pharmacy()
    police('police_us_cruiser', light_bar)
    police('police_jp_black', beacon)
