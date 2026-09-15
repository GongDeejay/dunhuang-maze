class_name HudTopBar
extends RefCounted
## 横向顶栏 HUD（竖屏 / 平板横屏）

var panel_bg := Color(0.12, 0.10, 0.08)
var text_primary := Color(0.9, 0.85, 0.75)
var text_secondary := Color(0.65, 0.6, 0.52)
var accent := Color(0.9, 0.75, 0.3)
var inventory_chip_rects: Array[Rect2] = []
var heart_bar := HeartBar.new()


func draw(
	canvas: CanvasItem,
	rect: Rect2,
	compact: bool,
	portrait: bool,
	player,
	levels_data: Array,
	level_idx: int,
	diff_name: String,
	move_count: int,
	terrain_name: String,
	buff_info: String,
	key_tracker: KeyTracker,
	guide_dir: int,
	inventory: Inventory,
	selected_slot: int,
	low_hp_pulse: float,
	ui_scale: float = 1.0,
) -> void:
	inventory_chip_rects.clear()
	canvas.draw_rect(rect, panel_bg)
	canvas.draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y - 1, rect.size.x, 1), Color(0.25, 0.2, 0.15))

	if portrait:
		_draw_portrait(canvas, rect, compact, ui_scale, player, levels_data, level_idx, diff_name,
			move_count, terrain_name, buff_info, key_tracker, guide_dir,
			inventory, selected_slot, low_hp_pulse)
	else:
		_draw_landscape_strip(canvas, rect, compact, player, levels_data, level_idx, diff_name,
			move_count, terrain_name, buff_info, key_tracker, guide_dir,
			inventory, selected_slot, low_hp_pulse)


func _draw_portrait(
	canvas: CanvasItem,
	rect: Rect2,
	compact: bool,
	ui_scale: float,
	player,
	levels_data: Array,
	level_idx: int,
	diff_name: String,
	move_count: int,
	terrain_name: String,
	buff_info: String,
	key_tracker: KeyTracker,
	guide_dir: int,
	inventory: Inventory,
	selected_slot: int,
	low_hp_pulse: float,
) -> void:
	var pad := 12.0
	var fs_title := 22
	var fs_body := 16
	var fs_small := 14

	var level_name := ""
	if level_idx < levels_data.size():
		level_name = levels_data[level_idx].get("name", "")

	var title_max_w := rect.size.x - pad * 2.0
	var title_y := rect.position.y + pad + fs_title * 0.85
	canvas.draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + pad, title_y),
		"%s · %s" % [level_name, diff_name], HORIZONTAL_ALIGNMENT_LEFT, int(title_max_w), fs_title, accent)

	_draw_inventory_chips(canvas, rect, inventory, selected_slot, compact, fs_small, true)

	var heart_y := rect.position.y + 42.0
	var heart_h := heart_bar.draw(
		canvas,
		Vector2(rect.position.x + pad, heart_y),
		clampf(rect.size.x * 0.40, 96.0, 140.0),
		player.hp, player.max_hp, low_hp_pulse, 5,
	)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + pad + 148.0, heart_y + heart_h - 2),
		"%d/%d" % [player.hp, player.max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, fs_body, text_primary)

	var row3_y := rect.position.y + 84.0

	var rx := rect.position.x + pad
	if key_tracker != null:
		canvas.draw_string(ThemeDB.fallback_font, Vector2(rx, row3_y),
			"家人 %s" % key_tracker.get_progress(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_body, Color(0.3, 0.85, 0.45))
		rx += rect.size.x * 0.28

	canvas.draw_string(ThemeDB.fallback_font, Vector2(rx, row3_y),
		"步 %d" % move_count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_body, text_secondary)
	rx += rect.size.x * 0.18

	canvas.draw_string(ThemeDB.fallback_font, Vector2(rx, row3_y),
		"攻%d" % player.get_effective_atk(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small, text_secondary)
	rx = rect.position.x + pad
	row3_y += 23.0
	canvas.draw_string(ThemeDB.fallback_font, Vector2(rx, row3_y),
		terrain_name, HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x - pad * 2.0 - 70.0), fs_small, text_secondary)
	if guide_dir >= 0:
		rx = rect.end.x - 70.0
		canvas.draw_string(ThemeDB.fallback_font, Vector2(rx, row3_y),
			"指引%s" % _dir_label(guide_dir), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small, Color(0.55, 0.85, 0.95))
	if buff_info != "":
		canvas.draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 220.0, rect.position.y + 61.0),
			buff_info, HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x - 232), 11, Color(0.3, 0.85, 0.4))


