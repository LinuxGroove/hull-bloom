extends RefCounted
## Crew quarters' own fittings, which the kits don't have: bunks, shower
## stalls, washers and dryers, mess tables, galley counters, pews, a sofa and
## a little gym. Built in code from boxes and cylinders, each piece one mesh
## with a surface per colour, and solid where it should block. Like the
## kit's models, each faces +z (yaw 0 faces south, 90 east).

const STEEL := Color(0.32, 0.34, 0.36)
const DARK := Color(0.09, 0.1, 0.11)
const CHROME := Color(0.62, 0.64, 0.66)
const WHITE := Color(0.82, 0.83, 0.82)
const TILES := Color(0.66, 0.72, 0.74)
const MATTRESS := Color(0.3, 0.33, 0.38)
const SHEET := Color(0.76, 0.75, 0.7)
const BLANKETS := [Color(0.5, 0.2, 0.12), Color(0.18, 0.27, 0.42), Color(0.33, 0.37, 0.28), Color(0.46, 0.38, 0.27)]
const COVERALL := Color(0.86, 0.36, 0.08)
const WOOD := Color(0.34, 0.22, 0.13)
const FABRIC := Color(0.36, 0.2, 0.16)


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


## A double bunk, 2 m long along its x, its open side (rail and ladder) to
## +z. `made` beds have their blankets straight; others are thrown back.
static func bunk(parent: Node3D, pos: Vector3, yaw: float, seed := 0, made := true) -> Node3D:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var p := Parts.new()
	for x in [-0.97, 0.97]:
		for z in [-0.42, 0.42]:
			p.box(Vector3(x, 0.98, z), Vector3(0.06, 1.96, 0.06), STEEL, 0.4)
	for y in [0.32, 1.32]:
		p.box(Vector3(0, y, 0), Vector3(2.0, 0.06, 0.9), STEEL, 0.45)
		p.box(Vector3(0, y + 0.1, 0), Vector3(1.9, 0.14, 0.82), MATTRESS, 0.9)
		p.box(Vector3(-0.75, y + 0.21, 0), Vector3(0.36, 0.09, 0.6), SHEET, 0.95, Vector3(0, r.randf_range(-0.2, 0.2), 0))
		var blanket: Color = BLANKETS[r.randi() % BLANKETS.size()]
		if made:
			p.box(Vector3(0.3, y + 0.19, 0), Vector3(1.25, 0.05, 0.86), blanket, 0.95)
		else:
			p.box(Vector3(0.55, y + 0.22, 0.05), Vector3(0.8, 0.1, 0.9), blanket, 0.95, Vector3(r.randf_range(-0.15, 0.15), 0, r.randf_range(-0.1, 0.1)))
	# The upper bunk's rail and the ladder at its foot.
	p.box(Vector3(-0.3, 1.72, 0.42), Vector3(1.3, 0.04, 0.04), STEEL, 0.4)
	for z in [0.42, 0.62]:
		p.box(Vector3(0.97, 0.9, z), Vector3(0.04, 1.8, 0.04), STEEL, 0.4)
	for i in 4:
		p.box(Vector3(0.97, 0.35 + i * 0.38, 0.52), Vector3(0.04, 0.03, 0.2), STEEL, 0.4)
	p.solid(Vector3(0, 0.98, 0), Vector3(2.0, 1.96, 0.9))
	return p.build(parent, "Bunk", pos, yaw)


