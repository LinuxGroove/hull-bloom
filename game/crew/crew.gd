class_name Crew
extends Node3D
## A member of Marigold's crew: a Universal Base Character in a coverall
## coloured by job, animated with the Universal Animation Libraries. The same
## body is a survivor, a corpse or one of the Taken; [method set_look] sets how
## dead, bloodied and grown through they are.

const MALE := "res://assets/quaternius/crew/Superhero_Male_FullBody.gltf"
const FEMALE := "res://assets/quaternius/crew/Superhero_Female_FullBody.gltf"
const UAL1 := "res://assets/quaternius/crew/UAL1_Standard.glb"
const UAL2 := "res://assets/quaternius/crew/UAL2_Standard.glb"
const SHADER := preload("res://game/crew/crew.gdshader")

## Coverall colours by job.
const JOBS := {
	"tech": {"suit": Color(0.86, 0.36, 0.08), "stripe": Color(0.85, 0.85, 0.78)},
	"botanist": {"suit": Color(0.27, 0.45, 0.22), "stripe": Color(0.85, 0.8, 0.45)},
	"medic": {"suit": Color(0.82, 0.84, 0.82), "stripe": Color(0.15, 0.6, 0.6)},
	"science": {"suit": Color(0.78, 0.8, 0.85), "stripe": Color(0.25, 0.45, 0.85)},
	"security": {"suit": Color(0.16, 0.17, 0.2), "stripe": Color(0.75, 0.15, 0.12)},
	"cook": {"suit": Color(0.85, 0.83, 0.78), "stripe": Color(0.5, 0.48, 0.45)},
	"command": {"suit": Color(0.12, 0.16, 0.3), "stripe": Color(0.85, 0.7, 0.3)},
	"engineer": {"suit": Color(0.75, 0.6, 0.12), "stripe": Color(0.15, 0.15, 0.15)},
	"cargo": {"suit": Color(0.3, 0.33, 0.36), "stripe": Color(0.95, 0.6, 0.1)},
}
const SKINS := [Color(0.88, 0.69, 0.56), Color(0.78, 0.56, 0.44), Color(0.6, 0.42, 0.3), Color(0.42, 0.28, 0.2), Color(0.3, 0.2, 0.15)]
const HAIRS := [Color(0.08, 0.06, 0.05), Color(0.25, 0.15, 0.08), Color(0.5, 0.35, 0.18), Color(0.6, 0.55, 0.5), Color(0.55, 0.22, 0.1)]
## Clips that loop.
const LOOPS := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Sitting_Idle", "Sitting_Talking",
	"Idle_Talking", "Idle_FoldArms", "Idle_TalkingPhone", "Idle_Torch", "Fixing_Kneeling", "Pistol_Idle", "Walk_Carry",
	"Zombie_Idle", "Zombie_Walk_Fwd", "Zombie_Scratch", "Consume", "Idle_Rail", "Farm_Watering", "Walk_Formal", "Swim_Idle"]
## Bones that make up each region, for the shader.
const HEAD_BONES := ["Head", "neck_01"]
const FOOT_BONES := ["foot_l", "foot_r", "ball_l", "ball_r", "ball_leaf_l", "ball_leaf_r"]

static var _libs := {}
static var _baked := {}
static var _mats := {}

var job := "tech"
var female := false
var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var meshes: Array[MeshInstance3D] = []
var height := 1.8
var _current := ""


## A crew member. `seed` picks the face: skin, hair and its style.
static func make(job_ := "tech", female_ := false, seed := 0) -> Crew:
	var c := Crew.new()
	c.name = "Crew"
	c.job = job_ if JOBS.has(job_) else "tech"
	c.female = female_
	c._build(seed)
	return c


