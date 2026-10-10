extends DeckLevel
## The Core: the station's spine, where every deck's feed meets. A ring
## corridor runs round the sample chamber, where SV-3 grew into the Heart.
## Two ways lead in from the ring: decontamination on the west, the
## conduits on the east, where the feeds' cables run to the centre and the
## growth came along them. Round the outside: MARI's server hall, the
## observation room, and rooms from every part of the station that the
## Bloom grew in here.
##
##   z -5..-4   security post (-5..-4, -4..-3)    observation (0, -4) and (-1..1, -5)
##   z -3       north ring (-3..3)
##   z -2..2    west ring (x -3) | decontamination (-2) | sample chamber (-1..1), root (0, 0)
##              | conduits (2) | east ring (x 3) | MARI core (4..5, -1..1)
##              nutrient junction (-5..-4, -1..1) off the west ring
##   z  3       south ring (-3..3), window onto the chamber at (0, 3)
##   z  3..4    night crew rest (-5..-4)          core stores (4..5)
##   z  4..5    lift lobby (-1..1), lift at (0, 5)

## The two bulkheads where the south ring meets the west and east rings:
## seal either and the other way round still leads to the Heart.
const RING_DOORS := [[Vector2i(-3, 3), Vector2i(-3, 2)], [Vector2i(3, 3), Vector2i(3, 2)]]
const ROOT := Vector2i(0, 0)

const MARI_LOG := """21:40. Hydroponics stopped answering. Organic obstruction in the seed lab. Ticket raised.

22:10. Organic obstruction in the nutrient, air and water feeds and the power conduits, on every deck. Every feed on Marigold passes through the Core. The obstruction is following them here.

22:31. I have lowered the temperature in this hall to protect my servers. The obstruction grows slowly in the cold.

23:02. Dr Okafor asked me to open the sample chamber, and I did. Her badge is still reading in there. Her heart rate is 31 beats a minute, very steady. So is the room's. I have logged both as sensor faults."""

const OKAFOR_LOG := """Day 22. Station rules: every off-world sample goes to the Core's sample chamber, the deepest containment we have. I sent SV-3's case down on day 2 and kept a few spores for the seed vault. Everything upstairs grew from those few.

The rest has had three weeks down here, at the end of every feed on the station. Water, nutrients, air, power. It never needed to find a way out. We built it a hundred.

MARI says the chamber is reading a pulse. I'm going in. I need to see what it is before anyone burns it.

If I'm not back through this door in an hour, burn it anyway."""


func build() -> void:
	default_style("core")
	_layout()
	_growth()
	_lobby()
	_rings()
	_decon()
	_chamber()
	_conduits()
	_mari_core()
	_observation()
	_junction()
	_security()
	_crew_rest()
	_stores()
	_views()


