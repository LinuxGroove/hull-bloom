extends DeckLevel
## Security: the lift lobby and the checkpoint, the main corridor north with
## the briefing room, the chief's office and monitoring off it, the brig and
## its three cells, the armoury behind the chief's keycard, the firing range,
## and the robot bay at the top, where the units that came back from
## Hydroponics were docked and the Bloom took root.
##
##   z -11..-9  robot bay (-2..2), root at (0, -11)
##   z -8..-7   firing range (-4..-1)      armoury (1..2, -7..-6), locked
##   z -5..-4   brig (-4..-1) and cells    monitoring (1..3, -4..-3)
##   z -2..-1   briefing room (-3..-1)     chief's office (1..2)
##   z  0..1    checkpoint (-1..1)
##   z -1..-8   main corridor (x 0)
##   z  2..3    lift lobby (-1..1), lift at (0, 3)

const ROOT := Vector2i(0, -11)
const ARMOURY_CARD := Vector2i(1, -2)
const BRIG_CARD := Vector2i(3, -3)

const LOCKDOWN := """Effective 21:40, Security is in lockdown. Every unit holds its post. The armoury is locked to my card. The robots are set to challenge anyone without a badge, so wear yours.

The lifts from Labs and Hydroponics are closed to us. If a member of the crew is acting strangely, do not approach them. Call it in.

Two of the units that came back from Hydroponics are running hot. I'm taking them off the docks and opening them up myself. Nobody else goes into the robot bay."""

const MAINTENANCE := """QO-4. Front left joint seizing. Opened it up: the joint is packed with something soft, grey and pink. Warm to the touch. Cleaned it out and closed it.

QO-4, two hours later. It's back, and more of it. It has grown along the cable runs inside the leg, all the way to the battery.

RP-1. The same, in both hips. Nobody sent RP-1 to the bay. It walked here from Hydroponics on its own and plugged itself into a dock.

Every unit I open has it in the joints, and every one still passes its self-test. The chief says she'll look at them herself."""

const LAST_SHIFT := """22:05. Checkpoint. Nobody down the lift for an hour. The chief's in the robot bay with Jonah.

22:20. Left my badge on the monitoring desk. GD-2 has been following me round the room like it's never seen me before.

22:31. Heard the chief on the radio. Something about the docks. Then nothing.

22:40. Going back for my badge. Ana says she'll talk to the drone."""


func build() -> void:
	default_style("security")
	room("lobby", "Lift lobby", Rect2i(-1, 2, 3, 2), "corridor")
	lift(Vector2i(0, 3), "S")
	room("checkpoint", "Checkpoint", Rect2i(-1, 0, 3, 2))
	door(Vector2i(0, 2), Vector2i(0, 1), {"open": true})
	corridor("spine", "Main corridor", Vector2i(0, -1), Vector2i(0, -8))
	door(Vector2i(0, 0), Vector2i(0, -1))
	room("briefing", "Briefing room", Rect2i(-3, -2, 3, 2))
	door(Vector2i(-1, -2), Vector2i(0, -2))
	room("chief", "Chief's office", Rect2i(1, -2, 2, 2), "crew")
	door(Vector2i(0, -1), Vector2i(1, -1))
	room("monitoring", "Monitoring", Rect2i(1, -4, 3, 2), "lab")
	door(Vector2i(0, -4), Vector2i(1, -4))
	door(Vector2i(2, -3), Vector2i(2, -2))
	corridor("brig", "Brig", Vector2i(-1, -5), Vector2i(-4, -5), "security")
	door(Vector2i(-1, -5), Vector2i(0, -5))
	room("cell_1", "Cell 1", Rect2i(-2, -4, 1, 1))
	door(Vector2i(-2, -4), Vector2i(-2, -5), {"open": true})
	room("cell_2", "Cell 2", Rect2i(-3, -4, 1, 1))
	door(Vector2i(-3, -4), Vector2i(-3, -5))
	room("cell_3", "Cell 3", Rect2i(-4, -4, 1, 1))
	door(Vector2i(-4, -4), Vector2i(-4, -5), {"locked": "brig"})
	room("armoury", "Armoury", Rect2i(1, -7, 2, 2))
	door(Vector2i(0, -6), Vector2i(1, -6), {"locked": "armoury"})
	room("range", "Firing range", Rect2i(-4, -8, 4, 2), "cargo")
	door(Vector2i(-1, -7), Vector2i(0, -7))
	room("bay", "Robot bay", Rect2i(-2, -11, 5, 3), "engine", {"warm": 1.2})
	door(Vector2i(0, -8), Vector2i(0, -9), {"jammed": true})
	door(Vector2i(-2, -8), Vector2i(-2, -9))
	# Service ducts out of the bay, and a cable run into the armoury.
	vent(Vector2i(-2, -10), Vector2i(-4, -5))
	vent(Vector2i(2, -10), Vector2i(3, -3))
	cable(Vector2i(1, -9), Vector2i(1, -7))
	root(ROOT)
	grow_room("bay", 3.3)
	grow(ROOT, 4.0)
	grow(Vector2i(-1, -11), 3.7)
	grow(Vector2i(1, -11), 3.7)
	grow(Vector2i(0, -8), 2.2)
	grow(Vector2i(0, -7), 1.3)
	grow(Vector2i(0, -6), 0.6)
	grow(Vector2i(-2, -8), 2.0)
	grow(Vector2i(-3, -8), 1.2)
	grow(Vector2i(-1, -8), 1.1)
	grow(Vector2i(-2, -7), 0.6)
	_lobby()
	_checkpoint()
	_spine()
	_briefing()
	_chief()
	_monitoring()
	_brig()
	_armoury()
	_range()
	_bay()
	_views()


