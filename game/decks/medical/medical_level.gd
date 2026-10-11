extends DeckLevel
## Medical: the lift lobby and triage, the main corridor east past the ward
## and surgery, the locked pharmacy and the chief medical officer's office,
## the morgue, and behind them the dark isolation corridor with its two
## isolation rooms and the quarantine ward, sealed on the first patients. The
## Bloom took root in quarantine and got out through the vents.
##
##   z -5..-4                     iso 1 (5)  iso 2 (7)    quarantine (9..11, root at (10, -5))
##   z -3                         isolation corridor (5..11) ==S==   ==S==
##   z -2..-1             pharmacy (4..5)  office (6..7)  | (8) |  morgue (9..11)
##   z  0     lobby (-2..-1) _ triage (0..2) | main corridor (3..11)
##   z  1..3                         ward (3..6) | surgery (7..9, z 1..2)
##
## Two loops: the isolation corridor round through the morgue, and the ward
## through surgery.

const Furniture := preload("res://game/decks/medical/medical_fittings.gd")

const CMO_NOTES := """Day 18. P. Brennan, botanist, admitted with a grey rash on both forearms. Warm to the touch. No pain. Sent back to hydroponics with cream.

Day 19. Brennan back, with two more from hydroponics. The rash is raised now, in lines that follow the veins. Under the microscope it is not a rash. It is root hair, growing in the tissue and feeding on the blood supply.

Day 20. Cut a section out of Brennan's arm. It grew back overnight, towards the dressing on the next bed. Six admitted. All of them sleep too much and walk in their sleep, always to the same places.

Day 21. Brennan died at 04:10. At 04:50 the night nurse found him standing at the foot of his bed. He was not breathing. He still isn't. I have ordered quarantine for everyone from hydroponics."""

const LETTER := """Mum, they've moved me to the ward, so don't worry if the messages are slow. It's only a rash. The doctor here is very good. She keeps taking pictures of my arms.

I can't feel my left hand much now, but it's warm all the time, which is nice up here. Everyone on the ward dreams about the same thing. Somewhere warm and dark, and something growing very slowly, and being part of it.

I'll call when I'm out. Tell Dad the tomato seeds I sent are from the station. Plant them somewhere sunny."""

const ORDER := """QUARANTINE ORDER, Medical, day 21.

Everyone admitted from hydroponics is confined to the quarantine ward until further notice. Both doors are sealed. Nobody opens them without my word, whatever you hear from inside.

Staff entering this corridor wear full suits. Burn the suits after.

Dr Helena Sorensen, chief medical officer. Countersigned: Deck Officer Hale."""

const BOARD := """Admitted tonight: 14. Discharged: 0. Beds free: 0.

Bodies in the morgue: 6. Bodies in the morgue at the last count: 4.

Morgue temperature rising. Cause: organic obstruction.

Night staff on the ward: please answer your pager."""


