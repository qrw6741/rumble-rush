class_name DropOpener
extends Control
## Star drop opening for Rush / Super / Mega Drops.
## Idle: the chest bobs and glows in its tier colour. Each tap shakes it and, if the
## prize is rarer, upgrades the glow one rarity (common > rare > epic > mythic >
## legendary) with cracks of light. Once at the rolled rarity, the next tap blows
## the lid open: a beam of light, the prize rises out, coins or gems rain down.
## Opens every drop waiting in Save.data.drops, one after another.

signal finished

const S := preload("res://scripts/ui/main_menu.gd").SlantButton

var _prize: Dictionary = {}
var _tier := 0
var _phase := "intro" # intro -> idle -> open -> reveal
var _t := 0.0
var _shown := 0          # rarity currently shown on the chest
var _shake := 0.0
var _pop := 0.0          # quick scale punch after a tap
var _lid := 0.0          # 0 closed .. 1 fully open
var _tap_lock := 0.0
var _taps := 0
var _rain: Array = []    # falling coins / gems [pos, vel, rot, spin, icon]
var _sparks: Array = []  # [pos, vel, life, col]
var _count := 0.0        # amount counter on reveal

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	var skip := UIKit.button("OPEN ALL", Color("6b5f86"), 16, Vector2(150, 46))
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.position = Vector2(-170, 18)
	skip.pressed.connect(_open_all)
	skip.name = "OpenAll"
	add_child(skip)
	_next()

func _next() -> void:
	if Save.data.drops.is_empty():
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		await tw.finished
		finished.emit()
		queue_free()
		return
	_tier = clampi(int(Save.data.drops[0]), 0, 2)
	_prize = Save.open_next_drop()
	_phase = "intro"
	_t = 0.0
	_shown = 0
	_lid = 0.0
	_taps = 0
	_count = 0.0
	_rain.clear()
	_tap_lock = 0.45
	var ob := get_node_or_null("OpenAll")
	if ob:
		ob.visible = Save.data.drops.size() >= 1
	Sfx.play("ui_confirm", -4.0, 0.0)

## Opens everything left at once and shows a summary.
func _open_all() -> void:
	var got: Array = []
	if _phase != "reveal" and not _prize.is_empty():
		got.append(_prize)
	while not Save.data.drops.is_empty():
		got.append(Save.open_next_drop())
	var tot := {}
	var other: Array = []
	for p in got:
		var ty: String = p.get("type", "")
		if ty in ["credits", "gems", "tokens"]:
			tot[ty] = int(tot.get(ty, 0)) + int(p.amount)
		else:
			other.append(Progression.reward_text(p))
	var parts: Array = []
	for k in [["credits", "COINS"], ["gems", "GEMS"], ["tokens", "PASS TOKENS"]]:
		if tot.has(k[0]):
			parts.append("+%d %s" % [int(tot[k[0]]), k[1]])
	parts.append_array(other)
	_prize = {"type": "summary", "lines": parts, "rarity": 0}
	_phase = "reveal"
	_t = 0.0
	_lid = 1.0
	Sfx.play("victory", -3.0, 0.0)

func _gui_input(e: InputEvent) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
	if not tap or _tap_lock > 0.0:
		return
	accept_event()
	match _phase:
		"intro", "idle":
			_tap()
		"reveal":
			if _t > 0.45:
				_next()

func _tap() -> void:
	_phase = "idle"
	_tap_lock = 0.22
	_taps += 1
	_shake = 1.0
	_pop = 1.0
	var target: int = int(_prize.get("rarity", 0))
	var c := _chest_center()
	if _shown < target:
		_shown += 1
		var rc: Color = Progression.RARITIES[_shown].color
		Sfx.play("gem_pickup", 0.0, 0.12 * _shown)
		FX.burst(self, c, rc, 22 + _shown * 6, 460.0, 0.6, 7.0)
		_burst_sparks(c, rc, 18)
	else:
		_phase = "open"
		_t = 0.0
		Sfx.play("super_ready")
		_tap_lock = 0.9

func _chest_center() -> Vector2:
	return size * 0.5 + Vector2(0, 40)

