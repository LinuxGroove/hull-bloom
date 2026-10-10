extends RefCounted
## Engineering's machines, which the kits don't have: the reactor, the
## generators and the coolant and fuel tanks, built from simple shapes in the
## kits' colours with kit pipes and fans on them. Each returns its node,
## already added to `parent`, with collision where it should block.

const STEEL := Color(0.3, 0.32, 0.35)
const DARK := Color(0.1, 0.11, 0.12)
const PANEL := Color(0.55, 0.57, 0.6)
const HAZARD := Color(0.85, 0.62, 0.1)
const GLOW := Color(1.0, 0.55, 0.18)
const COOLANT := Color(0.35, 0.75, 1.0)

static var _mats := {}


## The reactor: a squat core on its round plinth, glowing through its
## slots, with four pipe columns up into the ceiling.
static func reactor(parent: Node3D, pos: Vector3) -> Node3D:
	var root := _body(parent, pos, 0.0, "Reactor")
	Kit.model(root, "Platform_Round1", Vector3(0, 0.0, 0))
	_cyl(root, Vector3(0, 0.25, 0), 1.75, 1.75, 0.3, DARK, 0.5)
	_cyl(root, Vector3(0, 2.1, 0), 1.3, 1.45, 3.4, STEEL, 0.35, 0.6)
	_cyl(root, Vector3(0, 3.95, 0), 1.6, 1.35, 0.35, PANEL, 0.4, 0.5)
	_cyl(root, Vector3(0, 4.45, 0), 0.7, 1.0, 0.7, DARK, 0.5, 0.4)
	# Glowing bands and the slots between the core's plates.
	for y in [1.15, 2.1, 3.05]:
		var band := _cyl(root, Vector3(0, y, 0), 1.33 + (3.05 - y) * 0.04, 1.33 + (3.05 - y) * 0.04, 0.09, GLOW, 0.3)
		band.material_override = _glow(GLOW, 3.0)
	for i in 8:
		var a := TAU * i / 8.0
		var slot := _box(root, Vector3(cos(a) * 1.36, 2.1, sin(a) * 1.36), Vector3(0.1, 2.6, 0.22), GLOW, 0.3)
		slot.rotation.y = -a
		slot.material_override = _glow(GLOW, 1.6)
		var rib := _box(root, Vector3(cos(a + PI / 8) * 1.42, 2.1, sin(a + PI / 8) * 1.42), Vector3(0.16, 3.3, 0.3), DARK, 0.5)
		rib.rotation.y = -(a + PI / 8)
	# The coolant columns, one on each diagonal.
	for d in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		Kit.model(root, "Column_Pipes", d * 1.55)
	var l := OmniLight3D.new()
	l.name = "CoreGlow"
	l.position = Vector3(0, 2.2, 0)
	l.light_color = GLOW
	l.light_energy = 1.4
	l.omni_range = 9.0
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	root.add_child(l)
	_shape_cyl(root, Vector3(0, 2.5, 0), 1.85, 5.0)
	return root


## A generator: a long housing with a fan on top, warning stripes, a lit
## gauge and its cable into the floor. `yaw` in radians; it runs along x.
static func generator(parent: Node3D, pos: Vector3, yaw := 0.0, running := true) -> Node3D:
	var root := _body(parent, pos, yaw, "Generator")
	_box(root, Vector3(0, 0.12, 0), Vector3(3.0, 0.24, 1.7), DARK, 0.6)
	_box(root, Vector3(0, 1.1, 0), Vector3(2.7, 1.75, 1.4), STEEL, 0.4, 0.5)
	_box(root, Vector3(0, 2.02, 0), Vector3(2.8, 0.1, 1.5), PANEL, 0.45, 0.4)
	for x in [-1.25, 1.25]:
		_box(root, Vector3(x, 1.1, 0), Vector3(0.22, 1.8, 1.48), HAZARD, 0.6)
	for x in [-0.6, 0.0, 0.6]:
		_box(root, Vector3(x, 1.1, 0.71), Vector3(0.38, 1.3, 0.02), DARK, 0.7)
	Kit.model(root, "Prop_Fan_Small", Vector3(-0.5, 2.07, 0))
	Kit.model(root, "Prop_Vent_Small", Vector3(0.75, 2.08, 0), PI * 0.5)
	var gauge := _box(root, Vector3(0.75, 1.55, -0.71), Vector3(0.5, 0.26, 0.02), COOLANT, 0.3)
	gauge.material_override = _glow(GLOW if running else Color(0.4, 0.1, 0.05), 2.0 if running else 0.6)
	_shape_box(root, Vector3(0, 1.05, 0), Vector3(3.0, 2.1, 1.7))
	return root