func _layout() -> void:
	room("lobby", "Core lift lobby", Rect2i(-1, 4, 3, 2))
	lift(Vector2i(0, 5), "S")
	corridor("ring_s", "South ring", Vector2i(-3, 3), Vector2i(3, 3), "core")
	corridor("ring_w", "West ring", Vector2i(-3, -2), Vector2i(-3, 2), "core")
	corridor("ring_n", "North ring", Vector2i(-3, -3), Vector2i(3, -3), "core")
	corridor("ring_e", "East ring", Vector2i(3, -2), Vector2i(3, 2), "core")
	door(Vector2i(0, 4), Vector2i(0, 3))
	for d in RING_DOORS:
		door(d[0], d[1])
	arch(Vector2i(-3, -2), Vector2i(-3, -3))
	arch(Vector2i(3, -2), Vector2i(3, -3))
	room("chamber", "Sample chamber", Rect2i(-1, -2, 3, 5), "core", {"warm": 1.3})
	root(ROOT)
	corridor("decon", "Decontamination", Vector2i(-2, -1), Vector2i(-2, 1), "medical")
	door(Vector2i(-3, 0), Vector2i(-2, 0))
	door(Vector2i(-2, 0), Vector2i(-1, 0))
	window(Vector2i(-2, -1), Vector2i(-1, -1))
	window(Vector2i(-2, 1), Vector2i(-1, 1))
	corridor("conduits", "Conduits", Vector2i(2, -1), Vector2i(2, 1), "engine", {"warm": 1.3})
	door(Vector2i(3, 0), Vector2i(2, 0))
	# The growth forced this one and it never shut again.
	door(Vector2i(2, 0), Vector2i(1, 0), {"jammed": true})
	# The rings look in on the Heart.
	window(Vector2i(0, 3), Vector2i(0, 2))
	window(Vector2i(-1, -3), Vector2i(-1, -2))
	window(Vector2i(1, -3), Vector2i(1, -2))
	room("mari", "MARI core", Rect2i(4, -1, 2, 3), "lab", {"warm": 0.7})
	door(Vector2i(3, -1), Vector2i(4, -1))
	room_cells("observation", "Observation room", [Vector2i(0, -4), Vector2i(-1, -5), Vector2i(0, -5), Vector2i(1, -5)], "window", {"vent": true})
	door(Vector2i(0, -3), Vector2i(0, -4))
	room("junction", "Nutrient junction", Rect2i(-5, -1, 2, 3), "hydro", {"warm": 1.5, "vent": true})
	door(Vector2i(-3, 1), Vector2i(-4, 1))
	room("security", "Security post", Rect2i(-5, -4, 2, 2), "security")
	door(Vector2i(-3, -3), Vector2i(-4, -3))
	room("crew", "Night crew rest", Rect2i(-5, 3, 2, 2), "crew")
	door(Vector2i(-3, 3), Vector2i(-4, 3))
	room("stores", "Core stores", Rect2i(4, 3, 2, 2), "cargo")
	door(Vector2i(3, 3), Vector2i(4, 3))
	# Ducts out of the chamber, and between the outer rooms.
	vent(Vector2i(-1, -2), Vector2i(-5, -4))
	vent(Vector2i(1, 2), Vector2i(5, 4))
	vent(Vector2i(-5, 1), Vector2i(-5, 3))
	vent(Vector2i(5, -1), Vector2i(3, -3))
	# Every feed's cables meet in the chamber, and the growth runs along them.
	cable(Vector2i(0, -2), Vector2i(0, -3))
	cable(Vector2i(0, 2), Vector2i(0, 3))
	cable(Vector2i(2, -1), Vector2i(3, -2))
	cable(Vector2i(2, 1), Vector2i(3, 2))
	cable(Vector2i(2, 0), Vector2i(4, 0))
	cable(Vector2i(-1, 0), Vector2i(-4, 0))


## The heaviest start of any deck: the chamber full, the ways in nearly so,
## and the rings and outer rooms grown from the feeds.
func _growth() -> void:
	grow_room("chamber", 4.0)
	grow_room("conduits", 3.4)
	grow(Vector2i(2, 0), 3.8)
	grow_room("decon", 2.6)
	grow(Vector2i(-2, 0), 3.0)
	for x in range(-2, 3):
		grow(Vector2i(x, -3), [2.0, 2.6, 3.0, 2.6, 2.0][x + 2])
	for z in range(-2, 3):
		grow(Vector2i(3, z), [1.8, 2.6, 3.0, 2.6, 1.8][z + 2])
	for z in range(-1, 2):
		grow(Vector2i(-3, z), [1.8, 2.4, 1.8][z + 1])
	grow(Vector2i(0, 3), 1.4)
	grow(Vector2i(-4, -1), 2.6)
	grow(Vector2i(-4, 0), 3.2)
	grow(Vector2i(-4, 1), 2.6)
	grow(Vector2i(-5, 0), 2.4)
	grow(Vector2i(-5, -4), 1.8)
	grow(Vector2i(-4, -4), 1.2)
	grow(Vector2i(4, 0), 1.0)


