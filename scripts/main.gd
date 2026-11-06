extends Control
## Entry point. Hands control to the Router, which shows the main menu.

var _wrap: SubViewportContainer
var _sub: SubViewport
var _inner: Control
var _portrait := false
var _rwrap: SubViewportContainer  # fixed-resolution wrapper (720p / 1080p / 4K)
var _rsub: SubViewport
var _rinner: Control

func _ready() -> void:
	Router.root_container = self
	Router.app = self
	randomize()
	if OS.has_feature("web") or OS.has_feature("mobile"):
		# phones: render the 2D UI at game resolution instead of full Retina pixels (big FPS win)
		Save.apply_fps()
		if OS.has_feature("web"):
			_setup_web_updates()
		get_tree().root.size_changed.connect(func(): _apply_orientation.call_deferred())
		_apply_orientation()
	else:
		get_tree().root.size_changed.connect(func(): apply_resolution.call_deferred())
	apply_resolution()
	# Command line: `-- --autotest` runs an automated bot-vs-bot match (used for QA).
	var args := OS.get_cmdline_user_args()
	if "--gallery" in args:
		add_child(load("res://tests/gallery.gd").new())
		return
	if "--qa" in args:
		add_child(load("res://tests/qa_runner.gd").new())
		return
	if "--check" in args:
		_check_scripts()
		return
	for a in args:
		if a.begins_with("--screen="):
			_screenshot_mode(args, a.substr(9))
			return
	if "--autotest" in args:
		var mode := "knockout" if "--knockout" in args else ("showdown" if "--showdown" in args else ("duel" if "--duel" in args else "gem_grab"))
		var ts := 1.0
		var diff := "normal"
		for a in args:
			if a.begins_with("--ts="):
				ts = float(a.substr(5))
			if a.begins_with("--diff="):
				diff = a.substr(7)
		var params := {"mode": mode, "autoplay": true, "time_scale": ts, "quit_after": true, "difficulty": diff}
		for a in args:
			if a.begins_with("--brawler="):
				params["brawler"] = a.substr(10)
			if a.begins_with("--map="):
				params["map"] = a.substr(6)
		Router.goto("match", params, true)
		return
	Router.goto("menu", {}, true)

## QA helper: load every script so compile errors surface (run with `-- --check`).
func _check_scripts() -> void:
	var bad := 0
	var stack := ["res://scripts"]
	while stack.size() > 0:
		var dir: String = stack.pop_back()
		var da := DirAccess.open(dir)
		for f in da.get_files():
			if f.ends_with(".gd") and load(dir + "/" + f) == null:
				bad += 1
				print("FAILED: ", dir + "/" + f)
		for sub in da.get_directories():
			stack.append(dir + "/" + sub)
	print("SCRIPT CHECK DONE, failures: ", bad)
	get_tree().quit()

