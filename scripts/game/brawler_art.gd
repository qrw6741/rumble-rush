class_name BrawlerArt
extends RefCounted
## Procedural, animated cartoon art for every brawler. Used in battle AND menus so
## the characters always look identical. Everything is vector-drawn with thick
## anti-aliased outlines for a clean "sticker" look.
##
## anim keys: t (time), moving (bool), flash (0..1 white hit flash), recoil (0..1),
## aim (Vector2 normalized), alpha, blink (bool), skin_hue (optional)

const OUTLINE := Color("1a1028")
const OW := 3.0

static var _flash := 0.0
static var _alpha := 1.0
static var _s := 1.0 # current draw scale; outlines thin out at large sizes

static func _c(col: Color) -> Color:
	var r := col.lerp(Color(1, 1, 1, col.a), _flash)
	r.a *= _alpha
	return r

static func _ellipse_pts(c: Vector2, rx: float, ry: float, n := 28, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts

static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var p := pts.duplicate()
	p.append(pts[0])
	return p

static func poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, outline := true, w := OW) -> void:
	ci.draw_colored_polygon(pts, _c(fill))
	if outline:
		ci.draw_polyline(_closed(pts), _c(OUTLINE), w / sqrt(_s), true)
	else:
		ci.draw_polyline(_closed(pts), _c(fill), 1.0, true) # anti-alias the fill edge

static func ell(ci: CanvasItem, c: Vector2, rx: float, ry: float, fill: Color, outline := true, w := OW, rot := 0.0) -> void:
	poly(ci, _ellipse_pts(c, rx, ry, 28, rot), fill, outline, w)

static func circ(ci: CanvasItem, c: Vector2, r: float, fill: Color, outline := true, w := OW) -> void:
	ell(ci, c, r, r, fill, outline, w)

static func rrect_pts(center: Vector2, size: Vector2, radius: float, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	radius = min(radius, min(hx, hy))
	var corners := [Vector2(hx - radius, -hy + radius), Vector2(hx - radius, hy - radius), Vector2(-hx + radius, hy - radius), Vector2(-hx + radius, -hy + radius)]
	var start_angles := [-PI / 2, 0.0, PI / 2, PI]
	for i in 4:
		for s in 6:
			var a: float = start_angles[i] + (PI / 2) * float(s) / 5.0
			pts.append(center + (corners[i] + Vector2(cos(a), sin(a)) * radius).rotated(rot))
	return pts

static func rrect(ci: CanvasItem, center: Vector2, size: Vector2, radius: float, fill: Color, outline := true, w := OW, rot := 0.0) -> void:
	poly(ci, rrect_pts(center, size, radius, rot), fill, outline, w)

static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float, outline := true) -> void:
	if outline:
		var ow := OW * 2.0 / sqrt(_s)
		ci.draw_line(a, b, _c(OUTLINE), w + ow, true)
		ci.draw_circle(a, (w + ow) * 0.5, _c(OUTLINE))
		ci.draw_circle(b, (w + ow) * 0.5, _c(OUTLINE))
	ci.draw_line(a, b, _c(col), w, true)
	ci.draw_circle(a, w * 0.5, _c(col))
	ci.draw_circle(b, w * 0.5, _c(col))

static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color, layers := 4) -> void:
	for i in layers:
		var f := 1.0 - float(i) / float(layers)
		var cc := col
		cc.a = col.a * 0.22 * (1.0 - f * 0.5)
		cc.a *= _alpha
		ci.draw_circle(c, r * (0.45 + f * 0.75), cc)

