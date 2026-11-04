extends Control
## CHAMPS: the competitive mode. Qualify (5 wins before 3 losses), then play the
## 15-match Finals. Your Finals wins decide your Champs rank (X up to I).
## Layout: title + timer, a row of rank shields, entry requirements, rank rewards
## and performance cards, and one big action button.

const Lobby := preload("res://scripts/ui/main_menu.gd")
const S := preload("res://scripts/ui/main_menu.gd").SlantButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var bg := Backdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	Lobby.build_header(self, "", func(): Router.goto("menu"))
	var home := S.new()
	home.color = Color("2a1a14")
	home.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	home.position = Vector2(-118, 6)
	home.size = Vector2(104, 72)
	home.custom_draw = func(ci: Control):
		UIKit.draw_icon(ci, "home", Vector2(52, 34), 58.0)
	home.pressed.connect(func(): Router.goto("menu"))
	add_child(home)

	var head := Header.new()
	head.position = Vector2(40, 92)
	head.size = Vector2(900, 120)
	add_child(head)
	var track := RankTrack.new()
	track.position = Vector2(30, 222)
	track.size = Vector2(1220, 110)
	add_child(track)
	var req := Requirements.new()
	req.position = Vector2(40, 400)
	req.size = Vector2(330, 160)
	add_child(req)
	var rw := RewardsCard.new()
	rw.position = Vector2(420, 380)
	rw.size = Vector2(380, 250)
	add_child(rw)
	var perf := PerformanceCard.new()
	perf.position = Vector2(830, 380)
	perf.size = Vector2(380, 250)
	add_child(perf)

	var c := Save.champs()
	var btn: Button
	if c.stage == "rewards":
		btn = UIKit.button("CLAIM REWARDS", UIKit.GREEN, 24, Vector2(330, 64))
		btn.pressed.connect(_claim)
	else:
		btn = UIKit.button("PLAY QUALIFIER" if c.stage == "qualifier" else "PLAY FINALS MATCH", Color("e0a050"), 24, Vector2(330, 64))
		btn.pressed.connect(_play)
	btn.position = Vector2(40, 580)
	add_child(btn)
	for n in [head, track, req, rw, perf, btn]:
		UIKit.pop_in(n, 0.04 * [head, track, req, rw, perf, btn].find(n))

func _play() -> void:
	var c := Save.champs()
	var mid: String = Progression.CHAMPS_MODES[(int(c.q_w) + int(c.q_l) + int(c.f_w) + int(c.f_l)) % Progression.CHAMPS_MODES.size()]
	Sfx.play("ui_confirm")
	Router.goto("match", {"mode": mid, "brawler": Save.data.selected_brawler, "champs": true, "difficulty": Save.champs_difficulty()})

func _claim() -> void:
	var tier := Save.champs_claim()
	if tier.is_empty():
		return
	Sfx.play("victory", -2.0, 0.0)
	FX.burst(self, size * 0.5, tier.color, 40, 600.0, 0.9, 8.0)
	if not Save.data.drops.is_empty():
		var d := DropOpener.new()
		add_child(d)
		d.finished.connect(func(): Router.goto("champs"))
	else:
		await get_tree().create_timer(0.8).timeout
		Router.goto("champs")

# ====================================================================== pieces
class Backdrop extends Control:
	var _t := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var top := Color("3a1a12")
		var bot := Color("0e0605")
		var n := 24
		for i in n:
			var k := float(i) / n
			draw_rect(Rect2(0, size.y * k, size.x, size.y / n + 1), top.lerp(bot, k))
		# big faint crest shapes on the right
		var c := Vector2(size.x * 0.82, size.y * 0.42)
		for k in 3:
			var r := 220.0 + k * 90.0
			var pts := PackedVector2Array()
			for i in 6:
				var a := -PI / 2 + i * TAU / 6.0 + _t * 0.02 * (k + 1)
				pts.append(c + Vector2.from_angle(a) * r)
			pts.append(pts[0])
			draw_polyline(pts, Color(0.9, 0.55, 0.25, 0.07), 18.0, true)
		draw_rect(Rect2(0, 0, size.x, 84), Color(0, 0, 0, 0.35))


class Header extends Control:
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		S2.text_l(self, "CHAMPS", Vector2(0, 46), 52, Color.WHITE)
		UIKit.draw_icon(self, "clock", Vector2(14, 78), 24.0)
		S2.text_l(self, "Event ends in  " + Progression.season_time_left(), Vector2(32, 86), 18, Color("e0c27a"))
		S2.text_l(self, "Qualify, then play the Finals: every win climbs you toward a higher rank and better rewards.", Vector2(0, 114), 16, Color(1, 1, 1, 0.8))


