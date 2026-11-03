extends Control
## RUSH PASS: 30 tiers unlocked with tokens from matches. Free track for everyone,
## Gold track unlocked with credits. Tap a glowing tile to claim it.

const Lobby := preload("res://scripts/ui/main_menu.gd")
const COL_W := 132.0

var _scroll: ScrollContainer
var _row: Control
var _info: Control
var _tiles: Array[RewardTile] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	add_child(Lobby.LobbyBackground.new())
	Lobby.build_header(self, Progression.PASS_NAME, func(): Router.goto("menu"))

	_info = PassInfo.new()
	_info.position = Vector2(20, 96)
	_info.size = Vector2(300, 600)
	add_child(_info)

	var gold_btn := UIKit.button("", UIKit.YELLOW, 20, Vector2(270, 64))
	gold_btn.name = "BuyGold"
	gold_btn.position = Vector2(35, 600)
	add_child(gold_btn)
	_refresh_gold_button(gold_btn)
	gold_btn.pressed.connect(func(): _confirm_gold(gold_btn))

	var claim_all := UIKit.button("CLAIM ALL", UIKit.GREEN, 20, Vector2(200, 56))
	claim_all.name = "ClaimAll"
	claim_all.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	claim_all.position = Vector2(-220, 20)
	claim_all.pressed.connect(_claim_all)
	add_child(claim_all)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(340, 100)
	_scroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_scroll.size = Vector2(get_viewport_rect().size.x - 360, 600)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_row = PassTrack.new()
	_row.custom_minimum_size = Vector2(COL_W * Progression.PASS_TIERS + 40, 580)
	_scroll.add_child(_row)
	for tier in range(1, Progression.PASS_TIERS + 1):
		for track in ["gold", "free"]:
			var t := RewardTile.new()
			t.reward = Progression.pass_reward(tier, track)
			t.frame = Color("c98a1a") if track == "gold" else Color("2a8cff")
			t.size = Vector2(112, 150)
			t.position = Vector2(20 + (tier - 1) * COL_W, 30 if track == "gold" else 330)
			t.set_meta("tier", tier)
			t.set_meta("track", track)
			t.pressed.connect(func(): _claim(t))
			_row.add_child(t)
			_tiles.append(t)
	_refresh()
	await get_tree().process_frame
	_scroll.scroll_horizontal = int(max(0, (Save.pass_tier() - 2) * COL_W))

func _refresh() -> void:
	for t in _tiles:
		var tier: int = t.get_meta("tier")
		var track: String = t.get_meta("track")
		if tier in Save.data.pass_claimed[track]:
			t.state = "claimed"
		elif Save.pass_claimable(tier, track):
			t.state = "claimable"
		else:
			t.state = "locked"
		t.queue_redraw()
	_info.queue_redraw()
	_row.queue_redraw()

func _claim(t: RewardTile) -> void:
	var tier: int = t.get_meta("tier")
	var track: String = t.get_meta("track")
	if Save.claim_pass(tier, track):
		Sfx.play("gem_pickup", 0.0, 0.0)
		FX.burst(self, t.global_position + t.size * 0.5, Color("ffd23a"), 24, 380.0, 0.7, 7.0)
		_refresh()
	elif track == "gold" and not Save.data.gold_pass:
		Sfx.play("ui_error")
		_info.call("flash_hint", "Unlock the GOLD PASS to claim gold rewards")
	else:
		Sfx.play("ui_error")

func _claim_all() -> void:
	var n := 0
	for t in _tiles:
		if Save.claim_pass(t.get_meta("tier"), t.get_meta("track")):
			n += 1
			FX.burst(self, t.global_position + t.size * 0.5, Color("ffd23a"), 12, 300.0, 0.6, 6.0)
	Sfx.play("victory" if n > 0 else "ui_error", -4.0, 0.0)
	_refresh()

func _refresh_gold_button(b: Button) -> void:
	if Save.data.gold_pass:
		b.text = "GOLD PASS ACTIVE"
		b.disabled = true
	else:
		b.text = "GOLD PASS  %d" % Progression.GOLD_PASS_COST

