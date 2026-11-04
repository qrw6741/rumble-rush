extends Control
var t := 0.0
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(d: float) -> void:
	t += d
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("e8c88a"))
	var list := [["dusty", "inferno"], ["graves", "frost"], ["rio", "neon"], ["bruno", "polar"], ["mira", "starlight"], ["bront", "magma"]]
	for i in list.size():
		BrawlerArt.draw(self, list[i][0], Vector2(110 + i * 210, 450), 3.2, {"t": t, "aim": Vector2(1, 0.3), "skin": list[i][1]})
