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

static var _icons: Dictionary = {}
static var _font_bold: Font
static var _font_med: Font
static var _theme: Theme

## Original icon art from assets/icons (see gen/make_icons.py).
static func icon(name: String) -> Texture2D:
	if not _icons.has(name):
		var path := "res://assets/icons/%s.png" % name
		_icons[name] = load(path) if ResourceLoader.exists(path) else _ability_fallback(name)
	return _icons[name]

## New brawlers without their own ability art borrow the icon of a brawler
## whose ability works the same way.
static func _ability_fallback(name: String) -> Texture2D:
	if not name.begins_with("ab_"):
		return null
	var parts := name.split("_")
	if parts.size() < 3 or not Config.BRAWLERS.has(parts[1]):
		return null
	var slot := parts[2]
	var kind: String = Config.BRAWLERS[parts[1]].get(slot, {}).get("kind", "")
	for other in ["bront", "vex", "nova", "sprig", "rio"]:
		if Config.BRAWLERS[other].get(slot, {}).get("kind", "") == kind:
			return icon("ab_%s_%s" % [other, slot])
	return null

static func draw_icon(ci: CanvasItem, name: String, center: Vector2, size: float, tint := Color.WHITE) -> void:
	var t := icon(name)
	if t:
		ci.draw_texture_rect(t, Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size)), false, tint)

static func bold() -> Font:
	if _font_bold == null:
		_font_bold = load("res://assets/fonts/LilitaOne-Regular.ttf")
	return _font_bold

static func medium() -> Font:
	if _font_med == null:
		_font_med = load("res://assets/fonts/LilitaOne-Regular.ttf")
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

## Glossy 3D button skin: vertical gradient, shine on the top half, light inner rim,
## dark outline and a chunky bottom lip. Generated once per colour and cached.
static var _skins := {}

static func glossy(col: Color, radius := 18, lip := 6, pressed := false) -> StyleBoxTexture:
	var key := "%s|%d|%d|%s" % [col.to_html(), radius, lip, pressed]
	if _skins.has(key):
		return _skins[key]
	var S := 96
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var r := float(radius)
	var lp := float(lip if not pressed else 2)
	var top_col := col.lightened(0.28)
	var bot_col := col.darkened(0.18)
	var lip_col := col.darkened(0.55)
	for y in S:
		for x in S:
			var p := Vector2(x + 0.5, y + 0.5)
			var d_out := _rr_dist(p, Vector2(0, 0), Vector2(S, S), r)
			if d_out > 0.5:
				continue
			var a := clampf(0.5 - d_out, 0.0, 1.0)
			var c := DARK
			# face (above the lip), inset by the outline
			var face_d := _rr_dist(p, Vector2(4, 4), Vector2(S - 4, S - 4 - lp), maxf(2.0, r - 4.0))
			var lip_d := _rr_dist(p, Vector2(4, 4), Vector2(S - 4, S - 4), maxf(2.0, r - 4.0))
			if face_d <= 0.0:
				var t := clampf((p.y - 4.0) / float(S - 8 - lp), 0.0, 1.0)
				c = top_col.lerp(col, smoothstep(0.0, 0.5, t)).lerp(bot_col, smoothstep(0.5, 1.0, t))
				# shine on the top half
				if t < 0.46:
					c = c.lerp(Color.WHITE, 0.16 * (1.0 - t / 0.46) + 0.06)
				# light rim just inside the top edge
				if face_d > -3.0 and p.y < S * 0.5:
					c = c.lerp(Color.WHITE, 0.35)
			elif lip_d <= 0.0:
				c = lip_col
			c.a *= a
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	var m := float(maxi(radius, 12) + 2)
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m + lp
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8 + (4 if pressed else 0)
	sb.content_margin_bottom = 10 + lp
	_skins[key] = sb
	return sb

## Signed distance to a rounded rectangle (negative inside).
static func _rr_dist(p: Vector2, a: Vector2, b: Vector2, r: float) -> float:
	var c := (a + b) * 0.5
	var h := (b - a) * 0.5 - Vector2(r, r)
	var q := (p - c).abs() - h
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r

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
	b.add_theme_stylebox_override("normal", glossy(col))
	b.add_theme_stylebox_override("hover", glossy(col.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", glossy(col.darkened(0.08), 18, 6, true))
	b.add_theme_stylebox_override("disabled", glossy(Color("5a5470")))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): Sfx.play("ui_click", -2.0, 0.04))
	b.mouse_entered.connect(func(): _pop(b, 1.04))
	b.mouse_exited.connect(func(): _pop(b, 1.0))
	b.button_down.connect(func(): _pop(b, 0.95))
	b.button_up.connect(func(): _pop(b, 1.0))
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	return b

