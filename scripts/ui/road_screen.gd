extends Control
## TROPHY ROAD: one long sideways bar that fills with your total trophies.
## Trophy numbers run along the bar, reward cards sit above it at each
## milestone, "NEXT GOAL" marks the next one, and brawler milestones show the
## brawler standing on an "UNLOCK" card.

const Lobby := preload("res://scripts/ui/main_menu.gd")
const S := preload("res://scripts/ui/main_menu.gd").SlantButton
const STEP := 240.0      # px between milestones
const X0 := 180.0        # x of the first milestone
const BAR_Y := 470.0

var _scroll: ScrollContainer
var _track: Control
var _cards: Array = []

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
	var top := TopBar.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 96
	add_child(top)
	Lobby.build_header(self, "", func(): Router.goto("menu"))
	var home := S.new()
	home.color = Color("27334d")
	home.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	home.position = Vector2(-118, 6)
	home.size = Vector2(104, 72)
	home.custom_draw = func(ci: Control):
		UIKit.draw_icon(ci, "home", Vector2(52, 34), 58.0)
	home.pressed.connect(func(): Router.goto("menu"))
	add_child(home)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = 100
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_track = Track.new()
	_track.custom_minimum_size = Vector2(X0 + STEP * Progression.ROAD.size() + 200, 610)
	_scroll.add_child(_track)

	var next_i := _next_goal()
	for i in Progression.ROAD.size():
		var m: Dictionary = Progression.ROAD[i]
		var card := RoadCard.new()
		card.index = i
		card.reward = m.reward
		card.next_goal = i == next_i
		var big: bool = m.reward.type == "brawler"
		card.size = Vector2(200, 250 if big else 140)
		card.position = Vector2(X0 + i * STEP - 100, (BAR_Y - 100) - card.size.y - 70)
		card.pressed.connect(func(): _claim(card))
		_track.add_child(card)
		_cards.append(card)
		if big:
			var pt := UIKit.BrawlerPortrait.new()
			pt.brawler_id = m.reward.brawler
			pt.backdrop = false
			pt.view_kind = "showcase"
			pt.art_scale = 1.0
			pt.position = Vector2(10, 6)
			pt.size = Vector2(180, 180)
			pt.custom_minimum_size = pt.size
			card.add_child(pt)
			card.move_child(pt, 0)
	await get_tree().process_frame
	_scroll.scroll_horizontal = int(maxf(0.0, Track.x_for_trophies(Save.total_trophies()) - 420.0))

func _next_goal() -> int:
	for i in Progression.ROAD.size():
		if not Save.road_claimed(i):
			return i
	return -1

func _claim(card: RoadCard) -> void:
	if Save.claim_road(card.index):
		Sfx.play("gem_pickup", 0.0, 0.0)
		FX.burst(self, card.global_position + card.size * 0.5, Color("ffd23a"), 26, 400.0, 0.7, 7.0)
		for c in _cards:
			c.next_goal = c.index == _next_goal()
			c.queue_redraw()
		_track.queue_redraw()
		if not Save.data.drops.is_empty():
			var d := DropOpener.new()
			add_child(d)
	else:
		Sfx.play("ui_error")


class TopBar extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		draw_rect(Rect2(0, 0, size.x, 22), Color(0.02, 0.03, 0.08, 0.6))
		S2.text_c(self, "TROPHY ROAD", Vector2(size.x * 0.5, 40), 34, Color.WHITE, 8)
		S2.text_c(self, "Climb in total trophies to unlock rewards and new brawlers!", Vector2(size.x * 0.5, 66), 16, Color(1, 1, 1, 0.9), 5)
		S2.text_c(self, "Total trophies is all of your brawlers' trophies added together.", Vector2(size.x * 0.5, 88), 16, Color(1, 1, 1, 0.9), 5)


