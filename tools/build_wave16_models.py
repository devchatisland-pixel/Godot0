#!/usr/bin/env python3
"""Builds the models of the sixteenth to nineteenth waves from their raw files (FREEMODELS/_incoming).

Usage:  python tools/build_wave16_models.py [--src <folder of the raw .glb>] [--info] [name ...]
Needs:  numpy, Pillow.

Every model is baked to plain triangles in world space (node transforms and skins applied: the
two Humvee files are rigged, and collapse to a few centimetres when their skin is ignored),
turned, scaled, centred on x/z and put on y = 0, with small textures. Three kinds of output:

  curated packs  FREEMODELS/curated/<pack>.glb + <pack>.models.json   (front +Z, cells)
  vehicles       vehicles/models/<category>/<id>.glb + vehicles/catalog.json   (front -Z, metres)
  shops          shops/models/<id>.glb + shops/catalog.json   (front -Z, metres)

With names after the options only those outputs (pack name or catalog id) are rebuilt.
"""
import io, json, os, struct, sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


# --- Reading ------------------------------------------------------------------------------------
class Glb:
    def __init__(self, path):
        d = open(path, "rb").read()
        n = struct.unpack("<I", d[12:16])[0]
        self.j = json.loads(d[20:20 + n])
        o = 20 + n
        n2 = struct.unpack("<I", d[o:o + 4])[0]
        self.bin = d[o + 8:o + 8 + n2]
        self._images = {}

    def acc(self, i):
        a = self.j["accessors"][i]
        bv = self.j["bufferViews"][a["bufferView"]]
        n = NC[a["type"]]
        dt = np.dtype(CT[a["componentType"]])
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride") or n * dt.itemsize
        if stride == n * dt.itemsize:
            r = np.frombuffer(self.bin, dt, a["count"] * n, off).reshape(a["count"], n)
        else:
            raw = np.frombuffer(self.bin, np.uint8, (a["count"] - 1) * stride + n * dt.itemsize, off)
            idx = (np.arange(a["count"])[:, None] * stride + np.arange(n * dt.itemsize)[None, :]).ravel()
            r = raw[idx].view(dt).reshape(a["count"], n)
        r = r.astype(np.float64) if dt.kind == "f" else r.copy()
        if a.get("normalized") and dt.kind != "f":
            r = r.astype(np.float64) / float(np.iinfo(dt).max)
        return r

    def image(self, i):
        if i not in self._images:
            bv = self.j["bufferViews"][self.j["images"][i]["bufferView"]]
            o = bv.get("byteOffset", 0)
            self._images[i] = Image.open(io.BytesIO(self.bin[o:o + bv["byteLength"]])).convert("RGBA")
        return self._images[i]

    @staticmethod
    def local(n):
        if "matrix" in n:
            return np.array(n["matrix"], dtype=float).reshape(4, 4).T
        m = np.eye(4)
        if "scale" in n:
            m = np.diag(list(n["scale"]) + [1.0]) @ m
        if "rotation" in n:
            x, y, z, w = n["rotation"]
            r = np.eye(4)
            r[:3, :3] = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
            m = r @ m
        if "translation" in n:
            t = np.eye(4)
            t[:3, 3] = n["translation"]
            m = t @ m
        return m

    def worlds(self):
        """World matrix and path of names ("a/b/c") of every node."""
        out, paths = {}, {}

        def rec(i, parent, path):
            n = self.j["nodes"][i]
            out[i] = parent @ self.local(n)
            paths[i] = path + "/" + n.get("name", "")
            for c in n.get("children", []):
                rec(c, out[i], paths[i])
        for r in self.j["scenes"][self.j.get("scene", 0)]["nodes"]:
            rec(r, np.eye(4), "")
        return out, paths

    def material(self, mi, tex_max):
        """Plain description of material `mi`: colour, picture, emission, blending."""
        if mi is None:
            return {"name": "none", "color": [0.8, 0.8, 0.8, 1.0]}
        m = self.j["materials"][mi]
        pbr = m.get("pbrMetallicRoughness", {})
        sg = m.get("extensions", {}).get("KHR_materials_pbrSpecularGlossiness", {})
        out = {"name": m.get("name", "mat%d" % mi), "key": (id(self), mi),
               "color": list(pbr.get("baseColorFactor", sg.get("diffuseFactor", [1, 1, 1, 1]))),
               "blend": m.get("alphaMode", "OPAQUE") == "BLEND"}
        bt = pbr.get("baseColorTexture", sg.get("diffuseTexture"))
        if bt is not None:
            out["image"] = _small(self.image(self.j["textures"][bt["index"]]["source"]), tex_max)
        if m.get("emissiveFactor") and any(m["emissiveFactor"]):
            out["emissive"] = list(m["emissiveFactor"])
            if "emissiveTexture" in m:
                out["emissive_image"] = _small(
                        self.image(self.j["textures"][m["emissiveTexture"]["index"]]["source"]), tex_max)
        return out

    def parts(self, tex_max=512):
        """Every triangle list of the file in world space: {"path", "pos", "nrm", "uv", "idx", "mat"}."""
        worlds, paths = self.worlds()
        res = []
        for i, n in enumerate(self.j["nodes"]):
            if "mesh" not in n or i not in worlds:
                continue
            skin = None
            if "skin" in n:
                s = self.j["skins"][n["skin"]]
                ibm = self.acc(s["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
                skin = np.stack([worlds[j] @ ibm[k] for k, j in enumerate(s["joints"])])
            for pr in self.j["meshes"][n["mesh"]]["primitives"]:
                if pr.get("mode", 4) != 4:
                    continue
                at = pr["attributes"]
                p = self.acc(at["POSITION"]).astype(float)
                raw = p
                bind_t = None
                nr = self.acc(at["NORMAL"]).astype(float) if "NORMAL" in at else None
                if skin is not None and "JOINTS_0" in at:
                    jo = self.acc(at["JOINTS_0"]).astype(int)
                    we = self.acc(at["WEIGHTS_0"]).astype(float)
                    we /= np.maximum(we.sum(1, keepdims=True), 1e-9)
                    mats = np.einsum("vk,vkab->vab", we, skin[jo])
                    bind_t = ibm[jo[0, 0]][:3, 3]
                else:
                    mats = np.broadcast_to(worlds[i], (len(p), 4, 4))
                p = np.einsum("vab,vb->va", mats[:, :3, :3], p) + mats[:, :3, 3]
                if nr is not None:
                    nr = np.einsum("vab,vb->va", np.linalg.inv(mats[:, :3, :3]).transpose(0, 2, 1), nr)
                    nr /= np.linalg.norm(nr, axis=1, keepdims=True) + 1e-12
                uv = self.acc(at["TEXCOORD_0"]).astype(float) if "TEXCOORD_0" in at else np.zeros((len(p), 2))
                idx = self.acc(pr["indices"]).astype(np.int64).ravel() if "indices" in pr else np.arange(len(p))
                idx = idx[:len(idx) // 3 * 3].reshape(-1, 3)
                if np.linalg.det(worlds[i][:3, :3]) < 0 and skin is None:
                    idx = idx[:, ::-1]
                res.append({"path": paths[i], "pos": p, "nrm": nr, "uv": uv, "idx": idx, "raw": raw, "bind_t": bind_t,
                            "mat": self.material(pr.get("material"), tex_max)})
        return res


def _small(img, tex_max):
    if max(img.size) > tex_max:
        k = tex_max / float(max(img.size))
        img = img.resize((max(1, round(img.size[0] * k)), max(1, round(img.size[1] * k))), Image.LANCZOS)
    return img


# --- Shaping ------------------------------------------------------------------------------------
def box(parts):
    lo = np.min([p["pos"].min(0) for p in parts], 0)
    hi = np.max([p["pos"].max(0) for p in parts], 0)
    return lo, hi


def turn(parts, m):
    for p in parts:
        p["pos"] = p["pos"] @ m.T
        if p["nrm"] is not None:
            p["nrm"] = p["nrm"] @ m.T


def yaw(deg):
    a = np.radians(deg)
    return np.array([[np.cos(a), 0, np.sin(a)], [0, 1, 0], [-np.sin(a), 0, np.cos(a)]])


def shape(parts, spec):
    """Turns (spec "yaw", degrees round Y; "tilt": 3x3 matrix first), scales (spec "length": the
    longest side on the ground, "width": the x side, or "height"; "scale" as it is) and puts the
    model centred on x/z, standing on y = 0 ("origin": the point [x, z] of the turned raw model
    that goes to 0 instead of the middle). Returns the size (x, y, z)."""
    if "tilt" in spec:
        turn(parts, np.array(spec["tilt"], dtype=float))
    if spec.get("yaw"):
        turn(parts, yaw(spec["yaw"]))
    lo, hi = box(parts)
    size = hi - lo
    s = spec.get("scale", 1.0)
    if "length" in spec:
        s = spec["length"] / max(size[0], size[2])
    elif "width" in spec:
        s = spec["width"] / size[0]
    elif "height" in spec:
        s = spec["height"] / size[1]
    base = np.array([(lo[0] + hi[0]) * 0.5, lo[1], (lo[2] + hi[2]) * 0.5])
    if "origin" in spec:
        base = np.array([spec["origin"][0], lo[1], spec["origin"][1]])
    for p in parts:
        p["pos"] = (p["pos"] - base) * s
    return size * s


# --- Writing ------------------------------------------------------------------------------------
def write_glb(path, root, items):
    """`items`: [(node name, parts)]; the file holds one root node `root` with one child per item."""
    chunks, bvs, accs = [], [], []
    size = [0]

    def add(data, target=None):
        pad = (-size[0]) % 4
        if pad:
            chunks.append(b"\0" * pad)
            size[0] += pad
        bv = {"buffer": 0, "byteOffset": size[0], "byteLength": len(data)}
        if target:
            bv["target"] = target
        chunks.append(data)
        size[0] += len(data)
        bvs.append(bv)
        return len(bvs) - 1

    def acc(arr, ct, typ, target, minmax=False):
        a = {"bufferView": add(arr.tobytes(), target), "componentType": ct, "count": int(arr.shape[0]), "type": typ}
        if minmax:
            a["min"] = [float(x) for x in arr.min(0)]
            a["max"] = [float(x) for x in arr.max(0)]
        accs.append(a)
        return len(accs) - 1

    images, textures, materials, mat_ids, tex_ids = [], [], [], {}, {}

    def texture(img):
        key = id(img)
        if key not in tex_ids:
            buf = io.BytesIO()
            alpha = np.asarray(img)[:, :, 3].min() < 250
            if alpha:
                img.save(buf, "PNG", optimize=True)
            else:
                img.convert("RGB").save(buf, "JPEG", quality=88)
            images.append({"bufferView": add(buf.getvalue()), "mimeType": "image/png" if alpha else "image/jpeg"})
            textures.append({"sampler": 0, "source": len(images) - 1})
            tex_ids[key] = len(textures) - 1
        return {"index": tex_ids[key]}

    def material(m):
        key = m.get("key", id(m))
        if key not in mat_ids:
            pbr = {"baseColorFactor": [float(c) for c in m["color"]], "metallicFactor": 0.0, "roughnessFactor": 0.9}
            if m.get("image") is not None:
                pbr["baseColorTexture"] = texture(m["image"])
            out = {"name": m["name"], "doubleSided": True, "pbrMetallicRoughness": pbr}
            if m.get("blend"):
                out["alphaMode"] = "BLEND"
            if m.get("emissive"):
                out["emissiveFactor"] = [float(c) for c in m["emissive"]]
                if m.get("emissive_image") is not None:
                    out["emissiveTexture"] = texture(m["emissive_image"])
            materials.append(out)
            mat_ids[key] = len(materials) - 1
        return mat_ids[key]

    nodes = [{"name": root, "children": []}]
    meshes = []
    for name, parts in items:
        prims = []
        for p in parts:
            at = {"POSITION": acc(p["pos"].astype("<f4"), 5126, "VEC3", 34962, True),
                  "TEXCOORD_0": acc(p["uv"].astype("<f4"), 5126, "VEC2", 34962)}
            if p["nrm"] is not None:
                at["NORMAL"] = acc(p["nrm"].astype("<f4"), 5126, "VEC3", 34962)
            prims.append({"attributes": at, "indices": acc(p["idx"].astype("<u4").ravel(), 5125, "SCALAR", 34963),
                          "material": material(p["mat"])})
        meshes.append({"name": name, "primitives": prims})
        nodes.append({"name": name, "mesh": len(meshes) - 1})
        nodes[0]["children"].append(len(nodes) - 1)
    doc = {"asset": {"version": "2.0", "generator": "tools/build_wave16_models.py"},
           "extensionsUsed": ["GODOT_single_root"], "scene": 0, "scenes": [{"nodes": [0]}],
           "nodes": nodes, "meshes": meshes, "materials": materials, "accessors": accs, "bufferViews": bvs,
           "buffers": [{"byteLength": 0}]}
    if textures:
        doc["textures"] = textures
        doc["images"] = images
        doc["samplers"] = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}]
    blob = b"".join(chunks)
    blob += b"\0" * ((-len(blob)) % 4)
    doc["buffers"][0]["byteLength"] = len(blob)
    js = json.dumps(doc, separators=(",", ":")).encode()
    js += b" " * ((-len(js)) % 4)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(blob)))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(blob), b"BIN\0") + blob)


