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

static var shading := true

static func poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, outline := true, w := OW) -> void:
	ci.draw_colored_polygon(pts, _c(fill))
	if outline and shading and pts.size() >= 4:
		_shade(ci, pts, fill)
	if outline:
		ci.draw_polyline(_closed(pts), _c(OUTLINE), w / sqrt(_s), true)
	else:
		ci.draw_polyline(_closed(pts), _c(fill), 1.0, true) # anti-alias the fill edge

## Painterly volume: darker underside, soft highlight up-left, warm bounce light.
static func _shade(ci: CanvasItem, pts: PackedVector2Array, fill: Color) -> void:
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var sz := hi - lo
	if sz.x < 7.0 or sz.y < 7.0:
		return
	# underside shadow: bottom 38%, slightly curved
	var cut := lo.y + sz.y * 0.62
	var band := PackedVector2Array([Vector2(lo.x - 2, cut + sz.y * 0.06), Vector2(lo.x + sz.x * 0.5, cut - sz.y * 0.04), Vector2(hi.x + 2, cut + sz.y * 0.06), Vector2(hi.x + 2, hi.y + 2), Vector2(lo.x - 2, hi.y + 2)])
	var dark := fill.darkened(0.2).lerp(Color("3a2a8a"), 0.12)
	for part in Geometry2D.intersect_polygons(pts, band):
		ci.draw_colored_polygon(part, _c(dark))
	# highlight: shrunken copy nudged up-left, clipped to the top part
	var c := (lo + hi) * 0.5
	var inset := PackedVector2Array()
	for p in pts:
		inset.append(c + (p - c) * 0.72 + Vector2(-sz.x * 0.08, -sz.y * 0.1))
	var top := PackedVector2Array([Vector2(lo.x - 2, lo.y - 2), Vector2(hi.x + 2, lo.y - 2), Vector2(hi.x + 2, lo.y + sz.y * 0.42), Vector2(lo.x - 2, lo.y + sz.y * 0.5)])
	var light := fill.lightened(0.28)
	light.a = fill.a * 0.75
	for a in Geometry2D.intersect_polygons(inset, pts):
		for part in Geometry2D.intersect_polygons(a, top):
			ci.draw_colored_polygon(part, _c(light))
	# tiny specular dot on bigger forms
	if sz.x > 16.0 and sz.y > 14.0:
		var sp := lo + Vector2(sz.x * 0.3, sz.y * 0.24)
		if Geometry2D.is_point_in_polygon(sp, pts):
			var w := Color(1, 1, 1, 0.45)
			ci.draw_circle(sp, minf(sz.x, sz.y) * 0.07, _c(w))

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
		"rio": _rio(ci, d, t, aim_l, recoil, step, blink)
		_: _nova(ci, d, t, aim_l, recoil, step, blink)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_flash = 0.0
	_alpha = 1.0
	_s = 1.0

