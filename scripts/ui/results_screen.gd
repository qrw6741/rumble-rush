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
	if data.get("debug", false):
		_debug_banner.call_deferred()
	if int(data.get("place", 0)) == 0 and data.has("players"):
		_team_layout(result)
		return
	if int(data.get("place", 0)) > 0:
		_showdown_layout(result)
		return

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
	_streak_banner(rewards, Vector2(40, 140))
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
		again.pressed.connect(func(): Router.goto("match", {"mode": data.mode, "brawler": data.brawler, "debug": data.get("debug", false)}))
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
			BrawlerArt.draw(self, brawler_id, feet + Vector2(0, 8), 3.0, {"t": 0.5, "aim": Vector2(1, 0.9), "moving": false, "skin": skin, "no_shadow": true, "blink": true, "alpha": 0.85})
			# rain cloud
			var cc := Vector2(size.x * 0.5, 50)
			for k in 3:
				draw_circle(cc + Vector2(-26 + k * 26, sin(_t + k) * 2.0), 22, Color("5a5f78"))
			for k in 6:
				var ph := fmod(_t * 1.6 + k * 0.17, 1.0)
				var p := cc + Vector2(-40 + k * 16, 20 + ph * 110)
				draw_line(p, p + Vector2(-2, 10), Color(0.6, 0.8, 1, 1.0 - ph), 2.0, true)


# ====================================================================== 3v3 layout
## Split screen: your team big on the blue side, the enemy smaller on the red
## side, a stat card under every brawler, awards, and HAVE FUN? + PROCEED.
func _team_layout(result: String) -> void:
	for c in get_children():
		c.queue_free()
	var view: int = data.get("view_team", 0)
	var stage := TeamStage.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.result = result
	stage.view = view
	stage.players = data.players
	add_child(stage)

	# awards: most KOs / most damage across everyone
	var best_ko: Dictionary = {}
	var best_dmg: Dictionary = {}
	for p: Dictionary in data.players:
		if best_ko.is_empty() or int(p.kos) > int(best_ko.kos):
			best_ko = p
		if best_dmg.is_empty() or int(p.damage) > int(best_dmg.damage):
			best_dmg = p

	var ours: Array = data.players.filter(func(p): return int(p.team) == view)
	var theirs: Array = data.players.filter(func(p): return int(p.team) != view)
	for i in ours.size():
		var card := _stat_card(ours[i], true, best_ko, best_dmg)
		card.position = Vector2(150 + i * 186, 404)
		add_child(card)
		UIKit.pop_in(card, 0.15 + i * 0.06, Vector2(0, 30))
	for i in theirs.size():
		var card := _stat_card(theirs[i], false, best_ko, best_dmg)
		card.position = Vector2(760 + i * 148, 330)
		add_child(card)
		UIKit.pop_in(card, 0.35 + i * 0.06, Vector2(0, 30))

	# title + trophies + other rewards
	var title_text: String = {"win": "VICTORY!", "loss": "DEFEAT", "draw": "DRAW"}[result]
	var tl := TitleSlant.new()
	tl.text = title_text
	tl.col = {"win": Color("fff3c2"), "loss": Color("ffd0d0"), "draw": Color.WHITE}[result]
	tl.position = Vector2(60, 14)
	tl.size = Vector2(520, 120)
	add_child(tl)
	var rewards: Dictionary = data.get("rewards", {})
	var rr := RewardStrip.new()
	rr.rewards = rewards
	rr.position = Vector2(66, 118)
	rr.size = Vector2(620, 50)
	add_child(rr)
	_streak_banner(rewards, Vector2(70, 176))

	# HAVE FUN? + PROCEED
	var fun := UIKit.label("HAVE FUN?", 22, Color.WHITE, 6, HORIZONTAL_ALIGNMENT_CENTER)
	fun.position = Vector2(820, 588)
	fun.size = Vector2(220, 30)
	add_child(fun)
	for k in 2:
		var b := ThumbButton.new()
		b.up = k == 0
		b.position = Vector2(830 + k * 106, 622)
		b.size = Vector2(96, 72)
		b.pressed.connect(func():
			Sfx.play("ui_confirm")
			for c in get_children():
				if c is ThumbButton:
					c.disabled = true
					c.queue_redraw())
		add_child(b)
	var proceed := UIKit.button("PROCEED", UIKit.BLUE, 30, Vector2(230, 72))
	proceed.position = Vector2(1040, 622)
	if data.get("champs", false):
		proceed.pressed.connect(func(): Router.goto("champs"))
	elif data.get("ranked", false):
		proceed.pressed.connect(func(): Router.goto("ranked"))
	else:
		proceed.pressed.connect(func(): Router.goto("menu"))
	add_child(proceed)
	if data.get("ranked", false):
		var rb := RankedBanner.new()
		rb.info = data.get("ranked_info", {})
		rb.position = Vector2(700, 92)
		rb.size = Vector2(540, 96)
		add_child(rb)
	var again := UIKit.button("PLAY AGAIN", UIKit.YELLOW, 18, Vector2(180, 48))
	again.position = Vector2(1090, 560)
	if data.get("ranked", false):
		again.text = "RANKED"
		again.pressed.connect(func(): Router.goto("ranked"))
	elif data.get("champs", false):
		again.text = "CHAMPS"
		again.pressed.connect(func(): Router.goto("champs"))
	else:
		again.pressed.connect(func(): Router.goto("match", {"mode": data.mode, "brawler": data.brawler, "debug": data.get("debug", false)}))
	add_child(again)

