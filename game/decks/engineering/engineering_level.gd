extends DeckLevel
## Engineering: the lift lobby off the long gangway that runs the width of
## the deck, the reactor hall north of it with the root grown into the
## reactor's core behind, the control room and the chief engineer's office
## looking into the hall, the generators and the fuel stores east, the
## coolant pumps and the workshop west, and two dark crawlways over the
## ends of the plant, joined to the core by the ducts.
##
##   z -8..-7  crawl_w (x -7..-5, z -7)    core (-1..1), root (0, -8)
##   z -7..-6  office (-4..-3)              crawl_e (4..6, -6)
##   z -6..-4  control (-4..-3, -5..-4) | reactor hall (-2..2) | generators (3..5, -5..-4)
##   z  -3     coolant pumps (-7..-6, -4..-2) == gangway (-5..5) == crawl_e (6, -3..-6)
##   z -2..-1  workshop (-5..-3)   lift lobby (-1..1), lift (0, -1)   fuel stores (3..4)

const Plant := preload("res://game/decks/engineering/engineering_plant.gd")

const SHEDDING := """Order 1, 22:05. The growth in Hydroponics follows the nutrient heaters. Cutting Hydroponics to emergency power. If it lives on our heat, it starves.

Order 2, 23:40. Hydroponics is dark and it grew faster. Okafor told me before she went down to the Core: it doesn't want heat, it wants the dark. Restoring Hydroponics. MARI says she can't: organic obstruction in the junctions.

Order 3, 01:15. It's in the ducts over the reactor now. Shedding Crew quarters, Medical and Labs to keep the core cool. I know what dark does to them now. The plant comes first, or there's no station to come back to.

Order 4. Three spare cells on the charging rack in the generator room. Whoever reads this: send them where people are still alive."""

const CRAWL := """Nobody goes into the east crawlway alone. I was relaying the duct sensors and something knocked on the pipe ahead of me. I knocked back. It knocked back, three times, the same as me.

Then it came down the duct towards me, faster than anyone can crawl. I never saw it. It stopped when I stopped breathing.

It hunts by sound. Shut the hatch behind you, walk, don't run, and don't fire in the long gangway unless you want everything on the deck to come and look."""

const REACTOR := """Reactor status, 02:51. Reactor temperature 431 K (normal 380 K). Coolant flow 58%. Cause: organic obstruction in coolant loop B.

Output shed to decks 1 to 5 by order of the chief engineer. Decks 6 and 7 on full power. Spare cells charged: 3.

Recommendation: clear coolant loop B. Recommendation assigned to: night shift."""

const JOBS := """Hydroponics lift is eating cells again. Nadia says it's the coupling. Bring it down and I'll strip it. Arlo

Cargo wants the shuttle's fuel lines checked before the next supply run. Done, signed off. Arlo

Whoever keeps borrowing the good cutter from this bench: it is not yours. Put it back. I. Varga"""


