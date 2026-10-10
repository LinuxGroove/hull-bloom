extends DeckLevel
## Hydroponics: the lift lobby, the main corridor north, the break room and
## the nutrient pumps either side, two grow rooms, the seed lab at the top
## and the vault behind it where the Bloom took root, and the observation
## gallery out to the stores.
##
##   z -10..-9  vault (root)                    stores (5..6, -9..-8)
##   z  -8..-6  seed lab (-2..2) == gallery (3..6, -7) windows
##   z  -5..4   main corridor (x 0)
##   z  -3..-1  grow room A (-4..-1)   grow room B (1..4, -4..-2)
##   z   1..3   break room (-3..-1)    nutrient pumps (1..3)
##   z   5..6   lift lobby (-1..1), lift at (0, 6)

const SAMPLE_LOG := """Day 1. SV-3 came back from the survey moon in a sealed case: grey spores, inert at station temperature. Logged. A few spores kept back in the seed vault for study.

Day 9. One spore germinated in the nutrient mist overnight. It grew a root system in four hours. It is not a plant. It is not like anything.

Day 17. It has found the vent. I've asked MARI to seal the vault door and she says it's sealed. It isn't. It's holding the door open from the inside.

Day 21. Whatever you do, don't let it reach the nutrient lines."""


func build() -> void:
	default_style("corridor")
	room("lobby", "Lift lobby", Rect2i(-1, 5, 3, 2))
	lift(Vector2i(0, 6), "S")
	corridor("spine", "Main corridor", Vector2i(0, 4), Vector2i(0, -5))
	arch(Vector2i(0, 5), Vector2i(0, 4))
	room("mess", "Break room", Rect2i(-3, 1, 3, 2), "crew")
	door(Vector2i(-1, 2), Vector2i(0, 2))
	room("pumps", "Nutrient pumps", Rect2i(1, 1, 3, 3), "engine")
	door(Vector2i(0, 2), Vector2i(1, 2))
	room("grow_a", "Grow room A", Rect2i(-4, -3, 4, 3), "hydro", {"warm": 1.5})
	door(Vector2i(-1, -2), Vector2i(0, -2))
	room("grow_b", "Grow room B", Rect2i(1, -4, 4, 3), "hydro", {"warm": 1.5})
	door(Vector2i(0, -3), Vector2i(1, -3))
	room("seed_lab", "Seed lab", Rect2i(-2, -8, 5, 3), "lab")
	door(Vector2i(0, -5), Vector2i(0, -6))
	room("vault", "Seed vault", Rect2i(-1, -10, 3, 2), "core", {"dark": true, "warm": 1.3})
	door(Vector2i(0, -8), Vector2i(0, -9), {"jammed": true})
	corridor("gallery", "Observation gallery", Vector2i(3, -7), Vector2i(6, -7), "window")
	arch(Vector2i(2, -7), Vector2i(3, -7))
	room("stores", "Stores", Rect2i(5, -9, 2, 2), "cargo")
	door(Vector2i(6, -7), Vector2i(6, -8))
	vent(Vector2i(-3, -2), Vector2i(-2, 1))
	vent(Vector2i(3, -3), Vector2i(2, 2))
	vent(Vector2i(-1, -7), Vector2i(-3, -3))
	cable(Vector2i(2, -6), Vector2i(3, -4))
	root(Vector2i(0, -10))
	grow_room("vault", 4.0)
	grow_room("seed_lab", 3.2)
	grow(Vector2i(0, -5), 1.6)
	grow(Vector2i(0, -4), 0.8)
	grow_room("grow_a", 2.0)
	grow(Vector2i(-3, -3), 3.0)
	grow(Vector2i(3, -4), 0.6)
	_lobby()
	_spine()
	_mess()
	_pumps()
	_grow_rooms()
	_seed_lab()
	_vault()
	_gallery_and_stores()
	_views()


func _lobby() -> void:
	thing("workbench", Vector2i(-1, 5), Vector3(0, 0, -1.3), 0.0)
	thing("bunk", Vector2i(1, 5), Vector3(0.6, 0, -0.8), 0.0)
	thing("log", Vector2i(1, 6), Vector3(1.2, 0, 0.4), -90.0, {"id": "hydro_rota", "style": "terminal", "title": "Night shift rota",
		"by": "Posted by Deck Officer Hale",
		"text": "Night shift, Hydroponics: one tech on call.\n\nThe seed lab asks that nobody goes into the vault without Dr Okafor. The vault door is reporting faults again. Ignore it, MARI's on it.\n\nThe break room coffee machine is fixed. Please stop hitting it."})
	pickup("flare", Vector2i(-1, 6), Vector3(0.4, 0, 0.3), 2)
	prop("ess:Prop_Locker", Vector2i(-1, 6), Vector3(-1.45, 0, 0.6), 90.0)
	prop("ess:Prop_Locker", Vector2i(-1, 6), Vector3(-1.45, 0, -0.5), 90.0)
	thing("decal", Vector2i(0, 5), Vector3(0, 0, -1.0), 0.0, {"name": "Decal_Arrows"})


