class_name LobShot
extends Node2D
## An arcing throw that flies over walls and resolves when it lands.
## Shows a landing marker on the ground so everyone can read (and dodge) it.

var owner_b: Brawler
var from := Vector2.ZERO
var to := Vector2.ZERO
var flight := 0.6
var style := "seed"
var radius := 60.0
var on_land: Callable
var _t := 0.0

static func spawn(g: Node, b: Brawler, target: Vector2, flight_time: float, vis: String, r: float, cb: Callable) -> LobShot:
	var l := LobShot.new()
	l.owner_b = b
	l.from = b.global_position
	l.to = target
	l.flight = flight_time
	l.style = vis
	l.radius = r
	l.on_land = cb
	l.position = Vector2.ZERO
	g.projectile_layer.add_child(l)
	return l

func _ready() -> void:
	z_index = 6

func _physics_process(delta: float) -> void:
	if owner_b.game.ended:
		queue_free()
		return
	_t += delta
	if _t >= flight:
		if on_land.is_valid():
			on_land.call(to)
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := clampf(_t / flight, 0.0, 1.0)
	var tc: Color = Config.tc(owner_b.team)
	# landing marker
	var m := tc
	m.a = 0.18 + 0.12 * k
	draw_circle(to, radius, m)
	m.a = 0.8
	draw_arc(to, radius, 0, TAU, 40, m, 3.0, true)
	draw_arc(to, radius * k, 0, TAU, 40, Color(1, 1, 1, 0.5), 2.0, true)
	var ground := from.lerp(to, k)
	var h := sin(k * PI) * (90.0 + from.distance_to(to) * 0.12)
	draw_circle(ground, 9.0 * (1.0 - h / 260.0), Color(0, 0, 0, 0.3))
	BrawlerArt.draw_projectile(self, style, ground + Vector2(0, -h - 20), (to - from).normalized(), _t, tc, owner_b.d)
