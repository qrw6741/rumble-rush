extends Control
## Account sync: copy a transfer code on one device, paste it on the other.
## On the web/iPhone, copying and pasting go through the browser's own text box
## (Safari only allows clipboard access that way).

var _status: Label
var _code_box: TextEdit

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.15, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(760, 0)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UIKit.label("ACCOUNT SYNC", 34, UIKit.YELLOW, 8, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.body("Move your progress between PC and iPhone:\n1.  On the device WITH your progress, tap COPY MY CODE.\n2.  Send the code to yourself (Notes, WhatsApp, email...).\n3.  On the other device, tap LOAD A CODE and paste it.\nThis replaces the progress on the device you load it on.", 16))
	var lvl := Save.account_level()
	v.add_child(UIKit.label("THIS DEVICE:  %s  ·  LEVEL %d  ·  %d TROPHIES" % [String(Save.data.username), lvl, Save.total_trophies()], 16, Color("8fd0ff"), 5, HORIZONTAL_ALIGNMENT_CENTER))
	_code_box = TextEdit.new()
	_code_box.custom_minimum_size = Vector2(700, 110)
	_code_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_code_box.placeholder_text = "Your code will appear here, or paste a code here."
	_code_box.add_theme_font_size_override("font_size", 13)
	v.add_child(_code_box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var cp := UIKit.button("COPY MY CODE", UIKit.GREEN, 20, Vector2(250, 60))
	cp.pressed.connect(_copy)
	row.add_child(cp)
	var ld := UIKit.button("LOAD A CODE", UIKit.ORANGE, 20, Vector2(250, 60))
	ld.pressed.connect(_load)
	row.add_child(ld)
	var close := UIKit.button("CLOSE", Color("6b5f86"), 20, Vector2(170, 60))
	close.pressed.connect(queue_free)
	row.add_child(close)
	_status = UIKit.label("", 17, Color.WHITE, 5, HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.custom_minimum_size = Vector2(700, 0)
	v.add_child(_status)
	UIKit.pop_in(p)

func _say(t: String, col := Color.WHITE) -> void:
	_status.text = t
	_status.add_theme_color_override("font_color", col)

func _copy() -> void:
	var code := Save.export_code()
	_code_box.text = code
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{navigator.clipboard&&navigator.clipboard.writeText(%s)}catch(e){}" % JSON.stringify(code), true)
		JavaScriptBridge.eval("window.prompt('Your Rumble Rush code (select all and copy):', %s)" % JSON.stringify(code), true)
	else:
		DisplayServer.clipboard_set(code)
	_say("Code copied! (%d characters)  Now paste it on your other device." % code.length(), Color("7dff8a"))
	Sfx.play("ui_confirm")

func _load() -> void:
	var code := _code_box.text.strip_edges()
	if not code.begins_with(Save.TRANSFER_PREFIX):
		if OS.has_feature("web"):
			var got = JavaScriptBridge.eval("window.prompt('Paste your Rumble Rush code:', '')||''", true)
			code = String(got) if got != null else ""
		else:
			code = DisplayServer.clipboard_get().strip_edges()
	if code == "":
		_say("Paste your code first.", Color("ffb070"))
		return
	_confirm(code)

func _confirm(code: String) -> void:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(c)
	var p := UIKit.panel()
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UIKit.label("REPLACE THIS DEVICE'S PROGRESS?", 26, UIKit.RED, 8, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("The progress on this device will be overwritten by the code.", 16, Color.WHITE, 4, HORIZONTAL_ALIGNMENT_CENTER))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	var no := UIKit.button("CANCEL", Color("6b5f86"), 20, Vector2(180, 56))
	no.pressed.connect(o.queue_free)
	h.add_child(no)
	var yes := UIKit.button("LOAD IT", UIKit.GREEN, 20, Vector2(180, 56))
	yes.pressed.connect(func():
		o.queue_free()
		var err := Save.import_code(code)
		if err != "":
			_say(err, Color("ff8a7a"))
			Sfx.play("ui_error")
			return
		Sfx.play("victory", -2.0, 0.0)
		_say("Progress loaded!", Color("7dff8a"))
		await get_tree().create_timer(0.8).timeout
		Router.goto("menu"))
	h.add_child(yes)
	add_child(o)