## The two Humvee files are broken: the wheels, seats and glass are stored in centimetres in the
## space of the scene, but the hull, the doors, the turret and the interior are stored in metres
## in another space (turned a quarter round Z), so they collapse to a few centimetres beside the
## rest. Found by fitting the doors on their glass and the hull on the wheels: these parts go
## back in place with one turn and one offset (the bind offset of a door, in metres); the hull
## alone uses its own bind offset.
HUMVEE_TURN = np.array([[0.0, 1.0, 0.0], [-1.0, 0.0, 0.0], [0.0, 0.0, 1.0]])


def repair_humvee(parts):
    door = [p for p in parts if p["mat"]["name"].startswith("Door_Rear_Right") and np.abs(p["raw"]).max() < 30]
    if not door:
        return
    offset = door[0]["bind_t"] / 100.0
    for p in parts:
        if p["bind_t"] is None or np.abs(p["raw"]).max() >= 30:
            continue
        o = p["bind_t"] / 100.0 if p["mat"]["name"] == "Chassis" else offset
        p["pos"] = p["raw"] @ HUMVEE_TURN.T + o
        if p["nrm"] is not None:
            n = p["nrm"]
            p["nrm"] = n / (np.linalg.norm(n, axis=1, keepdims=True) + 1e-12)


