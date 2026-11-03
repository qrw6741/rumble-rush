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
	_board.custom_minimum_size = Vector2(460, 96)
	_board.position = Vector2(-230, 8)
	add_child(_board)

	pause_button = UIKit.button("II", UIKit.PANEL_LIGHT, 24, Vector2(64, 58))
	pause_button.position = Vector2(14, 12)
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

	_hint = UIKit.label("WASD move  ·  Mouse aim  ·  LMB attack  ·  RMB / Q gadget  ·  Hold SPACE super  ·  ESC pause", 14, Color(1, 1, 1, 0.75), 5)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(16, -34)
	add_child(_hint)

	_abilities = AbilityReadout.new()
	_abilities.game = game
	_abilities.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_abilities.custom_minimum_size = Vector2(250, 120)
	_abilities.position = Vector2(-266, -136)
	add_child(_abilities)

	_fps = UIKit.label("", 14, Color(1, 1, 1, 0.6), 4)
	_fps.position = Vector2(90, 20)
	add_child(_fps)

func set_touch_mode(on: bool) -> void:
	_hint.visible = not on
	_abilities.visible = not on

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
	var kc: Color = Config.TEAM_COLORS[killer.team] if killer else Color.WHITE
	var kname := (killer.display_name if killer else "Zone")
	var k := UIKit.label(kname, 16, kc.lightened(0.3), 5)
	var mid := UIKit.label(" » ", 18, Color("ffd23a"), 5)
	var v := UIKit.label(victim.display_name, 16, Config.TEAM_COLORS[victim.team].lightened(0.3), 5)
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

func _process(delta: float) -> void:
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
		var my_col: Color = Config.TEAM_COLORS[view]
		var their_col: Color = Config.TEAM_COLORS[1 - view]
		var mine: int = h.blue if view == 0 else h.red
		var theirs: int = h.red if view == 0 else h.blue
		# clock
		var tl: float = max(0.0, game.time_left)
		var clock := "%d:%02d" % [int(tl) / 60, int(tl) % 60]
		var clock_col := Color.WHITE if tl > 10.0 else Color("ff6b6b")
		_pill(Rect2(mid - 62, 0, 124, 44), Color(0, 0, 0, 0.55))
		_text(f, clock, Vector2(mid, 32), 28, clock_col)
		# team panels
		_pill(Rect2(mid - 210, 6, 140, 54), my_col.darkened(0.25))
		_pill(Rect2(mid + 70, 6, 140, 54), their_col.darkened(0.25))
		if h.kind == "gem":
			Gem.draw_gem_icon(self, Vector2(mid - 175, 33), 13.0, _t)
			Gem.draw_gem_icon(self, Vector2(mid + 105, 33), 13.0, _t)
			_text(f, str(mine), Vector2(mid - 118, 46), 34, Color.WHITE)
			_text(f, str(theirs), Vector2(mid + 160, 46), 34, Color.WHITE)
			# progress to 10
			_bar(Rect2(mid - 205, 64, 130, 8), clampf(float(mine) / h.target, 0, 1), my_col)
			_bar(Rect2(mid + 75, 64, 130, 8), clampf(float(theirs) / h.target, 0, 1), their_col)
			if h.countdown_team != -1:
				var cc: Color = Config.TEAM_COLORS[h.countdown_team]
				var sc := 1.0 + 0.08 * sin(_t * 10.0)
				_pill(Rect2(mid - 54, 48, 108, 46), cc.darkened(0.2))
				draw_set_transform(Vector2(mid, 84), 0, Vector2(sc, sc))
				_text(f, str(int(ceil(h.countdown))), Vector2.ZERO, 34, Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		else:
			_text(f, str(mine), Vector2(mid - 140, 47), 36, Color.WHITE)
			_text(f, str(theirs), Vector2(mid + 140, 47), 36, Color.WHITE)
			_bar(Rect2(mid - 205, 64, 130, 8), clampf(float(mine) / h.target, 0, 1), my_col)
			_bar(Rect2(mid + 75, 64, 130, 8), clampf(float(theirs) / h.target, 0, 1), their_col)
			if h.overtime:
				_pill(Rect2(mid - 80, 48, 160, 34), Color("ffd23a").darkened(0.2))
				_text(f, "SUDDEN DEATH", Vector2(mid, 72), 16, Color.WHITE)

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


## PC: shows super charge and gadget cooldown with their key bindings.
class AbilityReadout extends Control:
	var game: Node
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var p: Brawler = game.player
		if p == null:
			return
		var f := UIKit.bold()
		# gadget
		var gc := Vector2(60, 64)
		var cd := p.gadget_cd / p.gadget_max_cd
		draw_circle(gc, 40, UIKit.DARK)
		draw_circle(gc, 36, Color("4fd36a") if cd <= 0.0 else Color(0.2, 0.3, 0.24))
		if cd > 0.0:
			draw_arc(gc, 32, -PI / 2, -PI / 2 + TAU * (1.0 - cd), 36, Color("4fd36a"), 6.0, true)
			_t2(f, str(int(ceil(p.gadget_cd))), gc + Vector2(0, 10), 26)
		else:
			_t2(f, "G", gc + Vector2(0, 10), 26)
		_t2(f, "RMB/Q", gc + Vector2(0, 58), 14)
		# super
		var sc := Vector2(170, 56)
		var full := p.super_charge >= 1.0
		var pulse := 1.0 + (0.06 * sin(_t * 8.0) if full else 0.0)
		draw_circle(sc, 50 * pulse, UIKit.DARK)
		draw_circle(sc, 46 * pulse, Color("ffd23a") if full else Color(0.25, 0.18, 0.1))
		draw_arc(sc, 40, -PI / 2, -PI / 2 + TAU * p.super_charge, 48, Color("ffd23a"), 8.0, true)
		var bolt := PackedVector2Array([sc + Vector2(5, -24), sc + Vector2(-12, 4), sc + Vector2(-1, 4), sc + Vector2(-6, 24), sc + Vector2(12, -5), sc + Vector2(1, -5)])
		draw_colored_polygon(bolt, UIKit.DARK if full else Color(1, 0.82, 0.25, 0.6))
		_t2(f, "SPACE", sc + Vector2(0, 66), 14)

	func _t2(f: Font, s: String, cb: Vector2, size: int) -> void:
		var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		var p := cb - Vector2(sz.x * 0.5, 0)
		draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, UIKit.DARK)
		draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)