func _lobby() -> void:
	thing("workbench", Vector2i(-1, 4), Vector3(0, 0, -1.35), 0.0)
	thing("bunk", Vector2i(1, 4), Vector3(0.6, 0, -0.8), 0.0)
	prop("ess:Prop_Locker", Vector2i(-1, 5), Vector3(-1.62, 0, 0.7), 90.0)
	prop("ess:Prop_Locker", Vector2i(-1, 5), Vector3(-1.62, 0, -0.4), 90.0)
	prop("ess:Prop_Shelves_WideShort", Vector2i(1, 5), Vector3(1.6, 0, 0.5), -90.0)
	pickup("flare", Vector2i(-1, 5), Vector3(0.5, 0, 0.6), 2)
	pickup("medkit", Vector2i(1, 5), Vector3(1.55, 1.22, 0.5), 1)
	pickup("ammo", Vector2i(1, 5), Vector3(0.7, 0, -0.6), 2)
	thing("decal", Vector2i(0, 4), Vector3(0, 0, -0.6), 0.0, {"name": "Decal_Arrows"})
	thing("decal", Vector2i(1, 4), Vector3(-0.4, 0, 1.2), 0.0, {"name": "Decal_Numbers_Eight"})


func _rings() -> void:
	# South: the way in, and the first look at the Heart.
	body(Vector2i(-2, 3), Vector3(0.4, 0, 0.7), 200.0, "tech")
	pickup("health", Vector2i(2, 3), Vector3(0.3, 0, 1.3), 1)
	pickup("ammo:scattergun", Vector2i(-1, 3), Vector3(-0.8, 0, 1.3), 1)
	prop("Prop_Barrel_Large", Vector2i(2, 3), Vector3(1.0, 0, -1.45))
	prop("Prop_Barrel_Small", Vector2i(2, 3), Vector3(1.5, 0, -1.3))
	prop("Prop_Crate4", Vector2i(-2, 3), Vector3(-1.0, 0.56, -1.3), 15.0)
	thing("decal", Vector2i(0, 3), Vector3(0, 0, -1.1), 0.0, {"name": "Decal_Caution"})
	thing("decal", Vector2i(2, 3), Vector3(0, 0, 0), 90.0, {"name": "Decal_Line_Straight"})
	thing("decal", Vector2i(-2, 3), Vector3(0, 0, 0), 90.0, {"name": "Decal_Line_Straight"})
	# West.
	spawn("taken", Vector2i(-3, -1), Vector3(0.3, 0, 0.2), 1, {"job": "medic"})
	pickup("ammo", Vector2i(-3, -2), Vector3(-1.3, 0, -0.6), 2)
	pickup("health", Vector2i(-3, 2), Vector3(-1.3, 0, -0.3), 1)
	prop("ess:Prop_Crate_Tarp", Vector2i(-3, -2), Vector3(0.9, 0, 0.3), 10.0)
	thing("vent_panel", Vector2i(-3, 2), Vector3(-1.68, 0, 0.6), 0.0, {"room": "junction"})
	# North: windows onto the chamber, the observation room off it.
	spawn("stalker", Vector2i(2, -3), Vector3(0.3, 0, 0.0), 1, {"asleep": true})
	spawn("pod", Vector2i(0, -3), Vector3(0.6, 0, 1.3), 1)
	pickup("grenade", Vector2i(-2, -3), Vector3(0.0, 0, -1.3), 1)
	pickup("health", Vector2i(2, -3), Vector3(1.2, 0, -1.3), 1)
	prop("Prop_Crate4", Vector2i(-1, -3), Vector3(-0.2, 0.56, -1.3), -20.0)
	thing("vent_panel", Vector2i(1, -3), Vector3(0.7, 0, -1.68), -90.0, {"room": "observation"})
	# East: the way through the conduits.
	spawn("taken", Vector2i(3, 1), Vector3(-0.2, 0, 0.3), 1, {"job": "engineer"})
	spawn("skitter", Vector2i(3, 2), Vector3(0.6, 0, 0.8), 1, {"asleep": true})
	spawn("pod", Vector2i(3, 0), Vector3(1.3, 0, 0.9), 1)
	pickup("ammo:rifle", Vector2i(3, -2), Vector3(1.3, 0, -0.9), 1)
	pickup("flare", Vector2i(3, 2), Vector3(-1.3, 0, 1.2), 1)
	prop("Prop_Barrel_Large", Vector2i(3, -2), Vector3(1.45, 0, 0.5))


