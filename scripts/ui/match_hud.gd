class_name MatchHUD
extends Control
## In-battle HUD: scoreboard + timer, kill feed, announcements, respawn timer,
## PC ability readouts, pause button.

var game: Node
var _announce: Label
var _announce_t := 0.0
var _respawn: Label
var _feed: VBoxContainer
var _hint: Label
var _fps: Label
var _abilities: AbilityReadout
var _board: Scoreboard
var _left: Label
var pause_button: Button

func setup(g: Node) -> void:
	game = g

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UIKit.theme()

	_board = Scoreboard.new()
	_board.game = game
	_board.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_board.custom_minimum_size = Vector2(560, 120)
	_board.position = Vector2(-280, 4)
	add_child(_board)

	pause_button = Button.new()
	pause_button.flat = true
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.icon = UIKit.icon("pause")
	pause_button.expand_icon = true
	pause_button.custom_minimum_size = Vector2(64, 64)
	pause_button.size = Vector2(64, 64)
	pause_button.position = Vector2(14, 10)
	for st in ["normal", "hover", "pressed", "focus"]:
		pause_button.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	pause_button.pressed.connect(func(): game.toggle_pause())
	add_child(pause_button)

	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.position = Vector2(-330, 14)
	_feed.custom_minimum_size = Vector2(316, 0)
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)

	_announce = UIKit.label("", 56, Color.WHITE, 14, HORIZONTAL_ALIGNMENT_CENTER)
	_announce.set_anchors_preset(Control.PRESET_CENTER)
	_announce.custom_minimum_size = Vector2(1000, 160)
	_announce.position = Vector2(-500, -170)
	_announce.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_announce.pivot_offset = Vector2(500, 80)
	_announce.modulate.a = 0.0
	add_child(_announce)

	_respawn = UIKit.label("", 34, Color.WHITE, 10, HORIZONTAL_ALIGNMENT_CENTER)
	_respawn.set_anchors_preset(Control.PRESET_CENTER)
	_respawn.custom_minimum_size = Vector2(600, 60)
	_respawn.position = Vector2(-300, 40)
	add_child(_respawn)

	_hint = UIKit.label("Mouse aim  ·  ESC pause", 14, Color(1, 1, 1, 0.75), 5)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(210, -34)
	add_child(_hint)

	var joy := WasdStick.new()
	joy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joy.size = Vector2(170, 170)
	joy.position = Vector2(24, -196)
	add_child(joy)
	_joy = joy
	_abilities = AbilityReadout.new()
	_abilities.game = game
	_abilities.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_abilities.custom_minimum_size = Vector2(360, 170)
	_abilities.position = Vector2(-376, -184)
	add_child(_abilities)

	_left = UIKit.label("", 38, Color.WHITE, 12)
	_left.position = Vector2(90, 14)
	add_child(_left)

	_fps = UIKit.label("", 14, Color(1, 1, 1, 0.6), 4)
	_fps.position = Vector2(90, 20)
	add_child(_fps)

var _joy: Control

func set_touch_mode(on: bool) -> void:
	_hint.visible = not on
	_abilities.visible = not on
	if _joy:
		_joy.visible = not on

