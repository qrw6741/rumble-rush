class_name PlayerController
extends Node
## Turns keyboard/mouse or touch input into brawler intentions.
## PC: WASD move, mouse aim, LMB attack (hold to keep firing), RMB/Q gadget,
## SPACE/E super (hold to preview, release to fire). Mobile: see TouchControls.

const T := 48.0

var b: Brawler
var game: Node
var touch: Node = null # TouchControls when on a touch device

# aim-preview state read by AimIndicator
var preview_mode := "" # "", "attack", "super"
var preview_dir := Vector2.RIGHT
var preview_dist := -1.0
var preview_strength := 0.0
var _super_hold := false
var _attack_queued := false

static func ensure_input_actions() -> void:
	var defs := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"super": [KEY_SPACE, KEY_E], "gadget": [KEY_Q, KEY_SHIFT], "pause": [KEY_ESCAPE, KEY_P],
	}
	for action in defs.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
			for k in defs[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(action, ev)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", mb)
	var gm := InputEventMouseButton.new()
	gm.button_index = MOUSE_BUTTON_RIGHT
	if not InputMap.action_has_event("gadget", gm):
		InputMap.action_add_event("gadget", gm)
	# gamepad: Options button pauses
	var pb := InputEventJoypadButton.new()
	pb.button_index = JOY_BUTTON_START
	if not InputMap.action_has_event("pause", pb):
		InputMap.action_add_event("pause", pb)
	# gamepad support comes for free
	_add_joy("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy("move_down", JOY_AXIS_LEFT_Y, 1.0)

static func _add_joy(action: String, axis: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = v
	if not InputMap.action_has_event(action, e):
		InputMap.action_add_event(action, e)

func setup(brawler: Brawler, g: Node) -> void:
	b = brawler
	game = g

func using_touch() -> bool:
	return touch != null and touch.visible

func tick(_delta: float) -> void:
	if not game.is_playing() or not b.alive:
		b.move_input = Vector2.ZERO
		preview_mode = ""
		return
	if pad_active():
		_tick_pad()
	elif using_touch():
		_tick_touch()
	else:
		_tick_mouse()

func _tick_mouse() -> void:
	b.move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var mouse: Vector2 = game.get_global_mouse_position()
	var v := mouse - b.global_position
	if v.length() < 4.0:
		v = b.aim_dir * 10.0
	var dir := v.normalized()
	if Save.setting("aim_assist"):
		dir = _assist(dir, v.length())
	b.aim_dir = dir
	preview_dir = dir
	preview_dist = v.length()
	# super: hold to preview, release to cast
	if Input.is_action_pressed("super") and b.super_charge >= 1.0:
		_super_hold = true
		preview_mode = "super"
		preview_strength = 1.0
	elif _super_hold:
		_super_hold = false
		b.try_super(dir, v.length())
		preview_mode = ""
	else:
		preview_mode = "attack"
		preview_strength = 1.0 if Input.is_action_pressed("attack") else 0.45
	if Input.is_action_just_pressed("attack"):
		_attack_queued = true
	if (Input.is_action_pressed("attack") or _attack_queued) and not _super_hold:
		if b.try_attack(dir, v.length()):
			_attack_queued = false
		elif b.ammo < 1.0:
			_attack_queued = false
	if Input.is_action_just_pressed("gadget"):
		b.try_gadget(dir)

# ------------------------------------------------------------------ PS5 / gamepad
## Left stick move · right stick aim · R2 attack (hold = keep firing; no aim = auto-aim)
## L2 super (hold to aim, release to fire) · R1 / L1 / Square gadget · Options pause.
static var last_pad_time := -100.0
static var last_mouse_time := 0.0

static func pad_active() -> bool:
	if Input.get_connected_joypads().is_empty():
		return false
	return last_pad_time >= last_mouse_time

static func note_input(e: InputEvent) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if e is InputEventJoypadButton or (e is InputEventJoypadMotion and absf(e.axis_value) > 0.4):
		last_pad_time = now
	elif e is InputEventMouseButton or (e is InputEventMouseMotion and e.relative.length() > 3.0) or e is InputEventKey or e is InputEventScreenTouch:
		if now - last_pad_time > 0.4:  # ignore the cursor's own synthetic clicks
			last_mouse_time = now

func _pad() -> int:
	var pads := Input.get_connected_joypads()
	return pads[0] if not pads.is_empty() else 0

var _pad_super_was := false
var _pad_gadget_was := false

func _tick_pad() -> void:
	var dev := _pad()
	if touch and touch.visible:
		touch.visible = false
	var mv := Vector2(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X), Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
	b.move_input = mv if mv.length() > 0.18 else Vector2.ZERO
	if b.move_input.length() > 1.0:
		b.move_input = b.move_input.normalized()
	var aim := Vector2(Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X), Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y))
	var aiming := aim.length() > 0.25
	var fire := Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > 0.4
	var sup := Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > 0.4
	var gad := Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER) or Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER) or Input.is_joy_button_pressed(dev, JOY_BUTTON_X)
	var dir := b.aim_dir
	var target := _nearest_enemy(b.super_range_px() if sup else b.attack_range_px())
	if aiming:
		dir = aim.normalized()
		if Save.setting("aim_assist"):
			dir = _assist(dir, b.attack_range_px())
	elif target:
		dir = (target.global_position - b.global_position).normalized()
	elif b.move_input.length() > 0.2:
		dir = b.move_input.normalized()
	b.aim_dir = dir
	preview_dir = dir
	var rng := b.super_range_px() if sup else b.attack_range_px()
	preview_dist = clampf(aim.length(), 0.0, 1.0) * rng if aiming else (b.global_position.distance_to(target.global_position) if target else rng)
	if sup and b.super_charge >= 1.0:
		_pad_super_was = true
		preview_mode = "super"
		preview_strength = 1.0
	elif _pad_super_was:
		_pad_super_was = false
		b.try_super(dir, preview_dist)
		preview_mode = ""
	else:
		preview_mode = "attack" if (aiming or fire) else ""
		preview_strength = 1.0 if fire else 0.45
		if fire:
			b.try_attack(dir, preview_dist)
	if gad and not _pad_gadget_was:
		b.try_gadget(dir)
	_pad_gadget_was = gad