## Smooth entrance: fade + spring scale (optionally slide), after `delay` seconds.
## Rank crest: gem-cut shield with bevelled facets, a "RANK" ribbon and the number.
## c = centre, h = total height. Colour changes every 5 ranks.
static func draw_rank_badge(ci: CanvasItem, c: Vector2, h: float, rank: int) -> void:
	var col := Progression.rank_color(rank)
	var u := h / 100.0
	var tier := Progression.rank_tier(rank)
	# crest outline: clipped top corners, straight sides, pointed bottom
	var outer := PackedVector2Array([Vector2(-30, -46), Vector2(30, -46), Vector2(42, -34), Vector2(42, 18), Vector2(0, 50), Vector2(-42, 18), Vector2(-42, -34)])
	var inner := PackedVector2Array([Vector2(-26, -39), Vector2(26, -39), Vector2(35, -30), Vector2(35, 14), Vector2(0, 41), Vector2(-35, 14), Vector2(-35, -30)])
	var face := PackedVector2Array([Vector2(-20, -30), Vector2(20, -30), Vector2(26, -24), Vector2(26, 10), Vector2(0, 30), Vector2(-26, 10), Vector2(-26, -24)])
	var tf := func(arr: PackedVector2Array, grow := 1.0) -> PackedVector2Array:
		var o := PackedVector2Array()
		for p in arr:
			o.append(c + p * u * grow)
		return o
	ci.draw_colored_polygon(tf.call(outer, 1.08), DARK)
	ci.draw_colored_polygon(tf.call(outer), col.lightened(0.15))
	# bevel facets: light from top-left, shade bottom-right
	for i in outer.size():
		var j := (i + 1) % outer.size()
		var mid := (outer[i] + outer[j]) * 0.5
		var light := clampf(0.5 - (mid.x * 0.6 + mid.y) / 90.0, 0.0, 1.0)
		var fc := col.darkened(0.35).lerp(col.lightened(0.45), light)
		ci.draw_colored_polygon(PackedVector2Array([c + outer[i] * u, c + outer[j] * u, c + inner[j] * u, c + inner[i] * u]), fc)
	ci.draw_colored_polygon(tf.call(inner), DARK)
	ci.draw_colored_polygon(tf.call(face), col.darkened(0.4))
	ci.draw_colored_polygon(PackedVector2Array([c + face[0] * u, c + face[1] * u, c + face[2] * u, c + Vector2(26, -8) * u, c + Vector2(-26, -8) * u, c + face[6] * u]), col.darkened(0.15))
	# shine streak
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-30, -34) * u, c + Vector2(-18, -34) * u, c + Vector2(-34, 6) * u, c + Vector2(-34, -24) * u]), Color(1, 1, 1, 0.25))
	# ribbon banner with folded tails
	var ry := -30.0
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-50, ry - 2) * u, c + Vector2(-38, ry - 2) * u, c + Vector2(-38, ry + 16) * u, c + Vector2(-50, ry + 16) * u, c + Vector2(-44, ry + 7) * u]), DARK)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(50, ry - 2) * u, c + Vector2(38, ry - 2) * u, c + Vector2(38, ry + 16) * u, c + Vector2(50, ry + 16) * u, c + Vector2(44, ry + 7) * u]), DARK)
	ci.draw_rect(Rect2(c + Vector2(-40, ry - 4) * u, Vector2(80, 22) * u), DARK)
	ci.draw_rect(Rect2(c + Vector2(-37, ry - 1) * u, Vector2(74, 16) * u), Color("f2f4ff"))
	ci.draw_rect(Rect2(c + Vector2(-37, ry + 9) * u, Vector2(74, 6) * u), Color("c9cfe8"))
	var S := preload("res://scripts/ui/main_menu.gd").SlantButton
	S.text_c(ci, "RANK", c + Vector2(0, ry + 12.5) * u, int(15 * u), DARK, 1)
	S.text_c(ci, str(rank), c + Vector2(0, 22) * u, int((34 if rank < 10 else 30) * u), Color.WHITE, maxi(4, int(7 * u)))
	# top gem on higher tiers
	if tier >= 2:
		var g := c + Vector2(0, -50) * u
		var gem := PackedVector2Array([g + Vector2(0, -9) * u, g + Vector2(8, 0) * u, g + Vector2(0, 9) * u, g + Vector2(-8, 0) * u])
		ci.draw_colored_polygon(PackedVector2Array([g + Vector2(0, -12) * u, g + Vector2(11, 0) * u, g + Vector2(0, 12) * u, g + Vector2(-11, 0) * u]), DARK)
		ci.draw_colored_polygon(gem, col.lightened(0.5))

