extends RefCounted
## Medical's own fittings, which the kits don't have: hospital beds, drip
## stands and monitors, curtains, the surgery table and its lamp, the
## morgue's drawers and slabs, medicine shelves and the strip curtains at the
## quarantine doors. Built in code from boxes and cylinders, each piece one
## mesh with a surface per colour, and solid where it should block. Like the
## kit's models, each faces +z (yaw 0 faces south, 90 east).

const STEEL := Color(0.5, 0.53, 0.55)
const FRAME := Color(0.78, 0.8, 0.8)
const DARK := Color(0.09, 0.1, 0.11)
const MATTRESS := Color(0.55, 0.62, 0.66)
const SHEET := Color(0.8, 0.84, 0.84)
const BLANKET := Color(0.45, 0.62, 0.68)
const CURTAIN := Color(0.52, 0.68, 0.64)
const GLOW := Color(0.3, 0.95, 0.6)


## Boxes and cylinders gathered by colour, then made into one mesh with a
## surface per colour.
class Parts:
	var _by_mat := {}
	var _order: Array = []
	var _solid: Array = []

	func box(at: Vector3, size: Vector3, color: Color, rough := 0.7, rot := Vector3.ZERO, glow := 0.0) -> void:
		var m := BoxMesh.new()
		m.size = size
		_add(m, at, rot, color, rough, glow)

	func cyl(at: Vector3, radius: float, height: float, color: Color, rough := 0.6, rot := Vector3.ZERO, glow := 0.0, top := -1.0) -> void:
		var m := CylinderMesh.new()
		m.top_radius = radius if top < 0.0 else top
		m.bottom_radius = radius
		m.height = height
		m.radial_segments = 14
		m.rings = 1
		_add(m, at, rot, color, rough, glow)

	## A box of collision, in the piece's own space.
	func solid(center: Vector3, size: Vector3) -> void:
		_solid.append([center, size])

	func _add(mesh: Mesh, at: Vector3, rot: Vector3, color: Color, rough: float, glow: float) -> void:
		var mat := Kit.flat(color, rough, color if glow > 0.0 else Color.BLACK, glow)
		if not _by_mat.has(mat):
			_by_mat[mat] = []
			_order.append(mat)
		_by_mat[mat].append([mesh, Transform3D(Basis.from_euler(rot), at)])

	func build(parent: Node3D, name: String, pos: Vector3, yaw: float) -> Node3D:
		var am := ArrayMesh.new()
		for mat in _order:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for p in _by_mat[mat]:
				st.append_from(p[0], 0, p[1])
			st.commit(am)
			am.surface_set_material(am.get_surface_count() - 1, mat)
		var root: Node3D
		if _solid.is_empty():
			root = Node3D.new()
		else:
			var body := StaticBody3D.new()
			body.collision_layer = Kit.LAYER_STATION
			body.collision_mask = 0
			for s in _solid:
				var cs := CollisionShape3D.new()
				var shape := BoxShape3D.new()
				shape.size = s[1]
				cs.shape = shape
				cs.position = s[0]
				body.add_child(cs)
			root = body
		root.name = name
		root.position = pos
		root.rotation.y = yaw
		var mi := MeshInstance3D.new()
		mi.mesh = am
		root.add_child(mi)
		parent.add_child(root)
		return root


## A hospital bed 2.1 m long along its z, the head at -z. `made` beds have
## the blanket straight; others are thrown back. `stained` ones are bloody.
static func bed(parent: Node3D, pos: Vector3, yaw: float, seed := 0, made := true, stained := false) -> Node3D:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var p := Parts.new()
	p.box(Vector3(0, 0.42, 0), Vector3(0.92, 0.08, 2.0), FRAME, 0.4)
	for x in [-0.4, 0.4]:
		for z in [-0.9, 0.9]:
			p.box(Vector3(x, 0.22, z), Vector3(0.05, 0.36, 0.05), STEEL, 0.35)
			p.cyl(Vector3(x, 0.06, z), 0.06, 0.04, DARK, 0.6, Vector3(0, 0, PI * 0.5))
	p.box(Vector3(0, 0.75, -1.0), Vector3(0.95, 0.7, 0.05), FRAME, 0.4)
	p.box(Vector3(0, 0.62, 1.0), Vector3(0.95, 0.42, 0.05), FRAME, 0.4)
	# The mattress: the head end raised.
	p.box(Vector3(0, 0.53, 0.3), Vector3(0.86, 0.14, 1.3), MATTRESS, 0.9)
	p.box(Vector3(0, 0.7, -0.6), Vector3(0.86, 0.14, 0.72), MATTRESS, 0.9, Vector3(0.45, 0, 0))
	p.box(Vector3(0, 0.88, -0.78), Vector3(0.55, 0.1, 0.32), SHEET, 0.95, Vector3(0.45, r.randf_range(-0.15, 0.15), 0))
	if made:
		p.box(Vector3(0, 0.62, 0.3), Vector3(0.9, 0.05, 1.3), BLANKET, 0.95)
	else:
		p.box(Vector3(0.1, 0.64, 0.75), Vector3(0.9, 0.1, 0.55), BLANKET, 0.95, Vector3(r.randf_range(-0.2, 0.2), r.randf_range(-0.3, 0.3), 0))
		p.box(Vector3(0, 0.605, 0.0), Vector3(0.84, 0.02, 1.1), SHEET, 0.95)
	if stained:
		p.box(Vector3(r.randf_range(-0.15, 0.15), 0.63, r.randf_range(-0.3, 0.2)), Vector3(0.45, 0.012, 0.6), Color(0.3, 0.02, 0.02), 0.3, Vector3(0, r.randf(), 0))
	# Side rails.
	for x in [-0.47, 0.47]:
		p.box(Vector3(x, 0.72, -0.2), Vector3(0.03, 0.03, 1.1), STEEL, 0.35)
		for z in [-0.7, 0.3]:
			p.box(Vector3(x, 0.6, z), Vector3(0.03, 0.24, 0.03), STEEL, 0.35)
	p.solid(Vector3(0, 0.55, 0), Vector3(0.95, 1.1, 2.1))
	return p.build(parent, "Bed", pos, yaw)


