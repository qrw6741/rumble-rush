class_name Brawler
extends CharacterBody2D
## A brawler in battle. Owns health, ammo, reload, super charge, gadget cooldown,
## status effects and movement. A controller (player input or bot brain) feeds it
## move/aim intentions; abilities live in Abilities.

const BODY_OFFSET := Vector2(0, -32) # visual centre of the body above the feet

var id := ""
var d: Dictionary
var team := 0
var is_player := false
var is_bot := true
var display_name := ""
var level := 1
var game: Node # Match
var controller: Node

# core stats
var max_hp := 3000.0
var hp := 3000.0
var speed := 230.0
var dmg_mult := 1.0
var max_ammo := 3
var ammo := 3.0
var reload_time := 1.5
var radius := 22.0
var super_charge := 0.0
var gadget_cd := 0.0
var gadget_max_cd := 12.0
var has_gadget := true

# state
var alive := true
var respawn_t := 0.0
var protect_t := 0.0
var regen_block := 0.0
var reveal_t := 0.0
var stun_t := 0.0
var root_t := 0.0
var slow_t := 0.0
var slow_amt := 0.0
var shield_t := 0.0
var invis_t := 0.0
var attack_cd := 0.0
var busy_t := 0.0
var gems := 0
var power_cells := 0
var spawn_pos := Vector2.ZERO

# movement overrides
var dash_t := 0.0
var dash_vel := Vector2.ZERO
var dash_hit: Dictionary = {}
var leap_t := 0.0
var leap_total := 0.0
var leap_from := Vector2.ZERO
var leap_to := Vector2.ZERO
var air_h := 0.0
var knock_vel := Vector2.ZERO
var beam_charge_t := 0.0
var beam_dir := Vector2.RIGHT

# controls
var move_input := Vector2.ZERO
var aim_dir := Vector2.RIGHT

# visuals
var anim_t := 0.0
var flash := 0.0
var recoil := 0.0
var hurt_t := 0.0
var atk_age := 9.0  # seconds since the last basic attack
var super_pose_t := 0.0
var blink_t := 2.0
var _moving := false
var _ghost_t := 0.0
var overhead: Node2D
var view: BrawlerView
var sprite: Sprite2D
var bank = null        # baked sprite frames (SpriteBank) once ready
var skin := ""
var _yaw := 0.0
const VIEW_PX := 320
const SPRITE_SCALE := 0.48 # world px per texture px at VIEW_PX
var flat := false
var _walk_vel := Vector2.ZERO
const FLASH_SHADER := preload("res://assets/shaders/sprite_flash.gdshader")

var stats := {"kos": 0, "deaths": 0, "damage": 0, "healing": 0, "gems": 0}

func setup(brawler_id: String, team_id: int, player: bool, name_text: String, lvl: int, g: Node) -> void:
	id = brawler_id
	d = Config.BRAWLERS[id]
	team = team_id
	is_player = player
	is_bot = not player
	display_name = name_text
	level = lvl
	game = g
	var m := Config.level_mult(level)
	max_hp = d.health * m
	hp = max_hp
	dmg_mult = m
	speed = d.speed
	max_ammo = d.ammo
	ammo = max_ammo
	reload_time = d.reload
	radius = d.radius
	gadget_max_cd = d.gadget.cooldown
	gadget_cd = 3.0 # short lock at match start
	# gadgets must be bought at power 6; bots get theirs from power 6
	has_gadget = Save.has_gadget(id) if player else level >= Config.GADGET_LEVEL

func _ready_rest() -> void:
	overhead = BrawlerOverhead.new()
	overhead.b = self
	add_child(overhead)
	anim_t = randf() * 10.0

