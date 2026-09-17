class_name UIPanel
extends RefCounted

var panel_bg := Color(0.12, 0.10, 0.08)
var text_primary := Color(0.9, 0.85, 0.75)
var text_secondary := Color(0.65, 0.6, 0.52)
var text_dim := Color(0.62, 0.58, 0.51)
var accent := Color(0.9, 0.75, 0.3)
var hp_green := Color(0.2, 0.7, 0.3)
var hp_red := Color(0.9, 0.15, 0.1)
var inventory_hit_rects: Array[Rect2] = []
var panel_origin_x: float = 0.0
var heart_bar := HeartBar.new()

func draw_panel(owner: Node2D, panel_x: float, panel_w: float, vp_h: float,
		player, maze, maze_w: int, maze_h: int, exit_pos: Vector2i,
		levels_data: Array, level_idx: int, diff_name: String,
		move_count: int, terrain_name: String, buff_info: String,
		visited: Dictionary, revealed_func: Callable,
		combat_log: Array, inventory: Inventory, key_tracker: KeyTracker = null,
		selected_slot: int = 0, items: Array = [], guide_dir: int = -1,
		low_hp_pulse: float = 0.0, ui_scale: float = 1.0) -> void:

	panel_origin_x = panel_x
	inventory_hit_rects.clear()

	owner.draw_rect(Rect2(panel_x, 0, panel_w, vp_h), panel_bg)

	var s := clampf(ui_scale, 1.0, 1.35)
	var title_fs := int(round(23.0 * s))
	var body_fs := int(round(15.0 * s))
	var small_fs := int(round(13.0 * s))
	var tiny_fs := int(round(12.0 * s))
	var line_h := 18.0 * s
	var pad := 14.0 * s
	var y: float = 18.0 * s
	var lx: float = panel_x + pad

	# Title
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"敦煌迷途", HORIZONTAL_ALIGNMENT_LEFT, -1, title_fs, accent)
	y += 28.0 * s

	var level_name = ""
	if level_idx < levels_data.size():
		level_name = levels_data[level_idx].get("name", "")
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"%s [%s]" % [level_name, diff_name], HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, text_secondary)
	y += 23.0 * s

	# HP hearts
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"生命", HORIZONTAL_ALIGNMENT_LEFT, -1, body_fs, text_primary)
	y += 5.0 * s
	var bar_w: float = panel_w - pad * 2.0
	heart_bar.draw(owner, Vector2(lx, y), bar_w, player.hp, player.max_hp, low_hp_pulse, 6)
	y += 25.0 * s
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"%d / %d" % [player.hp, player.max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, text_secondary)
	if float(player.hp) / float(maxi(player.max_hp, 1)) <= 0.3:
		owner.draw_string(ThemeDB.fallback_font, Vector2(lx + bar_w - 48, y - 24),
			"低血!", HORIZONTAL_ALIGNMENT_LEFT, -1, tiny_fs,
			Color(1.0, 0.35, 0.25, 0.7 + 0.3 * clampf(low_hp_pulse, 0.0, 1.0)))
	y += line_h

	# Stats
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"攻击: %d" % player.get_effective_atk(), HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, text_primary)
	y += line_h
	if player.level > 1:
		owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
			"等级: Lv.%d" % player.level, HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, accent)
		y += line_h
	if key_tracker != null:
		owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
			"家人: %s" % key_tracker.get_progress(), HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, Color(0.3, 0.85, 0.45))
		y += line_h
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"步数: %d" % move_count, HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, text_primary)
	y += line_h
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"地形: %s" % terrain_name, HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, text_primary)
	y += line_h

	if buff_info != "":
		owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
			buff_info, HORIZONTAL_ALIGNMENT_LEFT, -1, tiny_fs, Color(0.3, 0.85, 0.4))
		y += line_h

	y += 5

	# Minimap
	var cell_px: int = clampi(int(floor((panel_w - pad * 2.0) / float(maxi(maze_w, 1)))), 3, int(round(5.0 * s)))
	var mw: int = maze_w * cell_px
	var mh: int = maze_h * cell_px
	var mx: float = lx + (panel_w - pad * 2.0 - mw) / 2
	owner.draw_rect(Rect2(mx - 2, y - 2, mw + 4, mh + 4), Color(0.25, 0.2, 0.15))
	owner.draw_rect(Rect2(mx, y, mw, mh), Color(0.15, 0.12, 0.10))
	for my in maze_h:
		for mmx in maze_w:
			var mpos = Vector2i(mmx, my)
			if not visited.get(mpos, false):
				continue
			var t = maze.get_terrain(mmx, my)
			var t_key = MazeGenerator.TERRAIN_KEY[t]
			var cfg = DataLoader.get_terrain_config(t_key)
			var fc = DataLoader.color_from_array(cfg.get("floor_color", [0.5, 0.5, 0.5]))
			if not revealed_func.call(mpos):
				fc = fc.darkened(0.4)
			owner.draw_rect(Rect2(mx + mmx * cell_px, y + my * cell_px, cell_px, cell_px), fc)
	var mep = Vector2(mx + exit_pos.x * cell_px, y + exit_pos.y * cell_px)
	owner.draw_rect(Rect2(mep, Vector2(cell_px, cell_px)), Color(0.2, 0.8, 0.3))
	var mpp = Vector2(mx + player.pos.x * cell_px, y + player.pos.y * cell_px)
	owner.draw_rect(Rect2(mpp, Vector2(cell_px, cell_px)), Color(0.9, 0.15, 0.1))
	for it in items:
		if not is_instance_valid(it):
			continue
		if not visited.get(it.pos, false):
			continue
		var dot_color := Color(0.3, 0.85, 0.45) if it.item_type == "key" else Color(0.95, 0.85, 0.25)
		var dp := Vector2(mx + it.pos.x * cell_px, y + it.pos.y * cell_px)
		owner.draw_rect(Rect2(dp + Vector2(0.5, 0.5), Vector2(cell_px - 1, cell_px - 1)), dot_color)
	y += mh + 12.0 * s

	if guide_dir >= 0:
		owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
			"指引: %s" % _dir_label(guide_dir), HORIZONTAL_ALIGNMENT_LEFT, -1, tiny_fs, Color(0.55, 0.85, 0.95))
		y += line_h

	# Inventory
	y = _draw_inventory(owner, lx, y, panel_w - pad * 2.0, inventory, selected_slot, s)

	y += 8

	# Terrain legend
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"地形", HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, text_primary)
	y += 5
	for t_key in DataLoader.terrain_data:
		y += 16
		var cfg = DataLoader.terrain_data[t_key]
		var c = DataLoader.color_from_array(cfg.get("floor_color", [0.5, 0.5, 0.5]))
		owner.draw_rect(Rect2(lx, y - 11, 10, 10), c)
		owner.draw_string(ThemeDB.fallback_font, Vector2(lx + 14, y),
			cfg.get("name", t_key), HORIZONTAL_ALIGNMENT_LEFT, -1, tiny_fs, text_secondary)
	y += 18

	# Monster legend
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"敌人", HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, text_primary)
	y += 5
	for t_key in DataLoader.monster_data:
		y += 15
		var def = DataLoader.monster_data[t_key]
		var mc = DataLoader.color_from_array(def.get("color", [0.5, 0.5, 0.5]))
		mc = Color(minf(mc.r + 0.15, 1.0), minf(mc.g + 0.15, 1.0), minf(mc.b + 0.15, 1.0))
		owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
			def.get("symbol", "?") + " " + def.get("name", "?"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, tiny_fs, mc)
	y += 20

	# Controls
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"WASD / 方向键移动", HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, text_dim)
	y += line_h
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"P / Esc 暂停", HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, text_dim)
	y += line_h
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"R 重开本关", HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, text_dim)
	y += line_h
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"1-5 选道具 · E 使用", HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, text_dim)
	y += line_h
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"Q 返回主界面", HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, text_dim)
	y += 22.0 * s

	# Combat log
	if combat_log.size() > 0:
		owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
			"战斗日志", HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, text_secondary)
		y += 6.0 * s
		for i in range(combat_log.size() - 1, -1, -1):
			y += line_h
			if y > vp_h - 20:
				break
			owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
				combat_log[i], HORIZONTAL_ALIGNMENT_LEFT, int(panel_w - pad * 2.0), tiny_fs, Color(0.8, 0.75, 0.66))

