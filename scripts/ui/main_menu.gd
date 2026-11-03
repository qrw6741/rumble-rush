extends Control
## Main menu: profile bar, currencies, selected brawler, mode + difficulty, PLAY.

var _mode_btn: Button
var _mode_desc: Label
var _diff_btn: Button
var _portrait: UIKit.BrawlerPortrait
var _brawler_name: Label
var _brawler_info: Label
var _t := 0.0
var _title: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	Sfx.play_music("music_menu")
	add_child(UIKit.MenuBackground.new())

	# ---------------- top bar
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_right = -18
	top.offset_top = 14
	top.add_theme_constant_override("separation", 14)
	add_child(top)

	var profile_btn := Button.new()
	profile_btn.flat = true
	profile_btn.focus_mode = Control.FOCUS_NONE
	profile_btn.custom_minimum_size = Vector2(300, 64)
	profile_btn.pressed.connect(func(): Sfx.play("ui_click"); Router.goto("profile"))
	var prof := _profile_badge()
	profile_btn.add_child(prof)
	top.add_child(profile_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(UIKit.currency_chip("trophy", str(Save.total_trophies()), UIKit.YELLOW))
	top.add_child(UIKit.currency_chip("coin", str(Save.data.credits), Color("ffe08a")))
	var settings := UIKit.button("SETTINGS", UIKit.PANEL_LIGHT, 18, Vector2(140, 52))
	settings.pressed.connect(_open_settings)
	top.add_child(settings)

	# ---------------- title
	_title = TitleLogo.new()
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.custom_minimum_size = Vector2(560, 120)
	_title.position = Vector2(-280, 78)
	add_child(_title)

	# ---------------- centre: selected brawler
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.custom_minimum_size = Vector2(380, 380)
	center.position = Vector2(-190, -150)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 2)
	add_child(center)
	var pbtn := Button.new()
	pbtn.flat = true
	pbtn.focus_mode = Control.FOCUS_NONE
	pbtn.custom_minimum_size = Vector2(380, 290)
	pbtn.pressed.connect(func(): Sfx.play("ui_click"); Router.goto("select"))
	_portrait = UIKit.BrawlerPortrait.new()
	_portrait.brawler_id = Save.data.selected_brawler
	_portrait.art_scale = 3.4
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pbtn.add_child(_portrait)
	center.add_child(pbtn)
	var d: Dictionary = Config.BRAWLERS[Save.data.selected_brawler]
	_brawler_name = UIKit.label(d.name, 40, Color.WHITE, 10, HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(_brawler_name)
	var bid: String = Save.data.selected_brawler
	_brawler_info = UIKit.label("%s  ·  LEVEL %d  ·  %d TROPHIES" % [d.role, Save.brawler_level(bid), Save.brawler_trophies(bid)], 17, Color(1, 1, 1, 0.85), 6, HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(_brawler_info)

	# ---------------- left column
	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	left.position = Vector2(28, -120)
	left.add_theme_constant_override("separation", 14)
	add_child(left)
	var brawlers_btn := UIKit.button("BRAWLERS", UIKit.BLUE, 24, Vector2(230, 70))
	brawlers_btn.pressed.connect(func(): Router.goto("select"))
	left.add_child(brawlers_btn)
	var profile2 := UIKit.button("PROFILE", UIKit.PURPLE, 24, Vector2(230, 70))
	profile2.pressed.connect(func(): Router.goto("profile"))
	left.add_child(profile2)
	var how := UIKit.button("HOW TO PLAY", Color("2bb6a3"), 20, Vector2(230, 60))
	how.pressed.connect(_open_how_to)
	left.add_child(how)
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		var quit := UIKit.button("QUIT", Color("6b5f86"), 18, Vector2(230, 52))
		quit.pressed.connect(func(): get_tree().quit())
		left.add_child(quit)

	# ---------------- bottom right: mode + play
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right.position = Vector2(-372, -322)
	right.custom_minimum_size = Vector2(350, 0)
	right.add_theme_constant_override("separation", 10)
	add_child(right)
	_mode_btn = UIKit.button("", UIKit.PURPLE, 26, Vector2(350, 76))
	_mode_btn.pressed.connect(_cycle_mode)
	right.add_child(_mode_btn)
	_mode_desc = UIKit.body("", 15, Color(1, 1, 1, 0.9))
	_mode_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_mode_desc)
	_diff_btn = UIKit.button("", Color("6b5f86"), 18, Vector2(350, 50))
	_diff_btn.pressed.connect(_cycle_difficulty)
	right.add_child(_diff_btn)
	var play := UIKit.button("PLAY", UIKit.YELLOW, 46, Vector2(350, 100))
	play.add_theme_color_override("font_color", Color.WHITE)
	play.pressed.connect(_play)
	right.add_child(play)
	_refresh_mode()

	# bottom-left credit line
	var foot := UIKit.label("v0.1  ·  5 brawlers  ·  2 modes  ·  2 arenas  ·  offline vs bots", 13, Color(1, 1, 1, 0.5), 4)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(20, -30)
	add_child(foot)

func _profile_badge() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lvl := LevelBadge.new()
	lvl.custom_minimum_size = Vector2(60, 60)
	h.add_child(lvl)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UIKit.label(Save.data.username, 24, Color.WHITE, 7))
	var prog := Save.level_progress()
	v.add_child(UIKit.label("XP %d / %d" % [prog.x, prog.y], 14, Color("8fd0ff"), 5))
	h.add_child(v)
	return h

