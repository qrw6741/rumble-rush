extends Control

const Lobby := preload("res://scripts/ui/main_menu.gd")
## Brawler collection: browse all brawlers, read their kits and stats, upgrade
## them with credits, and pick who you take into battle.

var _focus := ""
var _detail_portrait: UIKit.BrawlerPortrait
var _detail: VBoxContainer
var _cards: Dictionary = {}
var _credits_chip: PanelContainer

const SORTS := ["RARITY", "MOST TROPHIES", "LEAST TROPHIES"]
const RARITY_ORDER := ["RARE", "SUPER RARE", "EPIC", "MYTHIC", "LEGENDARY"]

var _grid: GridContainer
var _search := ""
var _sort := "RARITY"
var _sort_buttons: Dictionary = {}
var _overlay: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var bg := ColorRect.new()
	bg.color = Color("1a5fd6")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shade := Lobby.LobbyBackground.new()
	shade.modulate = Color(0.55, 0.7, 1.0, 0.5)
	add_child(shade)
	_focus = Save.data.selected_brawler

	# back arrow (left) + home (right)
	Lobby.build_header(self, "", func(): Router.goto("menu"))
	var home := Lobby.SlantButton.new()
	home.color = Color("27334d")
	home.name = "Home"
	home.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	home.position = Vector2(-120, 10)
	home.size = Vector2(104, 72)
	home.custom_draw = func(ci: Control):
		UIKit.draw_icon(ci, "home", Vector2(52, 34), 60.0)
	home.pressed.connect(func(): Router.goto("menu"))
	add_child(home)
	_credits_chip = UIKit.currency_chip("coin", str(Save.data.credits), Color("ffe08a"))
	_credits_chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_credits_chip.position = Vector2(-300, 20)
	add_child(_credits_chip)

	# title banner
	var banner := TitleBanner.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.position = Vector2(-150, 14)
	banner.size = Vector2(420, 80)
	add_child(banner)

	# one long scrolling list: unlocked brawlers first, then a LOCKED section
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 60
	scroll.offset_top = 160
	scroll.offset_right = -40
	scroll.offset_bottom = -6
	add_child(scroll)
	_build_filters()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_list)
	_rebuild_grid()

var _list: VBoxContainer
var _sort_btn: Button
var _sort_menu: Control

## Filter row: search box + sort button (opens a small list of sort orders).
func _build_filters() -> void:
	_sort_btn = UIKit.button("SORT: " + _sort, Color("2a8cff"), 18, Vector2(360, 48))
	_sort_btn.position = Vector2(70, 104)
	_sort_btn.pressed.connect(_toggle_sort_menu)
	add_child(_sort_btn)

func _toggle_sort_menu() -> void:
	Sfx.play("ui_click")
	if _sort_menu and is_instance_valid(_sort_menu):
		_sort_menu.queue_free()
		_sort_menu = null
		return
	_sort_menu = PanelContainer.new()
	_sort_menu.add_theme_stylebox_override("panel", UIKit.box(Color("1d2438"), 10, 3, UIKit.DARK, 6))
	_sort_menu.position = Vector2(70, 156)
	_sort_menu.z_index = 20
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_sort_menu.add_child(v)
	for sname in SORTS:
		var on: bool = sname == _sort
		var b := UIKit.button(sname, UIKit.ORANGE if on else Color("3a4a70"), 16, Vector2(340, 42))
		var nm: String = sname
		b.pressed.connect(func():
			_sort = nm
			_sort_btn.text = "SORT: " + nm
			Sfx.play("ui_confirm")
			_sort_menu.queue_free()
			_sort_menu = null
			_rebuild_grid())
		v.add_child(b)
	add_child(_sort_menu)