func _draw_inventory(owner: Node2D, lx: float, y: float, w: float, inventory: Inventory, selected_slot: int, scale: float = 1.0) -> float:
	var label_fs := int(round(13.0 * scale))
	var item_fs := int(round(12.0 * scale))
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"背包 (%d/%d)" % [inventory.get_count(), inventory.max_size],
		HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs, text_primary)
	y += 5

	var inv_items = inventory.get_item_list()
	if inv_items.is_empty():
		y += 16
		owner.draw_string(ThemeDB.fallback_font, Vector2(lx + 10, y),
			"空", HORIZONTAL_ALIGNMENT_LEFT, -1, item_fs, text_dim)
	else:
		for i in inv_items.size():
			y += 18
			var row_rect := Rect2(lx, y - 14, w, 18)
			inventory_hit_rects.append(row_rect)
			if i == selected_slot:
				owner.draw_rect(row_rect.grow(1), Color(0.35, 0.3, 0.15))
				owner.draw_rect(row_rect, accent, false, 1.0)
			var item = inv_items[i]
			var type_color = text_primary
			match item.type:
				"heal": type_color = Color(0.3, 0.8, 0.4)
				"attack": type_color = Color(0.9, 0.4, 0.2)
				"defense": type_color = Color(0.4, 0.6, 0.9)
				"reveal": type_color = Color(0.9, 0.8, 0.3)
			var prefix := "▶ " if i == selected_slot else "  "
			owner.draw_string(ThemeDB.fallback_font, Vector2(lx + 5, y),
				"%s%d. %s %s" % [prefix, i + 1, item.symbol, item.name],
				HORIZONTAL_ALIGNMENT_LEFT, -1, item_fs, type_color)

	y += 8
	return y