func build() -> void:
	default_style("corridor")
	room("lobby", "Lift lobby", Rect2i(-1, -2, 3, 2))
	lift(Vector2i(0, -1), "S")
	corridor("gangway_w", "West gangway", Vector2i(-5, -3), Vector2i(-1, -3))
	corridor("gangway_e", "East gangway", Vector2i(0, -3), Vector2i(5, -3))
	arch(Vector2i(1, -2), Vector2i(1, -3))
	door(Vector2i(-1, -3), Vector2i(0, -3))
	room("reactor", "Reactor hall", Rect2i(-2, -6, 5, 3), "engine", {"warm": 1.2})
	door(Vector2i(1, -4), Vector2i(1, -3))
	room("core", "Reactor core", Rect2i(-1, -8, 3, 2), "core", {"dark": true, "warm": 1.4})
	door(Vector2i(1, -6), Vector2i(1, -7), {"jammed": true})
	room("control", "Control room", Rect2i(-4, -5, 2, 2), "lab")
	window(Vector2i(-3, -5), Vector2i(-2, -5))
	door(Vector2i(-3, -4), Vector2i(-2, -4))
	door(Vector2i(-4, -4), Vector2i(-4, -3))
	room("office", "Chief engineer's office", Rect2i(-4, -7, 2, 2), "lab")
	window(Vector2i(-3, -6), Vector2i(-2, -6))
	door(Vector2i(-4, -6), Vector2i(-4, -5))
	room("generator", "Generator room", Rect2i(3, -5, 3, 2), "engine")
	door(Vector2i(2, -5), Vector2i(3, -5))
	door(Vector2i(4, -4), Vector2i(4, -3))
	room("pumps", "Coolant pumps", Rect2i(-7, -4, 2, 3), "engine", {"warm": 1.3})
	door(Vector2i(-6, -3), Vector2i(-5, -3))
	room("workshop", "Workshop", Rect2i(-5, -2, 3, 2), "cargo")
	door(Vector2i(-4, -2), Vector2i(-4, -3))
	room("fuel", "Fuel stores", Rect2i(3, -2, 2, 2), "cargo")
	door(Vector2i(3, -2), Vector2i(3, -3))
	room_cells("crawl_e", "East crawlway", [Vector2i(6, -3), Vector2i(6, -4), Vector2i(6, -5), Vector2i(6, -6), Vector2i(5, -6), Vector2i(4, -6)], "corridor", {"dark": true})
	door(Vector2i(5, -3), Vector2i(6, -3))
	door(Vector2i(4, -6), Vector2i(4, -5))
	room_cells("crawl_w", "West crawlway", [Vector2i(-7, -5), Vector2i(-7, -6), Vector2i(-7, -7), Vector2i(-6, -7), Vector2i(-5, -7)], "corridor", {"dark": true})
	door(Vector2i(-7, -4), Vector2i(-7, -5))
	door(Vector2i(-5, -7), Vector2i(-4, -7))
	# The ducts: both crawlways reach the core, and the ends of the plant.
	vent(Vector2i(1, -8), Vector2i(4, -6))
	vent(Vector2i(-1, -8), Vector2i(-5, -7))
	vent(Vector2i(6, -4), Vector2i(4, -2))
	vent(Vector2i(-6, -2), Vector2i(-5, -1))
	cable(Vector2i(-2, -5), Vector2i(-3, -5))
	cable(Vector2i(2, -4), Vector2i(3, -4))
	root(Vector2i(0, -8))
	grow_room("core", 4.0)
	for x in range(-2, 3):
		grow(Vector2i(x, -6), 3.2)
		grow(Vector2i(x, -5), 2.3)
		grow(Vector2i(x, -4), 1.2)
	grow(Vector2i(4, -6), 2.2)
	grow(Vector2i(5, -6), 1.7)
	grow(Vector2i(6, -6), 1.1)
	grow(Vector2i(6, -5), 0.5)
	grow(Vector2i(-5, -7), 2.0)
	grow(Vector2i(-6, -7), 1.4)
	grow(Vector2i(-7, -7), 0.7)
	grow(Vector2i(-3, -5), 0.8)
	grow(Vector2i(3, -5), 1.1)
	_lobby()
	_gangway()
	_reactor()
	_core()
	_control_and_office()
	_generators()
	_pumps_and_workshop()
	_fuel()
	_crawlways()
	_views()


func _lobby() -> void:
	thing("workbench", Vector2i(-1, -2), Vector3(0, 0, -1.3), 0.0)
	thing("bunk", Vector2i(-1, -1), Vector3(-0.6, 0, 0.6), 0.0)
	prop("ess:Prop_Locker", Vector2i(1, -1), Vector3(1.45, 0, 0.6), -90.0)
	prop("ess:Prop_Locker", Vector2i(1, -1), Vector3(1.45, 0, -0.5), -90.0)
	prop("ess:Prop_Shelves_ThinShort", Vector2i(0, -2), Vector3(0.0, 0, -1.45))
	pickup("flare", Vector2i(1, -2), Vector3(1.2, 0, -0.9), 2)
	thing("decal", Vector2i(1, -2), Vector3(0, 0, 0.2), 0.0, {"name": "Decal_Arrows"})


