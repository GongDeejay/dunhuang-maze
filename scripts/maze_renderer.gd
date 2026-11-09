class_name MazeRenderer
extends RefCounted

const FAMILY_KEY_TO_SPRITE := AssetRegistry.FAMILY_KEY_TO_SPRITE
const JourneyBranches = preload("res://scripts/journey_branches.gd")

var cell_size: int = 40
var wall_thickness: int = 4
var item_sprites: Dictionary = {}
var terrain_sprites: Dictionary = {}
var player_sprite: Texture2D
var family_sprites: Array[Texture2D] = []
var family_sprite_map: Dictionary = {}
var _sprite_cache: Dictionary = {}

func load_sprites() -> void:
	player_sprite = _load_character_sprite("dj")
	family_sprites = [
		_load_character_sprite("le"),
		_load_character_sprite("mac"),
		_load_character_sprite("mcking"),
	]
	family_sprite_map = {
		"family_1": family_sprites[0],
		"family_2": family_sprites[1],
		"family_3": family_sprites[2],
	}
	item_sprites = {}
	for item_type in AssetRegistry.ITEM_TYPE_FILES:
		var path := AssetRegistry.item_sprite_path(item_type)
		if ResourceLoader.exists(path):
			item_sprites[item_type] = load(path)
	item_sprites["key"] = family_sprites[0]
	terrain_sprites = {}
	for t_key in AssetRegistry.TERRAIN_FILES:
		var path := AssetRegistry.terrain_sprite_path(t_key)
		if ResourceLoader.exists(path):
			terrain_sprites[t_key] = load(path)
	_load_terrain_variants()

func _load_character_sprite(name: String) -> Texture2D:
	var path := AssetRegistry.character_sprite_path(name, true)
	if ResourceLoader.exists(path):
		return load(path)
	return null

func get_family_sprite(item_key: String) -> Texture2D:
	if family_sprite_map.has(item_key):
		return family_sprite_map[item_key]
	return family_sprites[0] if not family_sprites.is_empty() else null

func draw_sprite_in_cell(
	canvas: CanvasItem,
	texture: Texture2D,
	cell_origin: Vector2,
	cell_sz: float,
	padding: float,
) -> void:
	if texture == null:
		return
	var inner := cell_sz - padding * 2.0
	canvas.draw_texture_rect(texture, Rect2(cell_origin + Vector2(padding, padding), Vector2(inner, inner)), false)

func _load_terrain_variants() -> void:
	for key in AssetRegistry.TERRAIN_VARIANTS:
		var path := AssetRegistry.terrain_sprite_path(key)
		if ResourceLoader.exists(path):
			terrain_sprites[key] = load(path)

func get_terrain_sprite(maze: MazeGenerator, x: int, y: int) -> Texture2D:
	var t_key: String = MazeGenerator.TERRAIN_KEY[maze.get_terrain(x, y)]
	var cell: int = maze.grid[y][x]
	var openings := 0
	for bit in [MazeGenerator.N, MazeGenerator.S, MazeGenerator.E, MazeGenerator.W]:
		if cell & bit:
			openings += 1

	if t_key == "ancient_road":
		if openings >= 3:
			return terrain_sprites.get("ancient_road_cross", terrain_sprites.get("ancient_road"))
		if openings == 2:
			return terrain_sprites.get("ancient_road_cross_l", terrain_sprites.get("ancient_road"))
	elif t_key == "grotto":
		if openings >= 3:
			return terrain_sprites.get("grotto_cross", terrain_sprites.get("grotto"))
		if openings == 2:
			return terrain_sprites.get("grotto_cross_l", terrain_sprites.get("grotto"))
	elif t_key == "oasis":
		var hash_val := (x * 73856093 ^ y * 19349663) % 6
		if hash_val == 0:
			return terrain_sprites.get("oasis_pond", terrain_sprites.get("oasis"))
		if hash_val == 1:
			return terrain_sprites.get("oasis_tree", terrain_sprites.get("oasis"))

	return terrain_sprites.get(t_key)