func _burst_sparks(c: Vector2, col: Color, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		_sparks.append([c + Vector2.from_angle(a) * 40.0, Vector2.from_angle(a) * randf_range(180, 520), randf_range(0.4, 0.9), col])

func _start_rain() -> void:
	var ty: String = _prize.get("type", "")
	var icon := ""
	var n := 0
	match ty:
		"credits":
			icon = "coin"
			n = clampi(int(_prize.amount) / 12, 10, 40)
		"gems":
			icon = "gem"
			n = clampi(int(_prize.amount) * 2, 8, 40)
		"tokens":
			icon = "token"
			n = 14
	for i in n:
		_rain.append([_chest_center() + Vector2(randf_range(-40, 40), -60), Vector2(randf_range(-420, 420), randf_range(-900, -500)), randf() * TAU, randf_range(-8, 8), icon])

func _process(delta: float) -> void:
	_t += delta
	_tap_lock = maxf(0.0, _tap_lock - delta)
	_shake = maxf(0.0, _shake - delta * 3.5)
	_pop = maxf(0.0, _pop - delta * 5.0)
	if _phase == "intro" and _t > 0.5:
		_phase = "idle"
	if _phase == "open":
		_lid = minf(1.0, _t / 0.35)
		if _t > 0.45:
			_phase = "reveal"
			_t = 0.0
			var rc: Color = Progression.RARITIES[int(_prize.get("rarity", 0))].color
			FX.burst(self, _chest_center() + Vector2(0, -60), rc, 60, 820.0, 1.0, 9.0)
			_burst_sparks(_chest_center() + Vector2(0, -60), rc, 40)
			_start_rain()
			Sfx.play("victory", -4.0, 0.0)
	if _phase == "reveal" and _prize.has("amount"):
		_count = minf(float(_prize.amount), _count + float(_prize.amount) * delta * 2.2)
	for r in _rain:
		r[1].y += 1500.0 * delta
		r[0] += r[1] * delta
		r[2] += r[3] * delta
	_rain = _rain.filter(func(r): return r[0].y < size.y + 80)
	for sp in _sparks:
		sp[0] += sp[1] * delta
		sp[1] *= 0.92
		sp[2] -= delta
	_sparks = _sparks.filter(func(sp): return sp[2] > 0.0)
	queue_redraw()

# ====================================================================== drawing
func _draw() -> void:
	var c := size * 0.5
	var tier_col: Color = Progression.DROP_TIERS[_tier].color
	var rc: Color = Progression.RARITIES[_shown].color if _phase != "reveal" else Progression.RARITIES[int(_prize.get("rarity", 0))].color
	# backdrop: deep gradient tinted by the current rarity
	var top := rc.darkened(0.82)
	var bot := Color(0.02, 0.01, 0.06)
	for i in 20:
		var k := float(i) / 20.0
		draw_rect(Rect2(0, size.y * k, size.x, size.y / 20.0 + 1), top.lerp(bot, k).lerp(Color(0, 0, 0), 0.1))
	# light rays from the chest
	var cc := _chest_center()
	var ray_a := 0.10 if _phase != "reveal" else 0.2
	for i in 16:
		var a := _t * 0.35 + i * TAU / 16.0
		draw_colored_polygon(PackedVector2Array([cc, cc + Vector2.from_angle(a - 0.07) * 1100.0, cc + Vector2.from_angle(a + 0.07) * 1100.0]), Color(rc.r, rc.g, rc.b, ray_a))
	for k in 6:
		draw_circle(cc, 260.0 - k * 36.0, Color(rc.r, rc.g, rc.b, 0.05))
	# header: drop name
	var title := "%s DROP" % Progression.DROP_TIERS[_tier].name
	S.text_c(self, title, Vector2(c.x, 78), 44, tier_col.lightened(0.45), 10)
	var left: int = Save.data.drops.size()
	if left > 0 and _phase != "reveal":
		S.text_c(self, "+%d MORE TO OPEN" % left, Vector2(c.x, 112), 18, UIKit.YELLOW, 5)

	if _phase == "reveal":
		_draw_reveal(c, rc)
	else:
		_draw_star(cc, rc)
		var label: String = "TAP TO OPEN!" if _taps == 0 else String(Progression.RARITIES[_shown].name) + "!"
		var lc := Color.WHITE if _taps == 0 else rc
		var ls := 1.0 + 0.06 * sin(_t * 5.0) + 0.2 * _pop
		draw_set_transform(Vector2(c.x, size.y - 70), 0.0, Vector2(ls, ls))
		S.text_c(self, label, Vector2.ZERO, 40, lc, 10)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# falling coins / gems
	for r in _rain:
		draw_set_transform(r[0], r[2], Vector2.ONE)
		UIKit.draw_icon(self, r[4], Vector2.ZERO, 46.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for sp in _sparks:
		var col: Color = sp[3]
		draw_circle(sp[0], 3.0 + 4.0 * float(sp[2]), Color(col.r, col.g, col.b, clampf(float(sp[2]) * 1.4, 0, 1)))

## Faceted six-point star in the colour of the rarity it currently shows.
func _draw_star(cc: Vector2, rc: Color) -> void:
	var intro := ease(clampf(_t / 0.45, 0.0, 1.0), -2.5) if _phase == "intro" else 1.0
	var bob := sin(_t * 2.6) * 8.0
	var sh := Vector2(sin(_t * 80.0), cos(_t * 71.0)) * 14.0 * _shake
	var grow := 1.0 + 0.07 * _shown + 0.14 * _pop
	var open_k := clampf(_t / 0.4, 0.0, 1.0) if _phase == "open" else 0.0
	var sc := intro * grow * (1.0 + 0.35 * open_k) * (1.1 if _tier == 2 else (1.05 if _tier == 1 else 1.0))
	var rot := sin(_t * 1.6) * 0.06 + sin(_t * 70.0) * 0.08 * _shake + open_k * 2.2
	var base := cc + Vector2(0, bob - 20) + sh
	# ground shadow
	var sh_pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		sh_pts.append(cc + Vector2(cos(a) * 120.0 * sc, 160.0 + sin(a) * 22.0 * sc))
	draw_colored_polygon(sh_pts, Color(0, 0, 0, 0.4))
	for k in 5:
		draw_circle(base, (170.0 + k * 26.0) * sc, Color(rc.r, rc.g, rc.b, (0.05 + 0.03 * _shown) * (1.0 + _pop)))
	draw_set_transform(base, rot, Vector2(sc, sc))
	var R := 170.0
	var r := 118.0
	var outer: Array = []
	var inner: Array = []
	for i in 6:
		outer.append(Vector2.from_angle(-PI / 2 + i * TAU / 6.0) * R)
		inner.append(Vector2.from_angle(-PI / 2 + PI / 6.0 + i * TAU / 6.0) * r)
	var ring := PackedVector2Array()
	for i in 6:
		ring.append(outer[i])
		ring.append(inner[i])
	# ink outline (rounded by a fat polyline)
	var fat := PackedVector2Array()
	for p in ring:
		fat.append(p * 1.0)
	fat.append(ring[0])
	draw_colored_polygon(ring, UIKit.DARK)
	draw_polyline(fat, UIKit.DARK, 30.0, true)
	# facets: each point is two triangles (lit side / shaded side)
	var lit := rc.lightened(0.35)
	var mid := rc
	var dark := rc.darkened(0.3)
	var light_dir := Vector2(-0.6, -0.8).normalized()
	for i in 6:
		var o: Vector2 = outer[i]
		var a_in: Vector2 = inner[(i + 5) % 6]
		var b_in: Vector2 = inner[i]
		var facing := o.normalized().dot(light_dir)
		var c1 := lit if facing > 0.2 else (mid if facing > -0.4 else dark)
		var c2 := c1.darkened(0.18)
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, a_in, o]), c1)
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, o, b_in]), c2)
	# glossy highlight on the top-left point
	draw_colored_polygon(PackedVector2Array([outer[0] * 0.92, inner[5] * 0.85, Vector2(-30, -60)]), Color(1, 1, 1, 0.55))
	draw_colored_polygon(PackedVector2Array([outer[5] * 0.9, inner[4] * 0.9, inner[5] * 0.8]), Color(1, 1, 1, 0.3))
	# centre medallion with an original lightning emblem
	draw_circle(Vector2.ZERO, 84, UIKit.DARK)
	draw_circle(Vector2.ZERO, 76, rc.darkened(0.12))
	draw_circle(Vector2.ZERO, 64, UIKit.DARK)
	draw_circle(Vector2.ZERO, 58, rc.lightened(0.12))
	draw_circle(Vector2(-18, -24), 14, Color(1, 1, 1, 0.45))
	var bolt := PackedVector2Array([Vector2(10, -46), Vector2(-26, 6), Vector2(-4, 6), Vector2(-14, 46), Vector2(26, -8), Vector2(4, -8), Vector2(14, -46)])
	var bolt_o := PackedVector2Array()
	for p in bolt:
		bolt_o.append(p * 1.22)
	draw_colored_polygon(bolt_o, UIKit.DARK)
	draw_colored_polygon(bolt, Color.WHITE)
	# rarity cracks of light
	if _shown > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 91
		for k in _shown * 2:
			var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(88, 112)
			var pts := PackedVector2Array([p])
			for j in 3:
				p += Vector2(rng.randf_range(-18, 18), rng.randf_range(-18, 18))
				pts.append(p)
			draw_polyline(pts, Color(1, 1, 1, 0.85), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if open_k > 0.0:
		for k in 3:
			draw_circle(base, 200.0 * open_k * (1.0 + k * 0.5), Color(1, 1, 1, 0.25 * (1.0 - open_k)))
	# twinkles
	for k in 6:
		var a := _t * 0.8 + k * TAU / 6.0
		var p := cc + Vector2(cos(a) * 250.0, sin(a) * 140.0 - 30.0)
		var s := 6.0 + 4.0 * sin(_t * 5.0 + k)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 2), p + Vector2(s * 0.5, 0), p + Vector2(0, s * 2), p + Vector2(-s * 0.5, 0)]), Color(1, 1, 1, 0.8))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 2, 0), p + Vector2(0, s * 0.5), p + Vector2(s * 2, 0), p + Vector2(0, -s * 0.5)]), Color(1, 1, 1, 0.8))

