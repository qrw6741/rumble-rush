extends Node2D
## A single 3v3 battle: builds the arena, spawns the teams, runs the clock,
## enforces combat rules (no friendly fire, no acting while dead, nothing after the
## match ends), routes damage/heals/KOs and hands results to the results screen.

const T := 48.0

var mode_id := "gem_grab"
var map_id := ""
var player_brawler := "bront"
var difficulty := "normal"
var autoplay := false
var quit_after := false
var sim_time_scale := 1.0

var map: ArenaMap
var world: Node2D
var zone_layer: Node2D
var entity_layer: Node2D
var projectile_layer: Node2D
var bush_layer: Node2D
var fx_layer: Node2D
var camera: Camera2D
var hud: MatchHUD
var touch: TouchControls
var pause_menu: Control
var aim: AimIndicator

var brawlers: Array[Brawler] = []
var player: Brawler
var pc: PlayerController
var mode: GameMode

var state := "intro" # intro | playing | ended
var ended := false
var time_left := 150.0
var view_team := 0
var _intro_t := 3.6
var _last_intro_sec := 99
var _shake := 0.0
var _match_id := ""
var _elapsed := 0.0
var _ten_sec_warned := false
var _paused := false
var champs := false
var _champs_info := {}

func setup(params: Dictionary) -> void:
	mode_id = params.get("mode", Save.data.selected_mode)
	player_brawler = params.get("brawler", Save.data.selected_brawler)
	difficulty = params.get("difficulty", Config.match_difficulty(player_brawler))
	champs = params.get("champs", false)
	autoplay = params.get("autoplay", false)
	quit_after = params.get("quit_after", false)
	sim_time_scale = params.get("time_scale", 1.0)
	var maps: Array = Config.MODES[mode_id].maps
	var fallback: String = maps[randi() % maps.size()]
	# the map in rotation for this mode right now
	if not params.get("autoplay", false):
		fallback = Progression.active_map(mode_id)
	map_id = params.get("map", fallback)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	PlayerController.ensure_input_actions()
	_match_id = "%d_%d" % [Time.get_unix_time_from_system(), randi()]
	time_left = Config.MODES[mode_id].time_limit

	world = Node2D.new()
	add_child(world)
	map = ArenaMap.new()
	world.add_child(map)
	zone_layer = _layer(2)
	aim = AimIndicator.new()
	world.add_child(aim)
	entity_layer = _layer(0)
	entity_layer.y_sort_enabled = true
	projectile_layer = _layer(6)
	bush_layer = _layer(5)
	fx_layer = _layer(20)
	fx_layer.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF # FX animate in _process
	aim.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	map.build(map_id, entity_layer, bush_layer)

	match mode_id:
		"gem_grab": mode = ModeGem.new()
		"showdown": mode = ModeShowdown.new()
		"duel": mode = ModeDuel.new()
		_: mode = ModeKnockout.new()
	mode.setup(self, mode_id)
	if mode is ModeGem:
		var mine := GemMine.new()
		mine.mode = mode
		mine.position = map.gem_mine
		zone_layer.add_child(mine)

	if mode is ModeShowdown:
		_spawn_solo()
		var pl := PoisonLayer.new()
		pl.mode = mode
		pl.map = map
		world.add_child(pl)
	else:
		_spawn_teams()
		if mode is ModeDuel:
			var dl := PoisonLayer.new()
			dl.mode = mode
			dl.map = map
			world.add_child(dl)
	map.crate_broken.connect(func(pos: Vector2):
		if mode.has_method("on_crate_broken") and not ended:
			mode.on_crate_broken(pos))

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.5
	camera.limit_left = int(-T * 1.5)
	camera.limit_right = int(map.size_px.x + T * 1.5)
	camera.limit_top = int(-T * 3)
	camera.limit_bottom = int(map.size_px.y + T * 1.5)
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	world.add_child(camera)
	camera.global_position = player.global_position
	camera.make_current()
	_fit_zoom()
	get_viewport().size_changed.connect(_fit_zoom)

	# soft vignette between the world and the HUD
	var vl := CanvasLayer.new()
	vl.layer = 5
	add_child(vl)
	var vig := ColorRect.new()
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = preload("res://assets/shaders/vignette.gdshader")
	vig.material = vm
	vl.add_child(vig)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	touch = TouchControls.new()
	touch.b = player
	touch.ctrl = pc
	ui.add_child(touch)
	hud = MatchHUD.new()
	hud.setup(self)
	ui.add_child(hud)
	var want_touch := _want_touch()
	touch.visible = want_touch and not autoplay
	if pc:
		pc.touch = touch
	hud.set_touch_mode(touch.visible)
	pause_menu = _build_pause_menu()
	ui.add_child(pause_menu)

	for bl in bush_layer.get_children():
		if bl is BushLayer:
			bl.focus = player
	if pc:
		aim.pc = pc

	Sfx.play_music("music_battle")
	Sfx.listener_active = true
	if autoplay:
		Engine.time_scale = sim_time_scale
	hud.announce(Config.MODES[mode_id].name, Config.MODES[mode_id].color, 1.6, 52)
	_bake_sprites()

