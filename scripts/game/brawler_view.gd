class_name BrawlerView
extends SubViewport
## Renders one 3D BrawlerModel into a transparent texture that 2D scenes (the
## battle, menus) can display. Each view has its own little 3D world: key light,
## fill light, ambient light and a camera set up for the use case.
##   "battle"   – angled orthographic camera, like a classic top-down arena game
##   "portrait" – front 3/4 perspective close-up for menus and cards

var model: BrawlerModel
var camera: Camera3D
var kind := "battle"
var animated := true
var feet_px := Vector2.ZERO    # where the model's feet land in this texture
var px_scale := 1.0            # actual texture size / requested size (lower on low graphics)
var state := {"t": 0.0, "moving": false, "recoil": 0.0, "yaw": 0.0}
var _t := 0.0

static func create(brawler_id: String, view_kind: String, px: int, live := true, skin := "") -> BrawlerView:
	var v := BrawlerView.new()
	v.kind = view_kind
	v.animated = live
	var low := Save.low_graphics()
	v.px_scale = 0.85 if low else 1.0
	var real_px := maxi(64, int(px * v.px_scale))
	v.size = Vector2i(real_px, real_px)
	v.transparent_bg = true
	v.own_world_3d = true
	if low:
		v.msaa_3d = Viewport.MSAA_DISABLED if view_kind == "battle" else Viewport.MSAA_2X
	else:
		v.msaa_3d = Viewport.MSAA_2X if view_kind == "battle" else Viewport.MSAA_4X
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	v._build(brawler_id, skin)
	return v

func _build(brawler_id: String, skin := "") -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.8, 1.0)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 30, 0)
	key.light_energy = 1.05
	key.light_color = Color(1.0, 0.97, 0.9)
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.55, 0.75, 1.0)
	add_child(fill)
	# soft back/rim light, like a blue studio backdrop bouncing light onto the edges
	var back := DirectionalLight3D.new()
	back.rotation_degrees = Vector3(-15, 180, 0)
	back.light_energy = 0.35
	back.light_color = Color(0.6, 0.85, 1.0)
	add_child(back)

	model = BrawlerModel.new()
	model.outline_width = 0.014 if kind == "battle" else 0.0
	model.build(brawler_id, skin)
	add_child(model)

	camera = Camera3D.new()
	if kind == "battle":
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 3.4
		camera.position = Vector3(0, 4.2, 3.4)
		camera.look_at_from_position(camera.position, Vector3(0, 0.95, 0), Vector3.UP)
	elif kind == "bust":
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 24.0
		camera.position = Vector3(0, 1.45, 2.7)
		camera.look_at_from_position(camera.position, Vector3(0, 1.12, 0), Vector3.UP)
	elif kind == "showcase":
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 26.0
		camera.position = Vector3(0, 1.6, 5.4)
		camera.look_at_from_position(camera.position, Vector3(0, 0.9, 0), Vector3.UP)
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 30.0
		camera.position = Vector3(0, 1.45, 4.7)
		camera.look_at_from_position(camera.position, Vector3(0, 0.95, 0), Vector3.UP)
	add_child(camera)
	camera.current = true
	model.animate(0.0, {"t": 0.0, "yaw": 0.0 if kind == "battle" else 0.35, "instant": true})

func _ready() -> void:
	feet_px = camera.unproject_position(Vector3.ZERO)
	if not animated:
		render_target_update_mode = SubViewport.UPDATE_ONCE

## Drive the animation from outside (battle) ...
func pose(delta: float, moving: bool, recoil: float, yaw: float) -> void:
	_t += delta
	model.animate(delta, {"t": _t, "moving": moving, "recoil": recoil, "yaw": yaw})

## ... or let it idle by itself (menus).
func _process(delta: float) -> void:
	if kind != "battle" and animated:
		_t += delta
		var yaw: float = state.get("yaw", 0.35)
		if not state.get("manual", false):
			yaw += sin(_t * 0.6) * 0.25
		model.animate(delta, {"t": _t, "yaw": yaw, "moving": state.get("moving", false), "recoil": state.get("recoil", 0.0)})

## Converts a 2D aim direction (screen space) to the model's yaw.
static func yaw_from_aim(aim: Vector2) -> float:
	return atan2(aim.x, aim.y)
