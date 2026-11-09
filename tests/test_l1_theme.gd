extends RefCounted

const SAND_SHA := "2b3da189b960301f0a9f54a730656f22d703e707f2c2cdf4635ca67679d84a77"
const DESERT_SHA := "b63113f09250aa07a9321db6628a3ddc3d6b84d9c78b8153f189fda14d12462c"


static func run(t: Node) -> void:
	print("\n[TEST] Level 1 terrain theme")
	_original_tiles_unchanged(t)
	_generic_maze_still_uses_shared_tiles(t)
	await _contrast(t)


static func _original_tiles_unchanged(t: Node) -> void:
	t.assert_eq(_sha("res://assets/sprites/terrain/sand.png"), SAND_SHA, "sand.png is unchanged")
	t.assert_eq(_sha("res://assets/sprites/terrain/desert.png"), DESERT_SHA, "desert.png is unchanged")
	t.assert_true(FileAccess.file_exists(AssetRegistry.l1_terrain_path("floor_road")), "l1 road slab exists")
	t.assert_true(_sha(AssetRegistry.l1_terrain_path("floor_road")) != _sha(AssetRegistry.terrain_sprite_path("ancient_road_cross_l")), "l1 road is not cross_l")


static func _generic_maze_still_uses_shared_tiles(t: Node) -> void:
	var maze := MazeGenerator.new(FirstJourney.SIZE.x, FirstJourney.SIZE.y)
	var journey := FirstJourney.new()
	journey.build(maze)
	t.assert_eq(maze.theme_key, "l1", "first journey uses the l1 theme")
	maze.theme_key = ""
	var renderer := MazeRenderer.new()
	renderer.load_sprites()
	var found := false
	for y in maze.height:
		for x in maze.width:
			if MazeGenerator.TERRAIN_KEY[maze.get_terrain(x, y)] != "ancient_road":
				continue
			var openings := 0
			for bit in [MazeGenerator.N, MazeGenerator.S, MazeGenerator.E, MazeGenerator.W]:
				if maze.grid[y][x] & bit:
					openings += 1
			if openings == 2:
				var sprite := renderer.get_terrain_sprite(maze, x, y)
				var cross: Texture2D = load(AssetRegistry.terrain_sprite_path("ancient_road_cross_l"))
				t.assert_eq(sprite, cross, "a non-l1 road still uses cross_l")
				found = true
				break
		if found:
			break
	t.assert_true(found, "the authored road still has a two-opening cell")


static func _contrast(t: Node) -> void:
	var canvas: Node2D = preload("res://tests/l1_canvas.gd").new()
	var image: Image = null
	var holder: Node = canvas
	if DisplayServer.get_name() == "headless":
		t.add_child(canvas)
		await t.get_tree().process_frame
	else:
		var sub := SubViewport.new()
		sub.size = Vector2i(FirstJourney.SIZE.x * 40, FirstJourney.SIZE.y * 40)
		sub.disable_3d = true
		sub.transparent_bg = false
		sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sub.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		t.add_child(sub)
		sub.add_child(canvas)
		holder = sub
		for _i in 4:
			await t.get_tree().process_frame
		var tex: ViewportTexture = sub.get_texture()
		if tex != null:
			image = tex.get_image()
	var maze: MazeGenerator = canvas.get("maze")
	var renderer: MazeRenderer = canvas.get("renderer")
	if image == null:
		renderer.load_sprites()
		image = _bake(renderer, maze)
	t.assert_eq(image.get_width(), FirstJourney.SIZE.x * 40, "l1 preview is 40 px per cell")
	var gaps := _gaps(image, maze)
	for key in ["sand", "ancient_road", "desert", "grotto", "oasis"]:
		t.assert_true(gaps.has(key), "l1 has a wall beside " + key)
		var stats: Dictionary = gaps[key]
		t.assert_true(float(stats["min"]) >= 77.0, "%s wall/floor grayscale gap min %.1f over %d edges" % [key, float(stats["min"]), int(stats["count"])])
	image.save_png("/opt/cursor/artifacts/l1-full.png")
	_save_crop(image, Vector2i(3, 2), "l1-sand")
	_save_crop(image, Vector2i(6, 5), "l1-road")
	_save_crop(image, Vector2i(7, 8), "l1-grotto")
	_save_crop(image, Vector2i(3, 9), "l1-oasis")
	_save_crop(image, Vector2i(3, 11), "l1-waterskin")
	if is_instance_valid(holder):
		holder.free()


static func _gaps(image: Image, maze: MazeGenerator) -> Dictionary:
	var buckets := {}
	for y in maze.height:
		for x in maze.width:
			if maze.grid[y][x] != 0:
				continue
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + step.x
				var ny: int = y + step.y
				if nx < 0 or ny < 0 or nx >= maze.width or ny >= maze.height or maze.grid[ny][nx] == 0:
					continue
				var key: String = MazeGenerator.TERRAIN_KEY[maze.get_terrain(nx, ny)]
				var gap := _edge_gap(image, x, y, step)
				if not buckets.has(key):
					buckets[key] = {"min": gap, "count": 1}
				else:
					buckets[key]["count"] = int(buckets[key]["count"]) + 1
					buckets[key]["min"] = minf(float(buckets[key]["min"]), gap)
	return buckets