# ------------------------------------------------------------------ main loop
func _ready() -> void:
	add_to_group("brawlers")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 1 | 2
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius * 0.72
	cs.shape = shape
	add_child(cs)
	skin = Save.selected_skin(id) if is_player else ""
	# 2D gameplay view: flat vector art drawn in _draw (much cheaper, very smooth)
	flat = Save.setting("view_mode") == "2d"
	if flat:
		var st := BrawlerStatus.new()
		st.b = self
		add_child(st)
		_ready_rest()
		return
	# 3D model rendered into a texture and shown as a sprite
	# bots render slightly smaller on phones so every brawler can animate every frame
	var vpx := VIEW_PX if (is_player or not Save.low_graphics()) else int(VIEW_PX * 0.9)
	view = BrawlerView.create(id, "battle", vpx, true, skin)
	add_child(view)
	sprite = Sprite2D.new()
	sprite.texture = view.get_texture()
	sprite.centered = false
	sprite.scale = Vector2.ONE * SPRITE_SCALE * VIEW_PX / float(view.size.x)
	var sm := ShaderMaterial.new()
	sm.shader = FLASH_SHADER
	sprite.material = sm
	add_child(sprite)
	_update_sprite(0.0)
	var status := BrawlerStatus.new()
	status.b = self
	add_child(status)
	_ready_rest()

func _physics_process(delta: float) -> void:
	anim_t += delta
	flash = max(0.0, flash - delta * 7.0)
	recoil = max(0.0, recoil - delta * 4.5)
	hurt_t = max(0.0, hurt_t - delta)
	atk_age += delta
	super_pose_t = max(0.0, super_pose_t - delta)
	blink_t -= delta
	if blink_t < -0.12:
		blink_t = randf_range(2.0, 4.5)
	if not alive:
		return
	if controller:
		controller.tick(delta)

	# timers
	protect_t = max(0.0, protect_t - delta)
	reveal_t = max(0.0, reveal_t - delta)
	stun_t = max(0.0, stun_t - delta)
	root_t = max(0.0, root_t - delta)
	slow_t = max(0.0, slow_t - delta)
	shield_t = max(0.0, shield_t - delta)
	invis_t = max(0.0, invis_t - delta)
	attack_cd = max(0.0, attack_cd - delta)
	busy_t = max(0.0, busy_t - delta)
	gadget_cd = max(0.0, gadget_cd - delta)

	# reload
	if ammo < max_ammo:
		ammo = min(float(max_ammo), ammo + delta / reload_time)

	# regeneration
	regen_block += delta
	if regen_block >= Config.REGEN_DELAY and hp < max_hp:
		hp = min(max_hp, hp + max_hp * Config.REGEN_PERCENT_PER_SEC * delta)

	# beam charge (Nova super)
	if beam_charge_t > 0.0:
		beam_charge_t -= delta
		if beam_charge_t <= 0.0:
			Abilities.fire_beam(self, beam_dir)

	# movement
	if leap_t > 0.0:
		_update_leap(delta)
	elif dash_t > 0.0:
		_update_dash(delta)
	else:
		var v := Vector2.ZERO
		if stun_t <= 0.0 and root_t <= 0.0 and beam_charge_t <= 0.0:
			var mv := move_input.limit_length(1.0)
			var spd := speed * (1.0 - (slow_amt if slow_t > 0.0 else 0.0))
			v = mv * spd
		# very short ramp (~0.06 s) so starts, stops and turns feel smooth but still snappy
		_walk_vel = _walk_vel.move_toward(v, speed * 16.0 * delta)
		velocity = _walk_vel + knock_vel
		move_and_slide()
	knock_vel = knock_vel.move_toward(Vector2.ZERO, 2200.0 * delta)
	_moving = velocity.length() > 30.0 and leap_t <= 0.0
	if game.ended:
		move_input = Vector2.ZERO
	_update_sprite(delta)
	# 2D view: only spend time redrawing brawlers the camera can actually see
	if not flat or _on_screen():
		queue_redraw()

## Swap the live 3D render for pre-rendered frames (much cheaper).
func use_bank(set: Dictionary) -> void:
	bank = set
	if view:
		view.queue_free()
		view = null
	_update_sprite(0.0)