func _decon() -> void:
	prop("ess:Prop_Locker", Vector2i(-2, -1), Vector3(-0.6, 0, -1.65))
	prop("ess:Prop_Locker", Vector2i(-2, -1), Vector3(0.45, 0, -1.65))
	prop("ess:Prop_Shelves_ThinShort", Vector2i(-2, 1), Vector3(0.3, 0, 1.62), 180.0)
	thing("decal", Vector2i(-2, 0), Vector3(0, 0, 0), 0.0, {"name": "Decal_Warning"})
	thing("log", Vector2i(-2, 1), Vector3(-0.9, 0, 0.9), 200.0, {"id": "core_okafor", "title": "Before the chamber",
		"by": "Dr Imani Okafor, botany", "text": OKAFOR_LOG})
	pickup("stim", Vector2i(-2, 1), Vector3(0.3, 1.22, 1.62), 1)
	pickup("medkit", Vector2i(-2, -1), Vector3(0.6, 0, 0.4), 1)


func _chamber() -> void:
	# What held the sample, split open, and the containment cells either side.
	prop("Prop_Chest", Vector2i(0, 1), Vector3(0.0, 0, 1.1), 10.0, {"solid": false})
	prop("Prop_Pod", Vector2i(-1, 2), Vector3(-0.5, 0, 0.6))
	prop("Prop_Pod", Vector2i(1, 2), Vector3(0.5, 0, 0.6))
	spawn("taken", Vector2i(-1, 1), Vector3(-0.4, 0, 0.3), 1, {"job": "science", "female": true,
		"routine": [Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-2, 0), Vector2i(-2, 1), Vector2i(-1, -1)]})
	spawn("watcher", Vector2i(1, -1), Vector3(0.3, 0, -0.2), 1)
	spawn("feeder", Vector2i(-1, -2), Vector3(0.2, 0, 0.3), 1)
	spawn("pod", Vector2i(0, -2), Vector3(0.9, 0, -1.3), 1)
	spawn("pod", Vector2i(1, 1), Vector3(1.3, 0, -0.2), 1)
	spawn("pod", Vector2i(1, -1), Vector3(1.3, 0, 0.8), 1)


func _conduits() -> void:
	thing("column", Vector2i(2, -1), Vector3(-1.25, 0, -1.25), 0.0, {"name": "Column_Pipes"})
	thing("column", Vector2i(2, 1), Vector3(1.25, 0, 1.25), 0.0, {"name": "Column_Pipes"})
	spawn("feeder", Vector2i(2, -1), Vector3(0.3, 0, 0.2), 1)
	spawn("skitter", Vector2i(2, 1), Vector3(0.5, 0, 0.5), 2, {"asleep": true})
	pickup("salvage", Vector2i(2, 1), Vector3(-1.2, 0, 1.2), 2)


func _mari_core() -> void:
	thing("log", Vector2i(5, 0), Vector3(1.5, 0, 0), -90.0, {"id": "core_mari", "style": "terminal", "title": "MARI core log",
		"by": "MARI", "text": MARI_LOG})
	prop("ess:Prop_CeilingComputer", Vector2i(4, 0), Vector3(0.2, Kit.HEIGHT, 0), 90.0, {"solid": false})
	thing("decal", Vector2i(4, 0), Vector3(0.3, 0, 0), 0.0, {"name": "Decal_Logo"})
	for c in [Vector2i(4, -1), Vector2i(5, 1)]:
		thing("light", c, Vector3(0, 1.6, 0), 0.0, {"color": Color(0.35, 0.6, 1.0), "energy": 0.5, "range": 5.5})
	body(Vector2i(5, -1), Vector3(0.0, 0, 0.4), 0.0, "tech")
	spawn("taken", Vector2i(5, 1), Vector3(-0.6, 0, -0.2), 1, {"job": "command"})
	spawn("eyedrone", Vector2i(4, 0), Vector3(-0.3, 0, 0.6), 1, {"asleep": true})
	pickup("cell", Vector2i(4, 1), Vector3(-1.3, 0, 1.3), 1)
	pickup("salvage", Vector2i(4, -1), Vector3(-1.3, 0, -1.3), 2)


