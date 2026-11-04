extends Control
## QA: draws the rank crest for every colour tier.
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1a5fd6"))
	var ranks := [1, 5, 10, 15, 20, 25, 30, 35]
	for i in ranks.size():
		UIKit.draw_rank_badge(self, Vector2(90 + (i % 4) * 300, 180 + (i / 4) * 300), 200.0, ranks[i])