func _update_sprite(delta: float) -> void:
	if flat:
		return
	_yaw = lerp_angle(_yaw, BrawlerView.yaw_from_aim(aim_dir), clampf(delta * 16.0, 0.0, 1.0)) if delta > 0.0 else BrawlerView.yaw_from_aim(aim_dir)
	if bank != null:
		sprite.texture = SpriteBank.frame_for(bank, _yaw, _moving, recoil, anim_t)
		sprite.scale = Vector2.ONE * SPRITE_SCALE * VIEW_PX / float(sprite.texture.get_width())
		sprite.position = -Vector2(bank.feet) * sprite.scale.x + Vector2(0, -air_h + 4.0)
		_apply_sprite_fx()
		return
	if view == null:
		return
	# only spend GPU time on brawlers that can actually be seen
	if not (alive and is_visible_in_tree() and _on_screen()):
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var crowd: bool = game.brawlers.size() > 6 and not is_player
	if crowd:
		# big free-for-all: the player's own brawler renders every frame, others share the load
		var every := 3 if Save.low_graphics() else 2
		if (Engine.get_process_frames() + get_instance_id()) % every == 0:
			view.render_target_update_mode = SubViewport.UPDATE_ONCE
	elif view.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.pose(delta, _moving, recoil, BrawlerView.yaw_from_aim(aim_dir))
	sprite.position = -view.feet_px * sprite.scale.x + Vector2(0, -air_h + 4.0)
	_apply_sprite_fx()

func _on_screen() -> bool:
	var vp := get_viewport()
	if vp == null:
		return true
	var p := get_global_transform_with_canvas().origin
	return vp.get_visible_rect().grow(140.0).has_point(p)

func _apply_sprite_fx() -> void:
	var alpha := 1.0
	var viewer_team: int = game.view_team
	if team == viewer_team and (in_bush() or invis_t > 0.0):
		alpha = 0.5
	if protect_t > 0.0:
		alpha *= 0.55 + 0.35 * sin(anim_t * 20.0)
	var m := sprite.material as ShaderMaterial
	m.set_shader_parameter("flash", flash)
	m.set_shader_parameter("alpha", alpha)

func _update_leap(delta: float) -> void:
	leap_t -= delta
	var k := 1.0 - clampf(leap_t / leap_total, 0.0, 1.0)
	global_position = leap_from.lerp(leap_to, k)
	air_h = sin(k * PI) * 110.0
	if leap_t <= 0.0:
		air_h = 0.0
		collision_mask = 1 | 2
		# landed inside something solid? snap to nearest walkable tile
		var cell: Vector2i = game.map.world_to_cell(global_position)
		if not game.map.is_walkable_cell(cell):
			global_position = game.map.cell_center(game.map.nearest_walkable(global_position))
			reset_physics_interpolation()
		Abilities.leap_land(self)

func _update_dash(delta: float) -> void:
	dash_t -= delta
	velocity = dash_vel
	var before := global_position
	move_and_slide()
	Abilities.dash_hits(self, before, global_position)
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		_ghost_t = 0.055
		Ghost.spawn(game.fx_layer, self)
	if get_slide_collision_count() > 0 and dash_t > 0.02:
		dash_t = 0.0
	if dash_t <= 0.0:
		velocity = Vector2.ZERO

# ------------------------------------------------------------------ actions
func can_act() -> bool:
	return alive and stun_t <= 0.0 and leap_t <= 0.0 and dash_t <= 0.0 and busy_t <= 0.0 and game.is_playing()

func attack_range_px() -> float:
	return float(d.attack.range) * Config.TILE

func super_range_px() -> float:
	return float(d.super.range) * Config.TILE

func try_attack(dir: Vector2, dist := -1.0) -> bool:
	if not can_act() or ammo < 1.0 or attack_cd > 0.0 or dir.length() < 0.01:
		return false
	ammo = max(0.0, ammo - 1.0)
	attack_cd = 0.3 if id != "nova" else 0.42
	_on_offensive_action()
	aim_dir = dir.normalized()
	recoil = 1.0
	atk_age = 0.0
	Abilities.primary(self, aim_dir, dist)
	return true

func try_super(dir: Vector2, dist := -1.0) -> bool:
	if not can_act() or super_charge < 1.0 or dir.length() < 0.01:
		return false
	super_charge = 0.0
	_on_offensive_action()
	aim_dir = dir.normalized()
	recoil = 1.0
	super_pose_t = 0.6
	Abilities.cast_super(self, aim_dir, dist)
	return true

func try_gadget(dir: Vector2) -> bool:
	if not has_gadget or not can_act() or gadget_cd > 0.0:
		return false
	gadget_cd = gadget_max_cd
	if dir.length() > 0.01:
		aim_dir = dir.normalized()
	Abilities.gadget(self, aim_dir)
	return true

func _on_offensive_action() -> void:
	regen_block = 0.0
	reveal_t = Config.ATTACK_REVEAL_TIME
	invis_t = 0.0
	protect_t = 0.0

