extends Control
## CHOOSE EVENT: pick a mode + arena from big event cards. Opened by tapping the
## mode panel in the lobby. Tabs at the bottom filter by mode.

const Lobby := preload("res://scripts/ui/main_menu.gd")

var _row: HBoxContainer
var _tab := "ALL"
var _tabs: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var bg := ColorRect.new()
	bg.color = Color("1a5fd6")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shade := Lobby.LobbyBackground.new()
	shade.modulate = Color(0.55, 0.7, 1.0, 0.5)
	add_child(shade)
	Lobby.build_header(self, "CHOOSE EVENT", func(): Router.goto("menu"))

	# events section panel
	var section := SectionFrame.new()
	section.set_anchors_preset(Control.PRESET_FULL_RECT)
	section.offset_left = 20
	section.offset_top = 96
	section.offset_right = -20
	section.offset_bottom = -78
	add_child(section)

	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 40
	scroll.offset_top = 150
	scroll.offset_right = -40
	scroll.offset_bottom = -92
	add_child(scroll)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 22)
	scroll.add_child(_row)

	# bottom tab bar
	var bar := TabBarBg.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -70
	add_child(bar)
	var tabs := ["ALL", "SHOWDOWN", "GEM RUSH", "KNOCKOUT RUSH"]
	for i in tabs.size():
		var t := TabButton.new()
		t.label = tabs[i]
		t.name = "Tab" + str(i)
		t.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		t.position = Vector2(40 + i * 250, -62)
		t.size = Vector2(240, 54)
		var tab_name: String = tabs[i]
		t.pressed.connect(func():
			_tab = tab_name
			for k in _tabs.keys():
				_tabs[k].on = k == _tab
				_tabs[k].queue_redraw()
			Sfx.play("ui_click")
			_rebuild())
		_tabs[tab_name] = t
		add_child(t)
	_tabs["ALL"].on = true
	_rebuild()

func _events() -> Array:
	var out: Array = []
	for mode_id in Config.MODES.keys():
		var m: Dictionary = Config.MODES[mode_id]
		if _tab != "ALL" and m.name != _tab:
			continue
		# only the map currently in rotation for each mode
		out.append({"mode": mode_id, "map": Progression.active_map(mode_id)})
	return out

func _rebuild() -> void:
	for c in _row.get_children():
		c.queue_free()
	for e in _events():
		var card := EventCard.new()
		card.mode_id = e.mode
		card.map_id = e.map
		card.name = "Event_%s_%s" % [e.mode, e.map]
		card.custom_minimum_size = Vector2(270, 420)
		card.pressed.connect(func():
			Save.data.selected_mode = e.mode
			Save.data.selected_map = e.map
			Save.save_game()
			Sfx.play("ui_confirm")
			Router.goto("menu"))
		var info := UIKit.button("i", Color("2a8cff"), 22, Vector2(44, 44))
		info.position = Vector2(214, 10)
		info.pressed.connect(func(): _show_info(e.mode))
		card.add_child(info)
		_row.add_child(card)
		UIKit.pop_in(card, 0.06 * _row.get_child_count())

func _show_info(mode_id: String) -> void:
	var m: Dictionary = Config.MODES[mode_id]
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.14, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(c)
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(640, 0)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UIKit.label(m.name, 34, m.color.lightened(0.3), 8, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.body(m.rules, 17))
	var ok := UIKit.button("GOT IT", UIKit.GREEN, 22, Vector2(240, 56))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(o.queue_free)
	v.add_child(ok)
	add_child(o)