# ---------------------------------------------------------------------------
## Draw a brawler with feet at `pos`.
static func draw(ci: CanvasItem, id: String, pos: Vector2, s: float, anim: Dictionary) -> void:
	var d: Dictionary = Config.BRAWLERS[id]
	var t: float = anim.get("t", 0.0)
	var moving: bool = anim.get("moving", false)
	_flash = anim.get("flash", 0.0)
	_alpha = anim.get("alpha", 1.0)
	_s = max(0.5, s)
	var aim: Vector2 = anim.get("aim", Vector2.RIGHT)
	if aim.length() < 0.01:
		aim = Vector2.RIGHT
	aim = aim.normalized()
	var facing := -1.0 if aim.x < -0.05 else 1.0
	var aim_l := Vector2(aim.x * facing, aim.y) # local aim (always pointing right-ish)
	var recoil: float = anim.get("recoil", 0.0)
	var bob := 0.0
	var squash := 1.0
	var step := 0.0
	if moving:
		bob = -absf(sin(t * 12.0)) * 3.5
		step = sin(t * 12.0)
		squash = 1.0 + sin(t * 24.0) * 0.03
	else:
		bob = sin(t * 2.6) * 0.8
		squash = 1.0 + sin(t * 2.6) * 0.015

	# shadow (unflipped, unscaled by bob)
	ci.draw_set_transform(pos, 0.0, Vector2(s, s))
	var sh := Color(0, 0, 0, 0.32 * _alpha)
	ci.draw_colored_polygon(_ellipse_pts(Vector2(0, 1), 24, 8.5), sh)

	ci.draw_set_transform(pos + Vector2(0, bob * s), 0.0, Vector2(s * facing / squash, s * squash))
	var blink: bool = anim.get("blink", false)
	match id:
		"bront": _bront(ci, d, t, aim_l, recoil, step, blink)
		"vex": _vex(ci, d, t, aim_l, recoil, step, blink, moving)
		"nova": _nova(ci, d, t, aim_l, recoil, step, blink)
		"mira": _mira(ci, d, t, aim_l, recoil, step, blink)
		"sprig": _sprig(ci, d, t, aim_l, recoil, step, blink)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_flash = 0.0
	_alpha = 1.0
	_s = 1.0

static func _legs(ci: CanvasItem, col: Color, step: float, spread := 8.0, y := -7.0, size := Vector2(10, 11)) -> void:
	rrect(ci, Vector2(-spread, y + step * 2.0), size, 4, col)
	rrect(ci, Vector2(spread, y - step * 2.0), size, 4, col)

static func _eyes(ci: CanvasItem, l: Vector2, r: Vector2, rx: float, ry: float, look: Vector2, blink: bool, pupil := Color("1a1028"), white := Color.WHITE) -> void:
	if blink:
		line(ci, l + Vector2(-rx, 0), l + Vector2(rx, 0), OUTLINE, 2.0, false)
		line(ci, r + Vector2(-rx, 0), r + Vector2(rx, 0), OUTLINE, 2.0, false)
		return
	for e in [l, r]:
		ell(ci, e, rx, ry, white, true, 2.0)
		var p: Vector2 = e + look * Vector2(rx * 0.35, ry * 0.3)
		ell(ci, p, rx * 0.55, ry * 0.62, pupil, false)
		ci.draw_circle(p + Vector2(-rx * 0.2, -ry * 0.28), rx * 0.2, _c(Color.WHITE))

# ------------------------------------------------------------------ BRONT (tank)
static func _bront(ci: CanvasItem, d: Dictionary, t: float, aim: Vector2, recoil: float, step: float, blink: bool) -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	var hand := Vector2(20, -24)
	var swing := -recoil * 1.9 + recoil * recoil * 0.6
	var ang := aim.angle() + swing
	var hammer_behind := aim.y < -0.35
	if hammer_behind:
		_bront_hammer(ci, hand, ang)
	_legs(ci, sec.darkened(0.2), step, 10.0, -7.0, Vector2(13, 12))
	# torso
	rrect(ci, Vector2(0, -25), Vector2(50, 34), 14, prim)
	rrect(ci, Vector2(0, -21), Vector2(30, 22), 7, prim.darkened(0.18), false)
	line(ci, Vector2(-9, -34), Vector2(-9, -24), acc.darkened(0.1), 3.0, false)
	line(ci, Vector2(9, -34), Vector2(9, -24), acc.darkened(0.1), 3.0, false)
	rrect(ci, Vector2(0, -12), Vector2(46, 6), 3, sec)
	rrect(ci, Vector2(0, -12), Vector2(9, 7), 2, acc)
	# off arm
	circ(ci, Vector2(-25, -22 + step), 8.5, skin)
	# head
	circ(ci, Vector2(0, -48), 15, skin)
	_eyes(ci, Vector2(-5.5, -51), Vector2(6, -51), 3.4, 3.8, aim, blink)
	line(ci, Vector2(-9.5, -57), Vector2(-2, -55), OUTLINE, 2.6, false)
	line(ci, Vector2(10, -57), Vector2(2.5, -55), OUTLINE, 2.6, false)
	# beard
	var beard := PackedVector2Array([Vector2(-14, -47), Vector2(-12, -38), Vector2(-6, -33), Vector2(0, -31), Vector2(6, -33), Vector2(12, -38), Vector2(14, -47), Vector2(8, -43), Vector2(0, -42), Vector2(-8, -43)])
	poly(ci, beard, sec.lightened(0.15))
	# hard hat
	var hat := PackedVector2Array()
	for i in 15:
		var a := PI + PI * float(i) / 14.0
		hat.append(Vector2(0, -56) + Vector2(cos(a) * 16, sin(a) * 12))
	poly(ci, hat, acc)
	rrect(ci, Vector2(0, -56), Vector2(40, 6), 3, acc.darkened(0.12))
	rrect(ci, Vector2(0, -64), Vector2(5, 10), 2, acc.lightened(0.3), false)
	if not hammer_behind:
		_bront_hammer(ci, hand, ang)
	circ(ci, hand, 8.5, skin)

