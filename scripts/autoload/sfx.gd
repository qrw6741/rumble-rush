extends Node
## Audio manager: pooled sound effects with distance attenuation, and looping music
## with crossfades. Uses dedicated Music / SFX buses so volumes are independent.

const SOUNDS := [
	"shoot_hammer", "shoot_blade", "shoot_rifle", "shoot_heal", "shoot_lob",
	"hit", "heal_hit", "crate_break", "explosion", "slam", "ko",
	"beam", "dash", "super_cast", "super_ready", "gadget", "heal_field", "root", "shield",
	"gem_pickup", "gem_drop", "ui_click", "ui_confirm", "ui_error", "beep", "go", "respawn", "tick",
	"victory", "defeat", "draw",
]
const POOL_SIZE := 20

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: AudioStreamPlayer
var _music_name := ""
var _music_tween: Tween
var _last_played: Dictionary = {} # name -> msec, to avoid stacking identical sounds
var listener_pos := Vector2.ZERO
var listener_active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for n in SOUNDS:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for m in ["music_menu", "music_battle"]:
		var mp := "res://assets/audio/%s.wav" % m
		if ResourceLoader.exists(mp):
			_streams[m] = load(mp)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_music_current = _music_a
	apply_volumes()

func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80
	add_child(p)
	p.finished.connect(func(): if p == _music_current and _music_name != "": p.play())
	return p

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")

func apply_volumes() -> void:
	if not is_instance_valid(Save) or Save.data.is_empty():
		return
	_set_bus_linear("Music", float(Save.setting("music_volume")))
	_set_bus_linear("SFX", float(Save.setting("sfx_volume")))

func _set_bus_linear(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(v, 0.001)))

## Play a sound. pitch_var randomizes pitch a little so repeats don't sound robotic.
func play(sound: String, volume_db := 0.0, pitch_var := 0.06, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	var now := Time.get_ticks_msec()
	if _last_played.has(sound) and now - int(_last_played[sound]) < 35:
		return
	_last_played[sound] = now
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_var, pitch_var))
	p.play()

## Play a sound that gets quieter the further it is from the camera.
func play_at(sound: String, pos: Vector2, volume_db := 0.0, pitch_var := 0.06) -> void:
	if listener_active:
		var dist := pos.distance_to(listener_pos)
		if dist > 1400.0:
			return
		volume_db += lerpf(0.0, -18.0, clampf(dist / 1400.0, 0.0, 1.0))
	play(sound, volume_db, pitch_var)

func play_music(track: String, fade := 0.8) -> void:
	if track == _music_name or not _streams.has(track):
		return
	_music_name = track
	var old := _music_current
	var nxt := _music_b if _music_current == _music_a else _music_a
	_music_current = nxt
	nxt.stream = _streams[track]
	nxt.volume_db = -40
	nxt.play()
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(nxt, "volume_db", -6.0, fade)
	_music_tween.tween_property(old, "volume_db", -80.0, fade)
	_music_tween.chain().tween_callback(old.stop)

func stop_music(fade := 0.6) -> void:
	_music_name = ""
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_current, "volume_db", -80.0, fade)
	_music_tween.tween_callback(_music_current.stop)
