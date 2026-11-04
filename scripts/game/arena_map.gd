class_name ArenaMap
extends Node2D

signal crate_broken(pos: Vector2)
## Builds a map from MapData: floor art, collision, walls/crates (as y-sorted
## entities), bushes, water, spawn points and an AStar grid for bot navigation.

const T := 48.0

var map_id := ""
var grid: Array = []
var theme: Dictionary = {}
var astar := AStarGrid2D.new()
var blue_spawns: Array[Vector2] = []
var red_spawns: Array[Vector2] = []
var gem_mine := Vector2.ZERO
var crates: Dictionary = {} # Vector2i -> Crate
var bush_cells: Dictionary = {} # Vector2i -> true
var size_px := Vector2.ZERO
var w := 21
var h := 33
var ffa_spawns: Array[Vector2] = []
var _decals: Array = []
var _water_node: Node2D

var flat := false # "2D map" setting: everything drawn flat from straight above, in one pass

func build(id: String, entity_layer: Node2D, bush_layer: Node2D) -> void:
	map_id = id
	flat = Save.setting("map_view") == "2d"
	theme = MapData.MAPS[id].theme
	grid = MapData.build_grid(id)
	h = grid.size()
	w = grid[0].size()
	size_px = Vector2(w * T, h * T)
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(T, T)
	astar.offset = Vector2(T * 0.5, T * 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var walls_body := StaticBody2D.new()
	walls_body.collision_layer = 1
	walls_body.collision_mask = 0
	add_child(walls_body)
	var water_body := StaticBody2D.new()
	water_body.collision_layer = 2
	water_body.collision_mask = 0
	add_child(water_body)

	for r in h:
		var c := 0
		while c < w:
			var ch: String = grid[r][c]
			var cell := Vector2i(c, r)
			var center := cell_center(cell)
			match ch:
				"#":
					# merge horizontal wall runs into one collision rectangle
					var run := 1
					while c + run < w and grid[r][c + run] == "#":
						run += 1
					_add_rect(walls_body, Vector2(c * T, r * T), Vector2(run * T, T))
					for k in run:
						if not flat:
							var wb := WallBlock.new()
							wb.setup(Vector2i(c + k, r), theme, _wall_neighbors(c + k, r))
							entity_layer.add_child(wb)
						astar.set_point_solid(Vector2i(c + k, r), true)
					c += run
					continue
				"W":
					_add_rect(water_body, Vector2(c * T, r * T), Vector2(T, T))
					astar.set_point_solid(cell, true)
				"C":
					var cr := Crate.new()
					cr.setup(self, cell, theme)
					entity_layer.add_child(cr)
					crates[cell] = cr
					astar.set_point_solid(cell, true)
				"B":
					bush_cells[cell] = true
				"A":
					blue_spawns.append(center)
				"R":
					red_spawns.append(center)
				"G":
					gem_mine = center
			if ch == "." and rng.randf() < 0.12:
				var kind := rng.randi() % 3
				if theme.get("bones", false) and rng.randf() < 0.45:
					kind = 3
				_decals.append([center + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14)), rng.randf_range(3, 7), kind, rng.randf() * TAU])
			c += 1
	# decorative 3D fence ring around the arena (collision is the boundary below)
	for bc in range(-1, w + 1):
		for br in [-1, h]:
			_add_border_block(entity_layer, bc, br)
	for br in range(0, h):
		for bc in [-1, w]:
			_add_border_block(entity_layer, bc, br)
	# outer boundary walls
	_add_rect(walls_body, Vector2(-T * 2, -T * 2), Vector2(size_px.x + T * 4, T * 2))
	_add_rect(walls_body, Vector2(-T * 2, size_px.y), Vector2(size_px.x + T * 4, T * 2))
	_add_rect(walls_body, Vector2(-T * 2, 0), Vector2(T * 2, size_px.y))
	_add_rect(walls_body, Vector2(size_px.x, 0), Vector2(T * 2, size_px.y))
	if gem_mine == Vector2.ZERO:
		gem_mine = size_px * 0.5
	# free-for-all maps: 10 spawns evenly around a ring
	if MapData.MAPS[id].get("kind", "") == "quad":
		for k in 10:
			var a := -PI / 2 + k * TAU / 10.0
			var p := size_px * 0.5 + Vector2(cos(a), sin(a)) * size_px.x * 0.4
			ffa_spawns.append(cell_center(nearest_walkable(p)))

	# sort spawns so index 0 is the middle one (the player's spot)
	blue_spawns.sort_custom(func(a, b): return absf(a.x - size_px.x * 0.5) < absf(b.x - size_px.x * 0.5))
	red_spawns.sort_custom(func(a, b): return absf(a.x - size_px.x * 0.5) < absf(b.x - size_px.x * 0.5))

	_water_node = WaterLayer.new()
	_water_node.setup(self)
	add_child(_water_node)

	var bushes := BushLayer.new()
	bushes.setup(self)
	bush_layer.add_child(bushes)
	if flat:
		_bake_flat()
	queue_redraw()

