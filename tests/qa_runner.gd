extends Node
## Automated QA: drives real input events through a live match and checks the
## core rules. Run with:  godot --path . -- --qa

var passed := 0
var failed := 0

func check(name: String, ok: bool) -> void:
	if ok:
		passed += 1
		print("  PASS  ", name)
	else:
		failed += 1
		print("  FAIL  ", name)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# isolated, fresh profile so QA never touches the real save
	Save.save_path = "user://qa_save.json"
	Save.data = Save._default()
	Save._granted_matches.clear()
	Save.save_game()
	Save.data.settings.touch_controls = "off"
	Router.goto("match", {"mode": "knockout", "brawler": "nova", "map": "neon_district", "difficulty": "easy"}, true)
	await wait(0.5)
	var m = Router.current
	check("match screen loaded", m != null and m.has_method("is_playing"))
	check("6 brawlers spawned (3v3)", m.brawlers.size() == 6 and m.brawlers.filter(func(b): return b.team == 0).size() == 3)
	check("no attacking during countdown", not m.player.try_attack(Vector2.UP))
	while not m.is_playing():
		await frames(1)
	var p: Brawler = m.player
	# freeze bots so they don't interfere with the measurements
	for b in m.brawlers:
		if b != p:
			b.controller.set_process(false)
			b.controller = null
			b.move_input = Vector2.ZERO

	# --- movement through the real input map
	var start := p.global_position
	Input.action_press("move_right")
	await wait(0.5)
	Input.action_release("move_right")
	check("WASD moves the brawler (moved %.0f px)" % (p.global_position.x - start.x), p.global_position.x - start.x > 60.0)

	# --- mouse attack
	p.ammo = 3.0
	p.attack_cd = 0.0
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await frames(1)
	var projectiles: Array = m.projectile_layer.get_children().filter(func(n): return n is Projectile)
	check("left click fires (ammo %.2f, projectiles %d)" % [p.ammo, projectiles.size()], p.ammo < 2.5 and projectiles.size() >= 1)

	# --- ammo rules
	p.ammo = 0.4
	p.attack_cd = 0.0
	check("can't attack without ammo", not p.try_attack(Vector2.UP))
	check("ammo never negative", p.ammo >= 0.0)
	await wait(0.3)
	check("ammo reloads over time", p.ammo > 0.4)

	# --- super rules
	p.super_charge = 0.5
	check("super blocked below 100%", not p.try_super(Vector2.UP))
	p.super_charge = 1.0
	check("super fires at 100%", p.try_super(Vector2.UP))
	check("super meter resets after use", p.super_charge == 0.0)
	await wait(0.8)

	# --- gadget + cooldown
	p.ammo = 0.0
	p.gadget_cd = 0.0
	check("gadget works (Overclock refills ammo)", p.try_gadget(Vector2.UP) and p.ammo == p.max_ammo)
	check("gadget cooldown can't be bypassed", not p.try_gadget(Vector2.UP))

	# --- damage rules
	var ally: Brawler = m.brawlers.filter(func(b): return b.team == p.team and b != p)[0]
	var enemy: Brawler = m.brawlers.filter(func(b): return b.team != p.team)[0]
	var ally_hp := ally.hp
	check("no friendly fire", m.deal_damage(p, ally, 500.0, 0.0) == 0.0 and ally.hp == ally_hp)
	p.hp = p.max_hp - 100.0
	p.heal(99999.0)
	check("health never exceeds max", p.hp == p.max_hp)
	enemy.protect_t = 0.0
	var ehp := enemy.hp
	check("damage applies to enemies", m.deal_damage(p, enemy, 300.0, 0.1) > 0.0 and enemy.hp < ehp)
	enemy.protect_t = 1.0
	check("spawn protection blocks damage", m.deal_damage(p, enemy, 300.0, 0.0) == 0.0)
	enemy.protect_t = 0.0
	var kos_before: int = p.stats.kos
	m.deal_damage(p, enemy, 999999.0, 0.0)
	check("KO registered", not enemy.alive and p.stats.kos == kos_before + 1)
	check("dead brawlers can't attack", not enemy.try_attack(Vector2.DOWN))
	check("KO scored for the team", m.mode.score[p.team] >= 1)
	var waited := 0.0
	while not enemy.alive and waited < 20.0:
		await wait(0.25)
		waited += 0.25
	check("KO'd brawler respawns at spawn (alive=%s, dist=%.1f)" % [enemy.alive, enemy.global_position.distance_to(enemy.spawn_pos)], enemy.alive and enemy.global_position.distance_to(enemy.spawn_pos) < 1.0)

	# --- touch controls (simulated finger on the attack stick)
	m.touch.visible = true
	await frames(2)
	p.ammo = 3.0
	p.attack_cd = 0.0
	var c: Vector2 = m.touch.attack_center()
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = c
	t.pressed = true
	Input.parse_input_event(t)
	Input.flush_buffered_events()
	await frames(1)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = c + Vector2(0, -70)
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	await frames(1)
	check("touch aim preview shows while dragging", m.pc.preview_mode == "attack")
	var t2 := InputEventScreenTouch.new()
	t2.index = 0
	t2.position = c + Vector2(0, -70)
	t2.pressed = false
	Input.parse_input_event(t2)
	Input.flush_buffered_events()
	await frames(2)
	check("touch drag-and-release fires (ammo %.2f)" % p.ammo, p.ammo < 2.5)
	# floating move stick
	var mt := InputEventScreenTouch.new()
	mt.index = 1
	mt.position = Vector2(200, 500)
	mt.pressed = true
	Input.parse_input_event(mt)
	Input.flush_buffered_events()
	var md := InputEventScreenDrag.new()
	md.index = 1
	md.position = Vector2(280, 500)
	Input.parse_input_event(md)
	Input.flush_buffered_events()
	var before := p.global_position
	await wait(0.4)
	check("touch move stick moves the brawler", p.global_position.x - before.x > 40.0)
	mt = mt.duplicate()
	mt.pressed = false
	Input.parse_input_event(mt)
	Input.flush_buffered_events()
	m.touch.visible = false

	# --- pause
	m.toggle_pause()
	check("pause stops the game", get_tree().paused)
	m.toggle_pause()
	check("resume works", not get_tree().paused)

	# --- rewards & save
	var qa_id := "qa_%d" % Time.get_ticks_usec()
	var credits: int = Save.data.credits
	var r1: Dictionary = Save.grant_match_rewards(qa_id, "nova", "knockout", "win", 3, 1, 5000, true)
	var credits_after: int = Save.data.credits
	var r2: Dictionary = Save.grant_match_rewards(qa_id, "nova", "knockout", "win", 3, 1, 5000, true)
	check("rewards granted once", r1.credits > 0 and credits_after == credits + r1.credits)
	check("duplicate rewards rejected", r2.duplicate and Save.data.credits == credits_after)
	var f := FileAccess.open(Save.save_path, FileAccess.READ)
	var disk = JSON.parse_string(f.get_as_text())
	check("progress saved to disk", disk is Dictionary and int(disk.credits) == Save.data.credits)

	# --- end of match
	m.finish_match(p.team)
	await frames(2)
	check("match ends with a winner", m.ended)
	p.ammo = 3.0
	check("nobody can fight after the match ends", not p.try_attack(Vector2.UP))
	# --- menu flow, pressing real buttons
	await wait(3.2)
	check("results screen shown after match", Router.current != null and Router.current.get("data") is Dictionary)
	check("result saved to match history", Save.data.history.size() > 0)
	await press("MENU")
	check("results -> menu", Router.current.find_child("Play", true, false) != null)
	await press_named("Brawlers")
	check("menu -> brawlers", _screen_has_text("SELECT") or _screen_has_text("SELECTED"))
	Save.data.credits = 1000
	var lvl := Save.brawler_level("nova")
	Router.current._show("nova")
	await frames(2)
	await press("UPGRADE  %d" % Save.upgrade_cost("nova"))
	await press("UPGRADE")
	check("upgrade costs credits and levels up", Save.brawler_level("nova") == lvl + 1 and Save.data.credits < 1000)
	Router.current._show("vex")
	await frames(2)
	await press("SELECT")
	check("select brawler -> back to menu with VEX", Save.data.selected_brawler == "vex" and Router.current.get("_view") != null and Router.current._view.model.id == "vex")
	var mode_before: String = Save.data.selected_mode
	await press_named("Mode")
	check("mode button cycles game mode", Save.data.selected_mode != mode_before)
	await press_named("Settings")
	check("settings opens", _screen_has_text("SOUND EFFECTS"))
	await press("DONE")
	await press_named("Profile")
	check("menu -> profile with history", _screen_has_text("MATCH HISTORY") and _screen_has_text("VICTORY"))
	await press_named("Back")
	await press_named("Play")
	await wait(0.2)
	check("PLAY starts a match", Router.current != null and Router.current.has_method("is_playing"))
	print("QA DONE: %d passed, %d failed" % [passed, failed])
	await wait(0.3)
	get_tree().quit(1 if failed > 0 else 0)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text and node.is_visible_in_tree() and not node.disabled:
		return node
	for c in node.get_children():
		var r := _find_button(c, text)
		if r:
			return r
	return null

func _screen_has_text(text: String) -> bool:
	return _has_text(Router.current, text)

func _has_text(node: Node, text: String) -> bool:
	if node == null:
		return false
	if (node is Label or node is Button) and node.text.begins_with(text):
		return true
	for c in node.get_children():
		if _has_text(c, text):
			return true
	return false

func press(text: String) -> void:
	var b := _find_button(Router.current, text)
	if b == null:
		print("  (button not found: ", text, ")")
		failed += 1
		return
	b.pressed.emit()
	await wait(0.7)

func press_named(n: String) -> void:
	var b: BaseButton = Router.current.find_child(n, true, false)
	if b == null:
		print("  (button not found: ", n, ")")
		failed += 1
		return
	b.pressed.emit()
	await wait(0.7)
