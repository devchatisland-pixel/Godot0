"""blender -b -P render.py -- outdir night(0/1) group [group ...]
group = a.glb or a.glb+b.glb (models side by side in one picture). One png per group,
named after the first file. Night: dark world, emission x3 (like the game)."""
import bpy, sys, math, os
from mathutils import Vector
a = sys.argv[sys.argv.index('--') + 1:]
outdir, night, groups = a[0], a[1] == '1', a[2:]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
ids = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
sc.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in ids else 'BLENDER_EEVEE_NEXT'
sc.render.resolution_x, sc.render.resolution_y = 1200, 700
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
bg = w.node_tree.nodes['Background']
bg.inputs[0].default_value = (0.02, 0.025, 0.05, 1) if night else (0.5, 0.55, 0.65, 1)
bg.inputs[1].default_value = 0.6 if night else 1.0
sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN')); sc.collection.objects.link(sun)
sun.data.energy = 0.15 if night else 3; sun.rotation_euler = (math.radians(50), 0, math.radians(30))
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 40
for grp in groups:
    for o in list(bpy.data.objects):
        if o not in (sun, cam):
            bpy.data.objects.remove(o, do_unlink=True)
    x = 0.0
    allmin, allmax = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for f in grp.split('+'):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=f)
        new = [o for o in bpy.data.objects if o not in before]
        for o in new:
            if 'ollider' in o.name or o.type in ('CAMERA', 'LIGHT'):
                o.hide_render = True
        bpy.context.view_layer.update()
        pts = [o.matrix_world @ Vector(c) for o in new if o.type == 'MESH' and not o.hide_render for c in o.bound_box]
        lo = Vector([min(p[i] for p in pts) for i in range(3)])
        hi = Vector([max(p[i] for p in pts) for i in range(3)])
        for r in [o for o in new if o.parent is None]:
            r.location.x += x - lo.x
        allmin = Vector((min(allmin.x, x), min(allmin.y, lo.y), min(allmin.z, lo.z)))
        x += (hi.x - lo.x) * 1.08
        allmax = Vector((max(allmax.x, x), max(allmax.y, hi.y), max(allmax.z, hi.z)))
        if night:
            for o in new:
                if o.type != 'MESH':
                    continue
                for m in o.data.materials:
                    b = m.node_tree.nodes.get('Principled BSDF') if m and m.use_nodes else None
                    if b and 'Emission Strength' in b.inputs:
                        b.inputs['Emission Strength'].default_value *= 3.0
    ctr = (allmin + allmax) / 2
    ext = allmax - allmin
    # Far enough for the whole width and height (lens 40 mm on a 36 mm sensor, 1200 x 700).
    dist = max(ext.x / (2 * math.tan(math.radians(24))), ext.z / (2 * math.tan(math.radians(14.5)))) * 1.25 + ext.y / 2
    # glTF front (-Z) is Blender +Y after import.
    d = Vector((0.2, 1.0, 0.3)).normalized()
    cam.location = ctr + d * dist
    cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(outdir, os.path.basename(grp.split('+')[0]).replace('.glb', '.png'))
    bpy.ops.render.render(write_still=True)
