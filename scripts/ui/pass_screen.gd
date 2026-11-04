extends Control
## RUSH PASS. Season banner, REWARDS / QUESTS tabs, token progress bar with the
## season timer, and two reward tracks (GOLD on top, FREE below) with the tier
## numbers running between them. Some gold tiers are brawler challenges.

const Lobby := preload("res://scripts/ui/main_menu.gd")
const S := preload("res://scripts/ui/main_menu.gd").SlantButton
const COL_W := 176.0
const LEFT_W := 300.0

var _tab := "REWARDS"
var _scroll: ScrollContainer
var _track: Control
var _quests: HBoxContainer
var _tiles: Array = []
var _tabs: Dictionary = {}
var _hint: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var bg := ColorRect.new()
	bg.color = Color("2a2a9a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shade := Lobby.LobbyBackground.new()
	shade.modulate = Color(0.6, 0.55, 1.0, 0.35)
	add_child(shade)

	var frame := Frame.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)

	# reward tracks
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = LEFT_W - 40
	_scroll.offset_top = 162
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_track = TrackBg.new()
	_track.custom_minimum_size = Vector2(70 + COL_W * Progression.PASS_TIERS + 60, 540)
	_scroll.add_child(_track)
	for tier in range(1, Progression.PASS_TIERS + 1):
		for track in ["gold", "free"]:
			var t := PassTile.new()
			t.tier = tier
			t.track = track
			t.reward = Progression.pass_reward(tier, track)
			t.position = Vector2(70 + (tier - 1) * COL_W, 18 if track == "gold" else 312)
			t.size = Vector2(158, 196)
			t.pressed.connect(func(): _claim(t))
			_track.add_child(t)
			_tiles.append(t)
			if t.reward.has("challenge"):
				var c: Dictionary = t.reward.challenge
				var pt := UIKit.BrawlerPortrait.new()
				pt.brawler_id = c.brawler
				pt.skin = ""
				pt.view_kind = "bust"
				pt.backdrop = false
				pt.art_scale = 1.0
				pt.position = Vector2(10, 32)
				pt.size = Vector2(138, 100)
				pt.custom_minimum_size = pt.size
				t.add_child(pt)

	# quests page
	_quests = HBoxContainer.new()
	_quests.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quests.offset_left = LEFT_W + 20
	_quests.offset_top = 190
	_quests.offset_bottom = -60
	_quests.add_theme_constant_override("separation", 26)
	_quests.visible = false
	add_child(_quests)

	# left column: pass tickets
	var gold := Ticket.new()
	gold.gold = true
	gold.position = Vector2(26, 220)
	gold.size = Vector2(250, 190)
	gold.pressed.connect(_confirm_gold)
	add_child(gold)
	var free := Ticket.new()
	free.gold = false
	free.position = Vector2(26, 500)
	free.size = Vector2(250, 170)
	add_child(free)

	# top: back + season banner, tabs, progress, home
	var banner := SeasonBanner.new()
	banner.position = Vector2(0, 0)
	banner.size = Vector2(LEFT_W + 120, 160)
	add_child(banner)
	Lobby.build_header(self, "", func(): Router.goto("menu"))
	for i in 2:
		var name_t: String = ["REWARDS", "QUESTS"][i]
		var tb := TabButton.new()
		tb.label = name_t
		tb.set_anchors_preset(Control.PRESET_CENTER_TOP)
		tb.position = Vector2(-150 + i * 160, 8)
		tb.size = Vector2(156, 50)
		tb.pressed.connect(func(): _set_tab(name_t))
		add_child(tb)
		_tabs[name_t] = tb
	var prog := Progress.new()
	prog.set_anchors_preset(Control.PRESET_CENTER_TOP)
	prog.position = Vector2(-190, 64)
	prog.size = Vector2(440, 96)
	add_child(prog)
	var home := S.new()
	home.color = Color("27334d")
	home.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	home.position = Vector2(-118, 6)
	home.size = Vector2(104, 72)
	home.custom_draw = func(ci: Control):
		UIKit.draw_icon(ci, "home", Vector2(52, 34), 58.0)
	home.pressed.connect(func(): Router.goto("menu"))
	add_child(home)
	var all := UIKit.button("CLAIM ALL", UIKit.GREEN, 18, Vector2(170, 48))
	all.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	all.position = Vector2(-300, 18)
	all.pressed.connect(_claim_all)
	add_child(all)
	_hint = UIKit.label("", 18, Color("ffb0b0"), 6, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-300, -44)
	_hint.size = Vector2(600, 30)
	add_child(_hint)

	_set_tab("REWARDS")
	await get_tree().process_frame
	_scroll.scroll_horizontal = int(max(0.0, (Save.pass_tier() - 1.5) * COL_W))