static func _bront_hammer(ci: CanvasItem, hand: Vector2, ang: float) -> void:
	var dir := Vector2.RIGHT.rotated(ang)
	var tip := hand + dir * 30.0
	line(ci, hand - dir * 4.0, tip, Color("8a5a36"), 6.0)
	rrect(ci, tip + dir * 6.0, Vector2(20, 30), 5, Color("9aa3b5"), true, OW, ang)
	rrect(ci, tip + dir * 6.0, Vector2(6, 30), 2, Color("e9893a"), false, OW, ang)
	rrect(ci, tip + dir * 1.0, Vector2(4, 24), 1, Color("c9d0de"), false, OW, ang)

# ------------------------------------------------------------------ VEX (assassin)
static func _vex(ci: CanvasItem, d: Dictionary, t: float, aim: Vector2, recoil: float, step: float, blink: bool, moving: bool) -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	# scarf trailing behind
	var pts := PackedVector2Array()
	var wave_speed := 14.0 if moving else 5.0
	for i in 7:
		var f := float(i)
		pts.append(Vector2(-4 - f * 5.5, -34 + f * 1.5 + sin(t * wave_speed - f * 0.9) * (1.0 + f * 0.7)))
	ci.draw_polyline(pts, _c(OUTLINE), 10.0, true)
	ci.draw_polyline(pts, _c(acc), 5.0, true)
	var back_blade := Vector2(-13, -20)
	_vex_blade(ci, back_blade, aim.angle() + 2.4 - recoil * 0.6, acc, 0.85)
	_legs(ci, sec, step, 6.0, -6.0, Vector2(8, 11))
	# cloak body
	var body := PackedVector2Array([Vector2(-16, -10), Vector2(-12, -34), Vector2(12, -34), Vector2(16, -10), Vector2(8, -6), Vector2(0, -9), Vector2(-8, -6)])
	poly(ci, body, prim)
	poly(ci, PackedVector2Array([Vector2(-4, -33), Vector2(4, -33), Vector2(2, -12), Vector2(-2, -12)]), prim.darkened(0.3), false)
	rrect(ci, Vector2(0, -18), Vector2(28, 4), 2, sec.lightened(0.1), false)
	# hood with swept tip
	var hood := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		hood.append(Vector2(0, -45) + Vector2(cos(a) * 16, sin(a) * 15))
		if i == 15: # upper-left: sweep the hood tip out behind
			hood.append(Vector2(-21, -63 + sin(t * 4.0) * 1.5))
			hood.append(Vector2(-9, -60))
	poly(ci, hood, prim)
	ell(ci, Vector2(3, -43), 11, 9, sec)
	# glowing eyes
	var look := aim * 2.0
	glow(ci, Vector2(-1, -44) + look, 6, acc)
	glow(ci, Vector2(8, -44) + look, 6, acc)
	if blink:
		line(ci, Vector2(-4, -44) + look, Vector2(2, -44) + look, acc, 2.0, false)
		line(ci, Vector2(5, -44) + look, Vector2(11, -44) + look, acc, 2.0, false)
	else:
		ell(ci, Vector2(-1, -44) + look, 3.2, 2.2, acc, false, 1.0, -0.25)
		ell(ci, Vector2(8, -44) + look, 3.2, 2.2, acc, false, 1.0, 0.25)
	# front blade
	var hand := Vector2(14, -22)
	_vex_blade(ci, hand + aim * (4.0 + recoil * 10.0), aim.angle() - 0.4 + recoil * 1.6, acc, 1.0)
	circ(ci, hand, 5.0, sec)

