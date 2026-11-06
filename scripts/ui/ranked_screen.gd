extends Control
## RANKED: climb Bronze I -> Legendary III. Win +25 RP (more on a streak), lose -15 RP.
## You never drop out of a rank you have reached. Each new rank pays a one-time reward.

const Lobby := preload("res://scripts/ui/main_menu.gd")
const S := preload("res://scripts/ui/main_menu.gd").SlantButton

static var _tex := {}

## Rank badge textures, cached so they stay alive while drawn.
static func badge(id: String, crest := false) -> Texture2D:
	var key := "%s%s" % [id, "_crest" if crest else ""]
	if not _tex.has(key):
		_tex[key] = load("res://assets/ranks/%s.png" % key)
	return _tex[key]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var bg := Backdrop.new()
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

	var hero := Hero.new()
	hero.position = Vector2(40, 90)
	hero.size = Vector2(560, 330)
	add_child(hero)
	var ladder := Ladder.new()
	ladder.position = Vector2(30, 440)
	ladder.size = Vector2(1220, 170)
	add_child(ladder)
	var info := InfoCard.new()
	info.position = Vector2(640, 100)
	info.size = Vector2(600, 150)
	add_child(info)
	# mode picker: any mode can be played in Ranked
	var modes := HBoxContainer.new()
	modes.position = Vector2(640, 262)
	modes.add_theme_constant_override("separation", 8)
	add_child(modes)
	var cur: String = String(Save.ranked().get("mode", "gem_grab"))
	for m in Progression.RANKED_MODES:
		var sel: bool = m == cur
		var b := UIKit.button("", Color("8a3cff") if sel else Color("3a3166"), 14, Vector2(144, 58))
		var ic := ModeChip.new()
		ic.mode = m
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(ic)
		b.pressed.connect(func():
			Save.ranked()["mode"] = m
			Save.save_game()
			Router.goto("ranked", {}, true))
		modes.add_child(b)

	var btn := UIKit.button("PLAY RANKED", Color("8a3cff"), 30, Vector2(330, 76))
	btn.position = Vector2(910, 626) - Vector2(0, 0)
	btn.position = Vector2(900, 336)
	btn.pressed.connect(_play)
	add_child(btn)
	var note := UIKit.label("PLAYING AS: " + String(Config.BRAWLERS[Save.data.selected_brawler].name), 16, Color("d8c8ff"), 5)
	note.position = Vector2(904, 414)
	add_child(note)
	var i := 0
	for n in [hero, info, ladder, btn]:
		UIKit.pop_in(n, 0.05 * i)
		i += 1

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
	var _t := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var top := Color("2a1470")
		var bot := Color("0c0628")
		var n := 24
		for i in n:
			var k := float(i) / n
			draw_rect(Rect2(0, size.y * k, size.x, size.y / n + 1), top.lerp(bot, k))
		var info := Progression.ranked_info(int(Save.ranked().points))
		var c: Color = info.color
		var ctr := Vector2(300, 250)
		for k in 6:
			var a := _t * 0.15 + k * TAU / 6.0
			var p1 := ctr + Vector2.from_angle(a - 0.12) * 900.0
			var p2 := ctr + Vector2.from_angle(a + 0.12) * 900.0
			draw_colored_polygon(PackedVector2Array([ctr, p1, p2]), Color(c.r, c.g, c.b, 0.06))
		draw_rect(Rect2(0, 0, size.x, 84), Color(0, 0, 0, 0.35))


