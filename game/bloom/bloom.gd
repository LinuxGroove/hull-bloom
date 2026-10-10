class_name Bloom
extends RefCounted
## The Bloom on one deck's grid: a growth level for every 4 m tile, from 0
## (clean) to 4 (overgrown). It has no nodes: the deck ticks it every few
## seconds, its look reads the levels, and the tests run whole nights.
##
## Each tick a tile that can trace a path back to a living root grows, and
## tiles at [constant SPREAD_FROM] or more seed their neighbours through open
## ways, doors (barely, when shut; never when sealed), vents and cable runs.
## Tiles cut off from every root die back slowly. Lit tiles grow and are
## seeded at half speed; vented rooms are airless and stay clean. Overgrown
## tiles sprout pods, which [Director] turns into creatures.

## How a link between two tiles lets the growth through.
enum Kind { OPEN, DOOR, VENT, CABLE }
## A door's state.
enum Door { OPEN, CLOSED, SEALED }

const MAX := 4.0
## Seconds between ticks at normal speed (the difficulty setting scales it).
const TICK := 3.0
## A tile spreads to its neighbours once it has grown this far.
const SPREAD_FROM := 2.0
## A newly reached tile starts at this level.
const SEED := 0.35
## Growth per tick on a tile fed from a root.
const FEED := 0.09
## Growth lost per tick on a tile cut off from every root.
const DECAY := 0.07
## The chance per tick that a tile at full growth seeds a neighbour through
## an open way (scaled by how grown it is and how the way lets it through).
const SPREAD_CHANCE := 0.14
## How much each kind of link lets the growth through.
const OPEN_FACTOR := 1.0
const CLOSED_DOOR_FACTOR := 0.12
const VENT_FACTOR := 0.6
const CABLE_FACTOR := 0.4
## Lit tiles grow and are reached at this fraction of the speed.
const LIT_FACTOR := 0.5
## A tile this grown sprouts pods, up to [constant POD_CAP] of them.
const POD_LEVEL := 3.9
const POD_CAP := 2
const POD_CHANCE := 0.08
## Pods wither when their tile is burnt back below this.
const POD_WITHER := 2.0
## A body lying on a tile this grown gets up again as one of the Taken.
const TAKE_LEVEL := 3.0

## Tile coordinates, by index.
var cells: Array[Vector2i] = []
## Tile coordinates -> index.
var index := {}
var growth := PackedFloat32Array()
## Each tile's room, an index into [member room_names].
var room := PackedInt32Array()
var room_names: Array[String] = []
## How fast each tile grows and is reached: warm, damp, dark rooms are faster.
var mult := PackedFloat32Array()
## Powered room lights, per room.
var room_lit := PackedByteArray()
## Ticks of flare light left, per tile.
var flare := PackedInt32Array()
## Rooms opened to space, per room: airless, and the growth can't live there.
var airless := PackedByteArray()
## Per tile: [[other tile, link id], ...].
var links: Array = []
## Per link: {"a", "b", "kind", "door"}.
var edges: Array[Dictionary] = []
## Root tiles and whether each is still alive.
var roots := PackedInt32Array()
var root_alive := PackedByteArray()
## Pods per tile index.
var pods := {}
## Scorch per tile, 1 when just burnt, fading over a few ticks (for the look).
var scorch := PackedFloat32Array()
var rng := RandomNumberGenerator.new()
## The difficulty's spread speed.
var speed := 1.0
var ticks := 0
## What the last tick did, for the deck and its look.
var changed: Array[int] = []
var sprouted: Array[int] = []
var withered: Array[int] = []
var reached_rooms: Array[int] = []
## Bumped whenever any level changes (ticks and burns), so the look knows
## when to redraw.
var version := 0


func _init(p_seed := 1) -> void:
	rng.seed = p_seed


