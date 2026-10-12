class_name BloomView
extends Node3D
## How the Bloom looks on a deck. Every tile it has reached (and the tiles
## next to them) gets growth sheets on its floor, walls and ceiling, which
## the growth shader swells by the tile's level, read from a small texture
## with one texel a tile ([code]bloom_map[/code]). The levels shown ease
## towards the simulation's, so growth creeps rather than pops. Lumps of
## flesh are scattered over the thickest tiles.

## How fast the shown level follows the real one, in levels a second.
const EASE := 0.35
const SUBDIV := 22
## Sheets sit this far in from a tile's edge, against the wall's face.
const WALL_IN := 1.68
const LUMP_LEVEL := 2.6
const LUMPS_PER_TILE := 7

var level: DeckLevel
var bloom: Bloom
var rect := Rect2i()
var shown := PackedFloat32Array()
var _img: Image
var _tex: ImageTexture
## Tile index -> its sheets node.
var _sheets := {}
var _mats: Array[ShaderMaterial] = []
var _floor_mesh: PlaneMesh
var _wall_mesh: PlaneMesh
var _lumps: MultiMeshInstance3D
var _lump_version := -1
var _seen_version := -1
var _dirty := true


static func make(lvl: DeckLevel) -> BloomView:
	var v := BloomView.new()
	v.name = "BloomView"
	v.level = lvl
	v.bloom = lvl.bloom
	v._build()
	return v


func _build() -> void:
	var b := level.bounds()
	rect = b
	_img = Image.create(maxi(1, b.size.x), maxi(1, b.size.y), false, Image.FORMAT_RG8)
	_tex = ImageTexture.create_from_image(_img)
	shown.resize(bloom.cells.size())
	for i in bloom.cells.size():
		shown[i] = bloom.growth[i]
	var shader := preload("res://game/bloom/growth.gdshader")
	for s in 3:
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("surface", s)
		_mats.append(m)
	_floor_mesh = PlaneMesh.new()
	_floor_mesh.size = Vector2(Kit.TILE, Kit.TILE)
	_floor_mesh.subdivide_width = SUBDIV
	_floor_mesh.subdivide_depth = SUBDIV
	_wall_mesh = PlaneMesh.new()
	_wall_mesh.size = Vector2(Kit.TILE, Kit.HEIGHT)
	_wall_mesh.subdivide_width = SUBDIV
	_wall_mesh.subdivide_depth = int(SUBDIV * 1.25)
	_wall_mesh.orientation = PlaneMesh.FACE_Z
	_lumps = MultiMeshInstance3D.new()
	_lumps.name = "Lumps"
	_lumps.layers = 1
	add_child(_lumps)
	_upload()
	_refresh_sheets()
	_refresh_lumps()


func _enter_tree() -> void:
	_upload()


## Shows the levels as they are now, at once (after a jump, or for shots).
func snap() -> void:
	for i in bloom.cells.size():
		shown[i] = bloom.growth[i]
	_dirty = true
	_refresh_sheets()
	_refresh_lumps()
	_upload()


func _process(delta: float) -> void:
	var moved := false
	var step := EASE * delta
	for i in bloom.cells.size():
		var want := bloom.growth[i]
		var have := shown[i]
		if have != want:
			shown[i] = move_toward(have, want, step if want > have else step * 3.0)
			moved = true
	if bloom.version != _seen_version:
		_seen_version = bloom.version
		_refresh_sheets()
		moved = true
	if moved or _dirty:
		_dirty = false
		_upload()
	if bloom.version != _lump_version and Engine.get_process_frames() % 20 == 0:
		_refresh_lumps()