func build() -> void:
	default_style("medical")
	room("lobby", "Lift lobby", Rect2i(-2, -1, 2, 3), "corridor")
	lift(Vector2i(-2, 0), "W")
	room("triage", "Triage", Rect2i(0, -1, 3, 3))
	arch(Vector2i(-1, 0), Vector2i(0, 0))
	corridor("hall", "Main corridor", Vector2i(3, 0), Vector2i(11, 0))
	door(Vector2i(2, 0), Vector2i(3, 0))
	room("ward", "Ward", Rect2i(3, 1, 4, 3))
	door(Vector2i(5, 0), Vector2i(5, 1))
	room("surgery", "Surgery", Rect2i(7, 1, 3, 2))
	door(Vector2i(9, 0), Vector2i(9, 1))
	door(Vector2i(6, 2), Vector2i(7, 2))
	room("pharmacy", "Pharmacy", Rect2i(4, -2, 2, 2), "lab")
	door(Vector2i(4, 0), Vector2i(4, -1), {"locked": "pharmacy"})
	room("office", "Chief medical officer's office", Rect2i(6, -2, 2, 2), "lab")
	door(Vector2i(6, 0), Vector2i(6, -1))
	room_cells("isolation", "Isolation corridor", [Vector2i(8, -1), Vector2i(8, -2), Vector2i(5, -3), Vector2i(6, -3), Vector2i(7, -3),
		Vector2i(8, -3), Vector2i(9, -3), Vector2i(10, -3), Vector2i(11, -3)], "corridor", {"dark": true})
	door(Vector2i(8, 0), Vector2i(8, -1))
	room("morgue", "Morgue", Rect2i(9, -2, 3, 2), "medical", {"warm": 0.7})
	door(Vector2i(10, 0), Vector2i(10, -1))
	door(Vector2i(10, -3), Vector2i(10, -2))
	room("iso_1", "Isolation room 1", Rect2i(5, -4, 1, 1))
	door(Vector2i(5, -3), Vector2i(5, -4))
	room("iso_2", "Isolation room 2", Rect2i(7, -4, 1, 1))
	door(Vector2i(7, -3), Vector2i(7, -4))
	room("quarantine", "Quarantine ward", Rect2i(9, -5, 3, 2), "medical", {"dark": true, "warm": 1.3})
	door(Vector2i(9, -3), Vector2i(9, -4), {"sealed": true})
	door(Vector2i(11, -3), Vector2i(11, -4), {"sealed": true})
	vent(Vector2i(11, -5), Vector2i(11, -2))
	vent(Vector2i(9, -5), Vector2i(7, -4))
	vent(Vector2i(9, -1), Vector2i(6, 3))
	cable(Vector2i(10, -4), Vector2i(8, 1))
	root(Vector2i(10, -5))
	grow_room("quarantine", 4.0)
	grow(Vector2i(11, -2), 3.0)
	grow(Vector2i(11, -1), 2.6)
	grow(Vector2i(10, -2), 2.4)
	grow(Vector2i(10, -1), 2.0)
	grow(Vector2i(9, -2), 1.8)
	grow(Vector2i(9, -1), 1.4)
	grow(Vector2i(7, -4), 2.2)
	grow(Vector2i(10, -3), 1.4)
	grow(Vector2i(9, -3), 1.0)
	grow(Vector2i(11, -3), 1.0)
	grow(Vector2i(7, -3), 0.6)
	grow(Vector2i(10, 0), 1.2)
	grow(Vector2i(11, 0), 1.0)
	grow(Vector2i(9, 0), 0.6)
	grow(Vector2i(8, 1), 1.2)
	grow(Vector2i(9, 1), 0.5)
	grow(Vector2i(6, 3), 0.6)
	_lobby()
	_triage()
	_hall()
	_ward()
	_surgery()
	_pharmacy()
	_office()
	_isolation()
	_morgue()
	_quarantine()
	_views()


func _lobby() -> void:
	thing("workbench", Vector2i(-1, -1), Vector3(0, 0, -1.25), 0.0)
	thing("bunk", Vector2i(-1, 1), Vector3(0.5, 0, 0.55), 0.0)
	prop("ess:Prop_Locker", Vector2i(-2, 1), Vector3(-1.5, 0, 0.7), 90.0)
	prop("ess:Prop_Locker", Vector2i(-2, -1), Vector3(-1.5, 0, -0.7), 90.0)
	pickup("flare", Vector2i(-2, 1), Vector3(0.6, 0, 1.2), 2)
	thing("decal", Vector2i(-1, 0), Vector3(0.6, 0, 0), 90.0, {"name": "Decal_Arrows"})


func _triage() -> void:
	thing("log", Vector2i(0, -1), Vector3(-1.5, 0, 0.6), 90.0, {"id": "medical_board", "style": "terminal", "title": "Triage board",
		"by": "MARI", "text": BOARD})
	body(Vector2i(1, 1), Vector3(-0.6, 0, -0.6), 300.0, "tech")
	pickup("medkit", Vector2i(2, -1), Vector3(1.2, 0, 0.9), 1)
	pickup("health", Vector2i(0, 1), Vector3(-1.2, 0, -0.4), 1)
	pickup("health", Vector2i(2, 1), Vector3(1.0, 0, -0.9), 1)
	pickup("stim", Vector2i(1, -1), Vector3(-0.2, 0, 0.6), 1)
	spawn("taken", Vector2i(1, 0), Vector3(0.5, 0, 0.5), 1, {"job": "medic", "female": true,
		"routine": [Vector2i(0, -1), Vector2i(2, 1), Vector2i(3, 0), Vector2i(4, 0), Vector2i(1, 0), Vector2i(2, -1)]})


func _hall() -> void:
	# The first feeder, in the light where you can see it.
	spawn("feeder", Vector2i(6, 0), Vector3(0, 0, 0.2), 1)
	body(Vector2i(10, 0), Vector3(-0.6, 0, 0.6), 80.0, "cargo")
	pickup("health", Vector2i(3, 0), Vector3(0.6, 0, 1.2), 1)
	pickup("ammo:scattergun", Vector2i(11, 0), Vector3(1.2, 0, 0.9), 1)
	thing("decal", Vector2i(5, 0), Vector3.ZERO, 90.0, {"name": "Decal_Line_Straight"})
	thing("decal", Vector2i(8, 0), Vector3(0, 0, -0.9), 0.0, {"name": "Decal_Caution"})