## QA helper: open a screen and save screenshots at given times, e.g.
## `-- --screen=match --shots=2,6 --out=/tmp/shot`
func _screenshot_mode(args: PackedStringArray, screen: String) -> void:
	var times := [2.0]
	var out := "user://shot"
	var params := {}
	for a in args:
		if a.begins_with("--shots="):
			times = []
			for t in a.substr(8).split(","):
				times.append(float(t))
		if a.begins_with("--out="):
			out = a.substr(6)
		if a.begins_with("--brawler="):
			params["brawler"] = a.substr(10)
		if a.begins_with("--mode="):
			params["mode"] = a.substr(7)
		if a.begins_with("--map="):
			params["map"] = a.substr(6)
	if screen == "match" and "--auto" in args:
		params["autoplay"] = true
	if screen == "results":
		params = {"result": "win", "mode": "gem_grab", "map": "crystal_canyon", "brawler": "nova", "view_team": 0,
			"rewards": {"trophies": 11, "credits": 72, "streak": 4, "streak_trophies": 3, "streak_credits": 30, "xp": 61, "level_up": true, "new_level": 3},
			"players": [
				{"name": "Player", "brawler": "nova", "team": 0, "is_player": true, "kos": 6, "deaths": 1, "damage": 18450, "healing": 0, "gems": 7, "mvp": true, "level": 3},
				{"name": "Juno (BOT)", "brawler": "mira", "team": 0, "is_player": false, "kos": 1, "deaths": 2, "damage": 6100, "healing": 9800, "gems": 2, "mvp": false, "level": 2},
				{"name": "Bolt (BOT)", "brawler": "bront", "team": 0, "is_player": false, "kos": 4, "deaths": 3, "damage": 15200, "healing": 0, "gems": 3, "mvp": false, "level": 3},
				{"name": "Kiwi (BOT)", "brawler": "vex", "team": 1, "is_player": false, "kos": 3, "deaths": 4, "damage": 12000, "healing": 0, "gems": 4, "mvp": false, "level": 2},
				{"name": "Echo (BOT)", "brawler": "sprig", "team": 1, "is_player": false, "kos": 2, "deaths": 5, "damage": 11800, "healing": 0, "gems": 1, "mvp": false, "level": 3},
				{"name": "Fuse (BOT)", "brawler": "nova", "team": 1, "is_player": false, "kos": 1, "deaths": 4, "damage": 9300, "healing": 0, "gems": 0, "mvp": false, "level": 2},
			]}
	if screen == "results" and "--sd" in args:
		params.mode = "showdown"
		params.place = 1
		params.brawler = "vex"
		params.erase("players")
	if "--graves" in args:
		Save.data.selected_brawler = "graves"
		if not "graves" in Save.data.unlocked:
			Save.data.unlocked.append("graves")
		params["brawler"] = "graves"
	if "--demo-ranked" in args:
		Save.save_path = "user://demo_save.json"
		Save.data.ranked = {"points": 745, "best": 760, "wins": 31, "losses": 12, "streak": 3, "claimed": [0, 1, 2]}
		if screen == "results":
			params["ranked"] = true
			params["ranked_info"] = {"before": 690, "after": 745, "delta": 35, "promoted": true, "demoted": false, "new_rank": -1, "streak": 3}
	if "--debugres" in args:
		params["debug"] = true
	if "--touch" in args:
		Save.data.settings.touch_controls = "on"
	if "--demo-champs" in args:
		Save.save_path = "user://demo_save.json"
		Save.data.champs = {"stage": "finals", "q_w": 5, "q_l": 1, "f_w": 9, "f_l": 3, "best": "RANK IV", "runs": 2}
	if "--res720" in args:
		Save.data.settings.resolution = "720p"
		apply_resolution()
	if "--res4k" in args:
		Save.data.settings.resolution = "4k"
		apply_resolution()
	if "--res1080" in args:
		Save.data.settings.resolution = "1080p"
		apply_resolution()
	if "--view2d" in args:
		Save.data.settings.view_mode = "2d"
		Save.data.settings.map_view = "2d"
	if "--demo-progress" in args:
		Save.save_path = "user://demo_save.json"
		Save.data.win_streak = 4
		Save.data.pass_tokens = 760
		Save.data.pass_claimed = {"free": [1, 2, 3], "gold": []}
		Save.data.brawler_trophies["vex"] = 95
		Save.data.road_claimed_t = [10, 25]
	Router.goto(screen, params, true)
	if "--demo-aim" in args or "--demo-super" in args:
		_demo_inputs(args)
	if "--debugmenu" in args:
		var dp: Control = preload("res://scripts/ui/debug_panel.gd").new()
		add_child(dp)
	if "--toggle4k" in args:
		await get_tree().create_timer(1.2).timeout
		Save.set_setting("resolution", "4k")
		await get_tree().create_timer(0.6).timeout
		Save.set_setting("resolution", "1080p")
		await get_tree().create_timer(0.4).timeout
		if "--tonative" in args:
			Save.set_setting("resolution", "native")
	if "--clicktest" in args:
		await get_tree().create_timer(1.0).timeout
		var ws := Vector2(get_tree().root.size)
		var at := Vector2(1215, 45) * ws.x / 1280.0
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.position = at
			ev.global_position = at
			Input.parse_input_event(ev)
			await get_tree().process_frame
	if "--settings" in args:
		var sp := SettingsPanel.new()
		sp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(sp)
	var elapsed := 0.0
	for i in times.size():
		var wait: float = times[i] - elapsed
		await get_tree().create_timer(max(0.05, wait), true, false, true).timeout
		elapsed = times[i]
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s_%d.png" % [out, i])
		print("saved ", "%s_%d.png" % [out, i], "  fps=", Engine.get_frames_per_second(), " img=", img.get_size(), " win=", get_tree().root.size, " cs=", get_tree().root.content_scale_size, " mode=", get_tree().root.content_scale_mode)
	get_tree().quit()