func _set_tab(t: String) -> void:
	_tab = t
	for k in _tabs.keys():
		_tabs[k].on = k == t
		_tabs[k].queue_redraw()
	_scroll.visible = t == "REWARDS"
	_quests.visible = t == "QUESTS"
	if t == "QUESTS":
		_build_quests()
	_refresh()

func _refresh() -> void:
	for t in _tiles:
		t.queue_redraw()
	_track.queue_redraw()
	for c in get_children():
		if c is Progress or c is Ticket or c is TabButton:
			c.queue_redraw()

# ------------------------------------------------------------------ claiming
func _claim(t: PassTile) -> void:
	if Save.claim_pass(t.tier, t.track):
		Sfx.play("gem_pickup", 0.0, 0.0)
		FX.burst(self, t.global_position + t.size * 0.5, Color("ffd23a"), 24, 380.0, 0.7, 7.0)
		_refresh()
		_maybe_open_drops()
		return
	Sfx.play("ui_error")
	if t.tier > Save.pass_tier():
		_flash("Reach tier %d to unlock this reward" % t.tier)
	elif t.track == "gold" and not Save.data.gold_pass:
		_flash("Unlock the GOLD PASS to claim gold rewards")
	elif t.reward.has("challenge") and not Save.challenge_done(t.reward.challenge):
		var c: Dictionary = t.reward.challenge
		_flash("%s  (%d / %d)" % [Progression.challenge_text(c), mini(int(c.kos), int(Save.data.challenge_kos.get(c.brawler, 0))), int(c.kos)])

func _claim_all() -> void:
	var n := 0
	for t in _tiles:
		if Save.claim_pass(t.tier, t.track):
			n += 1
			FX.burst(self, t.global_position + t.size * 0.5, Color("ffd23a"), 12, 300.0, 0.6, 6.0)
	for q in Progression.daily_quests(Save.today_key()):
		if Save.claim_quest(q):
			n += 1
	Sfx.play("victory" if n > 0 else "ui_error", -4.0, 0.0)
	if _tab == "QUESTS":
		_build_quests()
	_refresh()
	_maybe_open_drops()

func _maybe_open_drops() -> void:
	if not Save.data.drops.is_empty():
		var d := DropOpener.new()
		add_child(d)
		d.finished.connect(_refresh)

func _flash(msg: String) -> void:
	_hint.text = msg
	_hint.modulate.a = 1.0
	var tw := _hint.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(_hint, "modulate:a", 0.0, 0.5)

# ------------------------------------------------------------------ quests
func _build_quests() -> void:
	for c in _quests.get_children():
		c.queue_free()
	for q in Progression.daily_quests(Save.today_key()):
		var card := QuestCard.new()
		card.quest = q
		card.custom_minimum_size = Vector2(270, 440)
		card.pressed.connect(func():
			if Save.claim_quest(q):
				Sfx.play("gem_pickup", 0.0, 0.0)
				FX.burst(self, card.global_position + card.size * 0.5, Color("8fd0ff"), 24, 380.0, 0.7, 7.0)
				_build_quests()
				_refresh()
			else:
				Sfx.play("ui_error"))
		_quests.add_child(card)
		if q.has("brawler"):
			var pt := UIKit.BrawlerPortrait.new()
			pt.brawler_id = q.brawler
			pt.skin = ""
			pt.view_kind = "bust"
			pt.backdrop = false
			pt.art_scale = 1.0
			pt.position = Vector2(20, 70)
			pt.size = Vector2(230, 170)
			pt.custom_minimum_size = pt.size
			card.add_child(pt)
		UIKit.pop_in(card, 0.05 * _quests.get_child_count())