func _ward() -> void:
	thing("log", Vector2i(4, 2), Vector3(0.5, 0, 1.4), 30.0, {"id": "medical_letter", "title": "Message home (not sent)",
		"by": "Leo Marsh, patient", "text": LETTER})
	body(Vector2i(4, 2), Vector3(-0.6, 0, 1.2), 100.0, "botanist")
	pickup("health", Vector2i(6, 1), Vector3(1.2, 0, -1.0), 1)
	pickup("stim", Vector2i(3, 2), Vector3(0.6, 0, 0.4), 1)
	pickup("salvage", Vector2i(6, 3), Vector3(1.2, 0, 0.0), 1)
	pickup("ammo:scattergun", Vector2i(5, 2), Vector3(0.6, 0, 1.0), 1)
	spawn("taken", Vector2i(5, 2), Vector3(0.3, 0, 0.3), 1, {"asleep": true, "job": "botanist",
		"routine": [Vector2i(3, 1), Vector2i(6, 3), Vector2i(4, 2), Vector2i(6, 1), Vector2i(3, 3)]})


func _surgery() -> void:
	body(Vector2i(8, 1), Vector3(-1.2, 0, -0.6), 20.0, "science")
	pickup("medkit", Vector2i(9, 2), Vector3(1.2, 0, 1.2), 1)
	pickup("stim", Vector2i(7, 1), Vector3(-1.2, 0, -1.2), 1)
	pickup("salvage", Vector2i(9, 1), Vector3(1.3, 0, -1.2), 1)
	spawn("taken", Vector2i(8, 2), Vector3(0.9, 0, 0.6), 1, {"asleep": true, "job": "medic",
		"routine": [Vector2i(7, 1), Vector2i(9, 2), Vector2i(8, 1), Vector2i(7, 2)]})


func _pharmacy() -> void:
	prop("ess:Prop_Desk_Medium", Vector2i(5, -1), Vector3(0.3, 0, 1.2), 180.0)
	thing("survivor", Vector2i(5, -2), Vector3(-1.6, 0, 0.2), 10.0, {"id": "medical_kaya", "name": "Elif Kaya", "job": "medic", "pose": "crouch", "female": true,
		"line": "That's Dr Sorensen's card. She went to the morgue to count them again and didn't come back. I'll come with you. Take the stims. Take all of them."})
	pickup("stim", Vector2i(4, -2), Vector3(-0.6, 0, -0.9), 2)
	pickup("stim", Vector2i(5, -2), Vector3(0.6, 0, -0.9), 1)
	pickup("medkit", Vector2i(5, -1), Vector3(-0.6, 0.94, 1.2), 1)
	pickup("medkit", Vector2i(5, -2), Vector3(1.0, 0, 0.5), 1)
	pickup("health", Vector2i(4, -2), Vector3(0.6, 0, 0.2), 2)
	pickup("salvage", Vector2i(5, -1), Vector3(1.2, 0, -0.2), 2)


func _office() -> void:
	prop("ess:Prop_Desk_Medium", Vector2i(7, -2), Vector3(0, 0, -1.3), 0.0)
	prop("ess:Prop_Chair", Vector2i(7, -2), Vector3(0.3, 0, -0.2), 180.0)
	thing("log", Vector2i(7, -2), Vector3(0.6, 0.94, -1.5), 0.0, {"id": "medical_cmo", "style": "screen", "title": "Patient notes: the first admissions",
		"by": "Dr Helena Sorensen, chief medical officer", "text": CMO_NOTES})
	prop("ess:Prop_Shelves_WideTall", Vector2i(6, -2), Vector3(-1.6, 0, 0.0), 90.0)
	prop("ess:Prop_Locker", Vector2i(6, -1), Vector3(-1.6, 0, 0.6), 90.0)
	prop("ess:Prop_Mug", Vector2i(7, -2), Vector3(-0.8, 0.94, -1.2), 0.0, {"solid": false})
	pickup("cell", Vector2i(7, -1), Vector3(1.2, 0, 1.2), 1)
	pickup("salvage", Vector2i(6, -2), Vector3(0.4, 0, -1.0), 2)


