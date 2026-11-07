extends Control
## Test sheet: one brawler in every pose across a few moments in time.
var _t := 0.0
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(d: float) -> void:
	_t += d
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("3b7d4e"))
	var poses := [
		["idle", {"in_match": true}],
		["fidget", {"in_match": true, "t_add": 4.0}],
		["walk", {"in_match": true, "moving": true}],
		["windup", {"in_match": true, "atk": 0.04}],
		["strike", {"in_match": true, "atk": 0.16}],
		["follow", {"in_match": true, "atk": 0.3}],
		["hurt", {"in_match": true, "hurt": 0.2}],
		["super", {"in_match": true, "super_pose": 0.35}],
		["victory", {"moving": true}],
		["defeat", {"blink": true, "alpha": 0.9}],
		["walk down", {"in_match": true, "moving": true, "aim_override": Vector2(0, 1)}],
		["walk up", {"in_match": true, "moving": true, "aim_override": Vector2(0, -1)}],
	]
	for i in poses.size():
		for j in 6:
			var a: Dictionary = poses[i][1].duplicate()
			a["t"] = _t + float(a.get("t_add", 0.0))
			a["aim"] = a.get("aim_override", Vector2(1, 0.2))
			a["skin"] = "crimson" if j == 0 else ""
			BrawlerArt.draw(self, ["gunslinger", "dusty", "nova", "sprig", "bruno", "vex"][j], Vector2(60 + i * 105, 128 + j * 116), 0.78, a)
		draw_string(ThemeDB.fallback_font, Vector2(20 + i * 105, 30), poses[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
