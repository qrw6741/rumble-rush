class_name SettingsPanel
extends Control
## Full-screen settings overlay. Every option is saved immediately.

signal closed

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.12, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(620, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(UIKit.label("SETTINGS", 34, UIKit.YELLOW, 10, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(slider_row("MUSIC", "music_volume"))
	v.add_child(slider_row("SOUND EFFECTS", "sfx_volume"))
	v.add_child(choice_row("BOT DIFFICULTY", "difficulty", ["auto", "easy", "normal", "hard", "extreme"], ["AUTO", "EASY", "MED", "HARD", "EXTRM"], 66))
	v.add_child(choice_row("TOUCH CONTROLS", "touch_controls", ["auto", "on", "off"], ["AUTO", "ON", "OFF"]))
	v.add_child(choice_row("GRAPHICS", "graphics", ["auto", "high", "low"], ["AUTO", "HIGH", "LOW"]))
	v.add_child(toggle_row("AIM ASSIST", "aim_assist"))
	v.add_child(toggle_row("SCREEN SHAKE", "screen_shake"))
	v.add_child(toggle_row("DAMAGE NUMBERS", "damage_numbers"))
	v.add_child(choice_row("FPS LIMIT", "fps_cap", [30, 60, 90, 120, 0], ["30", "60", "90", "120", "MAX"], 62))
	v.add_child(toggle_row("SHOW FPS", "show_fps"))
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		v.add_child(toggle_row("FULLSCREEN", "fullscreen"))
	var close := UIKit.button("DONE", UIKit.GREEN, 24, Vector2(560, 52))
	close.pressed.connect(func():
		closed.emit()
		queue_free())
	v.add_child(close)
	p.pivot_offset = Vector2(310, 300)
	p.scale = Vector2(0.85, 0.85)
	p.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.15)

static func _row(title: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := UIKit.label(title, 20, Color.WHITE, 6)
	l.custom_minimum_size = Vector2(230, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h

static func slider_row(title: String, key: String) -> HBoxContainer:
	var h := _row(title)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Save.setting(key))
	s.custom_minimum_size = Vector2(240, 30)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color("15102a")
	track.set_corner_radius_all(6)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = UIKit.YELLOW
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var pct := UIKit.label("%d%%" % int(s.value * 100), 18, UIKit.YELLOW, 5)
	pct.custom_minimum_size = Vector2(60, 0)
	s.value_changed.connect(func(val: float):
		pct.text = "%d%%" % int(val * 100)
		Save.data.settings[key] = val
		Sfx.apply_volumes())
	s.drag_ended.connect(func(_c): Save.set_setting(key, s.value); Sfx.play("ui_click"))
	h.add_child(s)
	h.add_child(pct)
	return h

static func toggle_row(title: String, key: String) -> HBoxContainer:
	var h := _row(title)
	var on: bool = Save.setting(key)
	var b := UIKit.button("ON" if on else "OFF", UIKit.GREEN if on else Color("6b5f86"), 18, Vector2(130, 40))
	b.pressed.connect(func():
		var nv: bool = not Save.setting(key)
		Save.set_setting(key, nv)
		b.text = "ON" if nv else "OFF"
		var col := UIKit.GREEN if nv else Color("6b5f86")
		b.add_theme_stylebox_override("normal", UIKit.box(col))
		b.add_theme_stylebox_override("hover", UIKit.box(col.lightened(0.12))))
	h.add_child(b)
	return h

static func choice_row(title: String, key: String, values: Array, labels: Array, bw := 84) -> HBoxContainer:
	var h := _row(title)
	var buttons: Array[Button] = []
	for i in values.size():
		var val = values[i]
		var sel: bool = Save.setting(key) == val
		var b := UIKit.button(labels[i], UIKit.ORANGE if sel else Color("6b5f86"), 16, Vector2(bw, 40))
		buttons.append(b)
		b.pressed.connect(func():
			Save.set_setting(key, val)
			for j in buttons.size():
				var c := UIKit.ORANGE if values[j] == val else Color("6b5f86")
				buttons[j].add_theme_stylebox_override("normal", UIKit.box(c))
				buttons[j].add_theme_stylebox_override("hover", UIKit.box(c.lightened(0.12))))
		h.add_child(b)
	return h
