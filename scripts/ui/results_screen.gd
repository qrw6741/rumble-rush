extends Control
## Post-match screen: result banner, both teams' stats with MVP, animated rewards.

var data: Dictionary
var _t := 0.0

func setup(params: Dictionary) -> void:
	data = params

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var result: String = data.get("result", "draw")
	var bg := UIKit.MenuBackground.new()
	match result:
		"win":
			bg.top = Color("6b4a10")
			bg.bottom = Color("1f1240")
		"loss":
			bg.top = Color("5a1424")
			bg.bottom = Color("140a26")
		_:
			bg.top = Color("3a3a5a")
			bg.bottom = Color("141428")
	add_child(bg)
	Sfx.play_music("music_menu")

	# your brawler, big: celebrating on a win, slumped on a loss
	var hero := Hero.new()
	hero.brawler_id = data.get("brawler", "bront")
	hero.result = result
	hero.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hero.position = Vector2(0, -330)
	hero.size = Vector2(300, 330)
	add_child(hero)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 30
	root.offset_right = -30
	root.offset_top = 14
	root.offset_bottom = -14
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var title_text: String = {"win": "VICTORY!", "loss": "DEFEAT", "draw": "DRAW"}[result]
	var place: int = data.get("place", 0)
	if place > 0:
		title_text = "#1 WINNER!" if place == 1 else "RANK #%d" % place
	var title_col: Color = {"win": UIKit.YELLOW, "loss": UIKit.RED, "draw": Color.WHITE}[result]
	var title := UIKit.label(title_text, 72, title_col, 16, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(title)
	var sub := "%s  ·  %s" % [Config.MODES[data.mode].name, MapData.MAPS[data.map].name]
	if data.get("forfeit", false):
		sub += "  ·  LEFT MATCH"
	root.add_child(UIKit.label(sub, 18, Color(1, 1, 1, 0.75), 5, HORIZONTAL_ALIGNMENT_CENTER))
	title.pivot_offset = Vector2(610, 50)
	title.scale = Vector2(0.4, 0.4)
	create_tween().tween_property(title, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# teams (or a top-10 leaderboard in Showdown)
	var view: int = data.get("view_team", 0)
	if place > 0:
		var sorted: Array = data.players.duplicate()
		sorted.sort_custom(func(a, b): return int(a.place) < int(b.place))
		for rowi in 2:
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 8)
			root.add_child(row)
			for k in range(rowi * 5, rowi * 5 + 5):
				if k < sorted.size():
					row.add_child(_solo_card(sorted[k]))
	for team in ([] if place > 0 else [view, 1 - view]):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		root.add_child(row)
		var tag := UIKit.label("YOUR TEAM" if team == view else "ENEMY", 16, Config.tc(team).lightened(0.3), 5)
		tag.custom_minimum_size = Vector2(110, 0)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
		for p in data.players:
			if p.team == team:
				row.add_child(_player_card(p))

	# rewards + buttons
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 26)
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(bottom)
	var rewards: Dictionary = data.get("rewards", {})
	var rp := UIKit.panel(Color(0, 0, 0, 0.4), 18, 3)
	rp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(rp)
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 26)
	rp.add_child(rh)
	var tr: int = rewards.get("trophies", 0)
	rh.add_child(_reward("trophy", tr, UIKit.YELLOW, true))
	rh.add_child(_reward("coin", rewards.get("credits", 0), Color("ffe08a"), false))
	rh.add_child(_reward("xp", rewards.get("xp", 0), Color("8fd0ff"), false))
	var tok := VBoxContainer.new()
	tok.alignment = BoxContainer.ALIGNMENT_CENTER
	var tic := TokenIcon.new()
	tic.custom_minimum_size = Vector2(56, 56)
	tic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tok.add_child(tic)
	tok.add_child(UIKit.label("+%d" % int(rewards.get("tokens", 0)), 30, Color("8fd0ff"), 8, HORIZONTAL_ALIGNMENT_CENTER))
	rh.add_child(tok)
	if int(rewards.get("mastery_gain", 0)) > 0:
		var ml := Progression.mastery_level(int(rewards.mastery_points))
		var mtxt := "+%d MASTERY" % int(rewards.mastery_gain)
		if rewards.get("mastery_level_up", false):
			mtxt = "MASTERY: " + Progression.MASTERY_NAMES[ml] + "!"
		var mlb := UIKit.label(mtxt, 20, Progression.MASTERY_COLORS[ml].lightened(0.2), 6)
		mlb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rh.add_child(mlb)
	if rewards.get("rank_up", false):
		var ru := UIKit.label("RANK UP!  %d" % int(rewards.new_rank), 22, Progression.rank_color(int(rewards.new_rank)).lightened(0.3), 6)
		ru.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rh.add_child(ru)
	if rewards.get("level_up", false):
		var lu := UIKit.label("LEVEL UP!  %d" % rewards.new_level, 22, UIKit.GREEN, 6)
		lu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rh.add_child(lu)

	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(btns)
	var again := UIKit.button("PLAY AGAIN", UIKit.YELLOW, 28, Vector2(280, 72))
	if data.get("champs", false):
		again.text = "BACK TO CHAMPS"
		again.pressed.connect(func(): Router.goto("champs"))
		var ci: Dictionary = data.get("champs_info", {})
		var msg := ""
		if ci.get("qualified", false):
			msg = "QUALIFIED FOR CHAMPS FINALS!"
		elif ci.get("failed", false):
			msg = "QUALIFIER OVER - TRY AGAIN"
		elif ci.get("finished", false):
			msg = "FINALS COMPLETE! CLAIM YOUR REWARDS"
		else:
			var c := Save.champs()
			msg = ("QUALIFIER  %d W - %d L" % [int(c.q_w), int(c.q_l)]) if c.stage == "qualifier" else ("FINALS  %d W - %d L" % [int(c.f_w), int(c.f_l)])
		btns.add_child(UIKit.label("CHAMPS: " + msg, 18, UIKit.YELLOW, 6, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		again.pressed.connect(func(): Router.goto("match", {"mode": data.mode, "brawler": data.brawler}))
	btns.add_child(again)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	btns.add_child(h)
	var change := UIKit.button("BRAWLERS", UIKit.BLUE, 18, Vector2(135, 54))
	change.pressed.connect(func(): Router.goto("select"))
	h.add_child(change)
	var menu := UIKit.button("MENU", UIKit.PANEL_LIGHT, 18, Vector2(135, 54))
	menu.pressed.connect(func(): Router.goto("menu"))
	h.add_child(menu)

func _player_card(p: Dictionary) -> Control:
	var col: Color = Config.tc(p.team)
	var panel := PanelContainer.new()
	var sb := UIKit.box(col.darkened(0.55) if not p.is_player else col.darkened(0.3), 16, 3 if not p.is_player else 5, UIKit.DARK if not p.is_player else Color("4dff7a"), 0)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 8
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(250, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	panel.add_child(h)
	var por := UIKit.BrawlerPortrait.new()
	por.brawler_id = p.brawler
	por.art_scale = 1.05
	por.custom_minimum_size = Vector2(84, 96)
	h.add_child(por)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	h.add_child(v)
	var nm := UIKit.label(p.name, 16, Color.WHITE, 5)
	v.add_child(nm)
	v.add_child(UIKit.label(Config.BRAWLERS[p.brawler].name + "  ·  LVL %d" % p.level, 12, col.lightened(0.4), 4))
	v.add_child(UIKit.label("KO %d   ·   DIED %d" % [p.kos, p.deaths], 14, Color.WHITE, 4))
	var extra := "DMG %d" % p.damage
	if p.healing > 0:
		extra += "  ·  HEAL %d" % p.healing
	if data.mode == "gem_grab":
		extra += "  ·  GEMS %d" % p.gems
	v.add_child(UIKit.label(extra, 12, Color(1, 1, 1, 0.75), 4))
	if p.mvp:
		var star := UIKit.IconDraw.new()
		star.kind = "star"
		star.custom_minimum_size = Vector2(34, 34)
		star.position = Vector2(4, 4)
		por.add_child(star)
		v.add_child(UIKit.label("STAR PLAYER", 13, UIKit.YELLOW, 5))
	return panel

func _reward(kind: String, amount: int, col: Color, signed: bool) -> Control:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := UIKit.IconDraw.new()
	ic.kind = kind
	ic.custom_minimum_size = Vector2(56, 56)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := UIKit.label("0", 30, col, 8, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(l)
	var setter := func(x: float):
		var n := int(round(x))
		l.text = ("+" if signed and n > 0 else "") + str(n)
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_method(setter, 0.0, float(amount), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): if amount != 0: Sfx.play("gem_pickup", -4.0, 0.0))
	return v


class TokenIcon extends Control:
	func _draw() -> void:
		UIKit.draw_icon(self, "token", size * 0.5, 64.0)


## Compact leaderboard card for Showdown placements.
func _solo_card(p: Dictionary) -> Control:
	var top4: bool = int(p.place) <= 4
	var panel := PanelContainer.new()
	var col := Color("2f9e4a") if top4 else Color("4a5570")
	var sb := UIKit.box(col.darkened(0.3), 14, 5 if p.is_player else 3, Color("4dff7a") if p.is_player else UIKit.DARK, 0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(228, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	panel.add_child(h)
	h.add_child(UIKit.label("#%d" % int(p.place), 26, UIKit.YELLOW if top4 else Color.WHITE, 8))
	var por := UIKit.BrawlerPortrait.new()
	por.brawler_id = p.brawler
	por.art_scale = 0.9
	por.backdrop = false
	por.view_kind = "bust"
	por.custom_minimum_size = Vector2(64, 64)
	h.add_child(por)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.add_child(UIKit.label(p.name, 15, Color.WHITE, 5))
	v.add_child(UIKit.label("KO %d  ·  DMG %d" % [p.kos, p.damage], 12, Color(1, 1, 1, 0.8), 4))
	h.add_child(v)
	return panel


## The player's brawler on the results screen. Win: happy bouncing with confetti.
## Loss: slumped, eyes closed, dimmed, with a little rain cloud.
class Hero extends Control:
	var brawler_id := "bront"
	var result := "win"
	var _t := 0.0
	var _confetti: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if result == "win":
			for i in 50:
				_confetti.append([Vector2(randf_range(0, 300), randf_range(-400, 0)), randf_range(60, 140), randf() * TAU,
					[Color("ffd23a"), Color("ff4d9a"), Color("4fd3ff"), Color("8cff5a"), Color.WHITE][i % 5]])

	func _process(d: float) -> void:
		_t += d
		for c in _confetti:
			c[0].y += c[1] * d
			c[0].x += sin(_t * 3.0 + c[2]) * 30.0 * d
			c[2] += d * 4.0
			if c[0].y > size.y:
				c[0].y = -20.0
		queue_redraw()

	func _draw() -> void:
		var skin := Save.selected_skin(brawler_id)
		var feet := Vector2(size.x * 0.5, size.y - 30)
		draw_colored_polygon(PackedVector2Array([feet + Vector2(-70, 0), feet + Vector2(70, 0), feet + Vector2(60, 10), feet + Vector2(-60, 10)]), Color(0, 0, 0, 0.25))
		if result == "win":
			var hop := absf(sin(_t * 5.0)) * 26.0
			BrawlerArt.draw(self, brawler_id, feet - Vector2(0, hop), 3.4, {"t": _t, "aim": Vector2(1, -0.6), "moving": true, "skin": skin, "no_shadow": true, "recoil": 0.5 + 0.5 * sin(_t * 5.0)})
			for c in _confetti:
				draw_set_transform(c[0], c[2], Vector2.ONE)
				draw_rect(Rect2(-4, -2, 8, 4), c[3])
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_set_transform(feet, -0.12, Vector2.ONE)
			BrawlerArt.draw(self, brawler_id, Vector2(0, 8), 3.1, {"t": _t * 0.3, "aim": Vector2(1, 0.9), "moving": false, "skin": skin, "no_shadow": true, "blink": true, "alpha": 0.85})
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# rain cloud
			var cc := Vector2(size.x * 0.5, 50)
			for k in 3:
				draw_circle(cc + Vector2(-26 + k * 26, sin(_t + k) * 2.0), 22, Color("5a5f78"))
			for k in 6:
				var ph := fmod(_t * 1.6 + k * 0.17, 1.0)
				var p := cc + Vector2(-40 + k * 16, 20 + ph * 110)
				draw_line(p, p + Vector2(-2, 10), Color(0.6, 0.8, 1, 1.0 - ph), 2.0, true)
