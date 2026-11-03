extends Control
## SHOP: daily deals (refresh every day), reward drops, skins and credit packs.
## Everything is bought with in-game Credits or Gems (no real money).

const Lobby := preload("res://scripts/ui/main_menu.gd")
const S := preload("res://scripts/ui/main_menu.gd").SlantButton

var _row: HBoxContainer
var _coins: PanelContainer
var _gems: PanelContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	add_child(Lobby.LobbyBackground.new())
	Lobby.build_header(self, "SHOP", func(): Router.goto("menu"))
	_coins = UIKit.currency_chip("coin", "", UIKit.YELLOW)
	_coins.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_coins.position = Vector2(-420, 22)
	add_child(_coins)
	_gems = UIKit.currency_chip("gems", "", Color("8dff9a"))
	_gems.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_gems.position = Vector2(-210, 22)
	add_child(_gems)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 100
	scroll.offset_bottom = -12
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 34)
	scroll.add_child(_row)
	_build()
	_refresh_currency()
	if not Save.data.drops.is_empty():
		_open_drops.call_deferred()

func _refresh_currency() -> void:
	(_coins.find_child("Value", true, false) as Label).text = str(Save.data.credits)
	(_gems.find_child("Value", true, false) as Label).text = str(Save.data.gems)

func _build() -> void:
	for c in _row.get_children():
		c.queue_free()
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(10, 0)
	_row.add_child(pad)
	# --- daily deals
	var deals: Array = []
	for o in Save.shop_offers():
		deals.append(o)
	_section("DAILY DEALS", "New deals every day", Color("ff9d2e"), deals, 2)
	# --- drops
	var drops: Array = []
	for t in 3:
		var pr: Dictionary = Progression.DROP_PRICES[t]
		drops.append({"id": "drop_%d" % t, "title": Progression.DROP_TIERS[t].name + " DROP", "reward": {"type": "drop", "tier": t},
			"currency": pr.currency, "cost": pr.cost, "repeat": true})
	_section("REWARD DROPS", "Open to win credits, gems or skins", Color("8e4dff"), drops, 2)
	# --- skins
	var skins: Array = []
	for id in Config.BRAWLER_ORDER:
		for sk in ["gold", "shadow"]:
			var owned: bool = ("%s:%s" % [id, sk]) in Save.data.skins_owned
			skins.append({"id": "skin_%s_%s" % [id, sk], "title": Config.BRAWLERS[id].name, "reward": {"type": "skin", "brawler": id, "skin": sk},
				"currency": "gems", "cost": Progression.SKIN_PRICE[sk], "repeat": true, "owned": owned})
	_section("SKINS", "Look your best in battle", Color("ff4d9a"), skins, 2)
	# --- credits
	var packs: Array = []
	for p in Progression.GEM_TO_CREDITS:
		packs.append({"id": p.id, "title": "CREDITS", "reward": {"type": "credits", "amount": p.credits}, "currency": "gems", "cost": p.gems, "repeat": true})
	_section("CREDITS", "Trade gems for credits", Color("2a8cff"), packs, 2)
	var pad2 := Control.new()
	pad2.custom_minimum_size = Vector2(20, 0)
	_row.add_child(pad2)

func _section(title: String, sub: String, col: Color, offers: Array, rows: int) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(UIKit.label(title, 30, Color.WHITE, 8))
	var sl := UIKit.label(sub, 16, Color(1, 1, 1, 0.65), 5)
	sl.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(sl)
	v.add_child(head)
	var g := GridContainer.new()
	g.columns = int(ceil(offers.size() / float(rows)))
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	for i in offers.size():
		var card := ShopCard.new()
		card.offer = offers[i]
		card.accent = col
		card.custom_minimum_size = Vector2(230, 262) if offers.size() <= 4 else Vector2(178, 262)
		card.pressed.connect(func(): _buy(card))
		g.add_child(card)
		UIKit.pop_in(card, 0.03 * i)
	v.add_child(g)
	_row.add_child(v)

func _buy(card: ShopCard) -> void:
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
	FX.burst(self, card.global_position + card.size * 0.5, card.accent, 26, 420.0, 0.7, 7.0)
	_refresh_currency()
	if o.reward.get("type", "") == "drop":
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
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l.position.y -= 90
	l.position.x -= 300
	l.size = Vector2(600, 50)
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 40, 1.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.6)
	tw.tween_callback(l.queue_free)


