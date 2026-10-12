class_name Gore
extends RefCounted
## Blood, ichor and gibs, as much as the Gore setting allows:
## - full: red blood, gibs, limbs coming off, bodies getting up again;
## - less: dark ichor in place of blood, gibs but no severed limbs, and bodies
##   don't get up on screen;
## - off: no blood or gibs (the Bloom's own look stays).
## Decals and gibs are capped; the oldest go first.

const MAX_DECALS := 90
const MAX_GIBS := 32
const GIB_LIFE := 14.0
## Creatures pinned to the walls by rivets stay longer than gibs.
const MAX_KEPT := 12
const KEPT_LIFE := 40.0
const DIR := "res://assets/gore/"

## Splash colours by what's bleeding.
const COLORS := {
	"blood": Color(0.32, 0.015, 0.02),
	"ichor": Color(0.07, 0.06, 0.03),
	"bloom": Color(0.24, 0.03, 0.08),
	"oil": Color(0.03, 0.03, 0.035),
	# Meltwater and frost from a shattered creature.
	"frost": Color(0.7, 0.82, 0.9, 0.75),
}

static var _decals: Array = []
static var _gibs: Array = []
static var _kept: Array = []
static var _tex := {}
static var _drop_mat: StandardMaterial3D


static func level() -> String:
	return String(LGSettings.get_value("gore", "level", "full"))


static func full() -> bool:
	return level() == "full"


static func shown() -> bool:
	return level() != "off"


## The colour a thing bleeds at the current setting, or a clear colour.
static func color(kind: String) -> Color:
	if not shown():
		return Color(0, 0, 0, 0)
	if kind == "blood" and not full():
		kind = "ichor"
	if kind == "frost":
		return COLORS["frost"]
	return COLORS.get(kind, COLORS["blood"])


static func _texture(name: String) -> Texture2D:
	if not _tex.has(name):
		var p := DIR + name + ".png"
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]


## A splash on the surface at `pos` facing `normal`. Station surfaces only:
## creatures and the player's hands don't take decals.
static func splat(world: Node, pos: Vector3, normal: Vector3, size := 1.0, kind := "blood", tex := "") -> Decal:
	if not shown() or world == null or not world.is_inside_tree():
		return null
	var d := Decal.new()
	var name := tex if tex != "" else "splat_%d" % (randi() % 4)
	d.texture_albedo = _texture(name)
	d.texture_orm = _texture(name + "_orm")
	d.modulate = color(kind)
	d.size = Vector3(size, 0.5, size)
	d.cull_mask = 1
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.distance_fade_enabled = true
	d.distance_fade_begin = 30.0
	d.distance_fade_length = 8.0
	world.get_tree().current_scene.add_child(d)
	var up := normal.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	d.global_transform = Transform3D(Basis(side, up, fwd).rotated(up, randf() * TAU), pos)
	_decals.append(d)
	while _decals.size() > MAX_DECALS:
		var old = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	return d


## A pool spreading under a body.
static func pool(world: Node, pos: Vector3, size := 1.6, kind := "blood") -> Decal:
	var d := splat(world, pos, Vector3.UP, 0.4, kind, "pool")
	if d:
		var t := d.create_tween()
		t.tween_property(d, "size", Vector3(size, 0.5, size), 6.0).set_ease(Tween.EASE_OUT)
	return d


## A spray from a wound: droplets that fly, and splashes where they land.
static func spray(world: Node, pos: Vector3, dir: Vector3, amount := 1.0, kind := "blood") -> void:
	if not shown() or world == null or not world.is_inside_tree():
		return
	var space := (world as Node3D).get_world_3d().direct_space_state if world is Node3D else null
	if DisplayServer.get_name() != "headless":
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.emitting = true
		p.amount = int(clampf(14.0 * amount, 4, 48))
		p.lifetime = 0.7
		p.explosiveness = 0.9
		p.direction = dir.normalized()
		p.spread = 35.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 5.5
		p.gravity = Vector3(0, -12, 0)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.4
		var q := QuadMesh.new()
		q.size = Vector2(0.05, 0.05)
		p.mesh = q
		if _drop_mat == null:
			_drop_mat = StandardMaterial3D.new()
			_drop_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			_drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_drop_mat.vertex_color_use_as_albedo = true
		p.material_override = _drop_mat
		p.color = color(kind).lightened(0.1)
		world.get_tree().current_scene.add_child(p)
		p.global_position = pos
		p.finished.connect(p.queue_free)
	# Splashes on whatever is behind and below.
	if space:
		for i in int(clampf(amount * 2.0, 1, 4)):
			var d := (dir.normalized() + Vector3(randf_range(-0.5, 0.5), randf_range(-0.6, 0.1), randf_range(-0.5, 0.5))).normalized()
			var q := PhysicsRayQueryParameters3D.create(pos, pos + d * 3.5, Kit.LAYER_STATION | Kit.LAYER_DOORS)
			var hit := space.intersect_ray(q)
			if hit:
				splat(world, hit.position, hit.normal, randf_range(0.5, 1.2) * clampf(amount, 0.6, 1.6), kind)


