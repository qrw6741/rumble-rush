extends Control
## CHAMPS: the competitive mode. Qualify (5 wins before 3 losses), then play the
## 15-match Finals. Your Finals win count decides your Champs rank and rewards.

const Lobby := preload("res://scripts/ui/main_menu.gd")
const S := preload("res://scripts/ui/main_menu.gd").SlantButton

var _status: StatusPanel

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var bg := UIKit.MenuBackground.new()
	bg.top = Color("4a1f8a")
	bg.bottom = Color("120a2e")
	add_child(bg)
	Lobby.build_header(self, "CHAMPS", func(): Router.goto("menu"))
	var home := S.new()
	home.color = Color("27334d")
	home.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	home.position = Vector2(-118, 6)
	home.size = Vector2(104, 72)
	home.custom_draw = func(ci: Control):
		UIKit.draw_icon(ci, "home", Vector2(52, 34), 58.0)
	home.pressed.connect(func(): Router.goto("menu"))
	add_child(home)

	_status = StatusPanel.new()
	_status.position = Vector2(40, 100)
	_status.size = Vector2(640, 470)
	add_child(_status)

	var ladder := Ladder.new()
	ladder.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ladder.position = Vector2(-560, 100)
	ladder.size = Vector2(520, 600)
	add_child(ladder)

	var c := Save.champs()
	var btn: Button
	if c.stage == "rewards":
		btn = UIKit.button("CLAIM REWARDS", UIKit.GREEN, 30, Vector2(400, 84))
		btn.pressed.connect(_claim)
	else:
		btn = UIKit.button("PLAY QUALIFIER" if c.stage == "qualifier" else "PLAY FINALS MATCH", UIKit.YELLOW, 30, Vector2(400, 84))
		btn.pressed.connect(_play)
	btn.position = Vector2(160, 596)
	add_child(btn)
	UIKit.pop_in(_status)
	UIKit.pop_in(ladder, 0.08)

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


## Left panel: stage, win/loss pips, record and projected rank.
class StatusPanel extends Control:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var c := Save.champs()
		var w := size.x
		var h := size.y
		draw_rect(Rect2(6, 10, w, h), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(0, 0, w, h), UIKit.DARK)
		draw_rect(Rect2(4, 4, w - 8, h - 8), Color("241a4a"))
		# trophy crest
		var cc := Vector2(110, 140)
		for k in 10:
			var a := _t * 0.3 + k * TAU / 10.0
			draw_colored_polygon(PackedVector2Array([cc, cc + Vector2.from_angle(a - 0.12) * 120.0, cc + Vector2.from_angle(a + 0.12) * 120.0]), Color(1, 0.8, 0.2, 0.06))
		UIKit.draw_icon(self, "trophy", cc, 150.0)
		var stage_name: String = {"qualifier": "QUALIFIER", "finals": "FINALS", "rewards": "FINALS COMPLETE"}.get(c.stage, "")
		S2.text_l(self, stage_name, Vector2(220, 70), 38, UIKit.YELLOW)
		match c.stage:
			"qualifier":
				S2.text_l(self, "Win %d before you lose %d to reach the Finals." % [Progression.CHAMPS_Q_WINS, Progression.CHAMPS_Q_LOSSES], Vector2(220, 104), 16, Color(1, 1, 1, 0.8))
				S2.text_l(self, "WINS", Vector2(220, 160), 20, Color("8dff9a"))
				for i in Progression.CHAMPS_Q_WINS:
					_pip(Vector2(310 + i * 54, 152), i < int(c.q_w), Color("4fd36a"))
				S2.text_l(self, "LOSSES", Vector2(220, 222), 20, Color("ff9a9a"))
				for i in Progression.CHAMPS_Q_LOSSES:
					_pip(Vector2(310 + i * 54, 214), i < int(c.q_l), Color("ff4d5e"))
			_:
				var played := int(c.f_w) + int(c.f_l)
				S2.text_l(self, "Play all %d matches. More wins, better rank." % Progression.CHAMPS_F_MATCHES, Vector2(220, 104), 16, Color(1, 1, 1, 0.8))
				S2.text_l(self, "%d W  -  %d L" % [int(c.f_w), int(c.f_l)], Vector2(220, 168), 44, Color.WHITE)
				S2.text_l(self, "MATCH %d / %d" % [mini(played + 1, Progression.CHAMPS_F_MATCHES), Progression.CHAMPS_F_MATCHES], Vector2(220, 206), 20, Color("c9d3f0"))
				# match strip
				for i in Progression.CHAMPS_F_MATCHES:
					var p := Vector2(40 + i * 38, 290)
					var col := Color("3a3060")
					if i < int(c.f_w):
						col = Color("4fd36a")
					elif i < played:
						col = Color("ff4d5e")
					draw_rect(Rect2(p - Vector2(15, 15), Vector2(30, 30)), UIKit.DARK)
					draw_rect(Rect2(p - Vector2(12, 12), Vector2(24, 24)), col)
		# projected rank
		var tier := Progression.champs_tier(int(c.f_w))
		var box := Rect2(30, 340, w - 60, 100)
		draw_rect(box, UIKit.DARK)
		draw_rect(box.grow(-4), tier.color.darkened(0.55))
		var label := "CURRENT RANK" if c.stage != "qualifier" else "BEST RANK"
		S2.text_l(self, label, box.position + Vector2(22, 34), 18, Color(1, 1, 1, 0.75))
		var shown: String = tier.rank if c.stage != "qualifier" else (c.best if c.best != "" else "-")
		S2.text_l(self, shown, box.position + Vector2(22, 80), 40, tier.color.lightened(0.2) if c.stage != "qualifier" else Color.WHITE)
		S2.text_r(self, "RUNS PLAYED  %d" % int(c.runs), box.end - Vector2(22, 20), 16, Color(1, 1, 1, 0.7))

	func _pip(c: Vector2, on: bool, col: Color) -> void:
		draw_circle(c, 20, UIKit.DARK)
		draw_circle(c, 16, col if on else Color("3a3060"))
		if on:
			draw_circle(c + Vector2(-5, -5), 5, Color(1, 1, 1, 0.35))


## Right panel: every Champs rank, the wins it needs and its rewards.
class Ladder extends Control:
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var c := Save.champs()
		var cur := Progression.champs_tier(int(c.f_w))
		var row_h := 56.0
		S2.text_l(self, "FINALS REWARDS", Vector2(10, 26), 24, Color.WHITE)
		for i in Progression.CHAMPS_TIERS.size():
			var t: Dictionary = Progression.CHAMPS_TIERS[i]
			var r := Rect2(0, 40 + i * row_h, size.x, row_h - 6)
			var is_cur: bool = c.stage != "qualifier" and t.rank == cur.rank
			draw_rect(r, UIKit.YELLOW if is_cur else UIKit.DARK)
			draw_rect(r.grow(-3), t.color.darkened(0.5))
			draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(8, r.size.y - 6)), t.color)
			S2.text_l(self, t.rank, r.position + Vector2(22, 34), 22, Color.WHITE)
			S2.text_l(self, "%d+ W" % int(t.wins), r.position + Vector2(140, 34), 18, Color(1, 1, 1, 0.75))
			var x := r.end.x - 40
			var rws: Array = t.rewards
			for k in range(rws.size() - 1, -1, -1):
				var rw: Dictionary = rws[k]
				RewardTile.draw_icon(self, rw, Vector2(x, r.get_center().y - 4), 16.0)
				if rw.has("amount"):
					S2.text_c(self, str(rw.amount), Vector2(x, r.end.y - 4), 12, Color.WHITE, 4)
				x -= 64
