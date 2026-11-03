extends Control
## Main menu: bright lobby with the selected brawler in 3D centre stage, profile
## and trophy bar on top, menu buttons on the left, level progress bottom-left,
## mode panel bottom-centre and a big PLAY button bottom-right.

var _view: BrawlerView
var _stage: Control
var _yaw := 0.35
var _dragging := false
var _drag_moved := 0.0
var _spin_back := 0.0
var _mode_panel: SlantButton
var _bots_btn: SlantButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	Sfx.play_music("music_menu")
	add_child(LobbyBackground.new())

	_build_stage()
	_build_top_bar()
	_build_left_buttons()
	_build_level_panel()
	_build_mode_panel()
	_build_play()

# ------------------------------------------------------------------ centre stage
func _build_stage() -> void:
	var id: String = Save.data.selected_brawler
	var d: Dictionary = Config.BRAWLERS[id]
	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_CENTER)
	_stage.custom_minimum_size = Vector2(520, 520)
	_stage.size = Vector2(520, 520)
	_stage.position = Vector2(-260, -226)
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.gui_input.connect(_stage_input)
	add_child(_stage)
	var floor_shadow := StageShadow.new()
	floor_shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(floor_shadow)
	_view = BrawlerView.create(id, "showcase", 720)
	_view.state = {"yaw": _yaw, "manual": true}
	_stage.add_child(_view)
	var tr := TextureRect.new()
	tr.texture = _view.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(tr)
	# rank / trophies / power badge above the head
	var badge := BrawlerBadge.new()
	badge.brawler_id = id
	badge.set_anchors_preset(Control.PRESET_CENTER_TOP)
	badge.custom_minimum_size = Vector2(330, 90)
	badge.position = Vector2(-165, 112)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	# pop-in
	tr.pivot_offset = Vector2(260, 420)
	tr.scale = Vector2(0.6, 0.6)
	create_tween().tween_property(tr, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_moved = 0.0
		else:
			_dragging = false
			if _drag_moved < 8.0:
				Sfx.play("ui_click")
				Router.goto("select")
			_spin_back = 1.5
	elif event is InputEventMouseMotion and _dragging:
		_yaw += event.relative.x * 0.012
		_drag_moved += absf(event.relative.x) + absf(event.relative.y)

func _process(delta: float) -> void:
	if not _dragging:
		_spin_back -= delta
		if _spin_back <= 0.0:
			_yaw = lerp_angle(_yaw, 0.35, delta * 2.0)
	if _view:
		_view.state = {"yaw": _yaw + (0.0 if _dragging else sin(Time.get_ticks_msec() / 1600.0) * 0.12), "manual": true}

# ------------------------------------------------------------------ top bar
func _build_top_bar() -> void:
	# profile tile
	var prof := SlantButton.new()
	prof.color = Color("27334d")
	prof.position = Vector2(14, 10)
	prof.size = Vector2(200, 92)
	prof.custom_draw = func(ci: Control):
		var r := Rect2(Vector2(70, 8), Vector2(62, 52))
		ci.draw_rect(r.grow(3), UIKit.DARK)
		ci.draw_rect(r, Color("2a8cff"))
		Gem.draw_gem_icon(ci, r.get_center(), 18.0, Time.get_ticks_msec() / 1000.0)
		SlantButton.text_c(ci, Save.data.username, Vector2(100, 84), 18, Color.WHITE)
	prof.name = "ProfileTile"
	prof.pressed.connect(func(): Router.goto("profile"))
	add_child(prof)

	# trophy / level bar with the yellow profile button
	var bar := SlantButton.new()
	bar.color = Color("27334d")
	bar.position = Vector2(226, 10)
	bar.size = Vector2(440, 92)
	bar.custom_draw = func(ci: Control):
		SlantButton.hexagon(ci, Vector2(58, 44), 30.0, Color("4c5a7a"), str(Save.account_level()))
		var ic := Vector2(112, 34)
		SlantButton.trophy(ci, ic, 17.0)
		SlantButton.text_l(ci, str(Save.total_trophies()), Vector2(134, 50), 30, UIKit.YELLOW)
		# progress to the next 100-trophy milestone
		var tt := Save.total_trophies()
		var goal := (tt / 100 + 1) * 100
		var br := Rect2(Vector2(96, 62), Vector2(210, 16))
		ci.draw_rect(br.grow(3), UIKit.DARK)
		ci.draw_rect(br, Color("1d2438"))
		ci.draw_rect(Rect2(br.position, Vector2(br.size.x * float(tt % 100) / 100.0, br.size.y)), Color("ff8a2a"))
		SlantButton.text_c(ci, "%d / %d" % [tt, goal], br.get_center() + Vector2(0, 6), 13, Color.WHITE)
		# yellow square
		var y := PackedVector2Array([Vector2(330, 0), Vector2(440, 0), Vector2(428, 92), Vector2(318, 92)])
		ci.draw_colored_polygon(y, UIKit.YELLOW)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(330, 0), Vector2(440, 0), Vector2(438, 14), Vector2(328, 14)]), Color("ffe680"))
		SlantButton.star(ci, Vector2(379, 44), 24.0)
	bar.pressed.connect(func(): Router.goto("profile"))
	add_child(bar)

	# credits + menu (settings)
	var credits := SlantButton.new()
	credits.color = Color(0, 0, 0, 0.7)
	credits.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	credits.position = Vector2(-330, 14)
	credits.size = Vector2(200, 58)
	credits.interactive = false
	credits.custom_draw = func(ci: Control):
		SlantButton.coin(ci, Vector2(34, 29), 20.0)
		SlantButton.text_l(ci, str(Save.data.credits), Vector2(66, 41), 30, Color.WHITE)
	add_child(credits)
	var menu := SlantButton.new()
	menu.color = Color("27334d")
	menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu.position = Vector2(-116, 10)
	menu.size = Vector2(100, 70)
	menu.custom_draw = func(ci: Control):
		for i in 3:
			var r := Rect2(Vector2(28, 18 + i * 13), Vector2(46, 8))
			ci.draw_rect(r.grow(2), UIKit.DARK)
			ci.draw_rect(r, Color.WHITE)
	menu.name = "Settings"
	menu.pressed.connect(_open_settings)
	add_child(menu)

