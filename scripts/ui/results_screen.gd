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

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 30
	root.offset_right = -30
	root.offset_top = 14
	root.offset_bottom = -14
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var title_text: String = {"win": "VICTORY!", "loss": "DEFEAT", "draw": "DRAW"}[result]
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

	# teams
	var view: int = data.get("view_team", 0)
	for team in [view, 1 - view]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		root.add_child(row)
		var tag := UIKit.label("YOUR TEAM" if team == view else "ENEMY", 16, Config.TEAM_COLORS[team].lightened(0.3), 5)
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
	var col: Color = Config.TEAM_COLORS[p.team]
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
		RewardTile.draw_icon(self, {"type": "tokens"}, size * 0.5, 24.0)
