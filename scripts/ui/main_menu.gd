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
	_animate_in()

func _animate_in() -> void:
	var i := 0
	for n in ["ProfileTile", "TrophyRoad", "Settings"]:
		UIKit.pop_in(find_child(n, false, false), 0.03 * i, Vector2(0, -40))
		i += 1
	i = 0
	for n in ["Brawlers", "Profile", "Guide"]:
		UIKit.pop_in(find_child(n, false, false), 0.08 + 0.06 * i, Vector2(-60, 0))
		i += 1
	UIKit.pop_in(find_child("RushPass", false, false), 0.15, Vector2(0, 60))
	UIKit.pop_in(find_child("Mode", false, false), 0.2, Vector2(0, 60))

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
	var tr: Control
	if Save.setting("view_mode") == "2d":
		# 2D brawler view: big animated 2D art on the lobby stage
		var pt := UIKit.BrawlerPortrait.new()
		pt.brawler_id = id
		pt.backdrop = false
		pt.view_kind = "showcase"
		pt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pt.offset_top = 96
		pt.offset_bottom = -118
		tr = pt
	else:
		_view = BrawlerView.create(id, "showcase", 720, true, Save.selected_skin(id))
		_view.state = {"yaw": _yaw, "manual": true}
		_stage.add_child(_view)
		var trr := TextureRect.new()
		trr.texture = _view.get_texture()
		trr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		trr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		trr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr = trr
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
		SlantButton.text_l(ci, Save.data.username, Vector2(84, 42), 20, Color.WHITE)
		SlantButton.text_l(ci, Save.title_name(Save.data.get("profile_title", "rookie")), Vector2(84, 68), 12, Color("ffb84d"))
	prof.name = "ProfileTile"
	var pic := UIKit.ProfileIcon.new()
	pic.custom_minimum_size = Vector2(66, 66)
	pic.size = Vector2(66, 66)
	pic.position = Vector2(12, 12)
	prof.add_child(pic)
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
		# road button: bright yellow only while a Trophy Road reward is waiting
		var road_ready := Save.road_unclaimed() > 0
		var yc := UIKit.YELLOW if road_ready else Color("3a4a70")
		var y := PackedVector2Array([Vector2(330, 4), Vector2(436, 4), Vector2(424, 88), Vector2(318, 88)])
		ci.draw_colored_polygon(y, yc)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(330, 4), Vector2(436, 4), Vector2(434, 16), Vector2(328, 16)]), yc.lightened(0.3))
		SlantButton.text_c(ci, "TROPHY", Vector2(377, 42), 22, Color.WHITE)
		SlantButton.text_c(ci, "ROAD", Vector2(377, 70), 22, Color.WHITE)
	bar.name = "TrophyRoad"
	bar.pressed.connect(func(): Router.goto("road"))
	add_child(bar)
	_dot(bar, Save.road_unclaimed(), Vector2(414, -12))

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
	var gems := SlantButton.new()
	gems.color = Color(0, 0, 0, 0.7)
	gems.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gems.position = Vector2(-520, 14)
	gems.size = Vector2(180, 58)
	gems.custom_draw = func(ci: Control):
		UIKit.draw_icon(ci, "gem", Vector2(34, 29), 46.0)
		SlantButton.text_l(ci, str(Save.data.gems), Vector2(62, 41), 30, Color.WHITE)
	gems.name = "Gems"
	gems.pressed.connect(func(): Router.goto("shop"))
	add_child(gems)
	var menu := SlantButton.new()
	menu.color = Color("27334d")
	menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu.position = Vector2(-116, 10)
	menu.size = Vector2(100, 70)
	menu.custom_draw = func(ci: Control):
		UIKit.draw_icon(ci, "settings", Vector2(50, 33), 54.0)
	menu.name = "Settings"
	menu.pressed.connect(_open_settings)
	add_child(menu)