## A drip stand with its bag.
static func drip(parent: Node3D, pos: Vector3, seed := 0) -> Node3D:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var p := Parts.new()
	for a in [0.0, PI * 0.4, PI * 0.8, PI * 1.2, PI * 1.6]:
		p.box(Vector3(cos(a) * 0.15, 0.04, sin(a) * 0.15), Vector3(0.3, 0.03, 0.03), STEEL, 0.35, Vector3(0, -a, 0))
	p.cyl(Vector3(0, 0.95, 0), 0.015, 1.9, STEEL, 0.3)
	p.box(Vector3(0, 1.88, 0), Vector3(0.3, 0.02, 0.02), STEEL, 0.3)
	var bag := Color(0.85, 0.8, 0.5, 0.55) if r.randf() < 0.6 else Color(0.5, 0.05, 0.05, 0.75)
	p.box(Vector3(0.12, 1.72, 0), Vector3(0.12, 0.22, 0.04), bag, 0.2)
	p.box(Vector3(0.12, 1.2, 0.02), Vector3(0.01, 0.8, 0.01), Color(0.9, 0.9, 0.9, 0.6), 0.2)
	p.solid(Vector3(0, 0.95, 0), Vector3(0.3, 1.9, 0.3))
	return p.build(parent, "Drip", pos, r.randf() * TAU)


## A monitor on a stand, its screen to +z, showing a flat line or a pulse.
static func monitor(parent: Node3D, pos: Vector3, yaw: float, alive := false) -> Node3D:
	var p := Parts.new()
	p.box(Vector3(0, 0.03, 0), Vector3(0.45, 0.06, 0.45), STEEL, 0.4)
	p.box(Vector3(0, 0.7, 0), Vector3(0.05, 1.3, 0.05), STEEL, 0.35)
	p.box(Vector3(0, 1.45, 0), Vector3(0.5, 0.38, 0.12), DARK, 0.4)
	p.box(Vector3(0, 1.45, 0.061), Vector3(0.44, 0.3, 0.005), Color(0.02, 0.05, 0.04), 0.2)
	var line := Color(1.0, 0.25, 0.2) if not alive else GLOW
	p.box(Vector3(0, 1.43, 0.065), Vector3(0.4, 0.01, 0.004), line, 0.4, Vector3.ZERO, 3.0)
	if alive:
		p.box(Vector3(0.05, 1.47, 0.065), Vector3(0.01, 0.1, 0.004), line, 0.4, Vector3(0, 0, 0.4), 3.0)
	p.solid(Vector3(0, 0.75, 0), Vector3(0.5, 1.5, 0.45))
	return p.build(parent, "Monitor", pos, yaw)


## A curtain on a ceiling rail, `length` along its x, part drawn.
static func curtain(parent: Node3D, pos: Vector3, yaw: float, length := 2.4, drawn := 0.6, seed := 0) -> Node3D:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var p := Parts.new()
	p.box(Vector3(0, 2.45, 0), Vector3(length, 0.04, 0.04), STEEL, 0.35)
	for side in [-1.0, 1.0]:
		p.box(Vector3(side * length * 0.5, 3.75, 0), Vector3(0.02, 2.6, 0.02), STEEL, 0.35)
	# Pleats, bunched up at one end.
	var span := length * drawn
	var n := int(span / 0.22) + 1
	for i in n:
		var x := -length * 0.5 + 0.1 + i * span / maxf(1, n)
		p.box(Vector3(x, 1.4, (0.05 if i % 2 == 0 else -0.05)), Vector3(0.24, 2.0, 0.02), CURTAIN, 0.95, Vector3(0, (0.45 if i % 2 == 0 else -0.45) + r.randf_range(-0.1, 0.1), 0))
	return p.build(parent, "Curtain", pos, yaw)


