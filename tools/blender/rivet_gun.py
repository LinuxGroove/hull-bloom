"""Builds Verdigris Protocol's rivet gun, and a single rivet, in Blender from the
Modular Sci-Fi MegaKit's trim sheets.

Run: blender-venv/bin/python rivet_gun.py <textures dir> <out dir>
Writes rivet_gun.gltf (body in MI_Trim_02, amber hazard stripes from T_Rivet_Hazard.png),
rivet_gun_red.gltf (body in MI_Trim_02_Red, the workbench's upgrade) and rivet.gltf, each
with its own .bin, into <out dir>; the kit's textures are referenced where they are
(relative to <out dir>), not copied.
.blend files go to the folder in $RIVET_BLEND when that's set.
Axes: the nose points +Y in Blender, which is -Z (forward) in Godot. The `Muzzle` empty
sits at the centre of the nose plate's front. The rivet points +Y too, its origin
under its head, so the shank goes into a wall and the head stays outside.
"""
import bpy, bmesh, math, sys, os, json, random
from mathutils import Vector, Matrix

TEX, OUT = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
os.makedirs(OUT, exist_ok=True)


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


def flat(name, color, rough=0.5, metal=0.0, emit=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1)
        b.inputs['Emission Strength'].default_value = strength
    return m


def reset():
    """A fresh scene with the materials every piece here uses."""
    global scene, parts, M_PLAIN, M_RED, M_PANEL, M_DARK, M_GLOW, M_RUBBER, M_HOSE, M_STEEL, M_HAZARD
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    parts = []
    random.seed(11)
    M_PLAIN = trim('MI_Trim_02', 'T_Trim_02_BaseColor.png', 'T_Trim_02_Normal.png', 'T_Trim_02_ORM.png')
    M_RED = trim('MI_Trim_02_Red', 'T_Trim_02_BaseColor_Red.png', 'T_Trim_02_Normal.png', 'T_Trim_02_ORM.png')
    M_PANEL = trim('MI_Trim_01', 'T_Trim_01_BaseColor.png', 'T_Trim_01_Normal.png', 'T_Trim_01_ORM.png')
    M_DARK = trim('MI_Trim_03_Dark', 'T_Trim_03_Cables.png', 'T_Trim_03_Normal.png', 'T_Trim_03_ORM.png')
    M_GLOW = flat('M_Rivet_Glow', (1.0, 0.55, 0.12), emit=(1.0, 0.5, 0.08), strength=2.0)
    M_RUBBER = flat('M_Rivet_Grip', (0.025, 0.027, 0.03), rough=0.85)
    M_HOSE = flat('M_Rivet_Hose', (0.75, 0.48, 0.05), rough=0.6)
    M_STEEL = flat('M_Rivet_Steel', (0.32, 0.33, 0.35), rough=0.35, metal=1.0)
    M_HAZARD = hazard_material()


