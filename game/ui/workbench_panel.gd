class_name WorkbenchPanel
extends Control
## A saved deck's workbench: salvage from the decks buys upgrades for the
## sprayer, the suit and the guns (the red guns of the kit).

signal closed

var _salvage: Label
var _list: VBoxContainer
var _col: VBoxContainer
var _panel: PanelContainer
var on_bought := Callable()


func _init() -> void:
	name = "Workbench"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	col.add_child(LGUi.label("Workbench", "HeaderMedium"))
	_salvage = LGUi.label("", "")
	_salvage.add_theme_color_override("font_color", StationTheme.AMBER)
	col.add_child(_salvage)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	col.add_child(_list)
	col.add_child(LGUi.button("Done", close, 600))
	_col = col


func _ready() -> void:
	LGScreenFit.center(_panel)


func open() -> void:
	_refresh()
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# The first upgrade you can buy, or Done when there's none.
	LGUi.focus_first(_col)


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	closed.emit()


func _refresh() -> void:
	_salvage.text = "SALVAGE: %d" % Progress.salvage()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for u in Progress.UPGRADES:
		var info: Array = Progress.UPGRADES[u]
		var have := Progress.has_upgrade(u)
		var text := "%s   (%d)   %s" % [info[0], info[2], info[1]] if not have else "%s   fitted" % info[0]
		var b := LGUi.button(text, _buy.bind(u), 600)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = have or Progress.salvage() < int(info[2])
		_list.add_child(b)
	if visible:
		LGUi.focus_first(_col)


func _buy(u: String) -> void:
	if Progress.buy(u):
		Sfx.ui(self, "ui_select")
		if on_bought.is_valid():
			on_bought.call(u)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu")):
		get_viewport().set_input_as_handled()
		close()