func draw_pc_view(
	canvas: CanvasItem,
	maze_rect: Rect2,
	hud_rect: Rect2,
	ui_scale: float,
	maze: MazeGenerator,
	maze_width: int,
	maze_height: int,
	player: PlayerController,
	monsters: Array,
	items: Array,
	exit_pos: Vector2i,
	exit_visible: bool,
	game_won: bool,
	visited: Dictionary,
	is_revealed: Callable,
	ui_panel: UIPanel,
	levels_data: Array,
	current_level_index: int,
	difficulty_name: String,
	move_count: int,
	current_terrain_name: String,
	buff_display: String,
	combat_log: Array,
	inventory: Inventory,
	key_tracker: KeyTracker = null,
	selected_slot: int = 0,
	guide_dir: int = -1,
	low_hp_pulse: float = 0.0,
) -> void:
	var maze_pixel_w: float = maze_width * cell_size
	var maze_pixel_h: float = maze_height * cell_size
	var inset := clampf(12.0 * ui_scale, 12.0, 20.0)
	var available := maze_rect.grow(-inset)
	var scale_x: float = available.size.x / maze_pixel_w
	var scale_y: float = available.size.y / maze_pixel_h
	# PC 浏览器按可用区域真正放大；上限避免超宽屏下像素块过度粗大。
	var draw_scale: float = clampf(minf(scale_x, scale_y), 0.45, 2.0)
	var scaled_w: float = maze_pixel_w * draw_scale
	var scaled_h: float = maze_pixel_h * draw_scale
	var offset := available.position + (available.size - Vector2(scaled_w, scaled_h)) * 0.5

	canvas.draw_rect(maze_rect, Color(0.85, 0.80, 0.70))
	canvas.draw_rect(Rect2(offset.x - 2, offset.y - 2, scaled_w + 4, scaled_h + 4), Color(0.15, 0.12, 0.08))
	canvas.draw_rect(Rect2(offset, Vector2(scaled_w, scaled_h)), Color(0.92, 0.88, 0.78))

	draw_cells(canvas, maze, maze_width, maze_height, offset, draw_scale, visited, is_revealed)
	draw_pillars(canvas, maze, maze_width, maze_height, offset, draw_scale)
	draw_exit(canvas, exit_pos, offset, draw_scale, is_revealed, exit_visible, game_won)
	for pos in maze.landmarks:
		var revealed := bool(is_revealed.call(pos))
		if landmark_visible(maze.landmarks[pos], revealed):
			draw_landmark(canvas, maze.landmarks[pos], offset + Vector2(pos) * cell_size * draw_scale, cell_size * draw_scale, revealed)
	draw_items(canvas, items, offset, draw_scale, is_revealed)
	draw_monsters(canvas, monsters, offset, draw_scale, is_revealed, player.pos)
	draw_player(canvas, player, offset, draw_scale)
	if guide_dir >= 0:
		draw_path_arrow(canvas, player.pos, guide_dir, offset, draw_scale)

	canvas.draw_rect(hud_rect, Color(0.12, 0.10, 0.08))
	ui_panel.draw_panel(
		canvas, hud_rect.position.x, hud_rect.size.x, hud_rect.size.y,
		player, maze, maze_width, maze_height, exit_pos,
		levels_data, current_level_index, difficulty_name,
		move_count, current_terrain_name, buff_display,
		visited, is_revealed,
		combat_log, inventory, key_tracker,
		selected_slot, items, guide_dir, low_hp_pulse, ui_scale,
	)

func draw_cells(
	canvas: CanvasItem,
	maze: MazeGenerator,
	maze_width: int,
	maze_height: int,
	offset: Vector2,
	scale: float,
	visited: Dictionary,
	is_revealed: Callable,
) -> void:
	var sc: float = scale
	var cs: float = cell_size * sc
	var wt: float = wall_thickness * sc
	for y in maze_height:
		for x in maze_width:
			var pos := Vector2i(x, y)
			var cell_pos := offset + Vector2(x * cs, y * cs)
			if not is_revealed.call(pos) and not visited.get(pos, false) and not maze.charted_route.has(pos):
				canvas.draw_rect(Rect2(cell_pos, Vector2(cs, cs)), Color(0.15, 0.12, 0.10, 0.85))
				continue

			var t_key: String = MazeGenerator.TERRAIN_KEY[maze.get_terrain(x, y)]
			var cfg := DataLoader.get_terrain_config(t_key)
			var floor_color := get_floor_color(maze, x, y)
			if not is_revealed.call(pos):
				floor_color = floor_color.darkened(0.4)

			canvas.draw_rect(Rect2(cell_pos + Vector2(wt, wt), Vector2(cs - wt * 2, cs - wt * 2)), floor_color)

			var terrain_sprite := get_terrain_sprite(maze, x, y)
			if maze.theme_key == "mogao" and is_revealed.call(pos):
				draw_mogao_floor(canvas, maze, pos, cell_pos, cs)
			elif terrain_sprite and is_revealed.call(pos):
				canvas.draw_texture_rect(terrain_sprite, Rect2(cell_pos + Vector2(wt, wt), Vector2(cs - wt * 2, cs - wt * 2)), false)

			var detail_sym: String = "" if maze.theme_key == "mogao" else cfg.get("detail_symbol", "")
			if detail_sym != "":
				var detail_color := _terrain_symbol_color(t_key, floor_color)
				canvas.draw_string(
					ThemeDB.fallback_font, cell_pos + Vector2(cs * 0.35, cs * 0.65),
					detail_sym, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * sc), detail_color,
				)

			_draw_walls(canvas, maze.grid[y][x], cell_pos, cs, wt, x, y, maze_width, maze_height)
			draw_charted_route(canvas, maze, pos, cell_pos, cs)

func draw_charted_route(canvas: CanvasItem, maze: MazeGenerator, pos: Vector2i, origin: Vector2, cs: float) -> void:
	if not maze.charted_route.has(pos): return
	var center := origin + Vector2.ONE * cs / 2
	canvas.draw_circle(center, maxf(2, cs * 0.05), Color("f9ce66"))
	for d in [maze.N, maze.S, maze.E, maze.W]:
		var offset := Vector2i(maze.DX[d], maze.DY[d])
		if maze.can_move(pos.x, pos.y, d) and maze.charted_route.has(pos + offset):
			canvas.draw_line(center, center + Vector2(offset) * cs / 2, Color("f9ce66"), maxf(2, cs * 0.045), true)

func get_floor_color(maze: MazeGenerator, x: int, y: int) -> Color:
	var key: String = MazeGenerator.TERRAIN_KEY[maze.get_terrain(x, y)]
	if maze.theme_key == "mogao":
		return {"sand": Color("c2986a"), "desert": Color("c4854f"), "grotto": Color("725441"), "oasis": Color("719d94"), "ancient_road": Color("aa8060")}[key]
	return DataLoader.color_from_array(DataLoader.get_terrain_config(key).get("floor_color", [0.8, 0.8, 0.8]))

