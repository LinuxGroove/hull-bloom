"""Renders cutter.blend from a few angles with Cycles on the CPU. Run: python render.py <out dir>"""
import bpy, math, sys, os
from mathutils import Vector

OUT = sys.argv[1]
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT, 'cutter.blend'))
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 960, 600
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Medium High Contrast'

world = bpy.data.worlds.new('World'); scene.world = world
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.012, 0.014, 0.018, 1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0


def light(name, kind, loc, energy, color, size=0.5, target=(0, 0.1, 0)):
    d = bpy.data.lights.new(name, kind)
    d.energy = energy; d.color = color
    if kind == 'AREA': d.size = size
    o = bpy.data.objects.new(name, d); o.location = loc
    scene.collection.objects.link(o)
    direction = Vector(target) - Vector(loc)
    o.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()


light('Key', 'AREA', (0.9, -0.6, 0.9), 60, (1.0, 0.96, 0.92), 0.8)
light('Rim', 'AREA', (-0.8, 0.9, 0.5), 45, (0.55, 0.8, 1.0), 0.6)
light('Warm', 'AREA', (-0.4, -0.9, -0.3), 18, (1.0, 0.45, 0.25), 0.6)

# A dark floor so it doesn't float in a void.
bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, -0.26))
floor = bpy.context.active_object
fm = bpy.data.materials.new('Floor'); fm.use_nodes = True
fm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.012, 0.013, 0.016, 1)
fm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.7
floor.data.materials.append(fm)

cam_data = bpy.data.cameras.new('Cam'); cam = bpy.data.objects.new('Cam', cam_data)
scene.collection.objects.link(cam); scene.camera = cam
views = {
    'three_quarter': ((0.95, -0.75, 0.45), (0, 0.12, -0.02), 50),
    'side': ((-1.35, 0.15, 0.1), (0, 0.15, -0.03), 50),
    'first_person': ((-0.15, -0.62, 0.17), (-0.06, 1.6, -0.02), 30),
}
for name, (loc, target, lens) in views.items():
    cam.location = loc
    cam_data.lens = lens
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = os.path.join(OUT, f'render_{name}.png')
    bpy.ops.render.render(write_still=True)
    print('rendered', name)
