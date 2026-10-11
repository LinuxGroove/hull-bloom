class_name Director
extends Node3D
## Decides what's alive on a deck: the creatures the level places, the hearts
## at its roots, the pods the Bloom sprouts and what they hatch, the dead who
## get up again on grown tiles, and the spawn that come back when you kill
## them without burning their tile. Everything it makes is its child.

## A hatched creature killed on a tile still grown this much comes back.
const REGROW_LEVEL := 2.0
const REGROW_TIME := Vector2(40.0, 70.0)
## How far from the player things may appear unseen.
const UNSEEN_MIN := 9.0
const UNSEEN_MAX := 28.0
## Chance per Bloom tick that a body on a grown tile gets up.
const RISE_CHANCE := 0.3

var level: DeckLevel
var bloom: Bloom
var deck: DeckDef
## Tile index -> [Pod] standing on it.
var pods := {}
var hearts: Array[Heart] = []
## [tile index, seconds left, what] for creatures owed back.
var debt: Array = []
## Creatures killed this visit, for the results.
var kills := 0
var rng := RandomNumberGenerator.new()

signal heart_killed(h: Heart)
signal creature_died(c: Creature)


func _init() -> void:
	name = "Director"


func setup(lvl: DeckLevel) -> void:
	level = lvl
	bloom = lvl.bloom
	deck = lvl.deck
	rng.seed = (deck.seed if deck else 1) * 7919 + 13


## Everything the deck starts with.
func start() -> void:
	for c in level.root_cells:
		var i: int = bloom.index.get(c, -1)
		if i < 0:
			continue
		var alive := false
		for k in bloom.roots.size():
			if bloom.roots[k] == i and bloom.root_alive[k] == 1:
				alive = true
		if alive:
			_add_heart(c)
	for sp in get_tree().get_nodes_in_group("spawn_points"):
		var s := sp as SpawnPoint
		var n := s.count * (2 if level.overgrown and s.what != "pod" else 1)
		for k in n:
			var jitter := Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)) if n > 1 else Vector3.ZERO
			if s.what == "pod":
				var i: int = bloom.index.get(DeckLevel.cell_at(s.global_position), -1)
				if i >= 0:
					bloom.pods[i] = int(bloom.pods.get(i, 0)) + 1
					_add_pod_at(i, s.global_position + jitter, false, Vector3.ZERO)
				continue
			spawn(s.what, s.global_position + jitter, s.asleep, s.opts)
	for i in bloom.pods:
		_sync_tile(i)


## A creature at `at`. Options go to [method Creatures.make].
func spawn(what: String, at: Vector3, asleep := false, opts := {}) -> Creature:
	var c := Creatures.make(what, opts)
	c.setup(level, at, asleep)
	c.rotation.y = rng.randf() * TAU
	c.died.connect(_on_died)
	add_child(c)
	return c


func alive() -> int:
	var n := 0
	for c in get_children():
		if c is Creature and not c.dead:
			n += 1
	return n


## After each tick of the Bloom: pods sprout and wither, the dead rise, and
## what was owed comes back.
func on_tick() -> void:
	for i in bloom.sprouted:
		_sync_tile(i)
	for i in bloom.withered:
		_sync_tile(i)
	for i in pods.keys():
		if int(bloom.pods.get(i, 0)) < (pods[i] as Array).size():
			_sync_tile(i)
	_raise_the_dead()


func _process(delta: float) -> void:
	if debt.is_empty():
		return
	var keep := []
	for d in debt:
		d[1] -= delta
		if d[1] > 0.0:
			keep.append(d)
			continue
		var cell: Vector2i = bloom.cells[d[0]]
		if bloom.level_at(cell) < REGROW_LEVEL:
			continue
		if alive() >= _cap():
			d[1] = 8.0
			keep.append(d)
			continue
		var at := unseen_spot(cell)
		if at == Vector3.INF:
			d[1] = 6.0
			keep.append(d)
			continue
		var c := spawn(d[2], at)
		c.spawned = true
		c.home = DeckLevel.center(cell)
		c.set_meta("tile", d[0])
		_hunt(c)
	debt = keep


## A pod hatches: what the deck hatches, if there's room for more.
func hatch_from(pod: Pod) -> void:
	if alive() >= _cap():
		return
	pod.pulse()
	var what := _pick_hatch()
	var n := 2 if what == "skitter" and rng.randf() < 0.2 else 1
	for k in n:
		var c := spawn(what, pod.global_position + Vector3(rng.randf_range(-0.6, 0.6), 0.05, rng.randf_range(-0.6, 0.6)))
		c.spawned = true
		c.set_meta("tile", pod.tile)
		_hunt(c)


## A heart calls up its guard.
func heart_spawn(heart: Heart) -> void:
	if alive() >= _cap() + 2:
		return
	var ang := rng.randf() * TAU
	var at := heart.global_position + Vector3(cos(ang), 0, sin(ang)) * (2.6 if heart.big else 1.8)
	var c := spawn(_pick_hatch(), at)
	c.spawned = true
	c.set_meta("tile", bloom.index.get(heart.cell, -1))
	_hunt(c)


