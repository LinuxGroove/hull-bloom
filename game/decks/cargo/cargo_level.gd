extends DeckLevel
## Cargo and docking: the lift lobby and customs at the south, the conveyor
## hall north between two big loading bays (the root is in bay 2, where the
## sample case sat), the cold store behind bay 1, and the dock at the top
## with the shuttle Corran on its pad, reached through the conveyor hall,
## the dockmaster's office or the dock walk along the hull.
##
##   z -10..-8  dockmaster (-3..-2, -9..-8) | dock (-1..2), shuttle | dock walk (3, -9..-7)
##   z  -7..-4  loading bay 1 (-4..-1) | conveyor hall (0..1, -7..-2) | loading bay 2 (2..6, -6..-4), root (6, -5)
##   z  -3..-2  cold store (-3..-2)
##   z  -1..0   customs (-2..1)
##   z   1..2   lift lobby (-1..1), lift (0, 2)

const Fit := preload("res://game/decks/cargo/cargo_fittings.gd")

const MANIFEST := """Inbound, day 1: survey tender Kestrel, docked 19:20.

Item 14: sample case SV-3, survey moon. Sealed, cold chain. Consigned to Dr I. Okafor, Hydroponics. Customs: passed without a scan (biological seal, not to be opened outside a lab). Signed E. Lind.

Note, day 4. The case sat in bay 2 for six hours before Hydroponics came for it, and the cold chain was off for some of that. Nobody told me until today. I've had bay 2 swabbed. Clean, they say.

Note, day 20. Bay 2 is warm. I've asked MARI twice. She says the heating is off."""

const PILOT := """Corran: fuelled, preflight done, flight plan to the colony relay filed. Waiting on clearance.

MARI won't give it. She says there's an obstruction in the dock. There isn't, I've walked it twice. Dunmore is staying with the ship. I'm going up to find the dockmaster and get the clearance signed by hand.

If I'm not back: she doesn't need a pilot to reach the relay. Get everyone aboard, close the hatch, and press the green one. L. Marsh"""

const CREW := """Supply run 14: shuttle Corran to the colony relay and back.

Pilot: Capt. L. Marsh
Loaders: R. Dunmore, J. Ferro, A. Quist
Customs: T. Hollis
Passengers: none listed

Run held by MARI at 02:10. Reason given: organic obstruction."""


func build() -> void:
	default_style("corridor")
	room("lobby", "Lift lobby", Rect2i(-1, 1, 3, 2))
	lift(Vector2i(0, 2), "S")
	room("customs", "Customs", Rect2i(-2, -1, 4, 2), "security")
	door(Vector2i(0, 1), Vector2i(0, 0), {"open": true})
	room("conveyor", "Conveyor hall", Rect2i(0, -7, 2, 6), "cargo")
	door(Vector2i(0, -1), Vector2i(0, -2))
	room("bay1", "Loading bay 1", Rect2i(-4, -7, 4, 4), "cargo", {"vent": true})
	door(Vector2i(-1, -5), Vector2i(0, -5))
	room("bay2", "Loading bay 2", Rect2i(2, -6, 5, 3), "cargo")
	door(Vector2i(1, -5), Vector2i(2, -5))
	room("cold", "Cold store", Rect2i(-3, -3, 2, 2), "medical", {"cold": true})
	door(Vector2i(-2, -2), Vector2i(-2, -1))
	door(Vector2i(-2, -3), Vector2i(-2, -4))
	room("dock", "Dock", Rect2i(-1, -10, 4, 3), "window")
	door(Vector2i(0, -7), Vector2i(0, -8))
	room("dockmaster", "Dockmaster's office", Rect2i(-3, -9, 2, 2), "lab")
	door(Vector2i(-3, -8), Vector2i(-3, -7))
	door(Vector2i(-2, -8), Vector2i(-1, -8))
	window(Vector2i(-2, -9), Vector2i(-1, -9))
	corridor("dockwalk", "Dock walk", Vector2i(3, -7), Vector2i(3, -9), "window")
	door(Vector2i(3, -6), Vector2i(3, -7))
	door(Vector2i(3, -8), Vector2i(2, -8))
	window(Vector2i(3, -9), Vector2i(2, -9))
	vent(Vector2i(2, -6), Vector2i(2, -10))
	vent(Vector2i(5, -4), Vector2i(1, -3))
	vent(Vector2i(-4, -7), Vector2i(-3, -9))
	vent(Vector2i(-4, -4), Vector2i(-3, -3))
	cable(Vector2i(1, -7), Vector2i(1, -8))
	root(Vector2i(6, -5))
	grow_room("bay2", 4.0)
	grow(Vector2i(1, -5), 2.6)
	grow(Vector2i(1, -6), 2.0)
	grow(Vector2i(1, -4), 2.0)
	grow(Vector2i(0, -5), 1.5)
	grow(Vector2i(1, -3), 1.4)
	grow(Vector2i(0, -6), 0.9)
	grow(Vector2i(0, -4), 0.9)
	grow(Vector2i(1, -7), 0.8)
	grow(Vector2i(3, -7), 2.2)
	grow(Vector2i(3, -8), 1.0)
	grow(Vector2i(2, -10), 1.2)
	grow(Vector2i(2, -9), 0.5)
	grow(Vector2i(-1, -5), 0.6)
	_lobby()
	_customs()
	_conveyor()
	_bay1()
	_bay2()
	_cold()
	_dock()
	_dockmaster()
	_dockwalk()
	_views()