func _spine() -> void:
	body(Vector2i(0, -3), Vector3(0.6, 0, 0.8), 160.0, "tech")
	pickup("health", Vector2i(0, 1), Vector3(1.3, 0, 0), 1)
	prop("Prop_Barrel_Large", Vector2i(0, 3), Vector3(1.4, 0, 0.6))
	prop("Prop_Barrel_Large", Vector2i(0, 3), Vector3(1.45, 0, -0.1))
	prop("Prop_Crate4", Vector2i(0, -1), Vector3(-1.3, 0.56, 1.0), 20.0)
	thing("decal", Vector2i(0, 0), Vector3.ZERO, 0.0, {"name": "Decal_Line_Straight"})
	thing("decal", Vector2i(0, -4), Vector3(0, 0, 0.5), 0.0, {"name": "Decal_Caution"})


func _mess() -> void:
	prop("ess:Prop_Desk_Medium", Vector2i(-2, 1), Vector3(0, 0, 0.6))
	prop("ess:Prop_Chair", Vector2i(-2, 1), Vector3(-0.8, 0, -0.3), 180.0)
	prop("ess:Prop_Chair", Vector2i(-2, 1), Vector3(0.7, 0, 1.6), 20.0)
	prop("ess:Prop_Mug", Vector2i(-2, 1), Vector3(0.3, 0.94, 0.5), 0.0, {"solid": false})
	prop("ess:Prop_Shelves_WideShort", Vector2i(-3, 2), Vector3(-1.5, 0, 0.2), 90.0)
	prop("ess:Prop_Locker", Vector2i(-1, 1), Vector3(0.2, 0, -1.5))
	thing("log", Vector2i(-2, 1), Vector3(-0.4, 0.95, 0.7), 10.0, {"id": "hydro_cook", "title": "Note on the table",
		"by": "Tomas Brandt, cook",
		"text": "Nadia, if you're on nights: the botanists have been taking meals into the grow rooms again and leaving them. Something's been at the bins. Not rats. We don't have rats.\n\nIt was warm in here this morning. The floor by the vent was wet. I put a towel down."})
	pickup("medkit", Vector2i(-1, 2), Vector3(0.6, 0, 1.2), 1)
	spawn("taken", Vector2i(-3, 1), Vector3(0.5, 0, 0.5), 1, {"job": "cook"})


func _pumps() -> void:
	prop("Prop_Pod_Short", Vector2i(3, 1), Vector3(0.4, 0, -0.4))
	prop("Prop_Pod_Short", Vector2i(3, 3), Vector3(0.4, 0, 0.4))
	thing("column", Vector2i(2, 2), Vector3(0.9, 0, 0.9), 0.0, {"name": "Column_Pipes"})
	prop("Prop_PipeHolder", Vector2i(1, 3), Vector3(0, 0, 1.2), 0.0)
	prop("Prop_Pipe_Thick_Straight", Vector2i(2, 1), Vector3(0, 4.3, -1.5), 90.0, {"solid": false})
	prop("Prop_Pipe_Thick_Straight", Vector2i(3, 2), Vector3(1.6, 4.3, 0), 0.0, {"solid": false})
	thing("pickup", Vector2i(1, 1), Vector3(-0.8, 0, -0.9), 0.0, {"item": "weapon:scattergun", "count": 1})
	pickup("ammo:scattergun", Vector2i(1, 1), Vector3(0.3, 0, -1.2), 12)
	pickup("salvage", Vector2i(3, 2), Vector3(-0.6, 0, -1.2), 2)
	thing("log", Vector2i(2, 3), Vector3(0, 0, 1.45), 180.0, {"id": "hydro_ticket", "style": "terminal", "title": "Maintenance ticket 4471",
		"by": "MARI",
		"text": "Ticket 4471: nutrient line B pressure low. Cause: organic obstruction.\n\nTicket 4472: nutrient line A pressure low. Cause: organic obstruction.\n\nTicket 4473: security unit QS-2 not responding. Last seen: nutrient pumps.\n\nAll tickets assigned to: night shift."})
	spawn("quadshell", Vector2i(2, 1), Vector3(0.5, 0, 0.0), 1, {"asleep": true})


func _grow_rooms() -> void:
	pickup("flare", Vector2i(-4, -1), Vector3(-1.0, 0, 1.0), 1)
	body(Vector2i(-3, -2), Vector3(0.3, 0, 0.6), 80.0, "botanist")
	body(Vector2i(-2, -1), Vector3(-0.4, 0, 0.9), 200.0, "botanist")
	spawn("skitter", Vector2i(-4, -3), Vector3(0.4, 0, 0.4), 2, {"asleep": true})
	pickup("health", Vector2i(4, -2), Vector3(1.0, 0, 1.0), 1)
	pickup("ammo:scattergun", Vector2i(4, -4), Vector3(1.0, 0, -1.0), 6)
	pickup("salvage", Vector2i(2, -4), Vector3(-0.8, 0, -1.2), 1)


