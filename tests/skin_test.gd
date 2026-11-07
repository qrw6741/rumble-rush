extends Control
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("2a8a4a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var i := 0
	for who in [["vex", ""], ["vex", "gold"], ["vex", "shadow"], ["graves", "gold"], ["graves", "frost"], ["dusty", "inferno"], ["rio", "neon"], ["bruno", "polar"]]:
		var c := One.new()
		c.who = who[0]
		c.sk = who[1]
		c.position = Vector2(20 + (i % 4) * 310, 20 + (i / 4) * 350)
		c.size = Vector2(300, 340)
		add_child(c)
		i += 1

class One extends Control:
	var who := "vex"
	var sk := ""
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		BrawlerArt.draw(self, who, Vector2(150, 320), 3.0, {"t": 0.0, "aim": Vector2(1, 0.2), "skin": sk})
		draw_string(UIKit.bold(), Vector2(10, 30), "%s %s" % [who, sk], HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