func get_inventory_slot_at(global_pos: Vector2) -> int:
	for i in inventory_hit_rects.size():
		var rect := inventory_hit_rects[i]
		if rect.has_point(global_pos):
			return i
	return -1

func _dir_label(dir: int) -> String:
	match dir:
		MazeGenerator.N: return "↑ 北"
		MazeGenerator.S: return "↓ 南"
		MazeGenerator.E: return "→ 东"
		MazeGenerator.W: return "← 西"
	return "?"

func draw_overlay(owner: Node2D, vp: Vector2, title: String, sub: String, hint: String, title_color: Color) -> void:
	owner.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.6))
	owner.draw_rect(Rect2(vp.x / 2 - 180, vp.y / 2 - 60, 360, 120), Color(0.1, 0.08, 0.06, 0.9))
	owner.draw_string(ThemeDB.fallback_font, Vector2(vp.x / 2 - 70, vp.y / 2 - 20),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, title_color)
	owner.draw_string(ThemeDB.fallback_font, Vector2(vp.x / 2 - 80, vp.y / 2 + 10),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	owner.draw_string(ThemeDB.fallback_font, Vector2(vp.x / 2 - 80, vp.y / 2 + 35),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.7, 0.7))

func draw_confirm_overlay(owner: Node2D, vp: Vector2, title: String, sub: String, hint: String) -> void:
	owner.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.55))
	var panel_w := minf(vp.x - 28.0, 430.0)
	var panel_h := 190.0
	var panel := Rect2(vp.x * 0.5 - panel_w * 0.5, vp.y * 0.5 - panel_h * 0.5, panel_w, panel_h)
	owner.draw_rect(panel, Color(0.12, 0.1, 0.08, 0.97))
	owner.draw_rect(panel, Color(0.65, 0.5, 0.18), false, 2.0)
	owner.draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 18, panel.position.y + 38),
		title, HORIZONTAL_ALIGNMENT_CENTER, int(panel.size.x - 36), 21, accent)
	owner.draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 18, panel.position.y + 70),
		sub, HORIZONTAL_ALIGNMENT_CENTER, int(panel.size.x - 36), 14, text_secondary)
	var buttons := get_confirm_button_rects(vp)
	owner.draw_rect(buttons.no, Color(0.20, 0.17, 0.14))
	owner.draw_rect(buttons.yes, Color(0.35, 0.27, 0.10))
	owner.draw_rect(buttons.yes, accent, false, 1.5)
	owner.draw_string(ThemeDB.fallback_font, buttons.no.position + Vector2(0, 29),
		"取消", HORIZONTAL_ALIGNMENT_CENTER, int(buttons.no.size.x), 15, text_secondary)
	owner.draw_string(ThemeDB.fallback_font, buttons.yes.position + Vector2(0, 29),
		"确认新旅途", HORIZONTAL_ALIGNMENT_CENTER, int(buttons.yes.size.x), 15, text_primary)
	owner.draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 18, panel.end.y - 14),
		hint, HORIZONTAL_ALIGNMENT_CENTER, int(panel.size.x - 36), 11, text_dim)


func get_confirm_button_rects(vp: Vector2) -> Dictionary:
	var panel_w := minf(vp.x - 28.0, 430.0)
	var panel_h := 190.0
	var panel := Rect2(vp.x * 0.5 - panel_w * 0.5, vp.y * 0.5 - panel_h * 0.5, panel_w, panel_h)
	var gap := 12.0
	var margin := 18.0
	var button_w := (panel.size.x - margin * 2.0 - gap) * 0.5
	var y := panel.position.y + 92.0
	return {
		"no": Rect2(panel.position.x + margin, y, button_w, 44.0),
		"yes": Rect2(panel.position.x + margin + button_w + gap, y, button_w, 44.0),
	}
