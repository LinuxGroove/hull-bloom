extends DeckLevel
## Labs: the lift lobby, the main corridor north between the offices and the
## server room, the clean room and the cold sample store, the xenobiology
## lab and Containment C-1 either side of the corridor's top, and the
## observation gallery along the deck's edge, looking down into both. The
## Bloom's root is the sample itself, in C-1. Both labs can be vented from
## panels in the corridor outside their doors.
##
##   z -9       observation gallery (-4..3), windows into both labs
##   z -8..-5   xenobiology lab (-4..-1)    containment C-1 (1..3, -8..-6), root
##   z -4..-2   clean room (-3..-1)         sample store (1..3), cold
##   z -1..0    offices (-3..-1)            server room (1..3), warm
##   z  1..-8   main corridor (x 0)
##   z  2..3    lift lobby (-1..1), lift at (0, 3)

const ROOT := Vector2i(2, -7)

const VOS_NOTES := """Week 1. Imani's culture came up from hydroponics in a sealed flask. We keep it at four degrees in C-1. At four degrees it does nothing at all, which is why everyone has been calling it dormant.

Week 2. It is not dormant. Under the scope every cell is moving, very slowly, towards the warm side of the flask. When Hugo stood at the glass it leaned towards him. When he walked away, it followed.

Week 3. It grows towards warmth and towards people, and it can tell the difference: it ignores the heater when one of us is in the room. I have asked MARI to lock out C-1's vent. This is the only living sample of anything we have ever found. Nobody vents it without me."""

const BREACH := """21:09. Containment C-1 cooling: power drawn by an unknown load. Temperature rising.

21:12. C-1 seal integrity: 40 percent. Organic material in the air ducts.

21:14. Emergency vent requested by Dr H. Lindqvist. Refused: vent locked out by Dr E. Vos.

21:31. C-1 sealed by protocol, with Dr E. Vos inside. Organic obstruction in the xenobiology lab and the server room. The vent panels are outside each lab's door. Confirm twice. Nothing inside can be recovered."""

const STAYED := """Elena went into C-1 to save the sample and the door sealed behind her. I watched from the gallery. She put her hand on the glass, and it put something like a hand on hers.

I'm keeping the chillers on for the sample store. It doesn't go into the cold. Priya's in there with the samples, and I've told her to stay put.

The servers run hot, and it has found them. It's in the duct above me. I can hear it moving towards the warmth, towards me. Whoever reads this: vent C-1. Don't wait for her."""

const OKAFOR := """Elena, one of the SV-3 spores germinated in the nutrient mist overnight. Four hours to a root system. I'm sending a culture up to you in a sealed flask.

Keep it cold, keep it locked up, and please don't let your team give it a name.

It moved when I leaned over the tray. I'm sure it was the air from the vent."""


func build() -> void:
	default_style("corridor")
	room("lobby", "Lift lobby", Rect2i(-1, 2, 3, 2))
	lift(Vector2i(0, 3), "S")
	corridor("spine", "Main corridor", Vector2i(0, 1), Vector2i(0, -8))
	arch(Vector2i(0, 2), Vector2i(0, 1))
	room("offices", "Offices", Rect2i(-3, -1, 3, 2), "crew")
	door(Vector2i(-1, 0), Vector2i(0, 0))
	room("servers", "Server room", Rect2i(1, -1, 3, 2), "core", {"warm": 1.4})
	door(Vector2i(0, -1), Vector2i(1, -1))
	room("clean", "Clean room", Rect2i(-3, -4, 3, 3), "medical")
	door(Vector2i(-1, -3), Vector2i(0, -3))
	door(Vector2i(-2, -2), Vector2i(-2, -1))
	room("store", "Sample store", Rect2i(1, -4, 3, 3), "cargo", {"warm": 0.7})
	door(Vector2i(0, -3), Vector2i(1, -3))
	door(Vector2i(2, -2), Vector2i(2, -1))
	room("xeno", "Xenobiology lab", Rect2i(-4, -8, 4, 4), "lab", {"warm": 1.2, "vent": true})
	door(Vector2i(-1, -7), Vector2i(0, -7))
	door(Vector2i(-2, -5), Vector2i(-2, -4))
	room("containment", "Containment C-1", Rect2i(1, -8, 3, 3), "core", {"dark": true, "warm": 1.3, "vent": true})
	door(Vector2i(0, -7), Vector2i(1, -7), {"sealed": true})
	corridor("gallery", "Observation gallery", Vector2i(-4, -9), Vector2i(3, -9), "window")
	arch(Vector2i(0, -8), Vector2i(0, -9))
	for x in range(-4, 4):
		if x != 0:
			window(Vector2i(x, -9), Vector2i(x, -8))
	# The ducts it found: from C-1 to the xenobiology lab, and down to the
	# warm server room. The cable run under the corridor's floor.
	vent(Vector2i(1, -6), Vector2i(-3, -6))
	vent(Vector2i(3, -6), Vector2i(3, -1))
	vent(Vector2i(-3, -8), Vector2i(-3, -2))
	cable(Vector2i(1, 0), Vector2i(-1, 0))
	root(ROOT)
	grow_room("containment", 3.6)
	grow(ROOT, 4.0)
	grow_room("xeno", 2.3)
	grow(Vector2i(-3, -6), 3.3)
	grow(Vector2i(-2, -6), 2.9)
	grow(Vector2i(-3, -7), 2.8)
	grow(Vector2i(-4, -5), 1.4)
	grow(Vector2i(-1, -5), 1.2)
	grow(Vector2i(0, -7), 1.3)
	grow(Vector2i(0, -8), 0.5)
	grow(Vector2i(3, -1), 1.5)
	grow(Vector2i(2, -1), 0.6)
	_lobby()
	_spine()
	_offices()
	_servers()
	_clean()
	_store()
	_xeno()
	_containment()
	_gallery()
	_views()