func add_super(x: float) -> void:
	if x <= 0.0 or not alive:
		return
	var was := super_charge >= 1.0
	super_charge = min(1.0, super_charge + x)
	if not was and super_charge >= 1.0 and is_player:
		Sfx.play("super_ready", -2.0, 0.0)

func is_invulnerable() -> bool:
	return protect_t > 0.0 or leap_t > 0.0 or (dash_t > 0.0 and id == "vex")

## Applies damage. Returns the damage actually dealt.
func take_damage(amount: float, source: Brawler) -> float:
	if not alive or is_invulnerable() or game.ended:
		return 0.0
	if shield_t > 0.0:
		amount *= 1.0 - float(d.gadget.get("reduction", 0.0))
	amount = round(amount)
	if amount <= 0.0:
		return 0.0
	var dealt: float = min(hp, amount)
	hp -= amount
	flash = 1.0
	hurt_t = 0.28
	regen_block = 0.0
	reveal_t = max(reveal_t, 0.5)
	add_super(amount * Config.SUPER_CHARGE_ON_DAMAGE_TAKEN)
	var col := Color("ff4d5e") if is_player else Color.WHITE
	FX.number(game.fx_layer, global_position + Vector2(0, -78), str(int(amount)), col, amount >= 1500)
	if is_player:
		game.shake(6.0)
	if hp <= 0.0:
		hp = 0.0
		die(source)
	return dealt

func add_power_cell(hp_bonus: float, dmg_bonus: float) -> void:
	power_cells += 1
	max_hp += hp_bonus
	hp += hp_bonus
	dmg_mult *= 1.0 + dmg_bonus
	FX.number(game.fx_layer, global_position + Vector2(0, -90), "POWER UP!", Color("9dff8a"), true)

func heal(amount: float) -> float:
	if not alive or hp >= max_hp:
		return 0.0
	var actual: float = min(max_hp - hp, round(amount))
	hp += actual
	if actual >= 1.0:
		FX.number(game.fx_layer, global_position + Vector2(0, -78), "+" + str(int(actual)), Color("6dff8a"))
	return actual

func die(killer: Brawler) -> void:
	if not alive:
		return
	alive = false
	stats.deaths += 1
	dash_t = 0.0
	leap_t = 0.0
	air_h = 0.0
	beam_charge_t = 0.0
	busy_t = 0.0
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	visible = false
	Sfx.play_at("ko", global_position, 0.0)
	FX.burst(game.fx_layer, global_position + BODY_OFFSET, d.primary, 26, 380.0, 0.8, 7.0)
	FX.burst(game.fx_layer, global_position + BODY_OFFSET, Config.tc(team), 14, 300.0, 0.7, 5.0)
	FX.shockwave(game.fx_layer, global_position, 90.0, Color.WHITE, 0.4)
	game.on_brawler_died(self, killer)

func respawn(at: Vector2) -> void:
	alive = true
	global_position = at
	hp = max_hp
	ammo = max_ammo
	protect_t = Config.SPAWN_PROTECTION
	stun_t = 0.0
	root_t = 0.0
	slow_t = 0.0
	shield_t = 0.0
	invis_t = 0.0
	knock_vel = Vector2.ZERO
	regen_block = 0.0
	collision_layer = 4
	collision_mask = 1 | 2
	visible = true
	reset_physics_interpolation()
	Sfx.play_at("respawn", at, -6.0)
	FX.shockwave(game.fx_layer, at, 60.0, Config.tc(team), 0.4)

func start_leap(target: Vector2, duration: float) -> void:
	leap_from = global_position
	leap_to = target
	leap_total = duration
	leap_t = duration
	collision_mask = 0

func start_dash(dir: Vector2, distance: float, duration: float) -> void:
	dash_t = duration
	dash_vel = dir * (distance / duration)
	dash_hit.clear()

func apply_knockback(v: Vector2) -> void:
	knock_vel += v

func in_bush() -> bool:
	return game.map.is_bush(global_position)