## Pre-render every brawler in this match into sprite frames (runs during the countdown).
func _bake_sprites() -> void:
	# live, fully animated 3D models by default; frame snapshots only on LOW graphics
	if not SpriteBank.can_bake() or Save.setting("view_mode") == "2d":
		return
	var g: String = Save.setting("graphics")
	# Showdown (10 brawlers): bots use pre-rendered frames, your brawler stays live 3D.
	# LOW graphics: everyone uses frames. HIGH: everyone live.
	var crowd := brawlers.size() > 6 and g != "high"
	if g != "low" and not crowd:
		return
	var targets: Array = []
	for b in brawlers:
		if g == "low" or not b.is_player:
			targets.append(b)
	var combos: Array = []
	for b in targets:
		var c := [b.id, b.skin]
		if not c in combos:
			combos.append(c)
	# phones: smaller frames (8 directions x 7 poses per brawler adds up fast)
	var bake_px := int(Brawler.VIEW_PX * (0.65 if (OS.has_feature("web") or OS.has_feature("mobile")) else 1.0))
	await SpriteBank.bake(self, combos, bake_px)
	if not is_inside_tree():
		return
	for b in targets:
		if not is_instance_valid(b):
			continue
		var set = SpriteBank.get_set(b.id, b.skin)
		if set != null:
			b.use_bank(set)

func _want_touch() -> bool:
	var s: String = Save.setting("touch_controls")
	if s == "on":
		if not DisplayServer.is_touchscreen_available():
			Input.emulate_touch_from_mouse = true # lets you try them with a mouse
		return true
	if s == "off":
		return false
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")

func _layer(z: int) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	world.add_child(n)
	return n

func _fit_zoom() -> void:
	if camera == null:
		return
	var vs := get_viewport_rect().size
	# show ~25 tiles across and at least ~15 tiles top to bottom
	var z := minf(vs.x / (T * 25.0), vs.y / (T * 15.0))
	z = clampf(z, 0.6, 1.2)
	camera.zoom = Vector2(z, z)
	# on very wide screens the view is wider than the arena: keep the arena centred
	var view := vs / z
	var ex := maxf(T * 1.5, (view.x - map.size_px.x) * 0.5)
	var ey := maxf(T * 1.5, (view.y - map.size_px.y) * 0.5)
	camera.limit_left = int(-ex)
	camera.limit_right = int(map.size_px.x + ex)
	camera.limit_top = int(-maxf(ey, T * 3.0))
	camera.limit_bottom = int(map.size_px.y + ey)