func _lobby() -> void:
	thing("workbench", Vector2i(-1, 2), Vector3(0, 0, -1.3), 0.0)
	thing("bunk", Vector2i(1, 2), Vector3(0.6, 0, -0.8), 0.0)
	prop("ess:Prop_Locker", Vector2i(-1, 3), Vector3(-1.45, 0, 0.6), 90.0)
	prop("ess:Prop_Locker", Vector2i(-1, 3), Vector3(-1.45, 0, -0.5), 90.0)
	prop("ess:Prop_Shelves_WideShort", Vector2i(1, 3), Vector3(1.45, 0, -0.2), -90.0)
	pickup("flare", Vector2i(1, 3), Vector3(1.4, 1.22, -0.2), 2)
	thing("log", Vector2i(-1, 3), Vector3(0.9, 0, 1.4), 180.0, {"id": "labs_visitors", "style": "terminal", "title": "Visitors to Labs",
		"by": "Posted by Dr Elena Vos, research lead",
		"text": "Labs is a restricted deck. Sign in at the lift and keep your badge on.\n\nNobody goes into Containment C-1 without me. Nobody stands at the gallery glass for more than ten minutes, however interesting it gets.\n\nIf you feel warm, tell someone."})
	thing("decal", Vector2i(0, 2), Vector3(0, 0, -0.6), 0.0, {"name": "Decal_Arrows"})


func _spine() -> void:
	for z in [0, -2, -4]:
		thing("decal", Vector2i(0, z), Vector3.ZERO, 0.0, {"name": "Decal_Line_Straight"})
	prop("Prop_Crate4", Vector2i(0, -1), Vector3(-1.3, 0.56, 1.1), 15.0)
	prop("Prop_Crate1", Vector2i(0, -1), Vector3(-1.4, 0.5, -0.1), -10.0)
	prop("Prop_Barrel_Large", Vector2i(0, 1), Vector3(1.45, 0, 1.0))
	pickup("health", Vector2i(0, -5), Vector3(1.3, 0, 0.6), 1)
	body(Vector2i(0, -5), Vector3(-0.6, 0, -0.9), 30.0, "science")
	thing("decal", Vector2i(0, -6), Vector3(0, 0, 0.6), 0.0, {"name": "Decal_Caution"})
	thing("decal", Vector2i(0, -7), Vector3.ZERO, 90.0, {"name": "Decal_Warning"})
	# The vent panels, on the corridor walls just past each lab's door.
	thing("vent_panel", Vector2i(0, -8), Vector3(1.6, 0, 0.3), 180.0, {"room": "containment"})
	thing("vent_panel", Vector2i(0, -8), Vector3(-1.6, 0, 0.3), 0.0, {"room": "xeno"})
	spawn("taken", Vector2i(0, -3), Vector3(0.4, 0, -0.6), 1, {"job": "science",
		"routine": [Vector2i(0, -2), Vector2i(0, -4), Vector2i(0, -6), Vector2i(-2, -3), Vector2i(-1, -2)]})