func _nearest_enemy(max_range: float) -> Brawler:
	var best: Brawler = null
	var bd := max_range * 1.05
	for e: Brawler in game.brawlers:
		if e.alive and e.team != b.team and not e.hidden_from(b.team):
			var d := e.global_position.distance_to(b.global_position)
			if d < bd:
				bd = d
				best = e
	return best

## Light aim assist: if an enemy is close to the cursor direction, snap to it.
func _assist(dir: Vector2, _dist: float) -> Vector2:
	var best := dir
	var best_ang := deg_to_rad(9.0)
	for e: Brawler in game.brawlers:
		if e.alive and e.team != b.team and not e.hidden_from(b.team):
			var to := e.global_position - b.global_position
			if to.length() > b.attack_range_px() * 1.1:
				continue
			var ang := absf(dir.angle_to(to))
			if ang < best_ang:
				best_ang = ang
				best = to.normalized()
	return best

func _tick_touch() -> void:
	b.move_input = touch.move_vec
	var ap: Vector2 = touch.attack_vec
	var sp: Vector2 = touch.super_vec
	if touch.super_active and sp.length() > touch.DEADZONE:
		preview_mode = "super"
		preview_dir = sp.normalized()
		preview_dist = _stick_to_dist(sp, b.super_range_px())
		preview_strength = 1.0
		b.aim_dir = preview_dir
	elif touch.attack_active and ap.length() > touch.DEADZONE:
		preview_mode = "attack"
		preview_dir = ap.normalized()
		preview_dist = _stick_to_dist(ap, b.attack_range_px())
		preview_strength = 1.0
		b.aim_dir = preview_dir
	else:
		preview_mode = ""
		if b.move_input.length() > 0.2:
			b.aim_dir = b.aim_dir.lerp(b.move_input.normalized(), 0.25).normalized()

func _stick_to_dist(v: Vector2, max_range: float) -> float:
	return clampf(v.length() / touch.STICK_R, 0.0, 1.0) * max_range

# -- called by TouchControls on release
func touch_attack(v: Vector2) -> void:
	if v.length() <= touch.DEADZONE:
		_auto(false)
	else:
		b.try_attack(v.normalized(), _stick_to_dist(v, b.attack_range_px()))

func touch_super(v: Vector2) -> void:
	if v.length() <= touch.DEADZONE:
		_auto(true)
	else:
		b.try_super(v.normalized(), _stick_to_dist(v, b.super_range_px()))

func touch_gadget() -> void:
	b.try_gadget(b.aim_dir)

## Quick-tap: auto-aim at the nearest visible enemy (or straight ahead).
func _auto(is_super: bool) -> void:
	var rng := b.super_range_px() if is_super else b.attack_range_px()
	var best: Brawler = null
	var best_d := rng * 1.05
	for e: Brawler in game.brawlers:
		if e.alive and e.team != b.team and not e.hidden_from(b.team):
			var dd := e.global_position.distance_to(b.global_position)
			if dd < best_d:
				best_d = dd
				best = e
	var dir := b.aim_dir
	var dist := rng
	if best:
		var lead := best.velocity * 0.15
		var to := best.global_position + lead - b.global_position
		dir = to.normalized()
		dist = to.length()
	if is_super:
		b.try_super(dir, dist)
	else:
		b.try_attack(dir, dist)