## Showdown: the player plus 9 bots, every brawler on their own team.
func _spawn_solo() -> void:
	var names: Array = Config.random_player_names(10)
	var spawns: Array[Vector2] = map.ffa_spawns.duplicate()
	var start := randi() % spawns.size()
	for i in 10:
		var is_player := i == 0
		var bid: String = player_brawler if is_player else Config.BRAWLER_ORDER[randi() % Config.BRAWLER_ORDER.size()]
		var b := Brawler.new()
		var lvl := Save.brawler_level(bid) if is_player else clampi(Save.brawler_level(player_brawler) + randi_range(-1, 1), 1, Config.MAX_LEVEL)
		var nm: String = Save.data.username if is_player else names[i % names.size()]
		b.setup(bid, i, is_player, nm, lvl, self)
		b.spawn_pos = spawns[(start + i) % spawns.size()]
		b.position = b.spawn_pos
		b.aim_dir = (map.size_px * 0.5 - b.spawn_pos).normalized()
		entity_layer.add_child(b)
		brawlers.append(b)
		if is_player and not autoplay:
			player = b
			pc = PlayerController.new()
			pc.setup(b, self)
			b.controller = pc
			b.add_child(pc)
		else:
			if is_player:
				player = b
			var brain := BotBrain.new()
			brain.setup(b, self, difficulty)
			b.controller = brain
			b.add_child(brain)
	view_team = player.team

func _spawn_teams() -> void:
	var pool: Array = Config.BRAWLER_ORDER.duplicate()
	var names: Array = Config.random_player_names(6)
	var name_i := 0
	for team in 2:
		var spawns: Array[Vector2] = map.blue_spawns if team == 0 else map.red_spawns
		var picks: Array = pool.duplicate()
		picks.shuffle()
		if team == 0:
			picks.erase(player_brawler)
			picks.insert(0, player_brawler)
		for i in int(Config.MODES[mode_id].get("team_size", 3)):
			var bid: String = picks[i]
			var b := Brawler.new()
			var is_player := team == 0 and i == 0
			var lvl := Save.brawler_level(bid) if is_player else clampi(Save.brawler_level(player_brawler) + randi_range(-1, 1), 1, Config.MAX_LEVEL)
			var nm: String = Save.data.username if is_player else names[name_i % names.size()]
			if not is_player:
				name_i += 1
			b.setup(bid, team, is_player, nm, lvl, self)
			b.spawn_pos = spawns[i % spawns.size()]
			b.position = b.spawn_pos
			b.aim_dir = Vector2.UP if team == 0 else Vector2.DOWN
			entity_layer.add_child(b)
			brawlers.append(b)
			if is_player and not autoplay:
				player = b
				pc = PlayerController.new()
				pc.setup(b, self)
				b.controller = pc
				b.add_child(pc)
			else:
				if is_player:
					player = b
				var brain := BotBrain.new()
				brain.setup(b, self, difficulty)
				b.controller = brain
				b.add_child(brain)
	view_team = player.team

# ------------------------------------------------------------------ loop
func is_playing() -> bool:
	return state == "playing"

func _process(delta: float) -> void:
	if state == "intro":
		_intro_t -= delta
		var sec := int(ceil(_intro_t - 0.6))
		if sec != _last_intro_sec and sec >= 1 and sec <= 3:
			_last_intro_sec = sec
			hud.announce(str(sec), Color.WHITE, 0.8, 96)
			Sfx.play("beep", 0.0, 0.0)
		if _intro_t <= 0.6 and _last_intro_sec != 0:
			_last_intro_sec = 0
			hud.announce("FIGHT!", Color("ffd23a"), 0.9, 96)
			Sfx.play("go", 0.0, 0.0)
			state = "playing"
			mode.on_start()
	# hide brawlers the local team can't see (bushes / invisibility)
	for b in brawlers:
		if b.alive:
			b.visible = not b.hidden_from(view_team)
	if _shake > 0.0:
		_shake = max(0.0, _shake - delta * 40.0)
		var amt := _shake if Save.setting("screen_shake") else 0.0
		camera.offset = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
	elif camera:
		camera.offset = Vector2.ZERO