func _sorted_ids() -> Array:
	var ids: Array = Config.BRAWLER_ORDER.filter(func(id): return _search == "" or Config.BRAWLERS[id].name.contains(_search))
	match _sort:
		"RARITY":
			ids.sort_custom(func(a, b): return RARITY_ORDER.find(Config.BRAWLERS[a].rarity) < RARITY_ORDER.find(Config.BRAWLERS[b].rarity))
		"RARITY DESCENDING":
			ids.sort_custom(func(a, b): return RARITY_ORDER.find(Config.BRAWLERS[a].rarity) > RARITY_ORDER.find(Config.BRAWLERS[b].rarity))
		"MOST TROPHIES":
			ids.sort_custom(func(a, b): return Save.brawler_trophies(a) > Save.brawler_trophies(b))
		"LEAST TROPHIES":
			ids.sort_custom(func(a, b): return Save.brawler_trophies(a) < Save.brawler_trophies(b))
		"CLOSEST TO NEXT RANK":
			ids.sort_custom(func(a, b): return _to_next(a) < _to_next(b))
		"POWER LEVEL":
			ids.sort_custom(func(a, b): return Save.brawler_level(a) > Save.brawler_level(b))
	return ids

func _to_next(id: String) -> int:
	var p := Progression.rank_progress(Save.brawler_trophies(id))
	return 99999 if p.y == 0 else p.y - p.x

func _rebuild_grid() -> void:
	for c in _list.get_children():
		c.queue_free()
	_cards.clear()
	var owned: Array = []
	var locked: Array = []
	for id in _sorted_ids():
		if Save.is_unlocked(id):
			owned.append(id)
		else:
			locked.append(id)
	_section(owned, "", 0)
	if not locked.is_empty():
		var h := SectionLabel.new()
		h.text = "LOCKED  %d" % locked.size()
		h.custom_minimum_size = Vector2(0, 54)
		_list.add_child(h)
		_section(locked, "", owned.size())

func _section(ids: Array, _title: String, delay_from: int) -> void:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 18)
	_list.add_child(g)
	var k := delay_from
	for id in ids:
		var card := _make_card(id)
		_cards[id] = card
		g.add_child(card)
		UIKit.pop_in(card, 0.03 * k)
		k += 1

func _make_card(id: String) -> Control:
	var card := BrawlerCard.new()
	card.brawler_id = id
	card.name = "Card_" + id
	card.custom_minimum_size = Vector2(272, 214)
	card.pressed.connect(func():
		Sfx.play("ui_click")
		_show(id))
	var por := UIKit.BrawlerPortrait.new()
	por.brawler_id = id
	por.art_scale = 1.0
	por.backdrop = false
	por.view_kind = "bust"
	por.position = Vector2(6, 38)
	por.size = Vector2(260, 128)
	por.custom_minimum_size = Vector2(260, 128)
	por.clip_contents = true
	if not Save.is_unlocked(id):
		por.modulate = Color(0.45, 0.45, 0.55)
	card.add_child(por)
	var front := CardFront.new()
	front.brawler_id = id
	front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(front)
	return card

## Detail sheet opens as an overlay on top of the grid.
func _open_overlay() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.15, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var panel := UIKit.panel(UIKit.PANEL)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(640, 640)
	panel.size = Vector2(640, 640)
	panel.position = Vector2(-320, -330)
	_overlay.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	scroll.add_child(_detail)
	var close := UIKit.button("X", UIKit.RED, 26, Vector2(60, 60))
	close.name = "CloseDetail"
	close.set_anchors_preset(Control.PRESET_CENTER)
	close.position = Vector2(290, -350)
	close.pressed.connect(func():
		_overlay.queue_free()
		_overlay = null)
	_overlay.add_child(close)
	add_child(_overlay)

func _clear_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()

