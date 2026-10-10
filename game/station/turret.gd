class_name Turret
extends UsableBody
## A sentry gun on a stand. Give it a power cell and it holds a corridor:
## it turns to the nearest creature it can see and fires until its belt runs
## dry. Load it with rifle rounds to refill it.

const RANGE := 16.0
const RATE := 0.14
const DAMAGE := 7.0
const BELT := 240
## How far it turns from where it faces, either way.
const ARC := deg_to_rad(80)

var powered := false
var ammo := BELT
## Asked when powering (true) or not (false); returns whether a cell moved.
var power := Callable()
var _pivot: Node3D
var _muzzle: Node3D
var _lamp: MeshInstance3D
var _cool := 0.0
var _target: Node3D
var _look := 0.0
var _flash: OmniLight3D


static func make(opts: Dictionary) -> Turret:
	var t := Turret.new()
	t.name = "Turret"
	t.ammo = int(opts.get("ammo", BELT))
	t.add_to_group("turrets")
	t._build()
	return t


func _build() -> void:
	display_name = "Turret"
	collision_layer = Kit.LAYER_STATION | Kit.LAYER_INTERACT
	Kit.model(self, "Prop_ItemHolder", Vector3.ZERO)
	var pole := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.08
	c.bottom_radius = 0.12
	c.height = 0.9
	pole.mesh = c
	pole.material_override = Kit.flat(Color(0.2, 0.21, 0.23), 0.5)
	pole.position.y = 0.85
	add_child(pole)
	_pivot = Node3D.new()
	_pivot.position.y = 1.35
	add_child(_pivot)
	var gun := Kit.model(_pivot, "ess:Gun_Rifle_Red", Vector3.ZERO, PI * 0.5, 1.5)
	gun.position = Vector3(0, 0.05, -0.2)
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0, 0.12, -1.25)
	_pivot.add_child(_muzzle)
	_lamp = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.06
	s.height = 0.12
	_lamp.mesh = s
	_lamp.position = Vector3(0, 0.3, 0.1)
	_pivot.add_child(_lamp)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.7, 0.3)
	_flash.omni_range = 5.0
	_flash.light_energy = 0.0
	_muzzle.add_child(_flash)
	add_box(Vector3(0, 0.75, 0), Vector3(0.9, 1.5, 0.9))
	add_action("interact", "Power the turret (1 cell)", _use)
	_refresh()


func _use(pic: Node) -> void:
	var player := pic.get_parent() if pic else null
	if not powered:
		if power.is_valid() and not power.call(true):
			UsableBody.hint(pic, "No free power cell")
			return
		powered = true
		Sfx.at(self, "power_on", global_position, -4.0)
	elif ammo < BELT and player and player.has_method("give_turret_ammo"):
		ammo += player.give_turret_ammo(BELT - ammo)
	else:
		powered = false
		if power.is_valid():
			power.call(false)
		Sfx.at(self, "power_off", global_position, -4.0)
	_refresh()


## Powers it off and gives the cell back (the deck's power map does this).
func set_powered(on: bool) -> void:
	powered = on
	_refresh()


func _refresh() -> void:
	var c := Color(0.2, 1.0, 0.4) if powered and ammo > 0 else (Color(1.0, 0.6, 0.1) if powered else Color(0.5, 0.1, 0.1))
	_lamp.material_override = Kit.flat(c * 0.3, 0.3, c, 3.0)
	var text := "Power the turret (1 cell)"
	if powered:
		text = "Turn the turret off" if ammo >= BELT * 0.9 else "Load rounds (%d/%d)" % [ammo, BELT]
	set_action_text("interact", text)


func _physics_process(delta: float) -> void:
	_flash.light_energy = maxf(0.0, _flash.light_energy - delta * 20.0)
	if not powered or ammo <= 0:
		return
	_cool -= delta
	if _cool > 0.0:
		_turn(delta)
		return
	_cool = RATE
	_target = _pick()
	if _target == null:
		_look = lerpf(_look, 0.0, 0.1)
		_pivot.rotation.y = _look
		return
	_turn(delta)
	var aim := (_target.global_position + Vector3(0, 0.5, 0) - _muzzle.global_position).normalized()
	if (-_pivot.global_transform.basis.z).dot(aim) < 0.95:
		return
	_fire(aim)


func _turn(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var local := to_local(_target.global_position)
	var want := clampf(atan2(-local.x, -local.z), -ARC, ARC)
	_look = lerp_angle(_look, want, clampf(delta * 8.0, 0.0, 1.0))
	_pivot.rotation.y = _look


func _pick() -> Node3D:
	var best: Node3D = null
	var best_d := RANGE
	var space := get_world_3d().direct_space_state
	for c in get_tree().get_nodes_in_group("creatures"):
		var cr := c as Creature
		if cr == null or cr.dead or not cr.visible:
			continue
		var d := global_position.distance_to(cr.global_position)
		if d > best_d:
			continue
		var local := to_local(cr.global_position)
		if absf(atan2(-local.x, -local.z)) > ARC + 0.2:
			continue
		var q := PhysicsRayQueryParameters3D.create(_muzzle.global_position, cr.global_position + Vector3(0, 0.5, 0), Kit.LAYER_SOLID)
		if not space.intersect_ray(q).is_empty():
			continue
		best = cr
		best_d = d
	return best


func _fire(dir: Vector3) -> void:
	ammo -= 1
	_flash.light_energy = 2.0
	Sfx.at(self, "turret", _muzzle.global_position, -2.0)
	Noises.make(self, global_position, 18.0, self)
	var from := _muzzle.global_position
	dir = (dir + Vector3(randf_range(-0.02, 0.02), randf_range(-0.02, 0.02), randf_range(-0.02, 0.02))).normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * RANGE, Kit.SHOT_MASK)
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := from + dir * RANGE
	if hit:
		end = hit.position
		var h := Hit.make(Hit.Kind.BULLET, DAMAGE, hit.position, dir, self)
		h.normal = hit.normal
		if Hit.deal(hit.collider, h) == null:
			Effects.impact(self, hit.position, hit.normal)
	Effects.tracer(self, from, end, Color(1.0, 0.75, 0.4))
	if ammo <= 0:
		_refresh()
