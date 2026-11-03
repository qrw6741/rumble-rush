extends Control
## Visual test sheet for the 3D brawler models (portrait + battle views).
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("2a7fd0")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var i := 0
	for id in Config.BRAWLER_ORDER:
		var v := BrawlerView.create(id, "portrait", 256)
		add_child(v)
		var tr := TextureRect.new()
		tr.texture = v.get_texture()
		tr.position = Vector2(i * 256, 0)
		add_child(tr)
		for k in 3:
			var bv := BrawlerView.create(id, "battle", 240)
			add_child(bv)
			var aims := [Vector2.DOWN, Vector2.RIGHT, Vector2(-0.6, -0.8)]
			bv.pose(0.016, k == 1, 0.0, BrawlerView.yaw_from_aim(aims[k]))
			var t2 := TextureRect.new()
			t2.texture = bv.get_texture()
			t2.position = Vector2(i * 256 + (k % 2) * 120 , 260 + (k / 2) * 230)
			t2.scale = Vector2(0.5, 0.5) if k == 2 else Vector2(0.5, 0.5)
			add_child(t2)
		i += 1