## One offer card: title strip, big prize art, price bar.
class ShopCard extends Button:
	var offer: Dictionary = {}
	var accent := Color("ff9d2e")
	var _t := 0.0

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		pivot_offset = custom_minimum_size * 0.5
		button_down.connect(func(): UIKit._pop(self, 0.94))
		button_up.connect(func(): UIKit._pop(self, 1.0))

	func is_sold() -> bool:
		if offer.get("owned", false):
			return true
		return not offer.get("repeat", false) and Save.shop_bought(offer.id)

	func _process(delta: float) -> void:
		_t += delta
		if offer.get("currency", "") == "free" and not is_sold():
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var ink := UIKit.DARK
		var r: Dictionary = offer.reward
		var bg := accent.darkened(0.35)
		if r.get("type", "") == "skin":
			bg = Progression.palette(r.brawler, r.skin).primary.darkened(0.45)
		draw_rect(Rect2(4, 8, w, h), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(0, 0, w, h), ink)
		draw_rect(Rect2(4, 4, w - 8, h - 8), bg)
		draw_rect(Rect2(4, 44, w - 8, (h - 108) * 0.5), Color(1, 1, 1, 0.05))
		draw_rect(Rect2(4, 4, w - 8, 40), accent)
		draw_rect(Rect2(4, 4, w - 8, 8), accent.lightened(0.25))
		S.text_c(self, offer.get("title", ""), Vector2(w * 0.5, 34), 20 if w > 200 else 17, Color.WHITE, 6)
		if r.get("type", "") == "skin":
			var view_c := Vector2(w * 0.5, h * 0.45)
			UIKit.draw_icon(self, "skin", view_c, 110.0, Progression.palette(r.brawler, r.skin).primary.lerp(Color.WHITE, 0.3))
			S.text_c(self, Progression.SKINS[r.skin].name + " SKIN", Vector2(w * 0.5, h - 82), 17, Color.WHITE, 5)
		else:
			RewardTile.draw_icon(self, r, Vector2(w * 0.5, h * 0.44), 56.0)
			S.text_c(self, Progression.reward_text(r), Vector2(w * 0.5, h - 82), 18 if w > 200 else 15, Color.WHITE, 5)
		if offer.has("tag") and not is_sold():
			var tp := Vector2(w - 34, 62)
			draw_circle(tp, 28, ink)
			draw_circle(tp, 24, Color("ff3b3b"))
			S.text_c(self, offer.tag, tp + Vector2(0, 7), 16, Color.WHITE)
		# price bar
		var pb := Rect2(14, h - 58, w - 28, 44)
		draw_rect(pb.grow(3), ink)
		if is_sold():
			draw_rect(pb, Color("4a5470"))
			S.text_c(self, "OWNED" if offer.get("owned", false) else "BOUGHT", pb.get_center() + Vector2(0, 9), 22, Color(1, 1, 1, 0.7), 5)
			draw_rect(Rect2(4, 4, w - 8, h - 8), Color(0, 0, 0, 0.3))
			return
		var cur: String = offer.currency
		var afford := Save.can_afford(cur, int(offer.cost))
		var pc := UIKit.GREEN if afford else Color("6b5f86")
		if cur == "free":
			pc = UIKit.YELLOW.lerp(Color.WHITE, 0.15 + 0.15 * sin(_t * 6.0))
		draw_rect(pb, pc)
		draw_rect(Rect2(pb.position, Vector2(pb.size.x, 8)), pc.lightened(0.25))
		if cur == "free":
			S.text_c(self, "FREE", pb.get_center() + Vector2(0, 10), 26, Color.WHITE, 6)
		else:
			var txt := str(offer.cost)
			var f := UIKit.bold()
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			var x0 := pb.get_center().x - (tw + 36) * 0.5
			UIKit.draw_icon(self, "gem" if cur == "gems" else "coin", Vector2(x0 + 14, pb.get_center().y), 40.0)
			S.text_l(self, txt, Vector2(x0 + 36, pb.get_center().y + 10), 26, Color.WHITE)
