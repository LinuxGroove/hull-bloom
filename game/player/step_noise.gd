class_name StepNoise
extends FootstepSurfaceDetector
## The tech's footsteps: metal, or wet where the Bloom has grown, and a noise
## for every step that creatures can hear (a Stalker hears you through a wall).

const WALK := 7.0
const SPRINT := 14.0
const CROUCH := 1.8


func _play_footstep(_profile: AudioStreamRandomizer, interaction_type: String):
	var p := get_parent() as Tech
	if p == null:
		return
	var wet := false
	if p.level and p.level.bloom:
		wet = p.level.bloom.level_at(DeckLevel.cell_at(p.global_position)) >= 1.5
	var r := CROUCH if p.is_crouching else (SPRINT if p.is_sprinting else WALK)
	if interaction_type == "landing":
		r *= 1.5
	Sfx.at(self, "step_wet" if wet else "step_metal", p.feet_position(), -16.0 if p.is_crouching else -9.0)
	Noises.make(self, p.global_position, r, p)
