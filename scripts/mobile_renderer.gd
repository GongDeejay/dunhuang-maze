class_name MobileRenderer
extends RefCounted

var maze_renderer: MazeRenderer

func _init(renderer: MazeRenderer) -> void:
	maze_renderer = renderer

func draw_mobile_view(
	canvas: CanvasItem,
	vp: Vector2,
	maze: MazeGenerator,
	maze_width: int,
	maze_height: int,
	player: PlayerController,
	monsters: Array,
	items: Array,
	exit_pos: Vector2i,
	game_won: bool,
	game_over: bool,
	visited: Dictionary,
	is_revealed: Callable,
	is_portrait: bool,
	levels_data: Array,
	current_level_index: int,
	move_count: int,
) -> void:
	var view_cols: int = 6 if is_portrait else 10
	var view_rows: int = 10 if is_portrait else 6
	var game_w: float = vp.x
	var game_h: float = vp.y
	var cell_w: float = game_w / view_cols
	var cell_h: float = game_h / view_rows
	var cell_sz: float = minf(cell_w, cell_h)
	var center_x: int = player.pos.x
	var center_y: int = player.pos.y
	var half_cols: int = view_cols / 2
	var half_rows: int = view_rows / 2
	var start_x: int = center_x - half_cols
	var start_y: int = center_y - half_rows
	var wall_w: float = maxf(cell_sz * 0.08, 3.0)
	var key_idx := 0

	canvas.draw_rect(Rect2(0, 0, game_w, game_h), Color(0.12, 0.10, 0.08))

	for vy in view_rows:
		for vx in view_cols:
			var gx: int = start_x + vx
			var gy: int = start_y + vy
			var screen_x: float = vx * cell_sz
			var screen_y: float = vy * cell_sz

			if gx < 0 or gx >= maze_width or gy < 0 or gy >= maze_height:
				canvas.draw_rect(Rect2(screen_x, screen_y, cell_sz, cell_sz), Color(0.15, 0.12, 0.10))
				continue

			var t_key: String = MazeGenerator.TERRAIN_KEY[maze.get_terrain(gx, gy)]
			var cfg := DataLoader.get_terrain_config(t_key)
			var floor_color := DataLoader.color_from_array(cfg.get("floor_color", [0.8, 0.8, 0.8]))
			if not is_revealed.call(Vector2i(gx, gy)) and not visited.get(Vector2i(gx, gy), false):
				floor_color = Color(0.15, 0.12, 0.10)

			canvas.draw_rect(Rect2(screen_x, screen_y, cell_sz, cell_sz), floor_color)
			var terrain_sprite := maze_renderer.get_terrain_sprite(maze, gx, gy)
			if terrain_sprite and is_revealed.call(Vector2i(gx, gy)):
				canvas.draw_texture_rect(terrain_sprite, Rect2(screen_x, screen_y, cell_sz, cell_sz), false)

			var cell: int = maze.grid[gy][gx]
			maze_renderer._draw_walls(canvas, cell, Vector2(screen_x, screen_y), cell_sz, wall_w, gx, gy, maze_width, maze_height)

			if gx == exit_pos.x and gy == exit_pos.y and (game_won or is_revealed.call(exit_pos)):
				canvas.draw_rect(
					Rect2(screen_x + cell_sz * 0.2, screen_y + cell_sz * 0.2, cell_sz * 0.6, cell_sz * 0.6),
					Color(0.1, 0.8, 0.3),
				)

			for it in items:
				if is_instance_valid(it) and it.pos == Vector2i(gx, gy) and is_revealed.call(it.pos):
					if it.item_type == "key":
						draw_mini_character(canvas, Vector2(screen_x, screen_y), cell_sz, key_idx)
						key_idx += 1
					else:
						draw_item_sprite(canvas, Vector2(screen_x, screen_y), cell_sz, it)

			for m in monsters:
				if is_instance_valid(m) and m.pos == Vector2i(gx, gy) and is_revealed.call(m.pos):
					_draw_monster_icon(canvas, m, screen_x, screen_y, cell_sz)

	var player_screen_x: float = half_cols * cell_sz
	var player_screen_y: float = half_rows * cell_sz
	draw_mini_character(canvas, Vector2(player_screen_x, player_screen_y), cell_sz, 1)
	_draw_completion_overlay(canvas, vp, game_over, game_won, levels_data, current_level_index, move_count)

