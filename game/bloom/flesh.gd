class_name Flesh
extends RefCounted
## The Bloom's flesh on models: bakes each skinned mesh's rest pose into
## CUSTOM0 (Godot skins before the vertex shader, so the rest pose is how the
## marbling sticks to a moving body) and puts the flesh shader on it.

const SHADER := preload("res://game/bloom/flesh.gdshader")

## Looks, by name: the colours and how glossy and veined each is.
const LOOKS := {
	"alien": {},
	"pod": {"light": Color(0.75, 0.35, 0.3), "glow": 0.6, "scale": 4.0},
	"heart": {"dark": Color(0.16, 0.0, 0.03), "mid": Color(0.45, 0.04, 0.09), "glow": 0.9, "breathe": 0.05, "scale": 1.6},
	"skitter": {"scale": 6.0, "glow": 0.25},
	"watcher": {"light": Color(0.78, 0.55, 0.5), "fat": Color(0.85, 0.75, 0.6), "glow": 0.45},
	"feeder": {"dark": Color(0.08, 0.02, 0.05), "mid": Color(0.3, 0.06, 0.12), "glow": 0.5},
	"lump": {"glow": 0.5, "scale": 5.0},
	"gib": {"glow": 0.15, "scale": 7.0, "breathe": 0.0},
	"ichor": {"dark": Color(0.03, 0.03, 0.02), "mid": Color(0.1, 0.12, 0.05), "light": Color(0.22, 0.25, 0.1), "fat": Color(0.3, 0.3, 0.15), "glow": 0.2},
	"charred": {"dark": Color(0.02, 0.01, 0.01), "mid": Color(0.06, 0.03, 0.02), "light": Color(0.14, 0.07, 0.04), "fat": Color(0.2, 0.12, 0.08), "glow": 0.3, "wet": 0.1},
	# Flesh left on a held deck: dried out, still and dull.
	"dead": {"dark": Color(0.04, 0.035, 0.03), "mid": Color(0.12, 0.1, 0.085), "light": Color(0.24, 0.2, 0.17), "fat": Color(0.3, 0.26, 0.21), "glow": 0.0, "wet": 0.05, "breathe": 0.0, "scale": 5.0},
}

static var _baked := {}
static var _mats := {}


## A flesh material (cached). `rest` uses the baked rest pose for skinned
## meshes; plain meshes use their own vertices.
static func material(look := "alien", rest := false) -> ShaderMaterial:
	var key := "%s/%s" % [look, rest]
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		var o: Dictionary = LOOKS.get(look, {})
		for k in o:
			var v = o[k]
			m.set_shader_parameter(k, Vector3(v.r, v.g, v.b) if v is Color else v)
		m.set_shader_parameter("use_rest", rest)
		_mats[key] = m
	return _mats[key]


## Gives every mesh under `root` the flesh look, baking skinned ones first.
static func apply(root: Node, look := "alien") -> void:
	for mi in root.find_children("", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var skinned := m.skin != null
		if skinned:
			m.mesh = bake(m.mesh)
		m.material_override = material(look, skinned)


## A copy of `mesh` with each vertex's rest position in CUSTOM0 (cached).
static func bake(mesh: Mesh) -> Mesh:
	if mesh == null or mesh.has_meta("rest_baked"):
		return mesh
	if _baked.has(mesh):
		return _baked[mesh]
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var custom := PackedFloat32Array()
		custom.resize(verts.size() * 3)
		for i in verts.size():
			custom[i * 3] = verts[i].x
			custom[i * 3 + 1] = verts[i].y
			custom[i * 3 + 2] = verts[i].z
		arrays[Mesh.ARRAY_CUSTOM0] = custom
		var fmt: int = (mesh as ArrayMesh).surface_get_format(s) if mesh is ArrayMesh else 0
		var flags: int = (fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) | (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays, [], {}, flags)
		var mat := mesh.surface_get_material(s)
		if mat:
			out.surface_set_material(s, mat)
	out.set_meta("rest_baked", true)
	_baked[mesh] = out
	return out


## A lump of growth: a squashed, lumpy sphere mesh in the flesh look.
static func lump_mesh(radius := 0.3, seed := 0) -> ArrayMesh:
	var key := "lump/%s/%s" % [snappedf(radius, 0.05), seed % 6]
	if _baked.has(key):
		return _baked[key]
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 1.6
	sm.radial_segments = 14
	sm.rings = 8
	var arrays := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 2.2 / maxf(radius, 0.05)
	for i in verts.size():
		var v := verts[i]
		var n := noise.get_noise_3dv(v)
		verts[i] = v * (1.0 + n * 0.35)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(out, 0)
	st.generate_normals()
	var lumped := st.commit()
	_baked[key] = lumped
	return lumped