## Tall event card: mode colours, emblem, mini map preview, names.
class EventCard extends Button:
	var mode_id := "gem_grab"
	var map_id := "crystal_canyon"
	var _t := 0.0

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		mouse_entered.connect(func(): UIKit._pop(self, 1.03))
		mouse_exited.connect(func(): UIKit._pop(self, 1.0))
		button_down.connect(func(): UIKit._pop(self, 0.96))
		button_up.connect(func(): UIKit._pop(self, 1.0))

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var S := preload("res://scripts/ui/main_menu.gd").SlantButton
		var m: Dictionary = Config.MODES[mode_id]
		var mc: Color = m.color
		var w := size.x
		var h := size.y
		var ink := UIKit.DARK
		var sel: bool = Save.data.selected_mode == mode_id
		draw_rect(Rect2(6, 10, w, h), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(0, 0, w, h), UIKit.YELLOW if sel else ink)
		var inner := Rect2(5, 5, w - 10, h - 10)
		# diagonal two-tone background
		draw_rect(inner, mc.darkened(0.15))
		draw_colored_polygon(PackedVector2Array([inner.position, inner.position + Vector2(inner.size.x, 0), inner.position + Vector2(inner.size.x, inner.size.y * 0.35), inner.position + Vector2(0, inner.size.y * 0.7)]), mc.lightened(0.12))
		# light streaks
		for i in 4:
			var x := fmod(_t * 40.0 + i * 90.0, w + 120.0) - 60.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 5), Vector2(x + 18, 5), Vector2(x - 40, h - 5), Vector2(x - 58, h - 5)]), Color(1, 1, 1, 0.06))
		# header strip
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, 54)), Color(0, 0, 0, 0.35))
		UIKit.draw_icon(self, "clock", Vector2(24, 30), 26.0)
		S.text_l(self, "NEW MAP IN " + Progression.map_time_left(), Vector2(42, 38), 15, Color("dff4ff"))
		# emblem
		var ec := Vector2(w * 0.5, 120)
		var bob := sin(_t * 2.0) * 3.0
		UIKit.draw_icon(self, m.get("icon", "mode_gem"), ec + Vector2(0, bob), 104.0)
		# mini map preview
		var grid: Array = MapData.build_grid(map_id)
		var th: Dictionary = MapData.MAPS[map_id].theme
		var cell := 5.0 if grid.size() < 34 else 3.4
		var gw: int = grid[0].size()
		var gh: int = grid.size()
		var mw := gw * cell
		var mh := gh * cell
		var mp := Vector2(w * 0.5 - mw * 0.5, 180)
		var prev_h := 165.0
		var sy := prev_h / mh
		draw_rect(Rect2(mp - Vector2(4, 4), Vector2(mw + 8, prev_h + 8)), ink)
		for r in gh:
			for c in gw:
				var ch: String = grid[r][c]
				var col: Color = th.floor_a
				match ch:
					"#": col = th.wall_top
					"B": col = th.bush
					"W": col = th.water
					"C": col = th.crate
					"A": col = Config.TEAM_COLORS[0]
					"R": col = Config.TEAM_COLORS[1]
					"G": col = Color("b25bff")
				draw_rect(Rect2(mp + Vector2(c * cell, r * cell * sy), Vector2(cell, cell * sy + 0.5)), col)
		# names
		S.text_c(self, m.name, Vector2(w * 0.5, h - 70), 26, Color.WHITE)
		S.text_c(self, MapData.MAPS[map_id].name, Vector2(w * 0.5, h - 42), 18, Color("ffe14d"))
		var nm := Progression.next_map(mode_id)
		if nm != map_id:
			S.text_c(self, "NEXT: " + MapData.MAPS[nm].name, Vector2(w * 0.5, h - 16), 13, Color(1, 1, 1, 0.7))
		if sel:
			draw_rect(Rect2(Vector2(w * 0.5 - 70, 64), Vector2(140, 26)), ink)
			S.text_c(self, "SELECTED", Vector2(w * 0.5, 84), 16, Color("4dff7a"))


class SectionFrame extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var S := preload("res://scripts/ui/main_menu.gd").SlantButton
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r.grow(3), UIKit.DARK)
		draw_rect(r, Color(0.1, 0.2, 0.45, 0.6))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 40)), Color(0.05, 0.1, 0.3, 0.8))
		S.text_c(self, "ARENA EVENTS", Vector2(size.x * 0.5, 30), 22, Color.WHITE)


class TabBarBg extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UIKit.DARK)
		draw_rect(Rect2(Vector2(0, 3), size), Color("1b2a52"))


class TabButton extends Button:
	var label := ""
	var on := false

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())

	func _draw() -> void:
		var S := preload("res://scripts/ui/main_menu.gd").SlantButton
		S.text_c(self, label, Vector2(size.x * 0.5, size.y * 0.5 + 8), 20, Color("ffe14d") if on else Color(1, 1, 1, 0.75))
		if on:
			draw_rect(Rect2(Vector2(20, size.y - 6), Vector2(size.x - 40, 5)), Color("ffe14d"))