func _physics_process(delta: float) -> void:
	# camera follow (in physics so it interpolates in step with the brawlers)
	if player and camera:
		var target := player.global_position + Vector2(0, -20)
		if player.alive and pc and not pc.using_touch():
			target += player.aim_dir * 50.0
		elif player.alive:
			target += player.velocity * 0.12 # look a little ahead of where you're running
		camera.global_position = target
		Sfx.listener_pos = player.global_position
	if state != "playing":
		return
	_elapsed += delta
	time_left -= delta
	if time_left <= 10.0 and not _ten_sec_warned and not mode.overtime:
		_ten_sec_warned = true
		hud.announce("10 SECONDS LEFT!", Color("ff6b6b"), 1.2, 44)
	mode.update(delta)
	if state != "playing":
		return
	for b in brawlers:
		if not b.alive and b.respawn_t < INF:
			b.respawn_t -= delta
			if b.respawn_t <= 0.0:
				b.respawn(b.spawn_pos)
	if time_left <= 0.0:
		time_left = 0.0
		mode.on_time_up()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state != "ended" and not _paused:
		toggle_pause()

# ------------------------------------------------------------------ combat API
func ray(from: Vector2, to: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	q.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_ray(q)

func has_los(a: Vector2, b: Vector2) -> bool:
	return ray(a, b).is_empty()

## Central damage routine. Friendly fire is impossible here by construction.
func deal_damage(src: Brawler, target: Brawler, amount: float, super_gain: float) -> float:
	if ended or target == null or not target.alive:
		return 0.0
	if src and src.team == target.team:
		return 0.0
	var dealt := target.take_damage(amount, src)
	if dealt > 0.0 and src:
		src.stats.damage += int(dealt)
		src.add_super(super_gain)
		if src == player or target == player:
			Sfx.play_at("hit", target.global_position, -4.0 if src == player else -2.0)
	return dealt

func heal(src: Brawler, target: Brawler, amount: float, super_gain: float) -> float:
	if ended or target == null or not target.alive:
		return 0.0
	var healed := target.heal(amount)
	if src and healed > 0.0:
		src.stats.healing += int(healed)
		src.add_super(super_gain)
	return healed

func on_brawler_died(victim: Brawler, killer: Brawler) -> void:
	victim.respawn_t = mode.respawn_delay(victim)
	if killer and killer != victim:
		killer.stats.kos += 1
	hud.add_feed(killer, victim)
	if victim == player:
		shake(10.0)
	elif killer == player:
		hud.announce("KO!", Color("ffd23a"), 0.7, 64)
	mode.on_ko(victim, killer)

func on_super_used(b: Brawler) -> void:
	if b == player:
		shake(3.0)

func announce(text: String, col: Color, dur := 1.6) -> void:
	hud.announce(text, col, dur, 44)

func shake(amount: float, at = null) -> void:
	if at != null and player and player.global_position.distance_to(at) > 900.0:
		return
	_shake = max(_shake, amount)

# ------------------------------------------------------------------ pause
func toggle_pause() -> void:
	if state == "ended":
		return
	_paused = not _paused
	get_tree().paused = _paused
	pause_menu.visible = _paused
	Sfx.play("ui_click")

func _build_pause_menu() -> Control:
	var root := PauseMenuRoot.new()
	root.game = self
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false
	root.theme = UIKit.theme()
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.12, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(440, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(UIKit.label("PAUSED", 44, UIKit.YELLOW, 10, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.body(Config.MODES[mode_id].rules, 15))
	v.add_child(SettingsPanel.slider_row("MUSIC", "music_volume"))
	v.add_child(SettingsPanel.slider_row("SOUND", "sfx_volume"))
	v.add_child(SettingsPanel.toggle_row("SCREEN SHAKE", "screen_shake"))
	v.add_child(SettingsPanel.toggle_row("AIM ASSIST", "aim_assist"))
	var resume := UIKit.button("RESUME", UIKit.GREEN, 26, Vector2(380, 64))
	resume.pressed.connect(toggle_pause)
	v.add_child(resume)
	var leave := UIKit.button("LEAVE (counts as loss)", UIKit.RED, 20, Vector2(380, 56))
	leave.pressed.connect(func():
		get_tree().paused = false
		_paused = false
		pause_menu.visible = false
		_finish_internal(1 - view_team, true))
	v.add_child(leave)
	return root

# ------------------------------------------------------------------ end of match
func finish_match(winner: int) -> void:
	_finish_internal(winner, false)

## Showdown ends with a placement (1 = last brawler standing).
func finish_showdown(place: int) -> void:
	_finish_internal(view_team if place <= 4 else -2, false, place)

func _finish_internal(winner: int, forfeited: bool, place := 0) -> void:
	if ended:
		return
	ended = true
	state = "ended"
	for b in brawlers:
		b.move_input = Vector2.ZERO
	var result := "draw"
	if winner == view_team:
		result = "win"
	elif winner != -1:
		result = "loss"
	if mode is ModeShowdown and forfeited:
		place = 10
	if place > 0:
		result = "win" if place <= 4 else "loss"
	var mvp := _pick_mvp(winner)
	var rewards := {}
	if not autoplay:
		rewards = Save.grant_match_rewards(_match_id, player.id, mode_id, result, player.stats.kos, player.stats.deaths, player.stats.damage, mvp == player, place)
		if champs:
			_champs_info = Save.champs_record(result)
	var text: String = {"win": "VICTORY!", "loss": "DEFEAT", "draw": "DRAW"}[result]
	if place > 0:
		text = "#1 WINNER!" if place == 1 else "RANK #%d" % place
	var col: Color = {"win": Color("ffd23a"), "loss": Color("ff4d5e"), "draw": Color.WHITE}[result]
	Sfx.stop_music(0.4)
	Sfx.play({"win": "victory", "loss": "defeat", "draw": "draw"}[result], 0.0, 0.0)
	hud.announce(text, col, 3.0, 110)
	Engine.time_scale = 0.35 if not autoplay else 1.0
	if mode is ModeShowdown:
		# survivors still standing get ranked by remaining health
		var alive_list: Array = brawlers.filter(func(x): return x.alive and not mode.placement.has(x))
		alive_list.sort_custom(func(x, y): return x.hp > y.hp)
		var next_place := 1
		for x in alive_list:
			while next_place == place and x != player:
				next_place += 1
			mode.placement[x] = place if x == player and place > 0 else next_place
			if x != player:
				next_place += 1
	var players: Array = []
	for b in brawlers:
		players.append({
			"name": b.display_name, "brawler": b.id, "team": b.team, "is_player": b.is_player,
			"kos": b.stats.kos, "deaths": b.stats.deaths, "damage": b.stats.damage,
			"healing": b.stats.healing, "gems": b.stats.gems, "mvp": b == mvp, "level": b.level,
			"place": int(mode.placement.get(b, 10)) if mode is ModeShowdown else 0,
		})
	var data := {
		"result": result, "mode": mode_id, "map": map_id, "brawler": player.id,
		"players": players, "rewards": rewards, "forfeit": forfeited,
		"score": mode.hud(), "duration": _elapsed, "view_team": view_team, "place": place,
		"champs": champs, "champs_info": _champs_info,
	}
	if quit_after:
		print("AUTOTEST RESULT: ", JSON.stringify({"result": result, "winner": winner, "mode": mode_id, "map": map_id, "duration": snappedf(_elapsed, 0.1), "score": mode.hud(), "players": players}))
		await get_tree().create_timer(0.5, true, false, true).timeout
		get_tree().quit()
		return
	await get_tree().create_timer(2.4, true, false, true).timeout
	Engine.time_scale = 1.0
	Sfx.listener_active = false
	Router.goto("results", data)

func _pick_mvp(winner: int) -> Brawler:
	var best: Brawler = null
	var best_s := -1.0
	for b in brawlers:
		if winner >= 0 and b.team != winner:
			continue
		var s: float = b.stats.kos * 3.0 + b.stats.damage / 900.0 + b.stats.healing / 900.0 + b.stats.gems * 1.5 - b.stats.deaths
		if s > best_s:
			best_s = s
			best = b
	return best

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Input.emulate_touch_from_mouse = false
	Sfx.listener_active = false


## Pause overlay root; keeps listening for ESC while the tree is paused.
class PauseMenuRoot extends Control:
	var game: Node

	func _unhandled_input(event: InputEvent) -> void:
		if visible and event.is_action_pressed("pause"):
			game.toggle_pause()
			get_viewport().set_input_as_handled()