## Crest + the row of rank shields from X to I; a marker sits over your rank.
class RankTrack extends Control:
	func _draw() -> void:
		var c := Save.champs()
		var tiers: Array = Progression.CHAMPS_TIERS.duplicate()
		tiers.reverse() # X ... I, left to right
		var y := 56.0
		draw_line(Vector2(80, y), Vector2(size.x - 20, y), Color("140405"), 8.0)
		draw_line(Vector2(80, y), Vector2(size.x - 20, y), Color("6a1418"), 4.0)
		# our crest on the left
		var cc := Vector2(40, y)
		var cp := PackedVector2Array()
		for i in 6:
			cp.append(cc + Vector2.from_angle(-PI / 2 + i * TAU / 6.0) * 38.0)
		draw_colored_polygon(cp, Color("120806"))
		var cp2 := PackedVector2Array()
		for i in 6:
			cp2.append(cc + Vector2.from_angle(-PI / 2 + i * TAU / 6.0) * 32.0)
		draw_colored_polygon(cp2, Color("c4202a"))
		UIKit.draw_icon(self, "trophy", cc, 44.0)
		var cur := Progression.champs_tier(int(c.f_w))
		var step := (size.x - 150.0) / tiers.size()
		for i in tiers.size():
			var t: Dictionary = tiers[i]
			var p := Vector2(120 + step * (i + 0.5), y)
			var reached: bool = c.stage != "qualifier" and int(c.f_w) >= int(t.wins)
			var is_cur: bool = c.stage != "qualifier" and t.rank == cur.rank
			var roman: String = String(t.rank).replace("RANK ", "")
			var heat := float(i) / float(tiers.size() - 1)
			ChampsShield.draw_shield(self, p, 64.0 if is_cur else 54.0, t.color, roman, reached or c.stage == "qualifier", heat)
			if is_cur:
				draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -56), p + Vector2(10, -56), p + Vector2(0, -43)]), Color("4fd3a0"))


## Small static helper so inner classes can draw shields.
class ChampsShield:
	## Red bevelled shield with a Roman numeral. `heat` 0..1 runs from deep
	## maroon (Rank X) to bright crimson (Rank I).
	static func draw_shield(ci: CanvasItem, c: Vector2, h: float, _col: Color, label: String, lit: bool, heat := 0.5) -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var u := h / 60.0
		var shape: Array[Vector2] = [Vector2(-21, -26), Vector2(-12, -30), Vector2(12, -30), Vector2(21, -26), Vector2(21, 6), Vector2(0, 30), Vector2(-21, 6)]
		var frame := PackedVector2Array()
		var rim := PackedVector2Array()
		var face := PackedVector2Array()
		for p: Vector2 in shape:
			frame.append(c + p * u * 1.16)
			rim.append(c + p * u)
			face.append(c + p * u * 0.78 + Vector2(0, -1.5 * u))
		var red := Color("5a0f12").lerp(Color("e8262c"), heat)
		if not lit:
			red = red.darkened(0.55)
		ci.draw_colored_polygon(frame, Color("140405"))
		# bevelled rim: lighter top-left edges, darker bottom-right
		for i in shape.size():
			var j := (i + 1) % shape.size()
			var mid: Vector2 = (shape[i] + shape[j]) * 0.5
			var light := clampf(0.55 - (mid.x * 0.5 + mid.y) / 60.0, 0.0, 1.0)
			ci.draw_colored_polygon(PackedVector2Array([rim[i], rim[j], face[j], face[i]]), red.darkened(0.4).lerp(red.lightened(0.35), light))
		ci.draw_colored_polygon(face, red)
		# soft sheen across the top of the face
		ci.draw_colored_polygon(PackedVector2Array([face[0], face[1], face[2], face[3], c + Vector2(16, -10) * u, c + Vector2(-16, -10) * u]), Color(1, 1, 1, 0.14 if lit else 0.05))
		S2.text_c(ci, label, c + Vector2(0, 6 * u), int(17 * u), Color.WHITE if lit else Color(1, 1, 1, 0.55), maxi(3, int(5 * u)))


## Card shell shared by the panels.
class Card extends Control:
	func panel_bg() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.12, 0.07, 0.06, 0.92))
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.9, 0.6, 0.3, 0.25), false, 2.0)