static func _vex_blade(ci: CanvasItem, at: Vector2, ang: float, acc: Color, sc: float) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := -1.0 + 2.0 * float(i) / 8.0
		pts.append(at + Vector2(cos(a) * 18.0, sin(a) * 18.0 * 0.9).rotated(ang) * sc)
	for i in 9:
		var a := 1.0 - 2.0 * float(i) / 8.0
		pts.append(at + (Vector2(cos(a) * 11.0, sin(a) * 14.0) + Vector2(1, 0)).rotated(ang) * sc)
	glow(ci, at + Vector2(14, 0).rotated(ang) * sc, 10 * sc, acc, 3)
	poly(ci, pts, acc.lightened(0.25), true, 2.5)

# ------------------------------------------------------------------ NOVA (marksman)
static func _nova(ci: CanvasItem, d: Dictionary, t: float, aim: Vector2, recoil: float, step: float, blink: bool) -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	var hair := Color("2a1a14")
	var hand := Vector2(10, -24)
	var behind := aim.y < -0.4
	if behind:
		_nova_rifle(ci, hand, aim, recoil, prim, acc)
	_legs(ci, sec.lightened(0.05), step, 6.5, -7.0, Vector2(9, 12))
	# ponytail
	var sway := sin(t * 5.0) * 0.25
	ell(ci, Vector2(-15, -47), 9, 5.5, hair, true, OW, 0.5 + sway)
	ell(ci, Vector2(-22, -42), 5, 4, hair, true, OW, 0.9 + sway)
	# jacket
	rrect(ci, Vector2(0, -23), Vector2(32, 26), 9, sec)
	poly(ci, PackedVector2Array([Vector2(-3, -35), Vector2(3, -35), Vector2(6, -11), Vector2(-6, -11)]), prim, false)
	rrect(ci, Vector2(-12, -28), Vector2(5, 12), 2, prim, false)
	circ(ci, Vector2(-16, -21 + step), 5.5, sec.lightened(0.15))
	# head
	circ(ci, Vector2(0, -45), 15, skin)
	var hair_top := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		hair_top.append(Vector2(0, -47) + Vector2(cos(a) * 16, sin(a) * 13))
	hair_top.append(Vector2(10, -47))
	hair_top.append(Vector2(-4, -51))
	poly(ci, hair_top, hair)
	# visor
	rrect(ci, Vector2(3, -45), Vector2(28, 9), 4, prim)
	var shine := Color(1, 1, 1, 0.85)
	var shine_x := fmod(t * 0.7, 2.0) * 30.0 - 12.0
	if shine_x > -10 and shine_x < 14:
		line(ci, Vector2(shine_x, -48), Vector2(shine_x + 3, -42), shine, 2.0, false)
	if not blink:
		ell(ci, Vector2(-2 + aim.x * 2, -45), 2.5, 2, acc, false)
		ell(ci, Vector2(8 + aim.x * 2, -45), 2.5, 2, acc, false)
	line(ci, Vector2(1, -37), Vector2(5, -37), OUTLINE, 1.8, false)
	if not behind:
		_nova_rifle(ci, hand, aim, recoil, prim, acc)

static func _nova_rifle(ci: CanvasItem, hand: Vector2, aim: Vector2, recoil: float, prim: Color, acc: Color) -> void:
	var a := aim.angle()
	var back := hand - aim * (recoil * 8.0)
	var mid := back + aim * 18.0
	rrect(ci, back + aim * 4.0, Vector2(16, 9), 3, Color("3a4766"), true, OW, a)
	rrect(ci, mid, Vector2(34, 8), 3, acc, true, OW, a)
	rrect(ci, mid + aim * 22.0, Vector2(16, 4), 2, Color("3a4766"), true, OW, a)
	rrect(ci, mid + Vector2(-2, -6).rotated(a), Vector2(14, 5), 2, Color("3a4766"), true, 2.0, a)
	line(ci, mid - aim * 10.0, mid + aim * 8.0, prim, 2.5, false)
	glow(ci, mid + aim * 31.0, 7.0 + recoil * 8.0, prim)
	circ(ci, back, 5.5, Color("8d5a3b"))

