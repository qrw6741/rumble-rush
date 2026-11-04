extends Control
## SHOP. One long sideways strip of tall offer cards grouped into sections
## (OFFERS, DAILY DEALS, SKINS, RESOURCES). The tab bar at the bottom jumps to a
## section and lights up as you scroll. Each card has a countdown tab on top.
## Everything is bought with in-game Credits or Gems (no real money).

const Lobby := preload("res://scripts/ui/main_menu.gd")
const S := preload("res://scripts/ui/main_menu.gd").SlantButton
const SKEW := 16.0
const SECTIONS := ["OFFERS", "DAILY DEALS", "SKINS", "RESOURCES"]

var _scroll: ScrollContainer
var _row: HBoxContainer
var _section_nodes: Dictionary = {}
var _tabs: Array = []
var _chips: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var bg := ColorRect.new()
	bg.color = Color("1f5ad8")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shade := Lobby.LobbyBackground.new()
	shade.modulate = Color(0.55, 0.7, 1.0, 0.45)
	add_child(shade)

	# top bar: dark strip, back, title, currencies, home
	var top := TopStrip.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 74
	add_child(top)
	Lobby.build_header(self, "SHOP", func(): Router.goto("menu"))
	var home := S.new()
	home.color = Color("27334d")
	home.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	home.position = Vector2(-118, 6)
	home.size = Vector2(104, 72)
	home.custom_draw = func(ci: Control):
		UIKit.draw_icon(ci, "home", Vector2(52, 34), 58.0)
	home.pressed.connect(func(): Router.goto("menu"))
	add_child(home)
	var cur := [["token", "tokens", Color("8fd0ff")], ["coin", "credits", Color("ffe08a")], ["gems", "gems", Color("8dff9a")]]
	for i in cur.size():
		var c: Array = cur[i]
		var chip := UIKit.currency_chip(c[0], "", c[2])
		chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		chip.position = Vector2(-640 + i * 170, 16)
		add_child(chip)
		_chips[c[1]] = chip

	# card strip
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = 84
	_scroll.offset_bottom = -66
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 40)
	_scroll.add_child(_row)
	_scroll.get_h_scroll_bar().value_changed.connect(func(_v): _update_tabs())

	# bottom tab bar
	var bar := BottomBar.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -66
	add_child(bar)
	for i in SECTIONS.size():
		var t := TabLabel.new()
		t.text_label = SECTIONS[i]
		t.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		t.position = Vector2(30 + i * 300, -62)
		t.size = Vector2(280, 58)
		var sec: String = SECTIONS[i]
		t.pressed.connect(func(): _jump(sec))
		add_child(t)
		_tabs.append(t)

	_build()
	_refresh_currency()
	if not Save.data.drops.is_empty():
		_open_drops.call_deferred()

func _refresh_currency() -> void:
	(_chips.tokens.find_child("Value", true, false) as Label).text = str(Save.data.pass_tokens)
	(_chips.credits.find_child("Value", true, false) as Label).text = str(Save.data.credits)
	(_chips.gems.find_child("Value", true, false) as Label).text = str(Save.data.gems)

# ------------------------------------------------------------------ build
func _build() -> void:
	var keep := _scroll.scroll_horizontal
	for c in _row.get_children():
		c.queue_free()
	_section_nodes.clear()
	_pad(14)
	var week := _until_week_end()
	var day := _until_midnight()

	# OFFERS: starter pack + featured skin
	var offers := _section("OFFERS", "")
	var sp: Dictionary = Progression.STARTER_PACK.duplicate()
	sp["timer"] = week
	sp["flag"] = "NEW"
	sp["note"] = "One-time offer!"
	_card(offers, sp, "bundle", Color("ff9d2e"), Vector2(320, 520))
	for o in Save.shop_offers():
		if String(o.id).begins_with("deal_skin"):
			var fo: Dictionary = o.duplicate()
			fo["timer"] = day
			fo["title"] = "SPECIAL OFFER"
			fo["old_cost"] = Progression.SKIN_PRICE[o.reward.skin]
			_card(offers, fo, "skin", Color("2a8cff"), Vector2(320, 520))

	# DAILY DEALS: two rows of small cards
	var daily := _section("DAILY DEALS", day)
	var grid := _grid(daily, 2)
	for o in Save.shop_offers():
		if String(o.id).begins_with("deal_skin"):
			continue
		_card(grid, o, "small", Color("8e4dff") if o.currency != "free" else Color("2fb8ec"), Vector2(230, 250))

	# SKINS: tall cards with the 3D model
	var skins := _section("SKINS", "")
	for id in Config.BRAWLER_ORDER:
		for sk in ["gold", "shadow"]:
			var key := "%s:%s" % [id, sk]
			var so := {"id": "skin_%s_%s" % [id, sk], "title": Config.BRAWLERS[id].name, "reward": {"type": "skin", "brawler": id, "skin": sk},
				"currency": "gems", "cost": Progression.SKIN_PRICE[sk], "repeat": true, "owned": key in Save.data.skins_owned}
			_card(skins, so, "skin", Progression.palette(id, sk).primary.darkened(0.15), Vector2(260, 520))

	# RESOURCES: drops + credit packs
	var res := _section("RESOURCES", "")
	var g2 := _grid(res, 2)
	for t in 3:
		var pr: Dictionary = Progression.DROP_PRICES[t]
		_card(g2, {"id": "drop_%d" % t, "title": Progression.DROP_TIERS[t].name + " DROP", "reward": {"type": "drop", "tier": t},
			"currency": pr.currency, "cost": pr.cost, "repeat": true}, "small", Progression.DROP_TIERS[t].color, Vector2(230, 250))
	for p in Progression.GEM_TO_CREDITS:
		_card(g2, {"id": p.id, "title": "CREDITS", "reward": {"type": "credits", "amount": p.credits}, "currency": "gems", "cost": p.gems, "repeat": true},
			"small", Color("e0a020"), Vector2(230, 250))
	_pad(30)
	await get_tree().process_frame
	_scroll.scroll_horizontal = keep
	_update_tabs()

