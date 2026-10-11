class_name StationTheme
extends RefCounted
## Verdigris Protocol's look for the shared theme: the station's own screens, dark
## glass panels with thin pale edges, teal for what's fine, amber for what
## needs you and red for trouble. The type is sharp sci-fi: titles in Saira
## Stencil, cut like the markings sprayed on a hull, headings, buttons and the
## HUD in Chakra Petch, and running text (speech, logs, menus) in Saira, which
## reads well in long lines. Symbols they lack (▲, ■, arrows) come from
## Montserrat, which comes with Cogito.

const TEXT := Color(0.86, 0.93, 0.95)
const DIM := Color(0.55, 0.66, 0.7)
const TEAL := Color(0.42, 0.88, 0.86)
const AMBER := Color(1.0, 0.62, 0.25)
const RED := Color(1.0, 0.32, 0.24)
const GREEN := Color(0.45, 0.95, 0.6)
const PANEL := Color(0.035, 0.045, 0.055, 0.86)
const EDGE := Color(0.55, 0.78, 0.82, 0.4)
## The green of a crew log's screen.
const SCREEN := Color(0.62, 1.0, 0.72)
const MONTSERRAT := "res://addons/cogito/Assets/Fonts/Montserrat/"
const FONTS := "res://assets/fonts/"

static var text_font: Font
static var bold_font: Font
## Headings, buttons and the HUD.
static var heading_font: Font
## The biggest words: the game's name, a result, a banner.
static var title_font: Font


static func apply(root: Window, base_size := 22) -> Theme:
	var t := build(base_size)
	root.theme = t
	ThemeDB.get_default_theme().merge_with(t)
	ThemeDB.get_default_theme().default_font = t.default_font
	ThemeDB.get_default_theme().default_font_size = t.default_font_size
	return t


