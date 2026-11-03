extends Control

const Lobby := preload("res://scripts/ui/main_menu.gd")
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
	add_child(preload("res://scripts/ui/main_menu.gd").LobbyBackground.new())
	_focus = Save.data.selected_brawler

	Lobby.build_header(self, "BRAWLERS", func(): Router.goto("menu"))
	_credits_chip = UIKit.currency_chip("coin", str(Save.data.credits), Color("ffe08a"))
	_credits_chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_credits_chip.position = Vector2(-200, 18)
	add_child(_credits_chip)

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
	var panel := UIKit.panel(UIKit.PANEL)
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
	var card := BrawlerCard.new()
	card.brawler_id = id
	card.custom_minimum_size = Vector2(196, 238)
	card.pressed.connect(func():
		Sfx.play("ui_click")
		_show(id))
	var por := UIKit.BrawlerPortrait.new()
	por.brawler_id = id
	por.art_scale = 1.75
	por.backdrop = false
	por.position = Vector2(10, 22)
	por.size = Vector2(176, 160)
	por.custom_minimum_size = Vector2(176, 160)
	card.add_child(por)
	var info := Label.new()
	info.name = "Info"
	info.visible = false
	card.add_child(info)
	return card

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
	var up := UIKit.button("MAX LEVEL" if cost < 0 else "UPGRADE  %d" % cost, UIKit.YELLOW, 20, Vector2(250, 62))
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
		_cards[bid].queue_redraw()
	_show(id)
	FX.burst(self, Vector2(size.x - 310, 200), UIKit.YELLOW, 30, 400.0, 0.8, 8.0)


## Collection card: rarity-coloured tile, power hex, trophy count, name banner.
class BrawlerCard extends Button:
	var brawler_id := "bront"

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		mouse_entered.connect(func(): UIKit._pop(self, 1.04))
		mouse_exited.connect(func(): UIKit._pop(self, 1.0))
		button_down.connect(func(): UIKit._pop(self, 0.95))
		button_up.connect(func(): UIKit._pop(self, 1.0))

	func _draw() -> void:
		var d: Dictionary = Config.BRAWLERS[brawler_id]
		var rc: Color = Config.RARITY_COLORS[d.rarity]
		var w := size.x
		var h := size.y
		var ink := UIKit.DARK
		var sel: bool = Save.data.selected_brawler == brawler_id
		draw_rect(Rect2(4, 8, w, h), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(0, 0, w, h), Color("ffd23a") if sel else ink)
		var inner := Rect2(4, 4, w - 8, h - 8)
		# rarity gradient background
		for i in 8:
			var k := float(i) / 8.0
			draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y * k, inner.size.x, inner.size.y / 8.0 + 1), rc.lightened(0.15).lerp(rc.darkened(0.35), k))
		# light rays
		var c := inner.get_center() + Vector2(0, -20)
		for i in 8:
			var a := i * TAU / 8.0
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a), sin(a)) * 150, c + Vector2(cos(a + 0.25), sin(a + 0.25)) * 150]), Color(1, 1, 1, 0.07))
		# name banner
		var banner := Rect2(inner.position.x, inner.end.y - 48, inner.size.x, 48)
		draw_rect(banner, Color("1d2438"))
		draw_rect(Rect2(banner.position, Vector2(banner.size.x, 3)), ink)
		Lobby.SlantButton.text_c(self, d.name, Vector2(w * 0.5, banner.end.y - 15), 24, Color.WHITE)
		# power hex
		Lobby.SlantButton.hexagon(self, Vector2(26, 28), 20.0, Color("ffb52e").darkened(0.1), str(Save.brawler_level(brawler_id)))
		# trophies
		Lobby.SlantButton.trophy(self, Vector2(w - 62, 24), 9.0)
		Lobby.SlantButton.text_l(self, str(Save.brawler_trophies(brawler_id)), Vector2(w - 48, 34), 20, Color.WHITE)
		if sel:
			Lobby.SlantButton.text_c(self, "SELECTED", Vector2(w * 0.5, banner.position.y - 6), 14, Color("4dff7a"))