# ------------------------------------------------------------------ left
func _build_left_buttons() -> void:
	var items := [
		["BRAWLERS", "brawlers", func(): Router.goto("select")],
		["PROFILE", "profile", func(): Router.goto("profile")],
		["GUIDE", "guide", _open_how_to],
	]
	for i in items.size():
		var it: Array = items[i]
		var b := SlantButton.new()
		b.color = Color("27334d")
		b.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		b.position = Vector2(22, -120 + i * 118)
		b.size = Vector2(160, 104)
		var icon_kind: String = it[1]
		var label: String = it[0]
		b.custom_draw = func(ci: Control):
			SlantButton.menu_icon(ci, icon_kind, Vector2(80, 40))
			SlantButton.text_c(ci, label, Vector2(80, 92), 21, Color.WHITE)
		b.name = label.capitalize()
		b.pressed.connect(it[2])
		add_child(b)

# ------------------------------------------------------------------ bottom-left level panel
func _build_level_panel() -> void:
	var lv := SlantButton.new()
	lv.color = UIKit.YELLOW
	lv.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lv.position = Vector2(18, -132)
	lv.size = Vector2(400, 116)
	lv.custom_draw = func(ci: Control):
		var prog := Save.level_progress()
		SlantButton.text_l(ci, "LEVEL ROAD", Vector2(24, 40), 28, Color.WHITE)
		var br := Rect2(Vector2(60, 62), Vector2(236, 34))
		ci.draw_rect(br.grow(3), UIKit.DARK)
		ci.draw_rect(br, Color("6b5a2a"))
		ci.draw_rect(Rect2(br.position, Vector2(br.size.x * float(prog.x) / prog.y, br.size.y)), Color("ffb02e"))
		SlantButton.text_c(ci, "%d/%d" % [prog.x, prog.y], br.get_center() + Vector2(0, 10), 22, Color.WHITE)
		SlantButton.hexagon(ci, Vector2(36, 79), 26.0, Color("27334d"), "XP")
		ci.draw_circle(Vector2(336, 79), 36, UIKit.DARK)
		ci.draw_circle(Vector2(336, 79), 31, Color("5a4a1e"))
		SlantButton.text_c(ci, str(Save.account_level()), Vector2(336, 92), 34, Color.WHITE)
	lv.pressed.connect(func(): Router.goto("profile"))
	add_child(lv)