## Adds a tile in a room (made on first use). Returns its index.
func add_tile(cell: Vector2i, room_name := "", p_mult := 1.0) -> int:
	if index.has(cell):
		return index[cell]
	var i := cells.size()
	cells.append(cell)
	index[cell] = i
	growth.append(0.0)
	scorch.append(0.0)
	var r := room_names.find(room_name)
	if r < 0:
		r = room_names.size()
		room_names.append(room_name)
		room_lit.append(0)
		airless.append(0)
	room.append(r)
	mult.append(p_mult)
	flare.append(0)
	links.append([])
	return i


## Joins two tiles. Returns the link's id, for doors.
func link(a: Vector2i, b: Vector2i, kind := Kind.OPEN, door := Door.OPEN) -> int:
	var ia: int = index[a]
	var ib: int = index[b]
	var id := edges.size()
	edges.append({"a": ia, "b": ib, "kind": kind, "door": door})
	links[ia].append([ib, id])
	links[ib].append([ia, id])
	return id


func find_link(a: Vector2i, b: Vector2i) -> int:
	if not index.has(a) or not index.has(b):
		return -1
	var ib: int = index[b]
	for l in links[index[a]]:
		if l[0] == ib:
			return l[1]
	return -1


func set_door(link_id: int, state: Door) -> void:
	edges[link_id]["door"] = state


func door_state(link_id: int) -> Door:
	return edges[link_id]["door"]


func add_root(cell: Vector2i, level := MAX) -> void:
	var i: int = index[cell]
	roots.append(i)
	root_alive.append(1)
	growth[i] = maxf(growth[i], level)
	version += 1


## The root on this tile is cut out: what it fed starts to die back.
func kill_root(cell: Vector2i) -> void:
	var i: int = index.get(cell, -1)
	for k in roots.size():
		if roots[k] == i:
			root_alive[k] = 0


func roots_alive() -> int:
	var n := 0
	for a in root_alive:
		n += a
	return n


## Starting growth on a tile (levels never go above [constant MAX]).
func set_level(cell: Vector2i, level: float) -> void:
	growth[index[cell]] = clampf(level, 0.0, MAX)
	version += 1


func level_at(cell: Vector2i) -> float:
	var i: int = index.get(cell, -1)
	return growth[i] if i >= 0 else 0.0


func room_of(cell: Vector2i) -> int:
	var i: int = index.get(cell, -1)
	return room[i] if i >= 0 else -1


func set_room_lit(room_name: String, on: bool) -> void:
	var r := room_names.find(room_name)
	if r >= 0:
		room_lit[r] = 1 if on else 0


func is_lit(i: int) -> bool:
	return room_lit[room[i]] == 1 or flare[i] > 0


## A flare on this tile lights it for `seconds`.
func add_flare(cell: Vector2i, seconds: float) -> void:
	var i: int = index.get(cell, -1)
	if i >= 0:
		flare[i] = maxi(flare[i], ceili(seconds / TICK))


## Opens a room to space: every tile in it goes clean and stays that way.
func vent_room(room_name: String) -> void:
	var r := room_names.find(room_name)
	if r < 0:
		return
	airless[r] = 1
	for i in cells.size():
		if room[i] == r:
			growth[i] = 0.0
			pods.erase(i)
			if not changed.has(i):
				changed.append(i)
	version += 1


## Burns a tile's growth down by `amount` levels; returns how much went.
func burn(cell: Vector2i, amount: float) -> float:
	var i: int = index.get(cell, -1)
	if i < 0 or growth[i] <= 0.0:
		return 0.0
	var before := growth[i]
	growth[i] = maxf(0.0, before - amount)
	scorch[i] = 1.0
	if growth[i] < POD_WITHER and pods.has(i):
		pods.erase(i)
		withered.append(i)
	if floori(before) != floori(growth[i]) or growth[i] == 0.0:
		if not changed.has(i):
			changed.append(i)
	version += 1
	return before - growth[i]


## How a link lets the growth through, 0 when it doesn't.
func link_factor(link_id: int) -> float:
	var e: Dictionary = edges[link_id]
	match e["kind"]:
		Kind.OPEN:
			return OPEN_FACTOR
		Kind.DOOR:
			match e["door"]:
				Door.OPEN:
					return OPEN_FACTOR
				Door.CLOSED:
					return CLOSED_DOOR_FACTOR
				_:
					return 0.0
		Kind.VENT:
			return VENT_FACTOR
		Kind.CABLE:
			return CABLE_FACTOR
	return 0.0