func _demo_inputs(args: PackedStringArray) -> void:
	await get_tree().create_timer(3.8).timeout
	var m = Router.current
	if m == null or m.player == null:
		return
	var p: Brawler = m.player
	var vp := get_viewport()
	var screen_pos: Vector2 = vp.get_canvas_transform() * (p.global_position + Vector2(140, -180))
	Input.warp_mouse(screen_pos)
	if "--demo-super" in args:
		p.super_charge = 1.0
		Input.action_press("super")


# ------------------------------------------------------------------ resolution
## RESOLUTION setting. The layout always stays 1280x720 "logical" pixels; only how
## many real pixels the game is drawn with changes:
##   720p   -> drawn at 1280x720 then scaled to the screen (fastest)
##   1080p  -> drawn at 1920x1080 then scaled (sharp, still light)
##   native -> drawn at the screen's own resolution (sharpest)
# ------------------------------------------------------------------ web updates
## The home-screen app caches the game offline. When a newer version has been
## published, switch to it right away (or as soon as the player is back in the menus).
var _update_pending := false

func _setup_web_updates() -> void:
	JavaScriptBridge.pwa_update_available.connect(func():
		_update_pending = true
		_try_web_update())
	# also catch an update that was found before the signal was connected
	get_tree().create_timer(2.0).timeout.connect(func():
		if JavaScriptBridge.pwa_needs_update():
			_update_pending = true
			_try_web_update())
	Router.screen_changed.connect(func(_name: String): _try_web_update())

func _try_web_update() -> void:
	if not _update_pending:
		return
	if Router.current_name == "match":
		return  # never interrupt a match; retried when the next screen opens
	Save.save_game()
	JavaScriptBridge.pwa_update()