## A tank on a skirt with bands round it and a pipe out of the top into the
## ceiling: coolant (blue-grey) or fuel (hazard yellow).
static func tank(parent: Node3D, pos: Vector3, fuel := false, radius := 0.85, height := 3.2) -> Node3D:
	var root := _body(parent, pos, 0.0, "Tank")
	var body_col := Color(0.62, 0.52, 0.18) if fuel else Color(0.4, 0.47, 0.52)
	_cyl(root, Vector3(0, 0.15, 0), radius + 0.08, radius + 0.08, 0.3, DARK, 0.6)
	_cyl(root, Vector3(0, 0.3 + height * 0.5, 0), radius, radius, height, body_col, 0.45, 0.35)
	var top := SphereMesh.new()
	top.radius = radius
	top.height = radius * 0.9
	top.is_hemisphere = true
	var cap := MeshInstance3D.new()
	cap.mesh = top
	cap.material_override = _mat(body_col, 0.45, 0.35)
	cap.position = Vector3(0, 0.3 + height, 0)
	root.add_child(cap)
	for y in [0.7, height - 0.2]:
		_cyl(root, Vector3(0, 0.3 + y, 0), radius + 0.03, radius + 0.03, 0.14, DARK, 0.5)
	var top_y := 0.3 + height + radius * 0.4
	if top_y < Kit.HEIGHT - 0.1:
		_cyl(root, Vector3(0, (top_y + Kit.HEIGHT) * 0.5, 0), 0.13, 0.13, Kit.HEIGHT - top_y, DARK, 0.5)
	var lamp := _box(root, Vector3(0, 1.6, radius + 0.01), Vector3(0.3, 0.12, 0.02), COOLANT, 0.3)
	lamp.material_override = _glow(HAZARD if fuel else COOLANT, 1.5)
	_shape_cyl(root, Vector3(0, (0.3 + height) * 0.5, 0), radius + 0.08, 0.3 + height)
	return root


## A rack of charging slots on the wall, its lamps lit where a cell sits.
static func charger(parent: Node3D, pos: Vector3, yaw := 0.0, full := 1) -> Node3D:
	var root := _body(parent, pos, yaw, "Charger")
	_box(root, Vector3(0, 1.05, 0), Vector3(2.2, 1.5, 0.35), STEEL, 0.4, 0.5)
	for i in 4:
		var x := -0.78 + i * 0.52
		_box(root, Vector3(x, 1.0, 0.16), Vector3(0.34, 0.9, 0.06), DARK, 0.6)
		var lamp := _box(root, Vector3(x, 1.6, 0.18), Vector3(0.2, 0.08, 0.02), COOLANT, 0.3)
		lamp.material_override = _glow(Color(0.35, 0.9, 1.0) if i < full else Color(0.6, 0.15, 0.08), 2.0 if i < full else 0.7)
	_shape_box(root, Vector3(0, 1.05, 0), Vector3(2.2, 1.5, 0.35))
	return root


static func _body(parent: Node3D, pos: Vector3, yaw: float, name: String) -> StaticBody3D:
	var root := StaticBody3D.new()
	root.name = name
	root.collision_layer = Kit.LAYER_STATION
	root.collision_mask = 0
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	return root


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
	c.radial_segments = 24
	c.rings = 1
	m.mesh = c
	m.material_override = _mat(color, rough, metal)
	m.position = at
	parent.add_child(m)
	return m


static func _shape_box(body: Node3D, at: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.position = at
	body.add_child(cs)


static func _shape_cyl(body: Node3D, at: Vector3, radius: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = height
	cs.shape = s
	cs.position = at
	body.add_child(cs)


static func _mat(color: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [color.to_html(), rough, metal]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		_mats[key] = m
	return _mats[key]


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	return Kit.flat(color * 0.4, 0.3, color, energy)