func _offices() -> void:
	prop("ess:Prop_Desk_Medium", Vector2i(-3, -1), Vector3(0.2, 0, -1.25))
	prop("ess:Prop_Chair", Vector2i(-3, -1), Vector3(0.6, 0, -0.2), 160.0)
	prop("ess:Prop_Screen", Vector2i(-3, -1), Vector3(-0.4, 0.94, -1.45), 0.0, {"solid": false})
	thing("log", Vector2i(-3, -1), Vector3(0.8, 0.94, -1.4), 0.0, {"id": "labs_sv3", "style": "screen", "title": "SV-3: working notes",
		"by": "Dr Elena Vos, research lead", "text": VOS_NOTES})
	prop("ess:Prop_Mug", Vector2i(-3, -1), Vector3(0.25, 0.94, -1.1), 0.0, {"solid": false})
	prop("ess:Prop_Desk_Medium", Vector2i(-2, 0), Vector3(0, 0, 1.25), 180.0)
	prop("ess:Prop_Chair", Vector2i(-2, 0), Vector3(-0.5, 0, 0.2), 20.0)
	prop("ess:Prop_Screen", Vector2i(-2, 0), Vector3(0.5, 0.94, 1.45), 180.0, {"solid": false})
	prop("ess:Prop_Shelves_WideTall", Vector2i(-3, -1), Vector3(-1.45, 0, 0.6), 90.0)
	prop("ess:Prop_Shelves_ThinShort", Vector2i(-3, 0), Vector3(-1.45, 0, 0.4), 90.0)
	prop("ess:Prop_Locker", Vector2i(-1, -1), Vector3(0.6, 0, -1.45))
	thing("survivor", Vector2i(-3, 0), Vector3(1.6, 0, 1.0), 90.0, {"id": "labs_grant", "name": "Felix Grant",
		"line": "Something floats past that door every few minutes. It stops and looks in. I've been behind this desk since the lights went. I'm going, I'm going.",
		"job": "science", "pose": "crouch"})
	pickup("ammo:scattergun", Vector2i(-1, 0), Vector3(0.8, 0, 1.2), 2)
	pickup("salvage", Vector2i(-3, 0), Vector3(-0.2, 0, -0.6), 1)


func _servers() -> void:
	# Racks along both long walls, and the hot air they make.
	for x in [1, 2, 3]:
		for dx in [-1.1, -0.35, 0.4]:
			if x == 1 and dx < 0.0:
				continue
			prop("Prop_Computer", Vector2i(x, -1), Vector3(dx, 0, -1.45))
		for dx in [-0.6, 0.15, 0.9]:
			prop("Prop_Computer", Vector2i(x, 0), Vector3(dx, 0, 1.45), 180.0)
	prop("ess:Prop_CeilingComputer", Vector2i(2, 0), Vector3(0, Kit.HEIGHT, -0.4), 0.0, {"solid": false})
	thing("column", Vector2i(3, -1), Vector3(1.4, 0, 1.4), 0.0, {"name": "Column_Pipes"})
	prop("Prop_Fan_Small", Vector2i(1, 0), Vector3(0, Kit.HEIGHT - 0.5, 0), 0.0, {"solid": false})
	body(Vector2i(3, -1), Vector3(-0.2, 0, 0.7), 250.0, "science")
	thing("log", Vector2i(3, -1), Vector3(-1.0, 0, 1.3), 30.0, {"id": "labs_stayed", "title": "Still here",
		"by": "Dr Hugo Lindqvist, xenobiology", "text": STAYED})
	pickup("salvage", Vector2i(2, 0), Vector3(0.3, 0, 0.4), 2)
	spawn("skitter", Vector2i(3, 0), Vector3(0.6, 0, 0.0), 1, {"asleep": true})


