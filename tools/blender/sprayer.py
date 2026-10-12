"""Builds Verdigris Protocol's cryo sprayer in Blender from the Modular Sci-Fi MegaKit's trim sheets.

Run: blender-venv/bin/python sprayer.py <textures dir> <out dir>
Writes sprayer.gltf, sprayer.bin and T_Sprayer_Screen.png into <out dir>; the kit's
textures are referenced where they are (relative to <out dir>), not copied.
A .blend goes to the folder in $SPRAYER_BLEND when that's set.
Axes: the nozzle points +Y in Blender, which is -Z (forward) in Godot. The `Muzzle`
empty sits at the centre of the bell's mouth.
"""
import bpy, bmesh, math, sys, os, json, random
from mathutils import Vector, Matrix

TEX, OUT = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
random.seed(7)


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


def flat(name, color, rough=0.5, metal=0.0, emit=None, strength=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1)
        b.inputs['Emission Strength'].default_value = strength
    if alpha < 1:
        b.inputs['Alpha'].default_value = alpha
        m.surface_render_method = 'BLENDED'
    return m


M_BODY = trim('MI_Trim_02_Blue', 'T_Trim_02_BaseColor_Blue.png', 'T_Trim_02_Normal.png', 'T_Trim_02_ORM.png')
M_HAZARD = trim('MI_Trim_02_Red', 'T_Trim_02_BaseColor_Red.png', 'T_Trim_02_Normal.png', 'T_Trim_02_ORM.png')
M_PANEL = trim('MI_Trim_01', 'T_Trim_01_BaseColor.png', 'T_Trim_01_Normal.png', 'T_Trim_01_ORM.png')
M_DARK = trim('MI_Trim_03_Dark', 'T_Trim_03_Cables.png', 'T_Trim_03_Normal.png', 'T_Trim_03_ORM.png')
M_GLOW = flat('M_Sprayer_Glow', (0.55, 0.92, 1.0), emit=(0.45, 0.88, 1.0), strength=1.6)
M_COOLANT = flat('M_Sprayer_Coolant', (0.5, 0.86, 1.0), rough=0.2, emit=(0.4, 0.8, 1.0), strength=0.9)
M_GLASS = flat('M_Sprayer_Glass', (0.6, 0.8, 0.9), rough=0.04, alpha=0.22)
M_FROST = flat('M_Sprayer_Frost', (0.72, 0.82, 0.88), rough=1.0)
M_RUBBER = flat('M_Sprayer_Grip', (0.025, 0.027, 0.03), rough=0.85)


def screen_material():
    """The pressure readout: a small texture drawn here, shown as both colour and glow."""
    w, h = 256, 160
    px = [0.0] * (w * h * 4)
    def rect(x0, y0, x1, y1, c):
        for y in range(y0, y1):
            for x in range(x0, x1):
                i = ((h - 1 - y) * w + x) * 4
                px[i:i + 4] = c
    rect(0, 0, w, h, (0.005, 0.02, 0.03, 1))
    rect(8, 8, w - 8, 12, (0.1, 0.5, 0.7, 1)); rect(8, h - 12, w - 8, h - 8, (0.1, 0.5, 0.7, 1))
    for k in range(10):  # pressure bars, all lit, rising left to right
        top = 120 - 7 * k
        rect(24 + k * 21, top, 24 + k * 21 + 15, 132, (0.35, 0.85, 1.0, 1))
    rect(20, 136, w - 20, 139, (0.2, 0.6, 0.8, 1))
    im = bpy.data.images.new('T_Sprayer_Screen', w, h)
    im.pixels = px
    im.filepath_raw = os.path.join(OUT, 'T_Sprayer_Screen.png'); im.file_format = 'PNG'; im.save()
    m = bpy.data.materials.new('M_Sprayer_Screen'); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    t = nt.nodes.new('ShaderNodeTexImage'); t.image = im
    nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    nt.links.new(t.outputs['Color'], b.inputs['Emission Color'])
    b.inputs['Emission Strength'].default_value = 2.0
    b.inputs['Roughness'].default_value = 0.15
    return m