# ------------------------------------------------------------------ bottom-centre mode panel
func _build_mode_panel() -> void:
	_bots_btn = SlantButton.new()
	_bots_btn.color = Color(0, 0, 0, 0.55)
	_bots_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bots_btn.position = Vector2(-160, -170)
	_bots_btn.size = Vector2(370, 36)
	_bots_btn.custom_draw = func(ci: Control):
		var dn: String = Config.DIFFICULTY[Save.setting("difficulty")].name
		SlantButton.text_r(ci, "BOTS: %s   (tap to change)" % dn, Vector2(350, 26), 16, Color("8fd0ff"))
	_bots_btn.pressed.connect(func():
		var order: Array = Config.DIFFICULTY_ORDER
		var i := order.find(Save.setting("difficulty"))
		Save.set_setting("difficulty", order[(i + 1) % order.size()])
		_bots_btn.queue_redraw())
	add_child(_bots_btn)

	_mode_panel = SlantButton.new()
	_mode_panel.color = Color("27334d")
	_mode_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_mode_panel.position = Vector2(-198, -136)
	_mode_panel.size = Vector2(430, 120)
	_mode_panel.custom_draw = func(ci: Control):
		var mid: String = Save.data.selected_mode
		var m: Dictionary = Config.MODES[mid]
		var maps: Array = m.maps
		# mode icon
		ci.draw_circle(Vector2(70, 60), 44, UIKit.DARK)
		ci.draw_circle(Vector2(70, 60), 39, m.color)
		if mid == "gem_grab":
			Gem.draw_gem_icon(ci, Vector2(70, 60), 26.0, Time.get_ticks_msec() / 1000.0)
		else:
			SlantButton.menu_icon(ci, "swords", Vector2(70, 60))
		SlantButton.text_l(ci, m.name, Vector2(126, 56), 27, Color.WHITE)
		SlantButton.text_l(ci, "%d arenas  ·  tap to switch" % maps.size(), Vector2(128, 90), 16, Color("9dff8a"))
		# cycle arrow
		var ar := Rect2(Vector2(368, 34), Vector2(40, 50))
		ci.draw_rect(ar.grow(3), UIKit.DARK)
		ci.draw_rect(ar, Color.WHITE)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(380, 47), Vector2(400, 59), Vector2(380, 71)]), UIKit.DARK)
	_mode_panel.name = "Mode"
	_mode_panel.pressed.connect(func():
		var keys := Config.MODES.keys()
		var i := keys.find(Save.data.selected_mode)
		Save.data.selected_mode = keys[(i + 1) % keys.size()]
		Save.save_game()
		_mode_panel.queue_redraw())
	add_child(_mode_panel)

	var info := SlantButton.new()
	info.color = Color("2a8cff")
	info.circle = true
	info.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	info.position = Vector2(-226, -160)
	info.size = Vector2(52, 52)
	info.custom_draw = func(ci: Control):
		SlantButton.text_c(ci, "i", Vector2(26, 38), 30, Color.WHITE)
	info.pressed.connect(_open_mode_info)
	add_child(info)

