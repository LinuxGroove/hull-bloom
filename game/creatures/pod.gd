class_name Pod
extends Node3D
## A pod: one of the Bloom's eye-covered chrysalises, sprouted from a fully
## grown tile on the floor or a wall. Awake, it hatches skitters every so
## often. Shot, it bursts in a spray of spores that blurs your eyes for a
## moment. It withers when its tile is burnt back.

signal burst(pod: Pod)

const HEALTH := 22.0
const HATCH_MIN := 16.0
const HATCH_MAX := 30.0
const WAKE_RANGE := 15.0
const SPORE_RANGE := 4.5

## The Bloom's tile index it grew on.
var tile := -1
var health := HEALTH
var awake := false
var dead := false
var model: Node3D
var _hatch := 0.0
var _time := 0.0
var _base_scale := 1.0


static func make(tile_index: int, on_wall := false) -> Pod:
	var p := Pod.new()
	p.tile = tile_index
	p.name = "Pod"
	p.add_to_group("pods")
	p._build(on_wall)
	return p


func _build(on_wall: bool) -> void:
	model = Node3D.new()
	add_child(model)
	var ps := Kit.scene("Alien_Oculichrysalis")
	var m: Node3D = ps.instantiate() if ps else Node3D.new()
	model.add_child(m)
	var box := Kit.aabb_of(m)
	_base_scale = randf_range(0.7, 1.05)
	m.position.y = -box.position.y
	model.scale = Vector3.ONE * _base_scale
	Flesh.apply(m, "pod")
	for mi in m.find_children("", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = 2
	if on_wall:
		# Grown out of the wall, leaning into the room.
		model.rotation.x = deg_to_rad(70)
	model.rotation.y = randf() * TAU
	var a := Area3D.new()
	a.name = "Hit_pod"
	a.collision_layer = Kit.LAYER_HITBOX
	a.collision_mask = 0
	a.monitoring = false
	a.set_meta("owner", self)
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.5 * _base_scale
	cs.shape = s
	cs.position = Vector3(0, 0.6 * _base_scale, 0) if not on_wall else Vector3(0, 0.25, 0.5) * _base_scale
	a.add_child(cs)
	add_child(a)
	_hatch = randf_range(HATCH_MIN * 0.5, HATCH_MAX)
	# Pods come into being slowly.
	model.scale = Vector3.ONE * 0.05
	var t := create_tween()
	t.tween_property(model, "scale", Vector3.ONE * _base_scale, 4.0).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if dead:
		return
	_time += delta
	model.scale = Vector3.ONE * _base_scale * (1.0 + 0.04 * sin(_time * 1.6) * float(LGSettings.get_value("play", "calm_walls", 1.0))) if _time > 4.0 else model.scale
	var player := get_tree().get_first_node_in_group("tech") as Node3D
	if not awake and player and player.global_position.distance_to(global_position) < WAKE_RANGE:
		wake()
	if not awake:
		return
	_hatch -= delta
	if _hatch <= 0.0:
		_hatch = randf_range(HATCH_MIN, HATCH_MAX)
		if DeckScene.current and DeckScene.current.director:
			DeckScene.current.director.hatch_from(self)


func wake() -> void:
	if awake or dead:
		return
	awake = true
	_hatch = minf(_hatch, randf_range(4.0, 10.0))


## Splits open (hatching): a squelch and a pulse.
func pulse() -> void:
	Sfx.at(self, "pod_hatch", global_position, -2.0)
	var t := create_tween()
	t.tween_property(model, "scale", Vector3.ONE * _base_scale * 1.25, 0.15)
	t.tween_property(model, "scale", Vector3.ONE * _base_scale, 0.4)


func take_hit(hit: Hit) -> void:
	if dead:
		return
	health -= hit.amount * (1.5 if hit.kind == Hit.Kind.BURN else 1.0)
	wake()
	if health <= 0.0:
		pop(true)


## Bursts: spores and gibs. `spores` false when it simply withers.
func pop(spores := true) -> void:
	if dead:
		return
	dead = true
	remove_from_group("pods")
	burst.emit(self)
	if spores:
		Sfx.at(self, "pod_burst", global_position)
		Gore.gibs(self, global_position + Vector3(0, 0.6, 0), 4, "pod", 3.0, "bloom")
		var player := get_tree().get_first_node_in_group("tech") as Node3D
		if player and player.has_method("spores"):
			var d := player.global_position.distance_to(global_position)
			if d < SPORE_RANGE:
				player.spores(1.0 - d / SPORE_RANGE)
		queue_free()
	else:
		var t := create_tween()
		t.tween_property(model, "scale", Vector3.ONE * 0.05, 2.0)
		t.tween_callback(queue_free)