def merged(parts):
    """One part per material (Godot draws at most 256 surfaces per mesh; the townhouse has 297)."""
    groups = {}
    for p in parts:
        groups.setdefault(p["mat"].get("key", id(p["mat"])), []).append(p)
    out = []
    for group in groups.values():
        offset, idx = 0, []
        for p in group:
            idx.append(p["idx"] + offset)
            offset += len(p["pos"])
        flat = [p["nrm"] if p["nrm"] is not None else np.tile([0.0, 1.0, 0.0], (len(p["pos"]), 1)) for p in group]
        out.append({"path": group[0]["path"], "pos": np.concatenate([p["pos"] for p in group]),
                    "nrm": np.concatenate(flat), "uv": np.concatenate([p["uv"] for p in group]),
                    "idx": np.concatenate(idx), "mat": group[0]["mat"]})
    return out


def triangles(parts):
    return int(sum(len(p["idx"]) for p in parts))


def pick(parts, spec):
    """The parts a spec keeps: "nodes" (names found in the node path), "prefix" (node names that
    start with one of these), "skip" (names left out), "skip_materials" (material name prefixes
    left out); "neon" makes every part a neon tube, "neon_materials" the parts of these materials."""
    out = []
    for p in parts:
        names = p["path"].split("/")
        if "nodes" in spec and not any(n in names for n in spec["nodes"]):
            continue
        if "prefix" in spec and not any(n.startswith(f) for n in names for f in spec["prefix"]):
            continue
        if any(n in names for n in spec.get("skip", [])):
            continue
        if any(p["mat"]["name"].startswith(m) for m in spec.get("skip_materials", [])):
            continue
        q = dict(p)
        q["pos"] = p["pos"].copy()
        q["nrm"] = None if p["nrm"] is None else p["nrm"].copy()
        if "region" in spec:
            # Only the triangles whose middle is inside the box (x0, y0, x1, y1) of the raw file,
            # and outside the boxes of "but".
            c = q["pos"][q["idx"]].mean(1)
            # "region": one box or several.
            boxes = spec["region"] if isinstance(spec["region"][0], list) else [spec["region"]]
            keep = np.zeros(len(c), bool)
            for one in boxes:
                keep |= _inside(c, one)
            for other in spec.get("but", []):
                keep &= ~_inside(c, other)
            if not keep.any():
                continue
            used, idx = np.unique(q["idx"][keep], return_inverse=True)
            q["idx"] = idx.reshape(-1, 3)
            q["pos"] = q["pos"][used]
            q["nrm"] = None if q["nrm"] is None else q["nrm"][used]
            q["uv"] = q["uv"][used]
        if spec.get("neon") or any(p["mat"]["name"] == m for m in spec.get("neon_materials", [])):
            # A neon tube: its own colour is the colour of its light, and it is not see-through.
            m = dict(q["mat"])
            if m.get("emissive") and m.get("image") is None:
                m["color"] = list(m["emissive"]) + [1.0]
            m["color"] = list(m["color"][:3]) + [1.0]
            m["blend"] = False
            m["key"] = ("neon",) + tuple(m.get("key", (id(p["mat"]),)))
            q["mat"] = m
        out.append(q)
    return out


def _inside(c, box):
    return (c[:, 0] >= box[0]) & (c[:, 1] >= box[1]) & (c[:, 0] <= box[2]) & (c[:, 1] <= box[3])


def welded(parts, cell):
    """Fewer triangles: the corners are snapped to a grid of `cell` and the triangles that
    collapse are dropped (neon tubes modelled with a hundred thousand triangles)."""
    out = []
    for p in parts:
        key = np.round(p["pos"] / cell).astype(np.int64)
        _, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
        idx = inv.reshape(-1)[p["idx"]]
        ok = (idx[:, 0] != idx[:, 1]) & (idx[:, 1] != idx[:, 2]) & (idx[:, 0] != idx[:, 2])
        idx = idx[ok]
        q = dict(p)
        q["pos"] = p["pos"][first]
        q["nrm"] = None if p["nrm"] is None else p["nrm"][first]
        q["uv"] = p["uv"][first]
        q["idx"] = idx
        out.append(q)
    return out