# ------------------------------------------------------------------ gold pass
func _confirm_gold() -> void:
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
	v.add_child(UIKit.body("Unlocks the gold track for this season: GOLD skins, brawler challenges and extra rewards on every tier. Tiers you've already reached become claimable straight away.", 16))
	v.add_child(UIKit.label("Cost: %d credits   (you have %d)" % [Progression.GOLD_PASS_COST, Save.data.credits], 18, Color("ffe08a"), 5, HORIZONTAL_ALIGNMENT_CENTER))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	var no := UIKit.button("CANCEL", Color("6b5f86"), 20, Vector2(170, 56))
	no.pressed.connect(o.queue_free)
	h.add_child(no)
	var yes := UIKit.button("UNLOCK", UIKit.GREEN, 20, Vector2(170, 56))
	yes.disabled = Save.data.credits < Progression.GOLD_PASS_COST
	if yes.disabled:
		yes.text = "NOT ENOUGH"
	yes.pressed.connect(func():
		o.queue_free()
		if Save.buy_gold_pass():
			Sfx.play("victory", -2.0, 0.0)
			_refresh()
		else:
			Sfx.play("ui_error"))
	h.add_child(yes)
	add_child(o)


# ====================================================================== pieces
## Dark top strip and the purple left column behind the tickets.
class Frame extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, 160), Color("2f6fe0"))
		draw_rect(Rect2(0, 156, size.x, 6), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(0, 0, size.x, 60), Color(0.02, 0.03, 0.08, 0.55))
		var lw := 300.0
		draw_colored_polygon(PackedVector2Array([Vector2(0, 160), Vector2(lw + 20, 160), Vector2(lw - 20, size.y), Vector2(0, size.y)]), Color("7a2fd8"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, 440), Vector2(lw - 2, 440), Vector2(lw - 20, size.y), Vector2(0, size.y)]), Color("5a24b0"))


class SeasonBanner extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var w := size.x
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - 30, 150), Vector2(0, 150)])
		draw_colored_polygon(pts, Color("ff8a2a"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - 8, 40), Vector2(0, 40)]), Color("ffb04a"))
		# desert skyline silhouette
		var sky := PackedVector2Array([Vector2(110, 110)])
		var xs := [110, 140, 140, 170, 170, 190, 205, 220, 220, 260, 260, 290, 300, 310, 330, 330, 370, 370, 400]
		var ys := [110, 110, 70, 70, 86, 86, 58, 86, 92, 92, 66, 66, 50, 66, 66, 84, 84, 96, 110]
		for k in xs.size():
			sky.append(Vector2(xs[k], ys[k]))
		sky.append(Vector2(400, 150))
		sky.append(Vector2(110, 150))
		draw_colored_polygon(sky, Color(0.75, 0.3, 0.05, 0.35))
		S2.text_r(self, "SEASON 1", Vector2(w - 56, 98), 22, Color.WHITE)
		S2.text_r(self, "NEON DESERT", Vector2(w - 44, 138), 38, Color.WHITE)


