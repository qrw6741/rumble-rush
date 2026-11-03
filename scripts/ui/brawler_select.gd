extends Control
## Brawler collection: browse all brawlers, read their kits and stats, upgrade
## them with credits, and pick who you take into battle.

var _focus := ""
var _detail_portrait: UIKit.BrawlerPortrait
var _detail: VBoxContainer
var _cards: Dictionary = {}
var _credits_chip: PanelContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var bg := UIKit.MenuBackground.new()
	bg.top = Color("1f3a7a")
	bg.bottom = Color("0d1230")
	add_child(bg)
	_focus = Save.data.selected_brawler

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_right = -18
	top.offset_top = 14
	top.add_theme_constant_override("separation", 14)
	add_child(top)
	var back := UIKit.button("BACK", UIKit.PANEL_LIGHT, 20, Vector2(120, 54))
	back.pressed.connect(func(): Router.goto("menu"))
	top.add_child(back)
	top.add_child(UIKit.label("BRAWLERS", 40, Color.WHITE, 10))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	_credits_chip = UIKit.currency_chip("coin", str(Save.data.credits), Color("ffe08a"))
	top.add_child(_credits_chip)

	# card grid (left)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.position = Vector2(26, 96)
	add_child(grid)
	for id in Config.BRAWLER_ORDER:
		var card := _make_card(id)
		_cards[id] = card
		grid.add_child(card)

	# detail panel (right)
	var panel := UIKit.panel(Color(0.1, 0.07, 0.25, 0.85))
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -600
	panel.offset_right = -20
	panel.offset_top = 90
	panel.offset_bottom = -20
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	scroll.add_child(_detail)
	_show(_focus)

func _make_card(id: String) -> Control:
	var d: Dictionary = Config.BRAWLERS[id]
	var b := Button.new()
	b.custom_minimum_size = Vector2(196, 238)
	b.focus_mode = Control.FOCUS_NONE
	var rc: Color = Config.RARITY_COLORS[d.rarity]
	b.add_theme_stylebox_override("normal", UIKit.box(rc.darkened(0.45), 18, 4))
	b.add_theme_stylebox_override("hover", UIKit.box(rc.darkened(0.3), 18, 4))
	b.add_theme_stylebox_override("pressed", UIKit.box(rc.darkened(0.2), 18, 4, UIKit.DARK, 2))
	b.pressed.connect(func():
		Sfx.play("ui_click")
		_show(id))
	b.mouse_entered.connect(func(): UIKit._pop(b, 1.04))
	b.mouse_exited.connect(func(): UIKit._pop(b, 1.0))
	var por := UIKit.BrawlerPortrait.new()
	por.brawler_id = id
	por.art_scale = 1.75
	por.position = Vector2(8, 6)
	por.size = Vector2(180, 160)
	b.add_child(por)
	var nm := UIKit.label(d.name, 24, Color.WHITE, 7, HORIZONTAL_ALIGNMENT_CENTER)
	nm.position = Vector2(0, 160)
	nm.size = Vector2(196, 34)
	b.add_child(nm)
	var info := UIKit.label("LVL %d  ·  %d" % [Save.brawler_level(id), Save.brawler_trophies(id)], 15, UIKit.YELLOW, 5, HORIZONTAL_ALIGNMENT_CENTER)
	info.name = "Info"
	info.position = Vector2(0, 194)
	info.size = Vector2(196, 24)
	b.add_child(info)
	var role := UIKit.label(d.role, 12, rc.lightened(0.4), 4, HORIZONTAL_ALIGNMENT_CENTER)
	role.position = Vector2(0, 8)
	role.size = Vector2(196, 20)
	b.add_child(role)
	if id == Save.data.selected_brawler:
		var tag := UIKit.label("SELECTED", 13, UIKit.GREEN, 5, HORIZONTAL_ALIGNMENT_CENTER)
		tag.name = "Tag"
		tag.position = Vector2(0, 216)
		tag.size = Vector2(196, 20)
		b.add_child(tag)
	return b

func _clear_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()

