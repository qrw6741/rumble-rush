class_name RewardTile
extends Button
## One reward box on the Rush Pass, Trophy Road or Rank list.
## state: "locked" | "claimable" | "claimed"

const Lobby := preload("res://scripts/ui/main_menu.gd")

var reward: Dictionary = {}
var state := "locked"
var frame := Color("27334d")
var _t := 0.0

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	text = ""
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	pivot_offset = size * 0.5
	mouse_entered.connect(func(): if state == "claimable": UIKit._pop(self, 1.06))
	mouse_exited.connect(func(): UIKit._pop(self, 1.0))

func _process(delta: float) -> void:
	_t += delta
	if state == "claimable":
		queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var ink := UIKit.DARK
	var bg := frame
	if state == "locked":
		bg = frame.darkened(0.35)
	elif state == "claimable":
		bg = frame.lerp(Color("ffd23a"), 0.25 + 0.15 * sin(_t * 6.0))
	draw_rect(Rect2(3, 6, w, h), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(0, 0, w, h), ink)
	draw_rect(Rect2(4, 4, w - 8, h - 8), bg)
	draw_rect(Rect2(4, 4, w - 8, 6), bg.lightened(0.18))
	var c := Vector2(w * 0.5, h * 0.42)
	draw_icon(self, reward, c, min(w, h) * 0.26)
	var label := short_text(reward)
	Lobby.SlantButton.text_c(self, label, Vector2(w * 0.5, h - 12), 15 if label.length() < 9 else 12, Color.WHITE)
	if state == "locked":
		draw_rect(Rect2(4, 4, w - 8, h - 8), Color(0.05, 0.05, 0.1, 0.45))
		# padlock
		var lp := Vector2(w - 20, 20)
		draw_arc(lp + Vector2(0, -4), 6, PI, TAU, 10, ink, 6.0, true)
		draw_arc(lp + Vector2(0, -4), 6, PI, TAU, 10, Color("c9d0de"), 3.0, true)
		draw_rect(Rect2(lp + Vector2(-9, -3), Vector2(18, 14)), ink)
		draw_rect(Rect2(lp + Vector2(-7, -1), Vector2(14, 10)), Color("c9d0de"))
	elif state == "claimed":
		draw_rect(Rect2(4, 4, w - 8, h - 8), Color(0.05, 0.1, 0.05, 0.35))
		var ck := PackedVector2Array([Vector2(w * 0.3, h * 0.45), Vector2(w * 0.45, h * 0.6), Vector2(w * 0.72, h * 0.3)])
		draw_polyline(ck, ink, 14.0, true)
		draw_polyline(ck, Color("4dff7a"), 8.0, true)
	elif state == "claimable":
		Lobby.SlantButton.text_c(self, "CLAIM!", Vector2(w * 0.5, 24), 16, Color("ffe14d"))

static func short_text(r: Dictionary) -> String:
	match r.get("type", ""):
		"credits": return "%d" % r.amount
		"tokens": return "%d TOKENS" % r.amount
		"xp": return "%d XP" % r.amount
		"skin": return "%s SKIN" % Progression.SKINS[r.skin].name
	return ""

static func draw_icon(ci: CanvasItem, r: Dictionary, c: Vector2, s: float) -> void:
	var ink := UIKit.DARK
	match r.get("type", ""):
		"credits":
			for i in 3:
				Lobby.SlantButton.coin(ci, c + Vector2(-s * 0.35 + i * s * 0.35, s * 0.15 - i * s * 0.12), s * 0.5)
		"tokens":
			var pts := PackedVector2Array()
			for i in 6:
				var a := -PI / 2 + i * TAU / 6
				pts.append(c + Vector2(cos(a), sin(a)) * s)
			ci.draw_colored_polygon(pts, ink)
			var inner := PackedVector2Array()
			for i in 6:
				var a := -PI / 2 + i * TAU / 6
				inner.append(c + Vector2(cos(a), sin(a)) * s * 0.82)
			ci.draw_colored_polygon(inner, Color("3ea2ff"))
			Lobby.SlantButton.star(ci, c, s * 0.5)
		"xp":
			ci.draw_circle(c, s, ink)
			ci.draw_circle(c, s * 0.84, Color("4fd36a"))
			Lobby.SlantButton.text_c(ci, "XP", c + Vector2(0, s * 0.3), int(s * 0.8), Color.WHITE)
		"skin":
			var pal := Progression.palette(r.brawler, r.skin)
			var shirt := PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.8), c + Vector2(-s * 0.15, -s * 0.6), c + Vector2(s * 0.15, -s * 0.6), c + Vector2(s * 0.4, -s * 0.8), c + Vector2(s, -s * 0.35), c + Vector2(s * 0.7, -s * 0.05), c + Vector2(s * 0.55, -s * 0.2), c + Vector2(s * 0.55, s * 0.8), c + Vector2(-s * 0.55, s * 0.8), c + Vector2(-s * 0.55, -s * 0.2), c + Vector2(-s * 0.7, -s * 0.05), c + Vector2(-s, -s * 0.35)])
			ci.draw_colored_polygon(shirt, pal.primary)
			var o := shirt.duplicate()
			o.append(shirt[0])
			ci.draw_polyline(o, ink, 4.0, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.55, s * 0.1), Vector2(s * 1.1, s * 0.18)), pal.accent)
			Lobby.SlantButton.text_c(ci, Config.BRAWLERS[r.brawler].name, c + Vector2(0, s * 1.25), int(s * 0.42), Color.WHITE)


## Small red notification bubble with a count.
class Dot extends Control:
	var count := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(36, 36)
		size = Vector2(36, 36)

	func _draw() -> void:
		if count <= 0:
			return
		var c := size * 0.5
		draw_circle(c, 17, UIKit.DARK)
		draw_circle(c, 14, Color("ff3b3b"))
		Lobby.SlantButton.text_c(self, str(count), c + Vector2(0, 7), 18, Color.WHITE)
