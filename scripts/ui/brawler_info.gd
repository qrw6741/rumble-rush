extends Control
## Brawler details: big animated brawler in the middle, name banner + rank, mastery,
## trophies and bio on the left, abilities, power and stats with UPGRADE on the right.
## SELECT picks the brawler; TRY starts a test match that saves nothing.

const Lobby := preload("res://scripts/ui/main_menu.gd")
const S := preload("res://scripts/ui/main_menu.gd").SlantButton

var id := "bront"

func setup(p: Dictionary) -> void:
	id = String(p.get("id", Save.data.selected_brawler))
	if not Config.BRAWLERS.has(id):
		id = "bront"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var d: Dictionary = Config.BRAWLERS[id]
	var unlocked := Save.is_unlocked(id)
	var bg := Backdrop.new()
	bg.rc = Config.RARITY_COLORS[d.rarity]
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ---------------- top bar
	Lobby.build_header(self, "", func(): Router.goto("select"))
	var skins: Array = [""] + Progression.skins_for(id)
	var owned := 0
	for sk in skins:
		if Save.owns_skin(id, sk):
			owned += 1
	var sk_chip := S.new()
	sk_chip.color = Color("27334d")
	sk_chip.position = Vector2(118, 10)
	sk_chip.size = Vector2(110, 70)
	sk_chip.custom_draw = func(ci: Control):
		UIKit.draw_icon(ci, "skin", Vector2(54, 28), 42.0)
		S.text_c(ci, "%d/%d" % [owned, skins.size()], Vector2(55, 62), 16, Color.WHITE)
	sk_chip.pressed.connect(_open_skins)
	add_child(sk_chip)
	var gems := UIKit.currency_chip("gem", str(Save.data.gems), Color("9dff9a"))
	gems.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gems.position = Vector2(-470, 18)
	add_child(gems)
	var coins := UIKit.currency_chip("coin", str(Save.data.credits), Color("ffe08a"))
	coins.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	coins.position = Vector2(-300, 18)
	add_child(coins)
	var home := S.new()
	home.color = Color("27334d")
	home.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	home.position = Vector2(-120, 10)
	home.size = Vector2(104, 72)
	home.custom_draw = func(ci: Control):
		UIKit.draw_icon(ci, "home", Vector2(52, 34), 60.0)
	home.pressed.connect(func(): Router.goto("menu"))
	add_child(home)

	# ---------------- centre: the brawler
	var stage := Stage.new()
	stage.id = id
	stage.position = Vector2(380, 80)
	stage.size = Vector2(500, 640)
	add_child(stage)

	# ---------------- left column
	var name_b := NameBanner.new()
	name_b.id = id
	name_b.position = Vector2(0, 118)
	name_b.size = Vector2(380, 120)
	add_child(name_b)
	var prog := ProgressRow.new()
	prog.id = id
	prog.position = Vector2(12, 250)
	prog.size = Vector2(340, 90)
	prog.pressed.connect(func(): Router.goto("select", {"ranks": id}))
	add_child(prog)
	var bio := UIKit.body(String(d.bio), 17, Color.WHITE)
	bio.position = Vector2(16, 348)
	bio.custom_minimum_size = Vector2(330, 0)
	bio.size = Vector2(330, 150)
	add_child(bio)
	var small := HBoxContainer.new()
	small.position = Vector2(16, 520)
	small.add_theme_constant_override("separation", 12)
	add_child(small)
	for k in [["info", _open_abilities], ["chat", func(): UIKit.toast(self, '"%s"' % String(d.tagline), "chat")], ["skin", _open_skins]]:
		var b := S.new()
		b.color = Color("27334d")
		b.custom_minimum_size = Vector2(100, 62)
		b.size = Vector2(100, 62)
		var icn: String = k[0]
		b.custom_draw = func(ci: Control):
			UIKit.draw_icon(ci, icn, Vector2(50, 29), 46.0)
		b.pressed.connect(k[1])
		small.add_child(b)

	var is_sel: bool = Save.data.selected_brawler == id
	var sel := UIKit.button("SELECTED" if is_sel else "SELECT", UIKit.YELLOW, 30, Vector2(320, 76))
	sel.position = Vector2(16, 610)
	if not unlocked:
		var u: Dictionary = d.get("unlock", {})
		var cur: String = u.get("currency", "credits")
		if cur == "pass":
			sel.text = "RUSH PASS TIER %d" % int(u.cost)
			sel.pressed.connect(func(): Router.goto("pass"))
		else:
			sel.text = "UNLOCK  %d %s" % [int(u.cost), "GEMS" if cur == "gems" else "COINS"]
			sel.add_theme_font_size_override("font_size", 24)
			sel.disabled = not Save.can_afford(cur, int(u.cost))
			sel.pressed.connect(func():
				if Save.unlock_brawler(id):
					Sfx.play("victory", -2.0, 0.0)
					Save.data.selected_brawler = id
					Save.save_game()
					Router.goto("brawler", {"id": id}, true)
				else:
					Sfx.play("ui_error"))
	else:
		sel.disabled = is_sel
		sel.pressed.connect(func():
			Save.data.selected_brawler = id
			Save.save_game()
			Sfx.play("ui_confirm")
			Router.goto("menu"))
	add_child(sel)
	var tr := UIKit.button("TRY", UIKit.BLUE, 26, Vector2(130, 64))
	tr.position = Vector2(352, 618)
	tr.pressed.connect(func():
		Sfx.play("ui_confirm")
		Router.goto("match", {"mode": "knockout", "brawler": id, "debug": true}))
	add_child(tr)

	# ---------------- right column
	var abil := AbilityRow.new()
	abil.id = id
	abil.position = Vector2(880, 96)
	abil.size = Vector2(394, 180)
	abil.clicked.connect(_open_abilities)
	add_child(abil)
	var pw := PowerPanel.new()
	pw.id = id
	pw.position = Vector2(880, 296)
	pw.size = Vector2(386, 270)
	add_child(pw)
	var cost := Save.upgrade_cost(id)
	var up := UIKit.button("", UIKit.GREEN, 26, Vector2(370, 90))
	up.position = Vector2(888, 600)
	var lab := UpgradeLabel.new()
	lab.cost = cost
	lab.unlocked = unlocked
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	up.add_child(lab)
	up.disabled = not unlocked or cost < 0 or Save.data.credits < cost
	up.pressed.connect(func(): _confirm_upgrade(cost))
	add_child(up)

	var i := 0
	for n in [name_b, prog, bio, small, sel, tr, abil, pw, up]:
		UIKit.pop_in(n, 0.03 * i, Vector2(-40, 0) if i < 6 else Vector2(40, 0))
		i += 1
	UIKit.pop_in(stage, 0.05)