func _clean() -> void:
	for z in [-4, -3, -2]:
		prop("ess:Prop_Locker", Vector2i(-3, z), Vector3(-1.45, 0, -0.55), 90.0)
		prop("ess:Prop_Locker", Vector2i(-3, z), Vector3(-1.45, 0, 0.5), 90.0)
	prop("Prop_Pod_Short", Vector2i(-1, -4), Vector3(0.45, 0, -0.45))
	prop("ess:Prop_Desk_Small", Vector2i(-2, -3), Vector3(0, 0, 0), 90.0)
	prop("ess:Prop_Shelves_ThinShort", Vector2i(-1, -2), Vector3(1.45, 0, 0.6), -90.0)
	thing("decal", Vector2i(-2, -4), Vector3(0, 0, 0.6), 0.0, {"name": "Decal_Caution"})
	# The decon gate inside the door to the xenobiology lab.
	for x in [-1.5, 1.5]:
		prop("Column_Hollow", Vector2i(-2, -4), Vector3(x, 0, -1.1), 0.0, {"scale": 0.5})
	prop("Prop_Light_Wide", Vector2i(-2, -4), Vector3(0, 2.62, -1.1), 0.0, {"solid": false})
	prop("ess:Prop_Shelves_WideShort", Vector2i(-3, -2), Vector3(0.4, 0, 1.5), 180.0)
	prop("ess:Prop_Crate", Vector2i(-1, -2), Vector3(0.2, 0, 0.7), 8.0)
	thing("body", Vector2i(-3, -3), Vector3(0.8, 0, 0.2), 200.0, {"job": "medic"})
	pickup("medkit", Vector2i(-2, -3), Vector3(0.1, 0.94, -0.3), 1)
	pickup("stim", Vector2i(-1, -2), Vector3(1.3, 1.22, 0.6), 1)
	pickup("ammo:scattergun", Vector2i(-3, -2), Vector3(0.4, 1.22, 1.5), 2)
	spawn("skitter", Vector2i(-3, -4), Vector3(0.6, 0, 0.4), 2, {"asleep": true})


func _store() -> void:
	for x in [1, 2, 3]:
		prop("ess:Prop_Shelves_WideTall", Vector2i(x, -4), Vector3(0, 0, -1.5))
	prop("Prop_Pod_Short", Vector2i(3, -3), Vector3(0.6, 0, 0))
	prop("Prop_Chest", Vector2i(1, -2), Vector3(-0.4, 0, 1.3), 180.0)
	prop("Prop_Chest", Vector2i(3, -2), Vector3(0.3, 0, 1.3), 180.0)
	prop("ess:Prop_Crate", Vector2i(2, -3), Vector3(-0.3, 0, 0.2), 12.0)
	prop("ess:Prop_Crate_Tarp", Vector2i(2, -4), Vector3(0.3, 0, 0.6), -8.0)
	thing("survivor", Vector2i(3, -4), Vector3(0.2, 0, 0.6), -45.0, {"id": "labs_shah", "name": "Priya Shah",
		"line": "Hugo told me to stay in the cold. It won't come in here. Is he with you? No. All right. I'll find the lift.",
		"job": "science", "pose": "crouch", "female": true})
	pickup("cell", Vector2i(2, -4), Vector3(0.6, 1.25, -1.45), 1)
	pickup("salvage", Vector2i(1, -3), Vector3(0.4, 0, -0.4), 2)
	pickup("medkit", Vector2i(2, -3), Vector3(-0.3, 1.5, 0.2), 1)
	pickup("grenade", Vector2i(3, -2), Vector3(-1.2, 0, 0.6), 1)


func _xeno() -> void:
	for z in [-8, -7, -6]:
		prop("Prop_Pod", Vector2i(-4, z), Vector3(-0.6, 0, 0))
	prop("ess:Prop_Desk_Large", Vector2i(-2, -7), Vector3(-0.2, 0, 0.2), 90.0)
	prop("ess:Prop_Desk_Medium", Vector2i(-1, -5), Vector3(1.25, 0, 0), -90.0)
	prop("ess:Prop_Screen", Vector2i(-1, -5), Vector3(1.45, 0.94, -0.6), -90.0, {"solid": false})
	prop("ess:Prop_HologramMap2", Vector2i(-3, -5), Vector3(-0.3, 0, 0.6))
	prop("ess:Prop_Shelves_ThinTall", Vector2i(-1, -6), Vector3(1.45, 0, 0.0), -90.0)
	prop("ess:Prop_Chair", Vector2i(-2, -6), Vector3(1.2, 0, 1.0), -40.0)
	thing("log", Vector2i(-2, -7), Vector3(-0.1, 1.0, -0.6), 80.0, {"id": "labs_okafor", "title": "Message from hydroponics",
		"by": "Dr Imani Okafor, botany", "text": OKAFOR})
	thing("body", Vector2i(-3, -7), Vector3(0.6, 0, 0.3), 120.0, {"job": "science", "swallowed": true})
	body(Vector2i(-1, -8), Vector3(0.3, 0, 0.4), 300.0, "science")
	pickup("salvage", Vector2i(-4, -5), Vector3(-0.5, 0, 0.9), 3)
	pickup("medkit", Vector2i(-1, -5), Vector3(1.2, 0.94, 0.5), 1)
	spawn("watcher", Vector2i(-2, -6), Vector3(0.6, 0, -0.4), 1)
	spawn("pod", Vector2i(-3, -6), Vector3(-0.8, 0, 0.6), 1)
	spawn("pod", Vector2i(-3, -8), Vector3(0.4, 0, -0.9), 1)
	spawn("taken", Vector2i(-3, -7), Vector3(-0.2, 0, 1.0), 1, {"job": "science"})


