class_name Effects
extends RefCounted
## Short-lived effects for shots: tracers, sparks where rounds hit metal,
## rivets left in the walls, chips of ice and blasts. Nothing here shakes or
## kicks the camera.

## Rivets left in walls; the oldest go first.
const MAX_RIVETS := 40
## The rivet model is life size; a little bigger shows at a distance.
const RIVET_SCALE := 1.5

static var _tracer_mat: StandardMaterial3D
static var _spark_mat: StandardMaterial3D
static var _ice_mat: StandardMaterial3D
static var _mist_mat: StandardMaterial3D
static var _rivets: Array = []


static func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


## A streak of light from `a` to `b` that fades fast.
static func tracer(world: Node, a: Vector3, b: Vector3, color := Color(1.0, 0.8, 0.5), width := 0.02, life := 0.06) -> void:
	if _headless() or world == null or not world.is_inside_tree() or a.distance_to(b) < 0.2:
		return
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, width, a.distance_to(b))
	m.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.emission_enabled = true
	mat.emission = color
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.get_tree().current_scene.add_child(m)
	m.global_transform = Transform3D(Basis.looking_at(b - a, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT), (a + b) * 0.5)
	var t := m.create_tween()
	t.tween_property(mat, "albedo_color:a", 0.0, life)
	t.tween_callback(m.queue_free)


## Sparks and a mark where a round hits the station.
static func impact(world: Node, pos: Vector3, normal: Vector3, color := Color(1.0, 0.7, 0.3)) -> void:
	if world == null or not world.is_inside_tree():
		return
	Sfx.at(world, "hit_metal", pos, -10.0)
	if _headless():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 8
	p.lifetime = 0.25
	p.explosiveness = 1.0
	p.direction = normal
	p.spread = 40.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -9, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.025)
	p.mesh = q
	if _spark_mat == null:
		_spark_mat = StandardMaterial3D.new()
		_spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_mat.vertex_color_use_as_albedo = true
	p.material_override = _spark_mat
	p.color = color
	world.get_tree().current_scene.add_child(p)
	p.global_position = pos + normal * 0.02
	p.finished.connect(p.queue_free)


## A flash of light at a point, for muzzles and blasts.
static func flash(world: Node, pos: Vector3, color: Color, energy := 2.0, range_ := 5.0, life := 0.08) -> void:
	if _headless() or world == null or not world.is_inside_tree():
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_
	world.get_tree().current_scene.add_child(l)
	l.global_position = pos
	var t := l.create_tween()
	t.tween_property(l, "light_energy", 0.0, life)
	t.tween_callback(l.queue_free)


## A blast: hurts everything in `radius` (less further out, not through
## walls), knocks it away, and lights the room for a moment.
static func blast(world: Node3D, pos: Vector3, radius: float, damage: float, from: Node = null) -> void:
	if world == null or not world.is_inside_tree():
		return
	Sfx.at(world, "explosion", pos, 2.0)
	Noises.make(world, pos, 40.0, from)
	flash(world, pos, Color(1.0, 0.6, 0.25), 6.0, radius * 2.5, 0.35)
	var space := world.get_world_3d().direct_space_state
	var hurt := {}
	for group in ["creatures", "tech", "pods", "hearts"]:
		for n in world.get_tree().get_nodes_in_group(group):
			var t := n as Node3D
			if t == null or hurt.has(t) or not t.has_method("take_hit"):
				continue
			var c := t.global_position + Vector3(0, 0.6, 0)
			var d := c.distance_to(pos)
			if d > radius:
				continue
			var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.2, 0), c, Kit.LAYER_SOLID)
			if not space.intersect_ray(q).is_empty():
				continue
			hurt[t] = true
			var h := Hit.make(Hit.Kind.BLAST, damage * (1.0 - 0.7 * d / radius), c, c - pos, from)
			h.knock = 8.0 * (1.0 - d / radius)
			h.sever = 2.0
			t.take_hit(h)
	if not _headless():
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.emitting = true
		p.amount = 40
		p.lifetime = 0.6
		p.explosiveness = 1.0
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 9.0
		p.gravity = Vector3(0, -6, 0)
		p.scale_amount_min = 1.0
		p.scale_amount_max = 3.0
		var q := QuadMesh.new()
		q.size = Vector2(0.08, 0.08)
		p.mesh = q
		if _spark_mat == null:
			impact(world, pos, Vector3.UP)
		p.material_override = _spark_mat
		p.color = Color(1.0, 0.6, 0.2)
		world.get_tree().current_scene.add_child(p)
		p.global_position = pos
		p.finished.connect(p.queue_free)
	var down := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.3, 0), pos + Vector3(0, -2, 0), Kit.LAYER_SOLID)
	var hit := space.intersect_ray(down)
	if hit:
		var d := Gore.splat(world, hit.position, hit.normal, radius * 0.6, "oil")
		if d:
			d.modulate = Color(0.02, 0.02, 0.02, 0.85)