# ------------------------------------------------------------------ popups
func _popup(title: String, w := 640.0) -> VBoxContainer:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.15, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(c)
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(w, 0)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UIKit.label(title, 30, UIKit.YELLOW, 8, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(o)
	UIKit.pop_in(p)
	var close := UIKit.button("CLOSE", Color("6b5f86"), 20, Vector2(200, 54))
	close.pressed.connect(o.queue_free)
	v.set_meta("close", close)
	return v

func _finish_popup(v: VBoxContainer) -> void:
	var h := CenterContainer.new()
	h.add_child(v.get_meta("close"))
	v.add_child(h)

func _open_abilities() -> void:
	var d: Dictionary = Config.BRAWLERS[id]
	var v := _popup("%s  ABILITIES" % d.name, 700)
	var a: Dictionary = d.attack
	for row in [["ATTACK", a, "ab_%s_attack" % id, Color("ff9d2e")], ["GADGET", d.gadget, "ab_%s_gadget" % id, Color("4fd36a")], ["SUPER", d.super, "ab_%s_super" % id, UIKit.YELLOW]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		var ic := TextureRect.new()
		ic.texture = UIKit.icon(row[2])
		ic.custom_minimum_size = Vector2(64, 64)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(ic)
		var vv := VBoxContainer.new()
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var extra := ""
		if row[0] == "GADGET":
			extra = "  ·  %ds cooldown" % int(d.gadget.cooldown)
		vv.add_child(UIKit.label("%s  ·  %s%s" % [row[0], String(row[1].name), extra], 19, (row[3] as Color).lightened(0.3), 6))
		vv.add_child(UIKit.body(String(row[1].desc), 15))
		h.add_child(vv)
		if row[0] == "GADGET" and not Save.has_gadget(id):
			ic.modulate = Color(0.5, 0.5, 0.55)
			var blk := Save.gadget_block(id)
			var bb := UIKit.button("BUY  %d COINS" % Config.GADGET_COST, UIKit.GREEN, 17, Vector2(190, 56))
			match blk:
				"level": bb.text = "NEEDS POWER %d" % Config.GADGET_LEVEL
				"locked": bb.text = "UNLOCK BRAWLER"
				"coins": bb.text = "NEED %d COINS" % Config.GADGET_COST
			bb.disabled = blk != ""
			bb.pressed.connect(func():
				if Save.buy_gadget(id):
					Sfx.play("victory", -2.0, 0.0)
					Router.goto("brawler", {"id": id}, true)
				else:
					Sfx.play("ui_error"))
			h.add_child(bb)
		v.add_child(h)
	var speed_name := "VERY FAST" if d.speed >= 200 else ("NORMAL" if d.speed >= 168 else "SLOW")
	var spd: Dictionary = Config.STAR_POWERS.get(id, {})
	if not spd.is_empty():
		var h2 := HBoxContainer.new()
		h2.add_theme_constant_override("separation", 14)
		var ic2 := TextureRect.new()
		ic2.texture = UIKit.icon("star_power")
		ic2.custom_minimum_size = Vector2(64, 64)
		ic2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h2.add_child(ic2)
		var vv2 := VBoxContainer.new()
		vv2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vv2.add_child(UIKit.label("STAR POWER  ·  %s" % String(spd.name), 19, Color("ffc04a"), 6))
		vv2.add_child(UIKit.body(String(spd.desc), 15))
		h2.add_child(vv2)
		if not Save.has_star(id):
			ic2.modulate = Color(0.5, 0.5, 0.55)
			var blk2 := Save.star_block(id)
			var sb := UIKit.button("BUY  %d COINS" % Config.STAR_COST, Color("ff9d1f"), 17, Vector2(190, 56))
			match blk2:
				"level": sb.text = "NEEDS POWER %d" % Config.STAR_LEVEL
				"locked": sb.text = "UNLOCK BRAWLER"
				"coins": sb.text = "NEED %d COINS" % Config.STAR_COST
			sb.disabled = blk2 != ""
			sb.pressed.connect(func():
				if Save.buy_star(id):
					Sfx.play("victory", -2.0, 0.0)
					Router.goto("brawler", {"id": id}, true)
				else:
					Sfx.play("ui_error"))
			h2.add_child(sb)
		v.add_child(h2)
	if not Save.has_gadget(id):
		v.add_child(UIKit.label("Gadgets unlock at POWER %d and cost %d coins." % [Config.GADGET_LEVEL, Config.GADGET_COST], 15, Color("ffd23a"), 5, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("RANGE %.1f tiles   ·   AMMO %d (%.2fs reload)   ·   SPEED %s" % [a.range, d.ammo, d.reload, speed_name], 15, Color("8fd0ff"), 5, HORIZONTAL_ALIGNMENT_CENTER))
	_finish_popup(v)

func _open_skins() -> void:
	var d: Dictionary = Config.BRAWLERS[id]
	var v := _popup("%s  SKINS" % d.name, 720)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	for sk in [""] + Progression.skins_for(id):
		var owned: bool = Save.owns_skin(id, sk)
		var cur: bool = Save.selected_skin(id) == sk
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		var pic := UIKit.BrawlerPortrait.new()
		pic.brawler_id = id
		pic.skin = sk
		pic.locked = not owned
		pic.custom_minimum_size = Vector2(150, 150)
		col.add_child(pic)
		var nm: String = "DEFAULT" if sk == "" else String(Progression.skin_info(sk).name)
		col.add_child(UIKit.label(nm, 15, Color.WHITE, 5, HORIZONTAL_ALIGNMENT_CENTER))
		var b := UIKit.button("EQUIPPED" if cur else ("EQUIP" if owned else "LOCKED"), UIKit.GREEN if owned else Color("4a5570"), 16, Vector2(150, 46))
		b.disabled = cur or not owned
		b.pressed.connect(func():
			if Save.select_skin(id, sk):
				Sfx.play("ui_confirm")
				Router.goto("brawler", {"id": id}, true))
		col.add_child(b)
		h.add_child(col)
	if Progression.skins_for(id).size() > 0:
		v.add_child(UIKit.body("Special skins come and go in the Shop every 2 hours.", 14, Color(1, 1, 1, 0.65)))
	_finish_popup(v)

func _confirm_upgrade(cost: int) -> void:
	var d: Dictionary = Config.BRAWLERS[id]
	var lvl := Save.brawler_level(id)
	var v := _popup("UPGRADE %s?" % d.name, 520)
	v.add_child(UIKit.label("POWER %d  »  %d" % [lvl, lvl + 1], 24, Color.WHITE, 6, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Cost: %d coins   (you have %d)" % [cost, Save.data.credits], 18, Color("ffe08a"), 5, HORIZONTAL_ALIGNMENT_CENTER))
	var yes := UIKit.button("UPGRADE", UIKit.GREEN, 22, Vector2(240, 60))
	yes.pressed.connect(func():
		if Save.try_upgrade(id):
			Sfx.play("super_ready", 0.0, 0.0)
			FX.burst(self, Vector2(630, 400), UIKit.YELLOW, 34, 450.0, 0.8, 8.0)
			await get_tree().create_timer(0.35).timeout
			Router.goto("brawler", {"id": id}, true)
		else:
			Sfx.play("ui_error"))
	var c := CenterContainer.new()
	c.add_child(yes)
	v.add_child(c)
	_finish_popup(v)

# ====================================================================== pieces
class Backdrop extends Control:
	var rc := Color.WHITE
	var _t := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var top := Color("1f7ae8")
		var bot := Color("0c3fa8")
		var n := 24
		for i in n:
			var k := float(i) / n
			draw_rect(Rect2(0, size.y * k, size.x, size.y / n + 1), top.lerp(bot, k))
		var c := Vector2(630, 400)
		for k in 12:
			draw_circle(c, 420.0 - k * 32.0, Color(0.55, 0.95, 1.0, 0.035))
		for k in 10:
			var a := _t * 0.08 + k * TAU / 10.0
			draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - 0.07) * 900.0, c + Vector2.from_angle(a + 0.07) * 900.0]), Color(1, 1, 1, 0.035))
		draw_rect(Rect2(0, 0, size.x, 92), Color(0, 0, 0, 0.22))


class Stage extends Control:
	var id := "bront"
	var _t := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var feet := Vector2(size.x * 0.5, size.y - 40)
		var sh := PackedVector2Array()
		for i in 32:
			var a := TAU * i / 32.0
			sh.append(feet + Vector2(cos(a) * 150, sin(a) * 26))
		draw_colored_polygon(sh, Color(0, 0.08, 0.3, 0.35))
		var sc := 4.6 if BrawlerArt.has_sprites(id) else 4.0
		BrawlerArt.draw(self, id, feet, sc, {"t": _t, "aim": Vector2(1, 0.15), "skin": Save.selected_skin(id), "no_shadow": true})


class NameBanner extends Control:
	var id := "bront"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var d: Dictionary = Config.BRAWLERS[id]
		var rc: Color = Config.RARITY_COLORS[d.rarity]
		var w := size.x
		draw_colored_polygon(PackedVector2Array([Vector2(0, 8), Vector2(w, 0), Vector2(w - 24, 100), Vector2(0, 104)]), UIKit.DARK)
		var face := PackedVector2Array([Vector2(0, 13), Vector2(w - 6, 6), Vector2(w - 29, 96), Vector2(0, 99)])
		draw_polygon(face, PackedColorArray([rc.lightened(0.15), rc.lightened(0.15), rc.darkened(0.2), rc.darkened(0.2)]))
		draw_colored_polygon(PackedVector2Array([face[0], face[1], face[1] + Vector2(-2, 14), face[0] + Vector2(0, 14)]), Color(1, 1, 1, 0.18))
		var nm := String(d.name)
		var fs := 46 if nm.length() <= 9 else (34 if nm.length() <= 13 else 28)
		S2.text_c(self, nm, Vector2(w * 0.47, 54), fs, Color.WHITE, 12)
		UIKit.draw_icon(self, "attack", Vector2(w * 0.47 - 82, 80), 26.0)
		S2.text_l(self, String(d.role), Vector2(w * 0.47 - 64, 88), 20, Color.WHITE)
		S2.text_r(self, String(d.rarity), Vector2(w - 34, 118), 16, rc.lightened(0.45))


## Mastery badge, brawler rank badge and the trophy bar (tap: rank rewards).
class ProgressRow extends Button:
	var id := "bront"
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var mp := Save.mastery_points(id)
		var ml := Progression.mastery_level(mp)
		var mc: Color = Progression.MASTERY_COLORS[ml]
		# mastery star badge
		var c := Vector2(38, 40)
		var pts := PackedVector2Array()
		for k in 16:
			var a := -PI / 2 + k * TAU / 16.0
			pts.append(c + Vector2.from_angle(a) * (36.0 if k % 2 == 0 else 27.0))
		var outl := PackedVector2Array()
		for p in pts:
			outl.append(c + (p - c) * 1.12)
		draw_colored_polygon(outl, UIKit.DARK)
		draw_colored_polygon(pts, mc)
		draw_circle(c, 20, mc.lightened(0.3))
		var roman: String = ["", "I", "II", "III"][ml % 3 + 1] if ml > 0 else "-"
		S2.text_c(self, roman, c + Vector2(0, 8), 20, UIKit.DARK)
		S2.text_c(self, String(Progression.MASTERY_NAMES[ml]).split(" ")[0], Vector2(38, 92), 12, Color.WHITE)
		# brawler rank badge
		var tr := Save.brawler_trophies(id)
		var rank := Progression.rank_for(tr)
		UIKit.draw_rank_badge(self, Vector2(116, 40), 70.0, rank)
		# trophy bar to next rank
		var nxt := tr
		if rank < Progression.RANK_TROPHIES.size():
			nxt = int(Progression.RANK_TROPHIES[rank])
		var prev := int(Progression.RANK_TROPHIES[rank - 1])
		var fr := 1.0 if nxt <= prev else clampf(float(tr - prev) / float(nxt - prev), 0.0, 1.0)
		var br := Rect2(160, 24, 176, 34)
		draw_rect(br.grow(3), UIKit.DARK)
		draw_rect(br, Color("2a1a40"))
		draw_rect(Rect2(br.position, Vector2(br.size.x * fr, br.size.y)), Color("ff8a1f"))
		draw_rect(Rect2(br.position, Vector2(br.size.x * fr, 11)), Color(1, 1, 1, 0.25))
		UIKit.draw_icon(self, "trophy", Vector2(178, 40), 30.0)
		S2.text_l(self, "%d/%d" % [tr, nxt], Vector2(198, 49), 20, Color.WHITE)
		S2.text_l(self, "RANK REWARDS >", Vector2(160, 84), 13, Color("ffd23a"))


## Attack / gadget / super icons in badges (tap: ability details).
class AbilityRow extends Button:
	var id := "bront"
	signal clicked
	var _t := 0.0
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		pressed.connect(func(): clicked.emit())
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var d: Dictionary = Config.BRAWLERS[id]
		var sp: Dictionary = Config.STAR_POWERS.get(id, {"name": "-"})
		var slots := [["attack", Color("ff7a2a"), String(d.attack.name)], ["gadget", Color("3fcf4a"), String(d.gadget.name)], ["super", Color("ffc21a"), String(d.super.name)], ["star", Color("ff9d1f"), String(sp.name)]]
		for k in 4:
			var c := Vector2(48 + k * 98, 60)
			var col: Color = slots[k][1]
			var hexo := PackedVector2Array()
			var hexi := PackedVector2Array()
			for i in 8:
				var a := PI / 8 + i * TAU / 8.0
				hexo.append(c + Vector2.from_angle(a) * 46.0)
				hexi.append(c + Vector2.from_angle(a) * 40.0)
			draw_colored_polygon(hexo, UIKit.DARK)
			draw_polygon(hexi, PackedColorArray([col.lightened(0.3), col.lightened(0.3), col, col.darkened(0.2), col.darkened(0.3), col.darkened(0.2), col, col.lightened(0.15)]))
			draw_circle(c + Vector2(-12, -15), 8, Color(1, 1, 1, 0.25))
			var locked := (k == 1 and not Save.has_gadget(id)) or (k == 3 and not Save.has_star(id))
			var icn: String = "star_power" if k == 3 else "ab_%s_%s" % [id, slots[k][0]]
			UIKit.draw_icon(self, icn, c, 60.0 + 3.0 * sin(_t * 2.0 + k), Color(0.45, 0.45, 0.5) if locked else Color.WHITE)
			var lab: String = "STAR POWER" if k == 3 else String(slots[k][0]).to_upper()
			S2.text_c(self, lab, c + Vector2(0, 64), 12, col.lightened(0.4))
			var nm: String = slots[k][2]
			if locked:
				UIKit.draw_icon(self, "lock", c + Vector2(22, 20), 28.0)
				var blk := Save.gadget_block(id) if k == 1 else Save.star_block(id)
				var need := Config.GADGET_LEVEL if k == 1 else Config.STAR_LEVEL
				nm = "TAP TO BUY" if blk == "" or blk == "coins" else ("POWER %d" % need)
				S2.text_c(self, nm, c + Vector2(0, 82), 12, Color("ffd23a"))
			else:
				S2.text_c(self, nm, c + Vector2(0, 82), 12 if nm.length() < 13 else 10, Color.WHITE)


class PowerPanel extends Control:
	var id := "bront"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var d: Dictionary = Config.BRAWLERS[id]
		var lvl := Save.brawler_level(id)
		var maxl := Config.MAX_LEVEL
		var m := Config.level_mult(lvl)
		var nm := Config.level_mult(mini(lvl + 1, maxl))
		var can_up := lvl < maxl
		draw_rect(Rect2(0, 0, size.x, size.y), UIKit.DARK)
		draw_rect(Rect2(3, 3, size.x - 6, size.y - 6), Color("12204a"))
		# header
		draw_circle(Vector2(34, 36), 30, UIKit.DARK)
		draw_circle(Vector2(34, 36), 26, Color("d63ad8"))
		draw_circle(Vector2(34, 30), 18, Color(1, 1, 1, 0.15))
		S2.text_c(self, str(lvl), Vector2(34, 46), 28, Color.WHITE, 8)
		S2.text_l(self, "POWER", Vector2(74, 34), 24, Color.WHITE)
		S2.text_r(self, "MAX %d" % maxl, Vector2(size.x - 14, 32), 17, Color("ff7ae0"))
		var seg_w := (size.x - 90.0) / maxl
		for k in maxl:
			var r := Rect2(74 + k * seg_w, 44, seg_w - 4, 12)
			draw_rect(r, Color("ff58d8") if k < lvl else Color("3a2a58"))
		# stat rows
		var a: Dictionary = d.attack
		var hp := int(float(d.health) * m)
		var dmg := int(float(a.damage) * m)
		var rows := [
			["HEALTH", "heart", Color("4dff7a"), str(hp), int(float(d.health) * nm) - hp],
			["ATTACK", "attack", Color("ff6b6b"), str(dmg) + (" x2" if a.kind == "twin_slash" else ""), int(float(a.damage) * nm) - dmg],
			["SUPER", "super", Color("ffd23a"), String(d.super.name).to_upper(), 0],
		]
		for k in rows.size():
			var y := 70.0 + k * 66.0
			var rr := Rect2(10, y, size.x - 20, 58)
			draw_rect(rr, Color(0, 0, 0, 0.35))
			var bc: Color = rows[k][2]
			draw_rect(Rect2(10, y, 52, 58), bc.darkened(0.35))
			UIKit.draw_icon(self, rows[k][1], Vector2(36, y + 29), 40.0)
			S2.text_l(self, rows[k][0], Vector2(72, y + 22), 15, bc)
			S2.text_l(self, rows[k][3], Vector2(72, y + 48), 22 if String(rows[k][3]).length() < 14 else 17, Color.WHITE)
			if can_up and int(rows[k][4]) > 0:
				var vw := UIKit.bold().get_string_size(String(rows[k][3]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
				S2.text_l(self, "+%d" % int(rows[k][4]), Vector2(80 + vw, 48 + y), 20, Color("6dff6a"))
			if can_up and int(rows[k][4]) > 0:
				var c := Vector2(size.x - 36, y + 29)
				draw_circle(c, 17, UIKit.DARK)
				draw_circle(c, 14, Color("3fcf4a"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(9, 1), c + Vector2(4, 1), c + Vector2(4, 9), c + Vector2(-4, 9), c + Vector2(-4, 1), c + Vector2(-9, 1)]), Color.WHITE)


class UpgradeLabel extends Control:
	var cost := 0
	var unlocked := true
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
		var c := size * 0.5
		if not unlocked:
			S2.text_c(self, "LOCKED", c + Vector2(0, 10), 30, Color.WHITE, 8)
			return
		if cost < 0:
			S2.text_c(self, "MAX POWER", c + Vector2(0, 10), 30, Color.WHITE, 8)
			return
		S2.text_c(self, "UPGRADE", Vector2(c.x, 30), 18, Color.WHITE, 6)
		UIKit.draw_icon(self, "coin", Vector2(c.x - 54, 58), 36.0)
		S2.text_l(self, str(cost), Vector2(c.x - 30, 70), 32, Color.WHITE if Save.data.credits >= cost else Color("ff9a9a"))