## Paints the whole flat map ONCE into a texture: as much detail as we like,
## and only a single quad to draw every frame afterwards.
func _bake_flat() -> void:
	var pad := T * 3.0
	var full := size_px + Vector2(pad, pad) * 2.0
	# phones/browsers have tight memory limits: keep the painted map under 2048 px
	var phone := OS.has_feature("web") or OS.has_feature("mobile")
	var k := minf(1.0, 2048.0 / maxf(full.x, full.y)) if phone else clampf(4000.0 / maxf(full.x, full.y), 1.0, 2.0)
	var vp := SubViewport.new()
	vp.size = Vector2i(int(full.x * k), int(full.y * k))
	vp.canvas_transform = Transform2D.IDENTITY.scaled(Vector2(k, k))
	vp.transparent_bg = false
	vp.msaa_2d = Viewport.MSAA_DISABLED if phone else Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.disable_3d = true
	var painter := FlatPainter.new()
	painter.map = self
	painter.position = Vector2(pad, pad)
	vp.add_child(painter)
	add_child(vp)
	var spr := Sprite2D.new()
	spr.texture = vp.get_texture()
	spr.centered = false
	spr.position = Vector2(-pad, -pad)
	spr.scale = Vector2.ONE / k
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(spr)
	move_child(spr, 0)
	# keep only a plain texture: copy the painted result and free the render target
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vp):
		return
	var img := vp.get_texture().get_image()
	if img:
		spr.texture = ImageTexture.create_from_image(img)
	vp.queue_free()

func _add_border_block(layer: Node2D, c: int, r: int) -> void:
	if flat:
		return
	var wb := WallBlock.new()
	wb.setup(Vector2i(c, r), theme, _wall_neighbors(c, r))
	if r == h:
		wb.position.y += WallBlock.LIFT # keep the near fence from covering the last row
	layer.add_child(wb)

func _wall_neighbors(c: int, r: int) -> Dictionary:
	return {
		"up": is_wall_char(c, r - 1), "down": is_wall_char(c, r + 1),
		"left": is_wall_char(c - 1, r), "right": is_wall_char(c + 1, r),
	}

func is_wall_char(c: int, r: int) -> bool:
	if c < 0 or r < 0 or c >= w or r >= h:
		# the decorative border ring counts as wall so edges merge cleanly
		return c >= -1 and r >= -1 and c <= w and r <= h
	return grid[r][c] == "#"

func _add_rect(body: StaticBody2D, top_left: Vector2, size: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	cs.position = top_left + size * 0.5
	body.add_child(cs)

func cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * T, (cell.y + 0.5) * T)

func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x / T)), 0, w - 1), clampi(int(floor(p.y / T)), 0, h - 1))

func in_bounds(p: Vector2) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < size_px.x and p.y < size_px.y

func is_bush(p: Vector2) -> bool:
	return in_bounds(p) and bush_cells.has(world_to_cell(p))

func is_walkable_cell(cell: Vector2i) -> bool:
	return astar.is_in_boundsv(cell) and not astar.is_point_solid(cell)

func crate_destroyed(cell: Vector2i) -> void:
	crate_broken.emit(cell_center(cell))
	crates.erase(cell)
	grid[cell.y][cell.x] = "."
	astar.set_point_solid(cell, false)

## Nearest walkable cell to a world position (used when a target sits on a solid tile).
func nearest_walkable(p: Vector2) -> Vector2i:
	var cell := world_to_cell(p)
	if is_walkable_cell(cell):
		return cell
	for radius in range(1, 5):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var cc := cell + Vector2i(dx, dy)
				if is_walkable_cell(cc):
					return cc
	return cell

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := nearest_walkable(from)
	var b := nearest_walkable(to)
	if a == b:
		return PackedVector2Array([to])
	return astar.get_point_path(a, b)

