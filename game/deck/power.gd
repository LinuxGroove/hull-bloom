class_name Power
extends RefCounted
## A deck's power cells and what they run. Room lights, sealed bulkheads,
## turrets and the lift each take one cell while they're on; switching
## something off gives its cell back. A deck has only a few, so the player
## decides what's worth one.

signal changed

## Cells on the deck, counting any picked up there.
var cells := 0
## What each cell runs: a key per user ("lights:<room>", "door:<edge>",
## "turret:<id>", "lift").
var users: Array[String] = []


func _init(p_cells := 4) -> void:
	cells = p_cells


func used() -> int:
	return users.size()


func free_cells() -> int:
	return cells - users.size()


func has(key: String) -> bool:
	return key in users


## Takes a cell for `key`; false when none is free.
func take(key: String) -> bool:
	if has(key):
		return true
	if free_cells() <= 0:
		return false
	users.append(key)
	changed.emit()
	return true


func give(key: String) -> void:
	if has(key):
		users.erase(key)
		changed.emit()


func add_cell(n := 1) -> void:
	cells += n
	changed.emit()


## How many cells go to users whose key starts with `kind` ("lights", "door").
func count(kind: String) -> int:
	var n := 0
	for u in users:
		if u.begins_with(kind + ":") or u == kind:
			n += 1
	return n
