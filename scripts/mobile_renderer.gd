class_name MobileRenderer
extends RefCounted

var maze_renderer: MazeRenderer

func _init(renderer: MazeRenderer) -> void:
	maze_renderer = renderer


func draw_follow_in_rect(
	canvas: CanvasItem,
	maze_rect: Rect2,
	maze: MazeGenerator,
	maze_width: int,
	maze_height: int,
	player: PlayerController,
	monsters: Array,
	items: Array,
	exit_pos: Vector2i,
	game_won: bool,
	visited: Dictionary,
	is_revealed: Callable,
	guide_dir: int = -1,
	ui_scale: float = 1.0,
	focus: Rect2i = Rect2i(),
) -> void:
	if maze_rect.size.x <= 1.0 or maze_rect.size.y <= 1.0:
		return

	var origin := maze_rect.position
	var area_w := maze_rect.size.x
	var area_h := maze_rect.size.y
	var density := clampf(area_w / 390.0, 1.0, 2.0)

	# ui_scale 2.0 → 更少格子、更大像素（iPhone 可读）
	var col_div := maxf(2.5, 5.0 / ui_scale)
	var row_div := maxf(3.0, 6.5 / ui_scale)
	var target_cell := clampf(minf(area_w / col_div, area_h / row_div), 48.0 * ui_scale * density, 120.0 * density)
	var view_cols := maxi(5, int(area_w / target_cell))
	var view_rows := maxi(5, int(area_h / target_cell))
	if focus.has_area():
		view_cols = focus.size.x
		view_rows = focus.size.y
	var cell_sz := minf(area_w / float(view_cols), area_h / float(view_rows))
	if focus.has_area(): origin += (maze_rect.size - Vector2(view_cols, view_rows) * cell_sz) / 2

	var center_x := player.pos.x
	var center_y := player.pos.y
	var half_cols := view_cols / 2
	var half_rows := view_rows / 2
	var start_x := clampi(center_x - half_cols, 0, maxi(0, maze_width - view_cols))
	var start_y := clampi(center_y - half_rows, 0, maxi(0, maze_height - view_rows))
	if focus.has_area():
		start_x = focus.position.x
		start_y = focus.position.y
	var wall_w := maxf(cell_sz * 0.08, 3.0)
	var draw_scale := cell_sz / float(maze_renderer.cell_size)

	canvas.draw_rect(maze_rect, Color(0.10, 0.08, 0.07))

	for vy in view_rows:
		for vx in view_cols:
			var gx := start_x + vx
			var gy := start_y + vy
			var screen_x := origin.x + vx * cell_sz
			var screen_y := origin.y + vy * cell_sz

			if gx < 0 or gx >= maze_width or gy < 0 or gy >= maze_height:
				canvas.draw_rect(Rect2(screen_x, screen_y, cell_sz, cell_sz), Color(0.15, 0.12, 0.10))
				continue

			var t_key: String = MazeGenerator.TERRAIN_KEY[maze.get_terrain(gx, gy)]
			var cfg := DataLoader.get_terrain_config(t_key)
			var floor_color := maze_renderer.get_floor_color(maze, gx, gy)
			if not is_revealed.call(Vector2i(gx, gy)) and not visited.get(Vector2i(gx, gy), false):
				floor_color = Color(0.15, 0.12, 0.10)

			canvas.draw_rect(Rect2(screen_x, screen_y, cell_sz, cell_sz), floor_color)
			var terrain_sprite := maze_renderer.get_terrain_sprite(maze, gx, gy)
			if maze.theme_key == "mogao" and is_revealed.call(Vector2i(gx, gy)):
				maze_renderer.draw_mogao_floor(canvas, maze, Vector2i(gx, gy), Vector2(screen_x, screen_y), cell_sz)
			elif terrain_sprite and is_revealed.call(Vector2i(gx, gy)):
				canvas.draw_texture_rect(terrain_sprite, Rect2(screen_x, screen_y, cell_sz, cell_sz), false)

			var cell: int = maze.grid[gy][gx]
			maze_renderer._draw_walls(canvas, cell, Vector2(screen_x, screen_y), cell_sz, wall_w, gx, gy, maze_width, maze_height)
			maze_renderer.draw_charted_route(canvas, maze, Vector2i(gx, gy), Vector2(screen_x, screen_y), cell_sz)

			if gx == exit_pos.x and gy == exit_pos.y and (game_won or is_revealed.call(exit_pos)):
				var ep := Vector2(screen_x, screen_y)
				canvas.draw_rect(Rect2(ep + Vector2(cell_sz * 0.15, cell_sz * 0.15), Vector2(cell_sz * 0.7, cell_sz * 0.7)), Color(0.1, 0.8, 0.3))
				canvas.draw_string(
					ThemeDB.fallback_font, ep + Vector2(cell_sz * 0.3, cell_sz * 0.65),
					"门", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * draw_scale), Color.WHITE,
				)

			var landmark_pos := Vector2i(gx, gy)
			if maze.landmarks.has(landmark_pos):
				var revealed := bool(is_revealed.call(landmark_pos))
				if maze_renderer.landmark_visible(maze.landmarks[landmark_pos], revealed):
					maze_renderer.draw_landmark(canvas, maze.landmarks[landmark_pos], Vector2(screen_x, screen_y), cell_sz, revealed)
			for it in items:
				if is_instance_valid(it) and it.pos == Vector2i(gx, gy) and is_revealed.call(it.pos):
					_draw_item_in_cell(canvas, it, Vector2(screen_x, screen_y), cell_sz, wall_w)

			for m in monsters:
				if is_instance_valid(m) and m.pos == Vector2i(gx, gy) and is_revealed.call(m.pos):
					if m.pos == player.pos:
						continue
					maze_renderer.draw_monster_in_cell(canvas, m, Vector2(screen_x, screen_y), cell_sz, wall_w, draw_scale)

	var player_screen_x := origin.x + (player.pos.x - start_x) * cell_sz
	var player_screen_y := origin.y + (player.pos.y - start_y) * cell_sz
	_draw_player_in_cell(canvas, Vector2(player_screen_x, player_screen_y), cell_sz, wall_w)
	if guide_dir >= 0:
		maze_renderer.draw_path_arrow(
			canvas, player.pos - Vector2i(start_x, start_y), guide_dir,
			origin, draw_scale,
		)