func _observation() -> void:
	prop("ess:Prop_HologramMap2", Vector2i(0, -5), Vector3(0, 0, -0.6))
	prop("ess:Prop_Chair", Vector2i(-1, -5), Vector3(0.4, 0, 0.6))
	prop("ess:Prop_Chair", Vector2i(1, -5), Vector3(-0.4, 0, 0.6), 20.0)
	body(Vector2i(1, -5), Vector3(0.7, 0, -0.9), 40.0, "science")
	spawn("watcher", Vector2i(-1, -5), Vector3(0.0, 0, -0.3), 1)
	pickup("ammo:rail", Vector2i(-1, -5), Vector3(-1.2, 0, -1.1), 1)


func _junction() -> void:
	prop("Prop_Pod_Short", Vector2i(-5, -1), Vector3(-0.6, 0, -0.6))
	prop("Prop_Pod_Short", Vector2i(-5, 1), Vector3(-0.6, 0, 0.6))
	thing("column", Vector2i(-4, -1), Vector3(1.25, 0, -1.25), 0.0, {"name": "Column_Pipes"})
	prop("ess:Prop_Barrel2_Closed", Vector2i(-4, 1), Vector3(-1.2, 0, 1.3))
	prop("ess:Prop_Barrel2_Open", Vector2i(-4, 1), Vector3(-0.5, 0, 1.45))
	thing("log", Vector2i(-4, -1), Vector3(-0.4, 0, -1.45), 0.0, {"id": "core_junction", "style": "terminal", "title": "Maintenance ticket 5120",
		"by": "MARI",
		"text": "Ticket 5120: Hydroponics nutrient feed, flow reversed. Cause: organic obstruction.\n\nTicket 5121: Crew quarters water feed, flow reversed. Cause: organic obstruction.\n\nTickets 5122 to 5139: every other feed on Marigold, flow reversed. Everything on the station is flowing toward the sample chamber.\n\nAll tickets assigned to: night shift."})
	spawn("taken", Vector2i(-5, 0), Vector3(0.5, 0, 0.2), 1, {"job": "botanist"})
	spawn("skitter", Vector2i(-4, -1), Vector3(-0.4, 0, 0.4), 2, {"asleep": true})
	spawn("pod", Vector2i(-4, 0), Vector3(1.2, 0, 0.6), 1)
	pickup("ammo:scattergun", Vector2i(-5, 1), Vector3(1.0, 0, 1.2), 2)
	pickup("salvage", Vector2i(-4, -1), Vector3(-1.3, 0, -0.2), 2)


