class_name DeckDef
extends RefCounted
## One deck of Marigold Station: its place on the ring, how long it holds out
## while you're elsewhere, its power and what saving it gives. Each deck's
## folder makes one with `<id>_deck.gd`'s static make(); the level itself is
## `<id>_level.gd`.

var id := ""
## 1 to 8, its place on the ring.
var number := 0
var name := ""
## One line for the ring map.
var blurb := ""
## What's new on this deck, for the ring map.
var news: Array[String] = []
## The level's script (a [DeckLevel]).
var level := ""
## Power cells on the deck.
var cells := 4
## Hours of the night shift before the Bloom takes the deck, counted from
## when the ring opens (0: never lost on its own, like Hydroponics and the Core).
var hours := 0
## How fast the Bloom spreads here (the difficulty setting scales it too).
var spread := 1.0
## The Bloom's seed, so each deck plays out the same way given the same moves.
var seed := 1
## What saving the deck gives: "" or one of "power", "turrets", "stims",
## "rail", "shuttle", "survivors".
var gives := ""
## A line about what it gives, for the ring map and the results.
var gives_text := ""
## Music: a file under assets/audio/music without the extension, or "".
var music := ""
## MARI's lines when you step out of the lift, and when the deck is held.
var arrive := ""
var held := ""
## What pods and hearts hatch here: creature -> weight.
var hatches := {"skitter": 1.0}
## Most creatures awake on the deck at once, besides those the level places.
var max_alive := 10
## The deck's colour on the ring map and its lights.
var color := Color(0.6, 0.8, 1.0)


func level_path() -> String:
	return level if level != "" else "res://game/decks/%s/%s_level.gd" % [id, id]
