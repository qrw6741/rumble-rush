extends Control
## Entry point. Hands control to the Router, which shows the main menu.

var _wrap: SubViewportContainer
var _sub: SubViewport
var _inner: Control
var _portrait := false

func _ready() -> void:
	Router.root_container = self
	randomize()
	if OS.has_feature("web") or OS.has_feature("mobile"):
		# phones: render the 2D UI at game resolution instead of full Retina pixels (big FPS win)
		Save.apply_fps()
		get_tree().root.size_changed.connect(func(): _apply_orientation.call_deferred())
		_apply_orientation()
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
			"rewards": {"trophies": 8, "credits": 42, "xp": 61, "level_up": true, "new_level": 3},
			"players": [
				{"name": "Player", "brawler": "nova", "team": 0, "is_player": true, "kos": 6, "deaths": 1, "damage": 18450, "healing": 0, "gems": 7, "mvp": true, "level": 3},
				{"name": "Juno (BOT)", "brawler": "mira", "team": 0, "is_player": false, "kos": 1, "deaths": 2, "damage": 6100, "healing": 9800, "gems": 2, "mvp": false, "level": 2},
				{"name": "Bolt (BOT)", "brawler": "bront", "team": 0, "is_player": false, "kos": 4, "deaths": 3, "damage": 15200, "healing": 0, "gems": 3, "mvp": false, "level": 3},
				{"name": "Kiwi (BOT)", "brawler": "vex", "team": 1, "is_player": false, "kos": 3, "deaths": 4, "damage": 12000, "healing": 0, "gems": 4, "mvp": false, "level": 2},
				{"name": "Echo (BOT)", "brawler": "sprig", "team": 1, "is_player": false, "kos": 2, "deaths": 5, "damage": 11800, "healing": 0, "gems": 1, "mvp": false, "level": 3},
				{"name": "Fuse (BOT)", "brawler": "nova", "team": 1, "is_player": false, "kos": 1, "deaths": 4, "damage": 9300, "healing": 0, "gems": 0, "mvp": false, "level": 2},
			]}
	if "--touch" in args:
		Save.data.settings.touch_controls = "on"
	if "--demo-champs" in args:
		Save.save_path = "user://demo_save.json"
		Save.data.champs = {"stage": "finals", "q_w": 5, "q_l": 1, "f_w": 9, "f_l": 3, "best": "RANK IV", "runs": 2}
	if "--view2d" in args:
		Save.data.settings.view_mode = "2d"
		Save.data.settings.map_view = "2d"
	if "--demo-progress" in args:
		Save.save_path = "user://demo_save.json"
		Save.data.pass_tokens = 760
		Save.data.pass_claimed = {"free": [1, 2, 3], "gold": []}
		Save.data.brawler_trophies["vex"] = 95
		Save.data.road_claimed = [0, 1]
	Router.goto(screen, params, true)
	if "--demo-aim" in args or "--demo-super" in args:
		_demo_inputs(args)
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
		print("saved ", "%s_%d.png" % [out, i], "  fps=", Engine.get_frames_per_second())
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
		if portrait:
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
		_wrap.size = Vector2(ls.y, ls.x)
		_inner.size = Vector2(ls.y, ls.x)
		_wrap.rotation = PI / 2.0
		_wrap.position = Vector2(ls.x, 0)
		if Router.current is Control:
			(Router.current as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _move_screens(from: Node, to: Node) -> void:
	Router.root_container = to
	for c in from.get_children():
		if c == _wrap:
			continue
		c.reparent(to, false)
		_finish_entrance(c)
		if c is Control:
			(c as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