func _show(id: String) -> void:
	_focus = id
	_open_overlay()
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
	if not Save.is_unlocked(id):
		var u: Dictionary = Config.BRAWLERS[id].get("unlock", {})
		var cur: String = u.get("currency", "credits")
		var ub: Button
		if cur == "pass":
			ub = UIKit.button("REACH RUSH PASS TIER %d" % int(u.cost), Color("8e2bd8"), 20, Vector2(420, 62))
			ub.pressed.connect(func(): Router.goto("pass"))
		else:
			var label := "UNLOCK  %d %s" % [int(u.cost), "GEMS" if cur == "gems" else "CREDITS"]
			ub = UIKit.button(label, UIKit.GREEN, 22, Vector2(420, 62))
			ub.disabled = not Save.can_afford(cur, int(u.cost))
			if ub.disabled:
				ub.text = "NEED %d %s" % [int(u.cost), "GEMS" if cur == "gems" else "CREDITS"]
			ub.pressed.connect(func():
				if Save.unlock_brawler(id):
					Sfx.play("victory", -2.0, 0.0)
					Save.data.selected_brawler = id
					Save.save_game()
					Router.goto("select")
				else:
					Sfx.play("ui_error"))
		actions.add_child(ub)
		_detail.add_child(UIKit.body(d.bio, 15, Color(1, 1, 1, 0.75)))
		return
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

	# rank row
	var rank_row := HBoxContainer.new()
	rank_row.add_theme_constant_override("separation", 12)
	_detail.add_child(rank_row)
	var rb := RankBar.new()
	rb.brawler_id = id
	rb.custom_minimum_size = Vector2(300, 64)
	rank_row.add_child(rb)
	var pending := Save.rank_unclaimed(id)
	var rr := UIKit.button("RANK REWARDS", UIKit.YELLOW if pending > 0 else UIKit.PANEL_LIGHT, 17, Vector2(200, 60))
	rr.name = "RankRewards"
	rr.pressed.connect(func(): _open_ranks(id))
	rank_row.add_child(rr)
	if pending > 0:
		var dot := RewardTile.Dot.new()
		dot.count = pending
		dot.position = Vector2(176, -12)
		rr.add_child(dot)

	# skins row
	var skins_row := HBoxContainer.new()
	skins_row.add_theme_constant_override("separation", 10)
	_detail.add_child(skins_row)
	skins_row.add_child(UIKit.label("SKINS", 18, Color.WHITE, 6))
	for sk in ["", "gold", "shadow"]:
		var owned: bool = Save.owns_skin(id, sk)
		var is_sel_skin: bool = Save.selected_skin(id) == sk
		var nm: String = "DEFAULT" if sk == "" else Progression.SKINS[sk].name
		var col: Color = Color("2a8cff") if sk == "" else Progression.SKINS[sk].primary.darkened(0.15)
		var b := UIKit.button(nm if owned else nm + " (LOCKED)", col if owned else Color("4a5570"), 14, Vector2(120 if owned else 150, 44))
		if is_sel_skin:
			b.add_theme_stylebox_override("normal", UIKit.box(col, 18, 5, Color("4dff7a")))
		b.disabled = not owned
		b.tooltip_text = "" if owned else "Earn it from the Rush Pass or Trophy Road"
		b.pressed.connect(func():
			if Save.select_skin(id, sk):
				Sfx.play("ui_confirm")
				Router.goto("select"))
		skins_row.add_child(b)

	_detail.add_child(UIKit.body(d.bio, 15, Color(1, 1, 1, 0.75)))

	# stats
	var stats := GridContainer.new()
	stats.columns = 3
	stats.add_theme_constant_override("h_separation", 10)
	stats.add_theme_constant_override("v_separation", 8)
	_detail.add_child(stats)
	var a: Dictionary = d.attack
	var speed_name := "VERY FAST" if d.speed >= 200 else ("NORMAL" if d.speed >= 168 else "SLOW")
	_stat(stats, "HEALTH", str(int(d.health * m)), Color("4dff7a"))
	_stat(stats, "DAMAGE", (str(int(a.damage * m)) + (" ×2" if a.kind == "twin_slash" else "")), Color("ff6b6b"))
	_stat(stats, "RANGE", "%.1f tiles" % a.range, Color("8fd0ff"))
	_stat(stats, "AMMO", "%d  ·  %.2fs reload" % [d.ammo, d.reload], Color("ff9d2e"))
	_stat(stats, "SPEED", speed_name, Color("e8c8ff"))
	_stat(stats, "SUPER", "%d hits to charge" % int(ceil(1.0 / a.super_per_hit)), UIKit.YELLOW)

	_ability(Color("ff9d2e"), "ATTACK  ·  " + a.name, a.desc, "ab_%s_attack" % id)
	_ability(Color("4fd36a"), "GADGET  ·  " + d.gadget.name + "  (%ds cooldown)" % int(d.gadget.cooldown), d.gadget.desc, "ab_%s_gadget" % id)
	_ability(UIKit.YELLOW, "SUPER  ·  " + d.super.name, d.super.desc, "ab_%s_super" % id)

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