func _containment() -> void:
	# SV-3's tank, broken open from the inside, and the spare tanks.
	prop("Prop_Pod", Vector2i(3, -8), Vector3(0.6, 0, -0.5))
	prop("Prop_Pod_Short", Vector2i(3, -6), Vector3(0.7, 0, 0.6))
	prop("ess:Prop_Desk_Small", Vector2i(1, -6), Vector3(-0.5, 0, 1.2), 180.0)
	thing("body", Vector2i(1, -8), Vector3(0.2, 0, 0.3), 160.0, {"job": "science", "swallowed": true, "female": true})
	pickup("salvage", Vector2i(1, -6), Vector3(0.6, 0, 0.8), 2)
	spawn("watcher", Vector2i(2, -6), Vector3(-0.8, 0, 0.2), 1)
	spawn("pod", Vector2i(1, -8), Vector3(-0.6, 0, -0.8), 1)
	spawn("pod", Vector2i(3, -7), Vector3(0.5, 0, 0.8), 1)


func _gallery() -> void:
	thing("log", Vector2i(1, -9), Vector3(0.0, 0, -1.3), 0.0, {"id": "labs_breach", "style": "terminal", "title": "Containment C-1: breach report",
		"by": "MARI", "text": BREACH})
	for x in [-3, -2, 2, 3]:
		prop("ess:Prop_Chair", Vector2i(x, -9), Vector3(0, 0, -0.9), 0.0)
	body(Vector2i(-1, -9), Vector3(0.3, 0, -0.5), 100.0, "security")
	pickup("health", Vector2i(3, -9), Vector3(1.2, 0, 1.0), 1)
	pickup("ammo", Vector2i(-4, -9), Vector3(-1.2, 0, -1.0), 2)
	spawn("stalker", Vector2i(-4, -9), Vector3(0.4, 0, 0.0), 1, {"asleep": true})


func _views() -> void:
	view("arrival", Vector3(0, 1.65, 9.5), 0.0, -3.0)
	view("corridor", Vector3(0, 1.65, 2.5), 0.0, -2.0)
	view("offices", Vector3(-3.0, 1.65, 1.2), 70.0, -10.0)
	view("server_room", Vector3(2.6, 1.65, -3.0), -95.0, -6.0)
	view("clean_room", Vector3(-3.0, 1.65, -8.0), 48.0, -10.0)
	view("sample_store", Vector3(3.0, 1.65, -8.0), -52.0, -10.0)
	view("corridor_top", Vector3(0, 1.65, -18.5), 0.0, 0.0)
	view("xenobiology", Vector3(-3.4, 1.65, -19.5), 46.0, -6.0)
	view("containment", Vector3(5.0, 1.65, -23.0), -38.0, -6.0)
	view("gallery", Vector3(13.2, 1.65, -35.0), 90.0, -2.0)
	view("gallery_c1", Vector3(6.6, 1.65, -37.6), 180.0, -14.0)
	view("gallery_xeno", Vector3(-9.4, 1.65, -37.6), 180.0, -14.0)


func decorate() -> void:
	Fittings.cocoon(self, DeckLevel.center(Vector2i(-4, -8)) + Vector3(0.6, 0, -1.4), 0.0, 41)
	Fittings.cocoon(self, DeckLevel.center(Vector2i(3, -7)) + Vector3(1.4, 0, -0.6), -PI * 0.5, 42)
	Fittings.cocoon(self, DeckLevel.center(Vector2i(2, -8)) + Vector3(-0.3, 0, -1.5), PI, 43)
	Fittings.drag(self, DeckLevel.center(Vector2i(0, -5)) + Vector3(-0.6, 0, -0.9), DeckLevel.center(Vector2i(-1, -7)))
	Fittings.drag(self, DeckLevel.center(Vector2i(-3, -7)) + Vector3(0.6, 0, 0.3), DeckLevel.center(Vector2i(-3, -6)))
