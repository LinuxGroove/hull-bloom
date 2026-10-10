extends DeckLevel
## Crew quarters: the lift lobby and the deck office, the main corridor north
## past the galley and its cold store, the mess, the rec room and its chapel,
## the two bunk rooms, and at the top the showers and the laundry, where the
## coveralls from hydroponics came to be washed and the Bloom took root.
##
##   z -8..-7   showers (-3..-2, dark) _ laundry (-1..1, root at (1, -8))
##   z -5..-3   bunk room A (-3..-1) | corridor | bunk room B (1..3)
##   z -2..0    chapel (-5..-4) | rec room (-3..-1) | corridor | mess (1..4)
##   z  1..2                                galley (1..3), cold store (4)
##   z  4..5    deck office (-3..-2) | lift lobby (-1..1), lift at (0, 5)
##
## Two loops let you round the corridor when the growth is thick in it:
## through the rec room and bunk room A, or the mess and bunk room B.

const Furniture := preload("res://game/decks/crew/crew_fittings.gd")

const ROLL_CALL := """02:40. Roll call by hand, since the board says everyone is in their bunks and they are not.

Bunk room A: four answer, two don't. Bunk room B: Novak says something is coming out of the vent and he can't get to the door. Brandt has sealed himself in the cold store, which is the first sensible thing anyone has done tonight. Duarte is in the chapel. She says she'll wait.

Nobody has answered from the laundry since midnight.

I'm taking the ones with the rash down to Medical. Whoever reads this: count them again. Don't trust the board."""

const BRANDT_NOTE := """If you're reading this and you're still you, knock on the cold store door and say something only a person would say.

I've sealed it from inside. There's food for a month in here and it's cold, and it doesn't like the cold. I watched it come out of the laundry and go the long way round the warm side of the mess.

Dinner was at seven. Half of them never came. The ones who did kept getting up from the table and walking to the laundry and back, like they'd left something there."""

const LAUNDRY_LOG := """Dryer 3: running warm. Cause: organic obstruction.

Dryers 1 to 6: running warm. Cause: organic obstruction. Washer 2: door will not close. Cause: organic obstruction.

Coveralls returned from hydroponics, 31 sets: washed at 90 degrees. Washed again at 90 degrees. Still damp.

All tickets assigned to: night shift."""

const FISCHER_LOG := """Day 20. A rash across my shoulders where the coveralls sit. Half the deck has it. Medical says it's the new detergent.

Day 21. It doesn't itch. That's what bothers me. It's warm, like skin that's been in the sun.

I keep waking up standing in the showers. Marta says I walk there every night now and stand over the drain, and when she says my name I don't answer.

I've asked her to lock our door. She says it doesn't lock from the inside."""


