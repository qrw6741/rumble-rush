extends Control
## RANKED: climb Bronze I -> Legendary III. Win +25 RP (more on a streak), lose -15 RP.
## You never drop out of a rank you have reached. Each new rank pays a one-time reward.
## Layout: big animated badge with RP bar on the left, mode cards + PLAY on the right,
## and a scrollable rank road along the bottom.

const Lobby := preload("res://scripts/ui/main_menu.gd")
const S := preload("res://scripts/ui/main_menu.gd").SlantButton

static var _tex := {}

## Rank badge textures, cached so they stay alive while drawn.
static func badge(id: String, crest := false) -> Texture2D:
	var key := "%s%s" % [id, "_crest" if crest else ""]
	if not _tex.has(key):
		_tex[key] = load("res://assets/ranks/%s.png" % key)
	return _tex[key]

var _info: Dictionary
var _road: ScrollContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	Save.ranked_season_tick()
	var got := Save.ranked_payout_tick()
	_info = Progression.ranked_info(int(Save.ranked().points))
	var bg := Backdrop.new()
	bg.col = _info.color
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	Lobby.build_header(self, "", func(): Router.goto("menu"))
	var home := S.new()
	home.color = Color("2a1a4a")
	home.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	home.position = Vector2(-118, 6)
	home.size = Vector2(104, 72)
	home.custom_draw = func(ci: Control):
		UIKit.draw_icon(ci, "home", Vector2(52, 34), 58.0)
	home.pressed.connect(func(): Router.goto("menu"))
	add_child(home)
	var title := TitleBar.new()
	title.position = Vector2(130, 14)
	title.size = Vector2(700, 64)
	add_child(title)

	var hero := Hero.new()
	hero.position = Vector2(20, 88)
	hero.size = Vector2(560, 372)
	add_child(hero)

	# ---------------- right column: mode cards + play
	var lab := UIKit.label("CHOOSE YOUR MODE", 20, Color("d8c8ff"), 6)
	lab.position = Vector2(612, 92)
	add_child(lab)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(608, 124)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	add_child(grid)
	var cur: String = String(Save.ranked().get("mode", "gem_grab"))
	var cards: Array = []
	for m in Progression.RANKED_MODES:
		var card := ModeCard.new()
		card.mode = m
		card.selected = m == cur
		card.custom_minimum_size = Vector2(312, 92)
		card.pressed.connect(func():
			Sfx.play("ui_click", -2.0, 0.04)
			Save.ranked()["mode"] = m
			Save.save_game()
			for c in cards:
				c.selected = c.mode == m
				c.queue_redraw())
		cards.append(card)
		grid.add_child(card)

	var play := PlayButton.new()
	play.col = _info.color
	play.position = Vector2(608, 344)
	play.size = Vector2(636, 92)
	play.pressed.connect(_play)
	add_child(play)

	# ---------------- rank road
	_road = ScrollContainer.new()
	_road.position = Vector2(0, 470)
	_road.size = Vector2(1280, 250)
	_road.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_road.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_road)
	var row := RoadRow.new()
	row.custom_minimum_size = Vector2(60 + Progression.RANKED_NAMES.size() * 200 + 40, 240)
	_road.add_child(row)

	if not got.is_empty():
		var parts: Array = []
		if int(got.get("credits", 0)) > 0: parts.append("+%d COINS" % int(got.credits))
		if int(got.get("gems", 0)) > 0: parts.append("+%d GEMS" % int(got.gems))
		UIKit.toast(self, "RANK REWARD COLLECTED:  " + "  ".join(parts), "coin")
	var sr := UIKit.button("SEASON REWARDS", Color("8a3cff"), 16, Vector2(220, 46))
	sr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sr.position = Vector2(-350, 18)
	sr.pressed.connect(_open_season_rewards)
	add_child(sr)
	show_season_report.call_deferred(self)
	var i := 0
	for n in [title, hero, lab, grid, play, _road]:
		UIKit.pop_in(n, 0.05 * i, Vector2(0, 24) if n == _road else Vector2.ZERO)
		i += 1
	# glide the road so the current rank is centred
	await get_tree().process_frame
	var target := clampi(int(60 + int(_info.rank) * 200 + 100 - 640), 0, int(row.custom_minimum_size.x - 1280))
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(_road, "scroll_horizontal", target, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Shows the "season ended" popup once, if there is a report waiting.
static func show_season_report(parent: Control) -> void:
	var r := Save.ranked()
	var rep: Dictionary = r.get("season_report", {})
	if rep.is_empty():
		return
	r.erase("season_report")
	Save.save_game()
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.z_index = 40
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.1, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(c)
	var p := UIKit.panel(Color("21124a"))
	p.custom_minimum_size = Vector2(640, 0)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UIKit.label("RANKED SEASON %d IS OVER!" % int(rep.season), 32, UIKit.YELLOW, 8, HORIZONTAL_ALIGNMENT_CENTER))
	var bc := CenterContainer.new()
	var b := TextureRect.new()
	b.texture = badge(Progression.RANKED_IDS[int(rep.rank)])
	b.custom_minimum_size = Vector2(180, 180)
	b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bc.add_child(b)
	v.add_child(bc)
	if int(rep.played) > 0:
		v.add_child(UIKit.label("BEST RANK:  " + String(rep.best_name), 24, Progression.RANKED_COLORS[int(rep.rank)].lightened(0.3), 6, HORIZONTAL_ALIGNMENT_CENTER))
		var parts: Array = []
		for rw in rep.rewards:
			parts.append(Progression.reward_text(rw))
		v.add_child(UIKit.label("REWARDS:  " + "  ·  ".join(parts), 17, Color.WHITE, 5, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UIKit.label("Season %d badge added to your profile." % int(rep.season), 15, Color("d8c8ff"), 4, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		v.add_child(UIKit.label("You didn't play Ranked last season, so there are no rewards.", 17, Color.WHITE, 4, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("NEW SEASON: %s  »  %s" % [String(rep.from), String(rep.to)], 17, Color("ffb070"), 5, HORIZONTAL_ALIGNMENT_CENTER))
	var ok := UIKit.button("COLLECT", UIKit.GREEN, 24, Vector2(240, 62))
	ok.pressed.connect(func():
		o.queue_free()
		if not Save.data.drops.is_empty():
			var d := DropOpener.new()
			parent.add_child(d))
	var cc := CenterContainer.new()
	cc.add_child(ok)
	v.add_child(cc)
	parent.add_child(o)
	UIKit.pop_in(p)
	Sfx.play("victory", -2.0, 0.0)

## Season reward table popup.
func _open_season_rewards() -> void:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.1, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(c)
	var p := UIKit.panel(Color("21124a"))
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var r := Save.ranked()
	v.add_child(UIKit.label("SEASON %d REWARDS" % Progression.ranked_season_now(), 30, UIKit.YELLOW, 8, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Paid when the season ends, for the BEST rank you reach. Then everyone drops %d ranks." % Progression.RANKED_SEASON_DROP, 15, Color(1, 1, 1, 0.75), 4, HORIZONTAL_ALIGNMENT_CENTER))
	var best_rank: int = int(Progression.ranked_info(maxi(int(r.get("season_best", 0)), int(r.points))).rank)
	for i in range(Progression.RANKED_NAMES.size() - 1, -1, -1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var ic := TextureRect.new()
		ic.texture = badge(Progression.RANKED_IDS[i], true)
		ic.custom_minimum_size = Vector2(44, 44)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(ic)
		var nm := UIKit.label(Progression.RANKED_NAMES[i], 19, Progression.RANKED_COLORS[i].lightened(0.3), 5)
		nm.custom_minimum_size = Vector2(150, 0)
		row.add_child(nm)
		var parts: Array = []
		for rw in Progression.RANKED_SEASON_REWARDS[i]:
			parts.append(Progression.reward_text(rw))
		row.add_child(UIKit.label("  ·  ".join(parts), 16, Color.WHITE if i != best_rank else Color("7dff8a"), 4))
		if i == best_rank:
			row.add_child(UIKit.label("  ◀ YOUR BEST", 15, Color("7dff8a"), 4))
		v.add_child(row)
	var close := UIKit.button("CLOSE", Color("6b5f86"), 20, Vector2(200, 54))
	close.pressed.connect(o.queue_free)
	var cc := CenterContainer.new()
	cc.add_child(close)
	v.add_child(cc)
	add_child(o)
	UIKit.pop_in(p)

func _play() -> void:
	var r := Save.ranked()
	var mid: String = String(r.get("mode", "gem_grab"))
	if not mid in Progression.RANKED_MODES:
		mid = "gem_grab"
	Sfx.play("ui_confirm")
	Router.goto("match", {"mode": mid, "brawler": Save.data.selected_brawler, "ranked": true,
		"difficulty": Progression.ranked_difficulty(int(r.points))})

# ====================================================================== pieces
class Backdrop extends Control:
	var col := Color.WHITE
	var _t := 0.0
	var _motes: Array = []
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in 36:
			_motes.append([randf() * 1280.0, randf() * 720.0, randf_range(8, 26), randf_range(1.5, 4.5), randf() * TAU])
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var top := Color("251060")
		var bot := Color("08041c")
		var n := 28
		for i in n:
			var k := float(i) / n
			draw_rect(Rect2(0, size.y * k, size.x, size.y / n + 1), top.lerp(bot, k))
		# soft rank-coloured glow behind the badge
		for k in 10:
			draw_circle(Vector2(250, 270), 420.0 - k * 36.0, Color(col.r, col.g, col.b, 0.025))
		# rising motes
		for m in _motes:
			var y: float = fposmod(float(m[1]) - _t * float(m[2]), size.y + 40.0) - 20.0
			var x: float = float(m[0]) + sin(_t * 0.8 + float(m[4])) * 12.0
			var a := 0.25 + 0.2 * sin(_t * 2.0 + float(m[4]))
			draw_circle(Vector2(x, y), float(m[3]), Color(col.r, col.g, col.b, a * 0.6))
		draw_rect(Rect2(0, 0, size.x, 84), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(0, 466, size.x, 254), Color(0, 0, 0, 0.28))
		draw_rect(Rect2(0, 466, size.x, 3), Color(col.r, col.g, col.b, 0.5))


class TitleBar extends Control:
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		S2.text_l(self, "RANKED", Vector2(0, 50), 50, Color.WHITE)
		UIKit.draw_icon(self, "clock", Vector2(236, 38), 26.0)
		S2.text_l(self, "SEASON %d ENDS IN  %s  (resets every Thursday)" % [Progression.ranked_season_now(), Progression.ranked_season_left()], Vector2(254, 34), 16, Color("e0d0ff"))
		var secs := Save.ranked_next_payout_secs()
		S2.text_l(self, "NEXT RANK REWARD IN  %dh %02dm  (auto-collected)" % [secs / 3600, (secs % 3600) / 60], Vector2(254, 58), 16, Color("ffd23a"))
	func _process(_d: float) -> void:
		queue_redraw()


## Big animated badge, rank name, division chips, RP bar and season stats.
class Hero extends Control:
	var _t := 0.0
	var _fill := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var r := Save.ranked()
		var info := Progression.ranked_info(int(r.points))
		var c: Color = info.color
		var ctr := Vector2(170, 160)
		# rotating light rays
		for k in 12:
			var a := _t * 0.35 + k * TAU / 12.0
			var p1 := ctr + Vector2.from_angle(a - 0.09) * 190.0
			var p2 := ctr + Vector2.from_angle(a + 0.09) * 190.0
			draw_colored_polygon(PackedVector2Array([ctr, p1, p2]), Color(c.r, c.g, c.b, 0.10))
		for k in 5:
			draw_circle(ctr, 120.0 - k * 18.0, Color(c.r, c.g, c.b, 0.06))
		# orbiting sparkles
		for k in 6:
			var a := _t * 0.9 + k * TAU / 6.0
			var p := ctr + Vector2(cos(a) * 132.0, sin(a) * 70.0)
			var s := 3.0 + 2.0 * sin(_t * 4.0 + k)
			draw_circle(p, s, Color(1, 1, 1, 0.75))
		# badge: gentle bob + breathe
		var tex := preload("res://scripts/ui/ranked_screen.gd").badge(info.id)
		var intro := ease(clampf(_t / 0.5, 0.0, 1.0), -3.0)
		var sz := 300.0 * (0.6 + 0.4 * intro) * (1.0 + sin(_t * 2.2) * 0.015)
		var bob := sin(_t * 1.8) * 5.0
		draw_texture_rect(tex, Rect2(ctr.x - sz * 0.5, ctr.y - sz * 0.5 + bob + 10, sz, sz), false)

		# right side text block
		var x0 := 340.0
		S2.text_l(self, Progression.RANKED_NAMES[int(info.rank)], Vector2(x0, 72), 44, c.lightened(0.3))
		# division chips I / II / III
		for d in 3:
			var on: bool = d <= int(info.div)
			var cur: bool = d == int(info.div)
			var px := x0 + d * 66.0
			var chip := PackedVector2Array([Vector2(px + 8, 90), Vector2(px + 62, 90), Vector2(px + 54, 126), Vector2(px, 126)])
			draw_colored_polygon(PackedVector2Array([chip[0] + Vector2(-3, -3), chip[1] + Vector2(3, -3), chip[2] + Vector2(3, 3), chip[3] + Vector2(-3, 3)]), UIKit.DARK)
			var cc := c if on else Color("2c2650")
			if cur:
				cc = cc.lerp(Color.WHITE, 0.15 + 0.1 * sin(_t * 4.0))
			draw_colored_polygon(chip, cc)
			draw_colored_polygon(PackedVector2Array([chip[0], chip[1], chip[1] + Vector2(-1, 10), chip[0] + Vector2(-1, 10)]), Color(1, 1, 1, 0.25 if on else 0.06))
			S2.text_c(self, Progression.RANKED_DIVS[d], Vector2(px + 31, 116), 20, Color.WHITE if on else Color(1, 1, 1, 0.35))
		# RP bar (fills smoothly on open, shine sweeps across)
		var target := 1.0 if bool(info.top) else float(info.into) / float(info.need)
		_fill = lerpf(_fill, target, clampf(get_process_delta_time() * 3.0, 0.0, 1.0)) if _t > 0.35 else 0.0
		var br := Rect2(x0, 146, 210, 30)
		draw_rect(br.grow(3), UIKit.DARK)
		draw_rect(br, Color("1a1438"))
		var fw := br.size.x * _fill
		draw_rect(Rect2(br.position, Vector2(fw, br.size.y)), c)
		draw_rect(Rect2(br.position, Vector2(fw, 10)), Color(1, 1, 1, 0.28))
		var sx := fmod(_t * 160.0, br.size.x + 80.0) - 40.0
		if sx < fw:
			draw_colored_polygon(PackedVector2Array([Vector2(br.position.x + sx, br.position.y), Vector2(br.position.x + minf(sx + 18, fw), br.position.y),
				Vector2(br.position.x + minf(sx + 8, fw), br.end.y), Vector2(br.position.x + maxf(sx - 10, 0), br.end.y)]), Color(1, 1, 1, 0.22))
		var into: int = int(info.into)
		var txt := ("%d RP" % into) if bool(info.top) else ("%d / %d RP" % [into, int(info.need)])
		S2.text_c(self, txt, br.get_center() + Vector2(0, 7), 18, Color.WHITE)
		if not bool(info.top):
			var nxt := Progression.ranked_info(Progression.ranked_step_start(int(info.step) + 1))
			S2.text_l(self, "NEXT: " + String(nxt.name), Vector2(x0, 200), 15, Color(1, 1, 1, 0.6))
		S2.text_l(self, "WIN +%d RP    LOSS -%d RP" % [Progression.ranked_win_pts(int(info.rank)), Progression.ranked_loss_pts(int(info.rank))], Vector2(x0, 220), 14, Color("ffd23a"))

		# season stats
		var w := int(r.wins)
		var l := int(r.losses)
		var wr := 0 if w + l == 0 else int(round(100.0 * w / (w + l)))
		var stats := [["WINS", str(w), Color("7dff8a")], ["LOSSES", str(l), Color("ff8a7a")], ["WIN RATE", "%d%%" % wr, Color.WHITE]]
		for k in stats.size():
			var sx2 := x0 + k * 72.0
			draw_rect(Rect2(sx2, 232, 66, 54), Color(0, 0, 0, 0.3))
			S2.text_c(self, stats[k][1], Vector2(sx2 + 33, 260), 22, stats[k][2])
			S2.text_c(self, stats[k][0], Vector2(sx2 + 33, 279), 11, Color(1, 1, 1, 0.6))
		if int(r.streak) >= 2:
			UIKit.StreakBadge.flame(self, Vector2(x0 + 14, 312), 30.0, Progression.streak_color(int(r.streak)), _t)
			S2.text_l(self, "%d WIN STREAK  +%d RP BONUS" % [int(r.streak), mini(Progression.RANKED_STREAK_MAX, Progression.RANKED_STREAK_STEP * int(r.streak))], Vector2(x0 + 34, 320), 15, Color("ffc04a"))
		var sbest := Progression.ranked_info(maxi(int(r.get("season_best", 0)), int(r.points)))
		S2.text_l(self, "SEASON BEST: " + String(sbest.name), Vector2(x0, 352), 15, Color("d8c8ff"))
		S2.text_c(self, "PLAYING AS " + String(Config.BRAWLERS[Save.data.selected_brawler].name), Vector2(170, 350), 15, Color(1, 1, 1, 0.7))


## Selectable mode card: icon, mode name, current map.
class ModeCard extends Button:
	var mode := "gem_grab"
	var selected := false
	var _t := 0.0
	var _sel_k := 0.0
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		resized.connect(func(): pivot_offset = size * 0.5)
		button_down.connect(func(): create_tween().tween_property(self, "scale", Vector2(0.95, 0.95), 0.07))
		button_up.connect(func(): create_tween().tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	func _process(d: float) -> void:
		_t += d
		_sel_k = move_toward(_sel_k, 1.0 if selected else 0.0, d * 6.0)
		queue_redraw()
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var w := size.x
		var h := size.y
		var base := Color("2a2258").lerp(Color("7a34e8"), _sel_k)
		if _sel_k > 0.01:
			var g := 4.0 + 3.0 * sin(_t * 4.0)
			draw_rect(Rect2(-g, -g, w + g * 2, h + g * 2), Color(0.75, 0.5, 1.0, 0.35 * _sel_k))
		draw_rect(Rect2(0, 0, w, h), UIKit.DARK)
		draw_rect(Rect2(3, 3, w - 6, h - 9), base)
		draw_rect(Rect2(3, h - 9, w - 6, 6), base.darkened(0.45))
		draw_rect(Rect2(3, 3, w - 6, (h - 9) * 0.45), Color(1, 1, 1, 0.08 + 0.06 * _sel_k))
		UIKit.draw_icon(self, Progression.RANKED_MODE_ICONS.get(mode, "play"), Vector2(46, h * 0.5 - 2), 64.0 + 6.0 * _sel_k)
		S2.text_l(self, String(Config.MODES[mode].name), Vector2(90, 40), 22, Color.WHITE)
		S2.text_l(self, String(MapData.MAPS[Progression.active_map(mode)].name), Vector2(90, 66), 14, Color("c8f0ff") if selected else Color(1, 1, 1, 0.55))
		var team: int = int(Config.MODES[mode].get("team_size", 3))
		var tag := "1v1" if team == 1 else ("SOLO" if mode == "showdown" else "3v3")
		S2.text_r(self, tag, Vector2(w - 14, 28), 14, Color("ffd23a"))
		if selected:
			UIKit.draw_icon(self, "check", Vector2(w - 26, h - 30), 30.0)


## Big pulsing PLAY RANKED button tinted by the current rank.
class PlayButton extends Button:
	var col := Color("8a3cff")
	var _t := 0.0
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		pivot_offset = size * 0.5
		button_down.connect(func(): create_tween().tween_property(self, "scale", Vector2(0.95, 0.95), 0.07))
		button_up.connect(func(): create_tween().tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var w := size.x
		var h := size.y
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		var face := Color("ffc21a")
		var sl := 16.0
		draw_colored_polygon(PackedVector2Array([Vector2(sl - 6, -6 - pulse * 3), Vector2(w + 6, -6 - pulse * 3), Vector2(w - sl + 6, h + 6 + pulse * 3), Vector2(-6, h + 6 + pulse * 3)]), Color(1, 0.8, 0.2, 0.18 + 0.12 * pulse))
		draw_colored_polygon(PackedVector2Array([Vector2(sl, 0), Vector2(w, 0), Vector2(w - sl, h), Vector2(0, h)]), UIKit.DARK)
		var top_c := face.lightened(0.3)
		var bot_c := face.darkened(0.15)
		draw_polygon(PackedVector2Array([Vector2(sl + 4, 4), Vector2(w - 4, 4), Vector2(w - sl - 4, h - 12), Vector2(4, h - 12)]), PackedColorArray([top_c, top_c, bot_c, bot_c]))
		draw_colored_polygon(PackedVector2Array([Vector2(4, h - 12), Vector2(w - sl - 4, h - 12), Vector2(w - sl - 4, h - 4), Vector2(4, h - 4)]), face.darkened(0.5))
		# moving shine stripe
		var sx := fmod(_t * 260.0, w + 300.0) - 150.0
		draw_colored_polygon(PackedVector2Array([Vector2(sx, 4), Vector2(sx + 50, 4), Vector2(sx + 20, h - 12), Vector2(sx - 30, h - 12)]), Color(1, 1, 1, 0.22))
		S2.text_c(self, "PLAY RANKED", Vector2(w * 0.5, h * 0.5 + 14), 44, Color.WHITE, 12)


## Road of rank cards with a glowing path; current rank highlighted.
class RoadRow extends Control:
	var _t := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var r := Save.ranked()
		var info := Progression.ranked_info(int(r.points))
		var n := Progression.RANKED_NAMES.size()
		var y := 92.0
		var x_of := func(i: float) -> float: return 60.0 + i * 200.0 + 100.0
		# path
		draw_rect(Rect2(x_of.call(0), y - 6, x_of.call(n - 1) - x_of.call(0), 12), UIKit.DARK)
		var prog := float(info.rank) + (float(info.div) + float(info.into) / float(info.need)) / 3.0
		var pc: Color = info.color
		draw_rect(Rect2(x_of.call(0), y - 3, x_of.call(minf(prog, n - 1)) - x_of.call(0), 6), pc)
		for i in n:
			var cx: float = x_of.call(i)
			var cur: bool = i == int(info.rank)
			var got: bool = i <= int(info.rank)
			var rc: Color = Progression.RANKED_COLORS[i]
			# card
			var card := Rect2(cx - 88, 8, 176, 222)
			if cur:
				var g := 5.0 + 3.0 * sin(_t * 3.0)
				draw_rect(card.grow(g), Color(rc.r, rc.g, rc.b, 0.35))
			draw_rect(card, UIKit.DARK)
			var fill := Color("2a2258") if got else Color("1a1636")
			draw_rect(card.grow(-3), fill)
			draw_rect(Rect2(card.position + Vector2(3, 3), Vector2(card.size.x - 6, 6)), rc if got else Color("3a3458"))
			var tex := preload("res://scripts/ui/ranked_screen.gd").badge(Progression.RANKED_IDS[i], true)
			var bob := sin(_t * 2.0 + i) * 3.0 if cur else 0.0
			var sz := 128.0 if cur else 108.0
			var tint := Color.WHITE if got else Color(0.4, 0.38, 0.52, 1)
			draw_texture_rect(tex, Rect2(cx - sz * 0.5, y - sz * 0.55 + bob, sz, sz), false, tint)
			S2.text_c(self, Progression.RANKED_NAMES[i], Vector2(cx, 172), 18, rc.lightened(0.3) if got else Color(1, 1, 1, 0.4))
			# status / rewards
			var rw: Array = Progression.RANKED_PAYOUTS[i]
			S2.text_c(self, "YOU ARE HERE" if cur else "EVERY 6H:", Vector2(cx, 192), 12, Color("ffd23a") if cur else Color(1, 1, 1, 0.55))
			var x := cx - (rw.size() - 1) * 40.0
			for item in rw:
				UIKit.draw_icon(self, "coin" if item.type == "credits" else "gem", Vector2(x - 14, 211), 20.0)
				S2.text_l(self, str(int(item.amount)), Vector2(x - 2, 218), 14, Color.WHITE)
				x += 80.0
			if not got:
				UIKit.draw_icon(self, "lock", Vector2(cx + 66, 30), 24.0)
