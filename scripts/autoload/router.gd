extends Node
## Screen router: swaps full-screen states (menu, brawler select, match, results...)
## with a smooth fade transition.

const SCREENS := {
	"menu": "res://scripts/ui/main_menu.gd",
	"select": "res://scripts/ui/brawler_select.gd",
	"match": "res://scripts/game/match.gd",
	"results": "res://scripts/ui/results_screen.gd",
	"profile": "res://scripts/ui/profile_screen.gd",
}

var root_container: Node
var current: Node
var _fade_layer: CanvasLayer
var _fade: ColorRect
var _busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color("0d0a1a")
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_fade_layer.add_child(_fade)

func goto(screen: String, params: Dictionary = {}, instant := false) -> void:
	if _busy:
		return
	_busy = true
	if not instant and current != null:
		_fade.mouse_filter = Control.MOUSE_FILTER_STOP
		var tw := create_tween()
		tw.tween_property(_fade, "modulate:a", 1.0, 0.22)
		await tw.finished
	get_tree().paused = false
	Engine.time_scale = 1.0
	if current and is_instance_valid(current):
		current.queue_free()
		await get_tree().process_frame
	var script: GDScript = load(SCREENS[screen])
	var node: Node = script.new()
	if node.has_method("setup"):
		node.setup(params)
	root_container.add_child(node)
	current = node
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, 0.28)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