M_SCREEN = screen_material()


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


def round_uv(bm, side, cap=None, along=False):
    """Anything round about Y: wrap `side` round it (the angle across the region,
    or along it with `along`), and map `cap` onto faces that look along Y."""
    uv = bm.loops.layers.uv.verify()
    ys = [v.co.y for v in bm.verts]
    y0, y1 = min(ys), max(ys)
    rmax = max(math.hypot(v.co.x, v.co.z) for v in bm.verts) or 1
    for f in bm.faces:
        if abs(f.normal.y) > 0.9 and cap:
            for l in f.loops:
                l[uv].uv = to_uv(*cap, 0.5 + 0.5 * l.vert.co.x / rmax, 0.5 - 0.5 * l.vert.co.z / rmax)
            continue
        angs = [math.atan2(l.vert.co.z, l.vert.co.x) for l in f.loops]
        ref = angs[0]
        for l, a in zip(f.loops, angs):
            if a - ref > math.pi: a -= 2 * math.pi
            if ref - a > math.pi: a += 2 * math.pi
            t = (a + math.pi) / (2 * math.pi)
            s = (l.vert.co.y - y0) / max(y1 - y0, 1e-6)
            l[uv].uv = to_uv(*side, s, t) if along else to_uv(*side, t, s)


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


def dark_box(name, size, loc, bevel=0.003, segs=1, rot=(0, 0, 0)):
    return box(name, size, loc, M_DARK, {'x': DARK, 'y': DARK, 'z': DARK}, bevel=bevel, segs=segs, rot=rot)


def tube(name, r1, r2, length, loc, mat, side, cap=None, segs=40, bevel=0.0, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=length)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-90), 3, 'X'))
    if bevel:
        rims = [e for e in bm.edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.y - e.link_faces[1].normal.y) > 0.5]
        bmesh.ops.bevel(bm, geom=rims, offset=bevel, segments=2, affect='EDGES', profile=0.5, clamp_overlap=True)
    bm.normal_update()
    round_uv(bm, side, cap)
    return finish(name, bm, mat, loc, rot)


def lathe(name, prof, mat, side=None, loc=(0, 0, 0), segs=40, cap=None, along=False, jitter=0.0, rot=(0, 0, 0), smooth=0.6):
    """Turns a profile of (radius, y) points round the Y axis. A profile that starts
    and ends on the axis closes into a solid; `jitter` roughens the outside (frost)."""
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
            rr = r + (random.uniform(-jitter, jitter) if jitter else 0.0)
            ring.append(bm.verts.new((rr * math.cos(a), y, rr * math.sin(a))))
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
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    round_uv(bm, side or DARK, cap, along)
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


def bezier(p0, p1, p2, p3, n):
    pts = []
    for k in range(n + 1):
        t = k / n
        u = 1 - t
        pts.append(p0 * u ** 3 + p1 * 3 * u * u * t + p2 * 3 * u * t * t + p3 * t ** 3)
    return pts


def sweep(name, path, radius, mat, sides=12, ribs=0.0, rib_len=0.008):
    """A tube along `path` (points), ribbed like a corrugated hose when `ribs` > 0."""
    bm = bmesh.new()
    tangents = []
    for k, p in enumerate(path):
        a = path[max(k - 1, 0)]; b = path[min(k + 1, len(path) - 1)]
        tangents.append((b - a).normalized())
    # Parallel transport keeps the rings from twisting.
    t0 = tangents[0]
    n = t0.cross(Vector((0, 0, 1)))
    if n.length < 1e-4:
        n = t0.cross(Vector((1, 0, 0)))
    n.normalize()
    rings = []
    s = 0.0
    for k, (p, t) in enumerate(zip(path, tangents)):
        if k:
            s += (p - path[k - 1]).length
            axis = tangents[k - 1].cross(t)
            if axis.length > 1e-6:
                ang = tangents[k - 1].angle(t)
                n = Matrix.Rotation(ang, 3, axis.normalized()) @ n
        b = t.cross(n).normalized()
        r = radius * (1 + ribs * math.cos(2 * math.pi * s / rib_len)) if ribs else radius
        ring = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            ring.append(bm.verts.new(p + (n * math.cos(a) + b * math.sin(a)) * r))
        rings.append(ring)
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