func draw_mogao_floor(canvas: CanvasItem, maze: MazeGenerator, pos: Vector2i, origin: Vector2, cs: float) -> void:
	if maze.grid[pos.y][pos.x] == 0:
		canvas.draw_rect(Rect2(origin, Vector2.ONE * cs), Color("604b3b"))
		canvas.draw_line(origin + Vector2(0, cs * 0.5), origin + Vector2(cs, cs * 0.5), Color("715744"), maxf(1, cs * 0.025))
		return
	var t := maze.get_terrain(pos.x, pos.y)
	var light: float = maze.landmarks.get(pos, {}).get("light", 0.0)
	if light > 0:
		canvas.draw_rect(Rect2(origin + Vector2.ONE * cs * 0.06, Vector2.ONE * cs * 0.88), Color(0.98, 0.78, 0.4, light * 0.55))
		for y in [0.12, 0.88]:
			canvas.draw_line(origin + Vector2(0.05, y) * cs, origin + Vector2(0.95, y) * cs, Color(1.0, 0.87, 0.59, light), maxf(2, cs * 0.04), true)
	if t == MazeGenerator.Terrain.ANCIENT_ROAD:
		for line in range(1, 4):
			canvas.draw_line(origin + Vector2(cs * 0.12, cs * line / 4.0), origin + Vector2(cs * 0.88, cs * line / 4.0), Color("74533c"), maxf(1, cs * 0.035))
	elif t == MazeGenerator.Terrain.GROTTO:
		var c := origin + Vector2(cs * 0.5, cs * 0.46)
		canvas.draw_arc(c, cs * 0.27, PI, TAU, 12, Color("c2a078"), maxf(1, cs * 0.045), true)
		for dx in [-0.27, 0.27]:
			canvas.draw_line(c + Vector2(dx * cs, 0), c + Vector2(dx * cs, cs * 0.3), Color("c2a078"), maxf(1, cs * 0.045))
	elif t == MazeGenerator.Terrain.OASIS:
		canvas.draw_arc(origin + Vector2.ONE * cs / 2, cs * 0.27, 0, TAU, 20, Color("c3e0cf"), maxf(1, cs * 0.04), true)

func draw_pillars(
	canvas: CanvasItem,
	maze: MazeGenerator,
	maze_width: int,
	maze_height: int,
	offset: Vector2,
	scale: float,
) -> void:
	var cs: float = cell_size * scale
	var wt: float = wall_thickness * scale
	for y in range(maze_height + 1):
		for x in range(maze_width + 1):
			var px := clampi(x, 0, maze_width - 1)
			var py := clampi(y, 0, maze_height - 1)
			var t_key: String = MazeGenerator.TERRAIN_KEY[maze.get_terrain(px, py)]
			var cfg := DataLoader.get_terrain_config(t_key)
			var pillar_color := DataLoader.color_from_array(cfg.get("wall_color", [0.2, 0.2, 0.2]))
			canvas.draw_rect(
				Rect2(offset + Vector2(x * cs - wt / 2, y * cs - wt / 2), Vector2(wt, wt)),
				pillar_color,
			)

func draw_exit(
	canvas: CanvasItem,
	exit_pos: Vector2i,
	offset: Vector2,
	scale: float,
	is_revealed: Callable,
	exit_visible: bool,
	game_won: bool,
) -> void:
	if not is_revealed.call(exit_pos) and not game_won:
		return
	if not exit_visible and not game_won:
		return
	var cs: float = cell_size * scale
	var ep := offset + Vector2(exit_pos.x * cs, exit_pos.y * cs)
	canvas.draw_rect(Rect2(ep + Vector2(cs * 0.15, cs * 0.15), Vector2(cs * 0.7, cs * 0.7)), Color(0.1, 0.8, 0.3))
	canvas.draw_string(
		ThemeDB.fallback_font, ep + Vector2(cs * 0.3, cs * 0.65),
		"门", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * scale), Color.WHITE,
	)

func landmark_visible(landmark: Dictionary, revealed: bool) -> bool:
	return revealed or bool(landmark.get("discovered", false)) or bool(landmark.get("silhouette", false)) or bool(landmark.get("ghost", false))