func _gangway() -> void:
	# West: the long run to the coolant pumps.
	prop("Prop_Barrel_Large", Vector2i(-2, -3), Vector3(0.4, 0, 1.45))
	prop("Prop_Barrel_Large", Vector2i(-2, -3), Vector3(-0.2, 0, 1.5))
	prop("Prop_Crate2", Vector2i(-3, -3), Vector3(1.0, 0.5, -1.4), 15.0)
	pickup("health", Vector2i(-2, -3), Vector3(-1.0, 0, -1.3), 1)
	pickup("ammo:scattergun", Vector2i(-3, -3), Vector3(-0.6, 0, 1.4), 2)
	body(Vector2i(-5, -3), Vector3(0.4, 0, 1.0), 110.0, "tech")
	thing("decal", Vector2i(-3, -3), Vector3.ZERO, 90.0, {"name": "Decal_Line_Straight"})
	thing("decal", Vector2i(-1, -3), Vector3(0.6, 0, 0), 90.0, {"name": "Decal_Caution"})
	# East: a turret looking down the gangway to the crawlway hatch.
	thing("turret", Vector2i(2, -3), Vector3(0.4, 0, 1.3), -90.0)
	prop("Prop_Crate4", Vector2i(5, -3), Vector3(1.2, 0.56, 1.3), 25.0)
	thing("log", Vector2i(5, -3), Vector3(1.2, 1.12, 1.3), -120.0, {"id": "eng_crawl", "title": "Note on the crawlway hatch",
		"by": "Arlo Benn, plant tech", "text": CRAWL})
	pickup("health", Vector2i(3, -3), Vector3(0.4, 0, -1.3), 1)
	thing("decal", Vector2i(2, -3), Vector3.ZERO, 90.0, {"name": "Decal_Line_Straight"})
	thing("decal", Vector2i(5, -3), Vector3(1.0, 0, 0), 90.0, {"name": "Decal_Warning"})


func _reactor() -> void:
	spawn("stalker", Vector2i(-1, -6), Vector3(-0.4, 0, -0.9), 1, {"asleep": true})
	spawn("pod", Vector2i(2, -6), Vector3(1.0, 0, -1.1), 1)
	spawn("pod", Vector2i(-2, -6), Vector3(-1.1, 0, -0.9), 1)
	body(Vector2i(1, -6), Vector3(-0.7, 0, 0.8), 200.0, "engineer")
	thing("body", Vector2i(-1, -4), Vector3(-0.6, 0, 1.2), 80.0, {"job": "engineer", "swallowed": true})
	thing("column", Vector2i(2, -4), Vector3(1.4, 0, 1.4), 0.0, {"name": "Column_Hollow"})
	thing("column", Vector2i(2, -6), Vector3(1.4, 0, -1.4), 0.0, {"name": "Column_Hollow"})
	prop("ess:Prop_Computer", Vector2i(0, -4), Vector3(0.8, 0, 1.55), 180.0)
	prop("ess:Prop_Computer", Vector2i(-1, -4), Vector3(0.6, 0, 1.55), 180.0)
	prop("Prop_Cable3", Vector2i(1, -5), Vector3(0.4, 0.01, 0.4), 30.0, {"solid": false})
	prop("Prop_Cable2", Vector2i(-1, -5), Vector3(-0.6, 0.01, 0.2), -60.0, {"solid": false})
	prop("Prop_Barrel_Small", Vector2i(2, -4), Vector3(1.4, 0, 0.9))
	prop("Prop_Barrel_Small", Vector2i(2, -4), Vector3(0.9, 0, 1.4), 40.0)
	pickup("ammo", Vector2i(2, -4), Vector3(0.5, 0, 0.4), 2)
	pickup("grenade", Vector2i(-2, -5), Vector3(-1.2, 0, 0.6), 1)
	thing("decal", Vector2i(1, -4), Vector3(0, 0, 0.6), 0.0, {"name": "Decal_Caution"})
	thing("decal", Vector2i(-2, -4), Vector3(0.5, 0, 0.5), 0.0, {"name": "Decal_Numbers_Six"})


func _core() -> void:
	prop("Prop_Pod", Vector2i(-1, -8), Vector3(-0.6, 0, -0.6))
	prop("Prop_Pod", Vector2i(1, -8), Vector3(0.6, 0, -0.6))
	prop("Prop_Pipe_Thick_Straight", Vector2i(0, -7), Vector3(0, 4.4, 1.5), 90.0, {"solid": false})
	body(Vector2i(-1, -7), Vector3(-0.4, 0, 0.6), 30.0, "engineer")
	pickup("salvage", Vector2i(1, -7), Vector3(1.2, 0, 0.9), 2)