func apply_resolution() -> void:
	var root := get_tree().root
	if _portrait:
		_res_unwrap()
		return # the upright-phone wrapper manages its own rendering size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_factor = 1.0
	var res: String = Save.setting("resolution")
	if res == "4k" and not Config.can_4k():
		res = "1080p"
	var f := 0.0
	match res:
		"720p": f = 1.0
		"1080p": f = 1.5
		"4k": f = 3.0
	if f <= 0.0:
		_res_unwrap()
		Config.render_px = maxf(1.0, float(root.size.y) / 720.0)
		return
	# render the whole game into an offscreen buffer of exactly this resolution,
	# laid out at the usual 1280x720 units, then scale it to the window
	var ls := root.get_visible_rect().size
	var fresh := _rwrap == null
	if fresh:
		_rwrap = SubViewportContainer.new()
		_rwrap.stretch = false
		_rwrap.process_mode = Node.PROCESS_MODE_ALWAYS
		_rwrap.mouse_filter = Control.MOUSE_FILTER_STOP
		_rwrap.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_rwrap)
		_rsub = SubViewport.new()
		_rsub.handle_input_locally = false
		_rsub.physics_object_picking = false
		_rwrap.add_child(_rsub)
		_rinner = Control.new()
		_rinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rsub.add_child(_rinner)
	_rsub.size = Vector2i(int(ls.x * f), int(ls.y * f))
	_rsub.size_2d_override = Vector2i(int(ls.x), int(ls.y))
	_rsub.size_2d_override_stretch = true
	_rwrap.size = Vector2(_rsub.size)
	_rwrap.scale = Vector2.ONE / f
	_rwrap.position = Vector2.ZERO
	_rinner.position = Vector2.ZERO
	_rinner.size = ls
	if fresh:
		_move_screens(self, _rinner)
	Config.render_px = f
	if Router.current is Control:
		(Router.current as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _res_unwrap() -> void:
	if _rwrap == null:
		return
	_move_screens(_rinner, self)
	_rwrap.queue_free()
	_rwrap = null
	_rsub = null
	_rinner = null

# ------------------------------------------------------------------ always-landscape
## iPhone browsers can't lock orientation, so when the screen is held upright we
## render the whole game into a landscape viewport and rotate it 90°. Touch input
## is rotated back automatically by the SubViewportContainer.
func _apply_orientation() -> void:
	var ws := DisplayServer.window_get_size()
	var portrait := ws.y > ws.x
	var root := get_tree().root
	if portrait != _portrait:
		_portrait = portrait
		root.content_scale_size = Vector2i(720, 1280) if portrait else Vector2i(1280, 720)
		# always render the 2D at the screen's full resolution (never a blurry upscale)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		apply_resolution.call_deferred()
		if portrait:
			_res_unwrap()
			_wrap = SubViewportContainer.new()
			_wrap.stretch = false
			# must keep forwarding taps while the game is paused (pause menu buttons)
			_wrap.process_mode = Node.PROCESS_MODE_ALWAYS
			_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
			add_child(_wrap)
			_sub = SubViewport.new()
			_sub.handle_input_locally = false
			_sub.physics_object_picking = false
			_wrap.add_child(_sub)
			_inner = Control.new()
			_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_sub.add_child(_inner)
			_move_screens(self, _inner)
		else:
			_move_screens(_inner, self)
			_wrap.queue_free()
			_wrap = null
			_sub = null
			_inner = null
	if _portrait:
		# logical portrait size with a 720-wide base, e.g. 720 x 1558 on an iPhone
		var ls := Vector2(720.0, 720.0 * float(ws.y) / float(ws.x))
		# render the rotated game at the screen's real pixel density so it stays sharp
		var dpi := maxf(1.0, float(ws.x) / ls.x)
		if Save.setting("graphics") == "low":
			dpi = 1.0
		_sub.size = Vector2i(int(ls.y * dpi), int(ls.x * dpi))
		_sub.size_2d_override = Vector2i(int(ls.y), int(ls.x))
		_sub.size_2d_override_stretch = true
		_wrap.scale = Vector2.ONE / dpi
		Config.render_px = dpi
		_wrap.size = Vector2(ls.y, ls.x)
		_inner.size = Vector2(ls.y, ls.x)
		_wrap.rotation = PI / 2.0
		_wrap.position = Vector2(ls.x, 0)
		if Router.current is Control:
			(Router.current as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _move_screens(from: Node, to: Node) -> void:
	Router.root_container = to
	for c in from.get_children():
		if c is SubViewportContainer:
			continue
		c.reparent(to, false)
		if c is Control:
			(c as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_finish_entrance(c)
		for cam in c.find_children("*", "Camera2D", true, false):
			(cam as Camera2D).make_current()

## Reparenting kills running entrance tweens, so snap those elements to their final state.
func _finish_entrance(n: Node) -> void:
	for c in n.find_children("*", "Control", true, false):
		var ctl := c as Control
		if ctl.has_meta("pop_target"):
			ctl.modulate.a = 1.0
			ctl.scale = Vector2.ONE
			ctl.position = ctl.get_meta("pop_target")