func _lobby() -> void:
	thing("workbench", Vector2i(-1, 2), Vector3(0, 0, -1.3), 0.0)
	thing("bunk", Vector2i(1, 2), Vector3(0.6, 0, -0.8), 0.0)
	prop("ess:Prop_Locker", Vector2i(-1, 3), Vector3(-1.45, 0, 0.6), 90.0)
	prop("ess:Prop_Locker", Vector2i(-1, 3), Vector3(-1.45, 0, -0.5), 90.0)
	pickup("flare", Vector2i(1, 3), Vector3(1.0, 0, 0.8), 2)
	thing("decal", Vector2i(0, 2), Vector3(0, 0, -0.6), 0.0, {"name": "Decal_Arrows"})


func _checkpoint() -> void:
	# The scanner gate between the lift and the corridor.
	for x in [-1.5, 1.5]:
		prop("Column_Hollow", Vector2i(0, 0), Vector3(x, 0, 1.0), 0.0, {"scale": 0.5})
	thing("decal", Vector2i(0, 0), Vector3(0, 0, 1.0), 0.0, {"name": "Decal_Authorized"})
	prop("ess:Prop_Desk_L", Vector2i(-1, 0), Vector3(-0.3, 0, -0.3), 90.0)
	prop("ess:Prop_Chair", Vector2i(-1, 0), Vector3(0.2, 0, 0.6), -150.0)
	prop("ess:Prop_Screen", Vector2i(-1, 0), Vector3(-1.0, 0.94, -0.6), 90.0, {"solid": false})
	prop("ess:Prop_Locker", Vector2i(1, 1), Vector3(1.45, 0, 0.6), -90.0)
	prop("ess:Prop_Locker", Vector2i(1, 1), Vector3(1.45, 0, -0.45), -90.0)
	prop("ess:Prop_GunRack", Vector2i(1, 0), Vector3(1.3, 0, -0.6), -90.0)
	pickup("medkit", Vector2i(-1, 0), Vector3(-0.9, 0.94, 0.2), 1)
	pickup("ammo", Vector2i(1, 0), Vector3(0.6, 0, 0.9), 2)
	spawn("taken", Vector2i(1, 0), Vector3(-0.4, 0, -0.6), 1, {"job": "security",
		"routine": [Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 0), Vector2i(0, -1), Vector2i(0, -2)]})


