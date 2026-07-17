class_name GameViewComposer
extends RefCounted
## 统一游戏画面绘制：布局 → HUD + Follow/Fit 地图

var maze_renderer: MazeRenderer
var mobile_renderer: MobileRenderer
var ui_panel: UIPanel
var hud_top_bar: HudTopBar

func _init(renderer: MazeRenderer, mobile: MobileRenderer, panel: UIPanel) -> void:
	maze_renderer = renderer
	mobile_renderer = mobile
	ui_panel = panel
	hud_top_bar = HudTopBar.new()


func draw(canvas: CanvasItem, layout: LayoutProfile, ctx: Dictionary) -> void:
	var vp: Vector2 = layout.viewport_size
	canvas.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.12, 0.10, 0.08))

	match layout.mode:
		LayoutProfile.Mode.DESKTOP_SIDE:
			_draw_desktop(canvas, layout, ctx)
		_:
			_draw_dynamic(canvas, layout, ctx)

	if ctx.get("game_over", false):
		ui_panel.draw_overlay(canvas, vp, "你倒下了...", "走了 %d 步" % ctx.get("move_count", 0), "按 R 重新尝试", Color(0.9, 0.3, 0.2))
	elif ctx.get("game_won", false):
		var level_idx: int = ctx.get("current_level_index", 0)
		var levels: Array = ctx.get("levels_data", [])
		var is_final := level_idx + 1 >= levels.size()
		var title := "通关!" if is_final else "穿越成功!"
		var sub := "你穿越了所有关卡" if is_final else "%s 已通关" % levels[level_idx].get("name", "")
		var hint := "按 R 重新开始" if is_final else "按 R 进入下一关"
		var c := Color(1.0, 0.85, 0.3) if is_final else Color.WHITE
		ui_panel.draw_overlay(canvas, vp, title, sub + "\n用了 %d 步" % ctx.get("move_count", 0), hint, c)


func _draw_desktop(canvas: CanvasItem, layout: LayoutProfile, ctx: Dictionary) -> void:
	maze_renderer.draw_pc_view(
		canvas, layout.viewport_size,
		ctx.maze, ctx.maze_width, ctx.maze_height,
		ctx.player, ctx.monsters, ctx.items, ctx.exit_pos,
		ctx.exit_visible, ctx.game_won, ctx.visited, ctx.is_revealed,
		ui_panel, ctx.levels_data, ctx.current_level_index,
		ctx.difficulty_name, ctx.move_count, ctx.terrain_name,
		ctx.buff_display, ctx.combat_log, ctx.inventory, ctx.key_tracker,
		ctx.selected_slot, ctx.guide_dir, ctx.low_hp_pulse,
	)


func _draw_dynamic(canvas: CanvasItem, layout: LayoutProfile, ctx: Dictionary) -> void:
	var compact := layout.mode == LayoutProfile.Mode.PORTRAIT_COMPACT
	var portrait := layout.is_portrait()
	hud_top_bar.draw(
		canvas, layout.hud_rect, compact, portrait,
		ctx.player, ctx.levels_data, ctx.current_level_index,
		ctx.difficulty_name, ctx.move_count, ctx.terrain_name,
		ctx.buff_display, ctx.key_tracker, ctx.guide_dir,
		ctx.inventory, ctx.selected_slot, ctx.low_hp_pulse, layout.ui_scale,
	)

	if layout.log_rect.size.y > 0.0 and ctx.combat_log.size() > 0:
		_draw_log_strip(canvas, layout.log_rect, ctx.combat_log, layout.ui_scale)

	mobile_renderer.draw_follow_in_rect(
		canvas, layout.maze_rect,
		ctx.maze, ctx.maze_width, ctx.maze_height,
		ctx.player, ctx.monsters, ctx.items, ctx.exit_pos,
		ctx.game_won, ctx.visited, ctx.is_revealed,
		ctx.guide_dir,
		layout.ui_scale,
	)


func _draw_log_strip(canvas: CanvasItem, rect: Rect2, combat_log: Array, ui_scale: float = 1.0) -> void:
	canvas.draw_rect(rect, Color(0.08, 0.07, 0.06, 0.92))
	var msg: String = combat_log[combat_log.size() - 1]
	var fs := int(clampf(rect.size.y * 0.42 * ui_scale, 16, 28))
	canvas.draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 8, rect.position.y + rect.size.y - 8),
		msg, HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x - 16), fs, Color(0.75, 0.7, 0.62))


func get_inventory_slot_at(global_pos: Vector2, layout: LayoutProfile) -> int:
	if layout.is_side_hud():
		return ui_panel.get_inventory_slot_at(global_pos)
	return hud_top_bar.get_inventory_slot_at(global_pos)