# ------------------------------------------------------------------ left
func _build_left_buttons() -> void:
	var items := [
		["SHOP", "shop", func(): Router.goto("shop")],
		["BRAWLERS", "brawlers", func(): Router.goto("select")],
		["PROFILE", "profile", func(): Router.goto("profile")],
		["GUIDE", "guide", _open_how_to],
	]
	for i in items.size():
		var it: Array = items[i]
		var b := SlantButton.new()
		b.color = Color("27334d")
		b.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		b.position = Vector2(22, -196 + i * 100)
		b.size = Vector2(150, 90)
		var icon_kind: String = it[1]
		var label: String = it[0]
		b.custom_draw = func(ci: Control):
			SlantButton.menu_icon(ci, icon_kind, Vector2(75, 34))
			SlantButton.text_c(ci, label, Vector2(75, 80), 20, Color.WHITE)
		b.name = label.capitalize()
		b.pressed.connect(it[2])
		add_child(b)
		if icon_kind == "brawlers":
			_dot(b, Save.ranks_unclaimed_total(), Vector2(126, -10))
		if icon_kind == "shop":
			var free_gift := 1 if not Save.shop_bought("daily_gift") else 0
			_dot(b, free_gift + Save.data.drops.size(), Vector2(126, -10))

# ------------------------------------------------------------------ bottom-left Rush Pass panel
func _build_level_panel() -> void:
	var pending := Save.pass_unclaimed()
	var lv := SlantButton.new()
	# only bright yellow while there's something to claim
	lv.color = UIKit.YELLOW if pending > 0 else Color("27334d")
	lv.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lv.position = Vector2(18, -132)
	lv.size = Vector2(400, 116)
	lv.name = "RushPass"
	lv.custom_draw = func(ci: Control):
		var tier := Save.pass_tier()
		var into := int(Save.data.pass_tokens) % Progression.TOKENS_PER_TIER
		var maxed := tier >= Progression.PASS_TIERS
		SlantButton.text_l(ci, Progression.PASS_NAME, Vector2(24, 40), 28, Color.WHITE)
		if Save.data.gold_pass:
			SlantButton.text_l(ci, "GOLD", Vector2(222, 40), 18, Color("ffe14d"))
		var br := Rect2(Vector2(60, 62), Vector2(236, 34))
		ci.draw_rect(br.grow(3), UIKit.DARK)
		ci.draw_rect(br, Color("1d2438"))
		ci.draw_rect(Rect2(br.position, Vector2(br.size.x * (1.0 if maxed else float(into) / Progression.TOKENS_PER_TIER), br.size.y)), Color("3ea2ff"))
		SlantButton.text_c(ci, "MAX" if maxed else "%d/%d" % [into, Progression.TOKENS_PER_TIER], br.get_center() + Vector2(0, 10), 22, Color.WHITE)
		UIKit.draw_icon(ci, "token", Vector2(36, 79), 56.0)
		ci.draw_circle(Vector2(336, 79), 36, UIKit.DARK)
		ci.draw_circle(Vector2(336, 79), 31, Color("2a8cff"))
		SlantButton.text_c(ci, str(tier), Vector2(336, 92), 34, Color.WHITE)
	lv.pressed.connect(func(): Router.goto("pass"))
	add_child(lv)
	_dot(lv, pending, Vector2(320, -16))

func _dot(parent: Control, count: int, at: Vector2) -> void:
	if count <= 0:
		return
	var d := RewardTile.Dot.new()
	d.count = count
	d.position = at
	parent.add_child(d)