func _isolation() -> void:
	# The second feeder hangs in the dark, where the corridor turns.
	spawn("feeder", Vector2i(8, -2), Vector3(0, 0, 0), 1)
	thing("log", Vector2i(10, -3), Vector3(0, 0, -1.45), 0.0, {"id": "medical_quarantine", "style": "terminal", "title": "Quarantine order",
		"by": "Dr Helena Sorensen, chief medical officer", "text": ORDER})
	body(Vector2i(9, -3), Vector3(0.4, 0, 0.9), 260.0, "medic")
	pickup("flare", Vector2i(5, -3), Vector3(-1.2, 0, 1.0), 2)
	pickup("ammo:scattergun", Vector2i(11, -3), Vector3(1.2, 0, 1.0), 1)
	thing("decal", Vector2i(9, -3), Vector3(0, 0, -1.2), 0.0, {"name": "Decal_Warning"})
	thing("decal", Vector2i(11, -3), Vector3(0, 0, -1.2), 0.0, {"name": "Decal_Warning"})
	# Isolation room 1: Menon, forgotten.
	thing("survivor", Vector2i(5, -4), Vector3(1.0, 0, 0.6), -160.0, {"id": "medical_menon", "name": "Ravi Menon", "job": "cargo", "pose": "crouch",
		"line": "They put me in here for a broken wrist and forgot me. The one in the next room walks into the door all night. Please. I can walk."})
	# Isolation room 2: Brennan, the first patient, still on his feet.
	spawn("taken", Vector2i(7, -4), Vector3(0.0, 0, 1.2), 1, {"job": "botanist", "routine": [Vector2i(7, -4)]})


func _morgue() -> void:
	# The dead from the ward, on growth that will have them up again.
	body(Vector2i(11, -2), Vector3(-1.0, 0, 0.4), 90.0, "medic")
	# One still on the slab, where Dr Sorensen left it.
	body(Vector2i(10, -2), Vector3(1.6, 0.88, 1.8), 0.0, "botanist")
	body(Vector2i(11, -1), Vector3(-1.0, 0, 0.6), 270.0, "tech")
	body(Vector2i(9, -2), Vector3(1.0, 0, 0.8), 180.0, "botanist")
	thing("pickup", Vector2i(11, -2), Vector3(-1.7, 0, 1.4), 0.0, {"item": "keycard:pharmacy", "count": 1})
	pickup("salvage", Vector2i(9, -1), Vector3(1.0, 0, 1.3), 1)


func _quarantine() -> void:
	spawn("pod", Vector2i(9, -5), Vector3(0.6, 0, 0.9), 1)
	spawn("pod", Vector2i(11, -5), Vector3(-0.6, 0, 0.9), 1)
	pickup("salvage", Vector2i(11, -4), Vector3(1.2, 0, 1.2), 2)
	pickup("medkit", Vector2i(9, -4), Vector3(-1.2, 0, 1.2), 1)


func _views() -> void:
	view("arrival", Vector3(-7.4, 1.65, 0.0), -90.0, -3.0)
	view("triage", Vector3(0.5, 1.65, 3.2), -50.0, -8.0)
	view("corridor", Vector3(13.0, 1.65, 0.0), -90.0, 0.0)
	view("ward", Vector3(13.0, 1.65, 4.6), -130.0, -8.0)
	view("surgery", Vector3(28.8, 1.65, 4.0), -125.0, -10.0)
	view("pharmacy", Vector3(16.0, 1.65, -3.0), -10.0, -10.0)
	view("office", Vector3(24.0, 1.65, -3.0), -30.0, -8.0)
	view("isolation_corridor", Vector3(32.0, 1.65, -3.0), 0.0, -4.0)
	view("isolation_room", Vector3(18.6, 1.65, -14.6), -45.0, -12.0)
	view("morgue", Vector3(36.4, 1.65, -3.2), -40.0, -8.0)
	view("quarantine", Vector3(36.0, 1.65, -14.6), -20.0, -6.0)