func draw_mini_character(canvas: CanvasItem, o: Vector2, s: float, char_type: int) -> void:
	var sprite: Texture2D
	if char_type == 1:
		sprite = maze_renderer.player_sprite
	else:
		sprite = maze_renderer.family_sprites[char_type % maze_renderer.family_sprites.size()]
	if sprite:
		canvas.draw_texture_rect(sprite, Rect2(o, Vector2(s, s)), false)

func draw_item_sprite(canvas: CanvasItem, o: Vector2, s: float, item) -> void:
	var sprite: Texture2D = maze_renderer.item_sprites.get(item.item_type)
	if sprite:
		canvas.draw_texture_rect(sprite, Rect2(o, Vector2(s, s)), false)
	else:
		var item_cx := o.x + s * 0.5
		var item_cy := o.y + s * 0.5
		var item_r := s * 0.25
		canvas.draw_circle(Vector2(item_cx, item_cy), item_r, item.color.darkened(0.2))
		canvas.draw_circle(Vector2(item_cx, item_cy), item_r * 0.6, item.color)

func _draw_monster_icon(canvas: CanvasItem, m: MonsterEntity, screen_x: float, screen_y: float, cell_sz: float) -> void:
	var mcx := screen_x + cell_sz * 0.5
	var mcy := screen_y + cell_sz * 0.5
	var mr := cell_sz * 0.3
	canvas.draw_circle(Vector2(mcx, mcy), mr, m.color.darkened(0.4))
	canvas.draw_circle(Vector2(mcx, mcy), mr * 0.7, m.color.darkened(0.2))
	var monster_names := {"sand": "蝎", "desert": "虫", "grotto": "魔", "oasis": "妖", "ancient_road": "匪"}
	var label: String = monster_names.get(m.monster_type, "?")
	var label_fs := int(cell_sz * 0.2)
	canvas.draw_string(
		ThemeDB.fallback_font, Vector2(mcx - label_fs / 2, screen_y + label_fs + 2),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs, Color(1, 1, 1, 0.9),
	)

func _draw_completion_overlay(
	canvas: CanvasItem,
	vp: Vector2,
	game_over: bool,
	game_won: bool,
	levels_data: Array,
	current_level_index: int,
	move_count: int,
) -> void:
	if game_over:
		canvas.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.7))
		var fs := int(36 * minf(vp.x, vp.y) / 400.0)
		canvas.draw_string(
			ThemeDB.fallback_font, Vector2(vp.x / 2 - 80, vp.y / 2 - 30),
			"你倒下了...", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.9, 0.3, 0.2),
		)
		canvas.draw_string(
			ThemeDB.fallback_font, Vector2(vp.x / 2 - 60, vp.y / 2 + 20),
			"走了 %d 步" % move_count, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.6), Color.WHITE,
		)
		canvas.draw_string(
			ThemeDB.fallback_font, Vector2(vp.x / 2 - 80, vp.y / 2 + 60),
			"按 R 重新尝试", HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.5), Color(0.7, 0.7, 0.7),
		)
	elif game_won:
		var is_final := current_level_index + 1 >= levels_data.size()
		var title := "通关!" if is_final else "穿越成功!"
		var sub := "你穿越了所有关卡" if is_final else "%s 已通关" % levels_data[current_level_index].get("name", "")
		var hint := "按 R 重新开始" if is_final else "按 R 进入下一关"
		var fs := int(36 * minf(vp.x, vp.y) / 400.0)
		canvas.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.7))
		var title_color := Color(1.0, 0.85, 0.3) if is_final else Color.WHITE
		canvas.draw_string(
			ThemeDB.fallback_font, Vector2(vp.x / 2 - 80, vp.y / 2 - 40),
			title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, title_color,
		)
		canvas.draw_string(
			ThemeDB.fallback_font, Vector2(vp.x / 2 - 100, vp.y / 2 + 10),
			sub + "\n用了 %d 步" % move_count, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.5), Color.WHITE,
		)
		canvas.draw_string(
			ThemeDB.fallback_font, Vector2(vp.x / 2 - 80, vp.y / 2 + 60),
			hint, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.5), Color(0.7, 0.7, 0.7),
		)