func draw_landmark(canvas: CanvasItem, landmark: Dictionary, origin: Vector2, cs: float, revealed: bool = true) -> void:
	var tint := Color.WHITE
	if landmark.get("kind", "") == "footprint":
		tint.a = JourneyBranches.footprint_alpha(Time.get_ticks_msec() / 1000.0, bool(landmark.get("pulse", false)))
	elif landmark.get("ghost", false) and not revealed and not landmark.get("discovered", false):
		tint.a = 0.45
	if landmark.kind == "beacon":
		var key := "beacon_lit" if landmark.get("lit", false) else "beacon"
		_draw_cached(canvas, AssetRegistry.landmark_path(key), Rect2(origin + Vector2(0, -cs), Vector2(cs, cs * 2.0)), tint)
		if not landmark.get("lit", false):
			_draw_cached(canvas, AssetRegistry.extra_item_path("bell"), Rect2(origin + Vector2(cs * 0.58, cs * 0.08), Vector2(cs * 0.36, cs * 0.36)), tint)
		canvas.draw_string(ThemeDB.fallback_font, origin + Vector2(0, cs * 0.42), "燧", HORIZONTAL_ALIGNMENT_CENTER, int(cs), int(cs * 0.32), Color("3f2b11"))
		return
	if landmark.kind == "caravan":
		var key := "caravan_searched" if landmark.get("searched", false) else "caravan"
		_draw_cached(canvas, AssetRegistry.landmark_path(key), Rect2(origin + Vector2(-cs, 0), Vector2(cs * 2.0, cs)), tint)
		if not landmark.get("searched", false):
			_draw_cached(canvas, AssetRegistry.extra_item_path("fragment_2"), Rect2(origin + Vector2(cs * 0.52, cs * 0.08), Vector2(cs * 0.4, cs * 0.4)), tint)
		return
	if landmark.kind == "stele":
		var key := "stele_read" if landmark.get("read", false) else "stele"
		_draw_cached(canvas, AssetRegistry.landmark_path(key), Rect2(origin + Vector2(cs * 0.18, cs * 0.12), Vector2(cs * 0.64, cs * 0.64)), tint)
		if not landmark.get("read", false):
			_draw_cached(canvas, AssetRegistry.extra_item_path("fragment_3"), Rect2(origin + Vector2(cs * 0.5, cs * 0.5), Vector2(cs * 0.4, cs * 0.4)), tint)
		return
	if landmark.kind == "footprint":
		_draw_cached(canvas, AssetRegistry.decal_path(str(landmark.get("dir", "n"))), Rect2(origin, Vector2(cs, cs)), tint)
		return
	if landmark.kind == "family_silhouette":
		if not landmark.get("silhouette", false):
			return
		var source: Dictionary = AssetRegistry.family_silhouette_source()
		var sprite := _cached_texture(str(source.get("path", "")))
		var slot := AssetRegistry.FAMILY_SILHOUETTE_ORIGIN
		var slot_size := AssetRegistry.FAMILY_SILHOUETTE_SIZE
		var modulate := AssetRegistry.FAMILY_SILHOUETTE_DARKEN if source.get("darken", false) else Color.WHITE
		if sprite:
			canvas.draw_texture_rect(sprite, Rect2(origin + Vector2(cs * slot.x, cs * slot.y), Vector2(cs * slot_size.x, cs * slot_size.y)), false, modulate)
		canvas.draw_arc(origin + Vector2(cs * 0.5, cs * 0.5), cs * 0.42, 0, TAU, 16, Color(0.85, 0.72, 0.35, 0.75), maxf(2, cs * 0.06), true)
		return
	if landmark.kind == "mural" and not landmark.get("found", false):
		_draw_cached(canvas, AssetRegistry.extra_item_path("fragment_1"), Rect2(origin + Vector2(cs * 0.52, cs * 0.08), Vector2(cs * 0.4, cs * 0.4)), tint)
	if landmark.kind == "deer":
		canvas.draw_texture_rect(TravelLore.DEER, Rect2(origin + Vector2.ONE * cs * 0.08, Vector2.ONE * cs * 0.84), false)
		return
	if landmark.kind == "stone_gate":
		var ink := Color("f9ce66")
		for x in [0.24, 0.76]: canvas.draw_line(origin + Vector2(x, 0.25) * cs, origin + Vector2(x, 0.86) * cs, ink, maxf(3, cs * 0.09))
		canvas.draw_line(origin + Vector2(0.13, 0.25) * cs, origin + Vector2(0.87, 0.25) * cs, ink, maxf(3, cs * 0.09))
		return
	if landmark.kind == "pattern_gate":
		var opened: float = landmark.get("visual_open", 0.0)
		var wood := Color("ad7947")
		# Two shrinking leaves expose the real traversable tile between the posts.
		for x in [0.08, 0.86]:
			canvas.draw_rect(Rect2(origin + Vector2(x, 0.1) * cs, Vector2(0.06, 0.8) * cs), Color("e1bb78"))
		canvas.draw_rect(Rect2(origin + Vector2(0.06, 0.08) * cs, Vector2(0.88, 0.09) * cs), Color("d0a361"))
		var width := 0.36 * (1.0 - opened)
		for x in [0.14, 0.86 - width]:
			canvas.draw_rect(Rect2(origin + Vector2(x, 0.18) * cs, Vector2(width, 0.66) * cs), wood)
			for y in [0.3, 0.68]:
				canvas.draw_line(origin + Vector2(x, y) * cs, origin + Vector2(x + width, y) * cs, Color("644530"), maxf(1, cs * 0.04))
		if opened < 0.6:
			_draw_pattern_seal(canvas, origin + Vector2(0.5, 0.48) * cs, cs * 0.28, Color.WHITE)
		else:
			canvas.draw_line(origin + Vector2(0.27, 0.54) * cs, origin + Vector2(0.74, 0.54) * cs, Color("f4d68c"), maxf(2, cs * 0.045), true)
			canvas.draw_polyline(PackedVector2Array([origin + Vector2(0.59, 0.41) * cs, origin + Vector2(0.75, 0.54) * cs, origin + Vector2(0.59, 0.67) * cs]), Color("f4d68c"), maxf(2, cs * 0.045), true)
		return
	if landmark.kind == "scarf":
		canvas.draw_line(origin + Vector2(0.65, 0.2) * cs, origin + Vector2(0.65, 0.87) * cs, Color("c5aa77"), maxf(2, cs * 0.08))
		canvas.draw_colored_polygon(PackedVector2Array([origin + Vector2(0.25, 0.26) * cs, origin + Vector2(0.73, 0.22) * cs, origin + Vector2(0.7, 0.41) * cs, origin + Vector2(0.55, 0.43) * cs, origin + Vector2(0.55, 0.78) * cs, origin + Vector2(0.38, 0.69) * cs, origin + Vector2(0.4, 0.42) * cs, origin + Vector2(0.22, 0.46) * cs]), Color("71c9f0"))
		canvas.draw_line(origin + Vector2(0.3, 0.31) * cs, origin + Vector2(0.65, 0.29) * cs, Color("d3f1ff"), maxf(1, cs * 0.04), true)
		return
	if landmark.kind == "pattern":
		canvas.draw_rect(Rect2(origin + Vector2(0.13, 0.36) * cs, Vector2(0.74, 0.46) * cs), Color("9e713e"))
		canvas.draw_rect(Rect2(origin + Vector2(0.13, 0.29) * cs, Vector2(0.74, 0.13) * cs), Color("dab779"))
		_draw_pattern_seal(canvas, origin + Vector2(0.5, 0.52) * cs, cs * 0.26, Color.WHITE)
		return
	var color := Color("d8b76b")
	if landmark.kind == "spring": color = Color("79c5c4")
	elif landmark.kind in ["camp", "shortcut"]: color = Color("8bbf7a")
	elif landmark.kind == "pattern": color = Color("99d3d0")
	elif landmark.kind == "pattern_gate": color = Color("8bbf7a") if landmark.get("open", false) else Color("e1ab77")
	var badge := Rect2(origin + Vector2(cs * 0.18, cs * 0.18), Vector2.ONE * cs * 0.64)
	canvas.draw_rect(badge, Color("30291e"))
	canvas.draw_rect(badge, color, false, maxf(1, cs * 0.03))
	canvas.draw_string(ThemeDB.fallback_font, origin + Vector2(0, cs * 0.68), landmark.symbol,
		HORIZONTAL_ALIGNMENT_CENTER, int(cs), int(cs * 0.43), color)