## The surgery table under its lamp, and a tray of instruments beside it.
static func surgery_table(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var p := Parts.new()
	p.box(Vector3(0, 0.05, 0), Vector3(0.7, 0.1, 1.0), STEEL, 0.35)
	p.box(Vector3(0, 0.45, 0), Vector3(0.3, 0.8, 0.4), STEEL, 0.35)
	p.box(Vector3(0, 0.88, 0), Vector3(0.6, 0.08, 2.0), Color(0.2, 0.32, 0.36), 0.6)
	p.box(Vector3(0, 0.93, -0.8), Vector3(0.4, 0.06, 0.25), Color(0.25, 0.38, 0.42), 0.7)
	p.box(Vector3(0.1, 0.925, 0.2), Vector3(0.35, 0.01, 0.7), Color(0.32, 0.02, 0.03), 0.25, Vector3(0, 0.4, 0))
	# The lamp: a ring on an arm from the ceiling.
	p.box(Vector3(0, 4.0, 0), Vector3(0.06, 2.0, 0.06), STEEL, 0.35)
	p.box(Vector3(0, 3.0, 0.3), Vector3(0.06, 0.06, 0.6), STEEL, 0.35)
	p.cyl(Vector3(0, 2.9, 0.6), 0.42, 0.14, FRAME, 0.35)
	p.cyl(Vector3(0, 2.82, 0.6), 0.36, 0.02, Color(1.0, 0.98, 0.9), 0.3, Vector3.ZERO, 2.5)
	# The instrument tray.
	p.box(Vector3(0.75, 0.5, 0.4), Vector3(0.04, 1.0, 0.04), STEEL, 0.35)
	p.box(Vector3(0.75, 1.0, 0.4), Vector3(0.5, 0.03, 0.35), STEEL.lightened(0.2), 0.25)
	for i in 5:
		p.box(Vector3(0.6 + i * 0.07, 1.02, 0.4), Vector3(0.015, 0.01, 0.2), Color(0.85, 0.87, 0.9), 0.15)
	p.solid(Vector3(0, 0.47, 0), Vector3(0.62, 0.94, 2.0))
	return p.build(parent, "SurgeryTable", pos, yaw)


## A wall of morgue drawers, `cols` wide and three high, the doors to +z.
## `open` drawers are pulled out on their trays (by index, left to right,
## bottom up); `covered` ones have a shape under a sheet.
static func drawers(parent: Node3D, pos: Vector3, yaw: float, cols := 3, open: Array = [], covered: Array = []) -> Node3D:
	var p := Parts.new()
	var w := cols * 0.8
	p.box(Vector3(0, 1.2, -0.05), Vector3(w + 0.1, 2.4, 0.9), STEEL.darkened(0.2), 0.4)
	for c in cols:
		for row in 3:
			var i := row * cols + c
			var at := Vector3(-w * 0.5 + 0.4 + c * 0.8, 0.45 + row * 0.75, 0.405)
			if i in open:
				p.box(at + Vector3(0, 0, 0.0), Vector3(0.66, 0.6, 0.01), DARK, 0.6)
				p.box(at + Vector3(0, -0.22, 0.95), Vector3(0.62, 0.04, 1.9), STEEL.lightened(0.15), 0.3)
				if i in covered:
					p.box(at + Vector3(0, -0.12, 1.0), Vector3(0.5, 0.18, 1.7), SHEET, 0.95)
					p.box(at + Vector3(0, -0.08, 0.25), Vector3(0.24, 0.2, 0.26), SHEET, 0.95)
			else:
				p.box(at, Vector3(0.68, 0.62, 0.02), STEEL.lightened(0.1), 0.3)
				p.box(at + Vector3(0, 0.18, 0.03), Vector3(0.24, 0.04, 0.04), FRAME, 0.25)
				p.box(at + Vector3(-0.2, -0.18, 0.015), Vector3(0.16, 0.08, 0.005), Color(0.9, 0.9, 0.85), 0.8)
	p.solid(Vector3(0, 1.2, -0.05), Vector3(w + 0.1, 2.4, 0.9))
	return p.build(parent, "Drawers", pos, yaw)


## A steel slab with a drain; `covered` has a body-shaped sheet on it.
static func slab(parent: Node3D, pos: Vector3, yaw: float, covered := false) -> Node3D:
	var p := Parts.new()
	p.box(Vector3(0, 0.4, 0), Vector3(0.25, 0.8, 0.25), STEEL, 0.35)
	p.box(Vector3(0, 0.84, 0), Vector3(0.75, 0.06, 2.0), STEEL.lightened(0.2), 0.25)
	p.box(Vector3(0, 0.875, 0.95), Vector3(0.75, 0.02, 0.06), STEEL, 0.3)
	p.cyl(Vector3(0, 0.872, 0.85), 0.05, 0.01, DARK, 0.5)
	if covered:
		p.box(Vector3(0, 0.95, 0.15), Vector3(0.5, 0.18, 1.5), SHEET, 0.95)
		p.box(Vector3(0, 0.98, -0.75), Vector3(0.24, 0.22, 0.26), SHEET, 0.95)
		p.box(Vector3(0.05, 1.04, -0.1), Vector3(0.3, 0.06, 0.4), SHEET.darkened(0.08), 0.95)
		p.box(Vector3(0.0, 1.0, -0.2), Vector3(0.2, 0.01, 0.3), Color(0.35, 0.04, 0.04), 0.4)
	p.solid(Vector3(0, 0.45, 0), Vector3(0.75, 0.9, 2.0))
	return p.build(parent, "Slab", pos, yaw)


## A medicine cabinet: shelves of boxes and bottles, `length` along its x,
## the front to +z.
static func med_shelves(parent: Node3D, pos: Vector3, yaw: float, length := 1.8, seed := 0, emptied := false) -> Node3D:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var p := Parts.new()
	p.box(Vector3(0, 1.1, -0.2), Vector3(length, 2.2, 0.03), FRAME.darkened(0.15), 0.4)
	for x in [-length * 0.5, length * 0.5]:
		p.box(Vector3(x, 1.1, 0), Vector3(0.03, 2.2, 0.42), FRAME, 0.4)
	for k in 5:
		var y := 0.1 + k * 0.48
		p.box(Vector3(0, y, 0), Vector3(length, 0.03, 0.42), FRAME, 0.4)
		if k == 4:
			continue
		var x := -length * 0.5 + 0.08
		while x < length * 0.5 - 0.12:
			var bw := r.randf_range(0.08, 0.2)
			if r.randf() < (0.55 if emptied else 0.12):
				x += bw + 0.03
				continue
			var bh := r.randf_range(0.1, 0.3)
			var col: Color = [Color(0.9, 0.9, 0.88), Color(0.85, 0.85, 0.8), Color(0.3, 0.55, 0.75), Color(0.75, 0.3, 0.25), Color(0.85, 0.7, 0.3)][r.randi() % 5]
			if r.randf() < 0.3:
				p.cyl(Vector3(x + bw * 0.5, y + 0.015 + bh * 0.5, r.randf_range(-0.08, 0.08)), bw * 0.4, bh, col, 0.4)
			else:
				p.box(Vector3(x + bw * 0.5, y + 0.015 + bh * 0.5, r.randf_range(-0.06, 0.06)), Vector3(bw, bh, r.randf_range(0.15, 0.3)), col, 0.7)
			x += bw + 0.03
	p.solid(Vector3(0, 1.1, 0), Vector3(length, 2.2, 0.44))
	return p.build(parent, "MedShelves", pos, yaw)


## Strips of heavy plastic hanging across a doorway, `width` along its x.
static func strips(parent: Node3D, pos: Vector3, yaw: float, width := 3.6) -> Node3D:
	var p := Parts.new()
	p.box(Vector3(0, 3.9, 0), Vector3(width, 0.06, 0.06), STEEL, 0.35)
	var n := int(width / 0.3)
	for i in n:
		p.box(Vector3(-width * 0.5 + 0.15 + i * 0.3, 2.0, (i % 2) * 0.02), Vector3(0.28, 3.8, 0.01), Color(0.75, 0.85, 0.85, 0.35), 0.15)
	return p.build(parent, "Strips", pos, yaw)


## A wheeled screen of pale panels, the kind put round a bed in triage.
static func screen(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var p := Parts.new()
	for i in 3:
		var a := (i - 1) * 0.35
		var at := Vector3(sin(a) * 0.65 * (i - 1), 0.95, -absf(i - 1) * 0.2)
		p.box(at, Vector3(0.7, 1.6, 0.03), CURTAIN.lightened(0.2), 0.9, Vector3(0, -a, 0))
		p.box(at + Vector3(0, -0.85, 0), Vector3(0.7, 0.03, 0.06), STEEL, 0.35, Vector3(0, -a, 0))
	p.solid(Vector3(0, 0.95, -0.1), Vector3(2.0, 1.9, 0.35))
	return p.build(parent, "Screen", pos, yaw)