func _build(seed: int) -> void:
	var ps: PackedScene = load(FEMALE if female else MALE)
	model = ps.instantiate()
	add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false)
	height = 1.78 if female else 1.82
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var mat := _material(job, r.randi() % SKINS.size(), r.randi() % HAIRS.size(), r.randi() % 3)
	for mi in model.find_children("", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		meshes.append(m)
		if m.name.begins_with("Eye"):
			# Eyes and brows: plain, dark for the dead.
			m.material_override = Kit.flat(Color(0.9, 0.88, 0.85) if m.name == "Eyes" else Color(0.1, 0.07, 0.05), 0.4)
			continue
		m.mesh = bake(m.mesh, m.skin, skeleton)
		m.material_override = mat
	set_instance("seed", float(seed % 97) * 0.13)
	anim = AnimationPlayer.new()
	anim.name = "Anim"
	model.add_child(anim)
	anim.add_animation_library("ual1", _lib(UAL1))
	anim.add_animation_library("ual2", _lib(UAL2))
	anim.playback_default_blend_time = 0.2


static func _material(job_: String, skin_i: int, hair_i: int, style: int) -> ShaderMaterial:
	var key := "%s/%d/%d/%d" % [job_, skin_i, hair_i, style]
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		var j: Dictionary = JOBS[job_]
		m.set_shader_parameter("suit", j["suit"])
		m.set_shader_parameter("stripe", j["stripe"])
		m.set_shader_parameter("skin", SKINS[skin_i])
		m.set_shader_parameter("hair", HAIRS[hair_i])
		m.set_shader_parameter("hair_style", style)
		_mats[key] = m
	return _mats[key]


static func _lib(path: String) -> AnimationLibrary:
	if not _libs.has(path):
		var lib: AnimationLibrary = load(path)
		for n in lib.get_animation_list():
			var a := lib.get_animation(n)
			a.loop_mode = Animation.LOOP_LINEAR if String(n) in LOOPS else Animation.LOOP_NONE
		_libs[path] = lib
	return _libs[path]


## A copy of a skinned body mesh with its rest pose in CUSTOM0 and how much
## of each vertex is head, hand and foot in CUSTOM1 (cached per mesh).
static func bake(mesh: Mesh, skin: Skin, skel: Skeleton3D) -> Mesh:
	if mesh == null or _baked.has(mesh):
		return _baked.get(mesh, mesh)
	var region_of := {}
	if skin:
		for i in skin.get_bind_count():
			var bname := String(skin.get_bind_name(i))
			if bname == "" and skel:
				bname = skel.get_bone_name(skin.get_bind_bone(i))
			var reg := Vector3.ZERO
			if bname in HEAD_BONES:
				reg = Vector3(1, 0, 0)
			elif bname.begins_with("hand_") or bname.begins_with("index_") or bname.begins_with("middle_") or bname.begins_with("ring_") or bname.begins_with("pinky_") or bname.begins_with("thumb_"):
				reg = Vector3(0, 1, 0)
			elif bname in FOOT_BONES:
				reg = Vector3(0, 0, 1)
			region_of[i] = reg
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		var fmt: int = (mesh as ArrayMesh).surface_get_format(s) if mesh is ArrayMesh else 0
		var per := 8 if fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS else 4
		var c0 := PackedFloat32Array()
		var c1 := PackedFloat32Array()
		c0.resize(verts.size() * 3)
		c1.resize(verts.size() * 4)
		for i in verts.size():
			c0[i * 3] = verts[i].x
			c0[i * 3 + 1] = verts[i].y
			c0[i * 3 + 2] = verts[i].z
			var reg := Vector3.ZERO
			if bones != null and weights != null and bones.size() >= (i + 1) * per:
				for k in per:
					reg += region_of.get(int(bones[i * per + k]), Vector3.ZERO) * float(weights[i * per + k])
			c1[i * 4] = reg.x
			c1[i * 4 + 1] = reg.y
			c1[i * 4 + 2] = reg.z
			c1[i * 4 + 3] = 0.0
		arrays[Mesh.ARRAY_CUSTOM0] = c0
		arrays[Mesh.ARRAY_CUSTOM1] = c1
		var flags: int = (fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) | (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays, [], {}, flags)
	_baked[mesh] = out
	return out


## Sets an instance uniform on the body: "dead", "blood", "bloom", "hurt",
## "charred", each 0 to 1.
func set_instance(key: String, value: float) -> void:
	for m in meshes:
		if m.material_override is ShaderMaterial:
			m.set_instance_shader_parameter(key, value)
	if key == "dead" and value > 0.5:
		for m in meshes:
			if m.name == "Eyes":
				m.material_override = Kit.flat(Color(0.75, 0.7, 0.5), 0.3)


## Plays a clip from either library by name ("Walk", "Zombie_Walk_Fwd").
func play(clip: String, blend := -1.0, speed := 1.0, restart := false) -> void:
	var full := clip_path(clip)
	if full == "":
		return
	anim.speed_scale = speed
	if full == _current and not restart and anim.is_playing():
		return
	_current = full
	anim.play(full, blend)
	if restart:
		anim.seek(0.0, true)


## Holds a clip at a moment (0 to 1 of its length), for posed bodies.
func pose(clip: String, at := 1.0) -> void:
	var full := clip_path(clip)
	if full == "":
		return
	anim.play(full, 0.0)
	var a := anim.get_animation(full)
	anim.seek(a.length * clampf(at, 0.0, 0.999), true)
	anim.pause()
	_current = full


func clip_path(clip: String) -> String:
	for lib in ["ual1", "ual2"]:
		var p := "%s/%s" % [lib, clip]
		if anim.has_animation(p):
			return p
	push_warning("Crew: no clip %s" % clip)
	return ""


func clip_length(clip: String) -> float:
	var p := clip_path(clip)
	return anim.get_animation(p).length if p != "" else 0.0


func bone_position(bone: String) -> Vector3:
	var i := skeleton.find_bone(bone)
	if i < 0:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(i).origin