func _draw_pattern_seal(canvas: CanvasItem, center: Vector2, radius: float, _color: Color) -> void:
	RabbitLore.draw_plate(canvas, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2))

func _cached_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _sprite_cache.has(path):
		return _sprite_cache[path]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_sprite_cache[path] = tex
	return tex


func _draw_cached(canvas: CanvasItem, path: String, rect: Rect2, tint: Color) -> void:
	var tex := _cached_texture(path)
	if tex:
		canvas.draw_texture_rect(tex, rect, false, tint)


func draw_items(
	canvas: CanvasItem,
	items: Array,
	offset: Vector2,
	scale: float,
	is_revealed: Callable,
) -> void:
	var cs: float = cell_size * scale
	var wt: float = wall_thickness * scale
	var key_palettes := [
		[Color(0.86, 0.24, 0.24), Color(0.2, 0.2, 0.2), Color(1.0, 0.85, 0.72)],
		[Color(0.31, 0.71, 0.31), Color(0.39, 0.27, 0.16), Color(1.0, 0.85, 0.72)],
		[Color(0.59, 0.31, 0.71), Color(0.86, 0.86, 0.86), Color(1.0, 0.85, 0.72)],
	]
	var key_index := 0
	for it in items:
		if not is_instance_valid(it) or not is_revealed.call(it.pos):
			continue
		var ip := offset + Vector2(it.pos.x * cs, it.pos.y * cs)
		if it.item_type == "key":
			var family_sprite := get_family_sprite(it.item_key)
			if family_sprite:
				draw_sprite_in_cell(canvas, family_sprite, ip, cs, wt * 0.45)
			else:
				var pal: Array = key_palettes[key_index % 3]
				draw_character(canvas, ip, cs / 16.0, pal[0], pal[1], pal[2])
			key_index += 1
		else:
			var sprite: Texture2D = item_sprites.get(it.item_type)
			if sprite:
				draw_sprite_in_cell(canvas, sprite, ip, cs, wt)
			else:
				canvas.draw_rect(Rect2(ip + Vector2(wt, wt), Vector2(cs - wt * 2, cs - wt * 2)), it.color.darkened(0.2))
				canvas.draw_string(
					ThemeDB.fallback_font, ip + Vector2(cs * 0.3, cs * 0.65),
					it.symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * scale), it.color,
				)

func draw_monsters(
	canvas: CanvasItem,
	monsters: Array,
	offset: Vector2,
	scale: float,
	is_revealed: Callable,
	player_pos: Vector2i = Vector2i(-1, -1),
) -> void:
	var cs: float = cell_size * scale
	var wt: float = wall_thickness * scale
	for m in monsters:
		if not is_instance_valid(m) or not is_revealed.call(m.pos):
			continue
		if m.pos == player_pos:
			continue
		var mp := offset + Vector2(m.pos.x * cs, m.pos.y * cs)
		draw_monster_in_cell(canvas, m, mp, cs, wt, scale)


func draw_monster_in_cell(
	canvas: CanvasItem,
	m: MonsterEntity,
	cell_origin: Vector2,
	cs: float,
	wt: float,
	scale: float = 1.0,
) -> void:
	if not is_instance_valid(m):
		return
	_draw_monster_avatar(canvas, m.monster_type, cell_origin, cs, wt, m.color)
	var hp_ratio := float(m.hp) / float(maxi(m.max_hp, 1))
	var bar_h := maxf(4.0, cs * 0.065)
	var bar_w := cs - wt * 2.0 - 4.0
	var bar_x := cell_origin.x + wt + 2.0
	var bar_y := cell_origin.y + cs - wt - bar_h - 1.0
	canvas.draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.16, 0.07, 0.06, 0.95))
	canvas.draw_rect(Rect2(bar_x, bar_y, bar_w * hp_ratio, bar_h), Color(0.9, 0.22, 0.18))
	
	# Draw intent arrow above monster
	var intent := m.get_intent_arrow()
	if intent != "":
		var intent_fs := int(cs * 0.25)
		canvas.draw_string(
			ThemeDB.fallback_font, cell_origin + Vector2(0.0, cs * 0.24),
			intent, HORIZONTAL_ALIGNMENT_CENTER, int(cs), intent_fs, Color(1.0, 0.85, 0.25, 0.95),
		)


