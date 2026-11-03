extends Control
## TROPHY ROAD: milestones along your total trophy count. Reach one, claim it.

const Lobby := preload("res://scripts/ui/main_menu.gd")
const STEP := 170.0

var _tiles: Array[RewardTile] = []
var _track: Control
var _scroll: ScrollContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	add_child(Lobby.LobbyBackground.new())
	Lobby.build_header(self, "TROPHY ROAD", func(): Router.goto("menu"))

	var total := UIKit.currency_chip("trophy", str(Save.total_trophies()), UIKit.YELLOW)
	total.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	total.position = Vector2(-200, 20)
	add_child(total)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 110)
	_scroll.size = Vector2(get_viewport_rect().size.x, 560)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_track = RoadTrack.new()
	_track.custom_minimum_size = Vector2(160 + STEP * Progression.ROAD.size(), 540)
	_scroll.add_child(_track)
	for i in Progression.ROAD.size():
		var t := RewardTile.new()
		t.reward = Progression.ROAD[i].reward
		t.frame = Color("8e4dff")
		t.size = Vector2(132, 160)
		t.position = Vector2(120 + i * STEP - 66, 40 if i % 2 == 0 else 330)
		t.set_meta("i", i)
		t.pressed.connect(func(): _claim(t))
		_track.add_child(t)
		_tiles.append(t)
	_refresh()
	# scroll to where the player currently is
	var cur := 0
	for i in Progression.ROAD.size():
		if Save.total_trophies() >= int(Progression.ROAD[i].trophies):
			cur = i
	await get_tree().process_frame
	_scroll.scroll_horizontal = int(max(0.0, cur * STEP - 300.0))

func _refresh() -> void:
	for t in _tiles:
		var i: int = t.get_meta("i")
		if i in Save.data.road_claimed:
			t.state = "claimed"
		elif Save.road_claimable(i):
			t.state = "claimable"
		else:
			t.state = "locked"
		t.queue_redraw()
	_track.queue_redraw()

func _claim(t: RewardTile) -> void:
	if Save.claim_road(t.get_meta("i")):
		Sfx.play("gem_pickup", 0.0, 0.0)
		FX.burst(self, t.global_position + t.size * 0.5, Color("ffd23a"), 24, 380.0, 0.7, 7.0)
		_refresh()
		_maybe_open_drops()
	else:
		Sfx.play("ui_error")


## The road line, milestone markers and the "you are here" indicator.
class RoadTrack extends Control:
	func _draw() -> void:
		var S := preload("res://scripts/ui/main_menu.gd").SlantButton
		var y := 270.0
		var road: Array = Progression.ROAD
		var tt := Save.total_trophies()
		var x_first := 120.0
		var x_last := 120.0 + (road.size() - 1) * 170.0
		draw_line(Vector2(40, y), Vector2(x_last + 60, y), UIKit.DARK, 26.0)
		draw_line(Vector2(40, y), Vector2(x_last + 60, y), Color("1d2438"), 18.0)
		# filled part: interpolate between milestones
		var fill_x := 40.0
		var prev_t := 0
		var prev_x := 40.0
		for i in road.size():
			var mt: int = road[i].trophies
			var mx := x_first + i * 170.0
			if tt >= mt:
				fill_x = mx
			else:
				fill_x = lerpf(prev_x, mx, clampf(float(tt - prev_t) / float(mt - prev_t), 0.0, 1.0))
				break
			prev_t = mt
			prev_x = mx
		if tt >= int(road[road.size() - 1].trophies):
			fill_x = x_last + 60
		draw_line(Vector2(40, y), Vector2(fill_x, y), Color("ff9d2e"), 18.0)
		for i in road.size():
			var c := Vector2(x_first + i * 170.0, y)
			var reached: bool = tt >= int(road[i].trophies)
			draw_line(c, c + Vector2(0, -60 if i % 2 == 0 else 60), UIKit.DARK, 6.0)
			draw_circle(c, 30, UIKit.DARK)
			draw_circle(c, 25, Color("ffb52e") if reached else Color("4a5570"))
			S.trophy(self, c + Vector2(0, -6), 9.0)
			S.text_c(self, str(road[i].trophies), c + Vector2(0, 18), 15, Color.WHITE)
		# you-are-here marker
		var m := Vector2(fill_x, y)
		draw_colored_polygon(PackedVector2Array([m + Vector2(-14, -48), m + Vector2(14, -48), m + Vector2(0, -24)]), UIKit.DARK)
		draw_colored_polygon(PackedVector2Array([m + Vector2(-9, -45), m + Vector2(9, -45), m + Vector2(0, -30)]), Color("4dff7a"))

func _maybe_open_drops() -> void:
	if not Save.data.drops.is_empty():
		var d := DropOpener.new()
		add_child(d)