func _debug_banner() -> void:
	var l := UIKit.label("TEST MATCH  ·  NOTHING WAS SAVED", 22, Color("ff7ad9"), 6, HORIZONTAL_ALIGNMENT_CENTER)
	l.position = Vector2(230, 566)
	l.size = Vector2(520, 34)
	add_child(l)

func _showdown_layout(result: String) -> void:
	for c in get_children():
		c.queue_free()
	var place: int = int(data.get("place", 1))
	var rewards: Dictionary = data.get("rewards", {})
	var stage := SDStage.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.brawler_id = data.get("brawler", "bront")
	stage.happy = result == "win" or place <= 3
	stage.place = place
	stage.rewards = rewards
	add_child(stage)
	# profile icon (top right)
	var pic := UIKit.ProfileIcon.new()
	pic.position = Vector2(1112, 116)
	pic.size = Vector2(92, 92)
	pic.custom_minimum_size = pic.size
	add_child(pic)
	# exit icon (top right corner)
	var ex := UIKit.button("", UIKit.BLUE, 18, Vector2(76, 52))
	ex.position = Vector2(1186, 12)
	ex.pressed.connect(func(): Router.goto("champs" if data.get("champs", false) else ("ranked" if data.get("ranked", false) else "menu")))
	var arrow := ExitArrow.new()
	arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ex.add_child(arrow)
	add_child(ex)
	var again := UIKit.button("PLAY AGAIN", UIKit.YELLOW, 24, Vector2(210, 64))
	again.position = Vector2(820, 630)
	if data.get("ranked", false):
		again.text = "RANKED"
		again.pressed.connect(func(): Router.goto("ranked"))
		var rb := RankedBanner.new()
		rb.info = data.get("ranked_info", {})
		rb.position = Vector2(30, 290)
		rb.size = Vector2(540, 96)
		add_child(rb)
	else:
		again.pressed.connect(func(): Router.goto("match", {"mode": data.mode, "brawler": data.brawler, "debug": data.get("debug", false)}))
	add_child(again)
	var exit := UIKit.button("EXIT", UIKit.BLUE, 26, Vector2(210, 64))
	exit.position = Vector2(1050, 630)
	exit.pressed.connect(func(): Router.goto("ranked" if data.get("ranked", false) else "menu"))
	add_child(exit)

