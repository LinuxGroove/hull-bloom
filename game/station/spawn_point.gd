class_name SpawnPoint
extends Node3D
## Where a deck places creatures when it starts: what, how many, and whether
## they're asleep. The deck's director reads these.

var what := "skitter"
var count := 1
var asleep := false
var opts := {}


static func make(o: Dictionary) -> SpawnPoint:
	var s := SpawnPoint.new()
	s.what = String(o.get("what", "skitter"))
	s.count = int(o.get("count", 1))
	s.asleep = bool(o.get("asleep", false))
	s.opts = o
	s.name = "Spawn_" + s.what
	s.add_to_group("spawn_points")
	return s