func build() -> void:
	default_style("corridor")
	room("lobby", "Lift lobby", Rect2i(-1, 4, 3, 2))
	lift(Vector2i(0, 5), "S")
	corridor("spine", "Main corridor", Vector2i(0, 3), Vector2i(0, -6))
	arch(Vector2i(0, 4), Vector2i(0, 3))
	room("office", "Deck office", Rect2i(-3, 4, 2, 2), "lab")
	door(Vector2i(-2, 4), Vector2i(-1, 4))
	room("galley", "Galley", Rect2i(1, 1, 3, 2), "lab")
	door(Vector2i(0, 2), Vector2i(1, 2))
	room("cold_store", "Cold store", Rect2i(4, 1, 1, 2), "cargo", {"warm": 0.6})
	door(Vector2i(3, 2), Vector2i(4, 2), {"sealed": true})
	room("mess", "Mess hall", Rect2i(1, -2, 4, 3), "crew")
	door(Vector2i(0, -1), Vector2i(1, -1))
	arch(Vector2i(3, 0), Vector2i(3, 1))
	window(Vector2i(2, 0), Vector2i(2, 1))
	room("bunks_b", "Bunk room B", Rect2i(1, -5, 3, 3), "crew")
	door(Vector2i(0, -4), Vector2i(1, -4))
	door(Vector2i(2, -3), Vector2i(2, -2))
	room("rec", "Rec room", Rect2i(-3, -2, 3, 3), "crew")
	door(Vector2i(-1, -1), Vector2i(0, -1))
	room("chapel", "Chapel", Rect2i(-5, -1, 2, 2), "window", {"dark": true})
	door(Vector2i(-4, -1), Vector2i(-3, -1))
	room("bunks_a", "Bunk room A", Rect2i(-3, -5, 3, 3), "crew")
	door(Vector2i(-1, -4), Vector2i(0, -4))
	door(Vector2i(-2, -3), Vector2i(-2, -2))
	room("showers", "Showers", Rect2i(-3, -7, 2, 2), "lab", {"dark": true, "warm": 1.35})
	door(Vector2i(-2, -6), Vector2i(-2, -5))
	room("laundry", "Laundry", Rect2i(-1, -8, 3, 2), "engine", {"warm": 1.4})
	door(Vector2i(0, -6), Vector2i(0, -7))
	arch(Vector2i(-2, -7), Vector2i(-1, -7))
	vent(Vector2i(1, -7), Vector2i(3, -5))
	vent(Vector2i(-3, -6), Vector2i(-3, -1))
	cable(Vector2i(1, -7), Vector2i(4, -2))
	root(Vector2i(1, -8))
	grow_room("laundry", 4.0)
	grow_room("showers", 3.2)
	grow(Vector2i(-2, -7), 3.6)
	grow(Vector2i(0, -6), 2.6)
	grow(Vector2i(0, -5), 1.8)
	grow(Vector2i(0, -4), 1.0)
	grow(Vector2i(0, -3), 0.4)
	grow(Vector2i(-2, -5), 2.2)
	grow(Vector2i(-3, -5), 1.6)
	grow(Vector2i(-1, -5), 1.2)
	grow(Vector2i(-2, -4), 1.0)
	grow(Vector2i(3, -5), 2.4)
	grow(Vector2i(2, -5), 1.4)
	grow(Vector2i(3, -4), 1.2)
	grow(Vector2i(1, -5), 0.6)
	grow(Vector2i(-3, -1), 1.4)
	grow(Vector2i(-3, -2), 0.6)
	grow(Vector2i(4, -2), 0.8)
	_lobby()
	_office()
	_spine()
	_galley()
	_cold_store()
	_mess()
	_bunks_b()
	_rec()
	_chapel()
	_bunks_a()
	_showers()
	_laundry()
	_views()


func _lobby() -> void:
	thing("workbench", Vector2i(1, 4), Vector3(-0.2, 0, -1.25), 0.0)
	thing("bunk", Vector2i(1, 5), Vector3(0.6, 0, 0.6), 0.0)
	prop("ess:Prop_Locker", Vector2i(-1, 5), Vector3(-1.5, 0, 0.6), 90.0)
	prop("ess:Prop_Locker", Vector2i(-1, 5), Vector3(-1.5, 0, -0.45), 90.0)
	pickup("flare", Vector2i(-1, 5), Vector3(0.3, 0, 1.0), 2)
	thing("decal", Vector2i(0, 4), Vector3(0, 0, -0.6), 0.0, {"name": "Decal_Arrows"})


func _office() -> void:
	prop("ess:Prop_Desk_Medium", Vector2i(-3, 4), Vector3(0.6, 0, 0.2), 90.0)
	prop("ess:Prop_Chair", Vector2i(-3, 4), Vector3(-0.5, 0, 0.2), -90.0)
	thing("log", Vector2i(-3, 4), Vector3(0.75, 0.94, -0.3), 90.0, {"id": "crew_rollcall", "style": "screen", "title": "Roll call",
		"by": "Deck Officer Hale", "text": ROLL_CALL})
	prop("ess:Prop_Mug", Vector2i(-3, 4), Vector3(0.5, 0.94, 0.8), 0.0, {"solid": false})
	prop("ess:Prop_Shelves_WideTall", Vector2i(-2, 4), Vector3(0.0, 0, -1.6))
	prop("ess:Prop_Shelves_ThinTall", Vector2i(-3, 5), Vector3(-1.6, 0, 0.6), 90.0)
	prop("ess:Prop_Locker", Vector2i(-3, 5), Vector3(-1.6, 0, -0.6), 90.0)
	# The deck map table, where the roll call is kept.
	prop("ess:Prop_Desk_Large", Vector2i(-2, 5), Vector3(-0.15, 0, 0.85))
	prop("ess:Prop_HologramMap2", Vector2i(-2, 5), Vector3(-0.15, 1.0, 0.85), 0.0, {"solid": false})
	pickup("medkit", Vector2i(-2, 4), Vector3(1.0, 0, 1.4), 1)
	pickup("salvage", Vector2i(-3, 4), Vector3(-1.2, 0, -1.2), 2)
	spawn("taken", Vector2i(-3, 5), Vector3(0.6, 0, -0.4), 1, {"job": "command",
		"routine": [Vector2i(-3, 4), Vector2i(-2, 4), Vector2i(-3, 5), Vector2i(-2, 4)]})