class TabButton extends Button:
	var label := ""
	var on := false
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var col := Color("ff7a1a") if on else Color("2b2f45")
		var pts := PackedVector2Array([Vector2(8, 0), Vector2(size.x, 0), Vector2(size.x - 8, size.y), Vector2(0, size.y)])
		draw_colored_polygon(pts, UIKit.DARK)
		var inner := PackedVector2Array([Vector2(11, 3), Vector2(size.x - 3, 3), Vector2(size.x - 10, size.y - 3), Vector2(3, size.y - 3)])
		draw_colored_polygon(inner, col)
		S2.text_c(self, label, Vector2(size.x * 0.5, 34), 22, Color.WHITE, 6)
		if label == "QUESTS" and Save.quests_ready() > 0:
			draw_circle(Vector2(size.x - 8, 6), 13, UIKit.DARK)
			draw_circle(Vector2(size.x - 8, 6), 10, Color("ff3b3b"))
			S2.text_c(self, str(Save.quests_ready()), Vector2(size.x - 8, 12), 15, Color.WHITE)


## Token bar: tier badge, tokens into the tier, arrow to the next tier, season timer.
class Progress extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var tier := Save.pass_tier()
		var maxed := tier >= Progression.PASS_TIERS
		var into := int(Save.data.pass_tokens) % Progression.TOKENS_PER_TIER
		var br := Rect2(54, 10, 290, 40)
		draw_rect(br.grow(3), UIKit.DARK)
		draw_rect(br, Color("1d2438"))
		var frac := 1.0 if maxed else float(into) / Progression.TOKENS_PER_TIER
		draw_rect(Rect2(br.position, Vector2(br.size.x * frac, br.size.y)), Color("ffb52e"))
		draw_rect(Rect2(br.position, Vector2(br.size.x * frac, 10)), Color("ffd98a"))
		S2.text_c(self, "MAX" if maxed else "%d/%d" % [into, Progression.TOKENS_PER_TIER], br.get_center() + Vector2(0, 11), 28, Color.WHITE, 6)
		UIKit.draw_icon(self, "token", Vector2(40, 30), 72.0)
		draw_colored_polygon(PackedVector2Array([Vector2(354, 18), Vector2(372, 30), Vector2(354, 42)]), Color.WHITE)
		draw_circle(Vector2(410, 30), 32, UIKit.DARK)
		draw_circle(Vector2(410, 30), 28, Color("1d2438"))
		S2.text_c(self, str(mini(tier + 1, Progression.PASS_TIERS)), Vector2(410, 42), 32, Color.WHITE, 5)
		S2.text_c(self, "SEASON ENDS IN  " + Progression.season_time_left(), Vector2(200, 82), 18, Color("8ff0ff"), 5)