# ------------------------------------------------------------------ PLAY
func _build_play() -> void:
	var play := SlantButton.new()
	play.color = UIKit.YELLOW
	play.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	play.position = Vector2(-392, -150)
	play.size = Vector2(372, 132)
	play.custom_draw = func(ci: Control):
		SlantButton.text_c(ci, "PLAY", Vector2(186, 88), 66, Color.WHITE, 14)
	play.name = "Play"
	play.pressed.connect(func():
		Sfx.play("ui_confirm")
		Router.goto("match", {"mode": Save.data.selected_mode, "brawler": Save.data.selected_brawler}))
	add_child(play)
	# idle pulse to draw the eye
	var tw := create_tween().set_loops()
	tw.tween_property(play, "scale", Vector2(1.03, 1.03), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(play, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	play.pivot_offset = play.size * 0.5

# ------------------------------------------------------------------ overlays
func _open_settings() -> void:
	var s := SettingsPanel.new()
	s.closed.connect(func(): if _bots_btn: _bots_btn.queue_redraw())
	add_child(s)

func _overlay(title: String) -> VBoxContainer:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.14, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(c)
	var p := UIKit.panel(Color("27334d"))
	p.custom_minimum_size = Vector2(760, 0)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UIKit.label(title, 38, UIKit.YELLOW, 10, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(o)
	v.set_meta("overlay", o)
	return v

func _close_button(v: VBoxContainer) -> void:
	var close := UIKit.button("GOT IT", UIKit.GREEN, 24, Vector2(300, 58))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect((v.get_meta("overlay") as Node).queue_free)
	v.add_child(close)

func _open_mode_info() -> void:
	var m: Dictionary = Config.MODES[Save.data.selected_mode]
	var v := _overlay(m.name)
	v.add_child(UIKit.body(m.rules, 18))
	_close_button(v)

func _open_how_to() -> void:
	var v := _overlay("HOW TO PLAY")
	var lines := [
		"PC — WASD to move, aim with the mouse, LEFT CLICK to attack (hold to keep firing).",
		"RIGHT CLICK or Q uses your GADGET. Hold SPACE to preview your SUPER, release to unleash it.",
		"MOBILE — left side moves. Drag the orange stick to aim and release to fire; quick-tap to auto-aim. The yellow stick is your SUPER, the green button your GADGET.",
		"Ammo reloads on its own. Land hits to charge your SUPER. Stay out of fights for 3 seconds to regenerate health.",
		"Hide in BUSHES to vanish from enemies — unless they get close or you attack. Shots can't pass walls, but lobbed throws can. Crates can be smashed.",
		"Tip: drag your brawler in the lobby to spin them around. Tap them to change brawler.",
	]
	for line in lines:
		v.add_child(UIKit.body("•  " + line, 17))
	_close_button(v)


# ====================================================================== widgets
## Chunky slanted lobby button with bevel, ink outline and press bounce.
class SlantButton extends Button:
	var color := Color("27334d")
	var custom_draw: Callable
	var interactive := true
	var circle := false
	const SLANT := 10.0

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		text = ""
		custom_minimum_size = size
		add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		if not interactive:
			mouse_filter = Control.MOUSE_FILTER_IGNORE
			return
		pivot_offset = size * 0.5
		pressed.connect(func(): Sfx.play("ui_click", -2.0, 0.04))
		button_down.connect(func(): _pop(0.93))
		button_up.connect(func(): _pop(1.0))
		mouse_entered.connect(func(): _pop(1.04))
		mouse_exited.connect(func(): _pop(1.0))

	func _pop(s: float) -> void:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(s, s), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if circle:
			draw_circle(Vector2(w, h) * 0.5 + Vector2(0, 3), w * 0.5, Color(0, 0, 0, 0.35))
			draw_circle(Vector2(w, h) * 0.5, w * 0.5, UIKit.DARK)
			draw_circle(Vector2(w, h) * 0.5, w * 0.5 - 4, color)
		else:
			var s := SLANT
			var shadow := PackedVector2Array([Vector2(s, 6), Vector2(w, 6), Vector2(w - s, h + 6), Vector2(0, h + 6)])
			draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
			var outer := PackedVector2Array([Vector2(s, 0), Vector2(w, 0), Vector2(w - s, h), Vector2(0, h)])
			draw_colored_polygon(outer, UIKit.DARK)
			var inset := 4.0
			var inner := PackedVector2Array([Vector2(s + inset, inset), Vector2(w - inset, inset), Vector2(w - s - inset, h - inset - 5), Vector2(inset, h - inset - 5)])
			draw_colored_polygon(inner, color)
			if color.a > 0.9:
				var hi := color.lightened(0.18)
				draw_colored_polygon(PackedVector2Array([inner[0], inner[1], inner[1] + Vector2(-1, 8), inner[0] + Vector2(-1, 8)]), hi)
				var lo := color.darkened(0.25)
				draw_colored_polygon(PackedVector2Array([Vector2(inset, h - inset - 5), Vector2(w - s - inset, h - inset - 5), Vector2(w - s - inset, h - inset), Vector2(inset, h - inset)]), lo)
		if custom_draw.is_valid():
			custom_draw.call(self)

	# ---- drawing helpers shared by the lobby widgets
	static func text_c(ci: CanvasItem, s: String, center_baseline: Vector2, size: int, col: Color, outline := 0) -> void:
		var f := UIKit.bold()
		var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		_text(ci, f, s, center_baseline - Vector2(sz.x * 0.5, 0), size, col, outline)

	static func text_l(ci: CanvasItem, s: String, baseline: Vector2, size: int, col: Color) -> void:
		_text(ci, UIKit.bold(), s, baseline, size, col, 0)

	static func text_r(ci: CanvasItem, s: String, baseline_right: Vector2, size: int, col: Color) -> void:
		var f := UIKit.bold()
		var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		_text(ci, f, s, baseline_right - Vector2(sz.x, 0), size, col, 0)

	static func _text(ci: CanvasItem, f: Font, s: String, p: Vector2, size: int, col: Color, outline: int) -> void:
		var o: int = outline if outline > 0 else maxi(6, size / 4)
		ci.draw_string_outline(f, p + Vector2(0, maxi(2, size / 12)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, o, UIKit.DARK)
		ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, o, UIKit.DARK)
		ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

	static func hexagon(ci: CanvasItem, c: Vector2, r: float, col: Color, label: String) -> void:
		var pts := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in 6:
			var a := -PI / 2 + i * TAU / 6
			pts.append(c + Vector2(cos(a), sin(a)) * r)
			inner.append(c + Vector2(cos(a), sin(a)) * (r - 4))
		ci.draw_colored_polygon(pts, UIKit.DARK)
		ci.draw_colored_polygon(inner, col)
		text_c(ci, label, c + Vector2(0, r * 0.32), int(r * 0.85), Color.WHITE)

	static func trophy(ci: CanvasItem, c: Vector2, r: float) -> void:
		var gold := Color("ffb52e")
		var cup := PackedVector2Array([c + Vector2(-r, -r * 0.8), c + Vector2(r, -r * 0.8), c + Vector2(r * 0.7, r * 0.2), c + Vector2(-r * 0.7, r * 0.2)])
		ci.draw_arc(c + Vector2(-r * 0.95, -r * 0.35), r * 0.38, PI * 0.5, PI * 1.5, 10, UIKit.DARK, 6.0, true)
		ci.draw_arc(c + Vector2(r * 0.95, -r * 0.35), r * 0.38, -PI * 0.5, PI * 0.5, 10, UIKit.DARK, 6.0, true)
		ci.draw_arc(c + Vector2(-r * 0.95, -r * 0.35), r * 0.38, PI * 0.5, PI * 1.5, 10, gold, 3.0, true)
		ci.draw_arc(c + Vector2(r * 0.95, -r * 0.35), r * 0.38, -PI * 0.5, PI * 0.5, 10, gold, 3.0, true)
		ci.draw_colored_polygon(cup, gold)
		var o := cup.duplicate()
		o.append(cup[0])
		ci.draw_polyline(o, UIKit.DARK, 3.0, true)
		ci.draw_rect(Rect2(c + Vector2(-r * 0.2, r * 0.2), Vector2(r * 0.4, r * 0.4)), gold.darkened(0.2))
		ci.draw_rect(Rect2(c + Vector2(-r * 0.6, r * 0.55), Vector2(r * 1.2, r * 0.35)), gold.darkened(0.3))
		ci.draw_rect(Rect2(c + Vector2(-r * 0.6, r * 0.55), Vector2(r * 1.2, r * 0.35)), UIKit.DARK, false, 2.0)
		ci.draw_circle(c + Vector2(-r * 0.45, -r * 0.45), r * 0.15, Color(1, 1, 1, 0.8))

	static func coin(ci: CanvasItem, c: Vector2, r: float) -> void:
		ci.draw_circle(c, r + 3, UIKit.DARK)
		ci.draw_circle(c, r, Color("ffb52e"))
		ci.draw_circle(c, r * 0.72, Color("ffd23a"))
		ci.draw_rect(Rect2(c + Vector2(-r * 0.14, -r * 0.42), Vector2(r * 0.28, r * 0.84)), Color("e08a1a"))
		ci.draw_circle(c + Vector2(-r * 0.4, -r * 0.42), r * 0.14, Color(1, 1, 1, 0.8))

	static func star(ci: CanvasItem, c: Vector2, r: float) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var rr := r if i % 2 == 0 else r * 0.45
			var a := -PI / 2 + i * PI / 5
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		ci.draw_colored_polygon(pts, Color.WHITE)
		pts.append(pts[0])
		ci.draw_polyline(pts, UIKit.DARK, 4.0, true)

	static func menu_icon(ci: CanvasItem, kind: String, c: Vector2) -> void:
		match kind:
			"brawlers":
				var cols := [Color("8e4dff"), Color("ff7bc2"), Color("e9893a")]
				for i in 3:
					var p := c + Vector2(-22 + i * 22, (2 - abs(i - 1) * 6))
					var r := Rect2(p - Vector2(15, 17), Vector2(30, 34))
					ci.draw_rect(r.grow(3), UIKit.DARK)
					ci.draw_rect(r, cols[i])
					ci.draw_circle(p + Vector2(-6, -3), 4, Color.WHITE)
					ci.draw_circle(p + Vector2(6, -3), 4, Color.WHITE)
					ci.draw_circle(p + Vector2(-6, -2), 2, UIKit.DARK)
					ci.draw_circle(p + Vector2(6, -2), 2, UIKit.DARK)
					ci.draw_line(p + Vector2(-5, 8), p + Vector2(5, 8), UIKit.DARK, 2.5)
			"profile":
				ci.draw_circle(c, 30, UIKit.DARK)
				ci.draw_circle(c, 26, Color("2a8cff"))
				ci.draw_circle(c + Vector2(0, -7), 10, Color.WHITE)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 18), c + Vector2(-12, 5), c + Vector2(12, 5), c + Vector2(16, 18)]), Color.WHITE)
			"guide":
				var r := Rect2(c - Vector2(26, 22), Vector2(52, 44))
				ci.draw_rect(r.grow(3), UIKit.DARK)
				ci.draw_rect(r, Color("dff4ff"))
				for i in 3:
					ci.draw_line(r.position + Vector2(8, 12 + i * 10), r.position + Vector2(44, 12 + i * 10), Color("2a8cff"), 4.0)
				ci.draw_circle(r.end - Vector2(2, 2), 12, UIKit.DARK)
				ci.draw_circle(r.end - Vector2(2, 2), 9, Color("4fd36a"))
				text_c(ci, "?", r.end + Vector2(-2, 5), 16, Color.WHITE)
			"swords":
				for sgn in [-1.0, 1.0]:
					var a := c + Vector2(-18 * sgn, 18)
					var b := c + Vector2(16 * sgn, -18)
					ci.draw_line(a, b, UIKit.DARK, 11.0, true)
					ci.draw_line(a, b, Color.WHITE, 6.0, true)
					var g := a.lerp(b, 0.25)
					var perp := (b - a).normalized().orthogonal() * 9.0
					ci.draw_line(g - perp, g + perp, UIKit.DARK, 6.0, true)