func _refresh_mode() -> void:
	var m: Dictionary = Config.MODES[Save.data.selected_mode]
	_mode_btn.text = m.name + "  »"
	_mode_btn.add_theme_stylebox_override("normal", UIKit.box(m.color))
	_mode_btn.add_theme_stylebox_override("hover", UIKit.box(m.color.lightened(0.12)))
	_mode_desc.text = m.short
	_diff_btn.text = "BOTS: " + Config.DIFFICULTY[Save.setting("difficulty")].name

func _cycle_mode() -> void:
	var keys := Config.MODES.keys()
	var i := keys.find(Save.data.selected_mode)
	Save.data.selected_mode = keys[(i + 1) % keys.size()]
	Save.save_game()
	_refresh_mode()

func _cycle_difficulty() -> void:
	var order: Array = Config.DIFFICULTY_ORDER
	var i := order.find(Save.setting("difficulty"))
	Save.set_setting("difficulty", order[(i + 1) % order.size()])
	_refresh_mode()

func _play() -> void:
	Sfx.play("ui_confirm")
	Router.goto("match", {"mode": Save.data.selected_mode, "brawler": Save.data.selected_brawler})

func _open_settings() -> void:
	var s := SettingsPanel.new()
	s.closed.connect(_refresh_mode)
	add_child(s)

func _open_how_to() -> void:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.12, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(c)
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(760, 0)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UIKit.label("HOW TO PLAY", 38, UIKit.YELLOW, 10, HORIZONTAL_ALIGNMENT_CENTER))
	var lines := [
		"PC — WASD to move, aim with the mouse, LEFT CLICK to attack (hold to keep firing).",
		"RIGHT CLICK or Q uses your GADGET. Hold SPACE to preview your SUPER, release to unleash it.",
		"MOBILE — left side moves. Drag the orange stick to aim and release to fire; quick-tap to auto-aim. The yellow stick is your SUPER, the green button your GADGET.",
		"Ammo reloads on its own. Land hits to charge your SUPER. Stay out of fights for 3 seconds to regenerate health.",
		"Hide in BUSHES to vanish from enemies — unless they get close or you attack. Shots can't pass walls, but lobbed throws can. Crates can be smashed.",
	]
	for line in lines:
		v.add_child(UIKit.body("•  " + line, 17))
	for id in Config.MODES.keys():
		v.add_child(UIKit.label(Config.MODES[id].name, 22, Config.MODES[id].color.lightened(0.3), 6))
		v.add_child(UIKit.body(Config.MODES[id].rules, 15))
	var close := UIKit.button("GOT IT", UIKit.GREEN, 24, Vector2(300, 58))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(o.queue_free)
	v.add_child(close)
	add_child(o)

func _process(delta: float) -> void:
	_t += delta


class TitleLogo extends Control:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var f := UIKit.bold()
		var words := ["RUMBLE", "RUSH"]
		var cols := [Color("ffd23a"), Color("ff7a2b")]
		var sizes := [64, 64]
		var total := 0.0
		var widths := []
		for i in 2:
			var w := f.get_string_size(words[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sizes[i]).x
			widths.append(w)
			total += w
		total += 24
		var x := size.x * 0.5 - total * 0.5
		for i in 2:
			var bob := sin(_t * 2.2 + i * 0.8) * 4.0
			var p := Vector2(x, 76 + bob)
			var rot := -0.04 if i == 0 else 0.04
			draw_set_transform(p, rot, Vector2.ONE)
			draw_string_outline(f, Vector2(0, 6), words[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sizes[i], 18, Color(0, 0, 0, 0.35))
			draw_string_outline(f, Vector2.ZERO, words[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sizes[i], 16, UIKit.DARK)
			draw_string(f, Vector2.ZERO, words[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sizes[i], cols[i])
			draw_string(f, Vector2(0, -3), words[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sizes[i], cols[i].lightened(0.25) * Color(1, 1, 1, 0.35))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			x += widths[i] + 24


class LevelBadge extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r: float = min(size.x, size.y) * 0.5
		var pts := PackedVector2Array()
		for i in 6:
			var a := -PI / 2 + i * TAU / 6
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, UIKit.DARK)
		var inner := PackedVector2Array()
		for i in 6:
			var a := -PI / 2 + i * TAU / 6
			inner.append(c + Vector2(cos(a), sin(a)) * (r - 4))
		draw_colored_polygon(inner, Color("3ea2ff"))
		var f := UIKit.bold()
		var s := str(Save.account_level())
		var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		draw_string_outline(f, c + Vector2(-sz.x * 0.5, 9), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, UIKit.DARK)
		draw_string(f, c + Vector2(-sz.x * 0.5, 9), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