## True if enemies of `viewer_team` cannot currently see this brawler.
func hidden_from(viewer_team: int) -> bool:
	if viewer_team == team or not alive:
		return false
	if reveal_t > 0.0:
		return false
	var hiding := invis_t > 0.0 or in_bush()
	if not hiding:
		return false
	for other in game.brawlers:
		if other.alive and other.team == viewer_team:
			if other.global_position.distance_to(global_position) < Config.BUSH_REVEAL_DISTANCE:
				return false
	return true

func body_center() -> Vector2:
	return global_position + BODY_OFFSET

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	if not alive:
		return
	var alpha := 1.0
	var viewer_team: int = game.view_team
	if team == viewer_team and (in_bush() or invis_t > 0.0):
		alpha = 0.55
	elif team != viewer_team and (invis_t > 0.0 or in_bush()):
		alpha = 0.8 # only drawn at all when revealed
	if protect_t > 0.0:
		alpha *= 0.55 + 0.35 * sin(anim_t * 20.0)
	var tc: Color = Config.tc(team)
	# team ring
	var ring := tc
	ring.a = 0.85 * alpha
	var ring_fill := tc
	ring_fill.a = 0.22 * alpha
	_draw_ellipse(Vector2(0, 3), 27, 11, ring_fill)
	draw_set_transform(Vector2(0, 3), 0, Vector2(1, 0.4))
	draw_arc(Vector2.ZERO, 27, 0, TAU, 36, ring, 4.0 if is_player else 3.0, true)
	if is_player:
		var a0 := anim_t * 2.0
		for i in 3:
			draw_arc(Vector2.ZERO, 33, a0 + i * TAU / 3.0, a0 + i * TAU / 3.0 + 0.6, 6, Color(1, 1, 1, 0.8 * alpha), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# leap shadow stays on ground, character goes up
	# ground shadow (the 3D model itself is a child sprite drawn on top)
	var sh := 1.0 - clampf(air_h / 160.0, 0.0, 0.6)
	_draw_ellipse(Vector2(0, 2), 24.0 * sh, 9.0 * sh, Color(0, 0, 0, 0.3 * alpha))
	if flat:
		var anim := {"t": anim_t, "moving": _moving, "flash": flash, "recoil": recoil,
			"aim": aim_dir, "alpha": alpha, "blink": blink_t < 0.0, "skin": skin, "no_shadow": true, "in_match": true, "hurt": hurt_t, "super_pose": super_pose_t, "atk": atk_age,
			"cheap": not is_player and game.brawlers.size() > 6}
		BrawlerArt.draw(self, id, Vector2(0, -air_h), 1.6, anim)

func _draw_ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

func _draw_star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		var a := -PI / 2 + i * PI / 5
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, Color("1a1028"), 1.5, true)


## Status effects (shield, stun, root, slow, super charge glow) drawn over the model.
class BrawlerStatus extends Node2D:
	var b: Brawler

	func _process(_delta: float) -> void:
		if b.flat and not b._on_screen():
			return
		queue_redraw()

	func _draw() -> void:
		if b == null or not b.alive:
			return
		if b.beam_charge_t > 0.0:
			var k := 1.0 - b.beam_charge_t / float(b.d.super.charge)
			BrawlerArt.glow(self, Brawler.BODY_OFFSET + b.aim_dir * 34.0, 10.0 + k * 26.0, Color(b.d.primary.r, b.d.primary.g, b.d.primary.b, 0.9))
		# status effects
		if b.shield_t > 0.0:
			var sc := Color("c9d0de")
			sc.a = 0.35 + 0.15 * sin(b.anim_t * 10.0)
			draw_circle(Brawler.BODY_OFFSET, 38, Color(sc.r, sc.g, sc.b, sc.a * 0.4))
			draw_arc(Brawler.BODY_OFFSET, 38, 0, TAU, 6, Color(1, 1, 1, 0.8), 3.0, true)
		if b.stun_t > 0.0:
			for i in 3:
				var a := b.anim_t * 6.0 + i * TAU / 3.0
				var p := Vector2(0, -74 - b.air_h) + Vector2(cos(a) * 18, sin(a) * 6)
				_star(p, 6.0, Color("ffe14d"))
		if b.root_t > 0.0:
			for i in 5:
				var a := i * TAU / 5.0 + 0.3
				var base := Vector2(cos(a) * 20, sin(a) * 8 + 2)
				draw_line(base, base + Vector2(cos(a) * 4, -18 - sin(b.anim_t * 5 + i) * 3), Color("2f7a35"), 5.0, true)
				draw_circle(base + Vector2(cos(a) * 4, -18), 4, Color("5fd35a"))
		if b.slow_t > 0.0:
			for i in 3:
				var p := Vector2(-14 + i * 14, -10 + fmod(b.anim_t * 40.0 + i * 9, 20.0))
				draw_circle(p, 3, Color(0.6, 0.3, 0.8, 0.7))

	func _star(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var rr := r if i % 2 == 0 else r * 0.45
			var a := -PI / 2 + i * PI / 5
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, Color("1a1028"), 1.5, true)


