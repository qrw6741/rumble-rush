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
		["walk", {"in_match": true, "moving": true}],
		["attack", {"in_match": true, "recoil": 0.9}],
		["hurt", {"in_match": true, "hurt": 0.2}],
		["super", {"in_match": true, "super_pose": 0.35}],
		["victory", {"moving": true}],
		["defeat", {"blink": true, "alpha": 0.9}],
		["walk down", {"in_match": true, "moving": true, "aim_override": Vector2(0, 1)}],
		["walk up", {"in_match": true, "moving": true, "aim_override": Vector2(0, -1)}],
	]
	for i in poses.size():
		for j in 3:
			var a: Dictionary = poses[i][1].duplicate()
			a["t"] = _t + j * 0.13
			a["aim"] = a.get("aim_override", Vector2(1, 0.2))
			BrawlerArt.draw(self, "graves", Vector2(70 + i * 140, 220 + j * 230), 1.6, a)
		draw_string(ThemeDB.fallback_font, Vector2(30 + i * 140, 30), poses[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
