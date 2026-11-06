extends Control
## Test sheet: big renders of two brawlers side by side, plus a few poses.
var _t := 0.0
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(d: float) -> void:
	_t += d
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("2b3a6e"))
	for k in 8:
		draw_circle(Vector2(320, 380), 300.0 - k * 30.0, Color(1, 1, 1, 0.025))
		draw_circle(Vector2(960, 380), 300.0 - k * 30.0, Color(1, 1, 1, 0.025))
	var S2 := preload("res://scripts/ui/main_menu.gd").SlantButton
	var ids := ["bront", "bruno"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--duo="):
			ids = Array(a.substr(6).split(","))
	for i in 2:
		var cx := 320.0 + i * 640.0
		draw_set_transform(Vector2.ZERO)
		var sh := PackedVector2Array()
		for k in 24:
			var a := TAU * k / 24.0
			sh.append(Vector2(cx, 560) + Vector2(cos(a) * 130, sin(a) * 28))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.3))
		BrawlerArt.draw(self, ids[i], Vector2(cx, 560), 6.0, {"t": 0.4, "aim": Vector2(1 if i == 0 else -1, 0.25), "no_shadow": true, "vector": true})
		S2.text_c(self, String(Config.BRAWLERS[ids[i]].name), Vector2(cx, 640), 48, Color.WHITE, 12)
		S2.text_c(self, String(Config.BRAWLERS[ids[i]].role), Vector2(cx, 680), 22, Color("ffd23a"))