func _spine() -> void:
	body(Vector2i(0, -5), Vector3(0.6, 0, 0.5), 200.0, "tech")
	pickup("health", Vector2i(0, 0), Vector3(1.3, 0, 0.4), 1)
	prop("Prop_Barrel_Large", Vector2i(0, 3), Vector3(-1.4, 0, -0.6))
	prop("Prop_Crate3", Vector2i(0, 1), Vector3(1.3, 0.5, -1.2), 10.0)
	prop("Prop_Crate4", Vector2i(0, -2), Vector3(-1.3, 0.56, 1.0), -15.0)
	thing("decal", Vector2i(0, 1), Vector3.ZERO, 0.0, {"name": "Decal_Line_Straight"})
	thing("decal", Vector2i(0, -5), Vector3(0, 0, -0.6), 0.0, {"name": "Decal_Caution"})


func _galley() -> void:
	thing("log", Vector2i(3, 2), Vector3(1.2, 0, -0.7), -60.0, {"id": "crew_brandt", "title": "Note on the cold store door",
		"by": "Tomas Brandt, cook", "text": BRANDT_NOTE})
	prop("ess:Prop_Shelves_WideTall", Vector2i(3, 1), Vector3(1.6, 0, -0.2), -90.0)
	prop("Prop_Barrel_Large", Vector2i(1, 1), Vector3(-1.3, 0, -1.3))
	prop("Prop_Barrel_Small", Vector2i(1, 1), Vector3(-0.7, 0, -1.4), 30.0)
	pickup("ammo:scattergun", Vector2i(2, 2), Vector3(-0.8, 0.94, 1.5), 1)
	pickup("health", Vector2i(3, 2), Vector3(0.6, 0.94, 1.5), 1)
	pickup("salvage", Vector2i(1, 2), Vector3(-1.0, 0, 1.2), 1)
	# Pieter still does the rounds with the trays: the galley to the mess and back.
	spawn("taken", Vector2i(1, 1), Vector3(0.6, 0, 0.6), 1, {"job": "cook",
		"routine": [Vector2i(1, 1), Vector2i(3, 2), Vector2i(3, 0), Vector2i(2, -1), Vector2i(4, -2), Vector2i(1, -1), Vector2i(2, 2)]})


func _cold_store() -> void:
	prop("ess:Prop_Shelves_WideTall", Vector2i(4, 1), Vector3(1.55, 0, 0.1), -90.0)
	prop("ess:Prop_Shelves_WideTall", Vector2i(4, 2), Vector3(1.55, 0, 0.6), -90.0)
	prop("ess:Prop_Crate", Vector2i(4, 2), Vector3(0.3, 0, 1.0), 10.0)
	prop("Prop_Barrel_Large", Vector2i(4, 1), Vector3(-1.2, 0, -1.3))
	prop("Prop_Barrel_Large", Vector2i(4, 1), Vector3(-0.6, 0, -1.4))
	thing("survivor", Vector2i(4, 1), Vector3(0.2, 0, 0.3), 160.0, {"id": "crew_brandt", "name": "Tomas Brandt", "job": "cook", "pose": "sit",
		"line": "You're still you. Good. I'll make for the lift. The one in my galley was Pieter. He still carries the trays. Don't let him near you."})
	pickup("salvage", Vector2i(4, 2), Vector3(-0.6, 0, 1.3), 1)
	pickup("grenade", Vector2i(4, 1), Vector3(-1.1, 0, 0.4), 1)


