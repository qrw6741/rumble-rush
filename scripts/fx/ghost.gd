class_name Ghost
extends Node2D
## Fading after-image left behind by dashes.

var id := ""
var aim := Vector2.RIGHT
var col := Color.WHITE
var _t := 0.0
const LIFE := 0.28

static func spawn(parent: Node, b: Brawler) -> void:
	var g := Ghost.new()
	g.id = b.id
	g.aim = b.aim_dir
	g.col = b.d.accent
	g.position = b.global_position
	parent.add_child(g)

func _ready() -> void:
	z_index = 4
	modulate = Color(col.r * 1.4, col.g * 1.4, col.b * 1.4, 1.0)

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := 1.0 - _t / LIFE
	BrawlerArt.draw(self, id, Vector2.ZERO, 1.0, {"t": 0.0, "aim": aim, "alpha": 0.45 * k, "flash": 0.6})
