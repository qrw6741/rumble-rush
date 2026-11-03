class_name UIKit
extends RefCounted
## Shared look for every menu: chunky outlined text, rounded glossy buttons with
## press/hover animation and sounds.

const DARK := Color("1a1028")
const ORANGE := Color("ff9d2e")
const YELLOW := Color("ffd23a")
const GREEN := Color("4fd36a")
const BLUE := Color("3ea2ff")
const PURPLE := Color("8e4dff")
const RED := Color("ff4d5e")
const PANEL := Color("27334d")
const PANEL_LIGHT := Color("3a4a70")

static var _font_bold: Font
static var _font_med: Font
static var _theme: Theme

static func bold() -> Font:
	if _font_bold == null:
		_font_bold = load("res://assets/fonts/Poppins-Bold.ttf")
	return _font_bold

static func medium() -> Font:
	if _font_med == null:
		_font_med = load("res://assets/fonts/Poppins-Medium.ttf")
	return _font_med

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = bold()
	t.default_font_size = 20
	t.set_color("font_color", "Label", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.set_corner_radius_all(8)
	t.set_stylebox("slider", "HSlider", sb)
	var grab := StyleBoxFlat.new()
	grab.bg_color = YELLOW
	grab.set_corner_radius_all(8)
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	var icon := _circle_icon(26, YELLOW)
	t.set_icon("grabber", "HSlider", icon)
	t.set_icon("grabber_highlight", "HSlider", icon)
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(0, 0, 0, 0)
	t.set_stylebox("panel", "ScrollContainer", sc)
	_theme = t
	return t

static func _circle_icon(size: int, col: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var dd := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if dd <= size * 0.5 - 0.5:
				img.set_pixel(x, y, DARK if dd > size * 0.5 - 4.0 else col)
	return ImageTexture.create_from_image(img)

static func box(col: Color, radius := 18, border := 4, border_col := DARK, shadow := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_col
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = 0
		s.shadow_offset = Vector2(0, shadow)
		s.border_width_bottom = border + 4
		s.border_color = border_col
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s

static func button(text: String, col := ORANGE, font_size := 26, min_size := Vector2(200, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", bold())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.9))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	b.add_theme_color_override("font_outline_color", DARK)
	b.add_theme_constant_override("outline_size", 8)
	b.add_theme_stylebox_override("normal", box(col))
	b.add_theme_stylebox_override("hover", box(col.lightened(0.12)))
	var pressed := box(col.darkened(0.1), 18, 4, DARK, 2)
	pressed.content_margin_top = 12
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", box(Color("5a5470")))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): Sfx.play("ui_click", -2.0, 0.04))
	b.mouse_entered.connect(func(): _pop(b, 1.04))
	b.mouse_exited.connect(func(): _pop(b, 1.0))
	b.button_down.connect(func(): _pop(b, 0.95))
	b.button_up.connect(func(): _pop(b, 1.0))
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	return b

static func _pop(c: Control, s: float) -> void:
	if not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(s, s), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func label(text: String, size := 22, col := Color.WHITE, outline := 8, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = bold()
	ls.font_size = size
	ls.font_color = col
	ls.outline_size = outline
	ls.outline_color = DARK
	if outline > 0:
		ls.shadow_size = 0
		ls.shadow_color = Color(0, 0, 0, 0.45)
		ls.shadow_offset = Vector2(0, max(2, size / 10))
	l.label_settings = ls
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func body(text: String, size := 17, col := Color(1, 1, 1, 0.85)) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = medium()
	ls.font_size = size
	ls.font_color = col
	l.label_settings = ls
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func panel(col := PANEL, radius := 22, border := 4) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(col, radius, border, DARK, 0)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", s)
	return p

static func currency_chip(icon_kind: String, value_text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(Color(0, 0, 0, 0.45), 16, 3, DARK, 0)
	s.content_margin_left = 10
	s.content_margin_right = 16
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var ic := IconDraw.new()
	ic.kind = icon_kind
	ic.custom_minimum_size = Vector2(30, 30)
	h.add_child(ic)
	var l := label(value_text, 22, col, 6)
	l.name = "Value"
	h.add_child(l)
	p.add_child(h)
	return p

## Small vector icons used across menus.
class IconDraw extends Control:
	var kind := "trophy"
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		if kind == "gem":
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r: float = min(size.x, size.y) * 0.5
		match kind:
			"trophy":
				var gold := Color("ffd23a")
				var cup := PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.75), c + Vector2(r * 0.7, -r * 0.75), c + Vector2(r * 0.5, r * 0.05), c + Vector2(r * 0.15, r * 0.3), c + Vector2(-r * 0.15, r * 0.3), c + Vector2(-r * 0.5, r * 0.05)])
				draw_arc(c + Vector2(-r * 0.62, -r * 0.35), r * 0.3, PI * 0.5, PI * 1.5, 12, UIKit.DARK, 5.0, true)
				draw_arc(c + Vector2(r * 0.62, -r * 0.35), r * 0.3, -PI * 0.5, PI * 0.5, 12, UIKit.DARK, 5.0, true)
				draw_arc(c + Vector2(-r * 0.62, -r * 0.35), r * 0.3, PI * 0.5, PI * 1.5, 12, gold, 2.5, true)
				draw_arc(c + Vector2(r * 0.62, -r * 0.35), r * 0.3, -PI * 0.5, PI * 0.5, 12, gold, 2.5, true)
				draw_colored_polygon(cup, gold)
				var o := cup.duplicate()
				o.append(cup[0])
				draw_polyline(o, UIKit.DARK, 2.5, true)
				draw_rect(Rect2(c + Vector2(-r * 0.15, r * 0.3), Vector2(r * 0.3, r * 0.3)), gold.darkened(0.15))
				draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.58), Vector2(r, r * 0.3)), gold.darkened(0.25))
				draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.58), Vector2(r, r * 0.3)), UIKit.DARK, false, 2.0)
				draw_circle(c + Vector2(-r * 0.25, -r * 0.45), r * 0.12, Color(1, 1, 1, 0.8))
			"coin":
				draw_circle(c, r * 0.9, UIKit.DARK)
				draw_circle(c, r * 0.78, Color("ffb52e"))
				draw_circle(c, r * 0.55, Color("ffd23a"))
				draw_rect(Rect2(c + Vector2(-r * 0.12, -r * 0.35), Vector2(r * 0.24, r * 0.7)), Color("e08a1a"))
				draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.12, Color(1, 1, 1, 0.8))
			"gem":
				Gem.draw_gem_icon(self, c, r * 0.85, t)
			"star":
				var pts := PackedVector2Array()
				for i in 10:
					var rr := r * 0.9 if i % 2 == 0 else r * 0.4
					var a := -PI / 2 + i * PI / 5
					pts.append(c + Vector2(cos(a), sin(a)) * rr)
				draw_colored_polygon(pts, Color("ffd23a"))
				pts.append(pts[0])
				draw_polyline(pts, UIKit.DARK, 2.5, true)
			"xp":
				draw_circle(c, r * 0.9, UIKit.DARK)
				draw_circle(c, r * 0.76, Color("3ea2ff"))
				var f := UIKit.bold()
				var s := f.get_string_size("XP", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.8))
				draw_string(f, c + Vector2(-s.x * 0.5, r * 0.3), "XP", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.8), Color.WHITE)