def preview(parts, path, cell=360):
    """Three flat views of a built model, to check which way it stands: seen from its front
    (+Z, x to the right), from its right side (+X) and from above (front at the bottom)."""
    from PIL import ImageDraw
    lo, hi = box(parts)
    span = float(max(hi - lo)) or 1.0
    mid = (lo + hi) * 0.5
    views = [(np.array([1.0, 0, 0]), np.array([0, 1.0, 0]), np.array([0, 0, 1.0])),
             (np.array([0, 0, -1.0]), np.array([0, 1.0, 0]), np.array([1.0, 0, 0])),
             (np.array([1.0, 0, 0]), np.array([0, 0, -1.0]), np.array([0, 1.0, 0]))]
    img = Image.new("RGB", (cell * 3, cell), (58, 64, 74))
    draw = ImageDraw.Draw(img)
    for v, (right, up, toward) in enumerate(views):
        tris = []
        for p in parts:
            m = p["mat"]
            col = np.array(m["color"][:3], dtype=float)
            pic = m.get("emissive_image") or m.get("image")
            tex = np.asarray(pic.convert("RGB"), dtype=float) / 255.0 if pic is not None else None
            if m.get("emissive") and tex is None:
                col = np.array(m["emissive"], dtype=float)
            t = p["pos"][p["idx"]]
            n = np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0])
            n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-12
            shade = 0.55 + 0.45 * np.abs(n @ toward)
            c = t.mean(1)
            uv = p["uv"][p["idx"]].mean(1)
            for k in range(len(t)):
                rgb = col
                if tex is not None:
                    rgb = col * tex[int(uv[k, 1] % 1.0 * (tex.shape[0] - 1)), int(uv[k, 0] % 1.0 * (tex.shape[1] - 1))]
                tris.append((c[k] @ toward, t[k], rgb * shade[k]))
        tris.sort(key=lambda e: e[0])
        for _, t, rgb in tris:
            pts = [(v * cell + cell * 0.5 + float((q - mid) @ right) / span * cell * 0.9,
                    cell * 0.5 - float((q - mid) @ up) / span * cell * 0.9) for q in t]
            draw.polygon(pts, fill=tuple(int(min(1.0, max(0.0, x)) * 255) for x in rgb))
        draw.text((v * cell + 6, 4), ["front (+Z)", "right side (+X)", "top (front down)"][v], fill=(255, 255, 255))
    img.save(path)


# --- What is built ---------------------------------------------------------------------------------
## A sign lying on its back, its top towards -Z: stood up, its face towards +Z.
STAND_UP = [[1, 0, 0], [0, 0, -1], [0, 1, 0]]
## The same for a sign whose top is towards +Z (its face then looks back: turn it with "yaw").
STAND_UP_Z = [[1, 0, 0], [0, 0, 1], [0, -1, 0]]
## The heart of the "neon" pack: its upper part, and its tip between the legs of the girl.
HEART = [[0.85, 2.25, 9, 9], [0.9, 2.02, 1.5, 2.25]]
STREET_PACK = "lowpoly_city_street_pack_buildings_stylized.glb"
INDUSTRIAL_SET = "industrial_buildings_set_-_low_poly_models.glb"
STORAGE_TANKS = "large_industrial_storage_tanks.glb"

