extends Control
## Player profile: name, level, trophies, lifetime stats, per-brawler trophies and
## the last 25 matches.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	add_child(preload("res://scripts/ui/main_menu.gd").LobbyBackground.new())

	preload("res://scripts/ui/main_menu.gd").build_header(self, "PROFILE", func(): Router.goto("menu"))

	var cols := HBoxContainer.new()
	cols.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cols.offset_left = 20
	cols.offset_right = -20
	cols.offset_top = 90
	cols.offset_bottom = -20
	cols.add_theme_constant_override("separation", 18)
	add_child(cols)

	# ---------------- left: identity + stats
	var left := UIKit.panel(UIKit.PANEL)
	left.custom_minimum_size = Vector2(560, 0)
	cols.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	left.add_child(lv)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	lv.add_child(name_row)
	var name_edit := LineEdit.new()
	name_edit.text = Save.data.username
	name_edit.max_length = 14
	name_edit.custom_minimum_size = Vector2(300, 52)
	name_edit.add_theme_font_size_override("font_size", 24)
	name_edit.add_theme_stylebox_override("normal", UIKit.box(Color(0, 0, 0, 0.4), 12, 3, UIKit.DARK, 0))
	name_edit.add_theme_stylebox_override("focus", UIKit.box(Color(0, 0, 0, 0.55), 12, 3, UIKit.YELLOW, 0))
	name_row.add_child(name_edit)
	var save_name := UIKit.button("RENAME", UIKit.GREEN, 18, Vector2(140, 52))
	var commit := func(_t = ""):
		var n := name_edit.text.strip_edges()
		if n.length() >= 2:
			Save.data.username = n
			Save.save_game()
			Sfx.play("ui_confirm")
		else:
			name_edit.text = Save.data.username
			Sfx.play("ui_error")
	save_name.pressed.connect(commit)
	name_edit.text_submitted.connect(commit)
	name_row.add_child(save_name)

	var prog := Save.level_progress()
	lv.add_child(UIKit.label("LEVEL %d   ·   %d / %d XP" % [Save.account_level(), prog.x, prog.y], 20, Color("8fd0ff"), 6))
	lv.add_child(UIKit.label("TROPHIES  %d    (best %d)" % [Save.total_trophies(), int(Save.data.highest_trophies)], 22, UIKit.YELLOW, 6))
	var s: Dictionary = Save.data.stats
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	lv.add_child(grid)
	var win_rate: float = 0.0 if s.matches == 0 else 100.0 * s.wins / s.matches
	for pair in [["MATCHES", s.matches], ["WINS", s.wins], ["WIN RATE", "%d%%" % int(win_rate)],
			["LOSSES", s.losses], ["DRAWS", s.draws], ["STAR PLAYER", s.mvp],
			["KOs", s.kos], ["DEATHS", s.deaths], ["DAMAGE", s.damage]]:
		grid.add_child(_tile(pair[0], str(pair[1])))
	lv.add_child(UIKit.label("BRAWLER TROPHIES", 18, Color.WHITE, 5))
	var bt := HBoxContainer.new()
	bt.add_theme_constant_override("separation", 6)
	lv.add_child(bt)
	for id in Config.BRAWLER_ORDER:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -6)
		var por := UIKit.BrawlerPortrait.new()
		por.brawler_id = id
		por.art_scale = 0.85
		por.custom_minimum_size = Vector2(96, 84)
		v.add_child(por)
		v.add_child(UIKit.label("%d" % Save.brawler_trophies(id), 16, UIKit.YELLOW, 5, HORIZONTAL_ALIGNMENT_CENTER))
		bt.add_child(v)
	var reset := UIKit.button("RESET PROGRESS", Color("8a3040"), 16, Vector2(220, 46))
	reset.pressed.connect(_confirm_reset)
	lv.add_child(reset)

	# ---------------- right: match history
	var right := UIKit.panel(UIKit.PANEL)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right.add_child(rv)
	rv.add_child(UIKit.label("MATCH HISTORY", 24, Color.WHITE, 6))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	if Save.data.history.is_empty():
		list.add_child(UIKit.body("No matches yet — go play one!", 16))
	for h in Save.data.history:
		list.add_child(_history_row(h))

func _tile(title: String, value: String) -> Control:
	var p := PanelContainer.new()
	var sb := UIKit.box(Color(0, 0, 0, 0.35), 12, 2, UIKit.DARK, 0)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(164, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.add_child(UIKit.label(title, 12, Color(1, 1, 1, 0.6), 0))
	v.add_child(UIKit.label(value, 22, Color.WHITE, 6))
	p.add_child(v)
	return p

func _history_row(h: Dictionary) -> Control:
	var res: String = h.result
	var col: Color = {"win": UIKit.GREEN, "loss": UIKit.RED, "draw": Color("9a94b0")}[res]
	var p := PanelContainer.new()
	var sb := UIKit.box(col.darkened(0.6), 12, 3, col.darkened(0.2), 0)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var por := UIKit.BrawlerPortrait.new()
	por.brawler_id = h.brawler if Config.BRAWLERS.has(h.brawler) else "bront"
	por.art_scale = 0.6
	por.backdrop = false
	por.custom_minimum_size = Vector2(50, 54)
	row.add_child(por)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var mname: String = Config.MODES[h.mode].name if Config.MODES.has(h.mode) else str(h.mode)
	v.add_child(UIKit.label("%s  ·  %s" % [{"win": "VICTORY", "loss": "DEFEAT", "draw": "DRAW"}[res], mname], 17, col.lightened(0.3), 5))
	v.add_child(UIKit.label("KO %d · DIED %d · DMG %d%s   —   %s" % [int(h.kos), int(h.deaths), int(h.damage), "  · STAR" if h.get("mvp", false) else "", str(h.time).replace("T", " ")], 12, Color(1, 1, 1, 0.7), 0))
	var tr := int(h.trophies)
	row.add_child(UIKit.label(("+%d" % tr) if tr > 0 else str(tr), 22, UIKit.YELLOW, 6))
	return p

func _confirm_reset() -> void:
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
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UIKit.label("RESET ALL PROGRESS?", 30, UIKit.RED, 8, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.body("Trophies, credits, levels, upgrades, stats and history will be wiped. Settings are kept. This can't be undone.", 16))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	var no := UIKit.button("CANCEL", UIKit.GREEN, 20, Vector2(170, 56))
	no.pressed.connect(o.queue_free)
	h.add_child(no)
	var yes := UIKit.button("RESET", UIKit.RED, 20, Vector2(170, 56))
	yes.pressed.connect(func():
		Save.reset_progress()
		Router.goto("profile"))
	h.add_child(yes)
	add_child(o)