## Animated menu backdrop: gradient, scrolling diagonal stripes and drifting sparks.
class MenuBackground extends Control:
	var top := Color("3a1f7a")
	var bottom := Color("12092c")
	var _t := 0.0
	var _sparks: Array = []

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 40:
			_sparks.append([randf(), randf(), randf_range(0.02, 0.06), randf_range(1.5, 4.0), randf()])

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var steps := 24
		for i in steps:
			var k := float(i) / steps
			draw_rect(Rect2(0, size.y * k, size.x, size.y / steps + 1), top.lerp(bottom, k))
		var stripe := Color(1, 1, 1, 0.035)
		var w := 70.0
		var off := fmod(_t * 25.0, w * 2.0)
		var x := -size.y - w * 2.0 + off
		while x < size.x + size.y:
			draw_colored_polygon(PackedVector2Array([Vector2(x, size.y), Vector2(x + w, size.y), Vector2(x + w + size.y, 0), Vector2(x + size.y, 0)]), stripe)
			x += w * 2.0
		for s in _sparks:
			var px: float = fmod(s[0] + _t * s[2] * 0.3, 1.0) * size.x
			var py: float = fmod(s[1] - _t * s[2] + 2.0, 1.0) * size.y
			var a := 0.25 + 0.25 * sin(_t * 2.0 + s[4] * 10.0)
			draw_circle(Vector2(px, py), s[3], Color(1, 0.85, 0.5, a))


## Shows a brawler's 3D model inside a UI control, on an optional round backdrop.
## Big portraits idle-animate; small ones render once to stay cheap.
class BrawlerPortrait extends Control:
	var brawler_id := "bront"
	var art_scale := 2.0   # >= 2 means "big": animated
	var backdrop := true
	var team_col := Color("3ea2ff")
	var locked := false
	var skin := "auto" # "auto" = the player's selected skin
	var _t := 0.0
	var _view: BrawlerView
	var _rect: TextureRect

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var want: Vector2 = custom_minimum_size if custom_minimum_size != Vector2.ZERO else size
		var px := int(clampf(max(want.x, want.y) * 1.6, 128.0, 640.0))
		var sk := Save.selected_skin(brawler_id) if skin == "auto" else skin
		_view = BrawlerView.create(brawler_id, "portrait", px, art_scale >= 2.0, sk)
		add_child(_view)
		_rect = TextureRect.new()
		_rect.texture = _view.get_texture()
		_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if locked:
			_rect.modulate = Color(0.2, 0.2, 0.25, 0.8)
		add_child(_rect)

	func _process(delta: float) -> void:
		_t += delta
		if backdrop:
			queue_redraw()

	func _draw() -> void:
		if not backdrop:
			return
		var d: Dictionary = Config.BRAWLERS[brawler_id]
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		var r: float = min(size.x, size.y) * 0.46
		var p: Color = d.primary
		draw_circle(c, r + 4, UIKit.DARK)
		draw_circle(c, r, p.darkened(0.55))
		draw_circle(c + Vector2(0, -r * 0.15), r * 0.82, p.darkened(0.35))
		for i in 12:
			var a := i * TAU / 12.0 + _t * 0.2
			var col := p
			col.a = 0.12
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a), sin(a)) * r, c + Vector2(cos(a + 0.2), sin(a + 0.2)) * r]), col)