static func pop_in(c: CanvasItem, delay := 0.0, from_offset := Vector2.ZERO) -> void:
	if c == null:
		return
	c.modulate.a = 0.0
	var ctl := c as Control
	var target_pos := Vector2.ZERO
	if ctl:
		ctl.scale = Vector2(0.88, 0.88)
		target_pos = ctl.position
		ctl.set_meta("pop_target", target_pos)
		ctl.position += from_offset
		ctl.resized.connect(func(): ctl.pivot_offset = ctl.size * 0.5, CONNECT_ONE_SHOT)
		ctl.pivot_offset = ctl.size * 0.5
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.22).set_delay(delay)
	if ctl:
		tw.tween_property(ctl, "scale", Vector2.ONE, 0.38).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if from_offset != Vector2.ZERO:
			tw.tween_property(ctl, "position", target_pos, 0.35).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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
		var names := {"trophy": "trophy", "coin": "coin", "gem": "crystal", "gems": "gem", "star": "star", "xp": "xp", "token": "token"}
		UIKit.draw_icon(self, names.get(kind, kind), size * 0.5, min(size.x, size.y) * 1.15)


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
	var view_kind := "portrait"
	var _t := 0.0
	var _view: BrawlerView
	var _rect: TextureRect

	var flat := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 2D brawler view: draw the 2D art here instead of a 3D render
		flat = Save.setting("view_mode") == "2d"
		if flat:
			clip_contents = view_kind == "bust"
			if locked:
				modulate = Color(0.2, 0.2, 0.25, 0.8)
			return
		var want: Vector2 = custom_minimum_size if custom_minimum_size != Vector2.ZERO else size
		var px := int(clampf(max(want.x, want.y) * 1.6, 128.0, 640.0))
		var sk := Save.selected_skin(brawler_id) if skin == "auto" else skin
		_view = BrawlerView.create(brawler_id, view_kind, px, art_scale >= 2.0, sk)
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
		if art_scale < 2.0:
			_freeze.call_deferred()

	## Still portraits: keep a plain copy of the render and free the 3D viewport
	## (screens like the shop show dozens of these; each viewport costs memory).
	func _freeze() -> void:
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		if not is_instance_valid(_view):
			return
		var img := _view.get_texture().get_image()
		if img:
			_rect.texture = ImageTexture.create_from_image(img)
			_view.queue_free()
			_view = null

	func _process(delta: float) -> void:
		_t += delta
		if backdrop or flat:
			queue_redraw()

	func _draw() -> void:
		if backdrop:
			_draw_backdrop()
		if flat:
			var sk := Save.selected_skin(brawler_id) if skin == "auto" else skin
			var s: float
			var feet: Vector2
			if view_kind == "bust":
				# head-and-shoulders crop
				s = size.y / 46.0
				feet = Vector2(size.x * 0.5, size.y * 0.58 + 52.0 * s)
			else:
				s = minf(size.y / 96.0, size.x / 78.0)
				feet = Vector2(size.x * 0.5, size.y * 0.95)
			BrawlerArt.draw(self, brawler_id, feet, s, {"t": _t, "aim": Vector2(1, 0.25), "skin": sk})

	func _draw_backdrop() -> void:
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


## Square profile icon: framed, clipped head-and-shoulders of a brawler.
class ProfileIcon extends Control:
	var brawler_id := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		var id := brawler_id if brawler_id != "" else Save.profile_icon()
		var pt := UIKit.BrawlerPortrait.new()
		pt.brawler_id = id
		pt.backdrop = false
		pt.view_kind = "bust"
		pt.art_scale = 1.0
		pt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pt.custom_minimum_size = custom_minimum_size
		add_child(pt)
		set_meta("bid", id)

	func _draw() -> void:
		var id: String = get_meta("bid", "bront")
		var rc: Color = Config.RARITY_COLORS[Config.BRAWLERS[id].rarity]
		draw_rect(Rect2(Vector2.ZERO, size), rc.lerp(Color("bfe4ff"), 0.3))
		draw_rect(Rect2(Vector2.ZERO, size), UIKit.DARK, false, 4.0)


