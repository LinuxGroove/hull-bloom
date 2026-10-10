extends RefCounted
## Cargo's fittings, which the kits don't have: the shuttle on its pad in
## the dock and the conveyor belts, built from simple shapes in the kits'
## colours with kit crates and lights on them. Each returns its node,
## already added to `parent`, with collision where it should block.

const HULL := Color(0.72, 0.74, 0.76)
const HULL_DARK := Color(0.2, 0.22, 0.25)
const STRIPE := Color(0.95, 0.72, 0.12)
const DARK := Color(0.1, 0.11, 0.12)
const BELT := Color(0.06, 0.06, 0.07)
const GLASS := Color(0.1, 0.18, 0.26)
const EXHAUST := Color(0.45, 0.75, 1.0)

static var _mats := {}


## The shuttle Corran, about ten metres nose to tail, nose along +x, sat on
## its gear with the hatch open on its +z side and the ramp down.
static func shuttle(parent: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	var root := StaticBody3D.new()
	root.name = "Shuttle"
	root.collision_layer = Kit.LAYER_STATION
	root.collision_mask = 0
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	# The fuselage: a long capsule, a little flattened, with a spine on top.
	var body := _capsule(root, Vector3(0.2, 2.0, 0), 1.35, 9.4, HULL, 0.4, 0.45)
	body.rotation.z = PI * 0.5
	body.scale = Vector3(0.85, 1.0, 1.0)
	_box(root, Vector3(-1.2, 3.12, 0), Vector3(5.2, 0.36, 1.1), HULL_DARK, 0.5, 0.4)
	_box(root, Vector3(-0.6, 0.98, 0), Vector3(6.6, 0.3, 1.6), HULL_DARK, 0.5, 0.4)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.0, 2.25, side * 1.32), Vector3(7.0, 0.2, 0.03), STRIPE, 0.6)
		_box(root, Vector3(0.0, 1.95, side * 1.34), Vector3(7.0, 0.06, 0.03), DARK, 0.6)
	# The canopy over the cockpit.
	var canopy := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	canopy.mesh = s
	canopy.material_override = Kit.flat(GLASS, 0.08, Color(0.2, 0.45, 0.6), 0.35)
	canopy.position = Vector3(3.3, 2.75, 0)
	canopy.scale = Vector3(1.5, 0.55, 0.95)
	root.add_child(canopy)
	# Swept wings, a stripe and a light at each tip.
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(-0.6, 1.55, side * 1.05)
		wing.rotation.y = side * 0.32
		root.add_child(wing)
		_box(wing, Vector3(-0.4, 0, side * 1.25), Vector3(2.6, 0.2, 2.5), HULL, 0.45, 0.4)
		_box(wing, Vector3(-0.4, 0.11, side * 1.6), Vector3(2.3, 0.02, 0.35), STRIPE, 0.6)
		_box(wing, Vector3(-1.0, 0.02, side * 2.5), Vector3(1.4, 0.26, 0.16), HULL_DARK, 0.5)
		var tip := _sphere(wing, Vector3(-0.4, 0.05, side * 2.55), 0.09)
		var c := Color(0.2, 1.0, 0.3) if side < 0.0 else Color(1.0, 0.15, 0.1)
		tip.material_override = Kit.flat(c * 0.4, 0.3, c, 4.0)
		_shape(root, wing.transform * Transform3D(Basis(), Vector3(-0.4, 0, side * 1.25)), Vector3(2.6, 0.25, 2.5))
	# The tail fin.
	var fin := _box(root, Vector3(-3.7, 3.7, 0), Vector3(2.1, 1.4, 0.16), HULL, 0.45, 0.4)
	fin.rotation.z = 0.42
	_box(root, Vector3(-3.95, 3.95, 0), Vector3(1.0, 0.25, 0.18), STRIPE, 0.6).rotation.z = 0.42
	var strobe := _sphere(root, Vector3(-4.35, 4.3, 0), 0.07)
	strobe.material_override = Kit.flat(Color.WHITE * 0.5, 0.3, Color.WHITE, 5.0)
	# Two engines, idling blue.
	for side in [-1.0, 1.0]:
		var eng := _cyl(root, Vector3(-4.3, 1.95, side * 0.85), 0.5, 0.58, 1.9, HULL_DARK, 0.4, 0.6)
		eng.rotation.z = PI * 0.5
		var ring := _cyl(root, Vector3(-5.27, 1.95, side * 0.85), 0.52, 0.52, 0.08, DARK, 0.5)
		ring.rotation.z = PI * 0.5
		var glow := _cyl(root, Vector3(-5.3, 1.95, side * 0.85), 0.4, 0.4, 0.04, EXHAUST, 0.3)
		glow.rotation.z = PI * 0.5
		glow.material_override = Kit.flat(EXHAUST * 0.3, 0.3, EXHAUST, 3.0)
	# The gear, on pads.
	for at in [Vector3(3.0, 0, 0), Vector3(-2.4, 0, -1.0), Vector3(-2.4, 0, 1.0)]:
		_cyl(root, at + Vector3(0, 0.55, 0), 0.09, 0.11, 1.0, DARK, 0.5, 0.6)
		_box(root, at + Vector3(0, 0.04, 0), Vector3(0.7, 0.08, 0.7), HULL_DARK, 0.6, 0.4)
		Kit.model(root, "Prop_Clamp", at + Vector3(0, 0.0, 0.5))
	# The hatch, open and lit, and the ramp down from it.
	var hatch := _box(root, Vector3(1.8, 1.8, 1.16), Vector3(1.2, 1.55, 0.04), Color(0.95, 0.9, 0.8), 0.4)
	hatch.material_override = Kit.flat(Color(0.5, 0.48, 0.42), 0.4, Color(1.0, 0.92, 0.75), 1.6)
	for x in [1.15, 2.45]:
		_box(root, Vector3(x, 1.8, 1.2), Vector3(0.1, 1.7, 0.08), STRIPE, 0.6)
	var ramp := _box(root, Vector3(1.8, 0.52, 2.15), Vector3(1.25, 0.08, 2.2), HULL_DARK, 0.6, 0.4)
	ramp.rotation.x = atan2(1.0, 2.0)
	_shape(root, ramp.transform, Vector3(1.25, 0.1, 2.2))
	var inside := OmniLight3D.new()
	inside.name = "HatchLight"
	inside.position = Vector3(1.8, 1.9, 1.7)
	inside.light_color = Color(1.0, 0.9, 0.72)
	inside.light_energy = 1.1
	inside.omni_range = 4.5
	inside.shadow_enabled = false
	root.add_child(inside)
	# Her name on the hull.
	for side in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = "CORRAN"
		label.font_size = 96
		label.pixel_size = 0.006
		label.modulate = Color(0.12, 0.13, 0.15)
		label.outline_size = 0
		label.double_sided = false
		label.position = Vector3(-1.4, 2.62, side * 1.3)
		label.rotation.y = 0.0 if side > 0.0 else PI
		root.add_child(label)
	_shape(root, Transform3D(Basis(), Vector3(-0.2, 1.7, 0)), Vector3(10.2, 3.4, 2.7))
	return root