func _spine() -> void:
	for z in [-1, -3, -5, -7]:
		thing("decal", Vector2i(0, z), Vector3.ZERO, 0.0, {"name": "Decal_Line_Straight"})
	thing("turret", Vector2i(0, -3), Vector3(1.3, 0, 0.6), 0.0)
	body(Vector2i(0, -4), Vector3(-0.7, 0, 0.6), 200.0, "security")
	thing("log", Vector2i(0, -4), Vector3(-1.2, 0, 1.3), 40.0, {"id": "sec_lastshift", "title": "Last shift",
		"by": "Officer Kemal Arslan, security", "text": LAST_SHIFT})
	prop("Prop_Crate2", Vector2i(0, -1), Vector3(-1.4, 0.5, -0.5), 10.0)
	prop("Prop_Barrel_Large", Vector2i(0, -5), Vector3(1.45, 0, 1.2))
	pickup("health", Vector2i(0, -5), Vector3(1.3, 0, 0.4), 1)
	thing("decal", Vector2i(0, -6), Vector3(0.9, 0, 0), 90.0, {"name": "Decal_Caution"})
	# RP-2 still guards the armoury door.
	spawn("raptor", Vector2i(0, -6), Vector3(-0.5, 0, 0.2), 1)


func _briefing() -> void:
	prop("ess:Prop_HologramMap2", Vector2i(-3, -2), Vector3(-0.7, 0, 2.0), 90.0)
	for x in [-2, -1]:
		for dz in [-0.9, 0.9]:
			for z in [-2, -1]:
				prop("ess:Prop_Chair", Vector2i(x, z), Vector3(-0.3, 0, dz), -90.0)
	prop("ess:Prop_Shelves_WideShort", Vector2i(-2, -1), Vector3(0, 0, 1.5), 180.0)
	body(Vector2i(-3, -1), Vector3(0.9, 0, 0.6), 60.0, "security")
	pickup("ammo:scattergun", Vector2i(-2, -1), Vector3(0.2, 1.22, 1.5), 2)
	pickup("salvage", Vector2i(-1, -2), Vector3(0.8, 0, -1.3), 1)
	spawn("eyedrone", Vector2i(-2, -2), Vector3(0, 0, 0.6), 1)


func _chief() -> void:
	prop("ess:Prop_Desk_Medium", Vector2i(1, -2), Vector3(0, 0, -1.25))
	prop("ess:Prop_Chair", Vector2i(1, -2), Vector3(0.3, 0, -0.2), 160.0)
	prop("ess:Prop_Screen", Vector2i(1, -2), Vector3(-0.3, 0.94, -1.45), 0.0, {"solid": false})
	thing("log", Vector2i(1, -2), Vector3(0.7, 0.94, -1.4), 0.0, {"id": "sec_lockdown", "style": "screen", "title": "Lockdown order",
		"by": "Chief Marta Kessler, security", "text": LOCKDOWN})
	pickup("keycard:armoury", ARMOURY_CARD, Vector3(-1.0, 0.95, -1.1), 1)
	prop("ess:Prop_GunRack", Vector2i(2, -1), Vector3(0.2, 0, 1.35), 180.0)
	prop("ess:Prop_Locker", Vector2i(2, -1), Vector3(1.45, 0, -0.3), -90.0)
	prop("ess:Prop_Shelves_ThinTall", Vector2i(2, -2), Vector3(1.45, 0, 0.5), -90.0)
	pickup("medkit", Vector2i(2, -1), Vector3(0.9, 0, 0.6), 1)
	pickup("salvage", Vector2i(1, -1), Vector3(-0.5, 0, 1.2), 1)
	# The chief, still going back to her armoury.
	spawn("taken", Vector2i(2, -1), Vector3(-0.5, 0, -0.3), 1, {"job": "security", "female": true,
		"routine": [Vector2i(2, -1), Vector2i(1, -2), Vector2i(0, -1), Vector2i(0, -3), Vector2i(0, -5), Vector2i(0, -6)]})


