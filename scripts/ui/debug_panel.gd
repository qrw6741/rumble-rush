extends Control
## Debug menu: play any brawler (locked ones too) in a test match that saves nothing.

var _mode := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	_mode = Save.data.selected_mode
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.08, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_build()

func _build() -> void:
	for c in get_children():
		if not c is ColorRect:
			c.queue_free()
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 40
	root.offset_right = -40
	root.offset_top = 16
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var title := UIKit.label("DEBUG  ·  TEST ANY BRAWLER", 32, Color("ff7ad9"), 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close := UIKit.button("CLOSE", Color("6b5f86"), 20, Vector2(150, 48))
	close.pressed.connect(queue_free)
	top.add_child(close)
	root.add_child(UIKit.label("Test matches never save anything: no trophies, coins, XP, mastery, quests, win streak or stats.", 16, Color(1, 1, 1, 0.8), 4))
	# mode picker
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	root.add_child(modes)
	modes.add_child(UIKit.label("MODE:", 20, UIKit.YELLOW, 5))
	for m in Config.MODES.keys():
		var sel: bool = m == _mode
		var b := UIKit.button(String(Config.MODES[m].name).to_upper(), UIKit.ORANGE if sel else Color("3a3f63"), 14, Vector2(150, 40))
		b.pressed.connect(func():
			_mode = m
			_build())
		modes.add_child(b)
	# brawler grid
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(grid)
	for id in Config.BRAWLER_ORDER:
		grid.add_child(_card(id))

func _card(id: String) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(160, 200)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("232845")
	sb.border_color = Color("ff7ad9") if not Save.is_unlocked(id) else Color("4a5080")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var pic := UIKit.BrawlerPortrait.new()
	pic.brawler_id = id
	pic.art_scale = 1.0
	pic.skin = ""
	pic.position = Vector2(8, 8)
	pic.size = Vector2(144, 144)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pic)
	var nm := UIKit.label(String(Config.BRAWLERS[id].name).to_upper(), 18, Color.WHITE, 5, HORIZONTAL_ALIGNMENT_CENTER)
	nm.position = Vector2(0, 152)
	nm.size = Vector2(160, 24)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nm)
	var tag := UIKit.label("LOCKED" if not Save.is_unlocked(id) else "OWNED", 13, Color("ff7ad9") if not Save.is_unlocked(id) else Color("8fd0ff"), 4, HORIZONTAL_ALIGNMENT_CENTER)
	tag.position = Vector2(0, 176)
	tag.size = Vector2(160, 20)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tag)
	b.pressed.connect(func():
		Sfx.play("ui_confirm")
		Router.goto("match", {"mode": _mode, "brawler": id, "debug": true}))
	return b