## A conveyor belt between two points on the floor (along x or z), with
## crates riding it.
static func conveyor(parent: Node3D, a: Vector3, b: Vector3, width := 1.1, crates := 2, seed := 0) -> Node3D:
	var root := StaticBody3D.new()
	root.name = "Conveyor"
	root.collision_layer = Kit.LAYER_STATION
	root.collision_mask = 0
	root.position = (a + b) * 0.5
	var d := b - a
	d.y = 0
	var length := d.length()
	root.rotation.y = atan2(-d.z, d.x)
	parent.add_child(root)
	_box(root, Vector3(0, 0.35, 0), Vector3(length, 0.7, width), HULL_DARK, 0.6, 0.4)
	_box(root, Vector3(0, 0.73, 0), Vector3(length - 0.1, 0.06, width - 0.12), BELT, 0.9)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0, 0.84, side * (width * 0.5 - 0.03)), Vector3(length, 0.16, 0.06), DARK, 0.5, 0.5)
		_box(root, Vector3(0, 0.5, side * (width * 0.5 + 0.005)), Vector3(length, 0.1, 0.01), STRIPE, 0.6)
		# Running lamps along the rails, still lit on the belt's own supply.
		var lamps := maxi(1, int(length / 1.6))
		for i in lamps:
			var lamp := _box(root, Vector3(-length * 0.5 + (i + 0.5) * length / lamps, 0.86, side * (width * 0.5 + 0.01)), Vector3(0.14, 0.05, 0.02), STRIPE, 0.4)
			lamp.material_override = Kit.flat(STRIPE * 0.3, 0.4, STRIPE, 2.2)
	for end in [-1.0, 1.0]:
		var roller := _cyl(root, Vector3(end * (length * 0.5 - 0.1), 0.62, 0), 0.14, 0.14, width - 0.05, DARK, 0.5, 0.5)
		roller.rotation.x = PI * 0.5
	var r := RandomNumberGenerator.new()
	r.seed = seed
	for i in crates:
		var x := -length * 0.5 + (i + 0.5) * length / crates + r.randf_range(-0.4, 0.4)
		var names := ["Prop_Crate1", "Prop_Crate2", "Prop_Crate3"]
		var m := Kit.model(root, names[r.randi() % names.size()], Vector3(x, 0.76 + 0.35, 0), r.randf_range(-0.3, 0.3), 0.7)
		m.name = "Crate"
	_shape(root, Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(length, 0.9, width))
	return root


static func _shape(body: Node3D, xf: Transform3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.transform = xf
	body.add_child(cs)


static func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color, rough: float, metal := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = _mat(color, rough, metal)
	m.position = at
	parent.add_child(m)
	return m


static func _cyl(parent: Node3D, at: Vector3, top: float, bottom: float, height: float, color: Color, rough: float, metal := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = 20
	c.rings = 1
	m.mesh = c
	m.material_override = _mat(color, rough, metal)
	m.position = at
	parent.add_child(m)
	return m


static func _capsule(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, rough: float, metal := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 32
	c.rings = 12
	m.mesh = c
	m.material_override = _mat(color, rough, metal)
	m.position = at
	parent.add_child(m)
	return m


static func _sphere(parent: Node3D, at: Vector3, radius: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	m.mesh = s
	m.position = at
	parent.add_child(m)
	return m


static func _mat(color: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [color.to_html(), rough, metal]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		_mats[key] = m
	return _mats[key]