func _seed_lab() -> void:
	prop("Prop_Pod", Vector2i(0, -7), Vector3(0, 0, -0.6))
	prop("ess:Prop_Desk_Medium", Vector2i(-2, -6), Vector3(0, 0, 1.2), 180.0)
	prop("ess:Prop_Computer", Vector2i(-2, -6), Vector3(-0.6, 0.94, 1.35), 180.0, {"solid": false})
	prop("ess:Prop_Desk_Medium", Vector2i(2, -8), Vector3(0, 0, -1.2))
	prop("ess:Prop_HologramMap1", Vector2i(-1, -8), Vector3(0, 0, -0.9))
	prop("ess:Prop_Shelves_ThinTall", Vector2i(2, -6), Vector3(1.45, 0, 0), -90.0)
	thing("log", Vector2i(2, -8), Vector3(0.5, 0.94, -1.1), 0.0, {"id": "hydro_sv3", "title": "Sample SV-3",
		"by": "Dr Imani Okafor, botany", "text": SAMPLE_LOG})
	body(Vector2i(1, -7), Vector3(0.4, 0, 0.5), 240.0, "science")
	spawn("pod", Vector2i(-2, -8), Vector3(-0.6, 0, -0.6), 1)
	spawn("pod", Vector2i(2, -7), Vector3(0.9, 0, 0.3), 1)
	spawn("skitter", Vector2i(-1, -6), Vector3.ZERO, 1, {"asleep": true})
	pickup("ammo:scattergun", Vector2i(-2, -7), Vector3(-1.2, 0, 0), 6)


func _vault() -> void:
	body(Vector2i(1, -9), Vector3(0.6, 0, 0.0), 300.0, "botanist")
	pickup("salvage", Vector2i(-1, -10), Vector3(-1.0, 0, -1.0), 3)


func _gallery_and_stores() -> void:
	pickup("grenade", Vector2i(5, -7), Vector3(0, 0, 1.2), 1)
	prop("ess:Prop_Shelves_WideTall", Vector2i(5, -9), Vector3(-0.2, 0, -1.6))
	prop("ess:Prop_Shelves_WideTall", Vector2i(6, -9), Vector3(0.2, 0, -1.6))
	prop("ess:Prop_Crate", Vector2i(5, -8), Vector3(-0.9, 0, 0.6), 15.0)
	prop("ess:Prop_Crate_Tarp", Vector2i(6, -9), Vector3(1.0, 0, 0.6), -10.0)
	pickup("cell", Vector2i(5, -9), Vector3(0.6, 0, 0.4), 1)
	pickup("salvage", Vector2i(6, -8), Vector3(0.9, 0, 0.9), 2)
	pickup("medkit", Vector2i(5, -8), Vector3(0.5, 0, 1.2), 1)


func _views() -> void:
	view("arrival", Vector3(0, 1.65, 21.5), 0.0, -3.0)
	view("corridor", Vector3(0, 1.65, 10.0), 0.0, -2.0)
	view("break_room", Vector3(-4.5, 1.65, 7.0), 90.0, -8.0)
	view("pumps", Vector3(4.5, 1.65, 6.0), -70.0, -6.0)
	view("grow_room_a", Vector3(-4.6, 1.65, -6.0), 105.0, -10.0)
	view("grow_room_b", Vector3(4.6, 1.65, -11.0), -80.0, -8.0)
	view("seed_lab", Vector3(7.0, 1.65, -24.8), 35.0, -8.0)
	view("vault", Vector3(0, 1.65, -31.0), 0.0, -10.0)
	view("gallery", Vector3(10.5, 1.65, -28.0), -90.0, 0.0)
	view("stores", Vector3(24.0, 1.65, -27.5), 0.0, -12.0)


func decorate() -> void:
	# Planters in rows either side of each grow room's aisle: dead where the
	# Bloom has been.
	var i := 0
	for z in [-11.0, -5.0]:
		for x in [-13.5, -8.0]:
			Fittings.planter(self, Vector3(x, 0, z), 0.0, 3.4, true, i)
			i += 1
	for z in [-15.0, -9.0]:
		for x in [7.5, 13.0]:
			Fittings.planter(self, Vector3(x, 0, z), 0.0, 3.4, false, i)
			i += 1
	Fittings.cocoon(self, DeckLevel.center(Vector2i(-1, -10)) + Vector3(-1.2, 0, -1.4), PI * 0.25, 4)
	Fittings.cocoon(self, DeckLevel.center(Vector2i(1, -10)) + Vector3(1.3, 0, -1.4), -PI * 0.25, 5)
	Fittings.drag(self, DeckLevel.center(Vector2i(0, -3)) + Vector3(0.6, 0, 0.8), DeckLevel.center(Vector2i(0, -5)))
