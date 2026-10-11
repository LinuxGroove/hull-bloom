"""Builds Verdigris Protocol's plasma cutter in Blender from the Modular Sci-Fi MegaKit's trim sheets.

Run: blender-venv/bin/python cutter.py <textures dir> <out dir>
Writes cutter.blend, cutter.glb and cutter.gltf (textures referenced by the kit's file names).
Axes: the barrel points +Y in Blender, which is -Z (forward) in Godot.
"""
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix

TEX, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ---------- materials ----------
def image(name, data=False):
    im = bpy.data.images.load(os.path.join(TEX, name), check_existing=True)
    if data:
        im.colorspace_settings.name = 'Non-Color'
    return im


def trim(name, base, normal, orm):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes['Principled BSDF']
    tb = nt.nodes.new('ShaderNodeTexImage'); tb.image = image(base)
    nt.links.new(tb.outputs['Color'], bsdf.inputs['Base Color'])
    to = nt.nodes.new('ShaderNodeTexImage'); to.image = image(orm, True)
    sep = nt.nodes.new('ShaderNodeSeparateColor')
    nt.links.new(to.outputs['Color'], sep.inputs['Color'])
    nt.links.new(sep.outputs['Green'], bsdf.inputs['Roughness'])
    nt.links.new(sep.outputs['Blue'], bsdf.inputs['Metallic'])
    tn = nt.nodes.new('ShaderNodeTexImage'); tn.image = image(normal, True)
    nm = nt.nodes.new('ShaderNodeNormalMap')
    nt.links.new(tn.outputs['Color'], nm.inputs['Color'])
    nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    return m


def flat(name, color, rough=0.5, metal=0.0, emit=None, strength=0.0, alpha=1.0, transmission=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1)
        b.inputs['Emission Strength'].default_value = strength
    if transmission:
        b.inputs['Transmission Weight'].default_value = transmission
    if alpha < 1:
        b.inputs['Alpha'].default_value = alpha
        m.surface_render_method = 'BLENDED'
    return m


M_BODY = trim('MI_Trim_02_Red', 'T_Trim_02_BaseColor_Red.png', 'T_Trim_02_Normal.png', 'T_Trim_02_ORM.png')
M_PANEL = trim('MI_Trim_01', 'T_Trim_01_BaseColor.png', 'T_Trim_01_Normal.png', 'T_Trim_01_ORM.png')
M_DARK = trim('MI_Trim_03_Dark', 'T_Trim_03_Cables.png', 'T_Trim_03_Normal.png', 'T_Trim_03_ORM.png')
M_GLOW = flat('M_Cutter_Glow', (0.05, 0.45, 1.0), emit=(0.02, 0.5, 1.0), strength=1.1)
M_CORE = flat('M_Cutter_Core', (0.05, 0.45, 1.0), emit=(0.02, 0.5, 1.0), strength=0.9)


def screen_material():
    """The heat readout: a small texture drawn here, shown as both colour and glow."""
    w, h = 256, 160
    px = [0.0] * (w * h * 4)
    def rect(x0, y0, x1, y1, c):
        for y in range(y0, y1):
            for x in range(x0, x1):
                i = ((h - 1 - y) * w + x) * 4
                px[i:i + 4] = c
    rect(0, 0, w, h, (0.005, 0.02, 0.03, 1))
    rect(8, 8, w - 8, 12, (0.1, 0.5, 0.7, 1)); rect(8, h - 12, w - 8, h - 8, (0.1, 0.5, 0.7, 1))
    for k in range(10):  # heat bars, seven lit, warming to amber
        on = k < 7
        c = (0.25, 0.75, 1.0, 1) if k < 4 else (1.0, 0.55, 0.15, 1)
        rect(24 + k * 21, 40, 24 + k * 21 + 15, 120, c if on else (0.03, 0.08, 0.1, 1))
    im = bpy.data.images.new('T_Cutter_Screen', w, h)
    im.pixels = px
    im.filepath_raw = os.path.join(OUT, 'T_Cutter_Screen.png'); im.file_format = 'PNG'; im.save()
    m = bpy.data.materials.new('M_Cutter_Screen'); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    t = nt.nodes.new('ShaderNodeTexImage'); t.image = im
    nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    nt.links.new(t.outputs['Color'], b.inputs['Emission Color'])
    b.inputs['Emission Strength'].default_value = 2.0
    b.inputs['Roughness'].default_value = 0.15
    return m


M_SCREEN = screen_material()
M_GLASS = flat('M_Cutter_Glass', (0.05, 0.12, 0.15), rough=0.05, alpha=0.35)
M_RUBBER = flat('M_Cutter_Grip', (0.025, 0.027, 0.03), rough=0.85)


# ---------- UVs on the trim sheets ----------
# Regions are (u0, v0, u1, v1) in image space (v down), as read off the textures.
def to_uv(u0, v0, u1, v1, a, b):
    return Vector((u0 + a * (u1 - u0), 1.0 - (v0 + b * (v1 - v0))))