func _mess() -> void:
	body(Vector2i(2, -1), Vector3(0.4, 0, -0.4), 30.0, "tech")
	pickup("health", Vector2i(4, 0), Vector3(1.0, 0, 0.9), 1)
	pickup("flare", Vector2i(1, 0), Vector3(-1.0, 0, 0.9), 1)
	prop("ess:Prop_Mug", Vector2i(1, -2), Vector3(1.2, 0.8, 1.9), 0.0, {"solid": false})
	prop("ess:Prop_Locker", Vector2i(4, -1), Vector3(1.4, 0, 0.0), -90.0)
	spawn("taken", Vector2i(3, -1), Vector3(0.4, 0, -0.4), 1, {"job": "tech",
		"routine": [Vector2i(1, -1), Vector2i(4, -2), Vector2i(2, 0), Vector2i(4, 0), Vector2i(1, -2)]})


func _bunks_b() -> void:
	prop("ess:Prop_Locker", Vector2i(1, -3), Vector3(-0.6, 0, 1.4), 180.0)
	prop("ess:Prop_Locker", Vector2i(1, -3), Vector3(0.4, 0, 1.4), 180.0)
	thing("survivor", Vector2i(3, -4), Vector3(0.8, 0, -1.2), -120.0, {"id": "crew_novak", "name": "Marek Novak", "job": "engineer", "pose": "crouch",
		"line": "It came out of that vent an hour ago and it's been creeping at me ever since. I couldn't get past it to the door. I'm going. The lift, yes?"})
	pickup("ammo:scattergun", Vector2i(1, -5), Vector3(-1.0, 0, 1.0), 1)
	pickup("salvage", Vector2i(2, -3), Vector3(-1.2, 0, 0.6), 1)
	# A card table and a footlocker where the tile corners meet, out of the walkways.
	prop("ess:Prop_Desk_Small", Vector2i(2, -4), Vector3(1.9, 0, 1.9), 90.0)
	prop("ess:Prop_Mug", Vector2i(2, -4), Vector3(1.8, 0.94, 1.6), 0.0, {"solid": false})
	prop("ess:Prop_Crate_Tarp", Vector2i(1, -5), Vector3(1.9, 0, 1.9), 30.0)
	spawn("taken", Vector2i(2, -4), Vector3(0.0, 0, 0.6), 1, {"job": "engineer",
		"routine": [Vector2i(1, -5), Vector2i(3, -4), Vector2i(2, -3), Vector2i(0, -4), Vector2i(0, -2)]})


func _rec() -> void:
	prop("ess:Prop_Desk_Small", Vector2i(-2, 0), Vector3(0, 0, 1.1), 180.0)
	prop("ess:Prop_Screen", Vector2i(-2, 0), Vector3(0, 0.94, 1.25), 180.0, {"solid": false})
	pickup("ammo:scattergun", Vector2i(-3, 0), Vector3(-1.0, 0, 1.0), 1)
	pickup("salvage", Vector2i(-1, -1), Vector3(0.9, 0, 1.2), 2)
	spawn("taken", Vector2i(-3, -2), Vector3(0.5, 0, 0.8), 1, {"job": "security",
		"routine": [Vector2i(-3, -2), Vector2i(-1, -2), Vector2i(-1, 0), Vector2i(-3, 0), Vector2i(-2, -1)]})


func _chapel() -> void:
	prop("ess:Prop_Desk_Small", Vector2i(-5, -1), Vector3(-1.1, 0, 0.6), 90.0)
	thing("survivor", Vector2i(-5, -1), Vector3(0.6, 0, -0.4), 70.0, {"id": "crew_duarte", "name": "Ines Duarte", "job": "botanist", "pose": "torch", "female": true,
		"line": "The lights went when it reached the vents. Hale lit the candles and said to wait. I've waited. I'll follow you to the lift. Don't leave me in the dark."})
	thing("light", Vector2i(-5, -1), Vector3(0.9, 1.1, -0.2), 0.0, {"color": Color(1.0, 0.92, 0.75), "energy": 0.7, "range": 7.0})
	pickup("cell", Vector2i(-5, 0), Vector3(-1.1, 0, -1.1), 1)
	pickup("flare", Vector2i(-4, 0), Vector3(0.8, 0, 1.2), 2)


