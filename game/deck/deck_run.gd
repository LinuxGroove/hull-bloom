class_name DeckRun
extends RefCounted
## One visit to a deck, from stepping out of the lift to leaving it: the
## time, the roots cut, whether it's held, the survivors found and brought
## to the lift, the logs read and the salvage picked up. [method result] is
## what [method Progress.finish_deck] keeps.

var deck: DeckDef
var time := 0.0
var roots := 0
var roots_cut := 0
## Held once every root is cut and the growth is burnt below level 1; it
## stays held from then on.
var held := false
var held_at := -1.0
var survivors_total := 0
var survivors_found: Array[String] = []
var survivors_saved: Array[String] = []
var logs: Array[String] = []
var salvage := 0
var kills := 0
var burnt := 0.0
var downs := 0
## Set when the run ends.
var over := false
var left := false


func _init(p_deck: DeckDef = null) -> void:
	deck = p_deck


func cut_root() -> void:
	roots_cut += 1


func found(id: String) -> void:
	if not id in survivors_found:
		survivors_found.append(id)


func saved(id: String) -> void:
	found(id)
	if not id in survivors_saved:
		survivors_saved.append(id)


func read(id: String) -> void:
	if not id in logs:
		logs.append(id)


## Checks the Bloom: once the roots are gone and the growth is low, the deck
## is held. Returns true the moment it becomes held.
func check_held(bloom: Bloom) -> bool:
	if held or bloom == null:
		return false
	if bloom.is_held():
		held = true
		held_at = time
		return true
	return false


## What's left to do, as [text, done] pairs, for the HUD and the map.
func objectives(bloom: Bloom) -> Array:
	var out := []
	if roots > 0:
		out.append([("Cut out the root" if roots == 1 else "Cut out the roots (%d of %d)" % [roots_cut, roots]), roots_cut >= roots])
	if roots_cut >= roots and not held and bloom:
		var left_tiles := 0
		for g in bloom.growth:
			if g >= 1.0:
				left_tiles += 1
		out.append(["Burn back the growth (%d tiles left)" % left_tiles, false])
	elif held:
		out.append(["The deck is held", true])
	if survivors_total > 0:
		out.append(["Bring survivors to the lift (%d of %d)" % [survivors_saved.size(), survivors_total], survivors_saved.size() >= survivors_total])
	return out


## The run as Progress keeps it.
func result(loadout: Dictionary) -> Dictionary:
	return {"held": held, "survivors": survivors_saved.size(), "salvage": salvage, "time": held_at if held else time,
		"loadout": loadout, "logs": logs.duplicate(), "kills": kills}