func _security() -> void:
	prop("ess:Prop_GunRack", Vector2i(-5, -4), Vector3(0.0, 0, -1.3))
	prop("ess:Prop_Locker", Vector2i(-5, -3), Vector3(-1.55, 0, 0.6), 90.0)
	prop("ess:Prop_Locker", Vector2i(-5, -3), Vector3(-1.55, 0, -0.5), 90.0)
	prop("ess:Prop_Desk_Medium", Vector2i(-4, -4), Vector3(0, 0, -1.25))
	prop("ess:Prop_Chair", Vector2i(-4, -4), Vector3(0.3, 0, -0.3), 160.0)
	thing("log", Vector2i(-4, -4), Vector3(0.5, 0.94, -1.4), 0.0, {"id": "core_watch", "style": "screen", "title": "Core watch, night duty",
		"by": "Officer Jonah Pell, core watch",
		"text": "22:40. Dr Okafor came down with her badge and asked me to let her into the chamber. I told her MARI had it sealed. MARI opened it for her.\n\nThe drones won't stand down. They've been guarding the chamber door like it's theirs. One of them put a round past my ear when I tried to follow her.\n\nI'm staying in the post with the door shut. Something keeps walking the ring. It walks like Okafor."})
	thing("pickup", Vector2i(-4, -4), Vector3(-0.6, 0.95, -1.25), 0.0, {"item": "weapon:rifle", "count": 1})
	pickup("ammo:rifle", Vector2i(-5, -4), Vector3(0.9, 0, -0.3), 2)
	pickup("ammo:smg", Vector2i(-5, -3), Vector3(0.4, 0, 1.2), 2)
	pickup("grenade", Vector2i(-5, -3), Vector3(0.6, 0, 0.3), 2)
	pickup("mine", Vector2i(-4, -3), Vector3(-0.4, 0, 1.3), 2)
	spawn("gundrone", Vector2i(-5, -4), Vector3(0.6, 0, 0.6), 1, {"asleep": true})
	spawn("taken", Vector2i(-4, -3), Vector3(-0.6, 0, -0.4), 1, {"job": "security"})


func _crew_rest() -> void:
	prop("Prop_Pod_Short", Vector2i(-5, 4), Vector3(-0.55, 0, 0.55))
	prop("ess:Prop_Desk_Small", Vector2i(-4, 4), Vector3(0.2, 0, 1.1), 180.0)
	prop("ess:Prop_Chair", Vector2i(-4, 4), Vector3(0.5, 0, 0.4), 10.0)
	prop("ess:Prop_Mug", Vector2i(-4, 4), Vector3(-0.3, 0.94, 1.15), 0.0, {"solid": false})
	prop("ess:Prop_Locker", Vector2i(-5, 3), Vector3(-0.5, 0, -1.38))
	prop("ess:Prop_Shelves_WideShort", Vector2i(-4, 3), Vector3(0.3, 0, -1.36))
	thing("log", Vector2i(-4, 4), Vector3(0.6, 0.95, 1.15), 170.0, {"id": "core_rest", "title": "Note for Theo",
		"by": "Ines Varga, core tech",
		"text": "Theo, if you get this up on the ring: don't come down. The Core's warm. It's never warm down here.\n\nThe lines are wet where they come in through the wall. I put my hand on the nutrient main and it was beating. Not pumping. Beating.\n\nI'm going to sleep in the cold hall with MARI's servers. She says it's slower in there. Love you. Ines."})
	body(Vector2i(-5, 3), Vector3(0.6, 0, 0.2), 120.0, "tech")
	pickup("medkit", Vector2i(-4, 3), Vector3(0.6, 1.22, -1.36), 1)
	pickup("health", Vector2i(-5, 4), Vector3(1.2, 0, 1.2), 1)
	pickup("salvage", Vector2i(-5, 3), Vector3(-1.2, 0, 1.3), 1)


func _stores() -> void:
	prop("ess:Prop_Shelves_WideTall", Vector2i(5, 3), Vector3(1.4, 0, -0.4), -90.0)
	prop("ess:Prop_Shelves_WideTall", Vector2i(5, 4), Vector3(1.4, 0, 0.3), -90.0)
	prop("ess:Prop_Crate_Tarp_Large", Vector2i(4, 4), Vector3(-0.2, 0, 0.7))
	prop("ess:Prop_Crate", Vector2i(5, 3), Vector3(-0.6, 0, -0.8), 12.0)
	prop("Prop_Crate1", Vector2i(4, 3), Vector3(0.9, 0.5, -1.1), 25.0)
	thing("log", Vector2i(5, 3), Vector3(-0.6, 1.5, -0.8), 30.0, {"id": "core_slip", "title": "Transfer slip 0442",
		"by": "Cargo, bay 2",
		"text": "Item: sample SV-3, survey moon, one sealed case.\nFrom: cargo bay 2. To: Core sample chamber, by the Core service lift.\nReceived by: Dr I. Okafor.\n\nNotes: case warm to the touch. Scanned clean twice. Logged as normal."})
	body(Vector2i(5, 4), Vector3(-0.4, 0, -0.6), 250.0, "cargo")
	spawn("taken", Vector2i(5, 3), Vector3(-0.8, 0, 0.8), 1, {"job": "cargo"})
	spawn("skitter", Vector2i(4, 4), Vector3(0.4, 0, -0.6), 1, {"asleep": true})
	pickup("salvage", Vector2i(5, 4), Vector3(-1.3, 0, 1.3), 3)
	pickup("grenade", Vector2i(4, 3), Vector3(-0.8, 0, 1.2), 1)
	pickup("ammo", Vector2i(4, 4), Vector3(-1.3, 0, -0.9), 2)