func _monitoring() -> void:
	for x in [1, 2, 3]:
		prop("Prop_Computer", Vector2i(x, -4), Vector3(-0.5, 0, -1.45))
		prop("Prop_Computer", Vector2i(x, -4), Vector3(0.4, 0, -1.45))
	prop("ess:Prop_CeilingComputer", Vector2i(2, -4), Vector3(0, Kit.HEIGHT, 0.4), 180.0, {"solid": false})
	prop("ess:Prop_Desk_Medium", Vector2i(3, -3), Vector3(0, 0, 1.2), 180.0)
	prop("ess:Prop_Screen", Vector2i(3, -3), Vector3(-0.6, 0.94, 1.4), 180.0, {"solid": false})
	prop("ess:Prop_Screen", Vector2i(3, -3), Vector3(0.6, 0.94, 1.4), 180.0, {"solid": false})
	prop("ess:Prop_Chair", Vector2i(3, -3), Vector3(0.6, 0, 0.3), 10.0)
	prop("ess:Prop_HologramMap1", Vector2i(2, -3), Vector3(-0.3, 0, -0.8))
	pickup("keycard:brig", BRIG_CARD, Vector3(0.0, 0.95, 1.1), 1)
	pickup("salvage", Vector2i(1, -3), Vector3(-0.8, 0, 1.2), 1)
	thing("survivor", Vector2i(3, -3), Vector3(-1.3, 0, 0.0), -90.0, {"id": "sec_ruiz", "name": "Ana Ruiz",
		"line": "It won't shoot me, I've got my badge on. Kemal went back for his and it's still on the desk. Get me to the lift.",
		"job": "security", "pose": "crouch", "female": true})
	spawn("gundrone", Vector2i(2, -4), Vector3(0, 0, 0.6), 1)


func _brig() -> void:
	thing("turret", Vector2i(-1, -5), Vector3(0.4, 0, -1.2), 90.0)
	thing("decal", Vector2i(-2, -5), Vector3.ZERO, 90.0, {"name": "Decal_Line_Straight"})
	thing("decal", Vector2i(-3, -5), Vector3.ZERO, 90.0, {"name": "Decal_Line_Straight"})
	for x in [-2, -3, -4]:
		prop("Prop_Chest", Vector2i(x, -4), Vector3(0, 0, 1.3), 180.0)
	thing("body", Vector2i(-2, -4), Vector3(0.3, 0, -0.2), 120.0, {"job": "cargo"})
	pickup("cell", Vector2i(-2, -4), Vector3(-0.8, 0, 0.6), 1)
	pickup("health", Vector2i(-4, -5), Vector3(-1.2, 0, -1.0), 1)
	spawn("taken", Vector2i(-3, -4), Vector3(0.2, 0, -0.2), 1, {"job": "cargo"})
	spawn("trilobite", Vector2i(-3, -5), Vector3.ZERO, 1, {"asleep": true})
	thing("survivor", Vector2i(-4, -4), Vector3(0.3, 0, 0.6), 180.0, {"id": "sec_petrov", "name": "Luka Petrov",
		"line": "You found the card. I locked myself in when the robots turned. Cell doors are the only ones they won't open. I'll make for the lift.",
		"job": "security", "pose": "fold"})


func _armoury() -> void:
	prop("ess:Prop_GunRack", Vector2i(1, -7), Vector3(0, 0, -1.3))
	prop("ess:Prop_GunRack", Vector2i(2, -7), Vector3(-0.3, 0, -1.3))
	prop("ess:Prop_Locker", Vector2i(2, -7), Vector3(1.45, 0, 0.3), -90.0)
	prop("ess:Prop_Locker", Vector2i(2, -6), Vector3(1.45, 0, -0.6), -90.0)
	prop("ess:Prop_Desk_Large", Vector2i(1, -6), Vector3(2.0, 0, 0.6))
	prop("ess:Prop_Ammo_Closed", Vector2i(1, -7), Vector3(0.9, 0, 0.3), 10.0)
	prop("ess:Prop_Ammo_Closed", Vector2i(2, -6), Vector3(1.0, 0, 1.4), -5.0)
	prop("ess:Prop_Ammo", Vector2i(2, -7), Vector3(-0.6, 0, 0.2), -20.0)
	thing("pickup", Vector2i(1, -6), Vector3(0.9, 1.0, 0.6), 0.0, {"item": "weapon:rifle", "count": 1})
	thing("pickup", Vector2i(2, -6), Vector3(-0.9, 1.0, 0.6), 0.0, {"item": "weapon:smg", "count": 1})
	pickup("ammo:rifle", Vector2i(1, -6), Vector3(0.0, 1.0, 0.6), 3)
	pickup("ammo:smg", Vector2i(2, -6), Vector3(0.1, 1.0, 0.6), 3)
	pickup("ammo:rifle", Vector2i(1, -7), Vector3(-0.3, 0, -0.3), 2)
	pickup("grenade", Vector2i(2, -7), Vector3(0.6, 0, -0.5), 2)
	pickup("mine", Vector2i(1, -7), Vector3(-0.8, 0, 0.3), 2)
	pickup("salvage", Vector2i(2, -6), Vector3(0.6, 0, -0.6), 2)


