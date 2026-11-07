extends CanvasLayer
## Controller navigation for menus: the left stick / D-pad moves a hand cursor,
## Cross (✕) clicks, Circle (○) goes back, the right stick scrolls.
## Hidden during matches (unless paused) and whenever mouse or touch is used.

var pos := Vector2(640, 360)
var _draw_node: Control
var _down := false
var _back_was := false
var _visible := false
## Testing without hardware: fake stick / Cross values.
static var test_stick := Vector2.ZERO
static var test_cross := false
static var test_mode := false

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_draw_node = Control.new()
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_node.draw.connect(_paint)
	add_child(_draw_node)

func _input(e: InputEvent) -> void:
	if e.has_meta("from_pad"):
		return
	PlayerController.note_input(e)

func _in_match() -> bool:
	return Router.current_name == "match" and not get_tree().paused

func _drop_open() -> bool:
	return not get_tree().get_nodes_in_group("drop_opener").is_empty()

func _process(d: float) -> void:
	var show := (test_mode or PlayerController.pad_active()) and not _in_match() and get_tree().get_nodes_in_group("pad_modal").is_empty() and not _drop_open()
	if show != _visible:
		_visible = show
		_draw_node.queue_redraw()
	if not show:
		return
	var pads := Input.get_connected_joypads()
	var dev: int = pads[0] if not pads.is_empty() else 0
	var v := test_stick + Vector2(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X), Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
	v += Vector2(float(Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT)),
		float(Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP)))
	if v.length() < 0.15:
		v = Vector2.ZERO
	var any_btn := false
	for bi in [JOY_BUTTON_A, JOY_BUTTON_B]:
		any_btn = any_btn or Input.is_joy_button_pressed(dev, bi)
	if v != Vector2.ZERO or any_btn:
		PlayerController.last_pad_time = Time.get_ticks_msec() / 1000.0
	var vs := get_viewport().get_visible_rect().size
	pos += v * v.length() * 900.0 * d
	pos = pos.clamp(Vector2.ZERO, vs)
	var wpos := get_viewport().get_final_transform() * pos
	if v != Vector2.ZERO:
		_send_motion(wpos)
	# Cross = click
	var cross := test_cross or Input.is_joy_button_pressed(dev, JOY_BUTTON_A)
	if cross != _down:
		_down = cross
		_send_click(wpos, cross)
	# Circle = back (acts like ESC / the back arrow)
	var circle := Input.is_joy_button_pressed(dev, JOY_BUTTON_B)
	if circle and not _back_was:
		var k := InputEventKey.new()
		k.keycode = KEY_ESCAPE
		k.physical_keycode = KEY_ESCAPE
		k.pressed = true
		k.set_meta("from_pad", true)
		Input.parse_input_event(k)
		var back: Node = Router.current.find_child("Back", true, false) if Router.current else null
		if back is BaseButton and back.is_visible_in_tree():
			(back as BaseButton).pressed.emit()
	_back_was = circle
	# right stick scrolls
	var sy := Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y)
	var sx := Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X)
	if absf(sy) > 0.4 or absf(sx) > 0.4:
		var w := InputEventMouseButton.new()
		w.button_index = (MOUSE_BUTTON_WHEEL_DOWN if sy > 0 else MOUSE_BUTTON_WHEEL_UP) if absf(sy) >= absf(sx) else (MOUSE_BUTTON_WHEEL_RIGHT if sx > 0 else MOUSE_BUTTON_WHEEL_LEFT)
		w.pressed = true
		w.factor = maxf(absf(sy), absf(sx)) * 0.6
		w.position = wpos
		w.global_position = wpos
		w.set_meta("from_pad", true)
		Input.parse_input_event(w)
	_draw_node.queue_redraw()

func _send_motion(wpos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = wpos
	m.global_position = wpos
	m.set_meta("from_pad", true)
	Input.parse_input_event(m)

func _send_click(wpos: Vector2, pressed: bool) -> void:
	var c := InputEventMouseButton.new()
	c.button_index = MOUSE_BUTTON_LEFT
	c.pressed = pressed
	c.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	c.position = wpos
	c.global_position = wpos
	c.set_meta("from_pad", true)
	Input.parse_input_event(c)

func _paint() -> void:
	if not _visible:
		return
	var p := pos
	var s := 1.0 if not _down else 0.88
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, 34), Vector2(9, 26), Vector2(16, 40), Vector2(23, 37), Vector2(16, 23), Vector2(28, 23)])
	var outl := PackedVector2Array()
	var fill := PackedVector2Array()
	for q in pts:
		outl.append(p + q * s * 1.18 - Vector2(2, 3))
		fill.append(p + q * s)
	_draw_node.draw_colored_polygon(outl, UIKit.DARK)
	_draw_node.draw_colored_polygon(fill, Color("ffd23a"))
	_draw_node.draw_circle(p + Vector2(34, 44), 13, UIKit.DARK)
	_draw_node.draw_circle(p + Vector2(34, 44), 10, Color("3ea2ff"))
	var f := UIKit.bold()
	_draw_node.draw_string(f, p + Vector2(28, 50), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
