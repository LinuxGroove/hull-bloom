class_name Fittings
extends RefCounted
## Fittings the kits don't have, built in code from simple shapes and the
## kits' own colours: hydroponic planters (healthy or dead), drag trails and
## cocoons. Each returns its node, already added to `parent`, with collision
## where it should block.

const METAL := Color(0.24, 0.26, 0.28)
const DARK := Color(0.1, 0.11, 0.12)
const SOIL := Color(0.09, 0.06, 0.04)
const LEAF := Color(0.26, 0.5, 0.2)
const DEAD_LEAF := Color(0.32, 0.27, 0.14)


## A hydroponic planter, `length` metres long along its local x, with rows
## of plants under a grow lamp. `dead` plants are brown and drooping.
static func planter(parent: Node3D, pos: Vector3, yaw: float, length := 3.2, dead := false, seed := 0) -> Node3D:
	var root := StaticBody3D.new()
	root.name = "Planter"
	root.collision_layer = Kit.LAYER_STATION
	root.collision_mask = 0
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var w := 0.9
	var h := 0.75
	_box(root, Vector3(0, h * 0.5, 0), Vector3(length, h, w), METAL, 0.45)
	_box(root, Vector3(0, h + 0.02, 0), Vector3(length - 0.12, 0.04, w - 0.12), SOIL, 0.95)
	_box(root, Vector3(0, 0.06, 0), Vector3(length + 0.08, 0.12, w + 0.08), DARK, 0.6)
	# The lamp over it, on two posts.
	for x in [-length * 0.5 + 0.1, length * 0.5 - 0.1]:
		_box(root, Vector3(x, h + 0.75, 0), Vector3(0.06, 1.5, 0.06), DARK, 0.5)
	var lamp := _box(root, Vector3(0, h + 1.5, 0), Vector3(length, 0.06, 0.3), DARK, 0.5)
	if not dead:
		var glow := _box(root, Vector3(0, h + 1.465, 0), Vector3(length - 0.2, 0.012, 0.22), Color(0.9, 0.3, 0.9), 0.5)
		glow.material_override = Kit.flat(Color(0.9, 0.4, 0.95), 0.5, Color(0.95, 0.35, 1.0), 2.4)
	lamp.name = "Lamp"
	var plant_mat := Kit.flat(DEAD_LEAF if dead else LEAF, 0.7)
	var stem_mat := Kit.flat((DEAD_LEAF if dead else LEAF).darkened(0.35), 0.8)
	var n := int(length / 0.36)
	for row in [-0.22, 0.22]:
		for i in n:
			var at := Vector3(-length * 0.5 + 0.2 + i * (length - 0.4) / maxf(1, n - 1), h + 0.04, row + r.randf_range(-0.05, 0.05))
			_plant(root, at, r, dead, plant_mat, stem_mat)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, h + 0.1, w)
	cs.shape = shape
	cs.position = Vector3(0, (h + 0.1) * 0.5, 0)
	root.add_child(cs)
	return root


static func _plant(parent: Node3D, at: Vector3, r: RandomNumberGenerator, dead: bool, leaf: Material, stem: Material) -> void:
	var tall := r.randf_range(0.25, 0.55) * (0.6 if dead else 1.0)
	var s := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.008
	c.bottom_radius = 0.014
	c.height = tall
	c.radial_segments = 5
	c.rings = 1
	s.mesh = c
	s.material_override = stem
	s.position = at + Vector3(0, tall * 0.5, 0)
	if dead:
		s.rotation.z = r.randf_range(-0.6, 0.6)
	parent.add_child(s)
	for k in 4 if not dead else 2:
		var l := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.18, 0.006, 0.05)
		l.mesh = b
		l.material_override = leaf
		l.position = at + Vector3(0, tall * r.randf_range(0.4, 1.0), 0)
		l.rotation = Vector3(0, r.randf() * TAU, r.randf_range(-0.5, 0.5) - (0.9 if dead else 0.0))
		parent.add_child(l)


static func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color, rough: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = Kit.flat(color, rough)
	m.position = at
	parent.add_child(m)
	return m


## A crew member wrapped to the wall in the Bloom's flesh, a cocoon.
static func cocoon(parent: Node3D, pos: Vector3, yaw: float, seed := 0) -> Node3D:
	var root := Node3D.new()
	root.name = "Cocoon"
	root.add_to_group("cocoons")
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var m := MeshInstance3D.new()
	m.mesh = Flesh.lump_mesh(0.45, seed)
	m.material_override = Flesh.material("lump")
	m.scale = Vector3(1.0, 2.2, 0.8)
	m.position = Vector3(0, 1.1, 0)
	m.layers = 2
	root.add_child(m)
	for i in 4:
		var l := MeshInstance3D.new()
		l.mesh = Flesh.lump_mesh(0.18, seed + i + 1)
		l.material_override = Flesh.material("lump")
		l.position = Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 2.2), randf_range(-0.1, 0.25))
		l.layers = 2
		root.add_child(l)
	return root


## A dark smear on the floor from `a` to `b`: something was dragged.
static func drag(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	d.y = 0
	var steps := maxi(1, int(d.length() / 1.2))
	for i in steps:
		var p := a + d * (float(i) + 0.5) / steps
		var dec := Gore.splat(parent, p + Vector3(0, 0.05, 0), Vector3.UP, 1.3, "blood", "drag")
		if dec:
			dec.rotation.y = atan2(d.x, d.z)