## Writes the shown levels and the frost into the map, and points the
## shaders at it.
func _upload() -> void:
	if _img == null:
		return
	for i in bloom.cells.size():
		var c: Vector2i = bloom.cells[i] - rect.position
		_img.set_pixel(c.x, c.y, Color(shown[i] / Bloom.MAX, bloom.frost[i], 0.0))
	_tex.update(_img)
	RenderingServer.global_shader_parameter_set("bloom_map", _tex)
	var r := Vector4(rect.position.x * Kit.TILE - Kit.TILE * 0.5, rect.position.y * Kit.TILE - Kit.TILE * 0.5, rect.size.x * Kit.TILE, rect.size.y * Kit.TILE)
	RenderingServer.global_shader_parameter_set("bloom_rect", r)


## Sheets for every tile with growth or next to growth; tiles that have
## stayed clean lose theirs.
func _refresh_sheets() -> void:
	var want := {}
	for i in bloom.cells.size():
		if bloom.growth[i] > 0.0 or shown[i] > 0.0:
			want[i] = true
			for l in bloom.links[i]:
				want[l[0]] = true
	for i in _sheets.keys():
		if not want.has(i):
			(_sheets[i] as Node).queue_free()
			_sheets.erase(i)
	for i in want:
		if not _sheets.has(i):
			_sheets[i] = _make_sheets(i)


func _make_sheets(i: int) -> Node3D:
	var cell: Vector2i = bloom.cells[i]
	var n := Node3D.new()
	n.name = "Growth_%d_%d" % [cell.x, cell.y]
	n.position = DeckLevel.center(cell)
	add_child(n)
	var f := _sheet(n, _floor_mesh, _mats[0])
	f.position.y = 0.03
	var ceil := _sheet(n, _floor_mesh, _mats[2])
	ceil.position.y = Kit.HEIGHT - 0.03
	ceil.rotation.x = PI
	for s in DeckLevel.SIDE_ORDER:
		var nb: Vector2i = cell + DeckLevel.STEP[s]
		if level.tiles.has(nb) and (level.tiles[nb] == level.tiles[cell] or String(level.ways.get(DeckLevel.edge_key(cell, nb), {}).get("kind", "")) in ["arch", "door"]):
			continue
		var out := Vector3(DeckLevel.STEP[s].x, 0, DeckLevel.STEP[s].y)
		var w := _sheet(n, _wall_mesh, _mats[1])
		w.position = out * WALL_IN + Vector3(0, Kit.HEIGHT * 0.5, 0)
		# The plane faces +z; turn it to face into the tile.
		w.rotation.y = atan2(-out.x, -out.z)
	return n


func _sheet(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The swelling can reach past the plane's own box.
	m.extra_cull_margin = 0.8
	parent.add_child(m)
	return m


## Lumps on the thickest tiles: a few per tile, more the more it's grown.
func _refresh_lumps() -> void:
	_lump_version = bloom.version
	var xfs: Array[Transform3D] = []
	for i in bloom.cells.size():
		var g := bloom.growth[i]
		if g < LUMP_LEVEL:
			continue
		var r := RandomNumberGenerator.new()
		r.seed = i * 977 + 3
		var cell: Vector2i = bloom.cells[i]
		var c := DeckLevel.center(cell)
		var n := int(LUMPS_PER_TILE * (g - LUMP_LEVEL + 0.4) / (Bloom.MAX - LUMP_LEVEL + 0.4))
		for k in n:
			var s := r.randf_range(0.5, 1.3) * (0.6 + 0.4 * g / Bloom.MAX)
			var at := c + Vector3(r.randf_range(-1.7, 1.7), 0.05, r.randf_range(-1.7, 1.7))
			var basis := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s * 1.2, s * 0.55, s * 1.2))
			xfs.append(Transform3D(basis, at))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _lump_mesh()
	mm.instance_count = xfs.size()
	for k in xfs.size():
		mm.set_instance_transform(k, xfs[k])
	_lumps.multimesh = mm
	_lumps.material_override = Flesh.material("lump")


static var _lump: Mesh


static func _lump_mesh() -> Mesh:
	if _lump == null:
		_lump = Flesh.lump_mesh(0.32, 7)
	return _lump