func _draw_monster_avatar(
	canvas: CanvasItem,
	monster_type: String,
	o: Vector2,
	cs: float,
	wt: float,
	base_color: Color,
) -> void:
	# 怪物使用按格子比例绘制的矢量剪影，避免字体图标放大后的低分辨率问题。
	var center := o + Vector2(cs * 0.5, cs * 0.52)
	var body := base_color.lightened(0.12)
	var shade := base_color.darkened(0.28)
	var line_w := maxf(2.0, cs * 0.055)
	var eye_r := maxf(1.5, cs * 0.035)
	canvas.draw_rect(Rect2(o + Vector2(wt, wt), Vector2(cs - wt * 2.0, cs - wt * 2.0)), shade.darkened(0.12))
	match monster_type:
		"sand":
			canvas.draw_circle(center, cs * 0.20, body)
			canvas.draw_circle(center + Vector2(-cs * 0.18, cs * 0.05), cs * 0.10, body)
			canvas.draw_line(center + Vector2(cs * 0.13, -cs * 0.10), center + Vector2(cs * 0.30, -cs * 0.23), body, line_w)
			canvas.draw_circle(center + Vector2(cs * 0.31, -cs * 0.24), cs * 0.055, body)
			for side in [-1.0, 1.0]:
				canvas.draw_line(center + Vector2(side * cs * 0.10, cs * 0.10), center + Vector2(side * cs * 0.31, cs * 0.23), body, line_w)
				canvas.draw_circle(center + Vector2(side * cs * 0.31, cs * 0.23), cs * 0.055, body)
		"desert":
			for i in 4:
				var seg := center + Vector2((float(i) - 1.5) * cs * 0.12, sin(float(i) * 1.7) * cs * 0.07)
				canvas.draw_circle(seg, cs * (0.14 - float(i) * 0.012), body.lightened(float(i) * 0.025))
			canvas.draw_line(center + Vector2(-cs * 0.23, -cs * 0.08), center + Vector2(-cs * 0.32, -cs * 0.20), body, line_w * 0.7)
			canvas.draw_line(center + Vector2(-cs * 0.17, -cs * 0.10), center + Vector2(-cs * 0.20, -cs * 0.24), body, line_w * 0.7)
		"grotto":
			canvas.draw_rect(Rect2(center - Vector2(cs * 0.20, cs * 0.19), Vector2(cs * 0.40, cs * 0.38)), body)
			canvas.draw_rect(Rect2(center - Vector2(cs * 0.28, cs * 0.10), Vector2(cs * 0.12, cs * 0.27)), body.darkened(0.05))
			canvas.draw_rect(Rect2(center + Vector2(cs * 0.16, -cs * 0.10), Vector2(cs * 0.12, cs * 0.27)), body.darkened(0.05))
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-cs * 0.18, -cs * 0.19), center + Vector2(-cs * 0.06, -cs * 0.32), center + Vector2(cs * 0.02, -cs * 0.19)]), body)
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(cs * 0.05, -cs * 0.19), center + Vector2(cs * 0.16, -cs * 0.31), center + Vector2(cs * 0.20, -cs * 0.19)]), body)
		"oasis":
			canvas.draw_circle(center + Vector2(0, cs * 0.05), cs * 0.23, body)
			canvas.draw_circle(center + Vector2(-cs * 0.13, -cs * 0.13), cs * 0.12, body.lightened(0.08))
			canvas.draw_circle(center + Vector2(cs * 0.12, -cs * 0.16), cs * 0.10, body.lightened(0.15))
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-cs * 0.20, cs * 0.12), center + Vector2(0, cs * 0.31), center + Vector2(cs * 0.20, cs * 0.12)]), body)
		_:
			canvas.draw_circle(center + Vector2(0, -cs * 0.08), cs * 0.17, body)
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-cs * 0.25, cs * 0.25), center + Vector2(-cs * 0.18, -cs * 0.02), center + Vector2(0, -cs * 0.20), center + Vector2(cs * 0.18, -cs * 0.02), center + Vector2(cs * 0.25, cs * 0.25)]), body)
			canvas.draw_line(center + Vector2(cs * 0.22, -cs * 0.02), center + Vector2(cs * 0.31, cs * 0.26), Color(0.18, 0.13, 0.08), line_w)
	canvas.draw_circle(center + Vector2(-cs * 0.065, -cs * 0.075), eye_r, Color(1.0, 0.88, 0.42))
	canvas.draw_circle(center + Vector2(cs * 0.065, -cs * 0.075), eye_r, Color(1.0, 0.88, 0.42))
	canvas.draw_circle(center + Vector2(-cs * 0.065, -cs * 0.075), eye_r * 0.45, Color(0.08, 0.05, 0.03))
	canvas.draw_circle(center + Vector2(cs * 0.065, -cs * 0.075), eye_r * 0.45, Color(0.08, 0.05, 0.03))

func draw_player(canvas: CanvasItem, player: PlayerController, offset: Vector2, scale: float) -> void:
	var cs: float = cell_size * scale
	var wt: float = wall_thickness * scale
	var pp := offset + Vector2(player.pos.x * cs, player.pos.y * cs)
	if player_sprite:
		draw_sprite_in_cell(canvas, player_sprite, pp, cs, wt * 0.45)
	else:
		draw_character(canvas, pp, cs / 16.0, Color(0.27, 0.51, 0.71), Color(0.85, 0.65, 0.13), Color(1.0, 0.85, 0.72))