func _streak_banner(rewards: Dictionary, pos: Vector2) -> void:
	var st := int(rewards.get("streak", 0))
	if st >= 2:
		var sb := UIKit.StreakBadge.new()
		sb.streak = st
		sb.show_label = false
		sb.position = pos
		sb.size = Vector2(56, 56)
		add_child(sb)
		var txt := "%d WIN STREAK!" % st
		var bonus := "BONUS  +%d TROPHIES   +%d COINS" % [int(rewards.get("streak_trophies", 0)), int(rewards.get("streak_credits", 0))]
		var l1 := UIKit.label(txt, 26, Progression.streak_color(st).lightened(0.25), 6)
		l1.position = pos + Vector2(64, -2)
		add_child(l1)
		var l2 := UIKit.label(bonus, 16, Color.WHITE, 5)
		l2.position = pos + Vector2(66, 30)
		add_child(l2)
	elif rewards.get("streak_broken", false):
		var l := UIKit.label("STREAK ENDED  (%d WINS)" % int(rewards.get("streak_before", 0)), 18, Color("ff9a8a"), 5)
		l.position = pos + Vector2(0, 8)
		add_child(l)

func _stat_card(p: Dictionary, big: bool, best_ko: Dictionary, best_dmg: Dictionary) -> Control:
	var c := StatCard.new()
	c.p = p
	c.big = big
	c.size = Vector2(178, 140) if big else Vector2(142, 110)
	c.award = ""
	if p == best_ko and int(p.kos) > 0:
		c.award = "Most KOs"
	elif p == best_dmg:
		c.award = "Most Damage"
	return c


class TeamStage extends Control:
	var result := "win"
	var view := 0
	var players: Array = []
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# diagonal split: blue (us) and red (them)
		draw_rect(Rect2(0, 0, w, h), Color("2f7ef0"))
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.62, 0), Vector2(w, 0), Vector2(w, h), Vector2(w * 0.54, h)]), Color("c4282a"))
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.6, 0), Vector2(w * 0.625, 0), Vector2(w * 0.545, h), Vector2(w * 0.52, h)]), Color("e8453a"))
		for k in 5:
			var x := fmod(_t * 30.0 + k * 220.0, w * 0.6)
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 50, 0), Vector2(x - 80, h), Vector2(x - 130, h)]), Color(1, 1, 1, 0.04))
		var we_won: bool = result == "win"
		var ours: Array = players.filter(func(p): return int(p.team) == view)
		var theirs: Array = players.filter(func(p): return int(p.team) != view)
		for i in ours.size():
			var p: Dictionary = ours[i]
			var feet := Vector2(239 + i * 186, 388)
			_pose(p, feet, 2.8, we_won or result == "draw", i)
			if p.get("mvp", false):
				var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
				draw_colored_polygon(PackedVector2Array([feet + Vector2(-60, -250), feet + Vector2(60, -250), feet + Vector2(80, 10), feet + Vector2(-80, 10)]), Color(1, 0.95, 0.5, 0.18))
				S2.text_c(self, "STAR PLAYER", feet + Vector2(0, 14), 18, Color("ffe14d"), 5)
		for i in theirs.size():
			var p: Dictionary = theirs[i]
			_pose(p, Vector2(831 + i * 148, 312), 2.1, not we_won and result != "draw", i + 3)

	func _pose(p: Dictionary, feet: Vector2, sc: float, happy: bool, k: int) -> void:
		var id: String = p.brawler
		var skin: String = Save.selected_skin(id) if p.get("is_player", false) else ""
		draw_colored_polygon(PackedVector2Array([feet + Vector2(-40 * sc / 3.0, -4), feet + Vector2(40 * sc / 3.0, -4), feet + Vector2(34 * sc / 3.0, 6), feet + Vector2(-34 * sc / 3.0, 6)]), Color(0, 0, 0, 0.22))
		if happy:
			var hop := absf(sin(_t * 4.5 + k * 0.9)) * 14.0
			BrawlerArt.draw(self, id, feet - Vector2(0, hop), sc, {"t": _t + k, "aim": Vector2(1 if k % 2 == 0 else -1, -0.5), "moving": true, "skin": skin, "no_shadow": true, "recoil": 0.3 + 0.3 * sin(_t * 4.0 + k)})
		else:
			var sag := 6.0 + sin(_t * 1.5 + k) * 2.0
			BrawlerArt.draw(self, id, feet + Vector2(0, sag), sc * 0.96, {"t": k * 0.7, "aim": Vector2(1 if k % 2 == 0 else -1, 0.9), "skin": skin, "no_shadow": true, "blink": true, "alpha": 0.85})