func _confirm_gold(b: Button) -> void:
	if Save.data.gold_pass:
		return
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.14, 0.8)
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
	v.add_child(UIKit.label("UNLOCK GOLD PASS?", 32, UIKit.YELLOW, 8, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.body("Unlocks the gold track for this season: 5 exclusive GOLD skins plus extra credits on every tier. Rewards for tiers you've already reached become claimable straight away.", 16))
	v.add_child(UIKit.label("Cost: %d credits   (you have %d)" % [Progression.GOLD_PASS_COST, Save.data.credits], 18, Color("ffe08a"), 5, HORIZONTAL_ALIGNMENT_CENTER))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	var no := UIKit.button("CANCEL", Color("6b5f86"), 20, Vector2(170, 56))
	no.pressed.connect(o.queue_free)
	h.add_child(no)
	var yes := UIKit.button("UNLOCK", UIKit.GREEN, 20, Vector2(170, 56))
	yes.name = "ConfirmGold"
	yes.disabled = Save.data.credits < Progression.GOLD_PASS_COST
	if yes.disabled:
		yes.text = "NOT ENOUGH"
	yes.pressed.connect(func():
		o.queue_free()
		if Save.buy_gold_pass():
			Sfx.play("victory", -2.0, 0.0)
			_refresh_gold_button(b)
			_refresh()
		else:
			Sfx.play("ui_error"))
	h.add_child(yes)
	add_child(o)


## Left info panel: season, current tier, token progress.
class PassInfo extends Control:
	var _hint := ""
	var _hint_t := 0.0

	func flash_hint(t: String) -> void:
		_hint = t
		_hint_t = 2.5

	func _process(delta: float) -> void:
		if _hint_t > 0.0:
			_hint_t -= delta
			queue_redraw()

	func _draw() -> void:
		var S := preload("res://scripts/ui/main_menu.gd").SlantButton
		var r := Rect2(0, 0, 300, 480)
		draw_rect(r.grow(4), UIKit.DARK)
		draw_rect(r, UIKit.PANEL)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 8)), UIKit.PANEL.lightened(0.15))
		S.text_c(self, Progression.PASS_SEASON, Vector2(150, 40), 16, Color("8fd0ff"))
		var tier := Save.pass_tier()
		S.hexagon(self, Vector2(150, 130), 62.0, Color("ffb52e") if Save.data.gold_pass else Color("2a8cff"), str(tier))
		S.text_c(self, "TIER", Vector2(150, 222), 22, Color.WHITE)
		var into := int(Save.data.pass_tokens) % Progression.TOKENS_PER_TIER
		var maxed := tier >= Progression.PASS_TIERS
		var br := Rect2(Vector2(30, 250), Vector2(240, 30))
		draw_rect(br.grow(3), UIKit.DARK)
		draw_rect(br, Color("1d2438"))
		draw_rect(Rect2(br.position, Vector2(br.size.x * (1.0 if maxed else float(into) / Progression.TOKENS_PER_TIER), br.size.y)), Color("3ea2ff"))
		S.text_c(self, "MAX" if maxed else "%d / %d" % [into, Progression.TOKENS_PER_TIER], br.get_center() + Vector2(0, 9), 20, Color.WHITE)
		S.text_c(self, "Earn tokens by playing matches.", Vector2(150, 320), 15, Color(1, 1, 1, 0.8))
		S.text_c(self, "Wins and KOs earn more!", Vector2(150, 342), 15, Color(1, 1, 1, 0.8))
		S.text_c(self, "GOLD" if Save.data.gold_pass else "FREE", Vector2(150, 410), 30, Color("ffd23a") if Save.data.gold_pass else Color.WHITE)
		S.text_c(self, "pass", Vector2(150, 436), 16, Color(1, 1, 1, 0.7))
		if _hint_t > 0.0:
			S.text_c(self, _hint, Vector2(150, 470), 13, Color("ff9d9d"))


## Draws the tier numbers and the progress line between the two tracks.
class PassTrack extends Control:
	func _draw() -> void:
		var S := preload("res://scripts/ui/main_menu.gd").SlantButton
		var tier := Save.pass_tier()
		S.text_l(self, "GOLD", Vector2(20, 22), 18, Color("ffd23a"))
		S.text_l(self, "FREE", Vector2(20, 320), 18, Color("8fd0ff"))
		var y := 255.0
		var x0 := 20.0 + 56.0
		var x1 := 20.0 + (Progression.PASS_TIERS - 1) * 132.0 + 56.0
		draw_line(Vector2(x0, y), Vector2(x1, y), UIKit.DARK, 16.0)
		draw_line(Vector2(x0, y), Vector2(x1, y), Color("1d2438"), 10.0)
		if tier > 0:
			draw_line(Vector2(x0, y), Vector2(x0 + (tier - 1) * 132.0, y), Color("3ea2ff"), 10.0)
		for i in Progression.PASS_TIERS:
			var c := Vector2(x0 + i * 132.0, y)
			var reached := i + 1 <= tier
			draw_circle(c, 26, UIKit.DARK)
			draw_circle(c, 21, Color("3ea2ff") if reached else Color("4a5570"))
			S.text_c(self, str(i + 1), c + Vector2(0, 8), 22, Color.WHITE)