func _range() -> void:
	prop("ess:Prop_Desk_Medium", Vector2i(-1, -8), Vector3(-0.8, 0, -0.2), 90.0)
	for z in [-8, -7]:
		for dz in [-1.0, 1.0]:
			thing("decal", Vector2i(-2, z), Vector3(0, 0, dz), 90.0, {"name": "Decal_Line_Straight"})
			thing("decal", Vector2i(-3, z), Vector3(0, 0, dz), 90.0, {"name": "Decal_Line_Straight"})
	thing("turret", Vector2i(-1, -7), Vector3(-0.2, 0, 1.4), 90.0)
	prop("ess:Prop_Ammo", Vector2i(-1, -8), Vector3(-0.8, 0.94, 0.4), 90.0, {"solid": false})
	pickup("ammo:scattergun", Vector2i(-1, -8), Vector3(-0.8, 0.94, -0.6), 2)
	pickup("salvage", Vector2i(-4, -7), Vector3(0.2, 0, 1.2), 1)
	spawn("skitter", Vector2i(-4, -8), Vector3(0.6, 0, 0.6), 2, {"asleep": true})


func _bay() -> void:
	prop("ess:Prop_Desk_Large", Vector2i(-2, -10), Vector3(-0.9, 0, 0), 90.0)
	thing("log", Vector2i(-2, -10), Vector3(-0.9, 1.0, 0.5), 70.0, {"id": "sec_maintenance", "title": "Robot maintenance log",
		"by": "Jonah Reyes, robotics", "text": MAINTENANCE})
	body(Vector2i(-1, -9), Vector3(0.2, 0, 0.3), 260.0, "engineer")
	prop("Prop_Chest", Vector2i(2, -9), Vector3(1.1, 0, 0.9), -90.0)
	prop("Prop_Crate3", Vector2i(2, -9), Vector3(1.3, 0.5, -0.9), 15.0)
	prop("Prop_Crate1", Vector2i(2, -9), Vector3(1.35, 1.5, -0.85), 5.0)
	prop("ess:Prop_Barrel2_Closed", Vector2i(-2, -9), Vector3(-1.4, 0, -0.8))
	prop("Prop_Pipe_Thick_Straight", Vector2i(-1, -10), Vector3(0, 4.3, 0), 90.0, {"solid": false})
	prop("Prop_Pipe_Thick_Straight", Vector2i(1, -10), Vector3(0, 4.3, 0), 90.0, {"solid": false})
	pickup("health", Vector2i(1, -9), Vector3(1.0, 0, 1.2), 1)
	pickup("salvage", Vector2i(2, -11), Vector3(1.2, 0, 1.2), 2)
	pickup("salvage", Vector2i(-2, -11), Vector3(-1.2, 0, 1.3), 1)
	# QO-4 and QS-5 on their docks, the Bloom in their joints.
	spawn("quadorb", Vector2i(-2, -11), Vector3(0.0, 0, -0.3), 1, {"asleep": true})
	spawn("quadshell", Vector2i(2, -11), Vector3(0.0, 0, -0.3), 1, {"asleep": true})
	spawn("pod", Vector2i(-1, -10), Vector3(-0.5, 0, -0.6), 1)
	spawn("pod", Vector2i(1, -9), Vector3(-0.7, 0, -0.4), 1)