func _views() -> void:
	view("arrival", Vector3(0, 1.65, 18.4), 0.0, -3.0)
	view("heart_window", Vector3(0, 1.65, 12.6), 0.0, 8.0)
	view("south_ring", Vector3(13.0, 1.65, 12.0), 90.0, -4.0)
	view("west_ring", Vector3(-12.0, 1.65, 9.2), 0.0, -4.0)
	view("north_ring", Vector3(-13.0, 1.65, -12.0), -90.0, -2.0)
	view("east_ring", Vector3(12.0, 1.65, -9.2), 180.0, -4.0)
	view("decontamination", Vector3(-8.0, 1.65, -4.4), 180.0, -6.0)
	view("chamber", Vector3(-5.4, 1.65, 1.0), -80.0, 12.0)
	view("chamber_north", Vector3(5.0, 1.65, -9.0), 151.0, 10.0)
	view("conduits", Vector3(8.0, 1.65, -5.6), 180.0, -5.0)
	view("mari_core", Vector3(15.0, 1.65, -5.0), -145.0, -4.0)
	view("observation", Vector3(0, 1.65, -15.0), 0.0, 4.0)
	view("nutrient_junction", Vector3(-15.0, 1.65, 5.0), 29.0, -5.0)
	view("security_post", Vector3(-14.6, 1.65, -12.6), 80.0, -6.0)
	view("crew_rest", Vector3(-14.6, 1.65, 11.4), 110.0, -6.0)
	view("core_stores", Vector3(14.6, 1.65, 11.4), -110.0, -6.0)


func decorate() -> void:
	_server_hall()
	_feeds()
	# The crew the Bloom keeps: cocooned round the chamber's walls.
	Fittings.cocoon(self, DeckLevel.center(Vector2i(0, -2)) + Vector3(-0.9, 0, -1.55), 0.0, 11)
	Fittings.cocoon(self, DeckLevel.center(Vector2i(1, -1)) + Vector3(1.55, 0, -0.7), -PI * 0.5, 12)
	Fittings.cocoon(self, DeckLevel.center(Vector2i(1, 1)) + Vector3(1.55, 0, 0.9), -PI * 0.5, 13)
	Fittings.cocoon(self, DeckLevel.center(Vector2i(-1, -2)) + Vector3(-1.55, 0, -0.6), PI * 0.5, 14)
	Fittings.cocoon(self, DeckLevel.center(Vector2i(2, -1)) + Vector3(0.6, 0, -1.55), 0.0, 15)
	Fittings.cocoon(self, DeckLevel.center(Vector2i(-5, 0)) + Vector3(-1.55, 0, -0.4), PI * 0.5, 16)
	# Dragged in from the ring: to the west door, and through the conduits.
	Fittings.drag(self, DeckLevel.center(Vector2i(-2, 3)) + Vector3(0.4, 0, 0.7), DeckLevel.center(Vector2i(-3, 2)))
	Fittings.drag(self, DeckLevel.center(Vector2i(3, 2)), DeckLevel.center(Vector2i(2, 0)))
	Fittings.drag(self, DeckLevel.center(Vector2i(2, 0)), DeckLevel.center(Vector2i(1, 0)) + Vector3(-1.2, 0, 0))


