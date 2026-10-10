class_name ShiftLevel
extends DeckLevel
## A deck for Shift mode, built from its DeckDef's seed out of the same
## pieces as the campaign's decks: a lobby with the lift, a spine corridor
## north with rooms either side, a nest room across the top, and an outer
## corridor down the east side that loops back, so there's always a second
## way round the growth.

## Room kinds: [style, name, props to scatter, crew jobs found there].
const KINDS := [
	["crew", "Bunks", ["ess:Prop_Locker", "ess:Prop_Chair", "ess:Prop_Shelves_WideShort"], ["tech", "cook"]],
	["crew", "Mess", ["ess:Prop_Desk_Medium", "ess:Prop_Chair", "ess:Prop_Mug"], ["cook", "tech"]],
	["hydro", "Grow room", ["Prop_Barrel_Large", "ess:Prop_Shelves_ThinTall"], ["botanist"]],
	["lab", "Lab", ["ess:Prop_Desk_Medium", "ess:Prop_Computer", "ess:Prop_HologramMap1", "Prop_Pod"], ["science"]],
	["medical", "Sick bay", ["ess:Prop_Desk_Medium", "ess:Prop_Locker", "ess:Prop_Shelves_ThinTall"], ["medic"]],
	["security", "Guard post", ["ess:Prop_Locker", "ess:Prop_Desk_Medium", "ess:Prop_Computer"], ["security"]],
	["engine", "Pump room", ["Prop_Barrel_Large", "Prop_PipeHolder", "Prop_Pod_Short"], ["engineer"]],
	["cargo", "Stores", ["ess:Prop_Crate", "ess:Prop_Crate_Tarp", "ess:Prop_Shelves_WideTall", "Prop_Crate4"], ["cargo"]],
]
const NEST_STYLES := ["core", "lab", "hydro", "engine"]
const FIRST_NAMES := ["Ada", "Bram", "Cleo", "Dev", "Ema", "Finn", "Gus", "Hana", "Ivo", "Juno", "Kit", "Lena", "Milo", "Nell", "Oren", "Pia", "Rafe", "Sana", "Teo", "Vera"]
const LAST_NAMES := ["Abara", "Brook", "Castell", "Dane", "Erikson", "Fonseca", "Grant", "Holm", "Ibsen", "Juarez", "Kaur", "Lund", "Moreau", "Novak", "Okoro", "Price", "Quill", "Reyes", "Sato", "Tran"]
const LINES := [
	"Is it gone? Is it actually gone? I'll follow you. Don't go fast.",
	"I sealed myself in here hours ago. I could hear it on the other side of the door.",
	"You're real. Okay. Okay. Get me to the lift.",
	"I've got a cutter burn on my hand and I'm not even sorry. Let's go.",
]
const LOGS := [
	["Shift note", "Whoever's on after me: the floor in %s is warm again. Not the heating. I checked the heating.\n\nI've closed the door. Leave it closed."],
	["Maintenance ticket", "Ticket: vent pressure low in %s. Cause: organic obstruction.\n\nTicket: lights failing in %s. Cause: organic obstruction.\n\nAll tickets assigned to: night shift."],
	["Message, unsent", "I keep telling them it moved. Not grew, moved. It was by the door in %s at the start of my shift and by the vent at the end.\n\nThey told me to get some sleep."],
]

var rooms_made: Array[String] = []