func _bunks_a() -> void:
	body(Vector2i(-2, -5), Vector3(0.3, 0, 0.4), 120.0, "botanist")
	thing("log", Vector2i(-3, -4), Vector3(0.6, 0, 0.7), 20.0, {"id": "crew_fischer", "title": "Personal log",
		"by": "Lena Fischer, botanist", "text": FISCHER_LOG})
	prop("ess:Prop_Locker", Vector2i(-3, -5), Vector3(0.4, 0, -1.4))
	pickup("medkit", Vector2i(-3, -4), Vector3(-0.2, 0, -0.2), 1)
	pickup("salvage", Vector2i(-1, -5), Vector3(-0.5, 0, -1.2), 1)
	prop("ess:Prop_Desk_Small", Vector2i(-3, -4), Vector3(1.9, 0, 1.9), 0.0)
	prop("ess:Prop_Crate_Tarp", Vector2i(-3, -5), Vector3(1.9, 0, 1.9), -20.0)
	# Lena walks from her bunk to the showers and stands over the drain.
	spawn("taken", Vector2i(-2, -4), Vector3(-0.4, 0, 0.2), 1, {"job": "botanist", "female": true,
		"routine": [Vector2i(-3, -4), Vector2i(-1, -3), Vector2i(-2, -6), Vector2i(-3, -7), Vector2i(-2, -5)]})


func _showers() -> void:
	spawn("skitter", Vector2i(-2, -7), Vector3(0.4, 0, 0.6), 2, {"asleep": true})
	spawn("pod", Vector2i(-3, -7), Vector3(0.6, 0, 0.6), 1)
	pickup("flare", Vector2i(-2, -6), Vector3(1.0, 0, 1.2), 1)


func _laundry() -> void:
	thing("log", Vector2i(-1, -8), Vector3(-1.4, 0, -0.5), 90.0, {"id": "crew_laundry", "style": "terminal", "title": "Laundry: service log",
		"by": "MARI", "text": LAUNDRY_LOG})
	thing("body", Vector2i(0, -8), Vector3(-0.3, 0, 1.0), 250.0, {"job": "botanist", "swallowed": true})
	spawn("pod", Vector2i(0, -8), Vector3(0.4, 0, 0.2), 1)
	spawn("pod", Vector2i(1, -7), Vector3(-0.6, 0, 0.8), 1)
	pickup("salvage", Vector2i(-1, -7), Vector3(0.2, 0, 1.3), 2)
	pickup("ammo:scattergun", Vector2i(0, -7), Vector3(1.0, 0, 1.1), 1)
	spawn("taken", Vector2i(-1, -7), Vector3(0.6, 0, 0.0), 1, {"job": "tech",
		"routine": [Vector2i(-1, -8), Vector2i(0, -7), Vector2i(-1, -7), Vector2i(-2, -7), Vector2i(-3, -6), Vector2i(-2, -6)]})


func _views() -> void:
	view("arrival", Vector3(0, 1.65, 21.0), 0.0, -3.0)
	view("corridor", Vector3(0, 1.65, 6.0), 0.0, -2.0)
	view("deck_office", Vector3(-6.8, 1.65, 18.5), 100.0, -10.0)
	view("galley", Vector3(3.2, 1.65, 7.0), -80.0, -10.0)
	view("cold_store", Vector3(15.2, 1.65, 9.0), 10.0, -12.0)
	view("mess", Vector3(3.0, 1.65, -9.0), -130.0, -10.0)
	view("bunk_room_b", Vector3(3.0, 1.65, -11.0), -40.0, -8.0)
	view("rec_room", Vector3(-3.0, 1.65, 1.0), 50.0, -8.0)
	view("chapel", Vector3(-14.6, 1.65, -4.0), 90.0, -6.0)
	view("bunk_room_a", Vector3(-3.0, 1.65, -13.0), 45.0, -8.0)
	view("showers", Vector3(-8.0, 1.65, -22.8), 0.0, -8.0)
	view("laundry", Vector3(0, 1.65, -26.6), 10.0, -10.0)


