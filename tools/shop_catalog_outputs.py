"""Text outputs of tools/build_shop_catalog.py: shops/CATALOG.md and the preview scene."""
import math


def write_markdown(data, path):
    rows = [
        "# Shop catalog", "",
        "15 shops placed on the island by `scripts/generation/shop_sites.gd` (data: `shops/catalog.json`).", "",
        "![Shop catalog](CATALOG.png)", "",
        "Models face -Z, origin at the centre of the footprint on the ground, 1 unit = 1 m.",
        "Rebuild with `python tools/build_shop_catalog.py <raw dir> shops`. Preview all of them in a row:",
        "`shops/preview/shop_island.tscn` (wheel = zoom, WASD = pan, F = reset).", "",
        "| ID | Category | Name | W x D x H (m) | Zones | Copies | Author | License |",
        "|---|---|---|---|---|---:|---|---|",
    ]
    for s in data["shops"]:
        z = s["size_m"]
        rows.append("| `%s` | %s | %s | %g x %g x %g | %s | %d | %s | %s |" % (
            s["id"], s["category"], s["name"], z["width"], z["depth"], z["height"],
            ", ".join(s["zones"]), s["copies"], s["credit"]["author"], s["credit"]["license"]))
    rows += ["", "## Notes and credits", ""]
    for s in data["shops"]:
        rows.append("- **%s** - %s Source: <%s>" % (s["id"], s["notes"], s["credit"]["url"]))
    rows.append("")
    open(path, "w", encoding="utf8", newline="\n").write("\n".join(rows))


def _tr(x, y, z):
    return "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.2f, %.2f, %.2f)" % (x, y, z)


def write_island(data, path):
    """A flat island with every shop in a row, sorted by height, fronts towards the camera (+Z)."""
    shops = sorted(data["shops"], key=lambda s: s["size_m"]["height"])
    gap, x = 4.0, 16.0
    ext = []
    for n, s in enumerate(shops):
        sz = s["size_m"]
        s["_x"] = x + sz["width"] / 2
        x += sz["width"] + gap
        ext.append('[ext_resource type="PackedScene" path="%s" id="%d_s"]' % (s["file"], n + 1))
    ext.append('[ext_resource type="Script" path="res://shops/preview/shop_island_camera.gd" id="cam_script"]')
    total = x - gap
    depth = max(s["size_m"]["depth"] for s in shops)
    w, d = total + 16, depth + 70
    cx, cz = (total + 4) / 2, (30 - (depth + 40)) / 2

    subs = [
        '[sub_resource type="StandardMaterial3D" id="g"]\nalbedo_color = Color(0.45, 0.72, 0.38, 1)',
        '[sub_resource type="StandardMaterial3D" id="sd"]\nalbedo_color = Color(0.9, 0.82, 0.6, 1)',
        '[sub_resource type="StandardMaterial3D" id="rl"]\nalbedo_color = Color(0.9, 0.2, 0.2, 1)',
        '[sub_resource type="BoxMesh" id="m_isl"]\nmaterial = SubResource("g")\nsize = Vector3(%.1f, 2, %.1f)' % (w, d),
        '[sub_resource type="BoxMesh" id="m_sand"]\nmaterial = SubResource("sd")\nsize = Vector3(%.1f, 1.5, %.1f)' % (w + 10, d + 10),
        '[sub_resource type="BoxMesh" id="m_rl"]\nmaterial = SubResource("rl")\nsize = Vector3(10, 0.1, 0.3)',
        '[sub_resource type="Environment" id="env"]\nbackground_mode = 1\nbackground_color = Color(0.55, 0.75, 0.95, 1)\n'
        'ambient_light_source = 2\nambient_light_color = Color(1, 1, 1, 1)\nambient_light_energy = 0.6',
    ]
    label = 'pixel_size = 0.012\nfont_size = 72\noutline_size = 24\n'
    nodes = [
        # Far from the map's own origin, in case the scene is ever instanced into it.
        '[node name="ShopIsland" type="Node3D"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2000, 0, 2000)\n',
        '[node name="Environment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("env")\n',
        '[node name="Sun" type="DirectionalLight3D" parent="."]\n'
        'transform = Transform3D(0.9, -0.2, 0.39, 0, 0.89, 0.46, -0.44, -0.41, 0.8, %.1f, 40, %.1f)\n'
        'shadow_enabled = true\ndirectional_shadow_max_distance = 400.0\n' % (cx, cz),
        '[node name="IslandSand" type="MeshInstance3D" parent="."]\ntransform = %s\nmesh = SubResource("m_sand")\n' % _tr(cx, -2.75, cz),
        '[node name="IslandGrass" type="MeshInstance3D" parent="."]\ntransform = %s\nmesh = SubResource("m_isl")\n' % _tr(cx, -1, cz),
        '[node name="Ruler10" type="MeshInstance3D" parent="."]\ntransform = %s\nmesh = SubResource("m_rl")\n' % _tr(5, 0.05, 5),
        '[node name="Ruler10_label" type="Label3D" parent="."]\ntransform = %s\n%stext = "10 m"\n' % (_tr(5, 0.8, 5), label),
    ]
    for n, s in enumerate(shops):
        sz = s["size_m"]
        # Turned 180 degrees: the models face -Z, the camera is on +Z.
        nodes.append('[node name="%s" parent="." instance=ExtResource("%d_s")]\n'
                     'transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, %.2f, 0, 0)\n' % (s["id"], n + 1, s["_x"]))
        nodes.append('[node name="Label_%s" type="Label3D" parent="."]\ntransform = %s\n%stext = "%s\\n%.1f x %.1f x %.1f"\n' % (
            s["id"], _tr(s["_x"], 0.9, sz["depth"] / 2 + 4), label, s["id"], sz["width"], sz["height"], sz["depth"]))
    dist = (total / 2 + 10) / math.tan(math.radians(20))
    nodes.append('[node name="Camera3D" type="Camera3D" parent="."]\n'
                 'transform = Transform3D(1, 0, 0, 0, 0.9703, 0.2419, 0, -0.2419, 0.9703, %.2f, %.2f, %.2f)\n'
                 'fov = 40.0\nfar = 2000.0\ncurrent = true\nscript = ExtResource("cam_script")\n'
                 % ((16 + total) / 2, 0.25 * dist + 4, dist))
    head = "[gd_scene load_steps=%d format=3]\n" % (len(ext) + len(subs) + 1)
    text = head + "\n" + "\n".join(ext) + "\n\n" + "\n\n".join(subs) + "\n\n" + "\n".join(nodes)
    open(path, "w", encoding="utf8", newline="\n").write(text)
