class_name Kit
extends RefCounted
## The station's pieces: Quaternius' Modular Sci-Fi MegaKit and Sci-Fi
## Essentials Kit, found by name, plus the collision layers and helpers for
## placing models in code. Decks are built from these by [DeckLevel].
##
## Names are the kits' own file names without the extension ("Platform_Simple",
## "WallBand_Straight", "Alien_Cyclop"); the Essentials Kit's take "ess:"
## ("ess:Prop_Locker", "ess:Gun_Pistol"), since some names are in both kits.

const MEGAKIT := "res://addons/quaternius/modularscifimegakit"
const ESSENTIALS := "res://addons/quaternius/Sci-FiEssentials"
const CREW := "res://assets/quaternius/crew"
const MODELS := "res://assets/models"

## Collision layers.
const LAYER_STATION := 1
const LAYER_INTERACT := 2
const LAYER_CREATURES := 4
const LAYER_PLAYER := 8
const LAYER_DOORS := 16
const LAYER_GIBS := 32
## Windows between rooms: stop bodies, not sight.
const LAYER_GLASS := 64
## Where shots hit creatures: their limbs and bodies, apart from the
## capsules they walk with.
const LAYER_HITBOX := 128
## What blocks sight, light and bullets.
const LAYER_SOLID := LAYER_STATION | LAYER_DOORS
## What shots hit.
const SHOT_MASK := LAYER_SOLID | LAYER_HITBOX | LAYER_GLASS

## The deck's grid: 4 m tiles, 5 m from floor to ceiling.
const TILE := 4.0
const HEIGHT := 5.0

static var _paths := {}
static var _scenes := {}
static var _materials := {}


## The file for a model name, or "" if there's none.
static func path(name: String) -> String:
	if _paths.is_empty():
		_index(MEGAKIT, "")
		_index(ESSENTIALS, "ess:")
		_index(CREW, "")
		_index(MODELS, "")
	return _paths.get(name, "")


static func _index(dir: String, prefix: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		# Exported games list "X.gltf.import" in place of "X.gltf".
		var file := f.trim_suffix(".import").trim_suffix(".remap")
		if file.ends_with(".gltf") or file.ends_with(".glb"):
			var key := prefix + file.get_basename()
			if not _paths.has(key):
				_paths[key] = dir.path_join(file)
	for sub in d.get_directories():
		_index(dir.path_join(sub), prefix)


static func has(name: String) -> bool:
	return path(name) != ""


static func scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		var p := path(name)
		if p == "":
			push_error("Kit: no model called %s" % name)
			_scenes[name] = null
		else:
			_scenes[name] = load(p)
	return _scenes[name]


static var _glass_meshes := {}
static var _glass: StandardMaterial3D


## The kit's window glass is tinted nearly opaque; the station's is clear,
## so space shows through. Returns the mesh with its glass swapped (the
## same mesh if it has none).
static func clear_glass(mesh: Mesh) -> Mesh:
	if not mesh is ArrayMesh:
		return mesh
	if _glass_meshes.has(mesh):
		return _glass_meshes[mesh]
	var out := mesh
	for s in mesh.get_surface_count():
		if (mesh as ArrayMesh).surface_get_name(s) == "M_Glass":
			if out == mesh:
				out = mesh.duplicate()
			if _glass == null:
				_glass = StandardMaterial3D.new()
				_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_glass.albedo_color = Color(0.55, 0.72, 0.82, 0.1)
				_glass.roughness = 0.04
				_glass.metallic_specular = 0.9
				_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
			out.surface_set_material(s, _glass)
	_glass_meshes[mesh] = out
	return out


## Places a model with no collision. `yaw` is in radians.
static func model(parent: Node, name: String, pos: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	var ps := scene(name)
	if ps == null:
		var n := Node3D.new()
		n.position = pos
		parent.add_child(n)
		return n
	var n: Node3D = ps.instantiate()
	_strip_collision(n)
	n.position = pos
	n.rotation.y = yaw
	if scale != 1.0:
		n.scale = Vector3.ONE * scale
	parent.add_child(n)
	return n


## The kits' own collision shapes come in as static bodies; the station
## makes its own, simpler ones, so those are dropped.
static func _strip_collision(n: Node) -> void:
	for c in n.get_children():
		if c is CollisionObject3D:
			# Keep what's visible under it.
			for m in c.get_children():
				if m is VisualInstance3D or (m is Node3D and m.get_child_count() > 0 and not m is CollisionShape3D):
					c.remove_child(m)
					n.add_child(m)
					m.transform = c.transform * m.transform
			n.remove_child(c)
			c.free()
		else:
			_strip_collision(c)


## Places a prop that blocks with a box around it. `pos` is the middle of
## its footprint, on the floor. Returns the body; the model is its child.
static func boxed(parent: Node, name: String, pos: Vector3, yaw := 0.0, scale := 1.0, layer := LAYER_STATION) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	body.collision_layer = layer
	body.collision_mask = 0
	parent.add_child(body)
	var n := model(body, name, Vector3.ZERO, 0.0, scale)
	var box := aabb_of(n)
	var c := box.get_center()
	n.position = Vector3(-c.x, 0, -c.z)
	box.position -= Vector3(c.x, 0, c.z)
	if box.size.length() > 0.0:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size.max(Vector3(0.05, 0.05, 0.05))
		cs.shape = shape
		cs.position = box.get_center()
		body.add_child(cs)
	return body


## An invisible box that blocks.
static func block(parent: Node, center: Vector3, size: Vector3, layer := LAYER_STATION) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	body.collision_layer = layer
	body.collision_mask = 0
	parent.add_child(body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	return body


## The bounds of a node's meshes, in the node's parent's space.
static func aabb_of(n: Node3D) -> AABB:
	var acc := [null]
	_merge_aabb(n, n.transform, acc)
	return acc[0] if acc[0] != null else AABB()


static func _merge_aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	if n is MeshInstance3D and n.mesh:
		var b: AABB = xf * n.mesh.get_aabb()
		acc[0] = b if acc[0] == null else acc[0].merge(b)
	for c in n.get_children():
		if c is Node3D:
			_merge_aabb(c, xf * c.transform, acc)


## A plain coloured material, cached.
static func flat(color: Color, roughness := 0.8, emission := Color.BLACK, energy := 1.0) -> StandardMaterial3D:
	var key := "%s/%s/%s/%s" % [color.to_html(), roughness, emission.to_html(), energy]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		if emission != Color.BLACK:
			m.emission_enabled = true
			m.emission = emission
			m.emission_energy_multiplier = energy
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[key] = m
	return _materials[key]


## Every mesh under `root` in one list of [mesh, transform relative to root].
static func meshes_of(root: Node3D) -> Array:
	var out := []
	_collect(root, Transform3D(), out)
	return out


static func _collect(n: Node, xf: Transform3D, out: Array) -> void:
	if n is MeshInstance3D and n.mesh and n.visible:
		out.append([n, xf])
	for c in n.get_children():
		if c is Node3D:
			_collect(c, xf * c.transform, out)