# ------------------------------------------------------------------ MIRA (support)
static func _mira(ci: CanvasItem, d: Dictionary, t: float, aim: Vector2, recoil: float, step: float, blink: bool) -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	# lantern (behind when aiming up)
	var lantern := Vector2(16, -28) + aim * (10.0 + recoil * 8.0) + Vector2(0, sin(t * 3.0) * 2.0)
	var behind := aim.y < -0.4
	if behind:
		_mira_lantern(ci, lantern, t, acc, recoil)
	_legs(ci, sec.darkened(0.15), step, 6.0, -6.0, Vector2(8, 10))
	# dress
	var dress := PackedVector2Array([Vector2(-17, -9), Vector2(-10, -32), Vector2(10, -32), Vector2(17, -9), Vector2(9, -6), Vector2(0, -8), Vector2(-9, -6)])
	poly(ci, dress, sec)
	ci.draw_polyline(PackedVector2Array([Vector2(-16, -11), Vector2(-8, -8), Vector2(0, -10), Vector2(8, -8), Vector2(16, -11)]), _c(prim), 3.0, true)
	circ(ci, Vector2(0, -25), 3.0, acc, false)
	# hair back + buns
	circ(ci, Vector2(-15, -58), 8, prim)
	circ(ci, Vector2(15, -58), 8, prim)
	circ(ci, Vector2(0, -47), 18, prim)
	# face
	ell(ci, Vector2(0, -43), 13, 12, skin)
	# bangs
	var bangs := PackedVector2Array([Vector2(-15, -48), Vector2(-12, -58), Vector2(0, -61), Vector2(12, -58), Vector2(15, -48), Vector2(8, -51), Vector2(2, -48), Vector2(-4, -51), Vector2(-10, -48)])
	poly(ci, bangs, prim.lightened(0.08))
	_eyes(ci, Vector2(-5, -42), Vector2(6, -42), 3.6, 4.4, aim, blink, Color("3b2350"))
	ell(ci, Vector2(-10, -37), 3, 1.6, Color(1, 0.45, 0.55, 0.5), false)
	ell(ci, Vector2(11, -37), 3, 1.6, Color(1, 0.45, 0.55, 0.5), false)
	# arm
	circ(ci, Vector2(-14, -22 + step), 4.5, skin)
	if not behind:
		_mira_lantern(ci, lantern, t, acc, recoil)

static func _mira_lantern(ci: CanvasItem, at: Vector2, t: float, acc: Color, recoil: float) -> void:
	glow(ci, at, 16 + recoil * 10.0 + sin(t * 6.0) * 1.5, acc)
	line(ci, at + Vector2(0, -12), at + Vector2(-6, -18), Color("c9a24a"), 2.0, false)
	rrect(ci, at + Vector2(0, -9), Vector2(10, 4), 2, Color("c9a24a"), true, 2.0)
	rrect(ci, at, Vector2(12, 14), 4, Color(acc.r, acc.g, acc.b, 0.85), true, 2.5)
	ell(ci, at + Vector2(0, 1), 3, 4.5 + sin(t * 9.0), Color.WHITE, false)
	rrect(ci, at + Vector2(0, 8), Vector2(10, 4), 2, Color("c9a24a"), true, 2.0)

