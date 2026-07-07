class_name MazeRenderer
extends RefCounted

var cell_size: int = 40
var wall_thickness: int = 4
var item_sprites: Dictionary = {}
var terrain_sprites: Dictionary = {}
var player_sprite: Texture2D
var family_sprites: Array[Texture2D] = []

func load_sprites() -> void:
	player_sprite = load("res://assets/sprites/player/dj.png")
	family_sprites = [
		load("res://assets/sprites/player/le.png"),
		load("res://assets/sprites/player/mac.png"),
		load("res://assets/sprites/player/mcking.png"),
	]
	item_sprites = {
		"container": load("res://assets/sprites/item/pot.png"),
		"heal": load("res://assets/sprites/item/scroll.png"),
		"defense": load("res://assets/sprites/item/shield.png"),
		"attack": load("res://assets/sprites/item/sword.png"),
		"trap": load("res://assets/sprites/item/pot.png"),
		"key": load("res://assets/sprites/player/le.png"),
	}
	terrain_sprites = {
		"sand": load("res://assets/sprites/terrain/sand.png"),
		"desert": load("res://assets/sprites/terrain/desert.png"),
		"grotto": load("res://assets/sprites/terrain/hole/line.png"),
		"oasis": load("res://assets/sprites/terrain/oasis/defult.png"),
		"ancient_road": load("res://assets/sprites/terrain/road/line.png"),
	}
	_load_terrain_variants()

func _load_terrain_variants() -> void:
	var variant_paths := {
		"ancient_road_cross": "res://assets/sprites/terrain/road/cross.png",
		"ancient_road_cross_t": "res://assets/sprites/terrain/road/cross_t.png",
		"ancient_road_cross_l": "res://assets/sprites/terrain/road/cross_l.png",
		"grotto_cross": "res://assets/sprites/terrain/hole/cross.png",
		"grotto_cross_t": "res://assets/sprites/terrain/hole/cross_t.png",
		"grotto_cross_l": "res://assets/sprites/terrain/hole/cross_l.png",
		"oasis_pond": "res://assets/sprites/terrain/oasis/pond.png",
		"oasis_tree": "res://assets/sprites/terrain/oasis/tree.png",
	}
	for key in variant_paths:
		var tex: Texture2D = load(variant_paths[key])
		if tex:
			terrain_sprites[key] = tex

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
	vp: Vector2,
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
) -> void:
	var panel_w: float = 220.0
	var game_w: float = vp.x - panel_w
	var game_h: float = vp.y - 40.0
	var maze_pixel_w: float = maze_width * cell_size
	var maze_pixel_h: float = maze_height * cell_size
	var scale_x: float = game_w / maze_pixel_w
	var scale_y: float = game_h / maze_pixel_h
	var draw_scale: float = minf(minf(scale_x, scale_y), 1.0)
	var scaled_w: float = maze_pixel_w * draw_scale
	var scaled_h: float = maze_pixel_h * draw_scale
	var offset := Vector2((game_w - scaled_w) / 2.0, (game_h - scaled_h) / 2.0)

	canvas.draw_rect(Rect2(0, 0, game_w, game_h), Color(0.85, 0.80, 0.70))
	canvas.draw_rect(Rect2(offset.x - 2, offset.y - 2, scaled_w + 4, scaled_h + 4), Color(0.15, 0.12, 0.08))
	canvas.draw_rect(Rect2(offset, Vector2(scaled_w, scaled_h)), Color(0.92, 0.88, 0.78))

	draw_cells(canvas, maze, maze_width, maze_height, offset, draw_scale, visited, is_revealed)
	draw_pillars(canvas, maze, maze_width, maze_height, offset, draw_scale)
	draw_exit(canvas, exit_pos, offset, draw_scale, is_revealed, exit_visible, game_won)
	draw_items(canvas, items, offset, draw_scale, is_revealed)
	draw_monsters(canvas, monsters, offset, draw_scale, is_revealed)
	draw_player(canvas, player, offset, draw_scale)

	canvas.draw_rect(Rect2(game_w, 0, panel_w, vp.y), Color(0.12, 0.10, 0.08))
	ui_panel.draw_panel(
		canvas, game_w, panel_w, vp.y,
		player, maze, maze_width, maze_height, exit_pos,
		levels_data, current_level_index, difficulty_name,
		move_count, current_terrain_name, buff_display,
		visited, is_revealed,
		combat_log, inventory,
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
			if not is_revealed.call(pos) and not visited.get(pos, false):
				canvas.draw_rect(Rect2(cell_pos, Vector2(cs, cs)), Color(0.15, 0.12, 0.10, 0.85))
				continue

			var t_key: String = MazeGenerator.TERRAIN_KEY[maze.get_terrain(x, y)]
			var cfg := DataLoader.get_terrain_config(t_key)
			var floor_color := DataLoader.color_from_array(cfg.get("floor_color", [0.8, 0.8, 0.8]))
			if not is_revealed.call(pos):
				floor_color = floor_color.darkened(0.4)

			canvas.draw_rect(Rect2(cell_pos + Vector2(wt, wt), Vector2(cs - wt * 2, cs - wt * 2)), floor_color)

			var terrain_sprite := get_terrain_sprite(maze, x, y)
			if terrain_sprite and is_revealed.call(pos):
				canvas.draw_texture_rect(terrain_sprite, Rect2(cell_pos + Vector2(wt, wt), Vector2(cs - wt * 2, cs - wt * 2)), false)

			var detail_sym: String = cfg.get("detail_symbol", "")
			if detail_sym != "":
				var detail_color := _terrain_symbol_color(t_key, floor_color)
				canvas.draw_string(
					ThemeDB.fallback_font, cell_pos + Vector2(cs * 0.35, cs * 0.65),
					detail_sym, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * sc), detail_color,
				)

			_draw_walls(canvas, maze.grid[y][x], cell_pos, cs, wt, x, y, maze_width, maze_height)

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
			var pal: Array = key_palettes[key_index % 3]
			draw_character(canvas, ip, cs / 16.0, pal[0], pal[1], pal[2])
			key_index += 1
		else:
			var sprite: Texture2D = item_sprites.get(it.item_type)
			if sprite:
				canvas.draw_texture_rect(sprite, Rect2(ip + Vector2(wt, wt), Vector2(cs - wt * 2, cs - wt * 2)), false)
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
) -> void:
	var cs: float = cell_size * scale
	var wt: float = wall_thickness * scale
	for m in monsters:
		if not is_instance_valid(m) or not is_revealed.call(m.pos):
			continue
		var mp := offset + Vector2(m.pos.x * cs, m.pos.y * cs)
		canvas.draw_rect(Rect2(mp + Vector2(wt, wt), Vector2(cs - wt * 2, cs - wt * 2)), m.color.darkened(0.3))
		canvas.draw_string(
			ThemeDB.fallback_font, mp + Vector2(cs * 0.3, cs * 0.65),
			m.symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * scale), m.color,
		)
		var hp_ratio := float(m.hp) / float(m.max_hp)
		var bar_w := cs - wt * 2 - 4
		var bar_x := mp.x + wt + 2
		var bar_y := mp.y + cs - wt - 6
		canvas.draw_rect(Rect2(bar_x, bar_y, bar_w, 4), Color(0.2, 0.1, 0.1))
		canvas.draw_rect(Rect2(bar_x, bar_y, bar_w * hp_ratio, 4), Color(0.8, 0.2, 0.2))