# ====================================================================== drawing kit
## Smooth closed (or open) Catmull-Rom curve through control points.
static func spline(ctrl: Array, closed := true, per := 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	var segs := n if closed else n - 1
	for i in segs:
		var p0: Vector2 = ctrl[(i - 1 + n) % n] if closed or i > 0 else ctrl[0]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[(i + 1) % n]
		var p3: Vector2 = ctrl[(i + 2) % n] if closed or i + 2 < n else ctrl[n - 1]
		for k in per:
			var t := float(k) / per
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	if not closed:
		out.append(ctrl[n - 1])
	return out

## An organic shape: smooth curve through the given points, shaded and inked.
static func blob(ci: CanvasItem, ctrl: Array, fill: Color, outline := true, w := OW) -> void:
	poly(ci, spline(ctrl), fill, outline, w)

## Offset a list of points.
static func _o(pts: Array, off: Vector2, sx := 1.0) -> Array:
	var r: Array = []
	for q in pts:
		r.append(off + Vector2(q.x * sx, q.y))
	return r

## Tapered limb from a (width wa) to b (width wb) with rounded ends.
static func limb(ci: CanvasItem, a: Vector2, b: Vector2, wa: float, wb: float, col: Color, outline := true) -> void:
	var d := (b - a).normalized()
	var n := d.orthogonal()
	var pts := PackedVector2Array()
	for k in 7:
		var ang := PI * 0.5 + PI * float(k) / 6.0
		pts.append(a + (d * cos(ang) + n * sin(ang)) * wa * 0.5)
	for k in 7:
		var ang := -PI * 0.5 + PI * float(k) / 6.0
		pts.append(b + (d * cos(ang) + n * sin(ang)) * wb * 0.5)
	poly(ci, pts, col, outline, 2.4)

## Cartoon hand: rounded palm, thumb and knuckle creases, pointing along dir.
static func hand(ci: CanvasItem, p: Vector2, dir: Vector2, col: Color, r := 5.0) -> void:
	var d := dir.normalized()
	var n := d.orthogonal()
	blob(ci, [p - d * r * 0.9 + n * r * 0.7, p + d * r * 0.5 + n * r * 0.9, p + d * r * 1.15, p + d * r * 0.5 - n * r * 0.9, p - d * r * 0.9 - n * r * 0.7], col, true, 2.2)
	limb(ci, p - n * r * 0.6, p - n * r * 1.2 + d * r * 0.6, r * 0.6, r * 0.5, col)
	for k in 2:
		var q := p + d * r * 0.55 + n * (k - 0.5) * r * 0.7
		ci.draw_line(q, q + d * r * 0.35, _c(col.darkened(0.3)), 1.2, true)

## Chunky boot / sneaker with sole and toe cap. p = ankle.
static func boot(ci: CanvasItem, p: Vector2, col: Color, sole: Color, size := 1.0, cap := Color(0, 0, 0, 0)) -> void:
	var s2 := size
	blob(ci, _o([Vector2(-4, -5), Vector2(4, -6), Vector2(7, -2), Vector2(11, 1), Vector2(10, 4), Vector2(-5, 4), Vector2(-6, 0)], p, s2), col, true, 2.4)
	poly(ci, PackedVector2Array([p + Vector2(-6, 2.5) * s2, p + Vector2(11, 2.5) * s2, p + Vector2(10.5, 5) * s2, p + Vector2(-5.5, 5) * s2]), sole, true, 2.0)
	if cap.a > 0.0:
		blob(ci, _o([Vector2(5, -1.5), Vector2(10, 0.5), Vector2(9.5, 2.5), Vector2(4, 2.5)], p, s2), cap, false)

## A pair of walking legs from the hips down. Returns nothing; draws back leg first.
static func legs2(ci: CanvasItem, step: float, hip: float, spread: float, length: float, w: float, pants: Color, boot_col: Color, sole: Color, bsize := 1.0, cap := Color(0, 0, 0, 0), front := true) -> void:
	for side: float in [-1.0, 1.0]:
		var sw := step * side * 4.0
		var lift := maxf(0.0, step * side) * 2.5
		var hp := Vector2(side * spread, -hip)
		var ank := Vector2(side * spread + sw, -3.0 - lift)
		var knee := (hp + ank) * 0.5 + Vector2(1.5, 0)
		var col := pants if side > 0 else pants.darkened(0.12)
		limb(ci, hp, knee, w, w * 0.9, col)
		limb(ci, knee, ank + Vector2(0, -2), w * 0.9, w * 0.8, col)
		boot(ci, ank, boot_col if side > 0 else boot_col.darkened(0.1), sole, bsize, cap)

static func _eyes(ci: CanvasItem, l: Vector2, r: Vector2, rx: float, ry: float, look: Vector2, blink: bool, pupil := Color("1a1028"), white := Color.WHITE) -> void:
	if blink:
		line(ci, l + Vector2(-rx, 0), l + Vector2(rx, 0), OUTLINE, 2.0, false)
		line(ci, r + Vector2(-rx, 0), r + Vector2(rx, 0), OUTLINE, 2.0, false)
		return
	for e in [l, r]:
		ell(ci, e, rx, ry, white, true, 2.0)
		var p: Vector2 = e + look * Vector2(rx * 0.35, ry * 0.3)
		# iris with a lighter lower half, pupil, two catch-lights, lash line
		ell(ci, p, rx * 0.62, ry * 0.68, pupil.lightened(0.25), false)
		ell(ci, p + Vector2(0, ry * 0.18), rx * 0.48, ry * 0.4, pupil.lightened(0.45), false)
		ell(ci, p, rx * 0.34, ry * 0.4, Color("0d0812"), false)
		ci.draw_circle(p + Vector2(-rx * 0.22, -ry * 0.3), rx * 0.22, _c(Color.WHITE))
		ci.draw_circle(p + Vector2(rx * 0.2, ry * 0.25), rx * 0.1, _c(Color(1, 1, 1, 0.8)))
		var lash := PackedVector2Array()
		for k in 9:
			var a := PI + PI * float(k) / 8.0
			lash.append(e + Vector2(cos(a) * rx * 1.02, sin(a) * ry * 1.02))
		ci.draw_polyline(lash, _c(OUTLINE), 2.2, true)


## Simple open-mouth smile with teeth, centred at p.
static func _mouth(ci: CanvasItem, p: Vector2, w: float, open := 3.0, teeth := true) -> void:
	var m := spline([p + Vector2(-w * 0.5, 0), p + Vector2(0, -0.6), p + Vector2(w * 0.5, -0.5), p + Vector2(w * 0.25, open), p + Vector2(-w * 0.2, open * 0.9)])
	poly(ci, m, Color("5a1a2a"), true, 1.5)
	if teeth:
		poly(ci, PackedVector2Array([p + Vector2(-w * 0.4, 0.2), p + Vector2(w * 0.42, -0.2), p + Vector2(w * 0.36, open * 0.38), p + Vector2(-w * 0.3, open * 0.4)]), Color.WHITE, false)

## Head silhouette: rounded cranium, soft cheek, slight jaw (facing right).
static func _head_pts(c: Vector2, w: float, h: float) -> Array:
	return [c + Vector2(-w * 0.5, -h * 0.05), c + Vector2(-w * 0.38, -h * 0.42), c + Vector2(0, -h * 0.52), c + Vector2(w * 0.42, -h * 0.38), c + Vector2(w * 0.54, -h * 0.02), c + Vector2(w * 0.46, h * 0.3), c + Vector2(w * 0.12, h * 0.5), c + Vector2(-w * 0.3, h * 0.4)]

static func _ear(ci: CanvasItem, p: Vector2, skin: Color, r := 3.5) -> void:
	blob(ci, [p + Vector2(-r * 0.6, -r), p + Vector2(r * 0.7, -r * 0.6), p + Vector2(r * 0.6, r * 0.8), p + Vector2(-r * 0.5, r)], skin, true, 2.0)
	ci.draw_arc(p, r * 0.45, -1.2, 1.4, 6, _c(skin.darkened(0.25)), 1.2, true)

# ------------------------------------------------------------------ BRONT (tank)
static func _bront(ci: CanvasItem, d: Dictionary, t: float, aim: Vector2, recoil: float, step: float, blink: bool) -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	var denim := Color("3c5a8a")
	var swing := -recoil * 1.9 + recoil * recoil * 0.6
	var ang := aim.angle() + swing
	var hand_p := Vector2(22, -26)
	var hammer_behind := aim.y < -0.35
	# back arm
	limb(ci, Vector2(-18, -36), Vector2(-24, -22 + step * 2.0), 12, 10, prim.darkened(0.1))
	limb(ci, Vector2(-24, -22 + step * 2.0), Vector2(-24, -14 + step * 2.0), 10, 9, skin.darkened(0.08))
	hand(ci, Vector2(-24, -12 + step * 2.0), Vector2(0, 1), skin.darkened(0.08), 6.5)
	if hammer_behind:
		_bront_hammer(ci, hand_p, ang)
	legs2(ci, step, 14, 8.5, 12, 11, denim, Color("4a3020"), Color("2a1a10"), 1.25)
	# barrel chest + overalls
	blob(ci, [Vector2(-22, -18), Vector2(-24, -34), Vector2(-14, -44), Vector2(0, -46), Vector2(15, -44), Vector2(24, -34), Vector2(22, -18), Vector2(12, -11), Vector2(-12, -11)], prim)
	blob(ci, [Vector2(-17, -12), Vector2(-15, -30), Vector2(15, -30), Vector2(17, -12), Vector2(0, -9)], denim)
	poly(ci, PackedVector2Array([Vector2(-6, -28), Vector2(6, -28), Vector2(6, -20), Vector2(-6, -20)]), denim.lightened(0.1), true, 2.0)
	for sx: float in [-1.0, 1.0]:
		limb(ci, Vector2(10 * sx, -29), Vector2(12 * sx, -43), 4, 4, acc.darkened(0.05), false)
		ci.draw_circle(Vector2(10 * sx, -29), 2.0, _c(Color("e6e9f2")))
	blob(ci, [Vector2(-21, -15), Vector2(0, -17), Vector2(21, -15), Vector2(20, -11), Vector2(0, -12), Vector2(-20, -11)], Color("4a2e1e"), true, 2.0)
	poly(ci, PackedVector2Array([Vector2(-4, -17), Vector2(4, -17), Vector2(4, -10), Vector2(-4, -10)]), acc, true, 2.0)
	# head: big jaw, bushy beard, hard hat with lamp
	var hc := Vector2(2, -54)
	_ear(ci, hc + Vector2(-12, 1), skin)
	blob(ci, _head_pts(hc, 28, 26), skin)
	blob(ci, [hc + Vector2(-13, -1), hc + Vector2(-8, 4), hc + Vector2(2, 3), hc + Vector2(13, 2), hc + Vector2(15, 9), hc + Vector2(8, 17), hc + Vector2(-2, 18), hc + Vector2(-11, 12)], sec.lightened(0.25))
	blob(ci, [hc + Vector2(-1, 2), hc + Vector2(6, -1), hc + Vector2(14, 2), hc + Vector2(8, 5)], sec.lightened(0.35), true, 2.0)
	_mouth(ci, hc + Vector2(6, 8), 7.0, 2.5)
	blob(ci, [hc + Vector2(8, -2), hc + Vector2(12, -4), hc + Vector2(14, 0), hc + Vector2(10, 2)], skin.darkened(0.08), true, 2.0)
	_eyes(ci, hc + Vector2(1, -6), hc + Vector2(10, -6), 3.0, 3.4, aim, blink, Color("3a5aa0"))
	limb(ci, hc + Vector2(-3, -12), hc + Vector2(4, -10), 4, 3, sec.lightened(0.2), false)
	limb(ci, hc + Vector2(8, -10), hc + Vector2(14, -12), 3, 4, sec.lightened(0.2), false)
	blob(ci, [hc + Vector2(-16, -6), hc + Vector2(-12, -18), hc + Vector2(0, -23), hc + Vector2(13, -19), hc + Vector2(17, -7), hc + Vector2(0, -9)], acc)
	blob(ci, [hc + Vector2(-19, -7), hc + Vector2(0, -10), hc + Vector2(21, -7), hc + Vector2(20, -4), hc + Vector2(0, -6), hc + Vector2(-18, -4)], acc.darkened(0.15), true, 2.0)
	blob(ci, [hc + Vector2(8, -17), hc + Vector2(14, -17), hc + Vector2(14, -11), hc + Vector2(8, -11)], Color("3a3f58"), true, 2.0)
	ci.draw_circle(hc + Vector2(13, -14), 2.4, _c(Color("fff6c2")))
	glow(ci, hc + Vector2(15, -14), 6, Color(1, 0.95, 0.6, 0.8), 2)
	# front arm swinging the hammer
	if not hammer_behind:
		_bront_hammer(ci, hand_p, ang)
	limb(ci, Vector2(16, -38), Vector2(20, -30), 13, 11, prim)
	limb(ci, Vector2(20, -30), hand_p, 11, 10, skin)
	hand(ci, hand_p, Vector2.RIGHT.rotated(ang), Color("6b3f22"), 7.0)

static func _bront_hammer(ci: CanvasItem, hand_p: Vector2, ang: float) -> void:
	var dir := Vector2.RIGHT.rotated(ang)
	var n := dir.orthogonal()
	var tip := hand_p + dir * 32.0
	limb(ci, hand_p - dir * 6.0, tip, 6, 6, Color("8a5a36"))
	limb(ci, hand_p + dir * 6.0, hand_p + dir * 10.0, 7.5, 7.5, Color("3a2a22"), false)
	var head := PackedVector2Array([tip - n * 15 - dir * 3, tip + n * 15 - dir * 3, tip + n * 13 + dir * 15, tip - n * 13 + dir * 15])
	poly(ci, head, Color("9aa3b5"))
	poly(ci, PackedVector2Array([tip - n * 16 + dir * 4, tip + n * 16 + dir * 4, tip + n * 16 + dir * 9, tip - n * 16 + dir * 9]), Color("e9893a"), true, 2.0)

# ------------------------------------------------------------------ VEX (assassin)
static func _vex(ci: CanvasItem, d: Dictionary, t: float, aim: Vector2, recoil: float, step: float, blink: bool, moving: bool) -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	var wave := 14.0 if moving else 5.0
	# flowing sash behind
	var sash: Array = []
	for i in 7:
		var f := float(i)
		sash.append(Vector2(-6 - f * 5.5, -36 + f * 1.8 + sin(t * wave - f * 0.9) * (1.0 + f * 0.8)))
	var sp := spline(sash, false)
	ci.draw_polyline(sp, _c(OUTLINE), 10.0, true)
	ci.draw_polyline(sp, _c(acc), 5.5, true)
	_vex_blade(ci, Vector2(-14, -22 + step * 2.0), aim.angle() + 2.4 - recoil * 0.6, acc, 0.85)
	limb(ci, Vector2(-10, -36), Vector2(-14, -22 + step * 2.0), 8, 7, prim.darkened(0.12))
	hand(ci, Vector2(-14, -20 + step * 2.0), Vector2(0, 1), Color("2b1f3d"), 4.5)
	legs2(ci, step, 14, 5.5, 11, 7.5, sec, Color("1a1028"), Color("0d0812"), 0.95)
	# tunic with cross wrap and belt
	blob(ci, [Vector2(-13, -12), Vector2(-12, -32), Vector2(-6, -40), Vector2(7, -40), Vector2(13, -32), Vector2(14, -12), Vector2(6, -7), Vector2(0, -10), Vector2(-7, -7)], prim)
	poly(ci, PackedVector2Array([Vector2(-8, -38), Vector2(-4, -38), Vector2(9, -18), Vector2(5, -18)]), prim.darkened(0.25), false)
	blob(ci, [Vector2(-14, -21), Vector2(14, -21), Vector2(14, -17), Vector2(-14, -17)], Color("3a2a4a"), true, 2.0)
	poly(ci, PackedVector2Array([Vector2(-10, -21), Vector2(-5, -21), Vector2(-5, -15), Vector2(-10, -15)]), Color("4a3a5a"), true, 1.8)
	# hooded head: open face with mask
	var hc := Vector2(1, -52)
	blob(ci, [hc + Vector2(-16, 4), hc + Vector2(-16, -10), hc + Vector2(-24, -20 + sin(t * 4.0) * 1.5), hc + Vector2(-6, -18), hc + Vector2(6, -18), hc + Vector2(16, -8), hc + Vector2(16, 6), hc + Vector2(8, 13), hc + Vector2(-8, 13)], prim)
	blob(ci, [hc + Vector2(-8, -5), hc + Vector2(0, -11), hc + Vector2(12, -9), hc + Vector2(14, 1), hc + Vector2(10, 9), hc + Vector2(-4, 9), hc + Vector2(-9, 3)], skin)
	blob(ci, [hc + Vector2(-9, 1), hc + Vector2(14, 0), hc + Vector2(12, 8), hc + Vector2(2, 11), hc + Vector2(-8, 8)], sec.lightened(0.18))
	_eyes(ci, hc + Vector2(1, -4), hc + Vector2(9, -4), 2.8, 2.8, aim, blink, Color("1f8f80"))
	limb(ci, hc + Vector2(-2, -9), hc + Vector2(4, -7), 2.5, 2, sec, false)
	limb(ci, hc + Vector2(7, -7), hc + Vector2(13, -9), 2, 2.5, sec, false)
	ci.draw_arc(hc + Vector2(2, 0), 17.0, -2.3, 1.1, 14, _c(prim.darkened(0.25)), 3.0, true)
	# front arm with blade
	var hp := Vector2(15, -24) + aim * (2.0 + recoil * 8.0)
	limb(ci, Vector2(9, -36), hp, 8, 7, prim)
	_vex_blade(ci, hp + aim * 4.0, aim.angle() - 0.4 + recoil * 1.6, acc, 1.0)
	hand(ci, hp, aim, Color("2b1f3d"), 4.8)

static func _vex_blade(ci: CanvasItem, at: Vector2, ang: float, acc: Color, sc: float) -> void:
	var dir := Vector2.RIGHT.rotated(ang)
	var n := dir.orthogonal()
	glow(ci, at + dir * 14.0 * sc, 10 * sc, acc, 3)
	var blade := spline([at - n * 3 * sc, at + dir * 10 * sc - n * 5 * sc, at + dir * 24 * sc - n * 1 * sc, at + dir * 27 * sc + n * 4 * sc, at + dir * 14 * sc + n * 3 * sc, at + n * 2 * sc])
	poly(ci, blade, acc.lightened(0.25), true, 2.4)
	limb(ci, at - dir * 4 * sc, at + dir * 1 * sc, 4 * sc, 4 * sc, Color("2b1a4d"), true)

# ------------------------------------------------------------------ RIO (skater)
static func _rio(ci: CanvasItem, d: Dictionary, t: float, aim: Vector2, recoil: float, step: float, blink: bool) -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	var hair := Color("3a2416")
	var behind := aim.y < -0.4
	var hp := Vector2(13, -25) - aim * recoil * 5.0
	# backpack, cans and strapped board
	blob(ci, [Vector2(-21, -42), Vector2(-11, -44), Vector2(-9, -16), Vector2(-21, -15)], Color("23232e"), true, 2.4)
	blob(ci, [Vector2(-20, -40), Vector2(-12, -41), Vector2(-11, -18), Vector2(-20, -17)], acc.darkened(0.05), false)
	blob(ci, [Vector2(-17, -38), Vector2(-5, -39), Vector2(-4, -17), Vector2(-16, -16)], sec.darkened(0.15))
	for k in 3:
		var cc: Color = [acc, Color("4fc3ff"), Color("8cff5a")][k]
		limb(ci, Vector2(-15 + k * 4.5, -43), Vector2(-15 + k * 4.5, -36), 4.5, 4.5, cc)
		ci.draw_circle(Vector2(-15 + k * 4.5, -45), 1.6, _c(Color("e6e9f2")))
	if behind:
		_rio_blaster(ci, hp, aim, recoil, acc)
	limb(ci, Vector2(-8, -36), Vector2(-12, -24 + step * 2.0), 8, 7, prim.darkened(0.1))
	hand(ci, Vector2(-12, -21 + step * 2.0), Vector2(0, 1), skin.darkened(0.08), 4.5)
	# legs: skin shins, white socks, chunky sneakers, shorts on top
	legs2(ci, step, 13, 5.5, 10, 6.5, skin, Color("f2f2f6"), Color("c9cfe0"), 1.05, acc)
	for side: float in [-1.0, 1.0]:
		var ank := Vector2(side * 5.5 + step * side * 4.0, -3.0 - maxf(0.0, step * side) * 2.5)
		limb(ci, ank + Vector2(0, -6), ank + Vector2(0, -2), 6.5, 6.5, Color.WHITE, false)
		ci.draw_line(ank + Vector2(-3, -5), ank + Vector2(3, -5), _c(acc), 1.4, true)
	blob(ci, [Vector2(-12, -17), Vector2(12, -17), Vector2(12, -9), Vector2(2, -9), Vector2(0, -12), Vector2(-2, -9), Vector2(-12, -9)], sec)
	# oversized hoodie
	blob(ci, [Vector2(-14, -15), Vector2(-15, -33), Vector2(-8, -41), Vector2(8, -41), Vector2(15, -33), Vector2(15, -15), Vector2(0, -13)], prim)
	blob(ci, [Vector2(-6, -24), Vector2(9, -24), Vector2(10, -17), Vector2(-7, -17)], prim.darkened(0.1), true, 2.0)
	blob(ci, [Vector2(-9, -41), Vector2(0, -38), Vector2(9, -41), Vector2(7, -36), Vector2(0, -34), Vector2(-7, -36)], prim.darkened(0.15), true, 2.0)
	ci.draw_line(Vector2(-2, -35), Vector2(-2, -29), _c(Color.WHITE), 1.4, true)
	ci.draw_line(Vector2(3, -35), Vector2(3, -29), _c(Color.WHITE), 1.4, true)
	blob(ci, [Vector2(-9, -31), Vector2(-5, -33), Vector2(-4, -29), Vector2(-8, -27)], acc, false)
	ci.draw_circle(Vector2(8, -28), 2.0, _c(Color("4fc3ff")))
	# head: curls, ear, face, backwards cap
	var hc := Vector2(1, -53)
	for k in 5:
		circ(ci, hc + Vector2(-13 + k * 1.2, -4 + k * 3.2), 4.2, hair, true, 2.0)
	_ear(ci, hc + Vector2(-9, 2), skin)
	blob(ci, _head_pts(hc, 26, 25), skin)
	blob(ci, [hc + Vector2(-14, -2), hc + Vector2(-12, -12), hc + Vector2(0, -17), hc + Vector2(12, -12), hc + Vector2(14, -4), hc + Vector2(0, -6)], sec)
	blob(ci, [hc + Vector2(-20, -3), hc + Vector2(-13, -6), hc + Vector2(-11, -1), hc + Vector2(-19, 1)], sec.darkened(0.2), true, 2.0)
	ci.draw_circle(hc + Vector2(1, -16), 2.0, _c(acc))
	blob(ci, [hc + Vector2(5, -6), hc + Vector2(9, -7), hc + Vector2(12, -5), hc + Vector2(7, -4)], hair, false)
	_eyes(ci, hc + Vector2(2, 0), hc + Vector2(10, 0), 3.0, 3.5, aim, blink, Color("5a3a1e"))
	limb(ci, hc + Vector2(-1, -5), hc + Vector2(4, -5), 2, 2, hair, false)
	limb(ci, hc + Vector2(8, -5), hc + Vector2(13, -7), 2, 2, hair, false)
	for f in [Vector2(-1, 5), Vector2(1, 6), Vector2(12, 5), Vector2(14, 6)]:
		ci.draw_circle(hc + f, 0.8, _c(skin.darkened(0.35)))
	blob(ci, [hc + Vector2(11, 1), hc + Vector2(14, 3), hc + Vector2(11, 5)], skin.darkened(0.08), false)
	_mouth(ci, hc + Vector2(6, 8), 8.0, 3.0)
	if not behind:
		_rio_blaster(ci, hp, aim, recoil, acc)
	limb(ci, Vector2(8, -37), hp - aim * 3.0, 8, 7, prim)
	hand(ci, hp, aim, skin, 4.8)

static func _rio_blaster(ci: CanvasItem, hp: Vector2, aim: Vector2, recoil: float, acc: Color) -> void:
	var a := aim.angle()
	var n := aim.orthogonal()
	limb(ci, hp + aim * 2.0, hp + aim * 9.0, 9, 9, Color("2b2f3e"))
	limb(ci, hp + aim * 6.0 - n * 3.2, hp + aim * 24.0 - n * 3.2, 6, 6, acc)
	limb(ci, hp + aim * 6.0 + n * 3.2, hp + aim * 24.0 + n * 3.2, 6, 6, Color("4fc3ff"))
	limb(ci, hp + aim * 24.0, hp + aim * 30.0, 4, 3, Color("e6e9f2"))
	ci.draw_circle(hp + aim * 31.0, 2.4 + recoil * 2.0, _c(acc))

# ------------------------------------------------------------------ NOVA (marksman)
static func _nova(ci: CanvasItem, d: Dictionary, t: float, aim: Vector2, recoil: float, step: float, blink: bool) -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	var hair := Color("2a1a14")
	var hp := Vector2(11, -26) - aim * recoil * 6.0
	var behind := aim.y < -0.4
	if behind:
		_nova_rifle(ci, hp, aim, recoil, prim, acc)
	limb(ci, Vector2(-8, -36), Vector2(-4, -27), 8, 7, sec.lightened(0.05))
	legs2(ci, step, 15, 5.5, 12, 7.5, sec.lightened(0.08), acc, Color("8a93a8"), 1.0, prim)
	for side: float in [-1.0, 1.0]:
		var kn := Vector2(side * 5.5 + step * side * 2.0, -9.0)
		blob(ci, [kn + Vector2(-3, -2), kn + Vector2(3, -2), kn + Vector2(3, 2), kn + Vector2(-3, 2)], acc.darkened(0.1), true, 1.8)
	# flight jacket
	blob(ci, [Vector2(-12, -14), Vector2(-13, -34), Vector2(-6, -41), Vector2(7, -41), Vector2(13, -34), Vector2(13, -14), Vector2(0, -12)], sec)
	poly(ci, PackedVector2Array([Vector2(-1.5, -40), Vector2(1.5, -40), Vector2(1.5, -13), Vector2(-1.5, -13)]), prim, false)
	blob(ci, [Vector2(-13, -19), Vector2(13, -19), Vector2(13, -16), Vector2(-13, -16)], Color("3a4766"), true, 2.0)
	blob(ci, [Vector2(-9, -43), Vector2(9, -43), Vector2(8, -38), Vector2(-8, -38)], sec.lightened(0.18), true, 2.0)
	blob(ci, [Vector2(-15, -38), Vector2(-7, -41), Vector2(-6, -35), Vector2(-14, -33)], acc, true, 2.0)
	ci.draw_circle(Vector2(-6, -29), 1.8, _c(prim))
	# ponytail swaying behind
	var sway := sin(t * 5.0) * 2.0
	var hc := Vector2(1, -54)
	blob(ci, [hc + Vector2(-10, -8), hc + Vector2(-18, -6 + sway * 0.3), hc + Vector2(-24, 2 + sway), hc + Vector2(-20, 9 + sway), hc + Vector2(-15, 2), hc + Vector2(-11, -1)], hair)
	_ear(ci, hc + Vector2(-9, 2), skin)
	blob(ci, _head_pts(hc, 26, 25), skin)
	blob(ci, [hc + Vector2(-14, 0), hc + Vector2(-13, -10), hc + Vector2(-2, -16), hc + Vector2(10, -13), hc + Vector2(14, -6), hc + Vector2(6, -8), hc + Vector2(-2, -5), hc + Vector2(-8, -1)], hair)
	# visor with sweeping shine
	blob(ci, [hc + Vector2(-6, -5), hc + Vector2(14, -6), hc + Vector2(15, 1), hc + Vector2(-5, 2)], prim)
	var sx := fmod(t * 0.7, 2.0) * 26.0 - 8.0
	if sx > -5 and sx < 13:
		ci.draw_line(hc + Vector2(sx, -4.5), hc + Vector2(sx + 3, 1), _c(Color(1, 1, 1, 0.85)), 2.0, true)
	if not blink:
		ci.draw_circle(hc + Vector2(2 + aim.x * 1.5, -1.5), 1.8, _c(acc))
		ci.draw_circle(hc + Vector2(10 + aim.x * 1.5, -1.5), 1.8, _c(acc))
	limb(ci, hc + Vector2(-7, -3), hc + Vector2(-11, 2), 3.5, 3.5, Color("3a4766"), true)
	ci.draw_line(hc + Vector2(-8, -6), hc + Vector2(-10, -16), _c(Color("3a4766")), 1.6, true)
	ci.draw_circle(hc + Vector2(-10, -17), 1.8, _c(prim))
	blob(ci, [hc + Vector2(3, 8), hc + Vector2(9, 7), hc + Vector2(8, 9)], Color("5a1a2a"), true, 1.4)
	if not behind:
		_nova_rifle(ci, hp, aim, recoil, prim, acc)
	limb(ci, Vector2(8, -37), hp - aim * 2.0, 8, 7, sec.lightened(0.05))
	hand(ci, hp, aim, Color("3a4766"), 4.8)

static func _nova_rifle(ci: CanvasItem, hp: Vector2, aim: Vector2, recoil: float, prim: Color, acc: Color) -> void:
	var n := aim.orthogonal()
	limb(ci, hp - aim * 8.0 + n * 2.0, hp + aim * 2.0 + n * 2.0, 8, 9, Color("3a4766"))
	limb(ci, hp, hp + aim * 26.0, 9, 8, acc)
	limb(ci, hp + aim * 22.0, hp + aim * 38.0, 4.5, 4, Color("3a4766"))
	limb(ci, hp + aim * 6.0 - n * 6.0, hp + aim * 16.0 - n * 6.0, 5, 5, Color("2b3350"))
	ci.draw_circle(hp + aim * 16.0 - n * 6.0, 1.6, _c(prim))
	for k in 3:
		var q := hp + aim * (25.0 + k * 4.0)
		ci.draw_line(q - n * 3.0, q + n * 3.0, _c(prim), 1.6, true)
	glow(ci, hp + aim * 40.0, 6.0 + recoil * 8.0, prim)

# ------------------------------------------------------------------ MIRA (support)
static func _mira(ci: CanvasItem, d: Dictionary, t: float, aim: Vector2, recoil: float, step: float, blink: bool) -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	var lantern := Vector2(17, -26) + aim * (8.0 + recoil * 8.0) + Vector2(0, sin(t * 3.0) * 1.5)
	var behind := aim.y < -0.4
	var hc := Vector2(1, -52)
	# hair back mass + twin buns (behind everything)
	blob(ci, [hc + Vector2(-17, 8), hc + Vector2(-19, -6), hc + Vector2(-10, -17), hc + Vector2(6, -18), hc + Vector2(17, -8), hc + Vector2(17, 8), hc + Vector2(10, 14), hc + Vector2(-10, 14)], prim.darkened(0.08))
	circ(ci, hc + Vector2(-14, -15), 7.5, prim)
	circ(ci, hc + Vector2(14, -15), 7.5, prim)
	if behind:
		_mira_lantern(ci, lantern, t, acc, recoil)
	limb(ci, Vector2(-7, -34), Vector2(-11, -24 + step * 2.0), 6.5, 5.5, sec.lightened(0.1))
	hand(ci, Vector2(-11, -21 + step * 2.0), Vector2(0, 1), skin, 4.0)
	legs2(ci, step, 12, 4.5, 9, 5.5, Color("f5e8f0"), prim.darkened(0.2), Color("7a2a50"), 0.9)
	# bell dress with apron and frill
	blob(ci, [Vector2(-18, -10), Vector2(-14, -22), Vector2(-8, -36), Vector2(8, -36), Vector2(14, -22), Vector2(18, -10), Vector2(9, -7), Vector2(0, -9), Vector2(-9, -7)], sec)
	blob(ci, [Vector2(-8, -12), Vector2(-6, -28), Vector2(7, -28), Vector2(9, -12), Vector2(0, -10)], Color("fff3f8"), true, 2.0)
	var frill: Array = []
	for k in 9:
		frill.append(Vector2(-18 + k * 4.5, -9 + (2.0 if k % 2 == 0 else -0.5)))
	ci.draw_polyline(spline(frill, false), _c(prim), 3.0, true)
	blob(ci, [Vector2(-5, -36), Vector2(0, -32), Vector2(5, -36), Vector2(4, -31), Vector2(0, -29), Vector2(-4, -31)], acc, true, 1.8)
	# face, bangs, blush
	blob(ci, _head_pts(hc + Vector2(0, 2), 25, 23), skin)
	blob(ci, [hc + Vector2(-14, 2), hc + Vector2(-13, -10), hc + Vector2(-3, -15), hc + Vector2(9, -13), hc + Vector2(15, -4), hc + Vector2(11, -5), hc + Vector2(7, -2), hc + Vector2(3, -6), hc + Vector2(-2, -2), hc + Vector2(-7, -6), hc + Vector2(-10, 0)], prim.lightened(0.05))
	_eyes(ci, hc + Vector2(-2, 2), hc + Vector2(8, 2), 3.4, 4.2, aim, blink, prim.darkened(0.35))
	ell(ci, hc + Vector2(-6, 8), 2.6, 1.4, Color(1, 0.45, 0.55, 0.55), false)
	ell(ci, hc + Vector2(12, 8), 2.6, 1.4, Color(1, 0.45, 0.55, 0.55), false)
	blob(ci, [hc + Vector2(2, 10), hc + Vector2(5, 9.5), hc + Vector2(4, 11.5)], Color("5a1a2a"), true, 1.2)
	if not behind:
		_mira_lantern(ci, lantern, t, acc, recoil)
	limb(ci, Vector2(7, -34), lantern + Vector2(-4, -12), 6.5, 5.5, sec.lightened(0.1))
	hand(ci, lantern + Vector2(-3, -13), Vector2(1, 0.4), skin, 4.0)

static func _mira_lantern(ci: CanvasItem, at: Vector2, t: float, acc: Color, recoil: float) -> void:
	var gold := Color("e0b44a")
	glow(ci, at, 16 + recoil * 10.0 + sin(t * 6.0) * 1.5, acc)
	ci.draw_arc(at + Vector2(0, -12), 4.0, PI, TAU, 8, _c(gold), 2.0, true)
	blob(ci, [at + Vector2(-7, -8), at + Vector2(0, -12), at + Vector2(7, -8)], gold, true, 2.0)
	blob(ci, [at + Vector2(-6, -7), at + Vector2(6, -7), at + Vector2(6, 7), at + Vector2(-6, 7)], Color(acc.r, acc.g, acc.b, 0.9), true, 2.2)
	for k in 2:
		ci.draw_line(at + Vector2(-2 + k * 4, -7), at + Vector2(-2 + k * 4, 7), _c(gold), 1.4, true)
	ell(ci, at + Vector2(0, 1), 2.6, 4.0 + sin(t * 9.0), Color.WHITE, false)
	blob(ci, [at + Vector2(-7, 7), at + Vector2(7, 7), at + Vector2(5, 11), at + Vector2(-5, 11)], gold, true, 2.0)

# ------------------------------------------------------------------ SPRIG (controller)
static func _sprig(ci: CanvasItem, d: Dictionary, t: float, aim: Vector2, recoil: float, step: float, blink: bool) -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	# seed sack with sprouts
	blob(ci, [Vector2(-22, -34), Vector2(-12, -38), Vector2(-8, -18), Vector2(-14, -12), Vector2(-23, -16)], Color("9a6a3e"))
	ci.draw_arc(Vector2(-16, -35), 4.0, PI, TAU, 8, _c(Color("6b4a2a")), 2.5, true)
	for k in 3:
		ci.draw_line(Vector2(-19 + k * 3.5, -37), Vector2(-20 + k * 4.5, -44 - (k % 2) * 3), _c(prim.lightened(0.1)), 2.0, true)
	limb(ci, Vector2(-7, -28), Vector2(-11, -19 + step * 2.0), 6, 5.5, skin.darkened(0.06))
	hand(ci, Vector2(-11, -16 + step * 2.0), Vector2(0, 1), skin.darkened(0.06), 4.0)
	legs2(ci, step, 10, 5, 7, 6, Color("6b4a2a"), Color("5a3a1e"), Color("2a1a10"), 1.1)
	# pot belly in overalls
	blob(ci, [Vector2(-11, -12), Vector2(-12, -24), Vector2(-6, -31), Vector2(6, -31), Vector2(12, -24), Vector2(11, -12), Vector2(0, -9)], skin)
	blob(ci, [Vector2(-11, -12), Vector2(-11, -22), Vector2(11, -22), Vector2(11, -12), Vector2(0, -9)], prim)
	blob(ci, [Vector2(-5, -24), Vector2(5, -24), Vector2(5, -18), Vector2(-5, -18)], prim.darkened(0.12), true, 2.0)
	for sx: float in [-1.0, 1.0]:
		ci.draw_line(Vector2(5 * sx, -22), Vector2(6 * sx, -30), _c(acc), 2.2, true)
		ci.draw_circle(Vector2(5 * sx, -22), 1.4, _c(Color("e6e9f2")))
	# big goblin head with long ears
	var hc := Vector2(1, -45)
	var flap := sin(t * 3.0) * 2.0
	blob(ci, [hc + Vector2(-12, -3), hc + Vector2(-30, -10 + flap), hc + Vector2(-13, 4)], skin)
	blob(ci, [hc + Vector2(-14, -2), hc + Vector2(-25, -7 + flap), hc + Vector2(-14, 2)], Color("ff9fb0"), false)
	blob(ci, [hc + Vector2(12, -3), hc + Vector2(30, -10 - flap), hc + Vector2(13, 4)], skin)
	blob(ci, [hc + Vector2(14, -2), hc + Vector2(25, -7 - flap), hc + Vector2(14, 2)], Color("ff9fb0"), false)
	blob(ci, [hc + Vector2(-17, 0), hc + Vector2(-14, -12), hc + Vector2(0, -16), hc + Vector2(14, -12), hc + Vector2(17, 0), hc + Vector2(13, 10), hc + Vector2(0, 13), hc + Vector2(-13, 10)], skin)
	# sprout
	var sway := sin(t * 3.5) * 0.3
	ci.draw_line(hc + Vector2(0, -15), hc + Vector2(1, -23), _c(sec), 2.5, true)
	blob(ci, _o([Vector2(0, 0), Vector2(-5, -3), Vector2(-9, 0), Vector2(-5, 2)], hc + Vector2(0, -23)), prim, true, 2.0)
	blob(ci, _o([Vector2(0, 0), Vector2(5, -3 - sway * 3.0), Vector2(9, 0), Vector2(5, 2)], hc + Vector2(1, -23)), prim, true, 2.0)
	# goggles on forehead
	blob(ci, [hc + Vector2(-16, -7), hc + Vector2(0, -10), hc + Vector2(16, -7), hc + Vector2(16, -5), hc + Vector2(0, -8), hc + Vector2(-16, -5)], Color("6b3f1f"), false)
	for gx: float in [-5.5, 6.5]:
		circ(ci, hc + Vector2(gx, -9), 4.5, acc, true, 2.2)
		circ(ci, hc + Vector2(gx, -9), 2.8, Color("bff4ff"), false)
		ci.draw_circle(hc + Vector2(gx - 1.2, -10.2), 1.0, _c(Color.WHITE))
	_eyes(ci, hc + Vector2(-5, 1), hc + Vector2(7, 1), 3.6, 4.0, aim, blink, Color("b06a0a"))
	blob(ci, [hc + Vector2(-1, 3), hc + Vector2(3, 2), hc + Vector2(5, 6), hc + Vector2(1, 7)], skin.darkened(0.08), false)
	_mouth(ci, hc + Vector2(1, 9), 10.0, 3.0, false)
	for fx: float in [-2.5, 3.5]:
		poly(ci, PackedVector2Array([hc + Vector2(fx - 1, 9), hc + Vector2(fx + 1, 9), hc + Vector2(fx, 11.5)]), Color.WHITE, false)
	# front hand holding a seed bomb
	var hp := Vector2(12, -21) + aim * (6.0 - recoil * 6.0)
	limb(ci, Vector2(7, -28), hp - aim * 2.0, 6, 5.5, skin)
	circ(ci, hp + aim * 6.0, 5.5, acc)
	ci.draw_circle(hp + aim * 6.0 + Vector2(-1.5, -1.5), 1.6, _c(Color(1, 1, 1, 0.8)))
	hand(ci, hp, aim, skin, 4.2)

# ---------------------------------------------------------------------------
## Draws a stylized projectile for a given visual style.
static func draw_projectile(ci: CanvasItem, style: String, pos: Vector2, dir: Vector2, t: float, team_col: Color, d: Dictionary) -> void:
	var a := dir.angle()
	match style:
		"paint":
			# wobbly paint blob with a trailing splatter
			var pc: Color = d.accent
			var wob := 1.0 + sin(t * 30.0) * 0.12
			for k in 3:
				var back := pos - dir * (10.0 + k * 9.0)
				ci.draw_circle(back, 6.0 - k * 1.6, Color(pc.r, pc.g, pc.b, 0.6 - k * 0.15))
			ci.draw_circle(pos, 13.0 * wob, Color("1a1028"))
			ci.draw_circle(pos, 10.5 * wob, pc)
			ci.draw_circle(pos + Vector2(-3, -4), 3.5, pc.lightened(0.5))
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
