class_name Survivor
extends UsableBody
## One of the crew, still alive and hiding. Talk to them and they make their
## way to the lift; anyone waiting at the lift when you leave is saved.

signal found(s: Survivor)

const POSES := {"sit": "Sitting_Idle", "crouch": "Crouch_Idle", "fold": "Idle_FoldArms", "kneel": "Fixing_Kneeling", "stand": "Idle", "phone": "Idle_TalkingPhone", "torch": "Idle_Torch"}
const WALK := 1.5

var survivor_id := ""
var person := ""
var line := ""
var job := "tech"
var level: DeckLevel
var crew: Crew
var is_found := false
var at_lift := false
var _path: Array = []
var _pose := "Crouch_Idle"
var _waiting := 0.0


static func make(lvl: DeckLevel, opts: Dictionary) -> Survivor:
	var s := Survivor.new()
	s.level = lvl
	s.survivor_id = String(opts.get("id", "survivor"))
	s.name = "Survivor_" + s.survivor_id
	s.person = String(opts.get("name", "A survivor"))
	s.line = String(opts.get("line", "Thank god. I'll head for the lift."))
	s.job = String(opts.get("job", "tech"))
	s._pose = POSES.get(String(opts.get("pose", "crouch")), "Crouch_Idle")
	s.add_to_group("survivors")
	s._build(bool(opts.get("female", false)), int(opts.get("seed", hash(s.survivor_id))))
	return s


func _build(female: bool, seed: int) -> void:
	collision_layer = Kit.LAYER_INTERACT | Kit.LAYER_CREATURES
	display_name = person
	crew = Crew.make(job, female, seed)
	add_child(crew)
	crew.set_instance("blood", 0.15)
	crew.play(_pose)
	add_box(Vector3(0, 0.9, 0), Vector3(0.6, 1.8, 0.6))
	add_action("interact", "Talk to " + person, _talk)


func _talk(_pic: Node) -> void:
	if is_found:
		if DeckScene.current:
			DeckScene.current.say(person, "I'll be at the lift.", survivor_id)
		return
	is_found = true
	set_action_text("interact", "Talk to " + person)
	if DeckScene.current:
		DeckScene.current.say(person, line, survivor_id)
	found.emit(self)
	_head_for_lift()


func _head_for_lift() -> void:
	if level == null:
		return
	_path.clear()
	var from := DeckLevel.cell_at(global_position)
	var steps := level.tile_path(from, level.lift_cell, false, false)
	if steps.is_empty() and from != level.lift_cell:
		_waiting = 4.0
		return
	var prev := from
	for s in steps:
		var c: Vector2i = s[0]
		_path.append((DeckLevel.center(prev) + DeckLevel.center(c)) * 0.5)
		prev = c
	var side := Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
	_path.append(DeckLevel.center(level.lift_cell) + side)


func _physics_process(delta: float) -> void:
	if not is_found or at_lift:
		return
	if _path.is_empty():
		if _waiting > 0.0:
			_waiting -= delta
			if _waiting <= 0.0:
				_head_for_lift()
			crew.play("Idle")
			return
		at_lift = DeckLevel.cell_at(global_position) == level.lift_cell
		if at_lift:
			crew.play("Idle_FoldArms")
		else:
			_waiting = 3.0
		return
	var wp: Vector3 = _path[0]
	var d := wp - global_position
	d.y = 0
	# Wait for a shut door in the way.
	var cell_here := DeckLevel.cell_at(global_position)
	var cell_next := DeckLevel.cell_at(global_position + d.normalized() * 1.0)
	if cell_next != cell_here:
		var key := DeckLevel.edge_key(cell_here, cell_next)
		if level.doors.has(key) and not level.doors[key].passable():
			crew.play("Idle")
			_waiting = 2.0
			_path.clear()
			return
	if d.length() < 0.3:
		_path.pop_front()
		return
	var step := d.normalized() * WALK * delta
	global_position += step
	rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), clampf(delta * 6.0, 0.0, 1.0))
	crew.play("Walk")