func _control_and_office() -> void:
	# Control: desks along the windows onto the reactor, and the status page.
	prop("ess:Prop_Desk_Medium", Vector2i(-3, -5), Vector3(0.9, 0, 0.1), 90.0)
	prop("ess:Prop_Screen", Vector2i(-3, -5), Vector3(1.05, 0.94, 0.8), -90.0, {"solid": false})
	thing("log", Vector2i(-3, -5), Vector3(1.0, 0.94, -0.6), -90.0, {"id": "eng_reactor", "style": "terminal", "title": "Reactor status",
		"by": "MARI", "text": REACTOR})
	prop("ess:Prop_Chair", Vector2i(-3, -5), Vector3(-0.2, 0, 0.2), 90.0)
	prop("ess:Prop_Desk_Small", Vector2i(-4, -4), Vector3(-1.2, 0, 0.2), 90.0)
	prop("ess:Prop_Computer", Vector2i(-4, -4), Vector3(-1.4, 0.94, 0.5), 90.0, {"solid": false})
	prop("ess:Prop_CeilingComputer", Vector2i(-4, -5), Vector3(0, Kit.HEIGHT, -0.4), 0.0, {"solid": false})
	thing("survivor", Vector2i(-4, -5), Vector3(0.6, 0, -0.7), -100.0, {"id": "eng_varga", "name": "Chief Engineer Ilse Varga",
		"job": "engineer", "pose": "fold", "female": true,
		"line": "You got the lift running? Then there's power left. I shut the decks down one by one to starve it, and it liked the dark. Get the spare cells out to the ring. I'll make my way to the lift."})
	pickup("ammo", Vector2i(-3, -4), Vector3(1.0, 0, 1.2), 2)
	# The office: her desk, her orders, and a cell she kept back.
	prop("ess:Prop_Desk_L", Vector2i(-3, -7), Vector3(0.6, 0, -0.9), 0.0)
	prop("ess:Prop_Chair", Vector2i(-3, -7), Vector3(0.2, 0, 0.3), 160.0)
	prop("ess:Prop_Screen", Vector2i(-3, -7), Vector3(0.9, 0.94, -1.4), 0.0, {"solid": false})
	thing("log", Vector2i(-3, -7), Vector3(-0.1, 0.94, -1.3), 10.0, {"id": "eng_shedding", "title": "Load-shedding orders",
		"by": "Chief Engineer Ilse Varga", "text": SHEDDING})
	prop("ess:Prop_Shelves_ThinTall", Vector2i(-4, -7), Vector3(-0.3, 0, -1.45))
	prop("ess:Prop_Locker", Vector2i(-4, -6), Vector3(-1.45, 0, 0.6), 90.0)
	pickup("cell", Vector2i(-4, -7), Vector3(-1.1, 0, -0.9), 1)
	pickup("medkit", Vector2i(-4, -6), Vector3(-0.8, 0, -0.6), 1)
	pickup("salvage", Vector2i(-3, -6), Vector3(1.1, 0, 0.9), 1)


func _generators() -> void:
	spawn("taken", Vector2i(5, -4), Vector3(-0.6, 0, 0.2), 1, {"job": "engineer",
		"routine": [Vector2i(3, -5), Vector2i(5, -5), Vector2i(4, -4), Vector2i(4, -3), Vector2i(2, -3)]})
	pickup("cell", Vector2i(3, -5), Vector3(0.6, 0, -1.4), 1)
	pickup("salvage", Vector2i(5, -5), Vector3(-0.8, 0, -1.4), 2)
	pickup("ammo", Vector2i(3, -4), Vector3(1.2, 0, 0.2), 2)
	body(Vector2i(4, -5), Vector3(0.5, 0, 0.3), 290.0, "engineer")
	prop("Prop_Pipe_Thick_Straight", Vector2i(4, -5), Vector3(0, 4.4, -1.5), 90.0, {"solid": false})
	prop("Prop_Pipe_Thick_Straight", Vector2i(3, -5), Vector3(0, 4.4, -1.5), 90.0, {"solid": false})
	thing("decal", Vector2i(4, -4), Vector3(0, 0, 0.8), 0.0, {"name": "Decal_Warning"})