static func _edge_gap(image: Image, x: int, y: int, step: Vector2i) -> float:
	var wall_sum := 0.0
	var floor_sum := 0.0
	var count := 0
	var x0 := x * 40
	var y0 := y * 40
	if step.x == 1:
		for py in range(4, 36):
			for px in range(6):
				wall_sum += _gray(image, x0 + 34 + px, y0 + py)
				floor_sum += _gray(image, x0 + 40 + px, y0 + py)
				count += 1
	elif step.x == -1:
		for py in range(4, 36):
			for px in range(6):
				wall_sum += _gray(image, x0 + px, y0 + py)
				floor_sum += _gray(image, x0 - 6 + px, y0 + py)
				count += 1
	elif step.y == 1:
		for py in range(6):
			for px in range(4, 36):
				wall_sum += _gray(image, x0 + px, y0 + 34 + py)
				floor_sum += _gray(image, x0 + px, y0 + 40 + py)
				count += 1
	else:
		for py in range(6):
			for px in range(4, 36):
				wall_sum += _gray(image, x0 + px, y0 + py)
				floor_sum += _gray(image, x0 + px, y0 - 6 + py)
				count += 1
	return (floor_sum - wall_sum) / float(count) * 255.0


static func _gray(image: Image, px: int, py: int) -> float:
	var pixel := image.get_pixel(px, py)
	return 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b


static func _save_crop(image: Image, center: Vector2i, name: String) -> void:
	var left := clampi((center.x - 2) * 40, 0, image.get_width() - 200)
	var top := clampi((center.y - 2) * 40, 0, image.get_height() - 200)
	image.get_region(Rect2i(left, top, 200, 200)).save_png("/opt/cursor/artifacts/%s.png" % name)


static func _sha(path: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(FileAccess.get_file_as_bytes(path))
	return ctx.finish().hex_encode()


static func _bake(renderer: MazeRenderer, maze: MazeGenerator) -> Image:
	var image := Image.create(maze.width * 40, maze.height * 40, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.92, 0.88, 0.78))
	for y in maze.height:
		for x in maze.width:
			_bake_cell(image, renderer, maze, x, y)
	for y in maze.height:
		for x in maze.width:
			_bake_edges(image, maze, x, y)
	return image


static func _sample(src: Image, u: int, v: int) -> Color:
	var sx := clampi(int(float(u) * src.get_width() / 40.0), 0, src.get_width() - 1)
	var sy := clampi(int(float(v) * src.get_height() / 40.0), 0, src.get_height() - 1)
	return src.get_pixel(sx, sy)


static func _bake_cell(image: Image, renderer: MazeRenderer, maze: MazeGenerator, x: int, y: int) -> void:
	var origin := Vector2i(x * 40, y * 40)
	var tex: Texture2D
	if maze.grid[y][x] == 0:
		var wall_key := "l1_wall" if (x * 7 + y * 3) % 5 != 0 else "l1_wall_alt"
		if y + 1 < maze.height and maze.grid[y + 1][x] != 0:
			wall_key = "l1_wall_face"
		tex = renderer.terrain_sprites.get(wall_key)
	else:
		tex = renderer._l1_floor_texture(maze, x, y)
	var src := tex.get_image()
	for py in 40:
		for px in 40:
			image.set_pixel(origin.x + px, origin.y + py, _sample(src, px, py))


static func _blend(dst: Color, src: Color) -> Color:
	if src.a >= 1.0:
		return src
	return Color(src.r * src.a + dst.r * (1.0 - src.a), src.g * src.a + dst.g * (1.0 - src.a), src.b * src.a + dst.b * (1.0 - src.a), 1.0)


static func _fill(image: Image, rect: Rect2i, color: Color) -> void:
	for y in rect.size.y:
		for x in rect.size.x:
			var px := rect.position.x + x
			var py := rect.position.y + y
			if px < 0 or py < 0 or px >= image.get_width() or py >= image.get_height():
				continue
			image.set_pixel(px, py, _blend(image.get_pixel(px, py), color))


static func _solid(maze: MazeGenerator, x: int, y: int) -> bool:
	return x < 0 or y < 0 or x >= maze.width or y >= maze.height or maze.grid[y][x] == 0


static func _bake_edges(image: Image, maze: MazeGenerator, x: int, y: int) -> void:
	var origin := Vector2i(x * 40, y * 40)
	if _solid(maze, x, y):
		if not _solid(maze, x, y - 1):
			_fill(image, Rect2i(origin, Vector2i(40, 2)), Color("9a6236"))
		return
	var cell: int = maze.grid[y][x]
	var wall_col := Color("74421f")
	if (cell & MazeGenerator.E) == 0 and not _solid(maze, x + 1, y):
		_fill(image, Rect2i(origin.x + 38, origin.y, 4, 40), wall_col)
	if (cell & MazeGenerator.S) == 0 and not _solid(maze, x, y + 1):
		_fill(image, Rect2i(origin.x, origin.y + 38, 40, 4), wall_col)
	if _solid(maze, x, y - 1) or (cell & MazeGenerator.N) == 0:
		var shadow_y := 0 if _solid(maze, x, y - 1) else 2
		_fill(image, Rect2i(origin.x, origin.y + shadow_y, 40, 3), Color(0.24, 0.13, 0.05, 0.38))
	if _solid(maze, x - 1, y):
		_fill(image, Rect2i(origin.x, origin.y, 2, 40), Color(0.24, 0.13, 0.05, 0.22))