## Curated packs: {"src", "tex", "items": [{"id", "cat", size keys of shape(), pick keys}]}.
## The signs are 3 cells wide; BuildingExtras sizes them on the wall they hang on.
PACKS = {
    "sign_windows": {"src": "windows_logo_2001-2012_in_3d.glb", "items": [
        {"id": "logo_windows", "cat": "SIGN_WINDOWS", "width": 3.0}]},
    "neon_joystick": {"src": "neon_joysticks.glb", "tex": 512, "items": [
        {"id": "joystick_white", "cat": "NEON_JOYSTICK", "nodes": ["FG Console Led"],
         "skip_materials": ["ConsoleLedGlass"], "width": 3.0}]},
    "neon_martini": {"src": "woman_in_martini_neon_sign.glb", "items": [
        {"id": "martini_woman", "cat": "NEON_MARTINI", "tilt": STAND_UP, "width": 3.0}]},
    "neon_bar": {"src": "bar_sign_board.glb", "items": [
        {"id": "bar_board", "cat": "NEON_BAR", "yaw": 180, "width": 3.0}]},
    # Seventeenth wave: more signs (the three of "neon" are cut out of one mesh), the bank.
    "neon_bull": {"src": "bull_neon_sign.glb", "items": [
        {"id": "bull", "cat": "NEON_BULL", "neon": True, "width": 3.0, "weld": 0.012}]},
    "neon_fun": {"src": "neon_fun.glb", "items": [
        {"id": "fun_arrow", "cat": "NEON_FUN", "neon": True, "skip_materials": ["Glass"], "width": 3.0}]},
    "neon_palm": {"src": "neon_palm_tree_sign.glb", "tex": 256, "items": [
        {"id": "palm_tree", "cat": "NEON_PALM", "neon": True, "skip": ["Object_2"], "tilt": STAND_UP_Z, "yaw": 180, "height": 3.0}]},
    "neon_vegas": {"src": "neon_pack3.glb", "tex": 512, "items": [
        {"id": "vegas_club", "cat": "NEON_CLUB", "neon": True, "region": [-9, -9, 9, 1.4], "width": 3.0, "weld": 0.012},
        {"id": "vegas_girl", "cat": "NEON_GIRL", "neon": True, "region": [-1.04, 1.4, 9, 9],
         "but": HEART, "width": 3.0, "weld": 0.012},
        {"id": "vegas_love", "cat": "NEON_LOVE", "neon": True, "region": HEART, "width": 2.4, "weld": 0.012}]},
    # Nineteenth wave: Taiwan style signboards for the towers of the urban island. The pack shares
    # one texture; the blade signs hang from brackets at their -X end, the LED band (board29, with
    # its colour stripes board28 above it) wraps the +X/+Z corner of a building.
    "taiwan_signs": {"src": "taiwan_style_signboard_lowpoly.glb", "tex": 1024, "items": [
        {"id": "tw_banasonic", "cat": "TW_BANASONIC", "nodes": ["board30"], "width": 3.0},
        {"id": "tw_mcdonalds", "cat": "TW_MCDONALDS", "nodes": ["board06"], "width": 3.0},
        {"id": "tw_cola_jp", "cat": "TW_COLA_JP", "nodes": ["board05"], "width": 3.0},
        {"id": "tw_cola_billboard", "cat": "TW_COLA_BILLBOARD", "nodes": ["board08"], "width": 3.0},
        {"id": "tw_led_board", "cat": "TW_LED_BOARD", "nodes": ["board07"], "width": 3.0},
        {"id": "tw_led_band", "cat": "TW_LED_BAND", "nodes": ["board29", "board28"], "width": 3.0}]},
    "bank_min": {"src": "bank_minimalist_model.glb", "items": [
        {"id": "bank_minimalist", "cat": "BANK_MIN", "length": 2.8}]},
    "hotel_low": {"src": "low_poly_hotel_1.glb", "tex": 512, "items": [
        {"id": "hotel_orange", "cat": "HOTEL_LOW", "skip": ["Collider"], "yaw": -90, "length": 2.8}]},
    # The court with its two hoops, as they stand in the pack (5.5 cells long).
    "court": {"src": STREET_PACK, "tex": 256, "items": [
        {"id": "basketball_court", "cat": "COURT", "nodes": ["Cube.209", "Cube.223", "terrain textures 1.004"],
         "length": 5.5}]},
    # Eighteenth wave: one model of each for the hotels and the industrial port (PortRework).
    "hotels": {"tex": 512, "items": [
        {"id": "hotel_small", "src": "low_poly_hotel.glb", "cat": "HOTEL_LOW", "yaw": -90, "length": 2.4},
        {"id": "hotel_stars", "src": "low_poly_hotel_2.glb", "cat": "HOTEL_LOW", "skip": ["Collider"],
         "yaw": -90, "length": 2.8},
        {"id": "hotel_tower", "src": "hotel_ostriv.glb", "cat": "HOTEL_LOW", "length": 2.8}]},
    # The industrial buildings set, about 10 m to the cell: big halls, small sheds, towers and tanks.
    "port_halls": {"src": INDUSTRIAL_SET, "tex": 512, "items": [
        {"id": "hall_building_1", "cat": "IND_HALL", "nodes": ["Industrial_Building_1"], "length": 4.7},
        {"id": "hall_building_10", "cat": "IND_HALL", "nodes": ["Industrial_Building_10"], "length": 6.5},
        {"id": "hall_factory_1", "cat": "IND_HALL", "nodes": ["Industrial_FactoryPlant_1"], "length": 7.0},
        {"id": "hall_factory_2", "cat": "IND_HALL", "nodes": ["Industrial_FactoryPlant_2"], "length": 7.0},
        {"id": "hall_hangar", "cat": "IND_HALL", "nodes": ["Industrial_Hangar_2"], "length": 5.0},
        {"id": "hall_warehouse_5", "cat": "IND_HALL", "nodes": ["Industrial_Warehouse_5"], "length": 5.0},
        {"id": "hall_powerplant", "cat": "IND_HALL", "nodes": ["Industrial_Powerplant_1"], "length": 7.0},
        {"id": "hall_terminal", "cat": "IND_HALL", "nodes": ["Industrial_LogisticTerminal_1"], "length": 5.0},
        {"id": "hall_warehouse_4", "cat": "IND_HALL", "nodes": ["Industrial_Warehouse_4"], "length": 4.0},
        {"id": "hall_warehouse_1", "cat": "IND_HALL", "nodes": ["Industrial_Warehouse_1"], "length": 3.4}]},
    "port_sheds": {"src": INDUSTRIAL_SET, "tex": 512, "items": [
        {"id": "shed_warehouse_3", "cat": "IND_SHED", "nodes": ["Industrial_Warehouse_3"], "length": 3.0},
        {"id": "shed_generic_4", "cat": "IND_SHED", "nodes": ["Industrial_GenericBuilding_4"], "length": 3.5},
        {"id": "shed_works_1", "cat": "IND_SHED", "nodes": ["Industrial_Smth_1"], "length": 2.2},
        {"id": "shed_works_2", "cat": "IND_SHED", "nodes": ["Industrial_Smth_2"], "length": 2.9},
        {"id": "shed_loadbay", "cat": "IND_SHED", "nodes": ["Industrial_Railroad_Loadbay_Shed_1"], "length": 2.8},
        {"id": "shed_duplex", "cat": "IND_SHED", "nodes": ["Industrial_Duplex_1"], "length": 2.1},
        {"id": "shed_small_4", "cat": "IND_SHED", "nodes": ["Industrial_WarehouseSmall_4"], "length": 1.4},
        {"id": "shed_generic_3", "cat": "IND_SHED", "nodes": ["Industrial_GenericBuilding_3"], "length": 1.3},
        {"id": "shed_trailer", "cat": "IND_SHED", "nodes": ["Industrial_OfficeTrailer_1"], "length": 1.2},
        {"id": "shed_station", "cat": "IND_SHED", "nodes": ["Industrial_TsrStation_1"], "length": 1.2}]},
    "port_towers": {"src": INDUSTRIAL_SET, "tex": 512, "items": [
        {"id": "tower_crane", "cat": "IND_TOWER", "nodes": ["Industrial_PortalCrane_2"], "length": 2.5},
        {"id": "tower_radio", "cat": "IND_TOWER", "nodes": ["Industrial_Radiotower_1"], "height": 2.6},
        {"id": "tower_water", "cat": "IND_TOWER", "nodes": ["Industrial_Watertower_1"], "height": 2.6},
        {"id": "tower_tank_1", "cat": "IND_TOWER", "nodes": ["Industrial_Tank_1"], "length": 2.0},
        {"id": "tower_tank_2", "cat": "IND_TOWER", "nodes": ["Industrial_Tank_2"], "length": 2.2},
        {"id": "tower_tank_4", "cat": "IND_TOWER", "nodes": ["Industrial_Tank_4"], "height": 2.0},
        {"id": "tower_tank_5", "cat": "IND_TOWER", "nodes": ["Industrial_Tank_5"], "height": 2.0},
        {"id": "tower_silo", "cat": "IND_TOWER", "nodes": ["Industrial_SiloTank_1"], "height": 1.0},
        {"id": "tower_tank_3", "cat": "IND_TOWER", "nodes": ["Industrial_Tank_3_Walls"], "length": 1.0},
        {"id": "tower_hut", "cat": "IND_TOWER", "nodes": ["Industrial_GenericBuilding_2"], "length": 0.8}]},
    # The other oil and storage tanks, the brick factory and the offshore rig.
    "port_tanks": {"tex": 512, "items": [
        {"id": "tank_big", "src": STORAGE_TANKS, "cat": "PORT_TANK", "nodes": ["pCylinder2"], "length": 2.2},
        {"id": "tank_spheres", "src": STORAGE_TANKS, "cat": "PORT_TANK", "length": 2.6,
         "prefix": ["Pipe", "Valve_RoundA", "Stair", "Support", "Round", "polySurface49"]},
        {"id": "tank_long", "src": STORAGE_TANKS, "cat": "PORT_TANK", "prefix": ["Long_Tank"], "length": 1.6},
        {"id": "tank_oil", "src": "oil_tank.glb", "cat": "PORT_TANK", "length": 1.6},
        {"id": "tank_rusty", "src": "free_oil_tank.glb", "cat": "PORT_TANK", "length": 2.2},
        {"id": "tank_old", "src": "old_oil_tank_.1.glb", "cat": "PORT_TANK", "length": 2.4},
        {"id": "factory_brick", "src": "industrial_building.glb", "cat": "PORT_TANK", "length": 3.5}]},
    "oil_rig": {"src": "oil_rig_-_low_poly.glb", "tex": 256, "items": [
        {"id": "oil_rig", "cat": "OIL_RIG", "length": 6.0}]},
    # Nineteenth wave. The checkpoint at the island end of the Golden Gate: the whole military
    # post of the pack (walls, two gates with their barriers, two guard posts, two watchtowers,
    # the vehicle shelter, the garage, the road lights) without its ground, its tank and its
    # transformer. The road runs along x through both gates; "origin" puts the middle of the
    # road between the gates at 0. 0.3 cells to the metre (vehicles: 0.17), so that the
    # gates are about as wide as the road.
    "checkpoint": {"src": "game_ready_military_base_asset_pack.glb", "tex": 512, "items": [
        {"id": "checkpoint_post", "cat": "CHECKPOINT", "skip": ["Ground", "Tank", "Transformer", "Parking"],
         "origin": [-5.05, 0.0], "scale": 0.3, "weld": 0.012}]},
    # Twenty-first wave. The city hall of Utrecht that serves as the museum. It faces +Z.
    "museum_hall": {"src": "utrecht_stadhuiscity_hall.glb", "tex": 512, "items": [
        {"id": "museum_hall", "cat": "MUSEUM_HALL", "length": 4.0}]},
    # Twenty-second wave. The towns of the fog island (FogBaseSites): two office buildings, a
    # night tower, a house and one storey of a block (stacked to make blocks of 2 to 6 floors).
    "fog_city": {"tex": 512, "items": [
        {"id": "fog_office", "src": "office.glb", "cat": "FOG_OFFICE", "length": 3.0},
        {"id": "fog_house", "src": "hq_residential_house_lq_lowpoly_edition.glb", "cat": "FOG_HOUSE", "length": 2.0},
        {"id": "fog_night_tower", "src": "modern_night_building_game-ready.glb", "cat": "FOG_NIGHT_TOWER", "length": 3.0},
        {"id": "fog_office_tower", "src": "modern_office_building.glb", "cat": "FOG_OFFICE_TOWER", "length": 3.5},
        {"id": "fog_floor", "src": "modular_building_piece.glb", "cat": "FOG_FLOOR", "length": 3.0},
        # The modular city of shops/models (made by hand): three houses and three towers.
        {"id": "mod_house_small", "src": "modular-city.glb", "nodes": ["modular-house-small"], "cat": "FOG_MOD_HOUSE", "length": 2.4},
        {"id": "mod_house_medium", "src": "modular-city.glb", "nodes": ["modular-house-medium"], "cat": "FOG_MOD_HOUSE", "length": 2.6},
        {"id": "mod_house_big", "src": "modular-city.glb", "nodes": ["modular-house-big"], "cat": "FOG_MOD_HOUSE", "length": 3.4},
        {"id": "mod_tower_small", "src": "modular-city.glb", "nodes": ["modular-tower-small"], "cat": "FOG_MOD_TOWER", "length": 3.4},
        {"id": "mod_tower_medium", "src": "modular-city.glb", "nodes": ["modular-tower-medium"], "cat": "FOG_MOD_TOWER", "length": 3.6},
        {"id": "mod_tower_big", "src": "modular-city.glb", "nodes": ["modular-tower-big"], "cat": "FOG_MOD_TOWER", "length": 4.0}]},
    # Twenty-third wave. The Las Vegas club B-00023 becomes a supermarket (the "Supermarket
    # building" of Randonavt, its sign and posters taken off by tools/clean_supermarket.py: no
    # text left), its door turned from +X to +Z; the XXX and Playboy neon signs hang on its wall.
    # Twenty-fourth wave: the Las Vegas building of sarthakv049 ("Building", CC-BY), its words
    # OCEAN VIEW rebuilt as CA$INO by tools/make_casino_sign.py. The building without the word
    # (its wavy neon tubes stay), and the word alone, sized on the wall by BuildingExtras.
    "vegas_casino": {"src": "building_vegas_casino.glb", "tex": 512, "items": [
        {"id": "casino_building", "cat": "VEGAS_CASINO", "skip": ["LOGO_0"], "neon_materials": ["Material.019"],
         "yaw": -90, "width": 3.0, "weld": 0.004},
        {"id": "casino_sign", "cat": "NEON_CASINO", "nodes": ["LOGO_0"], "neon": True, "yaw": -90, "width": 3.0}]},
    "supermarket": {"src": "supermarket_clean.glb", "tex": 1024, "items": [
        {"id": "supermarket", "cat": "SUPERMARKET", "yaw": -90, "length": 5.0}]},
    "neon_xxx": {"src": "xxx_neon_sign.glb", "tex": 512, "items": [
        {"id": "xxx_board", "cat": "NEON_XXX", "neon": True, "skip_materials": ["M_Glass_DirtyMaster"],
         "width": 3.0, "weld": 0.012}]},
    "neon_playboy": {"src": "neon_playboy_logo.glb", "tex": 256, "items": [
        {"id": "playboy_bunny", "cat": "NEON_PLAYBOY", "neon": True, "height": 3.0, "weld": 0.03}]},
    # The seven houses of the fog island (tools/build_modular_buildings.py --homes): stacked from
    # the City Game modular pack like the town houses of fog_city, each unlike the others. Their
    # fronts look -Z, as in fog_city (FogBase turns both categories round).
    "fog_homes": {"src": "modular-homes.glb", "tex": 512, "items": [
        {"id": h, "nodes": [h], "cat": "FOG_MOD_HOME", "length": 3.0} for h in
        ["home-bungalow", "home-villa", "home-glass", "home-terrace", "home-tall", "home-stepped", "home-block"]]},
    # The "Danger" plate of the fence pack (the other signs and the fences are not used), stood
    # with its face to +Z. FogBase hangs it on the fence of the secret base.
    "danger_sign": {"src": "simple_chainlink_fence.glb", "tex": 512, "items": [
        {"id": "danger", "cat": "DANGER_SIGN", "nodes": ["Danger"], "yaw": -90, "width": 1.0}]},
}

