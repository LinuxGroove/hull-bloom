class_name CrewBody
extends Node3D
## One of the crew, dead where they fell. On a tile the Bloom has grown over
## (level 3 and up) a body gets up again as one of the Taken; with the Gore
## setting below Full that only happens while you aren't looking.

var level: DeckLevel
var job := "tech"
var crew: Crew
## Already grown into the floor.
var swallowed := false
var female := false
var look_seed := 0
var rising := false
var gone := false


static func make(lvl: DeckLevel, opts: Dictionary) -> CrewBody:
	var b := CrewBody.new()
	b.name = "Body"
	b.level = lvl
	b.job = String(opts.get("job", "tech"))
	b.swallowed = bool(opts.get("swallowed", false))
	b.add_to_group("bodies")
	b._build(int(opts.get("seed", randi())), bool(opts.get("female", randf() < 0.45)), String(opts.get("pose", "Death01")))
	return b


func _build(seed: int, p_female: bool, pose_clip: String) -> void:
	female = p_female
	look_seed = seed
	crew = Crew.make(job, female, seed)
	add_child(crew)
	crew.set_instance("dead", 1.0)
	crew.set_instance("blood", 0.7)
	crew.pose(pose_clip, 1.0)
	if swallowed:
		crew.position.y = -0.12
		crew.set_instance("bloom", 0.45)
		for i in 5:
			var m := MeshInstance3D.new()
			m.mesh = Flesh.lump_mesh(randf_range(0.15, 0.3), seed + i)
			m.material_override = Flesh.material("lump")
			m.position = Vector3(randf_range(-0.5, 0.5), 0.02, randf_range(-0.9, 0.4))
			m.scale = Vector3(1.4, 0.45, 1.4)
			add_child(m)


func _ready() -> void:
	Gore.pool(self, global_position + Vector3(0, 0.02, -0.3), 1.8)


## The tile it lies on.
func cell() -> Vector2i:
	return DeckLevel.cell_at(global_position)