def hazard_material():
    """Amber and black hazard stripes for the plain gun: a small texture drawn here
    (the red gun uses the red sheet's stripes instead)."""
    w, h = 256, 32
    px = [0.0] * (w * h * 4)
    for y in range(h):
        for x in range(w):
            if y < 3 or y >= h - 3:
                c = (0.08, 0.08, 0.09, 1)
            elif ((x + y) // 16) % 2:
                c = (0.02, 0.02, 0.025, 1)
            else:
                c = (0.9, 0.55, 0.04, 1)
            i = ((h - 1 - y) * w + x) * 4
            px[i:i + 4] = c
    im = bpy.data.images.new('T_Rivet_Hazard', w, h)
    im.pixels = px
    im.filepath_raw = os.path.join(OUT, 'T_Rivet_Hazard.png'); im.file_format = 'PNG'; im.save()
    m = bpy.data.materials.new('M_Rivet_Hazard'); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    t = nt.nodes.new('ShaderNodeTexImage'); t.image = im
    nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.55
    return m


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


def round_uv(bm, side, cap=None, along=False, turn=0.0):
    """Anything round about Y: wrap `side` round it (the angle across the region,
    or along it with `along`, turned by `turn` radians), and map `cap` onto faces
    that look along Y."""
    uv = bm.loops.layers.uv.verify()
    ys = [v.co.y for v in bm.verts]
    y0, y1 = min(ys), max(ys)
    rmax = max(math.hypot(v.co.x, v.co.z) for v in bm.verts) or 1
    for f in bm.faces:
        if abs(f.normal.y) > 0.9 and cap:
            for l in f.loops:
                l[uv].uv = to_uv(*cap, 0.5 + 0.5 * l.vert.co.x / rmax, 0.5 - 0.5 * l.vert.co.z / rmax)
            continue
        angs = [(math.atan2(l.vert.co.z, l.vert.co.x) + turn + math.pi) % (2 * math.pi) - math.pi for l in f.loops]
        ref = angs[0]
        for l, a in zip(f.loops, angs):
            if a - ref > math.pi: a -= 2 * math.pi
            if ref - a > math.pi: a += 2 * math.pi
            t = (a + math.pi) / (2 * math.pi)
            s = (l.vert.co.y - y0) / max(y1 - y0, 1e-6)
            l[uv].uv = to_uv(*side, s, t) if along else to_uv(*side, t, s)


# ---------- parts ----------
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


def dark_box(name, size, loc, bevel=0.003, segs=1, rot=(0, 0, 0)):
    return box(name, size, loc, M_DARK, {'x': DARK, 'y': DARK, 'z': DARK}, bevel=bevel, segs=segs, rot=rot)


def lathe(name, prof, mat, side=None, loc=(0, 0, 0), segs=40, cap=None, along=False, turn=0.0, rot=(0, 0, 0), smooth=0.6):
    """Turns a profile of (radius, y) points round the Y axis. A profile that starts
    and ends on the axis closes into a solid, as does one whose ends meet."""
    bm = bmesh.new()
    closed = prof[0] == prof[-1]
    if closed:
        prof = prof[:-1]
    rings = []
    for r, y in prof:
        if r <= 1e-6:
            rings.append([bm.verts.new((0, y, 0))])
            continue
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            ring.append(bm.verts.new((r * math.cos(a), y, r * math.sin(a))))
        rings.append(ring)
    for p, q in zip(rings, rings[1:] + rings[:1] if closed else rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            if len(p) == 1:
                bm.faces.new((p[0], q[j], q[i]))
            elif len(q) == 1:
                bm.faces.new((p[i], p[j], q[0]))
            else:
                bm.faces.new((p[i], p[j], q[j], q[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    round_uv(bm, side or DARK, cap, along, turn)
    return finish(name, bm, mat, loc, rot, smooth)


def torus(name, major, minor, loc, mat, segs=40, sides=10, rot=(0, 0, 0)):
    """A ring round the Y axis."""
    bm = bmesh.new()
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
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    round_uv(bm, DARK)
    return finish(name, bm, mat, loc, rot, smooth=3.0)


def sweep(name, path, radius, mat, sides=10):
    """A tube along `path` (points), capped at both ends."""
    bm = bmesh.new()
    tangents = []
    for k, p in enumerate(path):
        a = path[max(k - 1, 0)]; b = path[min(k + 1, len(path) - 1)]
        tangents.append((b - a).normalized())
    t0 = tangents[0]
    n = t0.cross(Vector((0, 0, 1)))
    if n.length < 1e-4:
        n = t0.cross(Vector((1, 0, 0)))
    n.normalize()
    rings = []
    for k, (p, t) in enumerate(zip(path, tangents)):
        if k:  # parallel transport keeps the rings from twisting
            axis = tangents[k - 1].cross(t)
            if axis.length > 1e-6:
                n = Matrix.Rotation(tangents[k - 1].angle(t), 3, axis.normalized()) @ n
        b = t.cross(n).normalized()
        rings.append([bm.verts.new(p + (n * math.cos(2 * math.pi * i / sides) + b * math.sin(2 * math.pi * i / sides)) * radius)
                      for i in range(sides)])
    for p, q in zip(rings, rings[1:]):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((p[i], p[j], q[j], q[i]))
    for ring in (rings[0], rings[-1]):
        bm.faces.new(ring)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for l in f.loops:
            l[uv].uv = to_uv(*DARK, 0.5, 0.5)
    return finish(name, bm, mat, smooth=1.2)


def rivet_profile(head=0.009, shank=0.0028, length=0.04):
    """A domed head behind y = 0 on a shank along +Y."""
    dome = [(head * math.sin(math.radians(a)), -0.0065 + 0.0065 * (1 - math.cos(math.radians(a))) * 0.9) for a in (0, 30, 55, 75, 90)]
    return dome + [(head, 0.0), (shank, 0.0), (shank, length - 0.004), (shank * 0.6, length), (0.0, length)]


# Trim regions (image space).
SIDE_GREEBLE = (0.0, 0.605, 0.62, 0.80)     # Trim_02: buttons, grille, round hatch, amber light
BUTTONS = (0.0, 0.64, 0.19, 0.70)           # Trim_02: the dot grid, the amber lamp and a pad
PLAIN = (0.04, 0.28, 0.40, 0.50)             # Trim_02: plain panel with a seam
PISTON = (0.255, 0.27, 0.74, 0.555)         # Trim_02: panel with two slots, a band at the bottom (red on the red sheet)
HAZARD = (0.012, 0.792, 0.27, 0.822)         # Trim_02 (red): red and grey hazard stripes
X_PANEL = (0.79, 0.62, 0.995, 0.85)          # Trim_02: X-braced panel
VENTS = (0.25, 0.945, 0.35, 0.99)            # Trim_02: vertical slots
FRAMED = (0.02, 0.045, 0.245, 0.29)          # Trim_01: framed panel
SLOTS = (0.0, 0.475, 1.0, 0.50)              # Trim_01: band with a row of slots
RIBS = (0.0, 0.977, 1.0, 1.0)                # Trim_01: ribbed strip
SEAMS = (0.0, 0.40, 0.2, 0.47)               # Trim_01: plain band with seams
DARK = (0.1, 0.1, 0.6, 0.6)

GRIP_TILT = -16


def build_gun(body):
    # ---------- the piston ----------
    lathe('RearCap', [(0.0, -0.2), (0.03, -0.2), (0.041, -0.196), (0.047, -0.188), (0.049, -0.176), (0.049, -0.164), (0.0, -0.164)],
          M_DARK, segs=40)
    for k in range(6):  # exhaust ports round the rear cap
        a = 2 * math.pi * (k + 0.5) / 6
        box(f'Exhaust{k}', (0.014, 0.016, 0.006), (0.047 * math.cos(a), -0.183, 0.047 * math.sin(a)), body,
            {'x': PLAIN, 'y': PLAIN, 'z': VENTS}, bevel=0.002, segs=1, rot=(0, 90 - math.degrees(a), 0))
    # The piston's sheet has slots down its upper left and, on the red sheet, a red band at the front.
    piston = lathe('Piston', [(0.0, -0.168), (0.05, -0.168), (0.0505, -0.164), (0.0505, 0.02), (0.0, 0.02)],
                   body, PISTON, turn=math.radians(-135), segs=48)
    lathe('PistonFront', [(0.0, 0.016), (0.0505, 0.016), (0.0505, 0.058), (0.05, 0.062), (0.0, 0.062)], body, PLAIN, segs=48)
    red = body == M_RED
    lathe('HazardBand', [(0.049, 0.018), (0.0518, 0.018), (0.0522, 0.021), (0.0522, 0.045), (0.0518, 0.048), (0.049, 0.048), (0.049, 0.018)],
          M_RED if red else M_HAZARD, HAZARD if red else (0.0, 0.0, 1.0, 1.0), segs=48)
    lathe('Sleeve', [(0.0, 0.058), (0.046, 0.058), (0.046, 0.088), (0.04, 0.094), (0.0, 0.094)], M_PANEL, RIBS, segs=40)
    lathe('Neck', [(0.0, 0.09), (0.03, 0.09), (0.03, 0.098), (0.024, 0.101), (0.024, 0.124), (0.028, 0.128), (0.028, 0.132), (0.0, 0.132)],
          M_DARK, segs=32)
    # ---------- the nose plate (the anvil) ----------
    box('NosePlate', (0.088, 0.022, 0.084), (0, 0.14, 0.0), M_PANEL, {'x': SEAMS, 'y': FRAMED, 'z': SEAMS}, bevel=0.006, segs=2)
    lathe('Bore', [(0.0045, 0.149), (0.0105, 0.149), (0.0115, 0.1515), (0.0105, 0.1525), (0.0045, 0.1525), (0.0045, 0.149)], M_DARK, segs=24)
    lathe('BoreFloor', [(0.0, 0.1505), (0.005, 0.1505), (0.005, 0.1512), (0.0, 0.1512)], M_DARK, segs=12)
    for k, (x, z) in enumerate(((-0.031, -0.03), (0.031, -0.03), (-0.031, 0.03), (0.031, 0.03))):
        lathe(f'Bolt{k}', [(0.0, 0.149), (0.0055, 0.149), (0.0055, 0.1515), (0.0035, 0.1525), (0.0, 0.1525)], M_DARK, loc=(x, 0, z), segs=6)
    # ---------- the rivet strip on top ----------
    dark_box('ChannelFloor', (0.028, 0.2, 0.008), (0, -0.04, 0.052), bevel=0.002)
    for s in (-1, 1):
        box(f'ChannelWall{s}', (0.006, 0.2, 0.02), (s * 0.017, -0.04, 0.058), M_PANEL, {'x': SLOTS, 'y': SEAMS, 'z': SEAMS}, bevel=0.002, segs=2)
    box('Feed', (0.05, 0.05, 0.032), (0, 0.075, 0.056), body, {'x': VENTS, 'y': PLAIN, 'z': PLAIN}, bevel=0.006)
    dark_box('Strip', (0.016, 0.2, 0.003), (0, -0.045, 0.0575), bevel=0.0)
    for k in range(7):
        lathe(f'Rivet{k}', rivet_profile(head=0.0075, length=0.012), M_STEEL, loc=(0, -0.125 + k * 0.025, 0.0605), segs=14, rot=(-90, 0, 0))
    # ---------- the frame, grip and trigger ----------
    box('Frame', (0.054, 0.15, 0.03), (0, -0.105, -0.05), body, {'x': BUTTONS, 'y': PLAIN, 'z': PLAIN}, bevel=0.006)
    box('Valves', (0.02, 0.09, 0.05), (0.052, -0.07, 0.0), body, {'x': SIDE_GREEBLE, 'y': PLAIN, 'z': PLAIN}, bevel=0.005)
    box('Grip', (0.044, 0.066, 0.15), (0, -0.135, -0.135), M_RUBBER, {'x': DARK, 'y': DARK, 'z': DARK}, bevel=0.012, rot=(GRIP_TILT, 0, 0))
    tilt = Matrix.Rotation(math.radians(GRIP_TILT), 3, 'X')
    box('GripPlate', (0.048, 0.03, 0.12), Vector((0, -0.135, -0.135)) + tilt @ Vector((0, -0.024, 0.008)), body,
        {'x': X_PANEL, 'y': PLAIN, 'z': PLAIN}, bevel=0.005, rot=(GRIP_TILT, 0, 0))
    dark_box('Trigger', (0.018, 0.026, 0.058), (0, -0.068, -0.09), bevel=0.006, segs=2, rot=(14, 0, 0))
    dark_box('Guard', (0.016, 0.1, 0.01), (0, -0.06, -0.13))
    dark_box('GuardPost', (0.014, 0.01, 0.092), (0, -0.012, -0.089))
    # ---------- the air fitting and a stub of coiled hose ----------
    tilt = math.radians(GRIP_TILT)
    down = Vector((0, math.sin(tilt), -math.cos(tilt)))  # along the grip, out of its bottom
    base = Vector((0, -0.135, -0.135)) + down * 0.074
    spin = Matrix.Rotation(math.atan2(down.z, down.y), 4, 'X')  # +Y to `down`
    rot = [math.degrees(a) for a in spin.to_euler()]
    lathe('Nut', [(0.0, 0.0), (0.016, 0.0), (0.016, 0.01), (0.0, 0.01)], M_DARK, loc=base, segs=6, rot=rot, smooth=0.3)
    lathe('Coupler', [(0.0, 0.009), (0.011, 0.009), (0.011, 0.02), (0.0135, 0.022), (0.0135, 0.031), (0.009, 0.034), (0.0, 0.034)],
          M_DARK, loc=base, segs=24, rot=rot)
    m = Matrix.Translation(base) @ spin
    coil_r, pitch, turns = 0.012, 0.0105, 2.25
    path = [Vector((0, 0.03, 0)), Vector((0, 0.036, 0)), Vector((coil_r * 0.6, 0.039, 0))]
    n = int(turns * 20)
    for k in range(n + 1):
        a = 2 * math.pi * turns * k / n
        path.append(Vector((coil_r * math.cos(a), 0.041 + pitch * turns * k / n, coil_r * math.sin(a))))
    sweep('Hose', [m @ p for p in path], 0.0048, M_HOSE)
    # ---------- the status lamp ----------
    a = 125
    t = math.radians(a)
    dark_box('LampBase', (0.018, 0.026, 0.008), (0.051 * math.cos(t), -0.14, 0.051 * math.sin(t)), bevel=0.003, rot=(0, -(a - 90), 0))
    lathe('Lamp', [(0.0, 0.0), (0.0062, 0.0), (0.0058, 0.002), (0.004, 0.0045), (0.0, 0.0055)], M_GLOW,
          loc=(0.055 * math.cos(t), -0.14, 0.055 * math.sin(t)), segs=16, rot=(90, -(a - 90), 0))
    return piston


def join(root_name, active):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = active
    bpy.ops.object.join()
    active.name = root_name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    me = active.data
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    lo = [min(v.co[i] for v in me.vertices) for i in range(3)]
    hi = [max(v.co[i] for v in me.vertices) for i in range(3)]
    print(root_name, 'triangles', tris, 'materials', [m.name for m in me.materials])
    print(root_name, 'bounds', [round(x, 4) for x in lo], [round(x, 4) for x in hi])
    return active


def export(name):
    if os.environ.get('RIVET_BLEND'):
        os.makedirs(os.environ['RIVET_BLEND'], exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.environ['RIVET_BLEND'], name + '.blend'))
    path = os.path.join(OUT, name + '.gltf')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLTF_SEPARATE', use_selection=True, export_keep_originals=True)
    # Point the kit's textures at the kit, relative to the .gltf.
    with open(path) as f:
        doc = json.load(f)
    for im in doc.get('images', []):
        name = os.path.basename(im['uri'])
        if name.startswith('T_Rivet'):
            im['uri'] = name
        else:
            im['uri'] = os.path.relpath(os.path.join(TEX, name), OUT).replace(os.sep, '/')
    with open(path, 'w') as f:
        json.dump(doc, f, indent=2)


for name, red in (('rivet_gun', False), ('rivet_gun_red', True)):
    reset()
    gun = join('RivetGunRed' if red else 'RivetGun', build_gun(M_RED if red else M_PLAIN))
    muzzle = bpy.data.objects.new('Muzzle', None)
    muzzle.empty_display_size = 0.02
    muzzle.location = (0, 0.1525, 0)
    scene.collection.objects.link(muzzle)
    muzzle.parent = gun
    muzzle.select_set(True)
    print(name, 'muzzle', tuple(muzzle.location))
    export(name)

# A single rivet, for the ones stuck in walls.
reset()
join('Rivet', lathe('Rivet', rivet_profile(), M_STEEL, segs=16))
export('rivet')
print('done')