# ------------------------------------------------------------------ bottom-centre mode panel
func _build_mode_panel() -> void:
	_bots_btn = SlantButton.new()
	_bots_btn.color = Color(0, 0, 0, 0.55)
	_bots_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bots_btn.position = Vector2(-160, -170)
	_bots_btn.size = Vector2(370, 36)
	_bots_btn.custom_draw = func(ci: Control):
		var bid: String = Save.data.selected_brawler
		var dn: String = Config.DIFFICULTY[Config.match_difficulty(bid)].name
		var txt := "BOTS: %s  (RANK %d)" % [dn, Progression.rank_for(Save.brawler_trophies(bid))] if Save.setting("difficulty") == "auto" else "BOTS: %s  (fixed - tap)" % dn
		SlantButton.text_r(ci, txt, Vector2(350, 26), 16, Color("8fd0ff"))
	_bots_btn.pressed.connect(func():
		var order: Array = ["auto", "easy", "normal", "hard", "extreme"]
		var i := order.find(Save.setting("difficulty"))
		Save.set_setting("difficulty", order[(i + 1) % order.size()])
		_bots_btn.queue_redraw())
	_bots_btn.visible = false # bots scale with brawler rank automatically (Settings can override)
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
		UIKit.draw_icon(ci, m.get("icon", "mode_gem"), Vector2(70, 60), 96.0)
		SlantButton.text_l(ci, m.name, Vector2(126, 56), 27, Color.WHITE)
		var map_txt: String = MapData.MAPS[Progression.active_map(mid)].name
		SlantButton.text_l(ci, map_txt, Vector2(128, 90), 17, Color("9dff8a"))
		# cycle arrow
		var ar := Rect2(Vector2(368, 34), Vector2(40, 50))
		ci.draw_rect(ar.grow(3), UIKit.DARK)
		ci.draw_rect(ar, Color.WHITE)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(380, 47), Vector2(400, 59), Vector2(380, 71)]), UIKit.DARK)
	_mode_panel.name = "Mode"
	_mode_panel.pressed.connect(func(): Router.goto("events"))
	add_child(_mode_panel)

	var info := SlantButton.new()
	info.color = Color("2a8cff")
	info.circle = true
	info.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	info.position = Vector2(-226, -160)
	info.size = Vector2(52, 52)
	info.color = Color(0, 0, 0, 0)
	info.custom_draw = func(ci: Control):
		UIKit.draw_icon(ci, "info", Vector2(26, 26), 60.0)
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
	# win streak flame on the top-right corner of PLAY
	var streak := int(Save.data.get("win_streak", 0))
	if streak >= 1:
		var sb := UIKit.StreakBadge.new()
		sb.streak = streak
		sb.show_label = false
		sb.name = "WinStreak"
		sb.position = Vector2(300, -32)
		sb.size = Vector2(62, 62)
		play.add_child(sb)
	play.pressed.connect(func():
		Sfx.play("ui_confirm")
		Router.goto("match", {"mode": Save.data.selected_mode, "brawler": Save.data.selected_brawler}))
	add_child(play)
	# RANKED entry above CHAMPS
	var rk := SlantButton.new()
	rk.color = Color("2a1460")
	rk.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	rk.position = Vector2(-372, -384)
	rk.size = Vector2(340, 96)
	rk.name = "Ranked"
	var rinfo := Progression.ranked_info(int(Save.ranked().points))
	var rtex: Texture2D = load("res://assets/ranks/%s_crest.png" % rinfo.id)
	rk.custom_draw = func(ci: Control):
		ci.draw_rect(Rect2(0, 0, 340, 6), rinfo.color)
		ci.draw_texture_rect(rtex, Rect2(14, -10, 112, 112), false)
		SlantButton.text_l(ci, "RANKED", Vector2(138, 46), 30, Color.WHITE)
		SlantButton.text_l(ci, String(rinfo.name), Vector2(138, 76), 18, rinfo.color.lightened(0.3))
	rk.pressed.connect(func():
		Sfx.play("ui_click")
		Router.goto("ranked"))
	add_child(rk)
	UIKit.pop_in(rk, 0.35, Vector2(60, 0))
	# CHAMPS entry on the right side, above PLAY
	var ch := SlantButton.new()
	ch.color = Color("3a1a12")
	ch.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ch.position = Vector2(-372, -278)
	ch.size = Vector2(340, 96)
	ch.name = "Champs"
	ch.custom_draw = func(ci: Control):
		ci.draw_rect(Rect2(0, 0, 340, 6), Color("e0a050"))
		UIKit.draw_icon(ci, "champs", Vector2(74, 40), 128.0)
		SlantButton.text_l(ci, "COMPETE", Vector2(148, 46), 30, Color("ffd98a"))
		var c := Save.champs()
		var st := ""
		match c.stage:
			"qualifier": st = "QUALIFIER  %d W - %d L" % [int(c.q_w), int(c.q_l)]
			"finals": st = "FINALS  %d W - %d L" % [int(c.f_w), int(c.f_l)]
			_: st = "REWARDS READY!"
		SlantButton.text_l(ci, st, Vector2(148, 76), 16, Color(1, 1, 1, 0.85))
	ch.pressed.connect(func():
		Sfx.play("ui_click")
		Router.goto("champs"))
	add_child(ch)
	UIKit.pop_in(ch, 0.3, Vector2(60, 0))
	# idle pulse to draw the eye (starts after the entrance animation)
	UIKit.pop_in(play, 0.25, Vector2(60, 0))
	var tw := create_tween().set_loops()
	tw.tween_interval(0.7)
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