func _draw_chest(cc: Vector2, tier_col: Color, rc: Color) -> void:
	var intro := ease(clampf(_t / 0.45, 0.0, 1.0), -2.5) if _phase == "intro" else 1.0
	var bob := sin(_t * 2.6) * 8.0 if _phase != "open" else 0.0
	var sh := Vector2(sin(_t * 80.0), cos(_t * 71.0)) * 14.0 * _shake
	var grow := 1.0 + 0.08 * _shown + 0.12 * _pop
	var sc := intro * grow * (1.15 if _tier == 2 else (1.05 if _tier == 1 else 1.0))
	var base := cc + Vector2(0, bob) + sh
	# ground shadow
	var sh_pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		sh_pts.append(cc + Vector2(cos(a) * 150.0 * sc, 118.0 + sin(a) * 26.0 * sc))
	draw_colored_polygon(sh_pts, Color(0, 0, 0, 0.4))
	# glow aura in the current rarity colour (stronger every upgrade)
	for k in 4:
		draw_circle(base, (160.0 + k * 26.0) * sc, Color(rc.r, rc.g, rc.b, (0.06 + 0.03 * _shown) * (1.0 + _pop)))
	draw_set_transform(base, sin(_t * 30.0) * 0.06 * _shake, Vector2(sc, sc))
	var body := tier_col.darkened(0.15)
	var trim := Color("ffd23a") if _tier == 2 else (Color("dfe8ff") if _tier == 1 else Color("ffb84d"))
	var ink := UIKit.DARK
	# --- body
	var bw := 150.0
	var bh := 100.0
	draw_rect(Rect2(-bw - 6, -6, bw * 2 + 12, bh + 12), ink)
	draw_polygon(PackedVector2Array([Vector2(-bw, 0), Vector2(bw, 0), Vector2(bw, bh), Vector2(-bw, bh)]),
		PackedColorArray([body.lightened(0.15), body.lightened(0.15), body.darkened(0.35), body.darkened(0.35)]))
	draw_rect(Rect2(-bw, 0, bw * 2, 14), Color(1, 1, 1, 0.12))
	# planks
	for x in [-75.0, 0.0, 75.0]:
		draw_line(Vector2(x, 8), Vector2(x, bh - 4), body.darkened(0.45), 3.0)
	# metal bands
	for x in [-118.0, 118.0]:
		draw_rect(Rect2(x - 14, -2, 28, bh + 4), ink)
		draw_rect(Rect2(x - 10, 0, 20, bh), trim)
		draw_rect(Rect2(x - 10, 0, 6, bh), trim.lightened(0.35))
		for y in [18.0, 80.0]:
			draw_circle(Vector2(x, y), 4.0, trim.darkened(0.4))
	# rarity cracks of light on the body
	if _shown > 0:
		var crack := Color(rc.r, rc.g, rc.b, 0.9)
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for k in _shown * 2:
			var p := Vector2(rng.randf_range(-bw + 30, bw - 30), rng.randf_range(20, bh - 10))
			var pts := PackedVector2Array([p])
			for j in 4:
				p += Vector2(rng.randf_range(-22, 22), rng.randf_range(-14, 14))
				pts.append(p)
			draw_polyline(pts, crack, 3.0 + 0.6 * _shown, true)
	# --- lid (hinged at the back top edge, swings up)
	var open_a := -_lid * 1.9
	draw_set_transform(base + Vector2(0, -2) * sc, open_a * 0.0, Vector2(sc, sc))
	var lid_h := 66.0
	var lift := Vector2(0, -_lid * 120.0)
	var tilt := _lid * 0.55
	var lid_pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		lid_pts.append(lift + Vector2(cos(a) * bw, sin(a) * lid_h).rotated(-tilt))
	lid_pts.append(lift + Vector2(bw, 0).rotated(-tilt))
	lid_pts.append(lift + Vector2(-bw, 0).rotated(-tilt))
	if _lid > 0.0:
		# light pouring out of the open chest
		draw_colored_polygon(PackedVector2Array([Vector2(-bw + 10, 2), Vector2(bw - 10, 2), Vector2(bw * 1.6, -420), Vector2(-bw * 1.6, -420)]), Color(rc.r, rc.g, rc.b, 0.35 * _lid))
		draw_rect(Rect2(-bw + 8, -6, bw * 2 - 16, 14), rc.lightened(0.6))
	var outline := PackedVector2Array()
	for pt in lid_pts:
		outline.append(pt * 1.04 + Vector2(0, 2))
	draw_colored_polygon(outline, ink)
	draw_colored_polygon(lid_pts, body.lightened(0.05))
	# lid shine + bands
	var shine := PackedVector2Array()
	for i in 7:
		var a := PI * 1.15 + PI * 0.35 * float(i) / 6.0
		shine.append(lift + Vector2(cos(a) * bw * 0.8, sin(a) * lid_h * 0.8).rotated(-tilt))
	shine.append(lift + Vector2(-bw * 0.2, -lid_h * 0.3).rotated(-tilt))
	draw_colored_polygon(shine, Color(1, 1, 1, 0.18))
	for x in [-118.0, 118.0]:
		var hy := sqrt(maxf(0.0, 1.0 - (x * x) / (bw * bw))) * lid_h
		draw_line(lift + Vector2(x, 0).rotated(-tilt), lift + Vector2(x, -hy).rotated(-tilt), ink, 30.0)
		draw_line(lift + Vector2(x, 0).rotated(-tilt), lift + Vector2(x, -hy).rotated(-tilt), trim, 20.0)
	# lock plate
	if _lid < 0.2:
		draw_rect(Rect2(-30, -20, 60, 56), ink)
		draw_rect(Rect2(-25, -16, 50, 48), trim)
		draw_rect(Rect2(-25, -16, 50, 12), trim.lightened(0.4))
		draw_circle(Vector2(0, 6), 9, ink)
		draw_colored_polygon(PackedVector2Array([Vector2(-5, 8), Vector2(5, 8), Vector2(7, 24), Vector2(-7, 24)]), ink)
		# glowing gem on the lock for Super / Mega
		if _tier > 0:
			draw_circle(Vector2(0, -38), 14, ink)
			draw_circle(Vector2(0, -38), 10, rc)
			draw_circle(Vector2(-3, -41), 4, Color(1, 1, 1, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# twinkles around the chest
	for k in 6:
		var a := _t * 0.8 + k * TAU / 6.0
		var p := cc + Vector2(cos(a) * 230.0, sin(a) * 120.0 - 20.0)
		var s := 6.0 + 4.0 * sin(_t * 5.0 + k)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 2), p + Vector2(s * 0.5, 0), p + Vector2(0, s * 2), p + Vector2(-s * 0.5, 0)]), Color(1, 1, 1, 0.8))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 2, 0), p + Vector2(0, s * 0.5), p + Vector2(s * 2, 0), p + Vector2(0, -s * 0.5)]), Color(1, 1, 1, 0.8))