## Rank shield, brawler trophies and power level, shown above the lobby brawler.
class BrawlerBadge extends Control:
	var brawler_id := "bront"

	func _draw() -> void:
		var bt := Save.brawler_trophies(brawler_id)
		var rank := 1 + bt / 25
		var lvl := Save.brawler_level(brawler_id)
		# trophy ribbon
		var rib := PackedVector2Array([Vector2(70, 26), Vector2(270, 26), Vector2(262, 68), Vector2(62, 68)])
		draw_colored_polygon(rib, UIKit.DARK)
		draw_colored_polygon(PackedVector2Array([Vector2(74, 30), Vector2(266, 30), Vector2(259, 64), Vector2(66, 64)]), Color("6b2a5a"))
		draw_colored_polygon(PackedVector2Array([Vector2(74, 30), Vector2(150, 30), Vector2(143, 64), Vector2(66, 64)]), Color("ff7a2b"))
		SlantButton.trophy(self, Vector2(168, 47), 12.0)
		SlantButton.text_l(self, str(bt), Vector2(188, 60), 28, Color.WHITE)
		# rank shield
		var c := Vector2(48, 46)
		var sh := PackedVector2Array([c + Vector2(-36, -38), c + Vector2(36, -38), c + Vector2(36, 12), c + Vector2(0, 42), c + Vector2(-36, 12)])
		draw_colored_polygon(sh, UIKit.DARK)
		var sh2 := PackedVector2Array([c + Vector2(-30, -32), c + Vector2(30, -32), c + Vector2(30, 9), c + Vector2(0, 35), c + Vector2(-30, 9)])
		draw_colored_polygon(sh2, Color("5a5f8a"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-30, -32), c + Vector2(30, -32), c + Vector2(30, -14), c + Vector2(-30, -14)]), Color("e8ecff"))
		SlantButton.text_c(self, "RANK", c + Vector2(0, -17), 14, UIKit.DARK, 1)
		SlantButton.text_c(self, str(rank), c + Vector2(0, 22), 30, Color.WHITE)
		# power hex
		var pc := Vector2(292, 46)
		var pts := PackedVector2Array()
		var pts2 := PackedVector2Array()
		for i in 6:
			var a := -PI / 2 + i * TAU / 6
			pts.append(pc + Vector2(cos(a), sin(a)) * 36)
			pts2.append(pc + Vector2(cos(a), sin(a)) * 30)
		draw_colored_polygon(pts, Color("ffb52e"))
		draw_colored_polygon(pts2, UIKit.DARK)
		SlantButton.text_c(self, "POWER", pc + Vector2(0, -38), 14, Color.WHITE)
		SlantButton.text_c(self, str(lvl), pc + Vector2(0, 14), 36, Color.WHITE)