func _lobby() -> void:
	thing("workbench", Vector2i(-1, 1), Vector3(-0.3, 0, -1.3), 0.0)
	thing("bunk", Vector2i(1, 1), Vector3(0.6, 0, -0.8), 0.0)
	prop("ess:Prop_Locker", Vector2i(-1, 2), Vector3(-1.45, 0, 0.6), 90.0)
	prop("ess:Prop_Locker", Vector2i(-1, 2), Vector3(-1.45, 0, -0.5), 90.0)
	prop("ess:Prop_Crate_Tarp", Vector2i(1, 2), Vector3(1.0, 0, 0.9), -12.0)
	pickup("flare", Vector2i(1, 2), Vector3(0.9, 0, -0.6), 2)
	thing("decal", Vector2i(0, 1), Vector3(0, 0, 0.4), 0.0, {"name": "Decal_Arrows"})


func _customs() -> void:
	prop("ess:Prop_Desk_L", Vector2i(1, -1), Vector3(0.8, 0, -0.3), 0.0)
	prop("ess:Prop_Computer", Vector2i(1, -1), Vector3(1.3, 0.94, -1.1), 0.0, {"solid": false})
	thing("log", Vector2i(1, -1), Vector3(0.3, 0.94, -0.9), 20.0, {"id": "cargo_crew", "title": "Crew list, supply run 14",
		"by": "Customs", "text": CREW})
	body(Vector2i(1, 0), Vector3(0.9, 0, 0.4), 250.0, "security")
	for x in [-1.6, 1.6]:
		thing("column", Vector2i(0, -1), Vector3(x, 0, 0.6), 0.0, {"name": "Column_Astra"})
	thing("decal", Vector2i(0, -1), Vector3(0, 0, 0.6), 0.0, {"name": "Decal_Authorized"})
	thing("decal", Vector2i(-1, 0), Vector3.ZERO, 90.0, {"name": "Decal_Line_Straight"})
	prop("ess:Prop_Locker", Vector2i(-2, 0), Vector3(-1.45, 0, 0.6), 90.0)
	prop("ess:Prop_Locker", Vector2i(-2, 0), Vector3(-1.45, 0, -0.5), 90.0)
	prop("ess:Prop_GunRack", Vector2i(-2, -1), Vector3(-1.25, 0, 0.6), 90.0)
	prop("ess:Prop_Chest", Vector2i(-1, 0), Vector3(-0.2, 0, 1.3))
	pickup("ammo:scattergun", Vector2i(-2, 0), Vector3(-0.5, 0, 1.2), 2)
	pickup("health", Vector2i(-1, -1), Vector3(0.6, 0, -1.2), 1)
	pickup("salvage", Vector2i(1, 0), Vector3(1.3, 0, -0.6), 1)