# Trim regions (image space).
SIDE_GREEBLE = (0.0, 0.605, 0.62, 0.80)     # Trim_02: buttons, grille, round hatch, amber light
PLAIN = (0.04, 0.28, 0.40, 0.50)             # Trim_02: plain panel with a seam
BRACKETS = (0.18, 0.035, 0.92, 0.245)        # Trim_02: panel strip with brackets
HAZARD = (0.012, 0.792, 0.27, 0.822)         # Trim_02 (red): red and grey hazard stripes
HATCH = (0.525, 0.715, 0.635, 0.825)         # Trim_02: round hatch, for end caps
X_PANEL = (0.79, 0.62, 0.995, 0.85)          # Trim_02: X-braced panel
VENTS = (0.25, 0.945, 0.35, 0.99)            # Trim_02: vertical slots
FRAMED = (0.02, 0.045, 0.245, 0.29)          # Trim_01: framed panel
SLOTS = (0.0, 0.475, 1.0, 0.50)              # Trim_01: band with a row of slots
RIVETS = (0.0, 0.43, 1.0, 0.47)              # Trim_01: riveted band
RIBS = (0.0, 0.977, 1.0, 1.0)                # Trim_01: ribbed strip
SEAMS = (0.0, 0.40, 0.2, 0.47)               # Trim_01: plain band with seams
DARK = (0.1, 0.1, 0.6, 0.6)

# ---------- the body ----------
body = box('Body', (0.11, 0.34, 0.12), (0, -0.04, 0.0), M_BODY,
           {'x': SIDE_GREEBLE, 'y': X_PANEL, 'z': PLAIN}, bevel=0.012, taper=(0.9, 0.85, -0.004))
box('Housing', (0.084, 0.24, 0.04), (0, -0.07, 0.078), M_PANEL, {'x': SLOTS, 'y': FRAMED, 'z': FRAMED}, bevel=0.008)
box('HazardRail', (0.03, 0.2, 0.012), (0, -0.07, 0.103), M_HAZARD, {'x': HAZARD, 'y': HAZARD, 'z': HAZARD}, bevel=0.003, segs=2)
dark_box('Underplate', (0.12, 0.2, 0.02), (0, -0.06, -0.068), bevel=0.006, segs=3)
box('SidePlate', (0.008, 0.15, 0.07), (0.057, -0.07, -0.004), M_PANEL, {'x': FRAMED, 'y': SEAMS, 'z': SEAMS}, bevel=0.003, segs=2)

# ---------- the coolant canister, slung low on the left ----------
CX, CZ = -0.106, -0.036
cdome = lambda y0, y1, sgn: [(0.044 * math.sin(math.radians(a)), y0 + sgn * (y1 - y0) * (1 - math.cos(math.radians(a)))) for a in (0, 25, 45, 65, 80, 90)]
lathe('CanRear', cdome(-0.175, -0.145, 1) + [(0.044, -0.118), (0.0, -0.118)], M_PANEL, RIVETS, loc=(CX, 0, CZ), segs=36)
lathe('CanFront', [(0.0, 0.05), (0.044, 0.05)] + list(reversed(cdome(0.112, 0.082, -1))), M_PANEL, RIVETS, loc=(CX, 0, CZ), segs=36)
lathe('CanGlass', [(0.0, -0.121), (0.0425, -0.121), (0.0425, 0.053), (0.0, 0.053)], M_GLASS, loc=(CX, 0, CZ), segs=36)
lathe('CanCore', [(0.0, -0.12), (0.032, -0.12), (0.032, 0.052), (0.0, 0.052)], M_COOLANT, loc=(CX, 0, CZ), segs=24)
for k, (y0, y1) in enumerate(((-0.132, -0.11), (0.046, 0.068))):
    lathe(f'CanFrost{k}', [(0.039, y0), (0.0462, y0 - 0.002), (0.0475, (y0 + y1) / 2), (0.0462, y1 + 0.002), (0.039, y1)] + [(0.039, y0)],
          M_FROST, loc=(CX, 0, CZ), segs=36, jitter=0.0018)