func _ability(col: Color, title: String, desc: String, icon_name := "") -> void:
	var p := PanelContainer.new()
	var sb := UIKit.box(col.darkened(0.6), 14, 3, col.darkened(0.2), 0)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	if icon_name != "":
		var ic := TextureRect.new()
		ic.texture = UIKit.icon(icon_name)
		ic.custom_minimum_size = Vector2(58, 58)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(title, 17, col.lightened(0.3), 6))
	v.add_child(UIKit.body(desc, 14))
	row.add_child(v)
	p.add_child(row)
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
	_rebuild_grid()
	_show(id)
	FX.burst(self, size * 0.5, UIKit.YELLOW, 30, 400.0, 0.8, 8.0)


## Collection card frame (the portrait and the front decorations are children).
class BrawlerCard extends Button:
	var brawler_id := "bront"

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		pivot_offset = custom_minimum_size * 0.5
		mouse_entered.connect(func(): UIKit._pop(self, 1.03))
		mouse_exited.connect(func(): UIKit._pop(self, 1.0))
		button_down.connect(func(): UIKit._pop(self, 0.96))
		button_up.connect(func(): UIKit._pop(self, 1.0))

	func _draw() -> void:
		var d: Dictionary = Config.BRAWLERS[brawler_id]
		var rc: Color = Config.RARITY_COLORS[d.rarity]
		var w := size.x
		var h := size.y
		var ink := UIKit.DARK
		var sel: bool = Save.data.selected_brawler == brawler_id
		draw_rect(Rect2(4, 8, w, h), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(0, 0, w, h), UIKit.YELLOW if sel else ink)
		draw_rect(Rect2(3, 3, w - 6, h - 6), Color("1d2438"))
		# portrait window: rarity colour with a soft diagonal light
		var win := Rect2(6, 38, w - 12, 128)
		draw_rect(win, rc.lerp(Color("bfe4ff"), 0.35))
		draw_colored_polygon(PackedVector2Array([win.position, win.position + Vector2(win.size.x * 0.55, 0), win.position + Vector2(win.size.x * 0.25, win.size.y), win.position + Vector2(0, win.size.y)]), Color(1, 1, 1, 0.18))