class Hero extends Control:
	var _t := 0.0
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var r := Save.ranked()
		var info := Progression.ranked_info(int(r.points))
		var tex := preload("res://scripts/ui/ranked_screen.gd").badge(info.id)
		var bob := sin(_t * 2.0) * 4.0
		var c: Color = info.color
		for k in 4:
			draw_circle(Vector2(150, 160 + bob), 140.0 - k * 22.0, Color(c.r, c.g, c.b, 0.07))
		draw_texture_rect(tex, Rect2(10, 20 + bob, 280, 280), false)
		S2.text_l(self, "RANKED", Vector2(310, 52), 52, Color.WHITE)
		S2.text_l(self, String(info.name), Vector2(310, 112), 44, c.lightened(0.25))
		# division pips
		for d in 3:
			var on: bool = d <= int(info.div)
			var pc := Vector2(326 + d * 40, 142)
			draw_circle(pc, 15, UIKit.DARK)
			draw_circle(pc, 11, c if on else Color("3a3458"))
			S2.text_c(self, Progression.RANKED_DIVS[d], pc + Vector2(0, 5), 13, Color.WHITE)
		# progress bar
		var into: int = int(info.into)
		var fr := 1.0 if bool(info.top) else float(into) / Progression.RANKED_DIV_PTS
		draw_rect(Rect2(310, 176, 250, 30), UIKit.DARK)
		draw_rect(Rect2(313, 179, 244 * clampf(fr, 0.0, 1.0), 24), c)
		draw_rect(Rect2(313, 179, 244 * clampf(fr, 0.0, 1.0), 9), Color(1, 1, 1, 0.25))
		var txt := ("%d RP" % into) if bool(info.top) else ("%d / %d RP" % [into, Progression.RANKED_DIV_PTS])
		S2.text_c(self, txt, Vector2(435, 199), 18, Color.WHITE)
		S2.text_l(self, "WINS %d   LOSSES %d" % [int(r.wins), int(r.losses)], Vector2(310, 240), 18, Color(1, 1, 1, 0.8))
		if int(r.streak) >= 2:
			S2.text_l(self, "WIN STREAK x%d  (+%d BONUS RP)" % [int(r.streak), mini(15, 5 * int(r.streak))], Vector2(310, 268), 16, Color("ffb040"))
		var best := Progression.ranked_info(int(r.best))
		S2.text_l(self, "BEST: " + String(best.name), Vector2(310, 296), 16, Color("d8c8ff"))


class InfoCard extends Control:
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(0, 0, size.x, 4), Color("a46bff"))
		S2.text_l(self, "HOW RANKED WORKS", Vector2(20, 38), 24, Color.WHITE)
		var lines := [
			"Pick any mode below.  Showdown: top 4 counts as a win",
			"Win: +25 RP (+5 per extra win in a row, up to +15).  Lose: -15 RP",
			"100 RP per division (I > II > III), never drop out of a rank",
			"Tougher enemies as you climb.  No trophies won or lost",
		]
		for i in lines.size():
			S2.text_l(self, "•  " + lines[i], Vector2(24, 68 + i * 22), 15, Color(1, 1, 1, 0.85))


## Row of all seven badges with first-time rewards underneath.
class Ladder extends Control:
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var r := Save.ranked()
		var info := Progression.ranked_info(int(r.points))
		var n := Progression.RANKED_NAMES.size()
		var step := size.x / n
		draw_rect(Rect2(step * 0.5, 62, step * (n - 1), 8), UIKit.DARK)
		var reached := float(info.rank) + float(info.div) / 3.0 + float(info.into) / 300.0
		draw_rect(Rect2(step * 0.5, 64, step * minf(reached, n - 1), 4), info.color)
		for i in n:
			var cx := step * (i + 0.5)
			var cur: bool = i == int(info.rank)
			var got: bool = i <= int(info.rank)
			var sz := 118.0 if cur else 92.0
			var tex := preload("res://scripts/ui/ranked_screen.gd").badge(Progression.RANKED_IDS[i], true)
			var tint := Color.WHITE if got else Color(0.35, 0.33, 0.45, 1)
			if cur:
				var c: Color = info.color
				draw_circle(Vector2(cx, 66), 64, Color(c.r, c.g, c.b, 0.2))
			draw_texture_rect(tex, Rect2(cx - sz * 0.5, 66 - sz * 0.55, sz, sz), false, tint)
			S2.text_c(self, Progression.RANKED_NAMES[i], Vector2(cx, 136), 16, Progression.RANKED_COLORS[i].lightened(0.3) if got else Color(1, 1, 1, 0.4))
			var rw: Array = Progression.RANKED_REWARDS[i]
			if rw.size() > 0:
				var claimed: bool = i in r.claimed
				var x := cx - (rw.size() - 1) * 26.0
				for item in rw:
					RewardTile.draw_icon(self, item, Vector2(x, 160), 13.0)
					x += 52.0
				if claimed:
					UIKit.draw_icon(self, "check", Vector2(cx + 46, 150), 22.0)


class ModeChip extends Control:
	var mode := "gem_grab"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		UIKit.draw_icon(self, Progression.RANKED_MODE_ICONS.get(mode, "play"), Vector2(28, size.y * 0.5 - 2), 40.0)
		var nm: String = String(Config.MODES[mode].name).replace(" RUSH", "")
		S2.text_l(self, nm, Vector2(52, size.y * 0.5 + 4), 15 if nm.length() > 7 else 17, Color.WHITE)
