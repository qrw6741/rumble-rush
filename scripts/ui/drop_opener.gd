class_name DropOpener
extends Control
## Full-screen reward pod opening. Tap to crack it: the pod climbs through the
## rarity colours up to what you rolled, bursts, and shows the prize.
## Opens every drop waiting in Save.data.drops, one after another.

signal finished

const S := preload("res://scripts/ui/main_menu.gd").SlantButton

var _prize: Dictionary = {}
var _phase := "idle" # idle -> charging -> reveal
var _t := 0.0
var _shown_rarity := 0
var _pod_col := Color("8e4dff")
var _shake := 0.0
var _tap_lock := 0.0
var _opened := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	_next()

func _next() -> void:
	if Save.data.drops.is_empty():
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.2)
		await tw.finished
		finished.emit()
		queue_free()
		return
	var tier: int = Save.data.drops[0]
	_pod_col = Progression.DROP_TIERS[tier].color
	_prize = Save.open_next_drop()
	_opened += 1
	_phase = "idle"
	_t = 0.0
	_shown_rarity = 0
	_tap_lock = 0.25
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
	if not tap or _tap_lock > 0.0:
		return
	accept_event()
	_tap_lock = 0.3
	match _phase:
		"idle":
			_phase = "charging"
			_t = 0.0
			Sfx.play("ui_click")
		"charging":
			pass
		"reveal":
			_next()

func _process(delta: float) -> void:
	_t += delta
	_tap_lock = maxf(0.0, _tap_lock - delta)
	_shake = maxf(0.0, _shake - delta * 3.0)
	if _phase == "charging":
		# step up one rarity every 0.55 s until the rolled one, then burst
		var target: int = int(_prize.get("rarity", 0))
		var step := int(_t / 0.55)
		if step > _shown_rarity and _shown_rarity < target:
			_shown_rarity += 1
			_shake = 1.0
			Sfx.play("gem_pickup", 0.0, 0.1 * _shown_rarity)
			FX.burst(self, size * 0.5, Progression.RARITIES[_shown_rarity].color, 18, 420.0, 0.6, 7.0)
		elif _t > 0.55 * (target + 1) + 0.25:
			_phase = "reveal"
			_t = 0.0
			Sfx.play("super_ready")
			FX.burst(self, size * 0.5, Progression.RARITIES[target].color, 46, 700.0, 0.9, 9.0)
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.08, 0.88))
	var rc: Color = Progression.RARITIES[_shown_rarity].color
	# rotating light rays
	var rays := 14
	for i in rays:
		var a := _t * 0.4 + i * TAU / rays
		var p1 := c + Vector2.from_angle(a - 0.08) * 900.0
		var p2 := c + Vector2.from_angle(a + 0.08) * 900.0
		draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(rc.r, rc.g, rc.b, 0.08 if _phase != "reveal" else 0.16))
	if _phase != "reveal":
		var bob := sin(_t * 3.0) * 10.0
		var sh := Vector2(sin(_t * 70.0), cos(_t * 63.0)) * 10.0 * _shake
		var squash := 1.0 + 0.06 * sin(_t * 6.0)
		var pc := c + Vector2(0, bob) + sh
		var col := _pod_col if _phase == "idle" else _pod_col.lerp(rc, 0.75)
		draw_circle(pc + Vector2(0, 150), 90.0 * squash, Color(0, 0, 0, 0.3))
		UIKit.draw_icon(self, "drop", pc, 300.0 * Vector2(1.0 / squash, squash).x, col.lerp(Color.WHITE, 0.4))
		var txt: String = "TAP TO OPEN!" if _phase == "idle" else Progression.RARITIES[_shown_rarity].name
		S.text_c(self, txt, c + Vector2(0, 230), 40, Color.WHITE if _phase == "idle" else rc, 8)
		var left: int = Save.data.drops.size()
		if left > 0:
			S.text_c(self, "+%d MORE" % left, c + Vector2(0, -210), 24, UIKit.YELLOW, 6)
	else:
		var k := clampf(_t / 0.25, 0.0, 1.0)
		var sc := lerpf(0.3, 1.0, ease(k, -2.0)) + 0.03 * sin(_t * 4.0)
		var rar: Dictionary = Progression.RARITIES[int(_prize.get("rarity", 0))]
		S.text_c(self, rar.name, c + Vector2(0, -200), 46, rar.color, 9)
		RewardTile.draw_icon(self, _prize, c + Vector2(0, -10), 110.0 * sc)
		S.text_c(self, Progression.reward_text(_prize), c + Vector2(0, 190), 38, Color.WHITE, 8)
		if _t > 0.5:
			S.text_c(self, "TAP TO CONTINUE", c + Vector2(0, 250), 22, Color(1, 1, 1, 0.6 + 0.4 * sin(_t * 4.0)), 5)
