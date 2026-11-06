extends Control
## Renders one brawler large in several poses (reference sheet).
var who := "sprig"
var _t := 0.0
func setup(p: Dictionary) -> void:
	who = p.get("who", "sprig")
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(d: float) -> void:
	_t += d
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("2a2050"))
	draw_string(UIKit.bold(), Vector2(30, 60), String(Config.BRAWLERS[who].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 48)
	BrawlerArt.draw(self, who, Vector2(250, 600), 5.2, {"t": 0.3, "aim": Vector2(1, 0.2), "no_shadow": true})
	var poses := [["walk", {"moving": true, "aim": Vector2(1, 0.1)}], ["attack", {"recoil": 0.9, "aim": Vector2(1, 0)}], ["front", {"aim": Vector2(0.1, 1)}], ["back", {"aim": Vector2(0.1, -1)}]]
	for i in poses.size():
		var a: Dictionary = poses[i][1].duplicate()
		a["t"] = 0.25
		a["no_shadow"] = true
		var x := 560 + (i % 2) * 340
		var y := 330 + (i / 2) * 330
		BrawlerArt.draw(self, who, Vector2(x + 120, y), 2.6, a)
		draw_string(UIKit.bold(), Vector2(x + 60, y + 34), poses[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