func announce(text: String, col: Color, dur := 1.6, size := 56) -> void:
	_announce.text = text
	_announce.label_settings.font_color = col
	_announce.label_settings.font_size = size
	_announce_t = dur
	_announce.modulate.a = 1.0
	_announce.scale = Vector2(1.6, 1.6)
	var tw := create_tween()
	tw.tween_property(_announce, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func add_feed(killer: Brawler, victim: Brawler) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kc: Color = Config.tc(killer.team) if killer else Color.WHITE
	var kname := (killer.display_name if killer else "Zone")
	var k := UIKit.label(kname, 16, kc.lightened(0.3), 5)
	var mid := TextureRect.new()
	mid.texture = UIKit.icon("ko")
	mid.custom_minimum_size = Vector2(30, 30)
	mid.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mid.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var v := UIKit.label(victim.display_name, 16, Config.tc(victim.team).lightened(0.3), 5)
	row.add_child(k)
	row.add_child(mid)
	row.add_child(v)
	_feed.add_child(row)
	_feed.move_child(row, 0)
	while _feed.get_child_count() > 4:
		var last := _feed.get_child(_feed.get_child_count() - 1)
		_feed.remove_child(last)
		last.queue_free()
	var tw := row.create_tween()
	row.modulate.a = 0.0
	tw.tween_property(row, "modulate:a", 1.0, 0.15)
	tw.tween_interval(4.0)
	tw.tween_property(row, "modulate:a", 0.0, 0.6)
	tw.tween_callback(row.queue_free)

var _pad_was := false

func _process(delta: float) -> void:
	var pad := PlayerController.pad_active()
	if pad != _pad_was:
		_pad_was = pad
		if pad:
			_abilities.visible = true
			if _joy:
				_joy.visible = true
			_hint.text = "L-stick move  ·  R-stick aim  ·  R2 attack  ·  L2 super  ·  R1 gadget  ·  OPTIONS pause"
			_hint.visible = true
		else:
			_hint.text = "Mouse aim  ·  ESC pause"
	if _announce_t > 0.0:
		_announce_t -= delta
		if _announce_t <= 0.3:
			_announce.modulate.a = max(0.0, _announce_t / 0.3)
	var p: Brawler = game.player
	if p and not p.alive and game.is_playing():
		_respawn.text = "RESPAWNING IN %d" % int(ceil(p.respawn_t))
	else:
		_respawn.text = ""
	_fps.text = ("%d FPS" % Engine.get_frames_per_second()) if Save.setting("show_fps") else ""
	var h: Dictionary = game.mode.hud()
	if h.kind == "showdown":
		_board.visible = false
		_left.text = "Brawlers left: %d" % h.left
	else:
		_left.text = ""
		_board.queue_redraw()


## Custom-drawn scoreboard with team colours and the clock.
class Scoreboard extends Control:
	var game: Node
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta

	func _draw() -> void:
		var f := UIKit.bold()
		var h: Dictionary = game.mode.hud()
		var w := size.x
		var mid := w * 0.5
		var view: int = game.view_team
		var my_col: Color = Config.tc(view)
		var their_col: Color = Config.tc(1 - view)
		var mine: int = h.blue if view == 0 else h.red
		var theirs: int = h.red if view == 0 else h.blue
		var target: int = h.target
		# team plates (slanted, gradient)
		_plate(Rect2(mid - 262, 8, 200, 62), my_col, true)
		_plate(Rect2(mid + 62, 8, 200, 62), their_col, false)
		var ic := "crystal" if h.kind == "gem" else "ko"
		UIKit.draw_icon(self, ic, Vector2(mid - 222, 39), 52.0)
		UIKit.draw_icon(self, ic, Vector2(mid + 222, 39), 52.0)
		_text(f, str(mine), Vector2(mid - 132, 58), 44, Color.WHITE)
		_text(f, str(theirs), Vector2(mid + 132, 58), 44, Color.WHITE)
		# progress pips
		_pips(Vector2(mid - 252, 80), mine, target, my_col, false)
		_pips(Vector2(mid + 72, 80), theirs, target, their_col, true)
		# clock plate
		var tl: float = max(0.0, game.time_left)
		var clock := "%d:%02d" % [int(tl) / 60, int(tl) % 60]
		var urgent := tl <= 10.0
		var cr := Rect2(mid - 56, 4, 112, 54)
		draw_style_box(_sb(Color("0d1426"), 14), cr.grow(3))
		draw_style_box(_sb(Color("27334d") if not urgent else Color("7a1525"), 12), cr)
		var pulse := 1.0 + (0.08 * sin(_t * 12.0) if urgent else 0.0)
		draw_set_transform(Vector2(mid, 44), 0, Vector2(pulse, pulse))
		_text(f, clock, Vector2.ZERO, 34, Color.WHITE if not urgent else Color("ffd0d0"))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		if h.kind == "gem" and h.countdown_team != -1:
			var cc: Color = Config.tc(h.countdown_team)
			var c := Vector2(mid, 94)
			draw_circle(c, 30, UIKit.DARK)
			draw_circle(c, 26, cc.darkened(0.15))
			draw_arc(c, 26, -PI / 2, -PI / 2 + TAU * (h.countdown / 15.0), 32, Color.WHITE, 4.0, true)
			var sc := 1.0 + 0.1 * sin(_t * 10.0)
			draw_set_transform(c + Vector2(0, 11), 0, Vector2(sc, sc))
			_text(f, str(int(ceil(h.countdown))), Vector2.ZERO, 30, Color.WHITE)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		elif h.kind == "knockout" and h.overtime:
			var r := Rect2(mid - 84, 64, 168, 32)
			draw_style_box(_sb(Color("ffb52e"), 10), r)
			_text(f, "SUDDEN DEATH", Vector2(mid, 88), 20, Color.WHITE)

	func _sb(col: Color, radius: int) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(radius)
		sb.anti_aliasing = true
		return sb

	func _plate(r: Rect2, col: Color, left: bool) -> void:
		var s := 14.0
		var outer := PackedVector2Array([r.position + Vector2(s if left else 0.0, 0), r.position + Vector2(r.size.x - (0.0 if left else s), 0), r.end - Vector2(s if left else 0.0, 0), Vector2(r.position.x + (0.0 if left else s), r.end.y)])
		draw_colored_polygon(outer, UIKit.DARK)
		var inner := PackedVector2Array()
		for p in outer:
			inner.append(p + (r.get_center() - p).normalized() * 5.0)
		draw_colored_polygon(inner, col.darkened(0.15))
		draw_colored_polygon(PackedVector2Array([inner[0], inner[1], inner[1] + Vector2(-2, 16), inner[0] + Vector2(-2, 16)]), col.lightened(0.25))

	func _pips(at: Vector2, value: int, target: int, col: Color, rtl: bool) -> void:
		var n := target
		var pw := 180.0 / n
		for k in n:
			var idx := (n - 1 - k) if rtl else k
			var r := Rect2(at + Vector2(k * pw, 0), Vector2(pw - 3, 10))
			draw_rect(r.grow(2), UIKit.DARK)
			draw_rect(r, col.lightened(0.3) if idx < value else Color(0, 0, 0, 0.45))

	func _pill(r: Rect2, col: Color) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(int(r.size.y * 0.5))
		sb.set_border_width_all(3)
		sb.border_color = UIKit.DARK
		sb.anti_aliasing = true
		draw_style_box(sb, r)

	func _bar(r: Rect2, k: float, col: Color) -> void:
		draw_rect(r.grow(2), UIKit.DARK)
		draw_rect(r, Color(0, 0, 0, 0.5))
		draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), col.lightened(0.2))

	func _text(f: Font, s: String, center_bottom: Vector2, size: int, col: Color) -> void:
		var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		var p := center_bottom - Vector2(sz.x * 0.5, 0)
		draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, UIKit.DARK)
		draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## PC: the movement stick from the touch layout, driven by WASD.