class StatCard extends Control:
	var p: Dictionary = {}
	var big := true
	var award := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var w := size.x
		var h := size.y
		var mine: bool = p.get("is_player", false)
		var base := Color("16234a") if big else Color("4a1418")
		draw_rect(Rect2(0, 0, w, h), UIKit.DARK)
		draw_rect(Rect2(3, 3, w - 6, h - 6), base)
		draw_rect(Rect2(3, 3, w - 6, 34), base.lightened(0.12))
		if mine:
			draw_rect(Rect2(0, 0, w, h), Color("ffd23a"), false, 3.0)
		var fs := 15 if big else 12
		S2.text_l(self, String(p.name).left(14), Vector2(10, 22), fs, Color("ffe14d") if mine else Color.WHITE)
		if mine:
			S2.text_l(self, Save.title_name(Save.data.get("profile_title", "rookie")), Vector2(10, 36), 10, Color("ffb84d"))
		# thumbs-up badge in the corner
		var tb := Vector2(w - 20, 20)
		draw_circle(tb, 13, UIKit.DARK)
		draw_circle(tb, 11, Color("2a8cff"))
		ThumbButton.thumb(self, tb + Vector2(0, 1), 7.0, true, Color.WHITE)
		# KOs and deaths
		var row := Rect2(8, 44, w - 16, 34 if big else 28)
		draw_rect(row, Color(0, 0, 0, 0.3))
		UIKit.draw_icon(self, "attack", row.position + Vector2(18, row.size.y * 0.5), 26.0 if big else 22.0)
		S2.text_l(self, str(p.kos), row.position + Vector2(36, row.size.y * 0.5 + 8), 20 if big else 16, Color.WHITE)
		UIKit.draw_icon(self, "ko", row.position + Vector2(row.size.x * 0.58, row.size.y * 0.5), 26.0 if big else 22.0)
		S2.text_l(self, str(p.deaths), row.position + Vector2(row.size.x * 0.58 + 18, row.size.y * 0.5 + 8), 20 if big else 16, Color.WHITE)
		# damage
		var dy := row.end.y + (22 if big else 18)
		UIKit.draw_icon(self, "power_cell", Vector2(w * 0.5 - 40, dy - 6), 22.0)
		S2.text_l(self, str(p.damage), Vector2(w * 0.5 - 24, dy), 18 if big else 14, Color.WHITE)
		if award != "":
			S2.text_c(self, award, Vector2(w * 0.5, h - 6), 15 if big else 12, Color("ffd23a"), 5)