func _show(id: String) -> void:
	_focus = id
	_clear_detail()
	var d: Dictionary = Config.BRAWLERS[id]
	var lvl := Save.brawler_level(id)
	var m := Config.level_mult(lvl)
	var rc: Color = Config.RARITY_COLORS[d.rarity]

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_detail.add_child(head)
	_detail_portrait = UIKit.BrawlerPortrait.new()
	_detail_portrait.brawler_id = id
	_detail_portrait.art_scale = 2.2
	_detail_portrait.custom_minimum_size = Vector2(190, 190)
	head.add_child(_detail_portrait)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	hv.add_child(UIKit.label(d.name, 42, Color.WHITE, 10))
	hv.add_child(UIKit.label("%s  ·  %s" % [d.rarity, d.role], 17, rc.lightened(0.3), 6))
	hv.add_child(UIKit.label("POWER LEVEL %d / %d   ·   %d TROPHIES" % [lvl, Config.MAX_LEVEL, Save.brawler_trophies(id)], 15, UIKit.YELLOW, 5))
	var tl := UIKit.body('"%s"' % d.tagline, 16, Color(1, 1, 1, 0.95))
	hv.add_child(tl)
	# actions
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	_detail.add_child(actions)
	var cost := Save.upgrade_cost(id)
	var up := UIKit.button("MAX LEVEL" if cost < 0 else "UPGRADE  %d" % cost, UIKit.BLUE, 20, Vector2(250, 62))
	up.disabled = cost < 0 or Save.data.credits < cost
	if cost >= 0 and Save.data.credits < cost:
		up.text = "NEED %d CREDITS" % cost
	up.pressed.connect(func(): _confirm_upgrade(id, cost))
	actions.add_child(up)
	var is_sel: bool = Save.data.selected_brawler == id
	var sel := UIKit.button("SELECTED" if is_sel else "SELECT", UIKit.GREEN, 24, Vector2(250, 62))
	sel.disabled = is_sel
	sel.pressed.connect(func():
		Save.data.selected_brawler = id
		Save.save_game()
		Sfx.play("ui_confirm")
		Router.goto("menu"))
	actions.add_child(sel)
	if Save.upgrade_cost(id) >= 0:
		_detail.add_child(UIKit.body("Each power level adds +%d%% health and damage." % int(Config.UPGRADE_BONUS_PER_LEVEL * 100), 13, Color(1, 1, 1, 0.55)))

	_detail.add_child(UIKit.body(d.bio, 15, Color(1, 1, 1, 0.75)))

	# stats
	var stats := GridContainer.new()
	stats.columns = 3
	stats.add_theme_constant_override("h_separation", 10)
	stats.add_theme_constant_override("v_separation", 8)
	_detail.add_child(stats)
	var a: Dictionary = d.attack
	var speed_name := "VERY FAST" if d.speed >= 265 else ("NORMAL" if d.speed >= 228 else "SLOW")
	_stat(stats, "HEALTH", str(int(d.health * m)), Color("4dff7a"))
	_stat(stats, "DAMAGE", (str(int(a.damage * m)) + (" ×2" if a.kind == "twin_slash" else "")), Color("ff6b6b"))
	_stat(stats, "RANGE", "%.1f tiles" % a.range, Color("8fd0ff"))
	_stat(stats, "AMMO", "%d  ·  %.2fs reload" % [d.ammo, d.reload], Color("ff9d2e"))
	_stat(stats, "SPEED", speed_name, Color("e8c8ff"))
	_stat(stats, "SUPER", "%d hits to charge" % int(ceil(1.0 / a.super_per_hit)), UIKit.YELLOW)

	_ability(Color("ff9d2e"), "ATTACK  ·  " + a.name, a.desc)
	_ability(Color("4fd36a"), "GADGET  ·  " + d.gadget.name + "  (%ds cooldown)" % int(d.gadget.cooldown), d.gadget.desc)
	_ability(UIKit.YELLOW, "SUPER  ·  " + d.super.name, d.super.desc)

func _stat(grid: GridContainer, title: String, value: String, col: Color) -> void:
	var p := PanelContainer.new()
	var sb := UIKit.box(Color(0, 0, 0, 0.35), 12, 2, UIKit.DARK, 0)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.content_margin_left = 10
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(170, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.add_child(UIKit.label(title, 12, Color(1, 1, 1, 0.6), 0))
	v.add_child(UIKit.label(value, 17, col, 5))
	p.add_child(v)
	grid.add_child(p)

func _ability(col: Color, title: String, desc: String) -> void:
	var p := PanelContainer.new()
	var sb := UIKit.box(col.darkened(0.6), 14, 3, col.darkened(0.2), 0)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(UIKit.label(title, 17, col.lightened(0.3), 6))
	v.add_child(UIKit.body(desc, 14))
	p.add_child(v)
	_detail.add_child(p)

func _confirm_upgrade(id: String, cost: int) -> void:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.12, 0.75)
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
	var d: Dictionary = Config.BRAWLERS[id]
	v.add_child(UIKit.label("UPGRADE %s?" % d.name, 32, UIKit.YELLOW, 8, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Level %d  »  %d" % [Save.brawler_level(id), Save.brawler_level(id) + 1], 22, Color.WHITE, 6, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Cost: %d credits   (you have %d)" % [cost, Save.data.credits], 18, Color("ffe08a"), 5, HORIZONTAL_ALIGNMENT_CENTER))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var no := UIKit.button("CANCEL", Color("6b5f86"), 20, Vector2(170, 56))
	no.pressed.connect(o.queue_free)
	h.add_child(no)
	var yes := UIKit.button("UPGRADE", UIKit.GREEN, 20, Vector2(170, 56))
	yes.pressed.connect(func():
		o.queue_free()
		if Save.try_upgrade(id):
			Sfx.play("super_ready", 0.0, 0.0)
			_refresh_after_upgrade(id)
		else:
			Sfx.play("ui_error"))
	h.add_child(yes)
	add_child(o)

func _refresh_after_upgrade(id: String) -> void:
	var lbl: Label = _credits_chip.find_child("Value", true, false)
	if lbl:
		lbl.text = str(Save.data.credits)
	for bid in _cards.keys():
		var info: Label = _cards[bid].get_node("Info")
		info.text = "LVL %d  ·  %d" % [Save.brawler_level(bid), Save.brawler_trophies(bid)]
	_show(id)
	FX.burst(self, Vector2(size.x - 310, 200), UIKit.YELLOW, 30, 400.0, 0.8, 8.0)
