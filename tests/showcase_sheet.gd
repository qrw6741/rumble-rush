extends Control
## QA: all five brawlers as big menu showcases side by side.
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1f6ad8")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var ids := ["bront", "vex", "nova", "mira", "sprig"]
	for i in ids.size():
		var p := UIKit.BrawlerPortrait.new()
		p.brawler_id = ids[i]
		p.skin = ""
		p.view_kind = "bust"
		p.backdrop = false
		p.art_scale = 1.0
		p.position = Vector2(i * 256, 0)
		p.size = Vector2(256, 720)
		p.custom_minimum_size = p.size
		add_child(p)