func draw_path_arrow(canvas: CanvasItem, pos: Vector2i, dir: int, offset: Vector2, scale: float) -> void:
	var cs: float = cell_size * scale
	var center := offset + Vector2(pos.x * cs + cs * 0.5, pos.y * cs + cs * 0.5)
	var tip := center
	var left := center
	var right := center
	var arrow_len := cs * 0.22
	match dir:
		MazeGenerator.N:
			tip += Vector2(0, -arrow_len)
			left += Vector2(-arrow_len * 0.5, arrow_len * 0.2)
			right += Vector2(arrow_len * 0.5, arrow_len * 0.2)
		MazeGenerator.S:
			tip += Vector2(0, arrow_len)
			left += Vector2(-arrow_len * 0.5, -arrow_len * 0.2)
			right += Vector2(arrow_len * 0.5, -arrow_len * 0.2)
		MazeGenerator.E:
			tip += Vector2(arrow_len, 0)
			left += Vector2(-arrow_len * 0.2, -arrow_len * 0.5)
			right += Vector2(-arrow_len * 0.2, arrow_len * 0.5)
		MazeGenerator.W:
			tip += Vector2(-arrow_len, 0)
			left += Vector2(arrow_len * 0.2, -arrow_len * 0.5)
			right += Vector2(arrow_len * 0.2, arrow_len * 0.5)
		_:
			return
	canvas.draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(0.35, 0.9, 1.0, 0.85))

func draw_character(canvas: CanvasItem, o: Vector2, s: float, robe: Color, hair: Color, skin: Color) -> void:
	canvas.draw_rect(Rect2(o.x + 4 * s, o.y + 1 * s, 8 * s, 5 * s), hair)
	canvas.draw_rect(Rect2(o.x + 5 * s, o.y + 4 * s, 6 * s, 4 * s), skin)
	canvas.draw_rect(Rect2(o.x + 6 * s, o.y + 5 * s, 1 * s, 1 * s), Color.WHITE)
	canvas.draw_rect(Rect2(o.x + 9 * s, o.y + 5 * s, 1 * s, 1 * s), Color.WHITE)
	canvas.draw_rect(Rect2(o.x + 6 * s, o.y + 6 * s, 1 * s, 1 * s), Color.BLACK)
	canvas.draw_rect(Rect2(o.x + 9 * s, o.y + 6 * s, 1 * s, 1 * s), Color.BLACK)
	canvas.draw_rect(Rect2(o.x + 7 * s, o.y + 7 * s, 2 * s, 1 * s), Color(0.8, 0.4, 0.4))
	canvas.draw_rect(Rect2(o.x + 4 * s, o.y + 8 * s, 8 * s, 6 * s), robe)
	canvas.draw_rect(Rect2(o.x + 4 * s, o.y + 10 * s, 8 * s, 1 * s), hair)
	canvas.draw_rect(Rect2(o.x + 2 * s, o.y + 9 * s, 2 * s, 3 * s), skin)
	canvas.draw_rect(Rect2(o.x + 12 * s, o.y + 9 * s, 2 * s, 3 * s), skin)
	canvas.draw_rect(Rect2(o.x + 5 * s, o.y + 14 * s, 2 * s, 2 * s), hair.darkened(0.2))
	canvas.draw_rect(Rect2(o.x + 9 * s, o.y + 14 * s, 2 * s, 2 * s), hair.darkened(0.2))

func draw_difficulty_select(canvas: CanvasItem, vp: Vector2, selected_difficulty: String, continue_hint: String = "") -> void:
	canvas.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.12, 0.1, 0.08))
	var ui_scale := _difficulty_ui_scale(vp)
	var title_y := maxf(82.0, vp.y * 0.16)
	canvas.draw_string(
		ThemeDB.fallback_font, Vector2(vp.x * 0.5 - 100.0 * ui_scale, title_y),
		"敦煌迷途", HORIZONTAL_ALIGNMENT_CENTER, int(200.0 * ui_scale), int(38 * ui_scale), Color(0.9, 0.8, 0.6),
	)
	canvas.draw_string(
		ThemeDB.fallback_font, Vector2(vp.x * 0.5 - 100.0 * ui_scale, title_y + 42.0 * ui_scale),
		"选择旅途难度", HORIZONTAL_ALIGNMENT_CENTER, int(200.0 * ui_scale), int(19 * ui_scale), Color(0.7, 0.65, 0.55),
	)
	var cards := get_difficulty_card_rects(vp)
	for i in cards.size():
		var key: String = GameState.DIFFICULTY_OPTIONS[i]
		var name: String = GameState.DIFFICULTY_NAMES[key]
		var diff: Dictionary = DataLoader.difficulty_data.get(key, {})
		var desc: String = diff.get("description", "")
		var stats: String = _format_difficulty_stats(diff)
		var is_selected := key == selected_difficulty
		var card: Rect2 = cards[i]
		var bg_color := Color(0.25, 0.2, 0.15) if is_selected else Color(0.18, 0.15, 0.12)
		var text_color := Color(1.0, 0.9, 0.6) if is_selected else Color(0.6, 0.55, 0.45)
		canvas.draw_rect(card, bg_color)
		if is_selected:
			canvas.draw_rect(Rect2(card.position, Vector2(maxf(4.0, 4.0 * ui_scale), card.size.y)), Color(0.9, 0.7, 0.2))
		var text_x := card.position.x + 18.0 * ui_scale
		canvas.draw_string(
			ThemeDB.fallback_font, Vector2(text_x, card.position.y + 29.0 * ui_scale),
			name, HORIZONTAL_ALIGNMENT_LEFT, int(card.size.x - 36.0 * ui_scale), int(23 * ui_scale), text_color,
		)
		canvas.draw_string(
			ThemeDB.fallback_font, Vector2(text_x, card.position.y + 52.0 * ui_scale),
			desc, HORIZONTAL_ALIGNMENT_LEFT, int(card.size.x - 36.0 * ui_scale), int(15 * ui_scale), Color(0.68, 0.65, 0.58),
		)
		canvas.draw_string(
			ThemeDB.fallback_font, Vector2(text_x, card.position.y + 72.0 * ui_scale),
			stats, HORIZONTAL_ALIGNMENT_LEFT, int(card.size.x - 36.0 * ui_scale), int(14 * ui_scale), Color(0.55, 0.78, 0.55),
		)
	canvas.draw_string(
		ThemeDB.fallback_font, Vector2(vp.x * 0.5 - 150.0 * ui_scale, vp.y - 64.0 * ui_scale),
		"↑↓ 选择 · 回车确认 · 点击卡片开始", HORIZONTAL_ALIGNMENT_CENTER, int(300.0 * ui_scale), int(14 * ui_scale), Color(0.55, 0.52, 0.46),
	)
	if continue_hint != "":
		canvas.draw_string(
			ThemeDB.fallback_font, Vector2(vp.x * 0.5 - 170.0 * ui_scale, vp.y - 34.0 * ui_scale),
			continue_hint, HORIZONTAL_ALIGNMENT_CENTER, int(340.0 * ui_scale), int(13 * ui_scale), Color(0.4, 0.78, 0.45),
		)