def box_uv(bm, regions):
    """Fit each face group (by dominant axis) into its trim region."""
    uv = bm.loops.layers.uv.verify()
    lo = Vector([min(v.co[i] for v in bm.verts) for i in range(3)])
    hi = Vector([max(v.co[i] for v in bm.verts) for i in range(3)])
    span = hi - lo
    span = Vector([s if s > 1e-6 else 1 for s in span])
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        r = regions['xyz'[ax]]
        for l in f.loops:
            c = (l.vert.co - lo)
            if ax == 0:
                a, b = c.y / span.y, 1 - c.z / span.z
            elif ax == 1:
                a, b = c.x / span.x, 1 - c.z / span.z
            else:
                a, b = c.y / span.y, c.x / span.x
            l[uv].uv = to_uv(*r, a, b)


def tube_uv(bm, side, cap=None):
    """Cylinder along Y: wrap `side` round it, map `cap` onto the ends."""
    uv = bm.loops.layers.uv.verify()
    ys = [v.co.y for v in bm.verts]
    y0, y1 = min(ys), max(ys)
    rmax = max(math.hypot(v.co.x, v.co.z) for v in bm.verts) or 1
    for f in bm.faces:
        if abs(f.normal.y) > 0.9:
            r = cap or side
            for l in f.loops:
                l[uv].uv = to_uv(*r, 0.5 + 0.5 * l.vert.co.x / rmax, 0.5 - 0.5 * l.vert.co.z / rmax)
            continue
        angs = [math.atan2(l.vert.co.z, l.vert.co.x) for l in f.loops]
        ref = angs[0]
        for l, a in zip(f.loops, angs):
            if a - ref > math.pi: a -= 2 * math.pi
            if ref - a > math.pi: a += 2 * math.pi
            l[uv].uv = to_uv(*side, (a + math.pi) / (2 * math.pi), (l.vert.co.y - y0) / max(y1 - y0, 1e-6))


# ---------- parts ----------
parts = []


def finish(name, bm, mat, loc=(0, 0, 0), rot=(0, 0, 0), smooth=0.6):
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if e.is_manifold and e.calc_face_angle(0) > smooth:
            e.smooth = False
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    scene.collection.objects.link(ob)
    parts.append(ob)
    return ob


def box(name, size, loc, mat, regions, bevel=0.008, segs=3, rot=(0, 0, 0), taper=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    if taper:  # shrink the front (+Y) face: (x scale, z scale, z shift)
        front = [v for v in bm.verts if v.co.y > 0]
        for v in front:
            v.co.x *= taper[0]
            v.co.z = v.co.z * taper[1] + taper[2]
    if bevel:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=segs, affect='EDGES', profile=0.5, clamp_overlap=True)
    bm.normal_update()
    box_uv(bm, regions)
    return finish(name, bm, mat, loc, rot)


def tube(name, r1, r2, length, loc, mat, side, cap=None, segs=40, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=length)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-90), 3, 'X'))
    if bevel:
        rims = [e for e in bm.edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.y - e.link_faces[1].normal.y) > 0.5]
        bmesh.ops.bevel(bm, geom=rims, offset=bevel, segments=2, affect='EDGES', profile=0.5, clamp_overlap=True)
    bm.normal_update()
    tube_uv(bm, side, cap)
    return finish(name, bm, mat, loc)


def ring(name, major, minor, y, mat):
    bm = bmesh.new()
    segs, sides = 48, 12
    verts = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        row = []
        for j in range(sides):
            b = 2 * math.pi * j / sides
            rr = major + minor * math.cos(b)
            row.append(bm.verts.new((rr * math.cos(a), minor * math.sin(b), rr * math.sin(a))))
        verts.append(row)
    for i in range(segs):
        for j in range(sides):
            bm.faces.new((verts[i][j], verts[(i + 1) % segs][j], verts[(i + 1) % segs][(j + 1) % sides], verts[i][(j + 1) % sides]))
    bm.normal_update()
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for l in f.loops:
            l[uv].uv = (0.5, 0.5)
    return finish(name, bm, mat, (0, y, 0), smooth=3.0)


# Trim regions (image space).
SIDE_GREEBLE = (0.0, 0.605, 0.62, 0.80)     # buttons, grille, round hatch, amber light
PLAIN = (0.04, 0.28, 0.40, 0.58)             # plain panel with a seam
BRACKETS = (0.18, 0.035, 0.92, 0.245)        # panel strip with brackets
HAZARD = (0.012, 0.792, 0.27, 0.822)         # red and grey hazard stripes
RIVETS = (0.0, 0.43, 1.0, 0.47)              # Trim_01 riveted band
TRIANGLES = (0.0, 0.335, 1.0, 0.37)          # Trim_01 triangle band
HATCH = (0.525, 0.715, 0.635, 0.825)         # round hatch, for end caps
X_PANEL = (0.79, 0.62, 0.995, 0.85)          # Trim_02 X-braced panel
DARK = (0.1, 0.1, 0.6, 0.6)