func _conveyor() -> void:
	thing("vent_panel", Vector2i(0, -4), Vector3(-1.75, 0, 0.6), 0.0, {"room": "bay1"})
	thing("decal", Vector2i(0, -5), Vector3(0, 0, 0), 90.0, {"name": "Decal_Caution"})
	thing("body", Vector2i(1, -2), Vector3(1.2, 0.76, -0.4), 0.0, {"job": "cargo"})
	spawn("taken", Vector2i(0, -3), Vector3(-0.4, 0, 0.2), 1, {"job": "command", "female": true,
		"routine": [Vector2i(0, -3), Vector2i(0, -6), Vector2i(0, -8), Vector2i(1, -8)]})
	spawn("feeder", Vector2i(0, -6), Vector3(0.5, 0, 0.2), 1)
	prop("ess:Prop_Crate", Vector2i(0, -2), Vector3(-1.2, 0, -0.8), 12.0)
	prop("Prop_Crate1", Vector2i(0, -2), Vector3(-1.2, 2.0, -0.8), 40.0)
	prop("Prop_Barrel_Large", Vector2i(0, -7), Vector3(-1.4, 0, 0.6))
	prop("Prop_Barrel_Large", Vector2i(0, -7), Vector3(-1.45, 0, 1.3))
	pickup("ammo", Vector2i(0, -4), Vector3(-0.8, 0, -1.2), 2)
	pickup("grenade", Vector2i(0, -2), Vector3(0.6, 0, 1.2), 1)
	pickup("health", Vector2i(0, -6), Vector3(-1.2, 0, -1.0), 1)


func _bay1() -> void:
	spawn("raptor", Vector2i(-3, -6), Vector3(0.4, 0, 0.4), 1)
	spawn("stalker", Vector2i(-4, -4), Vector3(-0.4, 0, 0.5), 1, {"asleep": true})
	body(Vector2i(-2, -6), Vector3(0.5, 0, 0.3), 140.0, "cargo")
	# Crate stacks to fight round, on the corners between tiles so the
	# aisles stay clear, and shelving along the walls.
	prop("ess:Prop_Crate", Vector2i(-3, -7), Vector3(2.0, 0, 2.0), 8.0)
	prop("Prop_Crate2", Vector2i(-3, -7), Vector3(2.1, 2.0, 1.9), 20.0)
	prop("ess:Prop_Crate_Tarp", Vector2i(-4, -5), Vector3(2.0, 0, 2.0), 90.0)
	prop("ess:Prop_Crate", Vector2i(-2, -5), Vector3(2.0, 0, -2.0), 30.0)
	prop("Prop_Crate4", Vector2i(-2, -5), Vector3(2.0, 2.06, -2.0), 5.0)
	for z in [-7, -6, -5]:
		prop("ess:Prop_Shelves_WideTall", Vector2i(-4, z), Vector3(-1.45, 0, 0.2), 90.0)
	prop("ess:Prop_Shelves_WideTall", Vector2i(-4, -7), Vector3(0.0, 0, -1.45))
	prop("ess:Prop_Shelves_WideTall", Vector2i(-1, -7), Vector3(-0.2, 0, -1.45))
	prop("Prop_Crate3", Vector2i(-4, -4), Vector3(-1.3, 0.5, 1.3), 25.0)
	pickup("medkit", Vector2i(-4, -7), Vector3(1.0, 0, -1.2), 1)
	pickup("ammo:scattergun", Vector2i(-4, -5), Vector3(-1.0, 0, -1.0), 3)
	pickup("salvage", Vector2i(-1, -7), Vector3(1.0, 0, -1.0), 2)
	pickup("salvage", Vector2i(-4, -6), Vector3(-0.9, 0, 0.9), 1)
	pickup("mine", Vector2i(-2, -4), Vector3(0.8, 0, 0.9), 2)
	thing("decal", Vector2i(-2, -6), Vector3(0, 0, 0), 0.0, {"name": "Decal_Numbers_One"})
	thing("decal", Vector2i(-1, -5), Vector3(0.6, 0, 0), 90.0, {"name": "Decal_Caution"})