func _draw() -> void:
	if flat:
		return # the painted map texture (see _bake_flat) does all the work
	var th := theme
	# outside the arena
	draw_rect(Rect2(-T * 12, -T * 12, size_px.x + T * 24, size_px.y + T * 24), th.bg)
	# bevelled floor tiles with gentle colour variation
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(map_id) + 99
	for r in h:
		for c in w:
			var base: Color = th.floor_a if (r + c) % 2 == 0 else th.floor_b
			base = base.lightened(rng.randf_range(-0.02, 0.03))
			var rect := Rect2(c * T, r * T, T, T)
			draw_rect(rect, base)
			draw_rect(Rect2(rect.position, Vector2(T, 3)), base.lightened(0.12))
			draw_rect(Rect2(rect.position, Vector2(3, T)), base.lightened(0.07))
			draw_rect(Rect2(rect.position + Vector2(0, T - 3), Vector2(T, 3)), base.darkened(0.1))
			draw_rect(Rect2(rect.position + Vector2(T - 3, 0), Vector2(3, T)), base.darkened(0.07))
	# decals (pebbles / cracks / city bolts)
	for d in _decals:
		var p: Vector2 = d[0]
		var s: float = d[1]
		var col: Color = th.decal
		match int(d[2]):
			0:
				draw_circle(p, s, col)
				draw_circle(p + Vector2(s * 1.4, s * 0.4), s * 0.6, col)
			1:
				draw_polyline(PackedVector2Array([p, p + Vector2(s, s * 0.6), p + Vector2(s * 1.6, -s * 0.3), p + Vector2(s * 2.6, s * 0.4)]), col, 2.0, true)
			3:
				# a sun-bleached bone
				var rot: float = d[3]
				var dir := Vector2(cos(rot), sin(rot)) * s * 1.6
				var ink := Color("1a1028")
				draw_line(p - dir, p + dir, ink, 7.0, true)
				for e in [p - dir, p + dir]:
					for o in [-1, 1]:
						draw_circle(e + dir.orthogonal().normalized() * 3.0 * o, 4.5, ink)
				draw_line(p - dir, p + dir, Color("fff6e0"), 3.5, true)
				for e in [p - dir, p + dir]:
					for o in [-1, 1]:
						draw_circle(e + dir.orthogonal().normalized() * 3.0 * o, 3.0, Color("fff6e0"))
			_:
				draw_rect(Rect2(p - Vector2(s, s * 0.4), Vector2(s * 2, s * 0.8)), col)
	# soft cast shadows (light from the top-left)
	var sh := Color(0, 0, 0, 0.2)
	for r in range(-1, h + 1):
		for c in range(-1, w + 1):
			if not is_wall_char(c, r):
				continue
			var x := c * T
			var y := r * T
			if not is_wall_char(c + 1, r):
				draw_colored_polygon(PackedVector2Array([Vector2(x + T, y - 4), Vector2(x + T + 16, y + 10), Vector2(x + T + 16, y + T + 12), Vector2(x + T, y + T)]), sh)
			if not is_wall_char(c, r + 1):
				draw_colored_polygon(PackedVector2Array([Vector2(x, y + T), Vector2(x + T, y + T), Vector2(x + T + 16, y + T + 12), Vector2(x + 12, y + T + 12)]), sh)
	for bc in bush_cells.keys():
		var bp := cell_center(bc) + Vector2(8, 14)
		var pts := PackedVector2Array()
		for i in 20:
			var ang := TAU * i / 20.0
			pts.append(bp + Vector2(cos(ang) * 26, sin(ang) * 16))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.16))
	# team spawn pads
	for sp in blue_spawns:
		_spawn_pad(sp, Config.TEAM_COLORS[0])
	for sp in red_spawns:
		_spawn_pad(sp, Config.TEAM_COLORS[1])
	# half line
	var hl: Color = th.floor_edge
	hl.a = 0.5
	var y := size_px.y * 0.5
	var x := 0.0
	while x < size_px.x:
		draw_line(Vector2(x, y), Vector2(x + 18, y), hl, 3.0)
		x += 32

func _spawn_pad(p: Vector2, col: Color) -> void:
	var c := col
	c.a = 0.22
	draw_circle(p, 24, c)
	c.a = 0.6
	draw_arc(p, 24, 0, TAU, 32, c, 3.0, true)


