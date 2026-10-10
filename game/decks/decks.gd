class_name Decks
extends RefCounted
## The eight decks of Marigold Station, in their order round the ring. Each
## has a folder game/decks/<id>/ with `<id>_deck.gd` (its [DeckDef]),
## `<id>_level.gd` (its [DeckLevel]) and `<id>_tests.gd`.

const ORDER := ["hydroponics", "crew", "medical", "labs", "security", "engineering", "cargo", "core"]
## The decks you can take in any order once Hydroponics is held.
const MIDDLE := ["crew", "medical", "labs", "security", "engineering", "cargo"]
const DEF := "res://game/decks/%s/%s_deck.gd"

static var _cache := {}


## Every deck that exists in this build, in ring order.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for id in ORDER:
		if ResourceLoader.exists(DEF % [id, id]):
			out.append(id)
	return out


static func has(id: String) -> bool:
	return ResourceLoader.exists(DEF % [id, id])


static func get_deck(id: String) -> DeckDef:
	if not _cache.has(id):
		var script: GDScript = load(DEF % [id, id])
		var d: DeckDef = script.make()
		d.id = id
		if d.number == 0:
			d.number = ORDER.find(id) + 1
		_cache[id] = d
	return _cache[id]


## Builds a deck's level with no scene around it, for tests and tools. With
## `overgrown`, as it comes back after being lost.
static func make_level(id: String, overgrown := false) -> DeckLevel:
	var lvl: DeckLevel = load(get_deck(id).level_path()).new()
	lvl.deck = get_deck(id)
	lvl.overgrown = overgrown
	lvl.build()
	return lvl