class TitleSlant extends Control:
	var text := "VICTORY!"
	var col := Color.WHITE
	var _t := 0.0
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var f := UIKit.bold()
		var k := minf(1.0, _t / 0.35)
		var sc := lerpf(0.4, 1.0, ease(k, -2.5))
		draw_set_transform_matrix(Transform2D(0.0, Vector2(sc, sc), -0.12, Vector2(0, 92)))
		draw_string_outline(f, Vector2(4, 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, 20, UIKit.DARK)
		draw_string_outline(f, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, 16, UIKit.DARK)
		draw_string(f, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, col)
		draw_set_transform_matrix(Transform2D.IDENTITY)


class RewardStrip extends Control:
	var rewards: Dictionary = {}
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var x := 0.0
		var items := [["trophy", int(rewards.get("trophies", 0))], ["coin", int(rewards.get("credits", 0))], ["xp", int(rewards.get("xp", 0))], ["token", int(rewards.get("tokens", 0))]]
		for it in items:
			UIKit.draw_icon(self, it[0], Vector2(x + 18, 22), 38.0)
			var v: int = it[1]
			S2.text_l(self, ("+%d" % v) if v >= 0 else str(v), Vector2(x + 40, 34), 26, Color.WHITE)
			x += 110.0
		if int(rewards.get("mastery_gain", 0)) > 0:
			S2.text_l(self, "+%d MASTERY" % int(rewards.mastery_gain), Vector2(x + 6, 32), 18, Color("ffd98a"))


## Round thumbs-up / thumbs-down button ("HAVE FUN?").
class ThumbButton extends Button:
	var up := true
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
	func _draw() -> void:
		var col := Color("2a8cff") if up else Color("e8453a")
		if disabled:
			col = col.darkened(0.4)
		draw_rect(Rect2(0, 0, size.x, size.y), UIKit.DARK)
		draw_rect(Rect2(3, 3, size.x - 6, size.y - 6), col)
		draw_rect(Rect2(3, 3, size.x - 6, 12), col.lightened(0.2))
		var c := size * 0.5
		draw_circle(c, 24, UIKit.DARK)
		draw_circle(c, 21, col.lightened(0.15))
		thumb(self, c, 13.0, up, Color.WHITE)

	## Simple vector thumb: fist + raised (or lowered) thumb.
	static func thumb(ci: CanvasItem, c: Vector2, r: float, is_up: bool, col: Color) -> void:
		var sgn := -1.0 if is_up else 1.0
		ci.draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.3 * sgn - r * 0.5), Vector2(r * 1.3, r * 1.0)), col)
		ci.draw_rect(Rect2(c + Vector2(-r * 1.05, -r * 0.45), Vector2(r * 0.32, r * 0.9)), col)
		var tip := c + Vector2(-r * 0.1, sgn * r * 1.05)
		ci.draw_line(c + Vector2(-r * 0.1, sgn * r * 0.2), tip, col, r * 0.42, true)
		ci.draw_circle(tip, r * 0.21, col)