# ====================================================================== shared header
## Back arrow + big title used by the secondary screens.
static func build_header(parent: Control, title: String, on_back: Callable) -> void:
	var back := SlantButton.new()
	back.color = Color("2a8cff")
	back.position = Vector2(14, 12)
	back.size = Vector2(96, 70)
	back.name = "Back"
	back.custom_draw = func(ci: Control):
		UIKit.draw_icon(ci, "back", Vector2(50, 33), 58.0)
	back.pressed.connect(on_back)
	parent.add_child(back)
	var t := TitleText.new()
	t.text = title
	t.position = Vector2(126, 10)
	t.size = Vector2(600, 76)
	parent.add_child(t)


class TitleText extends Control:
	var text := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		SlantButton.text_l(self, text, Vector2(0, 58), 46, Color.WHITE)


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
		if circle and color.a < 0.05:
			pass
		elif circle:
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
			var inner := PackedVector2Array([Vector2(s + inset, inset), Vector2(w - inset, inset), Vector2(w - s - inset, h - inset - 6), Vector2(inset, h - inset - 6)])
			if color.a > 0.9:
				# bottom lip
				var lo := color.darkened(0.5)
				draw_colored_polygon(PackedVector2Array([Vector2(inset, h - inset - 7), Vector2(w - s - inset, h - inset - 7), Vector2(w - s - inset, h - inset), Vector2(inset, h - inset)]), lo)
				# vertical gradient face
				var top_c := color.lightened(0.25)
				var bot_c := color.darkened(0.16)
				draw_polygon(inner, PackedColorArray([top_c, top_c, bot_c, bot_c]))
				# shine across the top half
				var mid := lerpf(inner[0].y, inner[3].y, 0.46)
				var fx := func(y: float) -> float: return s * (1.0 - (y - 0.0) / h)
				var gl := PackedVector2Array([inner[0], inner[1], Vector2(w - inset - (s - fx.call(mid)), mid), Vector2(inset + fx.call(mid), mid)])
				draw_polygon(gl, PackedColorArray([Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.04)]))
				# rim light on the top edge
				draw_line(inner[0] + Vector2(2, 2), inner[1] + Vector2(-2, 2), Color(1, 1, 1, 0.45), 2.5, true)
			else:
				draw_colored_polygon(inner, color)
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
		UIKit.draw_icon(ci, "trophy", c, r * 2.9)

	static func coin(ci: CanvasItem, c: Vector2, r: float) -> void:
		UIKit.draw_icon(ci, "coin", c, r * 2.5)

	static func star(ci: CanvasItem, c: Vector2, r: float) -> void:
		UIKit.draw_icon(ci, "star", c, r * 2.3)

	static func menu_icon(ci: CanvasItem, kind: String, c: Vector2) -> void:
		var names := {"brawlers": "brawlers", "profile": "profile", "guide": "guide", "swords": "mode_knockout"}
		UIKit.draw_icon(ci, names.get(kind, kind), c, 72.0)


## Rank shield, brawler trophies and power level, shown above the lobby brawler.
class BrawlerBadge extends Control:
	var brawler_id := "bront"

	func _draw() -> void:
		var bt := Save.brawler_trophies(brawler_id)
		var rank := Progression.rank_for(bt)
		var lvl := Save.brawler_level(brawler_id)
		var rcol := Progression.rank_color(rank)
		# trophy ribbon
		var rib := PackedVector2Array([Vector2(70, 26), Vector2(270, 26), Vector2(262, 68), Vector2(62, 68)])
		draw_colored_polygon(rib, UIKit.DARK)
		draw_colored_polygon(PackedVector2Array([Vector2(74, 30), Vector2(266, 30), Vector2(259, 64), Vector2(66, 64)]), Color("6b2a5a"))
		var prog := Progression.rank_progress(bt)
		var frac := 1.0 if prog.y == 0 else float(prog.x) / prog.y
		draw_colored_polygon(PackedVector2Array([Vector2(74, 30), Vector2(74 + 192 * frac, 30), Vector2(67 + 192 * frac, 64), Vector2(66, 64)]), Color("ff7a2b"))
		SlantButton.trophy(self, Vector2(168, 47), 12.0)
		SlantButton.text_l(self, str(bt), Vector2(188, 60), 28, Color.WHITE)
		# rank crest
		UIKit.draw_rank_badge(self, Vector2(46, 46), 82.0, rank)
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