func decorate() -> void:
	# The galley: counters along the back wall, the hob, the sink and an
	# island, and a counter under the serving hatch on the mess side.
	Furniture.counter(self, DeckLevel.center(Vector2i(2, 2)) + Vector3(0, 0, 1.5), PI, 3.2, true)
	Furniture.counter(self, DeckLevel.center(Vector2i(3, 2)) + Vector3(0.1, 0, 1.5), PI, 2.8, false, true)
	Furniture.counter(self, DeckLevel.center(Vector2i(2, 1)) + Vector3(0, 0, 0.3), 0.0, 2.4)
	Furniture.counter(self, DeckLevel.center(Vector2i(2, 0)) + Vector3(0, 0, 1.28), PI, 3.0)
	# The mess: two rows of tables.
	var i := 0
	for z in [-6.2, -2.2]:
		for x in [6.6, 12.4]:
			Furniture.mess_table(self, Vector3(x, 0, z), 0.0, 3.4, i)
			i += 1
	# Bunks against the walls, open side to the room.
	for x in [5.2, 8.6, 12.0]:
		Furniture.bunk(self, Vector3(x, 0, -21.2), 0.0, i, i % 3 != 0)
		i += 1
	Furniture.bunk(self, Vector3(13.2, 0, -13.6), -PI * 0.5, i, false)
	i += 1
	for z in [-19.5, -15.5, -11.6]:
		Furniture.bunk(self, Vector3(-13.2, 0, z), PI * 0.5, i, i % 2 == 0)
		i += 1
	for z in [-20.2, -11.6]:
		Furniture.bunk(self, Vector3(-2.8, 0, z), -PI * 0.5, i, false)
		i += 1
	Furniture.clothes(self, Vector3(6.4, 0, -13.6), 1)
	Furniture.clothes(self, Vector3(-6.4, 0, -17.6), 2)
	# The rec room: a sofa before the screen, and the gym in the far corner.
	Furniture.sofa(self, Vector3(-8.0, 0, -1.1), 0.0)
	Furniture.mess_table(self, Vector3(-10.0, 0, -6.0), 0.0, 2.0, 9)
	Furniture.treadmill(self, Vector3(-12.6, 0, -8.7), 0.0)
	Furniture.treadmill(self, Vector3(-11.4, 0, -8.7), 0.0)
	Furniture.weights(self, Vector3(-3.8, 0, -8.6), 0.0)
	Furniture.bag(self, Vector3(-5.6, 0, -8.9))
	# The chapel: pews facing the altar on the west wall, and the candles.
	for x in [-16.2, -18.4]:
		Furniture.pew(self, Vector3(x, 0, -0.2), -PI * 0.5, 2.4)
	Furniture.candles(self, DeckLevel.center(Vector2i(-5, -1)) + Vector3(-1.1, 0.94, 0.6), 3)
	# The showers: stalls down the west wall and along the north.
	for z in [-29.2, -27.9, -26.6, -25.3, -24.0]:
		Furniture.shower(self, Vector3(-13.36, 0, z), PI * 0.5)
	for x in [-11.4, -10.1]:
		Furniture.shower(self, Vector3(x, 0, -29.36), 0.0)
	# The laundry: washers and dryers down the north wall, a folding table,
	# carts, and coveralls on the floor.
	for k in 7:
		Furniture.washer(self, Vector3(-4.4 + k * 0.8, 0, -33.3), 0.0, k == 2)
	Furniture.folding_table(self, Vector3(-1.4, 0, -29.6), 0.0, 1.8, 4)
	Furniture.cart(self, Vector3(-4.6, 0, -27.0), 0.3)
	Furniture.cart(self, Vector3(5.0, 0, -26.9), -0.4)
	Furniture.clothes(self, Vector3(1.5, 0, -30.5), 5)
	Furniture.clothes(self, Vector3(-11.0, 0, -26.0), 6)
	# The Bloom's nest at the root: crew grown into the walls.
	var r := DeckLevel.center(Vector2i(1, -8))
	Fittings.cocoon(self, r + Vector3(1.3, 0, -1.3), -PI * 0.25, 21)
	Fittings.cocoon(self, r + Vector3(-1.6, 0, -1.35), PI * 0.1, 22)
	Fittings.cocoon(self, r + Vector3(1.4, 0, 1.6), -PI * 0.6, 23)
	# Somebody was dragged from the showers to the laundry.
	Fittings.drag(self, DeckLevel.center(Vector2i(-3, -6)) + Vector3(0.6, 0, 0.6), DeckLevel.center(Vector2i(0, -8)) + Vector3(-0.3, 0, 1.0))
	Fittings.drag(self, DeckLevel.center(Vector2i(0, -5)) + Vector3(0.6, 0, 0.5), DeckLevel.center(Vector2i(0, -7)))