for k, a in enumerate((35, 145, 215)):  # guard bars over the window
    t = math.radians(a)
    dark_box(f'CanBar{k}', (0.005, 0.17, 0.005), (CX + 0.045 * math.cos(t), -0.035, CZ + 0.045 * math.sin(t)), bevel=0.0015, rot=(0, -a, 0))
lathe('CanNeck', [(0.0, 0.106), (0.012, 0.106), (0.012, 0.124), (0.009, 0.128), (0.0, 0.128)], M_DARK, loc=(CX, 0, CZ), segs=20)
torus('ValveWheel', 0.016, 0.0028, (CX, 0.118, CZ), M_DARK, segs=24, sides=8)
for k, a in enumerate((0, 90)):
    dark_box(f'ValveSpoke{k}', (0.032, 0.003, 0.003), (CX, 0.118, CZ), bevel=0.0, rot=(0, a, 0))
for y in (-0.121, 0.057):
    dark_box(f'CanClamp{y}', (0.03, 0.02, 0.05), (-0.064, y, CZ + 0.006), bevel=0.003)

# ---------- the lance and the bell ----------
tube('Collar', 0.042, 0.036, 0.1, (0, 0.17, 0.0), M_PANEL, RIVETS, cap=HATCH, bevel=0.005)
tube('Lance', 0.015, 0.015, 0.27, (0, 0.345, 0.0), M_BODY, BRACKETS, segs=24)
lathe('PortClamp', [(0.014, 0.252), (0.021, 0.252), (0.023, 0.258), (0.023, 0.282), (0.021, 0.288), (0.014, 0.288)] + [(0.014, 0.252)],
      M_DARK, segs=28)
tube('Port', 0.009, 0.009, 0.02, (-0.028, 0.27, 0.0), M_DARK, DARK, segs=16, rot=(0, 0, 90))
lathe('LanceFrost', [(0.014, 0.36), (0.0172, 0.358), (0.0182, 0.37), (0.0172, 0.382), (0.014, 0.38)] + [(0.014, 0.36)],
      M_FROST, segs=24, jitter=0.0008)
lathe('LanceRing', [(0.014, 0.43), (0.02, 0.43), (0.021, 0.436), (0.021, 0.448), (0.02, 0.454), (0.014, 0.454)] + [(0.014, 0.43)],
      M_DARK, segs=28)
BELL = [(0.0, 0.488), (0.032, 0.488), (0.034, 0.50), (0.038, 0.515), (0.044, 0.533), (0.049, 0.548), (0.052, 0.558),
        (0.055, 0.5615), (0.058, 0.559), (0.058, 0.553), (0.054, 0.535), (0.047, 0.512), (0.038, 0.488), (0.026, 0.47),
        (0.017, 0.461), (0.0, 0.461)]
lathe('Bell', BELL, M_PANEL, SEAMS, segs=48, smooth=0.5)
lathe('BellFrost', [(0.0565, 0.546), (0.0588, 0.548), (0.0594, 0.551), (0.0588, 0.554), (0.0574, 0.555), (0.0565, 0.546)],
      M_FROST, segs=48, jitter=0.0009)
lathe('JetPlate', [(0.0, 0.4895), (0.031, 0.4895), (0.031, 0.491), (0.0, 0.491)], M_DARK, segs=40)
for k in range(8):  # the jets, angled out a little to fan the spray
    a = 2 * math.pi * k / 8
    ob = lathe(f'Jet{k}', [(0.0, 0.0), (0.0042, 0.0), (0.0042, 0.006), (0.0032, 0.011), (0.002, 0.011), (0.002, 0.009), (0.0, 0.009)], M_DARK, segs=10)
    ob.location = (0.019 * math.cos(a), 0.4905, 0.019 * math.sin(a))
    ob.rotation_euler = (Matrix.Rotation(-a, 3, 'Y') @ Matrix.Rotation(math.radians(-14), 3, 'Z')).to_euler()