func _views() -> void:
	view("arrival", Vector3(0, 1.65, 9.5), 0.0, -3.0)
	view("checkpoint", Vector3(4.0, 1.65, 5.0), 32.0, -8.0)
	view("corridor", Vector3(0, 1.65, -2.5), 0.0, -2.0)
	view("briefing_room", Vector3(-13.2, 1.65, -2.8), -60.0, -10.0)
	view("chiefs_office", Vector3(3.0, 1.65, -3.0), -38.0, -10.0)
	view("monitoring", Vector3(3.0, 1.65, -11.0), -65.0, -8.0)
	view("brig", Vector3(-17.4, 1.65, -20.4), -90.0, -2.0)
	view("cell", Vector3(-8.0, 1.65, -20.6), 180.0, -14.0)
	view("armoury", Vector3(9.0, 1.65, -22.8), 45.0, -12.0)
	view("firing_range", Vector3(-3.0, 1.65, -28.5), 90.0, -4.0)
	view("robot_bay", Vector3(7.0, 1.65, -35.0), 40.0, -6.0)
	view("robot_docks", Vector3(-2.5, 1.65, -36.0), 35.0, -8.0)


func decorate() -> void:
	for d in [[Vector2i(-2, -11), 0.0], [Vector2i(2, -11), 0.0], [Vector2i(2, -10), -PI * 0.5]]:
		dock(self, DeckLevel.center(d[0]), d[1])
	for i in 3:
		target(self, DeckLevel.center(Vector2i(-4, -8)) + Vector3(-1.2, 0, 1.0 + i * 2.0 - 2.0), PI * 0.5)
	Fittings.cocoon(self, DeckLevel.center(Vector2i(0, -11)) + Vector3(-1.5, 0, -1.4), PI * 0.2, 51)
	Fittings.drag(self, DeckLevel.center(Vector2i(0, -6)), DeckLevel.center(Vector2i(0, -9)))
	Fittings.drag(self, DeckLevel.center(Vector2i(-1, -9)) + Vector3(0.2, 0, 0.3), DeckLevel.center(Vector2i(-1, -10)))


## A robot's charging dock: a pad on the floor against a wall (`yaw` turns
## it; 0 has the wall to the north), the charger on the wall and its cable.
static func dock(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Dock"
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var pad := Kit.model(root, "Platform_Round2", Vector3(0, 0.01, -0.3))
	pad.scale = Vector3(0.42, 0.6, 0.42)
	Kit.model(root, "Prop_AccessPoint", Vector3(0, 0, -1.55), -PI * 0.5)
	Kit.model(root, "Prop_Light_Floor", Vector3(0, 0.02, 0.85))
	var cable := Kit.model(root, "Prop_Cable1", Vector3(0.7, 0.01, -1.0), PI * 0.1)
	cable.scale = Vector3.ONE * 0.8
	return root


## A target board on a stand for the firing range, facing along `yaw`'s
## forward (0 faces south).
static func target(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var root := StaticBody3D.new()
	root.name = "Target"
	root.collision_layer = Kit.LAYER_STATION
	root.collision_mask = 0
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var dark := Kit.flat(Color(0.12, 0.13, 0.14), 0.6)
	_box(root, Vector3(0, 0.03, 0), Vector3(0.7, 0.06, 0.5), dark)
	_box(root, Vector3(0, 0.6, 0), Vector3(0.07, 1.2, 0.07), dark)
	_box(root, Vector3(0, 1.45, 0), Vector3(0.75, 0.95, 0.04), Kit.flat(Color(0.85, 0.82, 0.74), 0.8))
	for r in [[0.3, Color(0.75, 0.12, 0.08)], [0.2, Color(0.85, 0.82, 0.74)], [0.1, Color(0.75, 0.12, 0.08)]]:
		var ring := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = r[0]
		c.bottom_radius = r[0]
		c.height = 0.01
		ring.mesh = c
		ring.material_override = Kit.flat(r[1], 0.8)
		ring.rotation.x = PI * 0.5
		ring.position = Vector3(0, 1.5, 0.025 + (0.3 - r[0]) * 0.02)
		root.add_child(ring)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.75, 1.9, 0.3)
	cs.shape = shape
	cs.position = Vector3(0, 0.95, 0)
	root.add_child(cs)
	return root


static func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = at
	parent.add_child(m)