## Soft oval floor shadow under the lobby brawler.
class StageShadow extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.86)
		for i in 6:
			var k := 1.0 - i / 6.0
			var pts := PackedVector2Array()
			for j in 32:
				var a := TAU * j / 32.0
				pts.append(c + Vector2(cos(a) * 150 * k, sin(a) * 26 * k))
			draw_colored_polygon(pts, Color(0.02, 0.15, 0.3, 0.08))


## Bright lobby backdrop: radial sky gradient with drifting star and gem shapes.
class LobbyBackground extends Control:
	var _t := 0.0
	var _shapes: Array = []

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		for i in 26:
			_shapes.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(22, 46), rng.randf() * TAU, rng.randi() % 2, rng.randf_range(-0.3, 0.3)])

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var outer := Color("0d86e8")
		var inner := Color("6ff0ff")
		draw_rect(Rect2(Vector2.ZERO, size), outer)
		var c := size * Vector2(0.5, 0.45)
		var maxr := size.length() * 0.62
		var steps := 30
		for i in steps:
			var k := float(i) / steps
			draw_circle(c, maxr * (1.0 - k), outer.lerp(inner, pow(k, 1.4)))
		for s in _shapes:
			var p: Vector2 = s[0]
			var pos := Vector2(fmod(p.x + _t * 0.006, 1.0) * size.x, fmod(p.y + _t * 0.01, 1.0) * size.y)
			var r: float = s[1]
			var rot: float = s[2] + _t * float(s[4])
			var col := Color(1, 1, 1, 0.13)
			if s[3] == 0:
				var pts := PackedVector2Array()
				for i in 10:
					var rr := r if i % 2 == 0 else r * 0.45
					var a := rot + i * PI / 5
					pts.append(pos + Vector2(cos(a), sin(a)) * rr)
				draw_colored_polygon(pts, col)
			else:
				var pts2 := PackedVector2Array([pos + Vector2(0, -r).rotated(rot), pos + Vector2(r * 0.75, 0).rotated(rot), pos + Vector2(0, r).rotated(rot), pos + Vector2(-r * 0.75, 0).rotated(rot)])
				draw_colored_polygon(pts2, col)