func _pumps_and_workshop() -> void:
	prop("Prop_Pod_Short", Vector2i(-6, -2), Vector3(0.5, 0, 0.6))
	prop("Prop_PipeHolder", Vector2i(-6, -4), Vector3(0.3, 0, -1.3), 0.0)
	thing("column", Vector2i(-6, -3), Vector3(1.4, 0, -1.4), 0.0, {"name": "Column_Pipes"})
	prop("Prop_Pipe_Thick_Straight", Vector2i(-7, -3), Vector3(-1.5, 4.3, 0), 0.0, {"solid": false})
	prop("Prop_Pipe_Thick_Straight", Vector2i(-7, -2), Vector3(-1.5, 4.3, 0), 0.0, {"solid": false})
	body(Vector2i(-6, -4), Vector3(-0.6, 0, -0.8), 60.0, "engineer")
	spawn("skitter", Vector2i(-7, -2), Vector3(0.6, 0, 0.6), 1, {"asleep": true})
	pickup("health", Vector2i(-6, -3), Vector3(0.9, 0, 0.4), 1)
	pickup("salvage", Vector2i(-7, -4), Vector3(-1.1, 0, -1.2), 1)
	# The workshop.
	prop("ess:Prop_Desk_Large", Vector2i(-4, -1), Vector3(0, 0, 0.6))
	prop("ess:Prop_Screen", Vector2i(-4, -1), Vector3(0.9, 1.0, 1.2), 180.0, {"solid": false})
	thing("log", Vector2i(-4, -1), Vector3(-0.8, 1.0, 0.8), 160.0, {"id": "eng_jobs", "title": "Workshop job board",
		"by": "Engineering", "text": JOBS})
	prop("ess:Prop_GunRack", Vector2i(-5, -2), Vector3(-1.25, 0, 0.2), 90.0)
	prop("ess:Prop_Shelves_WideTall", Vector2i(-3, -1), Vector3(1.45, 0, 0.2), -90.0)
	prop("ess:Prop_Chest", Vector2i(-5, -1), Vector3(-1.1, 0, 1.2))
	prop("ess:Prop_Crate", Vector2i(-3, -2), Vector3(1.0, 0, -1.0), 10.0)
	spawn("taken", Vector2i(-5, -1), Vector3(0.4, 0, -0.4), 1, {"job": "tech",
		"routine": [Vector2i(-5, -2), Vector2i(-3, -1), Vector2i(-4, -3), Vector2i(-2, -3)]})
	pickup("mine", Vector2i(-5, -1), Vector3(-0.2, 0, 0.6), 2)
	pickup("ammo:scattergun", Vector2i(-3, -1), Vector3(0.4, 0, 1.2), 3)
	pickup("medkit", Vector2i(-4, -2), Vector3(-1.2, 0, -0.9), 1)
	pickup("salvage", Vector2i(-5, -2), Vector3(-0.6, 0, -1.2), 3)


func _fuel() -> void:
	prop("ess:Prop_Barrel1", Vector2i(3, -2), Vector3(-1.3, 0, 0.9))
	prop("ess:Prop_Barrel2_Closed", Vector2i(3, -2), Vector3(-1.4, 0, 0.1))
	prop("ess:Prop_Barrel2_Closed", Vector2i(3, -1), Vector3(-1.4, 0, -0.6), 30.0)
	prop("ess:Prop_Crate_Tarp", Vector2i(3, -1), Vector3(-0.8, 0, 1.0), 8.0)
	thing("survivor", Vector2i(4, -1), Vector3(-0.6, 0, 0.9), 200.0, {"id": "eng_kim", "name": "Rosa Kim", "job": "tech", "female": true,
		"line": "Don't shout. It hears everything on this deck. I've been sat behind the tanks since the lights went. I'll go to the lift. Quietly."})
	pickup("cell", Vector2i(3, -1), Vector3(0.4, 0, 1.3), 1)
	pickup("salvage", Vector2i(4, -2), Vector3(-0.8, 0, -1.2), 1)