## Everything drawn over the portrait: rank, trophies, name, power and the upgrade bar.
class CardFront extends Control:
	var brawler_id := "bront"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var S := preload("res://scripts/ui/main_menu.gd").SlantButton
		var d: Dictionary = Config.BRAWLERS[brawler_id]
		var w := size.x
		var ink := UIKit.DARK
		var bt := Save.brawler_trophies(brawler_id)
		var rank := Progression.rank_for(bt)
		var lvl := Save.brawler_level(brawler_id)
		var unlocked := Save.is_unlocked(brawler_id)
		# top strip with trophies
		var strip := Rect2(46, 6, w - 52, 28)
		draw_rect(strip, Color("e8692a"))
		draw_rect(Rect2(strip.position, Vector2(strip.size.x, 7)), Color("ff9a4a"))
		S.trophy(self, Vector2(strip.position.x + strip.size.x * 0.42, 20), 8.0)
		S.text_l(self, str(bt), Vector2(strip.position.x + strip.size.x * 0.42 + 16, 29), 22, Color.WHITE)
		UIKit.draw_rank_badge(self, Vector2(28, 26), 54.0, rank)
		# name + power over the bottom of the portrait
		var band := Rect2(6, 136, w - 12, 30)
		draw_rect(band, Color(0.05, 0.04, 0.12, 0.55))
		S.text_l(self, d.name, Vector2(14, 160), 22, Color.WHITE)
		if unlocked:
			S.text_r(self, "POWER", Vector2(w - 40, 157), 14, Color(1, 1, 1, 0.85))
			S.text_r(self, str(lvl), Vector2(w - 14, 161), 24, Color.WHITE)
		# bottom bar
		var bar := Rect2(44, 176, w - 56, 28)
		draw_rect(bar.grow(3), ink)
		var ic := Vector2(28, 190)
		if not unlocked:
			draw_colored_polygon(PackedVector2Array([Vector2(6, 38), Vector2(w - 6, 38), Vector2(w - 6, 166), Vector2(6, 166)]), Color(0.05, 0.04, 0.12, 0.25))
			UIKit.draw_icon(self, "lock", Vector2(w * 0.5, 92), 54.0)
			var u: Dictionary = d.get("unlock", {})
			var cur: String = u.get("currency", "credits")
			draw_rect(bar, Color("8e2bd8") if cur == "pass" else Color("2f3d5c"))
			draw_circle(ic, 18, ink)
			draw_circle(ic, 15, Color("8e2bd8") if cur == "pass" else Color("3a4a70"))
			if cur == "pass":
				UIKit.draw_icon(self, "token", ic, 26.0)
				S.text_c(self, "RUSH PASS TIER %d" % int(u.cost), bar.get_center() + Vector2(0, 8), 16, Color.WHITE)
			else:
				UIKit.draw_icon(self, "gem" if cur == "gems" else "coin", ic, 26.0)
				S.text_c(self, str(u.cost), bar.get_center() + Vector2(0, 9), 22, Color.WHITE)
			return
		var cost := Save.upgrade_cost(brawler_id)
		draw_circle(ic, 18, ink)
		draw_circle(ic, 15, Color("d22bd8"))
		UIKit.draw_icon(self, "coin", ic, 24.0)
		if cost < 0:
			draw_rect(bar, Color("8e2bd8"))
			S.text_c(self, "MAX POWER", bar.get_center() + Vector2(0, 8), 18, Color.WHITE)
		elif Save.data.credits >= cost:
			draw_rect(bar, Color("3fc94a"))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x, 7)), Color("7af07a"))
			var ac := Vector2(bar.position.x + 18, bar.get_center().y)
			draw_colored_polygon(PackedVector2Array([ac + Vector2(0, -9), ac + Vector2(8, 0), ac + Vector2(3, 0), ac + Vector2(3, 8), ac + Vector2(-3, 8), ac + Vector2(-3, 0), ac + Vector2(-8, 0)]), Color.WHITE)
			S.text_c(self, "UPGRADE", bar.get_center() + Vector2(6, 8), 20, Color.WHITE)
		else:
			draw_rect(bar, Color("3a2a50"))
			var frac := clampf(float(Save.data.credits) / cost, 0.0, 1.0)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color("d24bd8"))
			S.text_c(self, "%d/%d" % [mini(Save.data.credits, cost), cost], bar.get_center() + Vector2(0, 8), 18, Color.WHITE)
		if Save.data.selected_brawler == brawler_id:
			S.text_l(self, "SELECTED", Vector2(14, 58), 14, Color("4dff7a"))

	func _ability_icon(c: Vector2, col: Color, letter: String) -> void:
		var S := preload("res://scripts/ui/main_menu.gd").SlantButton
		draw_circle(c, 16, UIKit.DARK)
		draw_circle(c, 13, col.darkened(0.15))
		draw_circle(c, 8, col)
		S.text_c(self, letter, c + Vector2(0, 6), 14, Color.WHITE, 4)


## "BRAWLERS 5/5" title banner.
class TitleBanner extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var S := preload("res://scripts/ui/main_menu.gd").SlantButton
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r.grow(4), UIKit.DARK)
		draw_rect(r, Color("dff4ff"))
		draw_rect(r.grow(-6), Color("5cc8ff"))
		draw_rect(Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, 18)), Color("8fdcff"))
		var n := Config.BRAWLER_ORDER.size()
		S.text_l(self, "BRAWLERS", Vector2(28, 58), 40, Color("2a8cff"))
		S.text_l(self, "%d/%d" % [Save.data.unlocked.size(), n], Vector2(290, 58), 40, Color("ffe14d"))


## Sidebar sort option with an on/off pill.
class SortToggle extends Button:
	var label := ""
	var on := false

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())

	func _draw() -> void:
		var S := preload("res://scripts/ui/main_menu.gd").SlantButton
		var w := size.x
		var h := size.y
		draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(w - 30, 0), Vector2(w - 36, h), Vector2(0, h)]), Color("0d1426"))
		S.text_c(self, label, Vector2((w - 40) * 0.5, h * 0.5 + 7), 15 if label.length() < 16 else 13, Color.WHITE)
		var pc := Vector2(w - 26, h * 0.5)
		draw_circle(pc, 20, UIKit.DARK)
		draw_circle(pc, 16, Color("ff8a1a") if on else Color("2f3d5c"))