## A spot on grown floor near `cell` that the player can't see, or
## Vector3.INF if there's none.
func unseen_spot(near: Vector2i) -> Vector3:
	var player := Creature._player()
	var eye: Vector3 = player.eye_position() if player and player.has_method("eye_position") else Vector3(0, -1000, 0)
	var cands: Array[Vector2i] = []
	for c in level.reachable(near, true):
		if bloom.level_at(c) >= 1.0:
			cands.append(c)
	for v in level.vents:
		cands.append(v[0])
		cands.append(v[1])
	cands.shuffle()
	for c in cands:
		var at := DeckLevel.center(c) + Vector3(rng.randf_range(-1.0, 1.0), 0.05, rng.randf_range(-1.0, 1.0))
		var d := at.distance_to(eye)
		if d < UNSEEN_MIN or d > UNSEEN_MAX:
			continue
		if _seen(eye, at + Vector3(0, 0.8, 0)):
			continue
		return at
	return Vector3.INF


func _seen(eye: Vector3, at: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, at, Kit.LAYER_SOLID)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _cap() -> int:
	return deck.max_alive if deck else 10


func _pick_hatch() -> String:
	var table: Dictionary = deck.hatches if deck else {"skitter": 1.0}
	var total := 0.0
	for k in table:
		total += float(table[k])
	var r := rng.randf() * total
	for k in table:
		r -= float(table[k])
		if r <= 0.0:
			return k
	return "skitter"


func _hunt(c: Creature) -> void:
	var player := Creature._player()
	if player:
		c.alert(player.global_position)


func _on_died(c: Creature) -> void:
	kills += 1
	creature_died.emit(c)
	if c.spawned and c.has_meta("tile"):
		var i: int = c.get_meta("tile")
		if i >= 0:
			debt.append([i, rng.randf_range(REGROW_TIME.x, REGROW_TIME.y), c.kind if c.kind in ["skitter", "stalker", "feeder", "watcher"] else "skitter"])

#region Pods

## Matches the pods standing on a tile to the Bloom's count there: new ones
## grow, burnt ones wither.
func _sync_tile(i: int) -> void:
	var want := int(bloom.pods.get(i, 0))
	var have: Array = pods.get(i, [])
	have = have.filter(_pod_alive)
	while have.size() > want:
		var p: Pod = have.pop_back()
		p.pop(false)
	while have.size() < want:
		have.append(_grow_pod(i))
	if have.is_empty():
		pods.erase(i)
	else:
		pods[i] = have


func _pod_alive(p: Variant) -> bool:
	return is_instance_valid(p) and not (p as Pod).dead


func _grow_pod(i: int) -> Pod:
	var cell: Vector2i = bloom.cells[i]
	var c := DeckLevel.center(cell)
	# Against a wall when the tile has one, else on the floor.
	var walls: Array[String] = []
	for s in DeckLevel.SIDE_ORDER:
		var n: Vector2i = cell + DeckLevel.STEP[s]
		if not level.tiles.has(n) or (level.tiles[n] != level.tiles[cell] and not level.walkable(cell, n)):
			walls.append(s)
	if not walls.is_empty() and rng.randf() < 0.6:
		var s: String = walls[rng.randi() % walls.size()]
		var out := Vector3(DeckLevel.STEP[s].x, 0, DeckLevel.STEP[s].y)
		var along := Vector3(out.z, 0, -out.x)
		var at := c + out * 1.55 + along * rng.randf_range(-1.2, 1.2) + Vector3(0, rng.randf_range(0.5, 2.2), 0)
		return _add_pod_at(i, at, true, -out)
	return _add_pod_at(i, c + Vector3(rng.randf_range(-1.3, 1.3), 0.0, rng.randf_range(-1.3, 1.3)), false, Vector3.ZERO)


func _add_pod_at(i: int, at: Vector3, on_wall: bool, facing: Vector3) -> Pod:
	var p := Pod.make(i, on_wall)
	p.position = at
	if on_wall:
		p.rotation.y = atan2(facing.x, facing.z)
	p.burst.connect(_on_pod_burst)
	add_child(p)
	var list: Array = pods.get(i, [])
	list.append(p)
	pods[i] = list
	return p


func _on_pod_burst(p: Pod) -> void:
	bloom.remove_pod(p.tile)
	var list: Array = pods.get(p.tile, [])
	list.erase(p)

#endregion

#region Hearts and the dead

func _add_heart(cell: Vector2i) -> void:
	var h := Heart.make(level, cell, deck != null and deck.id == "core")
	h.position = DeckLevel.center(cell)
	h.killed.connect(_on_heart_killed)
	add_child(h)
	hearts.append(h)


func _on_heart_killed(h: Heart) -> void:
	heart_killed.emit(h)


## Bodies on tiles grown to level 3 get up as the Taken. With the Gore
## setting below Full that only happens out of sight.
func _raise_the_dead() -> void:
	var player := Creature._player()
	var eye: Vector3 = player.eye_position() if player and player.has_method("eye_position") else Vector3(0, -1000, 0)
	for b in get_tree().get_nodes_in_group("bodies"):
		var body := b as CrewBody
		if body == null or body.gone or not body.is_inside_tree():
			continue
		if bloom.level_at(body.cell()) < Bloom.TAKE_LEVEL or rng.randf() > RISE_CHANCE:
			continue
		if alive() >= _cap() + 4:
			return
		var at := body.global_position
		if not Gore.full() and (at.distance_to(eye) < UNSEEN_MIN or _seen(eye, at + Vector3(0, 0.4, 0))):
			continue
		raise_body(body)


## Gets a body up as one of the Taken, with its own looks.
func raise_body(body: CrewBody) -> Taken:
	body.gone = true
	body.remove_from_group("bodies")
	var t := spawn("taken", body.global_position, false, {"job": body.job, "female": body.female, "seed": body.look_seed}) as Taken
	t.rotation.y = body.global_rotation.y
	t.rise()
	body.queue_free()
	return t

#endregion