func _crawlways() -> void:
	spawn("stalker", Vector2i(6, -3), Vector3(0.5, 0, -0.7), 1, {"asleep": true})
	spawn("pod", Vector2i(4, -6), Vector3(-0.9, 0, -0.9), 1)
	thing("body", Vector2i(6, -5), Vector3(0.3, 0, 0.6), 170.0, {"job": "tech", "swallowed": true})
	pickup("flare", Vector2i(6, -5), Vector3(-1.0, 0, -1.0), 2)
	pickup("ammo:scattergun", Vector2i(6, -6), Vector3(1.0, 0, -1.0), 2)
	for c in [Vector2i(6, -4), Vector2i(6, -5)]:
		prop("Prop_Pipe_Thick_Straight", c, Vector3(1.5, 4.2, 0), 0.0, {"solid": false})
	prop("Prop_Pipe_Thick_Straight", Vector2i(5, -6), Vector3(0, 4.2, -1.5), 90.0, {"solid": false})
	prop("Prop_Cable2", Vector2i(6, -4), Vector3(-0.5, 0.01, 0), 0.0, {"solid": false})
	spawn("skitter", Vector2i(-6, -7), Vector3(0.2, 0, 0.3), 2, {"asleep": true})
	pickup("health", Vector2i(-7, -5), Vector3(-1.0, 0, 0.8), 1)
	pickup("salvage", Vector2i(-7, -7), Vector3(-1.1, 0, -1.1), 1)
	for c in [Vector2i(-7, -5), Vector2i(-7, -6)]:
		prop("Prop_Pipe_Thick_Straight", c, Vector3(-1.5, 4.2, 0), 0.0, {"solid": false})
	prop("Prop_Pipe_Thick_Straight", Vector2i(-6, -7), Vector3(0, 4.2, -1.5), 90.0, {"solid": false})
	prop("Prop_Cable4", Vector2i(-7, -6), Vector3(0.6, 0.01, 0), 0.0, {"solid": false})


func _views() -> void:
	view("arrival", Vector3(0, 1.65, -5.6), -14.0, -3.0)
	view("gangway_west", Vector3(-3.0, 1.65, -12.0), 90.0, -2.0)
	view("gangway_east", Vector3(1.0, 1.65, -11.0), -95.0, -2.0)
	view("reactor", Vector3(-8.5, 1.65, -15.0), -48.0, 4.0)
	view("core", Vector3(4.6, 1.65, -27.0), 38.0, -6.0)
	view("control", Vector3(-17.3, 1.65, -14.8), -62.0, -4.0)
	view("office", Vector3(-11.0, 1.65, -23.0), 55.0, -8.0)
	view("generators", Vector3(11.5, 1.65, -17.0), -62.0, -6.0)
	view("crawl_east", Vector3(22.9, 1.65, -10.4), -4.0, -6.0)
	view("crawl_west", Vector3(-28.0, 1.65, -19.0), 0.0, -4.0)
	view("pumps", Vector3(-23.0, 1.65, -14.0), 125.0, -8.0)
	view("workshop", Vector3(-11.0, 1.65, -9.0), 110.0, -8.0)
	view("fuel_stores", Vector3(11.0, 1.65, -9.0), -135.0, -8.0)


func decorate() -> void:
	Plant.reactor(self, DeckLevel.center(Vector2i(0, -5)))
	Plant.generator(self, Vector3(20.75, 0, -18.0), PI * 0.5)
	Plant.generator(self, Vector3(12.2, 0, -15.25), 0.0, false)
	Plant.charger(self, Vector3(12.4, 0, -21.5), 0.0, 1)
	Plant.tank(self, Vector3(-28.7, 0, -13.0))
	Plant.tank(self, Vector3(-28.7, 0, -9.2))
	Plant.tank(self, Vector3(16.7, 0, -8.3), true)
	Plant.tank(self, Vector3(16.7, 0, -4.6), true, 0.75, 2.8)
	Fittings.cocoon(self, DeckLevel.center(Vector2i(-1, -8)) + Vector3(-1.4, 0, 0.6), PI * 0.5, 11)
	Fittings.cocoon(self, DeckLevel.center(Vector2i(1, -7)) + Vector3(1.5, 0, -1.0), -PI * 0.5, 12)
	Fittings.drag(self, DeckLevel.center(Vector2i(5, -3)) + Vector3(-0.5, 0, 0.8), DeckLevel.center(Vector2i(6, -5)) + Vector3(0.3, 0, 0.6))
	Fittings.drag(self, DeckLevel.center(Vector2i(-1, -6)) + Vector3(0.4, 0, 0.2), DeckLevel.center(Vector2i(0, -7)))