func _draw_player_in_cell(canvas: CanvasItem, o: Vector2, cs: float, wt: float) -> void:
	if maze_renderer.player_sprite:
		maze_renderer.draw_sprite_in_cell(canvas, maze_renderer.player_sprite, o, cs, wt * 0.45)
	else:
		maze_renderer.draw_character(canvas, o, cs / 16.0, Color(0.27, 0.51, 0.71), Color(0.85, 0.65, 0.13), Color(1.0, 0.85, 0.72))


func _draw_item_in_cell(canvas: CanvasItem, item, o: Vector2, cs: float, wt: float) -> void:
	if item.item_type == "key":
		var family_sprite := maze_renderer.get_family_sprite(item.item_key)
		if family_sprite:
			maze_renderer.draw_sprite_in_cell(canvas, family_sprite, o, cs, wt * 0.45)
		else:
			maze_renderer.draw_character(canvas, o, cs / 16.0, Color(0.86, 0.24, 0.24), Color(0.2, 0.2, 0.2), Color(1.0, 0.85, 0.72))
		return
	var sprite: Texture2D = maze_renderer.item_sprites.get(item.item_type)
	if sprite:
		maze_renderer.draw_sprite_in_cell(canvas, sprite, o, cs, wt)
	else:
		canvas.draw_rect(Rect2(o + Vector2(wt, wt), Vector2(cs - wt * 2, cs - wt * 2)), item.color.darkened(0.2))
		canvas.draw_string(
			ThemeDB.fallback_font, o + Vector2(cs * 0.3, cs * 0.65),
			item.symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * cs / 40.0), item.color,
		)
