extends Control
## QA: the 2D battle art of every brawler, drawn large.
var t := 0.0
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(d: float) -> void:
	t += d
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("e8c88a"))
	var ids: Array = Config.BRAWLER_ORDER
	for i in ids.size():
		var x := 90 + (i % 7) * 180
		var y := 320 if i < 7 else 680
		BrawlerArt.draw(self, ids[i], Vector2(x, y), 2.9, {"t": t, "aim": Vector2(1, 0.3), "moving": false})