func _draw_landscape_strip(
	canvas: CanvasItem,
	rect: Rect2,
	compact: bool,
	player,
	levels_data: Array,
	level_idx: int,
	diff_name: String,
	move_count: int,
	terrain_name: String,
	buff_info: String,
	key_tracker: KeyTracker,
	guide_dir: int,
	inventory: Inventory,
	selected_slot: int,
	low_hp_pulse: float,
) -> void:
	var pad := 10.0
	var x := rect.position.x + pad
	var row1_y := rect.position.y + pad + _fs(rect, 0.17, 16, 24, false)
	var fs_title := _fs(rect, 0.17, 16, 24, 1.0)
	var fs_body := _fs(rect, 0.14, 14, 20, 1.0)
	var fs_small := _fs(rect, 0.12, 13, 17, 1.0)

	var level_name := ""
	if level_idx < levels_data.size():
		level_name = levels_data[level_idx].get("name", "")

	canvas.draw_string(ThemeDB.fallback_font, Vector2(x, row1_y),
		"%s · %s" % [level_name, diff_name], HORIZONTAL_ALIGNMENT_LEFT, -1, fs_title, accent)
	x += 130.0 * clampf(rect.size.x / 360.0, 0.9, 1.4)

	var heart_w := clampf(rect.size.x * 0.22, 90.0, 130.0)
	var heart_y := row1_y - fs_title * 0.75
	heart_bar.draw(canvas, Vector2(x, heart_y), heart_w, player.hp, player.max_hp, low_hp_pulse, 5)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(x + heart_w + 6, row1_y - 2),
		"%d/%d" % [player.hp, player.max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small, text_primary)
	x += heart_w + 52.0

	if key_tracker != null:
		canvas.draw_string(ThemeDB.fallback_font, Vector2(x, row1_y),
			"家人 %s" % key_tracker.get_progress(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_body, Color(0.3, 0.85, 0.45))
		x += 84.0

	canvas.draw_string(ThemeDB.fallback_font, Vector2(x, row1_y),
		"步 %d" % move_count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_body, text_secondary)

	if not compact:
		var row2_y := rect.position.y + rect.size.y - pad - 2.0
		var rx := rect.position.x + pad
		canvas.draw_string(ThemeDB.fallback_font, Vector2(rx, row2_y),
			"攻%d · %s" % [player.get_effective_atk(), terrain_name], HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small, text_secondary)
		rx += 130.0
		if guide_dir >= 0:
			canvas.draw_string(ThemeDB.fallback_font, Vector2(rx, row2_y),
				"指引 %s" % _dir_label(guide_dir), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small, Color(0.55, 0.85, 0.95))
			rx += 80.0
		if buff_info != "":
			canvas.draw_string(ThemeDB.fallback_font, Vector2(rx, row2_y),
				buff_info, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small, Color(0.3, 0.85, 0.4))

	_draw_inventory_chips(canvas, rect, inventory, selected_slot, compact, fs_small, false)


func _fs(rect: Rect2, ratio: float, min_v: int, max_v: int, scale: float = 1.0) -> int:
	return int(clampf(rect.size.y * ratio * scale, float(min_v), float(max_v)))


func _draw_inventory_chips(
	canvas: CanvasItem,
	rect: Rect2,
	inventory: Inventory,
	selected_slot: int,
	compact: bool,
	fs_small: int,
	portrait: bool,
) -> void:
	var items := inventory.get_item_list()
	if items.is_empty():
		return
	var chip_w := 44.0 if portrait else (32.0 if compact else 38.0)
	var chip_h := 40.0 if portrait else (26.0 if compact else 28.0)
	var gap := 5.0
	var total_w := items.size() * chip_w + maxi(items.size() - 1, 0) * gap
	var start_x := rect.position.x + rect.size.x - 10.0 - total_w
	var chip_y := rect.position.y + (118.0 if portrait else (18.0 if compact else rect.size.y * 0.24))
	for i in items.size():
		var chip_rect := Rect2(start_x + i * (chip_w + gap), chip_y, chip_w, chip_h)
		inventory_chip_rects.append(chip_rect)
		var bg := Color(0.22, 0.18, 0.14)
		if i == selected_slot:
			bg = Color(0.35, 0.28, 0.12)
			canvas.draw_rect(chip_rect.grow(1), accent, false, 1.0)
		canvas.draw_rect(chip_rect, bg)
		var item = items[i]
		canvas.draw_string(ThemeDB.fallback_font, Vector2(chip_rect.position.x + 5, chip_rect.position.y + chip_h - 7),
			"%d%s" % [i + 1, item.symbol], HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small, text_primary)


func get_inventory_slot_at(global_pos: Vector2) -> int:
	for i in inventory_chip_rects.size():
		if inventory_chip_rects[i].has_point(global_pos):
			return i
	return -1


func _dir_label(dir: int) -> String:
	match dir:
		MazeGenerator.N: return "↑"
		MazeGenerator.S: return "↓"
		MazeGenerator.E: return "→"
		MazeGenerator.W: return "←"
	return "?"
