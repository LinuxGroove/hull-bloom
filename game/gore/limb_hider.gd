class_name LimbHider
extends SkeletonModifier3D
## Folds away bones that have been cut off: after the animation has posed the
## skeleton, each hidden bone is scaled to nothing, and its children with it.

var _hidden := {}


func hide_bone(bone: int) -> void:
	_hidden[bone] = true


func is_hidden(bone: int) -> bool:
	if _hidden.has(bone):
		return true
	var s := get_skeleton()
	if s == null:
		return false
	var p := s.get_bone_parent(bone)
	while p >= 0:
		if _hidden.has(p):
			return true
		p = s.get_bone_parent(p)
	return false


func hidden_count() -> int:
	return _hidden.size()


func _process_modification() -> void:
	var s := get_skeleton()
	if s == null:
		return
	for b in _hidden:
		s.set_bone_pose_scale(b, Vector3.ONE * 0.001)