## The "GOLD PASS" / "FREE" ticket on the left.
class Ticket extends Button:
	var gold := true
	var _t := 0.0
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
	func _process(delta: float) -> void:
		_t += delta
		if gold and not Save.data.gold_pass:
			queue_redraw()
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var c := size * 0.5 + Vector2(0, 16)
		if gold and not Save.data.gold_pass:
			for k in 10:
				var a := _t * 0.6 + k * TAU / 10.0
				draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - 0.12) * 130.0, c + Vector2.from_angle(a + 0.12) * 130.0]), Color(1, 0.85, 0.3, 0.12))
		S2.text_c(self, "GOLD PASS" if gold else "FREE", Vector2(size.x * 0.5 - 20, 26), 26, Color("ffd23a") if gold else Color.WHITE, 7)
		var r := Rect2(c - Vector2(100, 56), Vector2(200, 112))
		var col := Color("ffcf3a") if gold else Color("eef0ff")
		draw_set_transform(c, -0.08, Vector2.ONE)
		var rr := Rect2(-r.size * 0.5, r.size)
		draw_rect(rr.grow(5), UIKit.DARK)
		draw_rect(rr, col)
		draw_rect(Rect2(rr.position, Vector2(rr.size.x, 14)), col.lightened(0.35))
		# perforation + notches
		for k in 6:
			draw_circle(Vector2(rr.end.x - 48, rr.position.y + 14 + k * 17), 4, col.darkened(0.3))
		draw_circle(Vector2(rr.end.x - 48, rr.position.y - 2), 10, UIKit.DARK)
		draw_circle(Vector2(rr.end.x - 48, rr.end.y + 2), 10, UIKit.DARK)
		for k in 5:
			draw_rect(Rect2(rr.end.x - 34, rr.position.y + 18 + k * 16, 22, 8), UIKit.DARK)
		# our emblem: lightning star
		var e := Vector2(-30, 0)
		var pts := PackedVector2Array()
		for i in 10:
			var rad := 38.0 if i % 2 == 0 else 17.0
			var a := -PI / 2 + i * PI / 5
			pts.append(e + Vector2(cos(a), sin(a)) * rad)
		draw_colored_polygon(pts, UIKit.DARK)
		draw_colored_polygon(PackedVector2Array([e + Vector2(4, -22), e + Vector2(-10, 4), e + Vector2(0, 4), e + Vector2(-4, 22), e + Vector2(12, -4), e + Vector2(2, -4)]), col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if gold:
			var sub := "ACTIVE" if Save.data.gold_pass else "TAP TO UNLOCK"
			S2.text_c(self, sub, Vector2(size.x * 0.5 - 10, size.y - 4), 16, Color.WHITE, 5)


## Tier numbers and lane backgrounds behind the tiles.
class TrackBg extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var tier := Save.pass_tier()
		draw_rect(Rect2(0, 0, size.x, 236), Color(0.35, 0.2, 0.8, 0.35))
		draw_rect(Rect2(0, 294, size.x, 240), Color(0.12, 0.1, 0.4, 0.45))
		var y := 265.0
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.45), 8.0)
		for i in Progression.PASS_TIERS:
			var c := Vector2(70 + i * 176.0 + 79, y)
			var reached := i + 1 <= tier
			draw_circle(c, 28, UIKit.DARK)
			draw_circle(c, 24, Color("ffb52e") if reached else Color("1d2438"))
			S2.text_c(self, str(i + 1), c + Vector2(0, 10), 26, Color.WHITE, 5)


## One reward on the pass. Challenge tiles show the brawler and the task.
class PassTile extends Button:
	var tier := 1
	var track := "free"
	var reward: Dictionary = {}
	var _t := 0.0
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
	func _process(delta: float) -> void:
		_t += delta
		if Save.pass_claimable(tier, track):
			queue_redraw()
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var w := size.x
		var h := size.y
		var claimed: bool = tier in Save.data.pass_claimed[track]
		var ready := Save.pass_claimable(tier, track)
		var locked := not claimed and not ready
		var base := Color("3fa0ff") if track == "gold" else Color("2c5fd0")
		if ready:
			base = Color("ffb52e").lerp(Color("ffd23a"), 0.5 + 0.5 * sin(_t * 6.0))
		var pts := PackedVector2Array([Vector2(10, 0), Vector2(w, 0), Vector2(w - 10, h), Vector2(0, h)])
		var pts_in := PackedVector2Array([Vector2(14, 4), Vector2(w - 4, 4), Vector2(w - 13, h - 4), Vector2(4, h - 4)])
		draw_colored_polygon(pts, Color("dfeaff") if track == "gold" else UIKit.DARK)
		draw_colored_polygon(pts_in, base)
		draw_colored_polygon(PackedVector2Array([Vector2(14, 4), Vector2(w - 4, 4), Vector2(w - 6, 24), Vector2(12, 24)]), base.lightened(0.2))
		if reward.has("challenge"):
			var c: Dictionary = reward.challenge
			draw_rect(Rect2(14, 30, w - 28, 104), Color("6a1f3a"))
			S2.text_l(self, "%d" % int(Save.data.challenge_kos.get(c.brawler, 0)), Vector2(20, 24), 15, UIKit.YELLOW)
			S2.text_c(self, Config.BRAWLERS[c.brawler].name, Vector2(w * 0.5, 130), 18, Color.WHITE, 5)
			var txt := Progression.challenge_text(c)
			draw_rect(Rect2(6, 138, w - 12, 50), Color("8a5ac8"))
			var words := txt.split(" ")
			var l1 := " ".join(words.slice(0, 3))
			var l2 := " ".join(words.slice(3))
			S2.text_c(self, l1, Vector2(w * 0.5, 158), 15, Color.WHITE, 4)
			S2.text_c(self, l2, Vector2(w * 0.5, 180), 15, Color.WHITE, 4)
		else:
			RewardTile.draw_icon(self, reward, Vector2(w * 0.5, h * 0.42), 46.0)
			S2.text_c(self, RewardTile.short_text(reward), Vector2(w * 0.5, h - 16), 18, Color.WHITE, 6)
		if locked and (track == "gold" and not Save.data.gold_pass or tier > Save.pass_tier()):
			draw_colored_polygon(pts_in, Color(0.05, 0.05, 0.15, 0.35))
			UIKit.draw_icon(self, "lock", Vector2(w - 26, 28), 38.0)
		elif claimed:
			draw_colored_polygon(pts_in, Color(0.05, 0.15, 0.05, 0.45))
			UIKit.draw_icon(self, "check", Vector2(w * 0.5, h * 0.45), 80.0)
		elif ready:
			S2.text_c(self, "CLAIM!", Vector2(w * 0.5, 22), 18, UIKit.YELLOW, 6)