## Which tiles trace a path back to a living root, through grown tiles and
## links the growth can pass.
func fed() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(cells.size())
	var queue: Array[int] = []
	for k in roots.size():
		if root_alive[k] == 1 and airless[room[roots[k]]] == 0:
			out[roots[k]] = 1
			queue.append(roots[k])
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		for l in links[i]:
			var j: int = l[0]
			if out[j] == 1 or growth[j] <= 0.0 or link_factor(l[1]) <= 0.0:
				continue
			out[j] = 1
			queue.append(j)
	return out


## One tick of the Bloom.
func step() -> void:
	changed.clear()
	sprouted.clear()
	withered.clear()
	reached_rooms.clear()
	var is_fed := fed()
	var next := growth.duplicate()
	var room_had := PackedByteArray()
	room_had.resize(room_names.size())
	for i in cells.size():
		if growth[i] > 0.0:
			room_had[room[i]] = 1
	for i in cells.size():
		var g := growth[i]
		if airless[room[i]] == 1:
			next[i] = 0.0
			continue
		var rate := mult[i] * speed * (LIT_FACTOR if is_lit(i) else 1.0)
		if g > 0.0:
			if is_fed[i] == 1:
				next[i] = minf(MAX, g + FEED * rate)
			else:
				next[i] = maxf(0.0, g - DECAY)
		# Only fed growth reaches out: cut the root and the front stops.
		if g >= SPREAD_FROM and is_fed[i] == 1:
			for l in links[i]:
				var j: int = l[0]
				if growth[j] > 0.0 or next[j] > 0.0 or airless[room[j]] == 1:
					continue
				var f := link_factor(l[1])
				if f <= 0.0:
					continue
				var chance := SPREAD_CHANCE * f * mult[j] * speed * (g / MAX)
				if is_lit(j):
					chance *= LIT_FACTOR
				if rng.randf() < chance:
					next[j] = SEED
	for i in cells.size():
		var before := growth[i]
		var after := next[i]
		if floori(before) != floori(after) or (before == 0.0) != (after == 0.0):
			changed.append(i)
		if before == 0.0 and after > 0.0 and room_had[room[i]] == 0 and not reached_rooms.has(room[i]):
			reached_rooms.append(room[i])
		if after >= POD_LEVEL and int(pods.get(i, 0)) < POD_CAP and rng.randf() < POD_CHANCE * speed:
			pods[i] = int(pods.get(i, 0)) + 1
			sprouted.append(i)
		elif after < POD_WITHER and pods.has(i):
			pods.erase(i)
			withered.append(i)
		if flare[i] > 0:
			flare[i] -= 1
		scorch[i] = maxf(0.0, scorch[i] - 0.15)
	growth = next
	ticks += 1
	version += 1


## A pod on this tile hatched or was destroyed.
func remove_pod(i: int) -> void:
	if pods.has(i):
		pods[i] = int(pods[i]) - 1
		if pods[i] <= 0:
			pods.erase(i)


## The share of tiles with any real growth (level 1 or more), 0 to 1.
func coverage() -> float:
	if cells.is_empty():
		return 0.0
	var n := 0
	for g in growth:
		if g >= 1.0:
			n += 1
	return float(n) / cells.size()


func max_level() -> float:
	var m := 0.0
	for g in growth:
		m = maxf(m, g)
	return m


## The deck is held: every root is dead and nothing is left above level 1.
func is_held() -> bool:
	return roots_alive() == 0 and max_level() < 1.0


## The room's highest growth level.
func room_level(room_name: String) -> float:
	var r := room_names.find(room_name)
	var m := 0.0
	for i in cells.size():
		if room[i] == r:
			m = maxf(m, growth[i])
	return m


## Grows the deck for `n` ticks with nobody there: how a deck looks when
## you come back to it.
func advance(n: int) -> void:
	for k in n:
		step()