## The lighthouse of the little island, a night club: the "Light House Club" sign of the club
## sign pack hangs on the east wall of the house (the model faces +Z: south on the map), like a
## blade sign: its poles against the wall, its face to the south. Two models in the same frame:
## the building with the metal of the sign, and the parts that glow (NightWindows lights them
## as a neon sign); BuildingExtras draws the second with the transform of the first.
LIGHTHOUSE = {"src": "light_house.glb", "sign": "night_club_sign.glb", "tex": 256,
              "length": 4.5,
              # Height of the sign and of its bottom above the ground, in cells (the walls of
              # the house are 0.6 cells high, the ridge 0.9, the tower 3).
              "sign_height": 1.3, "sign_lift": 0.15,
              # Where along the east wall (0 back, 1 front of the house at that end).
              "sign_along": 0.62,
              "glow": ["sign-legs", "words-glass", "words-L", "words-I", "words-G", "words-H-01",
                       "words-T", "words-H-02", "words-O", "words-U", "words-S", "words-E", "words-club"]}

HUMVEE = {"yaw": 90, "length": 4.9, "tex": 256, "skip_materials": ["Muzzleflash"],
          "file": "vehicles/models/military/%s.glb"}
## Vehicles (vehicles/catalog.json): front -Z, metres.
VEHICLES = {
    "school_bus": {"src": "school__bus_-_low_poly_model.glb", "length": 11.0, "tex": 512,
                   "file": "vehicles/models/buses_coaches/%s.glb",
                   "entry": {"name": "School bus (Yellow)", "category": "Buses & Coaches", "model": "School bus",
                             "sub_model": "Yellow", "pack": "schoolbus", "source": "single mesh"}},
    "jeep_willys": {"src": "jeep.glb", "yaw": 90, "length": 3.4, "tex": 512,
                    "file": "vehicles/models/military/%s.glb",
                    "entry": {"name": "Jeep (Willys, olive)", "category": "Military", "model": "Jeep",
                              "sub_model": "Willys, olive", "pack": "jeep", "source": "single mesh"}},
    "humvee_grey": dict(HUMVEE, src="armored_vehicle-test.glb",
                        entry={"name": "Armoured vehicle (Humvee, grey)", "category": "Military", "model": "Humvee",
                               "sub_model": "Grey", "pack": "humvee_test", "source": "repaired rig"}),
    "humvee_sand": dict(HUMVEE, src="armored_vehicleanimation.glb",
                        entry={"name": "Armoured vehicle (Humvee, sand)", "category": "Military", "model": "Humvee",
                               "sub_model": "Sand", "pack": "humvee_anim", "source": "repaired rig"}),
}
## Shops (shops/catalog.json): front -Z, metres.
SHOPS = {
    "shop-townhouse-blue": {"src": "low_poly_building.glb", "yaw": 90, "height": 9.0, "tex": 256,
                            "file": "shops/models/%s.glb",
                            "entry": {"category": "Townhouse", "name": "Low Poly Building (blue townhouse)",
                                      "credit": {"title": "Low Poly Building", "author": "Ahmed Galeb",
                                                 "url": "https://sketchfab.com/AhmedGaleb", "license": "CC-BY-4.0"},
                                      "notes": "Blue 3-storey townhouse with pink awnings and window boxes."}},
    # Twenty-first wave: two more buildings for the development island (ShopSites).
    "shop-business": {"src": "low_poly_business_buildings_pack.glb", "nodes": ["ShopBuilding"], "yaw": 180,
                      "width": 6.0, "tex": 512, "file": "shops/models/%s.glb",
                      "entry": {"category": "Business", "name": "Low Poly Business Buildings (shop)",
                                "credit": {"title": "Low Poly Business Buildings Pack", "author": "unknown",
                                           "url": "", "license": "see the pack"},
                                "notes": "ShopBuilding of the business pack: pink shop with a striped awning."}},
    "shop-house-balcony": {"src": "low_poly_house_with_wooden_balcony_and_tent.glb", "skip": ["Plane.001"],
                           "yaw": 90, "width": 8.0, "tex": 512, "file": "shops/models/%s.glb",
                           "entry": {"category": "House", "name": "Low Poly House (wooden balcony and tent)",
                                     "credit": {"title": "Low poly house with wooden balcony and tent",
                                                "author": "unknown", "url": "", "license": "see the source"},
                                     "notes": "Wooden house with a balcony, plants and a striped tent on the roof."}},
}
CREDITS = {
    "schoolbus": {"title": "SCHOOL BUS - low poly model", "author": "Jasmin Daniel",
                  "url": "https://sketchfab.com/jasmin.daniel", "license": "CC-BY-4.0"},
    "jeep": {"title": "Jeep", "author": "rajibkc", "url": "https://sketchfab.com/rajibkc", "license": "CC-BY-4.0"},
    "humvee_test": {"title": "Armored Vehicle-Test", "author": "Kapi777", "url": "https://sketchfab.com/Kapi777",
                    "license": "CC-BY-NC-4.0"},
    "humvee_anim": {"title": "Armored Vehicle+Animation", "author": "Kapi777", "url": "https://sketchfab.com/Kapi777",
                    "license": "CC-BY-NC-4.0"},
}


