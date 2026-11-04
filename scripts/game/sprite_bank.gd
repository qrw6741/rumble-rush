class_name SpriteBank
extends RefCounted
## Pre-renders each brawler's 3D model once into a set of sprite frames
## (8 facing directions x idle/walk/attack poses). Battles then show these frames
## instead of rendering 3D every frame, which is far cheaper on phones.

const DIRS := 8
const FRAMES := 7              # 0 idle | 1-4 walk cycle | 5-6 attack recoil
const MAX_CACHED := 10
const MAX_CACHED_PHONE := 5

static var cache: Dictionary = {}   # key -> {"frames": [[Texture2D]], "feet": Vector2, "px_scale": float}
static var _order: Array = []
static var _busy := false

static func key(id: String, skin: String) -> String:
	return "%s|%s|%s" % [id, skin, "low" if Save.low_graphics() else "high"]

static func get_set(id: String, skin: String):
	return cache.get(key(id, skin))

static func can_bake() -> bool:
	return DisplayServer.get_name() != "headless"

## Bakes every (brawler, skin) combo not cached yet. Await this.
static func bake(host: Node, combos: Array, px: int) -> void:
	if not can_bake():
		return
	while _busy:
		await host.get_tree().process_frame
	_busy = true
	for combo in combos:
		var k := key(combo[0], combo[1])
		if cache.has(k) or not is_instance_valid(host):
			continue
		var views: Array[BrawlerView] = []
		for d in DIRS:
			var v := BrawlerView.create(combo[0], "battle", px, true, combo[1])
			v.msaa_3d = Viewport.MSAA_2X if (OS.has_feature("web") or OS.has_feature("mobile")) else Viewport.MSAA_4X
			v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			host.add_child(v)
			views.append(v)
		var frames: Array = []
		for d in DIRS:
			frames.append([])
		for f in FRAMES:
			for d in DIRS:
				var yaw := TAU * float(d) / DIRS
				views[d].model.animate(0.0, _pose(f, yaw))
			await RenderingServer.frame_post_draw
			if not is_instance_valid(host):
				_busy = false
				return
			for d in DIRS:
				var img := views[d].get_texture().get_image()
				if img == null or img.is_empty():
					for v in views:
						v.queue_free()
					_busy = false
					return
				frames[d].append(ImageTexture.create_from_image(img))
		cache[k] = {"frames": frames, "feet": views[0].feet_px, "px_scale": views[0].px_scale}
		_order.append(k)
		for v in views:
			v.queue_free()
		var cap := MAX_CACHED_PHONE if (OS.has_feature("web") or OS.has_feature("mobile")) else MAX_CACHED
		while _order.size() > cap:
			cache.erase(_order.pop_front())
	_busy = false

static func _pose(f: int, yaw: float) -> Dictionary:
	match f:
		0:
			return {"t": 0.0, "moving": false, "recoil": 0.0, "yaw": yaw, "instant": true}
		5:
			return {"t": 0.0, "moving": false, "recoil": 1.0, "yaw": yaw, "instant": true}
		6:
			return {"t": 0.0, "moving": false, "recoil": 0.5, "yaw": yaw, "instant": true}
		_:
			# walk cycle: four phases of the 12 rad/s leg swing
			var phase := float(f - 1) * (PI / 2.0) + PI / 4.0
			return {"t": phase / 12.0, "moving": true, "recoil": 0.0, "yaw": yaw, "instant": true}

## Picks the frame for a direction (radians, 0 = facing camera) and pose.
static func frame_for(set: Dictionary, yaw: float, moving: bool, recoil: float, t: float) -> Texture2D:
	var d := int(round(fposmod(yaw, TAU) / (TAU / DIRS))) % DIRS
	var f := 0
	if recoil > 0.55:
		f = 5
	elif recoil > 0.12:
		f = 6
	elif moving:
		f = 1 + int(t * 10.0) % 4
	return set.frames[d][f]