## Showdown results in the "You are #N!" layout.
class SDStage extends Control:
	var brawler_id := "bront"
	var happy := true
	var place := 1
	var rewards: Dictionary = {}
	var _t := 0.0
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var W := size.x
		var H := size.y
		# blue backdrop with soft centre light and slanted streaks
		draw_rect(Rect2(0, 0, W, H), Color("1d5fd6"))
		for i in 8:
			var r := 620.0 - i * 70.0
			draw_circle(Vector2(W * 0.5, H * 0.52), r, Color(0.45, 0.75, 1.0, 0.05))
		for i in 6:
			var x0 := -200.0 + i * 260.0 + fmod(_t * 18.0, 260.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + 70, 0), Vector2(x0 - 180, H), Vector2(x0 - 250, H)]), Color(1, 1, 1, 0.035))
		# title band
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(560, 0), Vector2(520, 104), Vector2(0, 104)]), Color(0.05, 0.12, 0.35, 0.55))
		var f := UIKit.bold()
		var k := minf(1.0, _t / 0.35)
		var sc := lerpf(0.5, 1.0, ease(k, -2.5))
		var title := "You are #%d!" % place
		draw_set_transform_matrix(Transform2D(0.0, Vector2(sc, sc), -0.08, Vector2(34, 80)))
		draw_string_outline(f, Vector2(3, 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 68, 16, UIKit.DARK)
		draw_string_outline(f, Vector2.ZERO, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 68, 12, UIKit.DARK)
		draw_string(f, Vector2.ZERO, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 68, Color.WHITE)
		draw_set_transform_matrix(Transform2D.IDENTITY)

		# trophy breakdown: base + win streak bonus
		var total_tr := int(rewards.get("trophies", 0))
		var st_tr := int(rewards.get("streak_trophies", 0))
		var base := total_tr - st_tr
		UIKit.draw_icon(self, "trophy", Vector2(56, 138), 36.0)
		S2.text_l(self, ("+%d" % base) if base >= 0 else str(base), Vector2(78, 150), 28, Color.WHITE)
		if st_tr > 0:
			var px := 150.0
			var pill := PackedVector2Array([Vector2(px + 10, 116), Vector2(px + 196, 116), Vector2(px + 186, 158), Vector2(px, 158)])
			draw_colored_polygon(pill, UIKit.DARK)
			var pin := PackedVector2Array([Vector2(px + 13, 119), Vector2(px + 192, 119), Vector2(px + 183, 155), Vector2(px + 4, 155)])
			draw_colored_polygon(pin, Color("e8731c"))
			UIKit.StreakBadge.flame(self, Vector2(px + 26, 138), 32.0, Progression.streak_color(int(rewards.get("streak", 2))), _t)
			S2.text_l(self, "WIN STREAK", Vector2(px + 48, 146), 20, Color.WHITE)
			UIKit.draw_icon(self, "trophy", Vector2(px + 216, 136), 30.0)
			S2.text_l(self, "+%d" % st_tr, Vector2(px + 234, 148), 24, Color.WHITE)

		# brawler trophies with rank badge + progress
		var bt := Save.brawler_trophies(brawler_id)
		var rank := Progression.rank_for(bt)
		var nxt := bt
		if rank < Progression.RANK_TROPHIES.size():
			nxt = int(Progression.RANK_TROPHIES[rank])
		UIKit.draw_rank_badge(self, Vector2(58, 196), 52.0, rank)
		draw_rect(Rect2(90, 182, 210, 30), UIKit.DARK)
		var prev := int(Progression.RANK_TROPHIES[rank - 1])
		var fr := 1.0 if nxt <= prev else clampf(float(bt - prev) / float(nxt - prev), 0.0, 1.0)
		draw_rect(Rect2(93, 185, 204 * fr, 24), Color("ff8a1f"))
		UIKit.draw_icon(self, "trophy", Vector2(112, 197), 22.0)
		S2.text_l(self, "%d/%d" % [bt, nxt], Vector2(128, 205), 18, Color.WHITE)

		# other rewards, small
		var rx := 40.0
		for it in [["coin", int(rewards.get("credits", 0))], ["xp", int(rewards.get("xp", 0))], ["token", int(rewards.get("tokens", 0))]]:
			UIKit.draw_icon(self, it[0], Vector2(rx + 16, 250), 28.0)
			S2.text_l(self, "+%d" % int(it[1]), Vector2(rx + 34, 259), 20, Color.WHITE)
			rx += 96.0

		# big brawler in the centre
		var feet := Vector2(W * 0.5, H * 0.86)
		draw_set_transform(Vector2.ZERO)
		var sh := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			sh.append(feet + Vector2(cos(a) * 120, sin(a) * 26))
		draw_colored_polygon(sh, Color(0.02, 0.1, 0.3, 0.35))
		var skin: String = Save.selected_skin(brawler_id)
		if happy:
			var hop := absf(sin(_t * 3.2)) * 14.0
			BrawlerArt.draw(self, brawler_id, feet - Vector2(0, hop), 4.4, {"t": _t, "aim": Vector2(1, -0.5), "moving": true, "skin": skin, "no_shadow": true, "recoil": 0.3 + 0.3 * sin(_t * 4.0)})
		else:
			BrawlerArt.draw(self, brawler_id, feet + Vector2(0, 6), 4.2, {"t": 0.7, "aim": Vector2(1, 0.9), "skin": skin, "no_shadow": true, "blink": true, "alpha": 0.9})

		# right card: total trophies and change
		var tt := Save.total_trophies()
		draw_rect(Rect2(1104, 108, 108, 108), UIKit.DARK)
		var dc := Color("4cd964") if total_tr >= 0 else Color("ff6a5a")
		draw_rect(Rect2(1122, 220, 72, 30), UIKit.DARK)
		draw_rect(Rect2(1125, 223, 66, 24), dc.darkened(0.55))
		var dtxt := ("+%d" % total_tr) if total_tr >= 0 else str(total_tr)
		var dw := f.get_string_size(dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		S2.text_l(self, dtxt, Vector2(1158 - dw * 0.5, 243), 22, dc)
		var goal := tt
		for r in Progression.ROAD:
			if int(r.trophies) > tt:
				goal = int(r.trophies)
				break
		draw_rect(Rect2(1062, 260, 196, 28), UIKit.DARK)
		var gf := 1.0 if goal <= 0 else clampf(float(tt) / float(goal), 0.0, 1.0)
		draw_rect(Rect2(1065, 263, 190 * gf, 22), Color("ffb020"))
		UIKit.draw_icon(self, "trophy", Vector2(1080, 274), 22.0)
		S2.text_l(self, "%d/%d" % [tt, goal], Vector2(1096, 282), 17, Color.WHITE)


class ExitArrow extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		draw_rect(Rect2(c.x - 18, c.y - 14, 22, 28), Color.WHITE, false, 4.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-2, -4), c + Vector2(10, -4), c + Vector2(10, -12), c + Vector2(22, 0), c + Vector2(10, 12), c + Vector2(10, 4), c + Vector2(-2, 4)]), Color.WHITE)