func build() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = deck.seed if deck else 1
	rng.seed = r.seed
	var length := r.randi_range(8, 11)
	# The lobby and the lift, the spine, the nest across the top.
	room("lobby", "Lift lobby", Rect2i(-1, 0, 3, 2), "corridor")
	lift(Vector2i(0, 1), "S")
	corridor("spine", "Main corridor", Vector2i(0, -1), Vector2i(0, -length), "corridor")
	arch(Vector2i(0, 0), Vector2i(0, -1))
	var nest_style: String = NEST_STYLES[r.randi() % NEST_STYLES.size()]
	room("nest", "Nest", Rect2i(-2, -length - 3, 8, 3), nest_style, {"warm": 1.4, "dark": true})
	door(Vector2i(0, -length), Vector2i(0, -length - 1))
	# Rooms down both sides of the spine; the east ones are four wide so the
	# outer corridor meets them.
	var west := _side(r, -1, length)
	var east := _side(r, 1, length)
	corridor("outer", "Outer corridor", Vector2i(5, -1), Vector2i(5, -length), "window" if r.randf() < 0.6 else "corridor")
	arch(Vector2i(5, -length), Vector2i(5, -length - 1))
	for id in east:
		var cells: Array = rooms[id]["cells"]
		var c: Vector2i = cells[r.randi() % cells.size()]
		door(Vector2i(4, c.y), Vector2i(5, c.y), {"open": r.randf() < 0.3})
	# Vents across the spine and a cable to the nest.
	for k in 2:
		if not west.is_empty() and not east.is_empty():
			var a: String = west[r.randi() % west.size()]
			var b: String = east[r.randi() % east.size()]
			vent(rooms[a]["cells"][0], rooms[b]["cells"][0])
	cable(Vector2i(0, -length + 1), Vector2i(0, -length - 2))
	# The root, and the growth round it.
	var nest_cell := Vector2i(r.randi_range(-1, 4), -length - 2)
	root(nest_cell)
	grow_room("nest", 3.6)
	for i in 3:
		grow(Vector2i(0, -length + i), 2.4 - i * 0.7)
	var warm: Array = west + east
	warm.shuffle()
	for k in mini(2, warm.size()):
		grow_room(warm[k], r.randf_range(1.2, 2.6))
	_fill(r)
	_views(length)


## Rooms down one side of the spine (`dir` -1 west, 1 east), each with a
## door onto it. Returns their ids.
func _side(r: RandomNumberGenerator, dir: int, length: int) -> Array:
	var out := []
	var z := -1
	var n := 0
	while z > -length:
		var h := mini(r.randi_range(2, 3), z + length)
		if h < 2:
			break
		var w := 4 if dir > 0 else r.randi_range(2, 4)
		var x0 := 1 if dir > 0 else -w
		var kind: Array = KINDS[r.randi() % KINDS.size()]
		var id := "%s_%d" % ["east" if dir > 0 else "west", n]
		var opts := {}
		if r.randf() < 0.25:
			opts["dark"] = true
		if kind[0] == "hydro":
			opts["warm"] = 1.4
		room(id, kind[1], Rect2i(x0, z - h + 1, w, h), kind[0], opts)
		rooms[id]["kind"] = kind
		var dz := z - r.randi_range(0, h - 1)
		var dopts := {}
		if r.randf() < 0.12:
			dopts["sealed"] = true
		elif r.randf() < 0.2:
			dopts["open"] = true
		door(Vector2i(0, dz), Vector2i(dir, dz), dopts)
		out.append(id)
		rooms_made.append(id)
		n += 1
		z -= h + (1 if r.randf() < 0.25 else 0)
	return out