func get_difficulty_card_rects(vp: Vector2) -> Array[Rect2]:
	var scale := _difficulty_ui_scale(vp)
	var gap := 10.0 * scale
	var card_h := 84.0 * scale
	var card_w := minf(vp.x - 28.0, 560.0 * scale)
	var total_h := card_h * GameState.DIFFICULTY_OPTIONS.size() + gap * (GameState.DIFFICULTY_OPTIONS.size() - 1)
	var start_y := clampf(vp.y * 0.33, 190.0 * scale, vp.y - total_h - 92.0 * scale)
	var result: Array[Rect2] = []
	for i in GameState.DIFFICULTY_OPTIONS.size():
		result.append(Rect2(vp.x * 0.5 - card_w * 0.5, start_y + i * (card_h + gap), card_w, card_h))
	return result


func _difficulty_ui_scale(vp: Vector2) -> float:
	return clampf(minf(vp.x / 560.0, vp.y / 720.0), 0.86, 1.15)

func draw_error_screen(canvas: CanvasItem, vp: Vector2) -> void:
	canvas.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.15, 0.1, 0.08))
	canvas.draw_string(
		ThemeDB.fallback_font, Vector2(vp.x / 2 - 100, vp.y / 2 - 20),
		"加载失败", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.9, 0.3, 0.2),
	)

func _draw_walls(
	canvas: CanvasItem,
	cell: int,
	cell_pos: Vector2,
	cs: float,
	wt: float,
	x: int,
	y: int,
	maze_width: int,
	maze_height: int,
) -> void:
	var wall_color := Color(0.12, 0.08, 0.05)
	if (cell & MazeGenerator.N) == 0:
		canvas.draw_rect(Rect2(cell_pos, Vector2(cs, wt)), wall_color)
	if (cell & MazeGenerator.S) == 0:
		canvas.draw_rect(Rect2(cell_pos + Vector2(0, cs - wt), Vector2(cs, wt)), wall_color)
	if (cell & MazeGenerator.W) == 0:
		canvas.draw_rect(Rect2(cell_pos, Vector2(wt, cs)), wall_color)
	if (cell & MazeGenerator.E) == 0:
		canvas.draw_rect(Rect2(cell_pos + Vector2(cs - wt, 0), Vector2(wt, cs)), wall_color)
	if y == 0:
		canvas.draw_rect(Rect2(cell_pos, Vector2(cs, wt)), wall_color)
	if y == maze_height - 1:
		canvas.draw_rect(Rect2(cell_pos + Vector2(0, cs - wt), Vector2(cs, wt)), wall_color)
	if x == 0:
		canvas.draw_rect(Rect2(cell_pos, Vector2(wt, cs)), wall_color)
	if x == maze_width - 1:
		canvas.draw_rect(Rect2(cell_pos + Vector2(cs - wt, 0), Vector2(wt, cs)), wall_color)

func _terrain_symbol_color(t_key: String, floor_color: Color) -> Color:
	if floor_color.get_luminance() > 0.5:
		return Color(0.2, 0.15, 0.1)
	return Color(0.9, 0.85, 0.7)


func _format_difficulty_stats(diff: Dictionary) -> String:
	var base_hp := int(DataLoader.player_stats.get("max_hp", 18) * diff.get("hp_multiplier", 1.0))
	var base_atk := int(DataLoader.player_stats.get("base_atk", 5) * diff.get("atk_multiplier", 1.0))
	var drop := int(diff.get("item_drop_multiplier", 1.0) * 100)
	var reveal := int(diff.get("reveal_radius_bonus", 0))
	var reveal_str := "+%d 视野" % reveal if reveal >= 0 else "%d 视野" % reveal
	return "HP≈%d  攻≈%d  掉落%d%%  %s" % [base_hp, base_atk, drop, reveal_str]