func _open_ranks(id: String) -> void:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.14, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(c)
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(1140, 600)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var d: Dictionary = Config.BRAWLERS[id]
	v.add_child(UIKit.label("%s  RANK REWARDS" % d.name, 32, UIKit.YELLOW, 8, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.body("Win matches with %s to earn trophies and climb ranks. Every rank-up gives a reward." % d.name, 15))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1090, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var tiles: Array = []
	for r in range(2, Progression.MAX_RANK + 1):
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		var hdr := UIKit.label("RANK %d · %d" % [r, Progression.RANK_TROPHIES[r - 1]], 12, Progression.rank_color(r).lightened(0.3), 4, HORIZONTAL_ALIGNMENT_CENTER)
		cell.add_child(hdr)
		var t := RewardTile.new()
		t.reward = Progression.rank_reward(r)
		t.frame = Progression.rank_color(r).darkened(0.35)
		t.custom_minimum_size = Vector2(112, 110)
		t.size = Vector2(112, 110)
		t.set_meta("rank", r)
		cell.add_child(t)
		grid.add_child(cell)
		tiles.append(t)
	var refresh := func():
		for t in tiles:
			var rk: int = t.get_meta("rank")
			if rk in Save.data.rank_claimed[id]:
				t.state = "claimed"
			elif Save.rank_claimable(id, rk):
				t.state = "claimable"
			else:
				t.state = "locked"
			t.queue_redraw()
	for t in tiles:
		t.pressed.connect(func():
			if Save.claim_rank(id, t.get_meta("rank")):
				Sfx.play("gem_pickup", 0.0, 0.0)
				FX.burst(o, t.global_position + t.size * 0.5, Color("ffd23a"), 20, 340.0, 0.6, 6.0)
				refresh.call()
			else:
				Sfx.play("ui_error"))
	refresh.call()
	var close := UIKit.button("DONE", UIKit.GREEN, 22, Vector2(260, 56))
	close.name = "RanksDone"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func():
		o.queue_free()
		Router.goto("select"))
	v.add_child(close)
	add_child(o)


## Rank shield + trophies-to-next-rank bar.
class RankBar extends Control:
	var brawler_id := "bront"

	func _draw() -> void:
		var S := preload("res://scripts/ui/main_menu.gd").SlantButton
		var bt := Save.brawler_trophies(brawler_id)
		var rank := Progression.rank_for(bt)
		var col := Progression.rank_color(rank)
		UIKit.draw_rank_badge(self, Vector2(32, 34), 64.0, rank)
		var prog := Progression.rank_progress(bt)
		var br := Rect2(Vector2(72, 30), Vector2(220, 24))
		draw_rect(br.grow(3), UIKit.DARK)
		draw_rect(br, Color("1d2438"))
		var frac := 1.0 if prog.y == 0 else float(prog.x) / prog.y
		draw_rect(Rect2(br.position, Vector2(br.size.x * frac, br.size.y)), Color("ff9d2e"))
		var txt := "MAX RANK" if prog.y == 0 else "%d / %d" % [bt, Progression.RANK_TROPHIES[rank]]
		S.text_c(self, txt, br.get_center() + Vector2(0, 7), 16, Color.WHITE)
		S.text_l(self, "RANK %d" % rank, Vector2(72, 22), 18, col.lightened(0.3))


## "LOCKED" divider between the two groups.
class SectionLabel extends Control:
	var text := ""
	func _draw() -> void:
		var S := preload("res://scripts/ui/main_menu.gd").SlantButton
		draw_rect(Rect2(0, 22, size.x, 4), Color(1, 1, 1, 0.2))
		var f := UIKit.bold()
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_rect(Rect2(size.x * 0.5 - tw * 0.5 - 22, 4, tw + 44, 42), Color("1d2438"))
		UIKit.draw_icon(self, "lock", Vector2(size.x * 0.5 - tw * 0.5 - 2, 24), 30.0)
		S.text_l(self, text, Vector2(size.x * 0.5 - tw * 0.5 + 18, 36), 30, Color.WHITE)