## Chunks of flesh thrown from `pos` (frozen chunks keep their look at
## every setting that shows them).
static func gibs(world: Node, pos: Vector3, count := 4, look := "gib", impulse := 4.0, kind := "blood") -> void:
	if not shown() or world == null or not world.is_inside_tree():
		return
	if not full():
		count = maxi(1, count / 2)
		if look != "frozen":
			look = "ichor"
	for i in count:
		var body := RigidBody3D.new()
		body.collision_layer = Kit.LAYER_GIBS
		body.collision_mask = Kit.LAYER_STATION | Kit.LAYER_DOORS | Kit.LAYER_GIBS
		body.mass = 0.4
		var r := randf_range(0.07, 0.17)
		var mi := MeshInstance3D.new()
		mi.mesh = Flesh.lump_mesh(r, randi())
		mi.material_override = Flesh.material(look)
		mi.layers = 2
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = r * 0.8
		cs.shape = sh
		body.add_child(cs)
		world.get_tree().current_scene.add_child(body)
		body.global_position = pos + Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.3), randf_range(-0.2, 0.2))
		body.linear_velocity = Vector3(randf_range(-1, 1), randf_range(0.6, 1.4), randf_range(-1, 1)).normalized() * impulse * randf_range(0.6, 1.2)
		body.angular_velocity = Vector3(randf(), randf(), randf()) * 8.0
		body.contact_monitor = true
		body.max_contacts_reported = 1
		body.body_entered.connect(_gib_landed.bind(body, kind))
		_track_gib(body)
	splat(world, pos + Vector3(0, -0.05, 0), Vector3.UP, 1.3, kind)


static func _gib_landed(_other: Node, body: RigidBody3D, kind: String) -> void:
	if not is_instance_valid(body) or body.has_meta("splatted"):
		return
	body.set_meta("splatted", true)
	splat(body, body.global_position, Vector3.UP, randf_range(0.3, 0.6), kind)


static func _track_gib(body: Node3D) -> void:
	_gibs.append(body)
	var t := body.get_tree().create_timer(GIB_LIFE)
	t.timeout.connect(_expire.bind(body))
	while _gibs.size() > MAX_GIBS:
		var old = _gibs.pop_front()
		if is_instance_valid(old):
			old.queue_free()


## Untyped: the gib may have gone with its deck before its timer runs out.
static func _expire(body) -> void:
	_gibs.erase(body)
	_kept.erase(body)
	if is_instance_valid(body):
		body.queue_free()


## Keeps a body that isn't a gib (a creature pinned to the wall) for a
## while, then lets it go; the oldest go first.
static func keep(body: Node) -> void:
	if body == null or not body.is_inside_tree():
		return
	_kept.append(body)
	var t := body.get_tree().create_timer(KEPT_LIFE)
	t.timeout.connect(_expire.bind(body))
	while _kept.size() > MAX_KEPT:
		var old = _kept.pop_front()
		if is_instance_valid(old):
			old.queue_free()


