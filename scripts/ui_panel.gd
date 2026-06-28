class_name UIPanel
extends RefCounted

var panel_bg := Color(0.12, 0.10, 0.08)
var text_primary := Color(0.9, 0.85, 0.75)
var text_secondary := Color(0.65, 0.6, 0.52)
var text_dim := Color(0.45, 0.42, 0.38)
var accent := Color(0.9, 0.75, 0.3)
var hp_green := Color(0.2, 0.7, 0.3)
var hp_red := Color(0.9, 0.15, 0.1)

func draw_panel(owner: Node2D, panel_x: float, panel_w: float, vp_h: float,
		player, maze, maze_w: int, maze_h: int, exit_pos: Vector2i,
		levels_data: Array, level_idx: int, diff_name: String,
		move_count: int, terrain_name: String, buff_info: String,
		visited: Dictionary, revealed_func: Callable,
		combat_log: Array, inventory: Inventory) -> void:

	owner.draw_rect(Rect2(panel_x, 0, panel_w, vp_h), panel_bg)

	var y: float = 15
	var lx: float = panel_x + 12

	# Title
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"敦煌迷途", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, accent)
	y += 25

	var level_name = ""
	if level_idx < levels_data.size():
		level_name = levels_data[level_idx].get("name", "")
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"%s [%s]" % [level_name, diff_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_secondary)
	y += 22

	# HP bar
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_primary)
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx + 25, y),
		"%d / %d" % [player.hp, player.max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_primary)
	y += 6
	var bar_w: float = panel_w - 24
	owner.draw_rect(Rect2(lx, y, bar_w, 12), Color(0.3, 0.1, 0.1))
	var hp_ratio: float = float(player.hp) / float(player.max_hp)
	owner.draw_rect(Rect2(lx, y, bar_w * hp_ratio, 12),
		hp_green if hp_ratio > 0.3 else hp_red)
	y += 20

	# Stats
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"攻击: %d" % player.get_effective_atk(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_primary)
	y += 17
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"步数: %d" % move_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_primary)
	y += 17
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"地形: %s" % terrain_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_primary)
	y += 17

	if buff_info != "":
		owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
			buff_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.85, 0.4))
		y += 17

	y += 5

	# Minimap
	var cell_px: int = 3
	var mw: int = maze_w * cell_px
	var mh: int = maze_h * cell_px
	var mx: float = lx + (panel_w - 24 - mw) / 2
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
	y += mh + 10

	# Inventory
	y = _draw_inventory(owner, lx, y, panel_w - 24, inventory)

	y += 8

	# Terrain legend
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"地形", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_primary)
	y += 5
	for t_key in DataLoader.terrain_data:
		y += 16
		var cfg = DataLoader.terrain_data[t_key]
		var c = DataLoader.color_from_array(cfg.get("floor_color", [0.5, 0.5, 0.5]))
		owner.draw_rect(Rect2(lx, y - 11, 10, 10), c)
		owner.draw_string(ThemeDB.fallback_font, Vector2(lx + 14, y),
			cfg.get("name", t_key), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_secondary)
	y += 18

	# Monster legend
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"敌人", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_primary)
	y += 5
	for t_key in DataLoader.monster_data:
		y += 15
		var def = DataLoader.monster_data[t_key]
		var mc = DataLoader.color_from_array(def.get("color", [0.5, 0.5, 0.5]))
		mc = Color(minf(mc.r + 0.15, 1.0), minf(mc.g + 0.15, 1.0), minf(mc.b + 0.15, 1.0))
		owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
			def.get("symbol", "?") + " " + def.get("name", "?"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, mc)
	y += 20

	# Controls
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"WASD 移动", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_dim)
	y += 15
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"R 重新生成", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_dim)
	y += 15
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"E 使用道具", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_dim)
	y += 15
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"Q 返回主界面", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_dim)
	y += 20

	# Combat log
	if combat_log.size() > 0:
		owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
			"战斗日志", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_secondary)
		y += 5
		for i in range(combat_log.size() - 1, -1, -1):
			y += 15
			if y > vp_h - 20:
				break
			owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
				combat_log[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.7, 0.62))

func _draw_inventory(owner: Node2D, lx: float, y: float, w: float, inventory: Inventory) -> float:
	owner.draw_string(ThemeDB.fallback_font, Vector2(lx, y),
		"背包 (%d/%d)" % [inventory.get_count(), inventory.max_size],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_primary)
	y += 5

	var inv_items = inventory.get_item_list()
	if inv_items.is_empty():
		y += 16
		owner.draw_string(ThemeDB.fallback_font, Vector2(lx + 10, y),
			"空", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_dim)
	else:
		for i in inv_items.size():
			y += 18
			var item = inv_items[i]
			var type_color = text_primary
			match item.type:
				"heal": type_color = Color(0.3, 0.8, 0.4)
				"attack": type_color = Color(0.9, 0.4, 0.2)
				"defense": type_color = Color(0.4, 0.6, 0.9)
				"reveal": type_color = Color(0.9, 0.8, 0.3)
			owner.draw_string(ThemeDB.fallback_font, Vector2(lx + 5, y),
				"%d. %s %s" % [i + 1, item.symbol, item.name],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, type_color)

	y += 8
	return y

func draw_overlay(owner: Node2D, vp: Vector2, title: String, sub: String, hint: String, title_color: Color) -> void:
	owner.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.6))
	owner.draw_rect(Rect2(vp.x / 2 - 180, vp.y / 2 - 60, 360, 120), Color(0.1, 0.08, 0.06, 0.9))
	owner.draw_string(ThemeDB.fallback_font, Vector2(vp.x / 2 - 70, vp.y / 2 - 20),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, title_color)
	owner.draw_string(ThemeDB.fallback_font, Vector2(vp.x / 2 - 80, vp.y / 2 + 10),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	owner.draw_string(ThemeDB.fallback_font, Vector2(vp.x / 2 - 80, vp.y / 2 + 35),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.7, 0.7))