func draw_player(canvas: CanvasItem, player: PlayerController, offset: Vector2, scale: float) -> void:
	var cs: float = cell_size * scale
	var pp := offset + Vector2(player.pos.x * cs, player.pos.y * cs)
	draw_character(canvas, pp, cs / 16.0, Color(0.27, 0.51, 0.71), Color(0.85, 0.65, 0.13), Color(1.0, 0.85, 0.72))

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

func draw_difficulty_select(canvas: CanvasItem, vp: Vector2, selected_difficulty: String) -> void:
	canvas.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.12, 0.1, 0.08))
	var min_dim := minf(vp.x, vp.y)
	var font_mult := clampf(min_dim / 400.0, 1.0, 2.5)
	var title_y := vp.y * 0.2
	canvas.draw_string(
		ThemeDB.fallback_font, Vector2(vp.x / 2 - 80 * font_mult, title_y),
		"敦煌迷途", HORIZONTAL_ALIGNMENT_LEFT, -1, int(36 * font_mult), Color(0.9, 0.8, 0.6),
	)
	canvas.draw_string(
		ThemeDB.fallback_font, Vector2(vp.x / 2 - 60 * font_mult, title_y + 40 * font_mult),
		"选择旅途难度", HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * font_mult), Color(0.7, 0.65, 0.55),
	)
	var start_y := vp.y * 0.4
	for i in GameState.DIFFICULTY_OPTIONS.size():
		var key: String = GameState.DIFFICULTY_OPTIONS[i]
		var name: String = GameState.DIFFICULTY_NAMES[key]
		var diff: Dictionary = DataLoader.difficulty_data.get(key, {})
		var desc: String = diff.get("description", "")
		var is_selected := key == selected_difficulty
		var y := start_y + i * 80 * font_mult
		var bg_color := Color(0.25, 0.2, 0.15) if is_selected else Color(0.18, 0.15, 0.12)
		var text_color := Color(1.0, 0.9, 0.6) if is_selected else Color(0.6, 0.55, 0.45)
		canvas.draw_rect(Rect2(vp.x / 2 - 180 * font_mult, y - 10, 360 * font_mult, 65 * font_mult), bg_color)
		if is_selected:
			canvas.draw_rect(Rect2(vp.x / 2 - 180 * font_mult, y - 10, 4, 65 * font_mult), Color(0.9, 0.7, 0.2))
		canvas.draw_string(
			ThemeDB.fallback_font, Vector2(vp.x / 2 - 160 * font_mult, y + 15),
			name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * font_mult), text_color,
		)
		canvas.draw_string(
			ThemeDB.fallback_font, Vector2(vp.x / 2 - 160 * font_mult, y + 40),
			desc, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * font_mult), Color(0.5, 0.48, 0.42),
		)
	canvas.draw_string(
		ThemeDB.fallback_font, Vector2(vp.x / 2 - 100 * font_mult, vp.y * 0.85),
		"↑↓ 选择  回车/→ 确认", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * font_mult), Color(0.5, 0.48, 0.42),
	)

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