func _bay2() -> void:
	spawn("stalker", Vector2i(3, -4), Vector3(0.4, 0, 0.6), 1, {"asleep": true})
	spawn("taken", Vector2i(4, -6), Vector3(0.0, 0, 0.5), 1, {"job": "cargo",
		"routine": [Vector2i(2, -6), Vector2i(4, -5), Vector2i(5, -6), Vector2i(1, -5), Vector2i(1, -3)]})
	spawn("skitter", Vector2i(5, -4), Vector3(0.5, 0, 0.8), 2, {"asleep": true})
	spawn("pod", Vector2i(2, -6), Vector3(-1.2, 0, -1.2), 1)
	spawn("pod", Vector2i(5, -6), Vector3(0.8, 0, -1.3), 1)
	thing("body", Vector2i(4, -4), Vector3(-0.8, 0, 0.5), 30.0, {"job": "cargo", "swallowed": true})
	prop("ess:Prop_Crate", Vector2i(3, -5), Vector3(2.0, 0, -2.0), -6.0)
	prop("Prop_Crate3", Vector2i(3, -5), Vector3(2.0, 2.0, -2.1), 10.0)
	prop("ess:Prop_Crate_Tarp", Vector2i(4, -5), Vector3(2.0, 0, 2.0), 15.0)
	prop("ess:Prop_Crate", Vector2i(2, -5), Vector3(2.0, 0, 2.0), 4.0)
	# The open case racks where SV-3 sat.
	prop("ess:Prop_Shelves_WideTall", Vector2i(2, -4), Vector3(0.0, 0, 1.45), 180.0)
	prop("ess:Prop_Shelves_WideTall", Vector2i(5, -4), Vector3(0.0, 0, 1.45), 180.0)
	prop("ess:Prop_Shelves_WideShort", Vector2i(6, -6), Vector3(1.45, 0, -0.4), -90.0)
	prop("Prop_Crate2", Vector2i(6, -4), Vector3(1.3, 0.5, 1.3), 20.0)
	prop("Prop_Crate1", Vector2i(2, -6), Vector3(-1.3, 0.5, -1.3), -10.0)
	pickup("salvage", Vector2i(2, -4), Vector3(-1.1, 0, 1.0), 2)
	pickup("ammo", Vector2i(3, -6), Vector3(1.0, 0, -1.2), 2)
	pickup("grenade", Vector2i(5, -4), Vector3(-0.6, 0, 1.2), 1)
	thing("decal", Vector2i(3, -5), Vector3(0, 0, 0), 0.0, {"name": "Decal_Numbers_Two"})


func _cold() -> void:
	thing("survivor", Vector2i(-3, -2), Vector3(0.1, 0, 0.7), 150.0, {"id": "cargo_lind", "name": "Dockmaster Ewa Lind", "job": "cargo", "female": true,
		"line": "Shut the door. It's slow in the cold, it hasn't come in here yet. I signed that case through, you know. SV-3. Without a scan. Get me to the lift."})
	prop("ess:Prop_Shelves_WideTall", Vector2i(-3, -3), Vector3(-1.45, 0, 0.0), 90.0)
	prop("ess:Prop_Shelves_WideTall", Vector2i(-3, -2), Vector3(-1.45, 0, 0.0), 90.0)
	prop("ess:Prop_Crate", Vector2i(-3, -3), Vector3(0.3, 0, -1.2), 5.0)
	prop("Prop_Crate1", Vector2i(-3, -3), Vector3(0.3, 2.0, -1.2), 30.0)
	prop("Prop_Crate3", Vector2i(-2, -3), Vector3(1.3, 0.5, 0.2), -20.0)
	thing("light", Vector2i(-3, -3), Vector3(0.5, 3.6, 0.5), 0.0, {"color": Color(0.55, 0.78, 1.0), "energy": 0.8, "range": 8.0})
	pickup("medkit", Vector2i(-2, -3), Vector3(1.0, 0, 0.4), 1)
	pickup("salvage", Vector2i(-3, -3), Vector3(0.9, 0, 1.2), 1)


func _dock() -> void:
	spawn("raptor", Vector2i(2, -9), Vector3(0.6, 0, 0.0), 1, {"asleep": true})
	thing("survivor", Vector2i(1, -8), Vector3(0.4, 0, -1.4), 180.0, {"id": "cargo_dunmore", "name": "Rafe Dunmore", "job": "cargo", "pose": "torch",
		"line": "You're not the pilot. She went up for the clearance and never came back. The Corran's fuelled. She said it would fly without her. I'll come up to the lift with you, if you'll have me."})
	thing("log", Vector2i(0, -8), Vector3(0.8, 0, -1.45), 180.0, {"id": "cargo_pilot", "style": "terminal", "title": "Pilot's note",
		"by": "Capt. Lena Marsh, pilot", "text": PILOT})
	thing("light", Vector2i(0, -9), Vector3(2.0, 4.1, 0.6), 0.0, {"color": Color(0.75, 0.85, 1.0), "energy": 0.9, "range": 10.0})
	prop("Prop_Cable3", Vector2i(-1, -9), Vector3(0.2, 0.01, 0.6), 80.0, {"solid": false})
	prop("ess:Prop_Crate", Vector2i(-1, -10), Vector3(-1.0, 0, -1.0), 10.0)
	thing("decal", Vector2i(1, -8), Vector3(0, 0, 1.0), 90.0, {"name": "Decal_Line_Straight"})
	thing("decal", Vector2i(-1, -8), Vector3(0, 0, 1.0), 90.0, {"name": "Decal_Line_Straight"})
	pickup("salvage", Vector2i(-1, -10), Vector3(-0.2, 0, -1.3), 2)
	pickup("flare", Vector2i(-1, -8), Vector3(-0.6, 0, -1.2), 2)
	pickup("health", Vector2i(2, -8), Vector3(1.3, 0, 1.3), 1)