func decorate() -> void:
	var i := 0
	# Triage: beds along the north and south walls with curtains between,
	# and screens round the worst of them.
	for x in [0.5, 4.0, 7.5]:
		Furniture.bed(self, Vector3(x, 0, -4.8), 0.0, i, i == 1, i == 0)
		Furniture.drip(self, Vector3(x + 0.85, 0, -5.3), i)
		i += 1
	for x in [2.25, 5.75]:
		Furniture.curtain(self, Vector3(x, 0, -4.7), PI * 0.5, 2.4, 0.7, i)
	for x in [1.5, 5.5]:
		Furniture.bed(self, Vector3(x, 0, 4.8), PI, i, false, true)
		i += 1
	Furniture.screen(self, Vector3(5.5, 0, 3.3), 0.0)
	Furniture.monitor(self, Vector3(8.6, 0, -5.4), 0.0)
	# The main corridor: a gurney left against the wall.
	Furniture.bed(self, Vector3(28.0, 0, 1.3), PI * 0.5, i, false, true)
	i += 1
	# The ward: beds down the west wall and along the south, curtains, drips
	# and monitors that have nothing left to show.
	for z in [5.0, 8.0, 11.0]:
		Furniture.bed(self, Vector3(11.2, 0, z), PI * 0.5, i, i % 2 == 0, i % 3 == 0)
		Furniture.monitor(self, Vector3(10.6, 0, z + 1.0), PI * 0.5)
		i += 1
	for x in [15.0, 18.0, 21.0, 24.0]:
		Furniture.bed(self, Vector3(x, 0, 12.8), PI, i, i % 2 == 1, i % 3 == 1)
		Furniture.drip(self, Vector3(x + 0.85, 0, 13.3), i)
		i += 1
	for x in [16.5, 19.5, 22.5]:
		Furniture.curtain(self, Vector3(x, 0, 12.7), PI * 0.5, 2.4, 0.8, i)
	for x in [14.0, 24.0]:
		Furniture.bed(self, Vector3(x, 0, 3.2), 0.0, i, true)
		i += 1
	# Surgery.
	Furniture.surgery_table(self, Vector3(32.0, 0, 6.0), 0.0)
	Furniture.med_shelves(self, Vector3(28.6, 0, 9.65), PI, 1.8, 2)
	Furniture.monitor(self, Vector3(33.6, 0, 4.6), PI)
	Furniture.drip(self, Vector3(30.8, 0, 4.9), 7)
	# The pharmacy's shelves, half emptied in a hurry.
	Furniture.med_shelves(self, Vector3(16.0, 0, -9.65), 0.0, 3.4, 3, true)
	Furniture.med_shelves(self, Vector3(20.0, 0, -9.65), 0.0, 3.4, 4)
	Furniture.med_shelves(self, Vector3(21.65, 0, -6.6), -PI * 0.5, 2.0, 5)
	# The chief medical officer's office: an examination couch and her own shelves.
	Furniture.bed(self, Vector3(22.7, 0, -5.4), 0.0, 24, true)
	Furniture.med_shelves(self, Vector3(29.65, 0, -5.6), -PI * 0.5, 2.0, 6)
	# Isolation rooms: a bed each.
	Furniture.bed(self, Vector3(20.0, 0, -16.8), 0.0, 20, false)
	Furniture.monitor(self, Vector3(18.9, 0, -17.4), 0.0, true)
	Furniture.bed(self, Vector3(28.0, 0, -16.8), 0.0, 21, false, true)
	# The morgue: drawers down both long walls, two pulled out, and the slabs.
	Furniture.drawers(self, Vector3(45.4, 0, -8.0), -PI * 0.5, 3, [1], [1])
	Furniture.drawers(self, Vector3(45.4, 0, -4.0), -PI * 0.5, 3, [0, 4], [4])
	Furniture.drawers(self, Vector3(34.6, 0, -8.0), PI * 0.5, 3, [2], [])
	Furniture.drawers(self, Vector3(34.6, 0, -4.0), PI * 0.5, 3)
	Furniture.slab(self, Vector3(38.4, 0, -6.0), 0.0, true)
	Furniture.slab(self, Vector3(41.6, 0, -6.0), 0.0)
	# Quarantine: strip curtains inside both doors, the beds, and the first
	# patients grown into the walls round the root.
	for x in [36.0, 44.0]:
		Furniture.strips(self, Vector3(x, 0, -14.6), 0.0, 3.6)
	Furniture.bed(self, Vector3(35.4, 0, -20.8), 0.0, 22, false, true)
	Furniture.bed(self, Vector3(44.6, 0, -20.8), 0.0, 23, false, true)
	Furniture.monitor(self, Vector3(37.0, 0, -21.4), 0.0)
	var r := DeckLevel.center(Vector2i(10, -5))
	Fittings.cocoon(self, r + Vector3(-1.5, 0, -1.4), PI * 0.15, 31)
	Fittings.cocoon(self, r + Vector3(1.5, 0, -1.4), -PI * 0.15, 32)
	Fittings.cocoon(self, DeckLevel.center(Vector2i(11, -4)) + Vector3(1.5, 0, -0.6), -PI * 0.5, 33)
	# Something was dragged from the corridor into the morgue.
	Fittings.drag(self, DeckLevel.center(Vector2i(10, 0)) + Vector3(-0.6, 0, 0.6), DeckLevel.center(Vector2i(10, -2)) + Vector3(0.9, 0, -0.6))
