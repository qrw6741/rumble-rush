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

	# identity: profile icon + title, both changeable
	var idrow := HBoxContainer.new()
	idrow.add_theme_constant_override("separation", 14)
	lv.add_child(idrow)
	var icon := UIKit.ProfileIcon.new()
	icon.custom_minimum_size = Vector2(96, 96)
	idrow.add_child(icon)
	var idv := VBoxContainer.new()
	idv.add_theme_constant_override("separation", 6)
	idrow.add_child(idv)
	idv.add_child(UIKit.label(Save.title_name(Save.data.get("profile_title", "rookie")), 22, Color("ffb84d"), 6))
	var ib := HBoxContainer.new()
	ib.add_theme_constant_override("separation", 8)
	idv.add_child(ib)
	var ci := UIKit.button("CHANGE ICON", UIKit.BLUE, 15, Vector2(170, 46))
	ci.pressed.connect(_pick_icon)
	ib.add_child(ci)
	var ct := UIKit.button("CHANGE TITLE", Color("c25bff"), 15, Vector2(170, 46))
	ct.pressed.connect(_pick_title)
	ib.add_child(ct)

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
			["KOs", s.kos], ["DEATHS", s.deaths], ["DAMAGE", s.damage],
			["WIN STREAK", int(Save.data.get("win_streak", 0))], ["BEST STREAK", maxi(int(Save.data.get("best_streak", 0)), int(Save.data.get("win_streak", 0)))]]:
		grid.add_child(_tile(pair[0], str(pair[1])))
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
	rv.add_child(UIKit.label("BRAWLER MASTERY", 22, Color.WHITE, 6))
	var mscroll := ScrollContainer.new()
	mscroll.custom_minimum_size = Vector2(0, 250)
	mscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(mscroll)
	var mg := GridContainer.new()
	mg.columns = 3
	mg.add_theme_constant_override("h_separation", 8)
	mg.add_theme_constant_override("v_separation", 8)
	mscroll.add_child(mg)
	for id in Config.BRAWLER_ORDER:
		if Save.is_unlocked(id):
			mg.add_child(_mastery_tile(id))
	rv.add_child(UIKit.label("MATCH HISTORY", 22, Color.WHITE, 6))
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

func _mastery_tile(id: String) -> Control:
	var pts := Save.mastery_points(id)
	var lvl := Progression.mastery_level(pts)
	var col: Color = Progression.MASTERY_COLORS[lvl]
	var p := PanelContainer.new()
	var sb := UIKit.box(Color(0, 0, 0, 0.35), 10, 3, col.darkened(0.2), 0)
	sb.content_margin_left = 6
	sb.content_margin_right = 8
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(196, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	var ic := UIKit.ProfileIcon.new()
	ic.brawler_id = id
	ic.custom_minimum_size = Vector2(52, 52)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	h.add_child(v)
	v.add_child(UIKit.label(Config.BRAWLERS[id].name, 15, Color.WHITE, 4))
	v.add_child(UIKit.label(Progression.MASTERY_NAMES[lvl], 13, col, 4))
	var nxt: String = "MAX" if lvl >= 9 else "%d / %d" % [pts, int(Progression.MASTERY_POINTS[lvl + 1])]
	v.add_child(UIKit.label(nxt, 11, Color(1, 1, 1, 0.7), 3))
	return p

func _overlay_panel(title: String) -> VBoxContainer:
	var o := Control.new()
	o.name = "Picker"
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.12, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(c)
	var pnl := UIKit.panel()
	pnl.custom_minimum_size = Vector2(760, 520)
	c.add_child(pnl)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pnl.add_child(v)
	var hh := HBoxContainer.new()
	v.add_child(hh)
	var tl := UIKit.label(title, 30, UIKit.YELLOW, 8)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(tl)
	var x := UIKit.button("X", UIKit.RED, 22, Vector2(56, 52))
	x.pressed.connect(o.queue_free)
	hh.add_child(x)
	add_child(o)
	return v

func _pick_icon() -> void:
	var v := _overlay_panel("CHOOSE ICON")
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	v.add_child(g)
	for id in Config.BRAWLER_ORDER:
		if not Save.is_unlocked(id):
			continue
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(110, 110)
		var ic := UIKit.ProfileIcon.new()
		ic.brawler_id = id
		ic.custom_minimum_size = Vector2(110, 110)
		ic.size = Vector2(110, 110)
		b.add_child(ic)
		var bid: String = id
		b.pressed.connect(func():
			Save.data.profile_icon = bid
			Save.save_game()
			Sfx.play("ui_confirm")
			Router.goto("profile"))
		g.add_child(b)
	v.add_child(UIKit.body("Unlock more brawlers to get more icons.", 14))

func _pick_title() -> void:
	var v := _overlay_panel("CHOOSE TITLE")
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 420)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var have := Save.titles_unlocked()
	for t in Progression.title_list():
		var ok: bool = t.id in have
		var b := UIKit.button(t.name if ok else "%s  (%s)" % [t.name, t.how], Color("c25bff") if ok else Color("3a3f58"), 16, Vector2(700, 46))
		b.disabled = not ok
		var tid: String = t.id
		b.pressed.connect(func():
			Save.data.profile_title = tid
			Save.save_game()
			Sfx.play("ui_confirm")
			Router.goto("profile"))
		list.add_child(b)

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
