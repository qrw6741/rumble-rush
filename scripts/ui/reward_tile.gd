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
		UIKit.draw_icon(self, "lock", Vector2(w - 22, 24), 40.0)
	elif state == "claimed":
		draw_rect(Rect2(4, 4, w - 8, h - 8), Color(0.05, 0.1, 0.05, 0.35))
		UIKit.draw_icon(self, "check", Vector2(w * 0.5, h * 0.42), min(w, h) * 0.55)
	elif state == "claimable":
		Lobby.SlantButton.text_c(self, "CLAIM!", Vector2(w * 0.5, 24), 16, Color("ffe14d"))

static func short_text(r: Dictionary) -> String:
	match r.get("type", ""):
		"credits": return "%d" % r.amount
		"tokens": return "%d TOKENS" % r.amount
		"xp": return "%d XP" % r.amount
		"skin": return "%s SKIN" % Progression.SKINS[r.skin].name
		"gems": return "%d" % r.amount
		"brawler": return Config.BRAWLERS[r.brawler].name
		"drop": return "%s DROP" % Progression.DROP_TIERS[int(r.get("tier", 0))].name
	return ""

static func draw_icon(ci: CanvasItem, r: Dictionary, c: Vector2, s: float) -> void:
	match r.get("type", ""):
		"credits":
			var amt: int = r.get("amount", 0)
			var n := 1 if amt < 50 else (2 if amt < 150 else 3)
			for k in n:
				UIKit.draw_icon(ci, "coin", c + Vector2((k - (n - 1) * 0.5) * s * 0.55, -k * s * 0.12), s * 1.7)
		"tokens":
			UIKit.draw_icon(ci, "token", c, s * 2.0)
		"gems":
			UIKit.draw_icon(ci, "gem", c, s * 1.9)
		"brawler":
			var pc: Color = Config.BRAWLERS[r.brawler].primary
			ci.draw_circle(c, s * 1.05, Color("1a1028"))
			ci.draw_circle(c, s * 0.95, pc.darkened(0.3))
			BrawlerArt.draw(ci, r.brawler, c + Vector2(0, s * 0.95), s / 38.0, {"t": Time.get_ticks_msec() / 1000.0, "aim": Vector2(1, 0.2), "no_shadow": true})
		"drop":
			var dc: Color = Progression.DROP_TIERS[int(r.get("tier", 0))].color
			UIKit.draw_icon(ci, "drop", c, s * 2.0, dc.lerp(Color.WHITE, 0.45))
		"xp":
			UIKit.draw_icon(ci, "xp", c, s * 2.0)
		"skin":
			var pal := Progression.palette(r.brawler, r.skin)
			UIKit.draw_icon(ci, "skin", c, s * 2.0, pal.primary.lerp(Color.WHITE, 0.35))
			preload("res://scripts/ui/main_menu.gd").SlantButton.text_c(ci, Config.BRAWLERS[r.brawler].name, c + Vector2(0, s * 1.25), int(s * 0.42), Color.WHITE)


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
