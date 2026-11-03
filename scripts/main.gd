extends Control
## Entry point. Hands control to the Router, which shows the main menu.

func _ready() -> void:
	Router.root_container = self
	randomize()
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
		var mode := "knockout" if "--knockout" in args else "gem_grab"
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
	Router.goto(screen, params, true)
	if "--demo-aim" in args or "--demo-super" in args:
		_demo_inputs(args)
	var elapsed := 0.0
	for i in times.size():
		var wait: float = times[i] - elapsed
		await get_tree().create_timer(max(0.05, wait), true, false, true).timeout
		elapsed = times[i]
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s_%d.png" % [out, i])
		print("saved ", "%s_%d.png" % [out, i])
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
