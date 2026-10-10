extends SceneTree
## Prints the size of every model in the kits, for laying out decks:
##   godot --headless --path . -s tools/probe_models.gd [filter]

const DIRS := ["res://addons/quaternius/modularscifimegakit", "res://addons/quaternius/Sci-FiEssentials", "res://assets/quaternius/crew", "res://assets/models"]


func _init() -> void:
	var filter := ""
	for a in OS.get_cmdline_user_args():
		filter = a
	for d in DIRS:
		_scan(d, filter)
	quit()


func _scan(dir: String, filter: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if not (f.ends_with(".gltf") or f.ends_with(".glb")) or (filter != "" and not f.contains(filter)):
			continue
		var path := dir.path_join(f)
		var res = load(path)
		if not res is PackedScene:
			continue
		var n: Node = res.instantiate()
		var box := _aabb(n, Transform3D())
		var bodies := n.find_children("", "CollisionShape3D", true, false).size()
		var anims := []
		for ap in n.find_children("", "AnimationPlayer", true, false):
			anims.append_array(ap.get_animation_list())
		print("%-44s pos %s size %s shapes %d %s" % [f.get_basename(), _v(box.position), _v(box.size), bodies, ",".join(anims) if anims.size() > 0 else ""])
		n.free()
	for sub in d.get_directories():
		_scan(dir.path_join(sub), filter)


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	if n is MeshInstance3D and n.mesh:
		out = xf * n.mesh.get_aabb()
		first = false
	for c in n.get_children():
		if c is Node3D:
			var b := _aabb(c, xf * c.transform)
			if b.size != Vector3.ZERO:
				out = b if first else out.merge(b)
				first = false
	return out


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