## The progress bar, trophy numbers, league badge and "you are here" marker.
class Track extends Control:
	const STEP2 := 240.0
	const X02 := 180.0
	const BY := 370.0  # bar y inside this control (screen y 470 - scroll offset 100)

	static func x_for_trophies(tt: int) -> float:
		var road: Array = Progression.ROAD
		if tt <= 0:
			return X02 - STEP2
		var prev_t := 0
		var prev_x := X02 - STEP2
		for i in road.size():
			var mt := int(road[i].trophies)
			var mx := X02 + i * STEP2
			if tt <= mt:
				return lerpf(prev_x, mx, float(tt - prev_t) / float(maxi(1, mt - prev_t)))
			prev_t = mt
			prev_x = mx
		return prev_x + 60.0

	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var tt := Save.total_trophies()
		var ink := UIKit.DARK
		var bar := Rect2(0, BY - 18, size.x, 36)
		draw_rect(bar.grow(4), ink)
		draw_rect(bar, Color("5a1438"))
		var fx := x_for_trophies(tt)
		draw_rect(Rect2(bar.position, Vector2(fx, bar.size.y)), Color("ff8a1a"))
		draw_rect(Rect2(bar.position, Vector2(fx, 9)), Color("ffb25a"))
		# milestone ticks + trophy numbers
		var road: Array = Progression.ROAD
		for i in road.size():
			var x := X02 + i * STEP2
			draw_line(Vector2(x - 6, BY + 16), Vector2(x + 6, BY - 16), Color(1, 1, 1, 0.55), 3.0, true)
			S2.text_c(self, str(road[i].trophies), Vector2(x, BY + 58), 20, Color("8fd0ff"), 5)
		# league badge at the start of the road
		var lb := Vector2(X02 - STEP2 + 40, BY)
		UIKit.draw_rank_badge(self, lb, 78.0, 1 + mini(34, tt / 30))
		# "you are here" marker hanging under the bar
		var mp := Vector2(fx, BY + 18)
		draw_line(mp, mp + Vector2(0, 54), ink, 4.0)
		draw_line(mp, mp + Vector2(0, 54), Color("ffd23a"), 2.0)
		var tag := Rect2(mp + Vector2(-14, 54), Vector2(108, 40))
		draw_rect(tag.grow(3), ink)
		draw_rect(tag, Color("ffb52e"))
		draw_rect(Rect2(tag.position, Vector2(tag.size.x, 9)), Color("ffd98a"))
		S2.trophy(self, tag.position + Vector2(22, 20), 10.0)
		S2.text_l(self, str(tt), tag.position + Vector2(40, 30), 24, Color.WHITE)


## A reward card above the bar. Brawler unlocks are tall cards with the brawler.
class RoadCard extends Button:
	var index := 0
	var reward: Dictionary = {}
	var next_goal := false
	var _t := 0.0

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())

	func _process(delta: float) -> void:
		_t += delta
		if Save.road_claimable(index):
			queue_redraw()

	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var w := size.x
		var h := size.y
		var ink := UIKit.DARK
		var claimed := Save.road_claimed(index)
		var ready := Save.road_claimable(index)
		var is_brawler: bool = reward.get("type", "") == "brawler"
		if next_goal and not ready:
			S2.text_l(self, "NEXT GOAL", Vector2(0, -12), 26, Color.WHITE)
		var base := Color("2a8cff")
		if ready:
			base = Color("ffb52e").lerp(Color("ffd23a"), 0.5 + 0.5 * sin(_t * 6.0))
		if is_brawler:
			# brawler stands above an "UNLOCK" plate
			var plate := Rect2(0, h - 58, w, 58)
			draw_rect(Rect2(plate.position + Vector2(4, 6), plate.size), Color(0, 0, 0, 0.3))
			draw_rect(plate.grow(3), ink)
			draw_rect(plate, base)
			draw_rect(Rect2(plate.position, Vector2(w, 10)), base.lightened(0.25))
			S2.text_c(self, "UNLOCK: " + Config.BRAWLERS[reward.brawler].name, plate.get_center() + Vector2(0, 9), 20, Color.WHITE, 6)
			if claimed or Save.is_unlocked(reward.brawler):
				UIKit.draw_icon(self, "check", Vector2(w - 18, h - 50), 42.0)
			return
		draw_rect(Rect2(4, 8, w, h), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(0, 0, w, h).grow(3), ink)
		draw_rect(Rect2(0, 0, w, h), base)
		draw_rect(Rect2(0, 0, w, 10), base.lightened(0.25))
		RewardTile.draw_icon(self, reward, Vector2(w * 0.5, h * 0.45), 40.0)
		S2.text_c(self, RewardTile.short_text(reward), Vector2(w * 0.5, h - 12), 20, Color.WHITE, 6)
		UIKit.draw_icon(self, "info", Vector2(w - 18, 18), 30.0)
		if claimed:
			draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.1, 0.05, 0.4))
			UIKit.draw_icon(self, "check", Vector2(w * 0.5, h * 0.45), 70.0)
		elif ready:
			S2.text_c(self, "CLAIM!", Vector2(w * 0.5, 30), 20, Color.WHITE, 6)