## MARI's servers: rows of racks down the cold hall, and along its walls,
## with her terminal between them.
func _server_hall() -> void:
	var seed := 0
	for z in [-5.0, -3.8, -2.6, 2.6, 3.8, 5.0]:
		_rack(Vector3(21.35, 0, z), -PI * 0.5, seed)
		seed += 1
	for z in [-2.4, -1.2, 0.0, 1.2, 2.4]:
		_rack(Vector3(17.5, 0, z), -PI * 0.5, seed)
		_rack(Vector3(18.5, 0, z), PI * 0.5, seed + 7)
		seed += 1
	for x in [18.4, 19.6]:
		_rack(Vector3(x, 0, -5.35), 0.0, seed)
		_rack(Vector3(x, 0, 5.35), PI, seed + 3)
		seed += 1


## A server rack: a dark cabinet with its front (+z) lit by rows of status
## lights, blocking like a wall.
func _rack(pos: Vector3, yaw: float, seed: int) -> void:
	var body := StaticBody3D.new()
	body.name = "Rack"
	body.collision_layer = Kit.LAYER_STATION
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = yaw
	add_child(body)
	var size := Vector3(1.1, 2.7, 1.0)
	var cab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	cab.mesh = box
	cab.material_override = Kit.flat(Color(0.07, 0.08, 0.1), 0.4)
	cab.position.y = size.y * 0.5
	body.add_child(cab)
	var face := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(size.x - 0.16, size.y - 0.3, 0.02)
	face.mesh = fb
	face.material_override = Kit.flat(Color(0.12, 0.13, 0.16), 0.3)
	face.position = Vector3(0, size.y * 0.5, size.z * 0.5 + 0.01)
	body.add_child(face)
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var lit := Kit.flat(Color(0.2, 0.6, 1.0), 0.3, Color(0.25, 0.65, 1.0), 2.2)
	var warn := Kit.flat(Color(1.0, 0.35, 0.2), 0.3, Color(1.0, 0.3, 0.15), 2.2)
	for row in 7:
		var strip := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(r.randf_range(0.2, 0.7), 0.035, 0.01)
		strip.mesh = sb
		strip.material_override = warn if r.randf() < 0.18 else lit
		strip.position = Vector3(r.randf_range(-0.12, 0.12), 0.45 + row * 0.3, size.z * 0.5 + 0.025)
		body.add_child(strip)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position.y = size.y * 0.5
	body.add_child(cs)


## The feeds: thick mains overhead in the conduits and the junction, and
## cables across the floors to the chamber.
func _feeds() -> void:
	for x in [7.0, 9.0]:
		for z in [-4.0, 0.0, 4.0]:
			Kit.model(_static, "Prop_Pipe_Thick_Straight", Vector3(x, 4.3, z), 0.0)
	for z in [-4.0, 0.0, 4.0]:
		Kit.model(_static, "Prop_Pipe_Thick_Straight", Vector3(-21.2, 4.3, z), 0.0)
		Kit.model(_static, "Prop_Pipe_Medium_Straight", Vector3(-14.8, 4.5, z), 0.0)
	for x in [-20.0, -16.0]:
		Kit.model(_static, "Prop_Pipe_Medium_Straight", Vector3(x, 4.75, 0.0), PI * 0.5)
	Kit.model(_static, "Prop_Cable3", Vector3(7.9, 0.0, 0.0), 0.0)
	Kit.model(_static, "Prop_Cable2", Vector3(7.3, 0.0, 2.0), 0.0)
	Kit.model(_static, "Prop_Cable4", Vector3(0.6, 0.0, -11.2), PI * 0.5)
	Kit.model(_static, "Prop_Cable2", Vector3(-0.4, 0.0, 10.6), PI * 0.5)
	Kit.model(_static, "Prop_Cable3", Vector3(1.5, 0.0, -5.0), 0.3)
	Kit.model(_static, "Prop_Cable4", Vector3(-1.8, 0.0, 4.6), -0.4)
