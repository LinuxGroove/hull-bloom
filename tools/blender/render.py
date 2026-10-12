"""Imports an exported .gltf and renders it with Cycles on the CPU.
Run: python render.py <file.gltf> <out prefix> <views json> [samples]"""
import bpy, math, sys, os, json
from mathutils import Vector

SRC, PREFIX, VIEWS = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
SAMPLES = int(sys.argv[4]) if len(sys.argv) > 4 else 32
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=SRC)
for ob in bpy.data.objects:
    print('object', ob.name, ob.type, tuple(round(x, 4) for x in ob.matrix_world.translation), 'parent', ob.parent.name if ob.parent else None)
    if ob.type == 'MESH':
        for m in ob.data.materials:
            imgs = [n.image.filepath for n in m.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image] if m.use_nodes else []
            print('  mat', m.name, [ (os.path.basename(p), os.path.exists(bpy.path.abspath(p))) for p in imgs])
pts = [ob.matrix_world @ v.co for ob in bpy.data.objects if ob.type == 'MESH' for v in ob.data.vertices]
lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)])
print('bounds', tuple(round(x, 4) for x in lo), tuple(round(x, 4) for x in hi))

scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = SAMPLES
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 960, 600
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Medium High Contrast'
world = bpy.data.worlds.new('World'); scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes['Background']
bg.inputs['Color'].default_value = (0.09, 0.1, 0.12, 1)
bg.inputs['Strength'].default_value = 1.0


def light(name, kind, loc, energy, color, size=0.5, target=(0, 0.1, 0)):
    d = bpy.data.lights.new(name, kind)
    d.energy = energy; d.color = color
    if kind == 'AREA': d.size = size
    o = bpy.data.objects.new(name, d); o.location = loc
    scene.collection.objects.link(o)
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()


light('Key', 'AREA', (0.9, -0.6, 0.9), 60, (1.0, 0.96, 0.92), 0.8)
light('Rim', 'AREA', (-0.8, 0.9, 0.5), 45, (0.55, 0.8, 1.0), 0.6)
light('Fill', 'AREA', (-0.9, -0.7, 0.6), 30, (1.0, 1.0, 1.0), 0.8)
light('Warm', 'AREA', (-0.4, -0.9, -0.3), 18, (1.0, 0.45, 0.25), 0.6)
bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, lo.z - 0.04))
floor = bpy.context.active_object
fm = bpy.data.materials.new('Floor'); fm.use_nodes = True
fm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.05, 0.055, 0.06, 1)
fm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.7
floor.data.materials.append(fm)

cam_data = bpy.data.cameras.new('Cam'); cam = bpy.data.objects.new('Cam', cam_data)
scene.collection.objects.link(cam); scene.camera = cam
for name, v in VIEWS.items():
    loc, target, lens = v[:3]
    cam.location = loc
    cam_data.lens = lens
    cam_data.clip_start = 0.01
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = f'{PREFIX}_{name}.png'
    bpy.ops.render.render(write_still=True)
    print('rendered', name)