def main():
    args = sys.argv[1:]
    src = os.path.join(ROOT, "FREEMODELS", "_incoming")
    if "--src" in args:
        src = args[args.index("--src") + 1]
        del args[args.index("--src"):args.index("--src") + 2]
    info = "--info" in args
    only = [a for a in args if not a.startswith("--")]
    if info:
        for name in only:
            g = Glb(os.path.join(src, name))
            for p in g.parts(64):
                lo, hi = p["pos"].min(0), p["pos"].max(0)
                print("%-70s %-22s tris %6d  lo %s hi %s" % (p["path"][-70:], p["mat"]["name"][:22], len(p["idx"]),
                      np.round(lo, 2), np.round(hi, 2)))
        return
    cache = {}

    def source(name, tex):
        if (name, tex) not in cache:
            cache[(name, tex)] = Glb(os.path.join(src, name)).parts(tex)
            repair_humvee(cache[(name, tex)])
        return cache[(name, tex)]

    for pack, spec in PACKS.items():
        if only and pack not in only:
            continue
        items, manifest = [], []
        for it in spec["items"]:
            parts = pick(source(it.get("src", spec.get("src")), spec.get("tex", 512)), it)
            if not parts:
                print("!! nothing found for", it["id"])
                continue
            size = shape(parts, it)
            if "weld" in it:
                parts = welded(parts, it["weld"])
            parts = merged(parts)
            items.append((it["id"], parts))
            manifest.append({"cat": it["cat"], "node": it["id"]})
            print("%-18s %-16s %.2f x %.2f x %.2f cells, %d triangles" % (pack, it["id"], *size, triangles(parts)))
        out = os.path.join(ROOT, "FREEMODELS", "curated", pack)
        write_glb(out + ".glb", pack, items)
        with open(out + ".models.json", "w", newline="\n") as f:
            json.dump({"file": pack + ".glb", "models": manifest}, f, indent="\t")
            f.write("\n")
    _lighthouse(only, source)
    _catalog(only, source, VEHICLES, "vehicles", "vehicles")
    _catalog(only, source, SHOPS, "shops", "shops")