func _dockmaster() -> void:
	prop("ess:Prop_Desk_Medium", Vector2i(-2, -9), Vector3(1.0, 0, 0), 90.0)
	thing("log", Vector2i(-2, -9), Vector3(1.15, 0.94, 0.5), -90.0, {"id": "cargo_manifest", "style": "terminal", "title": "Manifest, inbound",
		"by": "Dockmaster Ewa Lind", "text": MANIFEST})
	prop("ess:Prop_Screen", Vector2i(-2, -9), Vector3(1.2, 0.94, -0.7), -90.0, {"solid": false})
	prop("ess:Prop_Chair", Vector2i(-2, -9), Vector3(-0.1, 0, 0.1), 90.0)
	prop("ess:Prop_Shelves_ThinTall", Vector2i(-3, -9), Vector3(0.0, 0, -1.45))
	prop("ess:Prop_Locker", Vector2i(-3, -8), Vector3(-1.45, 0, 0.0), 90.0)
	prop("ess:Prop_Locker", Vector2i(-3, -9), Vector3(-1.45, 0, 0.6), 90.0)
	pickup("cell", Vector2i(-3, -9), Vector3(-0.9, 0, -0.9), 1)
	pickup("salvage", Vector2i(-2, -8), Vector3(0.9, 0, 1.2), 1)


func _dockwalk() -> void:
	spawn("pod", Vector2i(3, -7), Vector3(1.0, 0, -1.2), 1)
	body(Vector2i(3, -8), Vector3(0.5, 0, 0.6), 200.0, "cargo")
	pickup("ammo:scattergun", Vector2i(3, -9), Vector3(1.0, 0, -1.2), 2)
	for z in [-7, -8, -9]:
		prop("Prop_RailStraight_Four", Vector2i(3, z), Vector3(1.5, 0, 2.0), 0.0, {"solid": false})


func _views() -> void:
	view("arrival", Vector3(0, 1.65, 5.6), 0.0, -3.0)
	view("customs", Vector3(5.0, 1.65, 1.0), 55.0, -6.0)
	view("conveyor", Vector3(1.0, 1.65, -7.2), 0.0, -3.0)
	view("bay_1", Vector3(-3.0, 1.65, -15.0), 45.0, -4.0)
	view("bay_2", Vector3(7.0, 1.65, -16.0), -65.0, -4.0)
	view("cold_store", Vector3(-7.0, 1.65, -7.0), 45.0, -8.0)
	view("dock", Vector3(9.2, 1.65, -30.8), 52.0, 0.0)
	view("shuttle", Vector3(-5.2, 1.65, -30.8), -50.0, 0.0)
	view("dockmaster", Vector3(-13.2, 1.65, -30.8), -62.0, -4.0)
	view("dock_walk", Vector3(12.0, 1.65, -26.6), 0.0, 0.0)


func decorate() -> void:
	Fit.shuttle(self, Vector3(2.0, 0, -38.0))
	Fit.conveyor(self, Vector3(5.15, 0, -29.3), Vector3(5.15, 0, -22.8), 1.1, 2, 7)
	Fit.conveyor(self, Vector3(5.15, 0, -17.2), Vector3(5.15, 0, -6.6), 1.1, 3, 8)
	Fittings.cocoon(self, DeckLevel.center(Vector2i(6, -6)) + Vector3(1.5, 0, -1.2), -PI * 0.5, 21)
	Fittings.cocoon(self, DeckLevel.center(Vector2i(6, -4)) + Vector3(1.5, 0, 0.4), -PI * 0.5, 22)
	Fittings.drag(self, DeckLevel.center(Vector2i(3, -8)) + Vector3(0.5, 0, 0.6), DeckLevel.center(Vector2i(3, -6)))
	Fittings.drag(self, DeckLevel.center(Vector2i(-2, -6)) + Vector3(0.5, 0, 0.3), DeckLevel.center(Vector2i(-1, -5)) + Vector3(1.0, 0, 0))