func _pad(w: float) -> void:
	var p := Control.new()
	p.custom_minimum_size = Vector2(w, 0)
	_row.add_child(p)

func _section(title: String, timer: String) -> HBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var head := SectionHead.new()
	head.title = title
	head.timer = timer
	head.custom_minimum_size = Vector2(0, 40)
	v.add_child(head)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	v.add_child(h)
	_row.add_child(v)
	_section_nodes[title] = v
	return h

func _grid(parent: Control, rows: int) -> GridContainer:
	var g := GridContainer.new()
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 20)
	g.set_meta("rows", rows)
	g.columns = 3
	parent.add_child(g)
	return g

func _card(parent: Control, offer: Dictionary, style: String, col: Color, sz: Vector2) -> void:
	var card := OfferCard.new()
	card.offer = offer
	card.style = style
	card.accent = col
	card.custom_minimum_size = sz
	card.pressed.connect(func(): _buy(card))
	parent.add_child(card)
	if style == "skin":
		var r: Dictionary = offer.reward
		var pt := UIKit.BrawlerPortrait.new()
		pt.brawler_id = r.brawler
		pt.skin = r.skin
		pt.view_kind = "showcase"
		pt.backdrop = false
		pt.art_scale = 1.0
		pt.position = Vector2(10, 92)
		pt.size = Vector2(sz.x - 20, sz.y - 200)
		pt.custom_minimum_size = pt.size
		card.add_child(pt)
		card.move_child(pt, 0)
	UIKit.pop_in(card, 0.02 * parent.get_child_count())
	# columns for small-card grids: fill top row then bottom
	if parent is GridContainer:
		var g := parent as GridContainer
		g.columns = maxi(1, int(ceil(g.get_child_count() / float(g.get_meta("rows")))))

# ------------------------------------------------------------------ tabs
func _jump(sec: String) -> void:
	var n: Control = _section_nodes.get(sec)
	if n == null:
		return
	Sfx.play("ui_click")
	var tw := create_tween()
	tw.tween_property(_scroll, "scroll_horizontal", int(maxf(0.0, n.position.x - 20.0)), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _update_tabs() -> void:
	var x := float(_scroll.scroll_horizontal) + 200.0
	var cur := SECTIONS[0]
	for sec in SECTIONS:
		var n: Control = _section_nodes.get(sec)
		if n and n.position.x <= x:
			cur = sec
	for t in _tabs:
		t.on = t.text_label == cur
		t.queue_redraw()

func _until_midnight() -> String:
	var now := Time.get_datetime_dict_from_system()
	var left := 86400 - (int(now.hour) * 3600 + int(now.minute) * 60 + int(now.second))
	return "%dh %dm" % [left / 3600, (left % 3600) / 60]

func _until_week_end() -> String:
	var now := Time.get_datetime_dict_from_system()
	var days_left := (7 - int(now.weekday)) % 7
	var secs := days_left * 86400 + 86400 - (int(now.hour) * 3600 + int(now.minute) * 60)
	return "%dd %dh" % [secs / 86400, (secs % 86400) / 3600]

# ------------------------------------------------------------------ buying
func _buy(card: OfferCard) -> void:
	var o: Dictionary = card.offer
	if card.is_sold():
		Sfx.play("ui_error")
		return
	if not Save.can_afford(o.currency, int(o.cost)):
		Sfx.play("ui_error")
		_toast("Not enough %s!" % ("gems" if o.currency == "gems" else "credits"))
		return
	var once: bool = not o.get("repeat", false)
	if not Save.buy(o.id, o.reward, o.currency, int(o.cost), once):
		Sfx.play("ui_error")
		return
	Sfx.play("ui_confirm")
	FX.burst(self, card.global_position + card.size * 0.5, card.accent.lightened(0.3), 28, 440.0, 0.7, 7.0)
	_refresh_currency()
	if not Save.data.drops.is_empty():
		_open_drops()
	else:
		_toast("Got %s!" % Progression.reward_text(o.reward))
		_build()

func _open_drops() -> void:
	var d := DropOpener.new()
	add_child(d)
	d.finished.connect(func():
		_refresh_currency()
		_build())

func _toast(msg: String) -> void:
	var l := UIKit.label(msg, 30, UIKit.YELLOW, 8, HORIZONTAL_ALIGNMENT_CENTER)
	l.position = Vector2(size.x * 0.5 - 300, size.y - 150)
	l.size = Vector2(600, 50)
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 40, 1.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.6)
	tw.tween_callback(l.queue_free)