static func build(base_size := 22) -> Theme:
	var t := LGTheme.build(base_size)
	if text_font == null:
		var symbols: Font = load(MONTSERRAT + "Montserrat-Medium.ttf")
		text_font = _font("Saira.ttf", 500, symbols)
		bold_font = _font("Saira.ttf", 700, symbols)
		heading_font = _font("ChakraPetch-SemiBold.ttf", 0, symbols)
		title_font = _font("SairaStencilOne.ttf", 0, symbols)
	# The add-on's own screens and StationTheme's HUD labels read this.
	LGTheme.heading_font = heading_font
	t.default_font = text_font
	t.set_font("normal_font", "RichTextLabel", text_font)
	t.set_font("bold_font", "RichTextLabel", bold_font)
	for v in ["HeaderMedium", "InkHeader", "NameLabel", "Button", "OptionButton", "MenuButton"]:
		t.set_font("font", v, heading_font)
	for v in ["HeaderLarge", "InkTitle"]:
		t.set_font("font", v, title_font)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", "Label", 3)
	for v in ["InkLabel", "InkHeader", "InkTitle"]:
		t.set_color("font_color", v, TEXT)
	t.set_type_variation("DimLabel", "Label")
	t.set_color("font_color", "DimLabel", DIM)
	t.set_font_size("font_size", "DimLabel", int(base_size * 0.8))
	t.set_type_variation("ScreenLabel", "Label")
	t.set_font("font", "ScreenLabel", text_font)
	t.set_color("font_color", "ScreenLabel", SCREEN)
	t.set_constant("outline_size", "ScreenLabel", 0)

	# Buttons: dark plates with a pale edge; focus lights the edge amber.
	var normal := box(Color(0.07, 0.09, 0.11, 0.94), EDGE, 2, 6)
	normal.set_content_margin_all(12)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.11, 0.15, 0.17, 0.96)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.04, 0.05, 0.06, 0.96)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.05, 0.05, 0.06, 0.7)
	disabled.border_color = Color(EDGE, 0.15)
	var focus := box(Color(AMBER, 0.12), AMBER, 3, 6)
	for type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_focus_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, TEXT)
		t.set_color("font_hover_pressed_color", type, Color.WHITE)
		t.set_color("font_disabled_color", type, Color(DIM, 0.6))
	var danger := box(Color(0.35, 0.06, 0.05, 0.94), Color(RED, 0.7), 2, 6)
	danger.set_content_margin_all(12)
	danger.content_margin_left = 22
	danger.content_margin_right = 22
	t.set_stylebox("normal", "DangerButton", danger)
	t.set_stylebox("hover", "DangerButton", danger)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		t.set_color(c, "DangerButton", Color.WHITE)

	# Panels.
	var panel := box(PANEL, EDGE, 1, 8)
	panel.set_content_margin_all(22)
	for v in ["PanelContainer", "Panel", "DarkPanel", "ParchmentPanel"]:
		t.set_stylebox("panel", v, panel)
	var glass := box(Color(0.02, 0.03, 0.04, 0.72), Color(EDGE, 0.25), 1, 6)
	glass.set_content_margin_all(14)
	t.set_stylebox("panel", "GlassPanel", glass)
	t.set_type_variation("ScreenPanel", "PanelContainer")
	var screen := box(Color(0.01, 0.06, 0.04, 0.95), Color(SCREEN, 0.45), 2, 4)
	screen.set_content_margin_all(26)
	t.set_stylebox("panel", "ScreenPanel", screen)

	# Text entry.
	var edit := box(Color(0.02, 0.03, 0.04, 0.95), EDGE, 2, 4)
	edit.set_content_margin_all(10)
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", AMBER)
	t.set_color("font_placeholder_color", "LineEdit", Color(DIM, 0.6))

	# Bars.
	t.set_stylebox("background", "ProgressBar", box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("fill", "ProgressBar", box(TEAL, Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("fill", "RedProgressBar", box(RED, Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("fill", "BlueProgressBar", box(Color(0.45, 0.75, 1.0), Color(0, 0, 0, 0), 0, 2))
	t.set_type_variation("AmberProgressBar", "ProgressBar")
	t.set_stylebox("fill", "AmberProgressBar", box(AMBER, Color(0, 0, 0, 0), 0, 2))
	t.set_type_variation("GreenProgressBar", "ProgressBar")
	t.set_stylebox("fill", "GreenProgressBar", box(GREEN, Color(0, 0, 0, 0), 0, 2))
	t.set_color("default_color", "RichTextLabel", TEXT)
	return t


## One of the game's fonts at a weight (0 for a font with only one), with
## Montserrat behind it for the symbols it lacks.
static func _font(file: String, weight: int, symbols: Font) -> Font:
	var f := FontVariation.new()
	f.base_font = load(FONTS + file)
	if weight > 0:
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	f.fallbacks = [symbols]
	return f


static func box(bg: Color, edge: Color, width: int, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = edge
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	return b


## A small panel for the HUD: dark glass with a thin edge.
static func hud_panel(edge := EDGE) -> PanelContainer:
	var p := PanelContainer.new()
	var b := box(Color(0.02, 0.03, 0.04, 0.62), edge, 1, 6)
	b.content_margin_left = 16
	b.content_margin_right = 16
	b.content_margin_top = 10
	b.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", b)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A HUD label in the heading font, spaced out like the station's screens.
static func hud_label(text: String, size := 18, color := TEXT, heading := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 2)
	if heading and LGTheme.heading_font:
		l.add_theme_font_override("font", LGTheme.heading_font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A HUD label in the title font, for the biggest words.
static func title_label(text: String, size := 40, color := TEXT) -> Label:
	var l := hud_label(text, size, color, false)
	if title_font:
		l.add_theme_font_override("font", title_font)
		# The stencil's lines stand far apart; a title's two lines sit close.
		l.add_theme_constant_override("line_spacing", -roundi(size * 0.3))
	return l


## A thin bar for the HUD.
static func bar(color: Color, width := 160.0, height := 8.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(width, height)
	b.max_value = 1.0
	b.add_theme_stylebox_override("background", box(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 0, 2))
	b.add_theme_stylebox_override("fill", box(color, Color(0, 0, 0, 0), 0, 2))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b