# ------------------------------------------------------------------ SPRIG (controller)
static func _sprig(ci: CanvasItem, d: Dictionary, t: float, aim: Vector2, recoil: float, step: float, blink: bool) -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	# backpack
	rrect(ci, Vector2(-13, -25), Vector2(16, 22), 5, Color("8a5a36"))
	circ(ci, Vector2(-15, -33), 3, acc, false)
	circ(ci, Vector2(-10, -30), 2.5, acc.darkened(0.1), false)
	_legs(ci, sec, step, 6.0, -5.0, Vector2(8, 9))
	# body
	ell(ci, Vector2(0, -19), 13, 12, prim)
	ell(ci, Vector2(2, -17), 7, 7, skin.lightened(0.2), false)
	# ears
	poly(ci, PackedVector2Array([Vector2(-14, -44), Vector2(-28, -50 + sin(t * 3.0)), Vector2(-15, -36)]), skin)
	poly(ci, PackedVector2Array([Vector2(14, -44), Vector2(28, -50 - sin(t * 3.0)), Vector2(15, -36)]), skin)
	# head
	ell(ci, Vector2(0, -40), 17, 14, skin)
	# sprout
	var sway := sin(t * 3.5) * 0.3
	line(ci, Vector2(0, -53), Vector2(1, -61), sec, 2.5, false)
	ell(ci, Vector2(-5, -63), 6, 3, prim, true, 2.0, -0.5 + sway)
	ell(ci, Vector2(6, -64), 6, 3, prim, true, 2.0, 0.5 + sway)
	# goggles
	line(ci, Vector2(-16, -49), Vector2(16, -49), Color("6b3f1f"), 3.0, false)
	circ(ci, Vector2(-6, -50), 5, acc, true, 2.5)
	circ(ci, Vector2(6, -50), 5, acc, true, 2.5)
	ci.draw_circle(Vector2(-7.5, -51.5), 1.6, _c(Color.WHITE))
	ci.draw_circle(Vector2(4.5, -51.5), 1.6, _c(Color.WHITE))
	_eyes(ci, Vector2(-6, -39), Vector2(7, -39), 3.6, 4.0, aim, blink)
	# grin
	ci.draw_arc(Vector2(1, -34), 5.0, 0.3, PI - 0.3, 10, _c(OUTLINE), 2.0, true)
	ci.draw_line(Vector2(0, -29.5), Vector2(0, -31), _c(Color.WHITE), 2.0)
	# hand with seed
	var hand := Vector2(13, -22) + aim * (6.0 - recoil * 6.0)
	circ(ci, hand + aim * 6.0, 5.5, acc)
	ci.draw_circle(hand + aim * 6.0 + Vector2(-1.5, -1.5), 1.6, _c(Color(1, 1, 1, 0.8)))
	circ(ci, hand, 4.5, skin)

# ---------------------------------------------------------------------------
## Draws a stylized projectile for a given visual style.
static func draw_projectile(ci: CanvasItem, style: String, pos: Vector2, dir: Vector2, t: float, team_col: Color, d: Dictionary) -> void:
	var a := dir.angle()
	match style:
		"slash":
			var acc: Color = d.accent
			glow(ci, pos, 20, acc)
			var pts := PackedVector2Array()
			for i in 11:
				var ang := -1.2 + 2.4 * float(i) / 10.0
				pts.append(pos + Vector2(cos(ang) * 16, sin(ang) * 18).rotated(a))
			for i in 11:
				var ang := 1.2 - 2.4 * float(i) / 10.0
				pts.append(pos + Vector2(cos(ang) * 9 - 3, sin(ang) * 13).rotated(a))
			poly(ci, pts, acc.lightened(0.3), true, 2.0)
		"bolt":
			var prim: Color = d.primary
			glow(ci, pos, 16, prim)
			for i in 4:
				var tail := pos - dir * (8.0 + i * 9.0)
				var c := prim
				c.a = 0.5 - i * 0.11
				ci.draw_circle(tail, 6.0 - i, c)
			rrect(ci, pos, Vector2(26, 9), 4, Color.WHITE, true, 2.0, a)
			rrect(ci, pos, Vector2(18, 4), 2, prim.lightened(0.4), false, 1.0, a)
		"orb":
			var acc: Color = d.accent
			var prim: Color = d.primary
			glow(ci, pos, 22, acc)
			for i in 3:
				var tp := pos - dir * (10.0 + i * 8.0) + Vector2(0, sin(t * 20.0 + i) * 3.0)
				ci.draw_circle(tp, 5.0 - i * 1.3, Color(prim.r, prim.g, prim.b, 0.6 - i * 0.15))
			circ(ci, pos, 9, acc.lightened(0.2), true, 2.5)
			ell(ci, pos + Vector2(-3, -3), 3, 2, Color.WHITE, false)
		"seed":
			var acc: Color = d.accent
			circ(ci, pos, 10, acc, true, 2.5)
			line(ci, pos + Vector2(0, -9), pos + Vector2(3, -15), Color("2f4a1f"), 2.0, false)
			ell(ci, pos + Vector2(6, -15), 5, 2.5, Color("5fd35a"), true, 1.5, 0.4)
			ci.draw_circle(pos + Vector2(-3, -3), 2.2, Color(1, 1, 1, 0.8))
		"lantern":
			var acc: Color = d.accent
			glow(ci, pos, 26, acc)
			circ(ci, pos, 12, acc, true, 2.5)
			ell(ci, pos, 4, 7, Color.WHITE, false)
		_:
			circ(ci, pos, 8, team_col)