class Requirements extends Card:
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var c := Save.champs()
		S2.text_l(self, "ENTRY REQUIREMENTS", Vector2(0, 20), 18, Color("4fd3a0"))
		var rows := [
			["Qualifier wins", "%d / %d" % [mini(int(c.q_w) if c.stage == "qualifier" else Progression.CHAMPS_Q_WINS, Progression.CHAMPS_Q_WINS), Progression.CHAMPS_Q_WINS], c.stage != "qualifier"],
			["Losses allowed", "%d / %d" % [int(c.q_l) if c.stage == "qualifier" else 0, Progression.CHAMPS_Q_LOSSES], c.stage != "qualifier"],
		]
		for i in rows.size():
			var r: Array = rows[i]
			var y := 40.0 + i * 50.0
			draw_rect(Rect2(0, y, size.x, 42), Color(0.12, 0.07, 0.06, 0.92))
			UIKit.draw_icon(self, "trophy" if i == 0 else "lock", Vector2(22, y + 21), 24.0)
			S2.text_l(self, r[0], Vector2(42, y + 28), 16, Color.WHITE)
			S2.text_r(self, r[1], Vector2(size.x - 40, y + 28), 16, Color(1, 1, 1, 0.85))
			draw_circle(Vector2(size.x - 18, y + 21), 8, Color("4fd3a0") if r[2] else Color(1, 1, 1, 0.15))
		var status: String = "Qualified" if c.stage != "qualifier" else "Not qualified"
		S2.text_l(self, status, Vector2(0, 160), 18, Color("4fd3a0") if c.stage != "qualifier" else Color(1, 1, 1, 0.6))


class RewardsCard extends Card:
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		panel_bg()
		var c := Save.champs()
		S2.text_l(self, "RANK REWARDS", Vector2(18, 34), 20, Color.WHITE)
		S2.text_l(self, "Win Finals matches to unlock better rewards", Vector2(18, 58), 14, Color(1, 1, 1, 0.65))
		# next rank to reach (or the rank you finished on)
		var wins := int(c.f_w) if c.stage != "qualifier" else 0
		var target: Dictionary = Progression.CHAMPS_TIERS[Progression.CHAMPS_TIERS.size() - 1]
		for t in Progression.CHAMPS_TIERS:
			if int(t.wins) > wins:
				target = t
		if c.stage == "rewards":
			target = Progression.champs_tier(wins)
		var ti := Progression.CHAMPS_TIERS.find(target)
		var heat := 1.0 - float(ti) / float(Progression.CHAMPS_TIERS.size() - 1)
		ChampsShield.draw_shield(self, Vector2(70, 150), 78.0, target.color, String(target.rank).replace("RANK ", ""), true, heat)
		S2.text_l(self, "RED " + String(target.rank).replace("RANK ", ""), Vector2(130, 120), 24, Color("ff6a6a"))
		S2.text_l(self, "%d / %d wins" % [mini(wins, int(target.wins)), int(target.wins)], Vector2(130, 152), 22, Color("6ad0ff"))
		var x := 140.0
		for rw: Dictionary in target.rewards:
			RewardTile.draw_icon(self, rw, Vector2(x, 200), 16.0)
			if rw.has("amount"):
				S2.text_c(self, str(rw.amount), Vector2(x, 232), 13, Color.WHITE, 4)
			x += 56.0


class PerformanceCard extends Card:
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		panel_bg()
		var c := Save.champs()
		var fin: bool = c.stage != "qualifier"
		var w := int(c.f_w) if fin else int(c.q_w)
		var l := int(c.f_l) if fin else int(c.q_l)
		var remaining := (Progression.CHAMPS_F_MATCHES - w - l) if fin else (Progression.CHAMPS_Q_WINS - w)
		S2.text_l(self, "PERFORMANCE" + ("" if fin else "  ·  QUALIFIER"), Vector2(18, 34), 20, Color.WHITE)
		S2.text_c(self, str(w), Vector2(size.x * 0.5, 120), 56, Color.WHITE, 8)
		S2.text_c(self, "Points", Vector2(size.x * 0.5, 146), 16, Color(1, 1, 1, 0.75))
		var cols := [["Wins", w], ["Losses", l], ["Remaining" if fin else "Wins needed", maxi(0, remaining)]]
		for i in cols.size():
			var x := size.x * (0.2 + i * 0.3)
			S2.text_c(self, cols[i][0], Vector2(x, 196), 16, Color.WHITE)
			S2.text_c(self, str(cols[i][1]), Vector2(x, 228), 26, Color("6ad0ff"), 5)