## A rivet left where a rivet went in, its head flat to the surface. `on` is
## what it went into, when that can move (a door, a pinned body); otherwise it
## stays with the deck.
static func rivet(world: Node, pos: Vector3, normal: Vector3, dir: Vector3, on: Node = null) -> void:
	if _headless() or world == null or not world.is_inside_tree() or not Kit.has("rivet"):
		return
	var m: Node3D = Kit.scene("rivet").instantiate()
	for mi in m.find_children("", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var parent: Node = on if on is Node3D and on.is_inside_tree() else world.get_tree().current_scene
	parent.add_child(m)
	# The model's shank runs along -z; it goes in at the angle it came in at,
	# a little.
	var z := (normal.normalized() - dir.normalized() * 0.25).normalized()
	var x := z.cross(Vector3.UP if absf(z.y) < 0.99 else Vector3.RIGHT).normalized()
	m.global_transform = Transform3D(Basis(x, z.cross(x), z).scaled(Vector3.ONE * RIVET_SCALE), pos)
	_rivets.append(m)
	while _rivets.size() > MAX_RIVETS:
		var old = _rivets.pop_front()
		if is_instance_valid(old):
			old.queue_free()


## A puff of air from the rivet gun's muzzle.
static func puff(world: Node, pos: Vector3, dir: Vector3) -> void:
	if _headless() or world == null or not world.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 6
	p.lifetime = 0.3
	p.explosiveness = 1.0
	p.direction = dir
	p.spread = 25.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.0
	p.gravity = Vector3.ZERO
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	p.mesh = q
	p.material_override = _mist()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.9, 0.92, 0.95, 0.3))
	ramp.set_color(1, Color(0.9, 0.92, 0.95, 0.0))
	p.color_ramp = ramp
	world.get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)


## Chips of ice knocked off frozen growth or a frozen creature.
static func ice_chips(world: Node, pos: Vector3, normal: Vector3, amount := 1.0) -> void:
	if _headless() or world == null or not world.is_inside_tree():
		return
	_chips(world, pos, normal, int(clampf(10.0 * amount, 4, 24)), 0.035, 1.5, 4.5, 50.0)


## A frozen creature bursting: ice flying everywhere, a breath of cold mist
## and a flash of pale light. `size` is about the creature's radius.
static func ice_burst(world: Node, pos: Vector3, size := 0.6) -> void:
	if _headless() or world == null or not world.is_inside_tree():
		return
	_chips(world, pos, Vector3.UP, int(clampf(40.0 * size, 16, 60)), 0.06, 2.5, 7.0, 180.0)
	flash(world, pos, Color(0.6, 0.85, 1.0), 2.0, 4.0 + size * 2.0, 0.2)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 14
	p.lifetime = 0.9
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, -0.4, 0)
	p.damping_min = 0.6
	p.damping_max = 1.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.6
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	p.mesh = q
	p.material_override = _mist()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.93, 1.0, 0.35))
	ramp.set_color(1, Color(0.85, 0.93, 1.0, 0.0))
	p.color_ramp = ramp
	world.get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)


static func _chips(world: Node, pos: Vector3, normal: Vector3, count: int, size: float, v_min: float, v_max: float, spread: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = count
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = normal
	p.spread = spread
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.3
	var b := BoxMesh.new()
	b.size = Vector3(size, size * 0.6, size * 0.8)
	p.mesh = b
	if _ice_mat == null:
		_ice_mat = StandardMaterial3D.new()
		_ice_mat.albedo_color = Color(0.78, 0.9, 0.98)
		_ice_mat.roughness = 0.15
		_ice_mat.emission_enabled = true
		_ice_mat.emission = Color(0.25, 0.4, 0.5)
		_ice_mat.rim_enabled = true
	p.material_override = _ice_mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.get_tree().current_scene.add_child(p)
	p.global_position = pos + normal * 0.03
	p.finished.connect(p.queue_free)


static func _mist() -> StandardMaterial3D:
	if _mist_mat == null:
		_mist_mat = StandardMaterial3D.new()
		_mist_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mist_mat.vertex_color_use_as_albedo = true
		_mist_mat.albedo_texture = _soft_dot()
	return _mist_mat


## A soft round dot, for mist.
static func _soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 32
	t.height = 32
	return t