class WasdStick extends Control:
	var _off := Vector2.ZERO
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(d: float) -> void:
		var v := Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
			float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
		if PlayerController.pad_active():
			var pads := Input.get_connected_joypads()
			if not pads.is_empty():
				v = Vector2(Input.get_joy_axis(pads[0], JOY_AXIS_LEFT_X), Input.get_joy_axis(pads[0], JOY_AXIS_LEFT_Y))
		if v.length() > 1.0:
			v = v.normalized()
		_off = _off.lerp(v * size.x * 0.24, clampf(d * 14.0, 0.0, 1.0))
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		draw_texture_rect(AbilityReadout.tex("joy_base"), Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 0.85))
		var kr := size.x * 0.27
		draw_texture_rect(AbilityReadout.tex("joy_knob"), Rect2(c + _off - Vector2(kr, kr), Vector2(kr, kr) * 2.0), false)
		var f := UIKit.bold()
		var t := "L-STICK" if PlayerController.pad_active() else "WASD"
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string_outline(f, Vector2(c.x - w * 0.5, size.y + 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 6, UIKit.DARK)
		draw_string(f, Vector2(c.x - w * 0.5, size.y + 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

## PC: shows super charge and gadget cooldown with their key bindings.
class AbilityReadout extends Control:
	var game: Node
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	static var _tex := {}
	static func tex(n: String) -> Texture2D:
		if not _tex.has(n):
			_tex[n] = load("res://assets/ui/pc/%s.png" % n)
		return _tex[n]

	func _btn(n: String, c: Vector2, r: float, tint := Color.WHITE) -> void:
		draw_texture_rect(tex(n), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, tint)

	func _draw() -> void:
		var p: Brawler = game.player
		if p == null:
			return
		var f := UIKit.bold()
		# ---- attack (red): normal / pressed / out of ammo
		var ac := Vector2(62, 104)
		var firing := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		var an := "attack_empty" if p.ammo < 1.0 else ("attack_down" if firing else "attack")
		_btn(an, ac + (Vector2(0, 3) if firing else Vector2.ZERO), 50.0)
		for i in p.max_ammo:
			var a0 := PI * 1.13 + i * 0.37
			var fillk := clampf(p.ammo - i, 0.0, 1.0)
			draw_arc(ac, 58, a0, a0 + 0.31, 8, UIKit.DARK, 11.0, true)
			draw_arc(ac, 58, a0, a0 + 0.31 * fillk, 8, Color("ff9d2e"), 6.0, true)
		var pad := PlayerController.pad_active()
		_t2(f, "R2" if pad else "LMB", ac + Vector2(0, 70), 15)
		# ---- gadget (green): ready / pressed / cooldown or locked
		var gc := Vector2(172, 112)
		var gdown := Input.is_action_pressed("gadget")
		if not p.has_gadget:
			_btn("gadget_cd", gc, 44.0, Color(0.6, 0.6, 0.65))
			UIKit.draw_icon(self, "lock", gc + Vector2(20, 18), 36.0)
		elif p.gadget_cd > 0.0:
			_btn("gadget_cd", gc, 44.0)
			var cdk := 1.0 - p.gadget_cd / p.gadget_max_cd
			draw_arc(gc, 34, -PI / 2, -PI / 2 + TAU * cdk, 40, Color("6dff6a"), 6.0, true)
			_t2(f, str(int(ceil(p.gadget_cd))), gc + Vector2(0, 12), 28)
		else:
			_btn("gadget_down" if gdown else "gadget", gc + (Vector2(0, 3) if gdown else Vector2.ZERO), 44.0 * (1.0 + 0.04 * sin(_t * 5.0)))
		_t2(f, "R1" if pad else "RMB / Q", gc + Vector2(0, 66), 15)
		# ---- super (yellow skull): charging ring / ready (pulsing) / pressed
		var sc := Vector2(292, 92)
		var full := p.super_charge >= 1.0
		var sdown := Input.is_action_pressed("super")
		if full:
			for k in 3:
				draw_circle(sc, 62 + k * 7 + sin(_t * 6.0) * 3.0, Color(1, 0.8, 0.2, 0.10))
			var pulse := 1.0 + 0.05 * sin(_t * 8.0)
			_btn("super_down" if sdown else "super", sc + (Vector2(0, 3) if sdown else Vector2.ZERO), 60.0 * pulse)
		else:
			_btn("super_charging", sc, 60.0)
			draw_arc(sc, 50, -PI / 2, -PI / 2 + TAU * p.super_charge, 64, UIKit.DARK, 11.0, true)
			draw_arc(sc, 50, -PI / 2, -PI / 2 + TAU * p.super_charge, 64, Color("ffd23a"), 7.0, true)
		_t2(f, ("L2" if pad else "SPACE") if full else "%d%%" % int(p.super_charge * 100), sc + Vector2(0, 82), 16)

	func _t2(f: Font, s: String, cb: Vector2, size: int) -> void:
		var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		var p := cb - Vector2(sz.x * 0.5, 0)
		draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, UIKit.DARK)
		draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


## Shared look for the super button (PC readout + touch controls).
class SuperButtonArt:
	static func draw(ci: CanvasItem, c: Vector2, r: float, charge: float, icon_name: String, t: float) -> void:
		var full := charge >= 1.0
		if full:
			for k in 3:
				ci.draw_circle(c, r + 8 + k * 6 + sin(t * 6.0) * 3.0, Color(1, 0.85, 0.2, 0.12))
		ci.draw_circle(c + Vector2(0, 5), r + 4, Color(0, 0, 0, 0.3))
		ci.draw_circle(c, r + 4, UIKit.DARK)
		ci.draw_circle(c, r, Color("2b2f4a"))
		ci.draw_arc(c, r - 4, -PI / 2, -PI / 2 + TAU * charge, 64, Color("ffd23a"), 8.0, true)
		var inner := r - 12
		ci.draw_circle(c, inner, Color("3a7be0") if full else Color("4a5570"))
		ci.draw_circle(c + Vector2(0, -inner * 0.35), inner * 0.62, Color(1, 1, 1, 0.12))
		UIKit.draw_icon(ci, icon_name, c, inner * 1.55, Color.WHITE if full else Color(0.75, 0.75, 0.8, 0.85))