body = box('Body', (0.12, 0.42, 0.13), (0, 0.0, 0.0), M_BODY,
           {'x': SIDE_GREEBLE, 'y': X_PANEL, 'z': PLAIN}, bevel=0.012, taper=(0.92, 0.85, -0.006))
box('Housing', (0.09, 0.3, 0.045), (0, -0.03, 0.085), M_BODY, {'x': BRACKETS, 'y': PLAIN, 'z': BRACKETS}, bevel=0.008)
box('HazardRail', (0.034, 0.27, 0.012), (0, -0.03, 0.111), M_BODY, {'x': HAZARD, 'y': HAZARD, 'z': HAZARD}, bevel=0.003, segs=2)
box('Underplate', (0.13, 0.22, 0.02), (0, -0.04, -0.07), M_DARK, {'x': DARK, 'y': DARK, 'z': DARK}, bevel=0.006)
# Barrel: shroud, fins, inner barrel, emitter rings, nozzle.
tube('Shroud', 0.05, 0.046, 0.17, (0, 0.29, 0.0), M_PANEL, RIVETS, cap=HATCH, bevel=0.006)
for k in range(6):
    box(f'Fin{k}', (0.085, 0.006, 0.026), (0, 0.225 + k * 0.024, 0.052), M_DARK, {'x': DARK, 'y': DARK, 'z': DARK}, bevel=0.002, segs=1)
tube('Barrel', 0.03, 0.03, 0.13, (0, 0.43, 0.0), M_BODY, TRIANGLES)
for k, y in enumerate((0.395, 0.425, 0.455)):
    ring(f'Emitter{k}', 0.036, 0.0075, y, M_GLOW)
tube('Nozzle', 0.036, 0.02, 0.055, (0, 0.52, 0.0), M_DARK, DARK, bevel=0.003)
tube('Tip', 0.012, 0.004, 0.012, (0, 0.553, 0.0), M_GLOW, DARK, segs=24)
# The plasma cell on the left side.
tube('CellGlass', 0.038, 0.038, 0.2, (-0.098, -0.03, -0.005), M_GLASS, DARK, segs=32)
tube('CellCore', 0.016, 0.016, 0.19, (-0.098, -0.03, -0.005), M_CORE, DARK, segs=24)
for y in (-0.135, 0.075):
    tube(f'CellCap{y}', 0.043, 0.043, 0.024, (-0.098, y, -0.005), M_BODY, BRACKETS, cap=HATCH, bevel=0.004)
for y in (-0.09, 0.03):
    box(f'CellClamp{y}', (0.03, 0.018, 0.05), (-0.07, y, -0.005), M_DARK, {'x': DARK, 'y': DARK, 'z': DARK}, bevel=0.003)
# Grip, trigger, foregrip.
box('Grip', (0.042, 0.07, 0.17), (0, -0.13, -0.14), M_RUBBER, {'x': DARK, 'y': DARK, 'z': DARK}, bevel=0.012, rot=(-16, 0, 0))
box('Trigger', (0.012, 0.016, 0.038), (0, -0.065, -0.095), M_DARK, {'x': DARK, 'y': DARK, 'z': DARK}, bevel=0.003, rot=(12, 0, 0))
box('Guard', (0.016, 0.11, 0.01), (0, -0.065, -0.125), M_DARK, {'x': DARK, 'y': DARK, 'z': DARK}, bevel=0.003)
tube('Foregrip', 0.021, 0.019, 0.1, (0, 0.14, -0.12), M_RUBBER, DARK, segs=24, bevel=0.005).rotation_euler = (math.radians(90), 0, 0)
# The heat readout at the back.
box('Screen', (0.072, 0.01, 0.045), (0, -0.2, 0.095), M_SCREEN, {'x': (0, 0, 0.03, 0.03), 'y': (0, 0, 1, 1), 'z': (0, 0, 0.03, 0.03)}, bevel=0.002, segs=1, rot=(-28, 0, 0))
box('ScreenFrame', (0.084, 0.012, 0.057), (0, -0.205, 0.093), M_DARK, {'x': DARK, 'y': DARK, 'z': DARK}, bevel=0.003, rot=(-28, 0, 0))

# One object, ready for a game.
bpy.ops.object.select_all(action='DESELECT')
for ob in parts:
    ob.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body.name = 'PlasmaCutter'
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
print('triangles', tris, 'materials', [m.name for m in body.data.materials])

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'cutter.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'cutter.glb'), export_format='GLB', use_selection=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'gltf', 'cutter.gltf'), export_format='GLTF_SEPARATE', use_selection=True)
print('done')