## Draws the detailed flat map onto `ci` (called once by FlatPainter).
func paint_flat(ci: CanvasItem) -> void:
	var th := theme
	var ink := Color("1a1028")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(map_id) + 7
	var pad := T * 3.0
	# surroundings: darker ground with soft blobs
	ci.draw_rect(Rect2(-pad, -pad, size_px.x + pad * 2, size_px.y + pad * 2), th.bg)
	for i in 60:
		var p := Vector2(rng.randf_range(-pad, size_px.x + pad), rng.randf_range(-pad, size_px.y + pad))
		ci.draw_circle(p, rng.randf_range(10, 34), th.bg.lightened(rng.randf_range(-0.06, 0.06)))
	# floor tiles: soft per-tile tint, speckles and rounded grout
	for r in h:
		for c in w:
			var base: Color = th.floor_a if (r + c) % 2 == 0 else th.floor_b
			base = base.lightened(rng.randf_range(-0.025, 0.035))
			var rect := Rect2(c * T, r * T, T, T)
			ci.draw_rect(rect, base.darkened(0.07))
			ci.draw_rect(rect.grow(-1.5), base)
			ci.draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(T - 4, 6)), base.lightened(0.05))
			for k in 4:
				var sp := rect.position + Vector2(rng.randf_range(5, T - 5), rng.randf_range(5, T - 5))
				ci.draw_circle(sp, rng.randf_range(0.8, 2.0), base.darkened(rng.randf_range(0.05, 0.12)))
	# decals: pebbles, cracks, bones
	for d in _decals:
		var p: Vector2 = d[0]
		var sz: float = d[1]
		var col: Color = th.decal
		match int(d[2]):
			0:
				ci.draw_circle(p + Vector2(1, 2), sz, col.darkened(0.25))
				ci.draw_circle(p, sz, col)
				ci.draw_circle(p - Vector2(sz * 0.3, sz * 0.3), sz * 0.35, col.lightened(0.25))
			1:
				ci.draw_polyline(PackedVector2Array([p, p + Vector2(sz, sz * 0.6), p + Vector2(sz * 1.6, -sz * 0.3), p + Vector2(sz * 2.6, sz * 0.4)]), col.darkened(0.2), 2.0, true)
			3:
				var rot: float = d[3]
				var dir := Vector2(cos(rot), sin(rot)) * sz * 1.6
				ci.draw_line(p - dir + Vector2(2, 3), p + dir + Vector2(2, 3), Color(0, 0, 0, 0.18), 7.0, true)
				ci.draw_line(p - dir, p + dir, Color("fff6e0"), 4.0, true)
				for e in [p - dir, p + dir]:
					for o in [-1, 1]:
						ci.draw_circle(e + dir.orthogonal().normalized() * 3.0 * o, 3.2, Color("fff6e0"))
			_:
				ci.draw_circle(p, sz * 0.7, col)
	# grass tufts along the floor edge of grassy maps
	if th.get("grass", false):
		for i in 140:
			var gp := Vector2(rng.randf_range(0, size_px.x), rng.randf_range(0, size_px.y))
			if is_wall_char(int(gp.x / T), int(gp.y / T)):
				continue
			var gc := Color("9fbf5a").lerp(th.floor_a, 0.35)
			for b in 3:
				var tip := gp + Vector2(-4 + b * 4, -6 - (b % 2) * 3)
				ci.draw_line(gp + Vector2(-2 + b * 2, 0), tip, gc, 1.6, true)
	# spawn pads + half line
	for sp2 in blue_spawns:
		_spawn_pad_on(ci, sp2, Config.TEAM_COLORS[0])
	for sp2 in red_spawns:
		_spawn_pad_on(ci, sp2, Config.TEAM_COLORS[1])
	var hl: Color = th.floor_edge
	hl.a = 0.45
	var y := size_px.y * 0.5
	var x := 0.0
	while x < size_px.x:
		ci.draw_line(Vector2(x, y), Vector2(x + 18, y), hl, 3.0, true)
		x += 32
	# soft drop shadows from walls (down-right), layered for a smooth falloff
	for layer in 4:
		var off := 4.0 + layer * 4.0
		var sh := Color(0.1, 0.05, 0.15, 0.07)
		for r in range(-1, h + 1):
			for c in range(-1, w + 1):
				if is_wall_char(c, r):
					ci.draw_rect(Rect2(c * T + off * 0.6, r * T + off, T, T), sh)
	# ambient occlusion: floor darkens softly right next to walls
	for r in h:
		for c in w:
			if is_wall_char(c, r):
				continue
			var x0 := c * T
			var y0 := r * T
			for k in 4:
				var a := 0.09 - k * 0.02
				var o := k * 3.0
				if is_wall_char(c, r - 1):
					ci.draw_rect(Rect2(x0, y0 + o, T, 3), Color(0, 0, 0, a))
				if is_wall_char(c - 1, r):
					ci.draw_rect(Rect2(x0 + o, y0, 3, T), Color(0, 0, 0, a))
				if is_wall_char(c + 1, r):
					ci.draw_rect(Rect2(x0 + T - 3 - o, y0, 3, T), Color(0, 0, 0, a))
	# walls: bevelled stone tops with block pattern
	var top: Color = th.wall_top
	var line_c: Color = th.wall_line
	for r in range(-1, h + 1):
		for c in range(-1, w + 1):
			if not is_wall_char(c, r):
				continue
			var rect := Rect2(c * T, r * T, T, T)
			ci.draw_rect(rect, top)
			# gentle vertical gradient
			for k in 6:
				ci.draw_rect(Rect2(rect.position.x, rect.position.y + k * T / 6.0, T, T / 6.0 + 0.5), Color(1, 1, 1, 0.07 - k * 0.018))
			# stone blocks: offset rows
			var stone := top.darkened(0.12)
			ci.draw_line(Vector2(rect.position.x, rect.position.y + T * 0.5), Vector2(rect.end.x, rect.position.y + T * 0.5), stone, 2.0)
			var ox := T * (0.5 if (r + 100) % 2 == 0 else 0.25)
			ci.draw_line(Vector2(rect.position.x + ox, rect.position.y + 2), Vector2(rect.position.x + ox, rect.position.y + T * 0.5), stone, 2.0)
			ci.draw_line(Vector2(rect.position.x + fmod(ox + T * 0.5, T), rect.position.y + T * 0.5), Vector2(rect.position.x + fmod(ox + T * 0.5, T), rect.end.y - 2), stone, 2.0)
			if rng.randf() < 0.25:
				var cp := rect.position + Vector2(rng.randf_range(8, T - 8), rng.randf_range(8, T - 8))
				ci.draw_polyline(PackedVector2Array([cp, cp + Vector2(5, 4), cp + Vector2(3, 10)]), stone.darkened(0.1), 1.5, true)
	# bevel + ink only where a wall meets open floor
	for r in range(-1, h + 1):
		for c in range(-1, w + 1):
			if not is_wall_char(c, r):
				continue
			var x0 := c * T
			var y0 := r * T
			if not is_wall_char(c, r - 1):
				ci.draw_rect(Rect2(x0, y0 + 2, T, 5), line_c.lerp(top, 0.4))
				ci.draw_line(Vector2(x0, y0), Vector2(x0 + T, y0), ink, 4.0, true)
			if not is_wall_char(c, r + 1):
				ci.draw_rect(Rect2(x0, y0 + T - 10, T, 10), th.wall_side)
				ci.draw_rect(Rect2(x0, y0 + T - 10, T, 2), th.wall_side.lightened(0.2))
				ci.draw_line(Vector2(x0, y0 + T), Vector2(x0 + T, y0 + T), ink, 4.0, true)
			if not is_wall_char(c - 1, r):
				ci.draw_rect(Rect2(x0 + 2, y0, 4, T), line_c.lerp(top, 0.6))
				ci.draw_line(Vector2(x0, y0), Vector2(x0, y0 + T), ink, 4.0, true)
			if not is_wall_char(c + 1, r):
				ci.draw_rect(Rect2(x0 + T - 6, y0, 4, T), top.darkened(0.15))
				ci.draw_line(Vector2(x0 + T, y0), Vector2(x0 + T, y0 + T), ink, 4.0, true)

func _spawn_pad_on(ci: CanvasItem, p: Vector2, col: Color) -> void:
	var c2 := col
	c2.a = 0.22
	ci.draw_circle(p, 30, c2)
	ci.draw_arc(p, 30, 0, TAU, 40, Color(col.r, col.g, col.b, 0.7), 3.0, true)
	ci.draw_arc(p, 20, 0, TAU, 32, Color(col.r, col.g, col.b, 0.4), 2.0, true)


class FlatPainter extends Node2D:
	var map: ArenaMap
	func _draw() -> void:
		map.paint_flat(self)