## Health bar, name and ammo drawn above everything else.
class BrawlerOverhead extends Node2D:
	var b: Brawler

	func _ready() -> void:
		z_index = 30

	func _process(_delta: float) -> void:
		if b.flat and not b._on_screen():
			return
		queue_redraw()

	func _draw() -> void:
		if b == null or not b.alive:
			return
		var f := FX._font()
		var y := (-140.0 if b.flat else -108.0) - b.air_h
		var w := 64.0
		var viewer: int = b.game.view_team
		var bar_col: Color
		if b.is_player:
			bar_col = Color("4dff7a")
		elif b.team == viewer:
			bar_col = Config.tc(b.team)
		else:
			bar_col = Color("ff4d5e")
		# name
		var name_col := bar_col.lightened(0.4)
		var nm: String = b.display_name
		var ns := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string_outline(f, Vector2(-ns.x * 0.5, y - 6), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 5, Color("1a1028"))
		draw_string(f, Vector2(-ns.x * 0.5, y - 6), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, name_col)
		# health bar
		var r := Rect2(-w * 0.5, y, w, 13)
		draw_rect(r.grow(2.5), Color("1a1028"))
		draw_rect(r, Color("3a2a4a"))
		var k := clampf(b.hp / b.max_hp, 0.0, 1.0)
		draw_rect(Rect2(r.position, Vector2(w * k, 13)), bar_col)
		draw_rect(Rect2(r.position, Vector2(w * k, 4)), bar_col.lightened(0.35))
		var hs := str(int(ceil(b.hp)))
		var hsz := f.get_string_size(hs, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		draw_string_outline(f, Vector2(-hsz.x * 0.5, y + 11), hs, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color("1a1028"))
		draw_string(f, Vector2(-hsz.x * 0.5, y + 11), hs, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		# ammo (own brawler only, like the classic arena games)
		if b.is_player:
			var seg_w := (w - (b.max_ammo - 1) * 3.0) / b.max_ammo
			for i in b.max_ammo:
				var sr := Rect2(-w * 0.5 + i * (seg_w + 3.0), y + 17, seg_w, 6)
				draw_rect(sr.grow(1.5), Color("1a1028"))
				var fill := clampf(b.ammo - i, 0.0, 1.0)
				var ac := Color("ff9d2e") if fill >= 1.0 else Color("8a5a2a")
				draw_rect(Rect2(sr.position, Vector2(sr.size.x * fill, sr.size.y)), ac)
		# super ready glow ring
		if b.super_charge >= 1.0:
			var gc := Color("ffd23a")
			gc.a = 0.5 + 0.4 * sin(b.anim_t * 8.0)
			draw_arc(Vector2(-w * 0.5 - 12, y + 6), 7, 0, TAU, 16, gc, 3.0, true)
			draw_circle(Vector2(-w * 0.5 - 12, y + 6), 4, gc)
		# power cells (Showdown)
		if b.power_cells > 0:
			var pp := Vector2(-14, y - 26)
			UIKit.draw_icon(self, "power_cell", pp, 26.0)
			var ps := str(b.power_cells)
			draw_string_outline(f, pp + Vector2(14, 8), ps, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color("1a1028"))
			draw_string(f, pp + Vector2(14, 8), ps, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("c8ffb0"))
		# carried gems
		if b.gems > 0:
			var gp := Vector2(0, y - 30)
			Gem.draw_gem_icon(self, gp, 9.0, b.anim_t)
			var gs := str(b.gems)
			draw_string_outline(f, gp + Vector2(11, 6), gs, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color("1a1028"))
			draw_string(f, gp + Vector2(11, 6), gs, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e8c8ff"))