## Daily quest card on the QUESTS tab.
class QuestCard extends Button:
	var quest: Dictionary = {}
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var w := size.x
		var h := size.y
		var prog := Save.quest_progress(quest)
		var goal := int(quest.goal)
		var done := prog >= goal
		var claimed := Save.quest_claimed(quest)
		var base := Color("2c5fd0")
		var pts := PackedVector2Array([Vector2(12, 0), Vector2(w, 0), Vector2(w - 12, h), Vector2(0, h)])
		draw_colored_polygon(pts, UIKit.DARK)
		draw_colored_polygon(PackedVector2Array([Vector2(16, 4), Vector2(w - 4, 4), Vector2(w - 15, h - 4), Vector2(4, h - 4)]), base)
		S2.text_c(self, "DAILY QUEST", Vector2(w * 0.5, 44), 24, Color.WHITE, 6)
		if not quest.has("brawler"):
			var ic: String = "trophy" if quest.kind == "win" else Config.MODES.get(quest.get("mode", ""), {}).get("icon", "mode_gem")
			UIKit.draw_icon(self, ic, Vector2(w * 0.5, 160), 130.0)
		var txt: String = quest.text % goal
		var words := txt.split(" ")
		var half := int(ceil(words.size() / 2.0))
		S2.text_c(self, " ".join(words.slice(0, half)), Vector2(w * 0.5, 276), 19, Color.WHITE, 5)
		S2.text_c(self, " ".join(words.slice(half)), Vector2(w * 0.5, 302), 19, Color.WHITE, 5)
		var br := Rect2(24, 322, w - 48, 32)
		draw_rect(br.grow(3), UIKit.DARK)
		draw_rect(br, Color("1d2438"))
		draw_rect(Rect2(br.position, Vector2(br.size.x * minf(1.0, float(prog) / goal), br.size.y)), Color("4fd36a"))
		S2.text_c(self, "%d / %d" % [mini(prog, goal), goal], br.get_center() + Vector2(0, 9), 20, Color.WHITE, 5)
		var pf := Rect2(16, h - 70, w - 32, 56)
		draw_rect(pf, Color("4fd36a") if done and not claimed else Color("1d2438"))
		if claimed:
			S2.text_c(self, "CLAIMED", pf.get_center() + Vector2(0, 10), 26, Color(1, 1, 1, 0.6), 6)
		else:
			UIKit.draw_icon(self, "token", pf.get_center() + Vector2(-40, 0), 46.0)
			S2.text_l(self, "+%d" % int(quest.tokens), pf.get_center() + Vector2(-14, 11), 28, Color.WHITE)