def _lighthouse(only, source):
    """FREEMODELS/curated/lighthouse_club.glb: the lighthouse with its club sign (LIGHTHOUSE)."""
    if only and "lighthouse_club" not in only:
        return
    spec = LIGHTHOUSE
    house = pick(source(spec["src"], spec["tex"]), {})
    size = shape(house, {"length": spec["length"]})
    pos = np.concatenate([p["pos"] for p in house])
    # The east wall: the farthest point east of the low part of the house (below its eaves),
    # and how far the house runs from back to front at that end.
    low = pos[pos[:, 1] < 0.3]
    east = low[:, 0].max()
    end = low[low[:, 0] > east - 0.15]
    back, front = end[:, 2].min(), end[:, 2].max()
    sign = pick(source(spec["sign"], spec["tex"]), {})
    lo, hi = box(sign)
    s = spec["sign_height"] / (hi[1] - lo[1])
    at = np.array([east + 0.01, spec["sign_lift"], back + (front - back) * spec["sign_along"]])
    for p in sign:
        # Its poles (the west end, -x) against the wall, its face to +Z.
        p["pos"] = (p["pos"] - np.array([lo[0], lo[1], (lo[2] + hi[2]) * 0.5])) * s + at
    glow = pick(sign, {"nodes": spec["glow"], "neon": True})
    metal = pick(sign, {"skip": spec["glow"]})
    items = [("lighthouse_club", merged(house + metal)), ("lighthouse_club_neon", merged(glow))]
    out = os.path.join(ROOT, "FREEMODELS", "curated", "lighthouse_club")
    write_glb(out + ".glb", "lighthouse_club", items)
    with open(out + ".models.json", "w", newline="\n") as f:
        json.dump({"file": "lighthouse_club.glb", "models": [{"cat": "LIGHTHOUSE_CLUB", "node": "lighthouse_club"},
                   {"cat": "NEON_LIGHTHOUSE", "node": "lighthouse_club_neon"}]}, f, indent="\t")
        f.write("\n")
    print("%-18s %-16s %.2f x %.2f x %.2f cells, %d + %d triangles, east wall x %.2f, z %.2f..%.2f" % (
          "lighthouse_club", "lighthouse_club", *size, triangles(items[0][1]), triangles(items[1][1]), east, back, front))


def _catalog(only, source, table, folder, key):
    path = os.path.join(ROOT, folder, "catalog.json")
    cat = json.load(open(path))
    changed = False
    for vid, spec in table.items():
        if only and vid not in only:
            continue
        parts = pick(source(spec["src"], spec.get("tex", 256)), spec)
        size = shape(parts, spec)
        parts = merged(parts)
        rel = spec["file"] % vid
        write_glb(os.path.join(ROOT, rel), vid, [(vid + "_body", parts)])
        entry = {"id": vid}
        entry.update(spec["entry"])
        entry.update({"file": "res://" + rel, "triangles": triangles(parts)})
        if folder == "vehicles":
            thumb = "vehicles/thumbs/%s.png" % vid
            preview(parts, os.path.join(ROOT, thumb), 240)
            entry["thumbnail"] = "res://" + thumb
            entry["parts"] = ["Body"]
            entry["size_m"] = {"width": round(size[0], 2), "height": round(size[1], 2), "length": round(size[2], 2)}
        else:
            entry["size_m"] = {"width": round(size[0], 2), "depth": round(size[2], 2), "height": round(size[1], 2)}
        cat[key] = [e for e in cat[key] if e["id"] != vid] + [entry]
        changed = True
        print("%-18s %-28s %.2f x %.2f x %.2f m, %d triangles" % (folder, vid, *size, entry["triangles"]))
    if changed:
        if "credits" in cat:
            cat["credits"].update({k: v for k, v in CREDITS.items() if any(
                    e.get("pack") == k for e in cat[key])})
        with open(path, "w", newline="\n") as f:
            json.dump(cat, f, indent=1)
            f.write("\n")


if __name__ == "__main__":
    main()