## Flame badge with the current win streak number.
class StreakBadge extends Control:
	var streak := 0
	var t := 0.0
	var show_label := true
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	static func _flame_pts(c: Vector2, w: float, h: float, tt: float) -> PackedVector2Array:
		# key points: round base, side tongues, tall centre tip (flickers)
		var f1 := sin(tt * 8.0) * 0.05
		var f2 := sin(tt * 6.3 + 1.7) * 0.06
		var key := [
			Vector2(0.0, 0.5), Vector2(0.38, 0.4), Vector2(0.5, 0.12), Vector2(0.44, -0.18),
			Vector2(0.52 + f2, -0.42), Vector2(0.28, -0.24), Vector2(0.22, -0.5),
			Vector2(0.04 + f1, -0.86), Vector2(-0.12, -0.5), Vector2(-0.24, -0.34),
			Vector2(-0.48 - f1, -0.58), Vector2(-0.46, -0.16), Vector2(-0.5, 0.12), Vector2(-0.38, 0.4),
		]
		var pts := PackedVector2Array()
		var n := key.size()
		for i in n:
			var p0: Vector2 = key[(i - 1 + n) % n]
			var p1: Vector2 = key[i]
			var p2: Vector2 = key[(i + 1) % n]
			var p3: Vector2 = key[(i + 2) % n]
			for k in 5:
				var t := k / 5.0
				var t2 := t * t
				var t3 := t2 * t
				var q: Vector2 = 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
				pts.append(c + Vector2(q.x * w, q.y * h))
		return pts

	static func flame(ci: CanvasItem, c: Vector2, h: float, col: Color, tt: float) -> void:
		var w := h * 0.9
		var hh := h * 0.95
		ci.draw_colored_polygon(_flame_pts(c + Vector2(0, 2), w * 1.16, hh * 1.12, tt), Color("1a1020"))
		ci.draw_colored_polygon(_flame_pts(c, w, hh, tt), col.darkened(0.15))
		ci.draw_colored_polygon(_flame_pts(c + Vector2(0, h * 0.06), w * 0.78, hh * 0.8, tt + 0.6), col)
		ci.draw_colored_polygon(_flame_pts(c + Vector2(0, h * 0.2), w * 0.5, hh * 0.5, tt + 1.3), col.lightened(0.5))

	func _draw() -> void:
		var col := Progression.streak_color(streak) if streak > 0 else Color("8a93a8")
		var h := size.y
		if show_label and size.x > h * 1.4:
			var bg := PackedVector2Array([Vector2(h * 0.5, h * 0.12), Vector2(size.x, h * 0.12), Vector2(size.x - 10, h * 0.92), Vector2(h * 0.5, h * 0.92)])
			draw_colored_polygon(bg, Color(0.06, 0.07, 0.14, 0.72))
		var c := Vector2(h * 0.5, h * 0.56)
		flame(self, c, h, col, t)
		var f: Font = UIKit.bold()
		var fs := int(h * 0.46)
		var txt := str(streak)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tp := c + Vector2(-tw * 0.5, h * 0.27)
		draw_string_outline(f, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color("1a1020"))
		draw_string(f, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		if show_label and size.x > h * 1.4:
			var ls := int(h * 0.3)
			var lp := Vector2(h * 1.02, h * 0.42)
			draw_string_outline(f, lp, "WIN STREAK", HORIZONTAL_ALIGNMENT_LEFT, -1, ls, 5, Color("1a1020"))
			draw_string(f, lp, "WIN STREAK", HORIZONTAL_ALIGNMENT_LEFT, -1, ls, col.lightened(0.3))
			var b := Progression.streak_bonus(streak + 1)
			var sub := "NEXT WIN  +%d TROPHIES  +%d COINS" % [int(b.trophies), int(b.credits)]
			if streak == 0:
				sub = "WIN 2 IN A ROW FOR BONUSES"
			var lp2 := Vector2(h * 1.02, h * 0.78)
			draw_string_outline(f, lp2, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, int(ls * 0.75), 4, Color("1a1020"))
			draw_string(f, lp2, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, int(ls * 0.75), Color.WHITE)


## Slide-down notification banner (auto hides).
static func toast(parent: Control, text: String, icon_name := "", col := Color("2a1460")) -> void:
	var t := Toast.new()
	t.text = text
	t.icon_name = icon_name
	t.col = col
	parent.add_child(t)

class Toast extends Control:
	var text := ""
	var icon_name := ""
	var col := Color("2a1460")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 50
		var f := UIKit.bold()
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + (90.0 if icon_name != "" else 50.0)
		size = Vector2(w, 64)
		position = Vector2(640 - w * 0.5, -80)
		var tw := create_tween()
		tw.tween_property(self, "position:y", 96.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(3.2)
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)
	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), UIKit.DARK)
		draw_rect(Rect2(3, 3, size.x - 6, size.y - 6), col)
		draw_rect(Rect2(3, 3, size.x - 6, 20), Color(1, 1, 1, 0.12))
		var x := 24.0
		if icon_name != "":
			UIKit.draw_icon(self, icon_name, Vector2(44, 32), 50.0)
			x = 76.0
		var f := UIKit.bold()
		draw_string_outline(f, Vector2(x, 40), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, UIKit.DARK)
		draw_string(f, Vector2(x, 40), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