## Props, pickups, bodies, logs, survivors and what's waiting in each room.
func _fill(r: RandomNumberGenerator) -> void:
	thing("workbench", Vector2i(-1, 0), Vector3(0, 0, -1.3), 0.0)
	thing("bunk", Vector2i(1, 0), Vector3(0.6, 0, -0.8), 0.0)
	pickup("flare", Vector2i(-1, 1), Vector3(0.3, 0, 0.4), 2)
	var survivors := 0
	var logs := 0
	for id in rooms_made:
		var kind: Array = rooms[id]["kind"]
		var cells: Array = rooms[id]["cells"]
		for k in mini(cells.size(), 4):
			var c: Vector2i = cells[r.randi() % cells.size()]
			var props: Array = kind[2]
			var off := Vector3(r.randf_range(-1.3, 1.3), 0, r.randf_range(-1.3, 1.3))
			var p: String = props[r.randi() % props.size()]
			var o := {"solid": not p.ends_with("Mug")}
			prop(p, c, off, r.randf_range(0, 360), o)
		var c0: Vector2i = cells[r.randi() % cells.size()]
		match r.randi() % 5:
			0:
				pickup("ammo:scattergun", c0, Vector3(0.8, 0, 0.8), 6)
			1:
				pickup("medkit", c0, Vector3(-0.8, 0, 0.6), 1)
			2:
				pickup("health", c0, Vector3(0.6, 0, -0.8), 1)
			3:
				pickup("salvage", c0, Vector3(-0.6, 0, -0.6), r.randi_range(1, 3))
			_:
				pickup("ammo:rifle", c0, Vector3(0.7, 0, 0.7), 20)
		var jobs: Array = kind[3]
		if r.randf() < 0.55:
			body(cells[r.randi() % cells.size()], Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)), r.randf_range(0, 360), jobs[r.randi() % jobs.size()])
		if r.randf() < 0.4:
			spawn("taken", cells[r.randi() % cells.size()], Vector3(0.5, 0, 0.5), 1, {"job": jobs[r.randi() % jobs.size()]})
		elif r.randf() < 0.5:
			spawn("skitter", cells[r.randi() % cells.size()], Vector3.ZERO, r.randi_range(1, 2), {"asleep": true})
		if kind[0] == "security" and r.randf() < 0.6:
			spawn(["eyedrone", "quadorb", "gundrone"][r.randi() % 3], cells[r.randi() % cells.size()], Vector3.ZERO, 1, {"asleep": true})
		if logs < 3 and r.randf() < 0.5:
			var l: Array = LOGS[logs % LOGS.size()]
			var where: String = rooms[id]["name"].to_lower()
			# Always draw the name, so the rest of the station comes out the same.
			var by := _name_from(r)
			if l[0] == "Maintenance ticket":
				by = "MARI"
			log_entry("shift_%d_%d" % [deck.seed if deck else 0, logs], l[0], l[1].replace("%s", "the " + where), cells[0], Vector3(1.2, 0, 1.2), 0.0, by)
			logs += 1
		if survivors < 2 and r.randf() < 0.3:
			var who := _name_from(r)
			survivor("shift_%d_s%d" % [deck.seed if deck else 0, survivors], who, cells[cells.size() - 1], LINES[r.randi() % LINES.size()], Vector3(0.6, 0, 0.6), r.randf_range(0, 360), jobs[r.randi() % jobs.size()])
			survivors += 1
	# The nest: pods, a body being taken, something guarding the root.
	var nest: Array = rooms["nest"]["cells"]
	spawn("pod", nest[0], Vector3(0.4, 0, 0.4), 1)
	spawn("pod", nest[nest.size() - 1], Vector3(-0.4, 0, -0.4), 1)
	spawn(["stalker", "feeder", "watcher"][r.randi() % 3], nest[nest.size() / 2], Vector3.ZERO, 1, {"asleep": true})
	pickup("cell", nest[r.randi() % nest.size()], Vector3(1.2, 0, 1.2), 1)


func _name_from(r: RandomNumberGenerator) -> String:
	return "%s %s" % [FIRST_NAMES[r.randi() % FIRST_NAMES.size()], LAST_NAMES[r.randi() % LAST_NAMES.size()]]


func _views(length: int) -> void:
	view("arrival", Vector3(0, 1.65, 3.0), 0.0, -3.0)
	view("spine", Vector3(0, 1.65, -6.0), 0.0, -4.0)
	view("nest", Vector3(0, 1.65, -(length + 1) * 4.0 + 1.0), 20.0, -10.0)
	view("outer", Vector3(20.0, 1.65, -4.5), 0.0, -3.0)
	var west: String = rooms_made[0]
	var c: Vector2i = rooms[west]["cells"][0]
	view("first_room", DeckLevel.center(c) + Vector3(1.0, 1.65, 1.0), 45.0, -8.0)
	var last: String = rooms_made[rooms_made.size() - 1]
	var c2: Vector2i = rooms[last]["cells"][0]
	view("last_room", DeckLevel.center(c2) + Vector3(-1.0, 1.65, 1.0), -45.0, -8.0)