lathe('CentreJet', [(0.0, 0.49), (0.008, 0.49), (0.0075, 0.5), (0.005, 0.508), (0.0, 0.508)], M_DARK, segs=20)
lathe('CentreJetTip', [(0.0, 0.5075), (0.003, 0.5075), (0.0, 0.5095)], M_GLOW, segs=12)
torus('GlowRing', 0.0378, 0.0026, (0, 0.522, 0), M_GLOW, segs=48, sides=8)

# ---------- the hose from the canister's valve to the lance ----------
p0 = Vector((CX, 0.128, CZ)); p3 = Vector((-0.038, 0.27, 0.0))
sweep('Hose', bezier(p0, p0 + Vector((0, 0.075, 0.0)), p3 + Vector((-0.06, 0.0, 0.0)), p3, 36), 0.0085, M_RUBBER, ribs=0.12, rib_len=0.009)

# ---------- grip, trigger, foregrip ----------
box('Grip', (0.042, 0.07, 0.17), (0, -0.13, -0.14), M_RUBBER, {'x': DARK, 'y': DARK, 'z': DARK}, bevel=0.012, rot=(-16, 0, 0))
dark_box('Trigger', (0.012, 0.016, 0.038), (0, -0.065, -0.095), rot=(12, 0, 0))
dark_box('Guard', (0.016, 0.11, 0.01), (0, -0.065, -0.125))
dark_box('GuardPost', (0.014, 0.01, 0.05), (0, -0.014, -0.1))
dark_box('ForegripMount', (0.05, 0.05, 0.022), (0, 0.17, -0.04), bevel=0.004, segs=2)
tube('Foregrip', 0.021, 0.019, 0.1, (0, 0.17, -0.1), M_RUBBER, DARK, segs=24, bevel=0.005, rot=(90, 0, 0))

# ---------- the pressure readout at the back ----------
# It faces back and up, at the tech; the frame sits in front of it.
box('Screen', (0.072, 0.01, 0.045), (0, -0.203, 0.108), M_SCREEN, {'x': (0, 0, 0.03, 0.03), 'y': (0, 0, 1, 1), 'z': (0, 0, 0.03, 0.03)}, bevel=0.002, segs=1, rot=(-28, 0, 0))
dark_box('ScreenFrame', (0.084, 0.012, 0.057), (0, -0.197, 0.106), rot=(-28, 0, 0))

# One object, ready for a game, with the muzzle marked.
bpy.ops.object.select_all(action='DESELECT')
for ob in parts:
    ob.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body.name = 'CryoSprayer'
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
muzzle = bpy.data.objects.new('Muzzle', None)
muzzle.empty_display_size = 0.02
muzzle.location = (0, 0.5615, 0)
scene.collection.objects.link(muzzle)
muzzle.parent = body
muzzle.select_set(True)
tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
print('triangles', tris, 'materials', [m.name for m in body.data.materials])
lo = [min(v.co[i] for v in body.data.vertices) for i in range(3)]
hi = [max(v.co[i] for v in body.data.vertices) for i in range(3)]
print('bounds', [round(x, 4) for x in lo], [round(x, 4) for x in hi], 'muzzle', tuple(muzzle.location))

if os.environ.get('SPRAYER_BLEND'):
    os.makedirs(os.environ['SPRAYER_BLEND'], exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.environ['SPRAYER_BLEND'], 'sprayer.blend'))
path = os.path.join(OUT, 'sprayer.gltf')
bpy.ops.export_scene.gltf(filepath=path, export_format='GLTF_SEPARATE', use_selection=True, export_keep_originals=True)
# Point the kit's textures at the kit, relative to the .gltf.
with open(path) as f:
    doc = json.load(f)
for im in doc.get('images', []):
    name = os.path.basename(im['uri'])
    if os.path.exists(os.path.join(TEX, name)) and not name.startswith('T_Sprayer'):
        im['uri'] = os.path.relpath(os.path.join(TEX, name), OUT).replace(os.sep, '/')
    elif os.path.exists(os.path.join(OUT, name)):
        im['uri'] = name
with open(path, 'w') as f:
    json.dump(doc, f, indent=2)
print('done')
