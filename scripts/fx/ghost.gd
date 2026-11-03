class_name Ghost
extends Sprite2D
## Fading, tinted after-image left behind by dashes (copies the brawler's current
## rendered 3D pose).

var _t := 0.0
const LIFE := 0.28

static func spawn(parent: Node, b: Brawler) -> void:
	if b.sprite == null:
		return
	var g := Ghost.new()
	# snapshot the current frame so the after-image stays frozen in place
	var img := b.view.get_texture().get_image()
	if img == null:
		return
	g.texture = ImageTexture.create_from_image(img)
	g.centered = false
	g.scale = b.sprite.scale
	g.position = b.global_position + b.sprite.position
	var c: Color = b.d.accent
	g.modulate = Color(c.r * 1.3, c.g * 1.3, c.b * 1.3, 0.5)
	parent.add_child(g)

func _ready() -> void:
	z_index = 4

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	modulate.a = 0.5 * (1.0 - _t / LIFE)