## Rank change after a Ranked match: badge, new division, RP gained or lost, bar.
class RankedBanner extends Control:
	var info: Dictionary = {}
	var _t := 0.0
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		if info.is_empty():
			return
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var after: int = int(info.after)
		var before: int = int(info.before)
		var k := clampf((_t - 0.6) / 1.0, 0.0, 1.0)
		var shown := int(lerpf(before, after, ease(k, -2.0)))
		var ri := Progression.ranked_info(shown)
		var c: Color = ri.color
		draw_colored_polygon(PackedVector2Array([Vector2(20, 0), Vector2(size.x, 0), Vector2(size.x - 20, size.y), Vector2(0, size.y)]), Color(0.05, 0.03, 0.15, 0.78))
		var tex: Texture2D = preload("res://scripts/ui/ranked_screen.gd").badge(ri.id, true)
		var pop := 1.0 + (0.15 * sin(clampf((_t - 1.6) * 6.0, 0.0, PI)) if info.get("promoted", false) else 0.0)
		var sz := 104.0 * pop
		draw_texture_rect(tex, Rect2(52 - sz * 0.5, 44 - sz * 0.5, sz, sz), false)
		S2.text_l(self, String(ri.name), Vector2(112, 38), 28, c.lightened(0.3))
		var d: int = int(info.delta)
		var dtxt := ("+%d RP" % d) if d >= 0 else ("%d RP" % d)
		S2.text_l(self, dtxt, Vector2(400, 38), 28, Color("7dff8a") if d >= 0 else Color("ff7a6a"))
		var fr := 1.0 if bool(ri.top) else float(ri.into) / Progression.RANKED_DIV_PTS
		draw_rect(Rect2(112, 52, 380, 18), UIKit.DARK)
		draw_rect(Rect2(114, 54, 376 * clampf(fr, 0, 1), 14), c)
		var sub := ""
		if info.get("new_rank", -1) >= 0:
			sub = "NEW RANK!  BIGGER 6-HOUR REWARDS"
		elif info.get("promoted", false):
			sub = "PROMOTED!"
		elif info.get("demoted", false):
			sub = "DEMOTED"
		elif int(info.get("streak", 0)) >= 2:
			sub = "WIN STREAK x%d" % int(info.streak)
		if sub != "" and _t > 1.4:
			S2.text_l(self, sub, Vector2(112, 90), 16, Color("ffd23a"))