## A shower stall against a wall: the back at -z, open to +z.
static func shower(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var p := Parts.new()
	p.box(Vector3(0, 1.15, -0.5), Vector3(1.2, 2.3, 0.06), TILES, 0.3)
	for x in [-0.6, 0.6]:
		p.box(Vector3(x, 1.05, -0.05), Vector3(0.05, 2.1, 0.9), WHITE, 0.35)
	p.box(Vector3(0, 0.03, -0.05), Vector3(1.15, 0.06, 0.9), TILES.darkened(0.15), 0.3)
	p.cyl(Vector3(0, 0.065, -0.05), 0.07, 0.01, DARK, 0.5)
	# The pipe up the back and the head.
	p.box(Vector3(0.2, 1.4, -0.44), Vector3(0.04, 1.6, 0.04), CHROME, 0.25)
	p.box(Vector3(0.2, 2.2, -0.33), Vector3(0.04, 0.04, 0.24), CHROME, 0.25)
	p.cyl(Vector3(0.2, 2.17, -0.2), 0.09, 0.03, CHROME, 0.25)
	p.cyl(Vector3(0.2, 1.1, -0.44), 0.05, 0.05, CHROME, 0.25, Vector3(PI * 0.5, 0, 0))
	p.solid(Vector3(0, 1.15, -0.5), Vector3(1.2, 2.3, 0.08))
	p.solid(Vector3(-0.6, 1.05, -0.05), Vector3(0.06, 2.1, 0.9))
	p.solid(Vector3(0.6, 1.05, -0.05), Vector3(0.06, 2.1, 0.9))
	return p.build(parent, "Shower", pos, yaw)


## A washer with a dryer stacked on it, doors to +z. `open` hangs the
## washer's door open.
static func washer(parent: Node3D, pos: Vector3, yaw: float, open := false) -> Node3D:
	var p := Parts.new()
	for k in 2:
		var y := k * 0.86
		p.box(Vector3(0, y + 0.43, 0), Vector3(0.74, 0.84, 0.68), WHITE, 0.4)
		p.box(Vector3(0, y + 0.78, 0.345), Vector3(0.7, 0.1, 0.01), DARK, 0.4)
		p.cyl(Vector3(-0.22, y + 0.78, 0.35), 0.025, 0.012, Color(0.2, 0.9, 0.5), 0.4, Vector3(PI * 0.5, 0, 0), 1.5)
		if k == 0 and open:
			p.cyl(Vector3(-0.26, 0.4, 0.5), 0.23, 0.05, CHROME, 0.3, Vector3(0, 0, PI * 0.5))
			p.cyl(Vector3(0, 0.4, 0.345), 0.2, 0.01, DARK, 0.6, Vector3(PI * 0.5, 0, 0))
		else:
			p.cyl(Vector3(0, y + 0.4, 0.35), 0.24, 0.03, CHROME, 0.3, Vector3(PI * 0.5, 0, 0))
			p.cyl(Vector3(0, y + 0.4, 0.365), 0.19, 0.01, Color(0.12, 0.16, 0.2), 0.15, Vector3(PI * 0.5, 0, 0))
	p.solid(Vector3(0, 0.86, 0), Vector3(0.74, 1.72, 0.68))
	return p.build(parent, "Washer", pos, yaw)


## A folding table with coveralls on it, `length` along its x.
static func folding_table(parent: Node3D, pos: Vector3, yaw: float, length := 1.8, seed := 0) -> Node3D:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var p := Parts.new()
	p.box(Vector3(0, 0.88, 0), Vector3(length, 0.04, 0.8), STEEL, 0.4)
	for x in [-length * 0.5 + 0.08, length * 0.5 - 0.08]:
		for z in [-0.32, 0.32]:
			p.box(Vector3(x, 0.43, z), Vector3(0.05, 0.86, 0.05), STEEL, 0.4)
	p.box(Vector3(0, 0.2, 0), Vector3(length - 0.1, 0.03, 0.7), STEEL, 0.4)
	for i in 3:
		var x := -length * 0.35 + i * length * 0.32
		for k in r.randi_range(1, 3):
			p.box(Vector3(x + r.randf_range(-0.05, 0.05), 0.92 + k * 0.06, r.randf_range(-0.1, 0.1)), Vector3(0.42, 0.06, 0.34), COVERALL.darkened(r.randf() * 0.3), 0.95, Vector3(0, r.randf_range(-0.2, 0.2), 0))
	p.solid(Vector3(0, 0.45, 0), Vector3(length, 0.9, 0.8))
	return p.build(parent, "FoldingTable", pos, yaw)


## A laundry cart on castors with a bag of coveralls.
static func cart(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var p := Parts.new()
	p.box(Vector3(0, 0.12, 0), Vector3(0.9, 0.04, 0.6), STEEL, 0.4)
	for x in [-0.43, 0.43]:
		for z in [-0.28, 0.28]:
			p.box(Vector3(x, 0.5, z), Vector3(0.03, 0.8, 0.03), STEEL, 0.4)
			p.cyl(Vector3(x, 0.05, z), 0.05, 0.04, DARK, 0.6, Vector3(PI * 0.5, 0, 0))
	p.box(Vector3(0, 0.55, 0), Vector3(0.84, 0.75, 0.54), Color(0.2, 0.22, 0.24), 0.95)
	p.box(Vector3(0.1, 0.95, 0.05), Vector3(0.5, 0.12, 0.4), COVERALL.darkened(0.2), 0.95, Vector3(0.1, 0.3, 0))
	p.solid(Vector3(0, 0.5, 0), Vector3(0.9, 1.0, 0.6))
	return p.build(parent, "Cart", pos, yaw)


## A long mess table with a bench either side, `length` along its x.
static func mess_table(parent: Node3D, pos: Vector3, yaw: float, length := 3.0, seed := 0) -> Node3D:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var p := Parts.new()
	p.box(Vector3(0, 0.76, 0), Vector3(length, 0.05, 0.9), Color(0.55, 0.57, 0.58), 0.35)
	for x in [-length * 0.32, length * 0.32]:
		p.box(Vector3(x, 0.38, 0), Vector3(0.12, 0.74, 0.5), STEEL, 0.4)
	for z in [-0.75, 0.75]:
		p.box(Vector3(0, 0.45, z), Vector3(length, 0.05, 0.34), STEEL.darkened(0.2), 0.5)
		for x in [-length * 0.32, length * 0.32]:
			p.box(Vector3(x, 0.22, z), Vector3(0.08, 0.44, 0.24), STEEL, 0.4)
	# Trays left where people got up.
	for i in r.randi_range(2, 4):
		var at := Vector3(r.randf_range(-length * 0.4, length * 0.4), 0.795, r.randf_range(-0.25, 0.25))
		p.box(at, Vector3(0.42, 0.02, 0.3), Color(0.25, 0.3, 0.32), 0.4, Vector3(0, r.randf_range(-0.4, 0.4), 0))
		p.cyl(at + Vector3(0.08, 0.035, 0.02), 0.07, 0.05, WHITE, 0.4)
	p.solid(Vector3(0, 0.39, 0), Vector3(length, 0.78, 0.9))
	p.solid(Vector3(0, 0.235, -0.75), Vector3(length, 0.47, 0.34))
	p.solid(Vector3(0, 0.235, 0.75), Vector3(length, 0.47, 0.34))
	return p.build(parent, "MessTable", pos, yaw)


## A galley counter `length` long along its x, its front to +z. `hob`
## puts four rings on it, `sink` a sink.
static func counter(parent: Node3D, pos: Vector3, yaw: float, length := 2.0, hob := false, sink := false) -> Node3D:
	var p := Parts.new()
	p.box(Vector3(0, 0.45, 0), Vector3(length, 0.9, 0.7), Color(0.42, 0.44, 0.45), 0.5)
	p.box(Vector3(0, 0.92, 0), Vector3(length + 0.02, 0.04, 0.74), CHROME, 0.25)
	p.box(Vector3(0, 0.06, 0.33), Vector3(length, 0.12, 0.04), DARK, 0.5)
	for i in int(length / 0.6):
		p.box(Vector3(-length * 0.5 + 0.3 + i * 0.6, 0.55, 0.352), Vector3(0.5, 0.6, 0.01), STEEL.lightened(0.1), 0.4)
		p.box(Vector3(-length * 0.5 + 0.3 + i * 0.6, 0.8, 0.36), Vector3(0.16, 0.02, 0.02), CHROME, 0.3)
	if hob:
		for x in [-0.22, 0.22]:
			for z in [-0.15, 0.15]:
				p.cyl(Vector3(x, 0.945, z), 0.11, 0.01, DARK, 0.5)
		p.box(Vector3(0.6, 1.0, -0.05), Vector3(0.28, 0.12, 0.28), CHROME, 0.3)
	if sink:
		p.box(Vector3(-length * 0.25, 0.93, 0), Vector3(0.6, 0.03, 0.45), DARK.lightened(0.15), 0.2)
		p.box(Vector3(-length * 0.25, 1.08, -0.28), Vector3(0.04, 0.3, 0.04), CHROME, 0.25)
		p.box(Vector3(-length * 0.25, 1.22, -0.18), Vector3(0.04, 0.04, 0.22), CHROME, 0.25)
	p.solid(Vector3(0, 0.47, 0), Vector3(length, 0.94, 0.72))
	return p.build(parent, "Counter", pos, yaw)


## A chapel pew, `length` along its x, facing +z.
static func pew(parent: Node3D, pos: Vector3, yaw: float, length := 2.4) -> Node3D:
	var p := Parts.new()
	p.box(Vector3(0, 0.45, 0), Vector3(length, 0.06, 0.44), WOOD, 0.6)
	p.box(Vector3(0, 0.75, -0.22), Vector3(length, 0.5, 0.05), WOOD, 0.6, Vector3(-0.12, 0, 0))
	for x in [-length * 0.5 + 0.04, length * 0.5 - 0.04]:
		p.box(Vector3(x, 0.45, -0.05), Vector3(0.06, 0.9, 0.5), WOOD.darkened(0.2), 0.6)
	p.solid(Vector3(0, 0.45, -0.05), Vector3(length, 0.9, 0.5))
	return p.build(parent, "Pew", pos, yaw)


## Candles on a ledge, with their own dim light.
static func candles(parent: Node3D, pos: Vector3, seed := 0) -> Node3D:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var p := Parts.new()
	for i in 7:
		var at := Vector3(r.randf_range(-0.35, 0.35), 0.0, r.randf_range(-0.12, 0.12))
		var h := r.randf_range(0.06, 0.2)
		p.cyl(at + Vector3(0, h * 0.5, 0), 0.025, h, Color(0.85, 0.82, 0.7), 0.8)
		p.box(at + Vector3(0, h + 0.015, 0), Vector3(0.012, 0.03, 0.012), Color(1.0, 0.7, 0.3), 0.5, Vector3.ZERO, 3.0)
	var n := p.build(parent, "Candles", pos, 0.0)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.68, 0.35)
	l.light_energy = 0.5
	l.omni_range = 3.5
	l.omni_attenuation = 1.6
	l.position = Vector3(0, 0.3, 0)
	n.add_child(l)
	return n


## A sofa, its seat to +z.
static func sofa(parent: Node3D, pos: Vector3, yaw: float, length := 2.2) -> Node3D:
	var p := Parts.new()
	p.box(Vector3(0, 0.22, 0), Vector3(length, 0.3, 0.9), FABRIC.darkened(0.3), 0.9)
	p.box(Vector3(0, 0.43, 0.06), Vector3(length - 0.36, 0.14, 0.76), FABRIC, 0.95)
	p.box(Vector3(0, 0.7, -0.36), Vector3(length, 0.7, 0.2), FABRIC, 0.95)
	for x in [-length * 0.5 + 0.09, length * 0.5 - 0.09]:
		p.box(Vector3(x, 0.45, 0.0), Vector3(0.18, 0.55, 0.9), FABRIC.darkened(0.15), 0.95)
	p.solid(Vector3(0, 0.45, 0), Vector3(length, 0.9, 0.9))
	return p.build(parent, "Sofa", pos, yaw)


## A treadmill, its belt along its z, the console at -z.
static func treadmill(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var p := Parts.new()
	p.box(Vector3(0, 0.1, 0.1), Vector3(0.75, 0.2, 1.8), STEEL.darkened(0.3), 0.5)
	p.box(Vector3(0, 0.205, 0.1), Vector3(0.55, 0.01, 1.7), DARK, 0.9)
	for x in [-0.34, 0.34]:
		p.box(Vector3(x, 0.7, -0.72), Vector3(0.05, 1.1, 0.05), STEEL, 0.4)
		p.box(Vector3(x, 1.0, -0.45), Vector3(0.04, 0.04, 0.5), STEEL, 0.4)
	p.box(Vector3(0, 1.28, -0.74), Vector3(0.6, 0.2, 0.12), DARK, 0.4, Vector3(-0.5, 0, 0))
	p.box(Vector3(0, 1.3, -0.69), Vector3(0.4, 0.1, 0.01), Color(0.3, 0.8, 0.9), 0.4, Vector3(-0.5, 0, 0), 1.2)
	p.solid(Vector3(0, 0.6, 0), Vector3(0.75, 1.2, 1.9))
	return p.build(parent, "Treadmill", pos, yaw)


## A weight bench with a rack and a bar.
static func weights(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var p := Parts.new()
	p.box(Vector3(0, 0.45, 0.2), Vector3(0.32, 0.08, 1.2), FABRIC.darkened(0.4), 0.9)
	p.box(Vector3(0, 0.22, 0.2), Vector3(0.1, 0.44, 0.9), STEEL, 0.4)
	for x in [-0.55, 0.55]:
		p.box(Vector3(x, 0.6, -0.35), Vector3(0.06, 1.2, 0.06), STEEL, 0.4)
	p.cyl(Vector3(0, 1.1, -0.35), 0.02, 1.8, CHROME, 0.25, Vector3(0, 0, PI * 0.5))
	for x in [-0.75, 0.75]:
		p.cyl(Vector3(x, 1.1, -0.35), 0.2, 0.05, DARK, 0.6, Vector3(0, 0, PI * 0.5))
	# Plates on the floor.
	for i in 3:
		p.cyl(Vector3(0.75, 0.03 + i * 0.05, 0.45), 0.18, 0.04, DARK, 0.6)
	p.solid(Vector3(0, 0.6, 0), Vector3(1.6, 1.2, 1.4))
	return p.build(parent, "Weights", pos, yaw)


## A punching bag hanging from the ceiling on a chain.
static func bag(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Parts.new()
	p.cyl(Vector3(0, 1.45, 0), 0.22, 1.1, Color(0.45, 0.12, 0.1), 0.7)
	p.box(Vector3(0, 3.5, 0), Vector3(0.03, 3.0, 0.03), STEEL, 0.4)
	p.solid(Vector3(0, 1.45, 0), Vector3(0.44, 1.1, 0.44))
	return p.build(parent, "PunchingBag", pos, 0.0)


## Coveralls dropped on the floor.
static func clothes(parent: Node3D, pos: Vector3, seed := 0) -> Node3D:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var p := Parts.new()
	for i in r.randi_range(2, 4):
		p.box(Vector3(r.randf_range(-0.35, 0.35), 0.03 + i * 0.03, r.randf_range(-0.3, 0.3)), Vector3(r.randf_range(0.4, 0.7), 0.05, r.randf_range(0.3, 0.5)), COVERALL.darkened(r.randf() * 0.4), 0.95, Vector3(0, r.randf() * TAU, 0))
	return p.build(parent, "Clothes", pos, 0.0)