## Cuts a limb off a skinned body: hides it on the body (see [LimbHider])
## and throws a copy that is only that limb, with a stump where it was.
## `bone` is the limb's first bone ("upperarm_l"); returns the severed body.
static func sever(body: Node3D, skel: Skeleton3D, hider: LimbHider, bone: String, dir: Vector3, kind := "blood") -> RigidBody3D:
	var bi := skel.find_bone(bone)
	if bi < 0 or hider == null or hider.is_hidden(bi):
		return null
	var limb_xf := skel.global_transform * skel.get_bone_global_pose(bi)
	if not full():
		gibs(body, limb_xf.origin, 2, "ichor", 3.0, kind)
		return null
	hider.hide_bone(bi)
	var rb := RigidBody3D.new()
	rb.name = "Severed_" + bone
	rb.collision_layer = Kit.LAYER_GIBS
	rb.collision_mask = Kit.LAYER_STATION | Kit.LAYER_DOORS | Kit.LAYER_GIBS
	rb.mass = 3.0
	body.get_tree().current_scene.add_child(rb)
	rb.global_transform = Transform3D(Basis(), limb_xf.origin)
	# A skeleton of its own: the limb's bones keep their pose, the rest fold away.
	var copy := Skeleton3D.new()
	var keep := {}
	_subtree(skel, bi, keep)
	for i in skel.get_bone_count():
		copy.add_bone(skel.get_bone_name(i))
	for i in skel.get_bone_count():
		copy.set_bone_parent(i, skel.get_bone_parent(i))
		copy.set_bone_rest(i, skel.get_bone_rest(i))
		copy.set_bone_pose(i, skel.get_bone_pose(i))
	copy.set_bone_parent(bi, -1)
	copy.set_bone_pose(bi, skel.get_bone_global_pose(bi))
	for i in skel.get_bone_count():
		if not keep.has(i):
			copy.set_bone_pose_scale(i, Vector3.ONE * 0.001)
	rb.add_child(copy)
	copy.global_transform = skel.global_transform
	var extent := 0.0
	for mi in skel.find_children("", "MeshInstance3D", false, false):
		var m := mi as MeshInstance3D
		if m.skin == null or m.name.begins_with("Eye"):
			continue
		var c := MeshInstance3D.new()
		c.mesh = m.mesh
		c.skin = m.skin
		c.material_override = m.material_override
		c.layers = m.layers
		copy.add_child(c)
		c.skeleton = c.get_path_to(copy)
		for p in ["blood", "dead", "bloom", "seed"]:
			c.set_instance_shader_parameter(p, m.get_instance_shader_parameter(p) if m.get_instance_shader_parameter(p) != null else 0.0)
		c.set_instance_shader_parameter("blood", 0.8)
	# A capsule as long as the limb.
	var tip := bi
	for i in keep:
		var d := skel.get_bone_global_pose(i).origin.distance_to(skel.get_bone_global_pose(bi).origin)
		if d > extent:
			extent = d
			tip = i
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.07
	cap.height = maxf(0.2, extent)
	cs.shape = cap
	var tip_world := skel.global_transform * skel.get_bone_global_pose(tip).origin
	var mid := (limb_xf.origin + tip_world) * 0.5
	rb.add_child(cs)
	var axis := (tip_world - limb_xf.origin).normalized() if tip != bi else Vector3.UP
	cs.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, axis)), mid)
	rb.linear_velocity = (dir.normalized() + Vector3(0, 0.6, 0)) * 3.5
	rb.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	# The cut end, on the limb and on the body.
	_stump(rb, limb_xf.origin, kind)
	var parent := skel.get_bone_parent(bi)
	if parent >= 0:
		var att := BoneAttachment3D.new()
		att.bone_name = skel.get_bone_name(parent)
		skel.add_child(att)
		var stump := MeshInstance3D.new()
		stump.mesh = Flesh.lump_mesh(0.07, bi)
		stump.material_override = Flesh.material("lump")
		stump.position = skel.get_bone_rest(bi).origin
		stump.layers = 2
		att.add_child(stump)
	spray(body, limb_xf.origin, dir + Vector3.UP * 0.3, 1.6, kind)
	_track_gib(rb)
	return rb


static func _stump(parent: Node3D, at: Vector3, _kind: String) -> void:
	var m := MeshInstance3D.new()
	m.mesh = Flesh.lump_mesh(0.07, 3)
	m.material_override = Flesh.material("lump")
	m.layers = 2
	parent.add_child(m)
	m.global_position = at


static func _subtree(skel: Skeleton3D, bi: int, out: Dictionary) -> void:
	out[bi] = true
	for c in skel.get_bone_children(bi):
		_subtree(skel, c, out)


## Forgets every decal and gib (a new deck).
static func clear() -> void:
	for d in _decals:
		if is_instance_valid(d):
			d.queue_free()
	for g in _gibs + _kept:
		if is_instance_valid(g):
			g.queue_free()
	_decals.clear()
	_gibs.clear()
	_kept.clear()