# ====================================================================== pieces
class TopStrip extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.02, 0.03, 0.08, 0.85))
		draw_rect(Rect2(0, size.y - 4, size.x, 4), Color(0, 0, 0, 0.5))


class BottomBar extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color("0f1f4a"))
		draw_rect(Rect2(0, 0, size.x, 4), Color("2c4a9a"))


class TabLabel extends Button:
	var text_label := ""
	var on := false
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		S2.text_c(self, text_label, Vector2(size.x * 0.5, 40), 30 if on else 26, UIKit.YELLOW if on else Color("c9d3f0"), 7)


class SectionHead extends Control:
	var title := ""
	var timer := ""
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		S2.text_l(self, title, Vector2(8, 30), 28, Color.WHITE)
		if timer != "":
			var f := UIKit.bold()
			var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			UIKit.draw_icon(self, "clock", Vector2(w + 34, 20), 26.0)
			S2.text_l(self, timer, Vector2(w + 50, 29), 18, Color("c9d3f0"))


## A tall, slightly slanted offer card with a countdown tab and price footer.
class OfferCard extends Button:
	var offer: Dictionary = {}
	var style := "small" # small | bundle | skin
	var accent := Color("ff9d2e")
	var _t := 0.0

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		button_down.connect(func(): pivot_offset = size * 0.5; UIKit._pop(self, 0.95))
		button_up.connect(func(): UIKit._pop(self, 1.0))

	func is_sold() -> bool:
		if offer.get("owned", false):
			return true
		return not offer.get("repeat", false) and Save.shop_bought(offer.id)

	func _process(delta: float) -> void:
		_t += delta
		if offer.get("currency", "") == "free" and not is_sold():
			queue_redraw()

	func _slant(r: Rect2, k: float) -> PackedVector2Array:
		return PackedVector2Array([r.position + Vector2(k, 0), r.end - Vector2(0, r.size.y), r.end - Vector2(k, 0), r.position + Vector2(0, r.size.y)])

	## Horizontal band of the slanted card body between y0 and y1 (edges stay aligned).
	func _band(y0: float, y1: float, k: float, top: float) -> PackedVector2Array:
		var hh := size.y - top
		var lx := func(y: float) -> float: return k * (1.0 - (y - top) / hh)
		var rx := func(y: float) -> float: return size.x - k * (y - top) / hh
		return PackedVector2Array([Vector2(lx.call(y0), y0), Vector2(rx.call(y0), y0), Vector2(rx.call(y1), y1), Vector2(lx.call(y1), y1)])

	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var w := size.x
		var h := size.y
		var ink := UIKit.DARK
		var k := 16.0 if style != "small" else 10.0
		var top := 30.0 if offer.has("timer") else 0.0
		var body := Rect2(0, top, w, h - top)
		# countdown tab + NEW flag
		if offer.has("timer"):
			var tab := Rect2(k + 10, 0, 150, top + 4)
			draw_rect(tab, Color(0.02, 0.03, 0.08, 0.9))
			UIKit.draw_icon(self, "clock", tab.position + Vector2(20, 16), 22.0)
			S2.text_l(self, offer.timer, tab.position + Vector2(36, 24), 18, Color("c9d3f0"))
			if offer.has("flag"):
				draw_colored_polygon(PackedVector2Array([Vector2(170 + k, 2), Vector2(240 + k, 2), Vector2(230 + k, top + 4), Vector2(160 + k, top + 4)]), Color("ff4d3a"))
				S2.text_c(self, offer.flag, Vector2(200 + k, 24), 17, Color.WHITE, 5)
		draw_colored_polygon(_slant(body.grow(4), k), ink)
		draw_colored_polygon(_slant(body, k), accent.darkened(0.15))
		# lighter middle band
		draw_colored_polygon(_band(top + 64, h - 86, k, top), accent.lightened(0.12))
		# title strip
		draw_colored_polygon(_band(top, top + 64, k, top), accent.darkened(0.05))
		draw_colored_polygon(_band(top + 60, top + 64, k, top), Color(0, 0, 0, 0.18))
		S2.text_c(self, offer.get("title", ""), Vector2(w * 0.5, top + 44), 26 if style != "small" else 21, Color.WHITE, 7)
		var r: Dictionary = offer.reward
		match style:
			"bundle":
				var items: Array = r.items
				var cx := [w * 0.3, w * 0.7]
				for i in 2:
					var it: Dictionary = items[i]
					RewardTile.draw_icon(self, it, Vector2(cx[i], top + 150), 46.0)
					_pill(Vector2(cx[i], top + 206), str(it.amount))
				RewardTile.draw_icon(self, items[2], Vector2(w * 0.5, top + 312), 58.0)
				S2.text_c(self, Progression.reward_text(items[2]), Vector2(w * 0.5, top + 262), 20, Color.WHITE, 6)
				_pill(Vector2(w * 0.5, top + 376), "x1")
			"skin":
				S2.text_r(self, Progression.SKINS[r.skin].name, Vector2(w - 24, top + 100), 20, Color.WHITE)
				S2.text_r(self, "SKIN", Vector2(w - 24, top + 122), 17, Color("8fd0ff"))
			_:
				RewardTile.draw_icon(self, r, Vector2(w * 0.5, top + 125), 46.0)
				S2.text_c(self, Progression.reward_text(r), Vector2(w * 0.5, h - 66), 17, Color.WHITE, 5)
		if offer.has("tag") and not is_sold():
			var tp := Vector2(w - 44, h - 100) if style == "bundle" else (Vector2(48, top + 106) if style == "skin" else Vector2(w - 30, top + 84))
			var pts := PackedVector2Array()
			for i in 16:
				var rr := (40.0 if style == "bundle" else 28.0) * (1.0 if i % 2 == 0 else 0.84)
				var a := i * TAU / 16.0
				pts.append(tp + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, Color("e8304a"))
			var tag: String = offer.tag
			var parts := tag.split(" ")
			S2.text_c(self, parts[0], tp + Vector2(0, 4 if parts.size() == 1 else -1), 20 if style == "bundle" else 15, Color.WHITE, 5)
			if parts.size() > 1:
				S2.text_c(self, parts[1], tp + Vector2(0, 18), 13, Color.WHITE, 4)
		# price footer
		draw_colored_polygon(_band(h - 56, h, k, top), Color(0, 0, 0, 0.28) if style != "small" else Color("1d2438"))
		var pc := Vector2(w * 0.5, h - 20)
		if is_sold():
			S2.text_c(self, "OWNED" if offer.get("owned", false) else "CLAIMED", pc, 26, Color(1, 1, 1, 0.6), 6)
			draw_colored_polygon(_slant(body, k), Color(0.05, 0.05, 0.12, 0.35))
			return
		var cur: String = offer.currency
		if cur == "free":
			S2.text_c(self, "FREE", pc, 30, UIKit.YELLOW.lerp(Color.WHITE, 0.2 + 0.2 * sin(_t * 6.0)), 7)
		else:
			var afford := Save.can_afford(cur, int(offer.cost))
			var txt := str(offer.cost)
			var f := UIKit.bold()
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
			var x0 := pc.x - (tw + 40) * 0.5
			if offer.has("old_cost"):
				var ow := f.get_string_size(str(offer.old_cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
				x0 += ow * 0.5 + 8
				var op := Vector2(x0 - ow - 16, pc.y - 2)
				S2.text_l(self, str(offer.old_cost), op, 24, Color(1, 1, 1, 0.7))
				draw_line(op + Vector2(-2, -6), op + Vector2(ow + 2, -14), Color("ff4d5e"), 3.0)
			UIKit.draw_icon(self, "gem" if cur == "gems" else "coin", Vector2(x0 + 16, pc.y - 11), 40.0)
			S2.text_l(self, txt, Vector2(x0 + 40, pc.y), 32, Color.WHITE if afford else Color("ff9a9a"))
		if offer.has("note"):
			S2.text_c(self, offer.note, Vector2(w * 0.5, h - 64), 14, Color(1, 1, 1, 0.8), 4)

	func _pill(c: Vector2, txt: String) -> void:
		var r := Rect2(c - Vector2(56, 22), Vector2(112, 44))
		draw_rect(r.grow(3), UIKit.DARK)
		draw_rect(r, Color("4fd36a"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 10)), Color("8af0a0"))
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		S2.text_c(self, txt, c + Vector2(0, 11), 28, Color.WHITE, 6)