func _draw_reveal(c: Vector2, rc: Color) -> void:
	var k := ease(clampf(_t / 0.35, 0.0, 1.0), -2.5)
	if _prize.get("type", "") == "summary":
		S.text_c(self, "ALL DROPS OPENED!", Vector2(c.x, 210), 44, UIKit.YELLOW, 10)
		var y := 290.0
		for line in _prize.lines:
			S.text_c(self, String(line), Vector2(c.x, y), 32, Color.WHITE, 8)
			y += 50.0
		if _t > 0.45:
			S.text_c(self, "TAP TO CONTINUE", Vector2(c.x, size.y - 60), 22, Color(1, 1, 1, 0.6 + 0.4 * sin(_t * 4.0)), 5)
		return
	var rar: Dictionary = Progression.RARITIES[int(_prize.get("rarity", 0))]
	# open chest behind the prize
	var cc := _chest_center() + Vector2(0, 140)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# rarity banner
	var bw := 360.0
	var by := 150.0
	draw_colored_polygon(PackedVector2Array([Vector2(c.x - bw * 0.5 - 20, by), Vector2(c.x + bw * 0.5 + 20, by), Vector2(c.x + bw * 0.5, by + 64), Vector2(c.x - bw * 0.5, by + 64)]), UIKit.DARK)
	draw_colored_polygon(PackedVector2Array([Vector2(c.x - bw * 0.5 - 14, by + 4), Vector2(c.x + bw * 0.5 + 14, by + 4), Vector2(c.x + bw * 0.5 - 2, by + 58), Vector2(c.x - bw * 0.5 + 2, by + 58)]), rar.color.darkened(0.15))
	S.text_c(self, rar.name, Vector2(c.x, by + 46), 38, Color.WHITE, 10)
	# prize card rising out
	var py := lerpf(cc.y, c.y + 20, k) + sin(_t * 2.5) * 6.0
	var card := Rect2(c.x - 150, py - 150, 300, 300)
	for g in 4:
		draw_rect(card.grow(10 + g * 10), Color(rc.r, rc.g, rc.b, 0.08))
	draw_rect(card.grow(5), UIKit.DARK)
	draw_rect(card, rc.darkened(0.55))
	draw_rect(Rect2(card.position, Vector2(card.size.x, card.size.y * 0.45)), Color(1, 1, 1, 0.07))
	var isc := 120.0 * (0.4 + 0.6 * k) * (1.0 + 0.03 * sin(_t * 4.0))
	RewardTile.draw_icon(self, _prize, card.get_center() + Vector2(0, -10), isc)
	var txt := Progression.reward_text(_prize)
	if _prize.has("amount") and _prize.get("type", "") in ["credits", "gems", "tokens"]:
		var unit: String = {"credits": "COINS", "gems": "GEMS", "tokens": "PASS TOKENS"}[_prize.type]
		txt = "+%d %s" % [int(_count), unit]
	S.text_c(self, txt, Vector2(c.x, card.end.y + 64), 40, Color.WHITE, 10)
	if _t > 0.45:
		var more := "TAP FOR NEXT DROP" if not Save.data.drops.is_empty() else "TAP TO CONTINUE"
		S.text_c(self, more, Vector2(c.x, size.y - 30), 22, Color(1, 1, 1, 0.6 + 0.4 * sin(_t * 4.0)), 5)
