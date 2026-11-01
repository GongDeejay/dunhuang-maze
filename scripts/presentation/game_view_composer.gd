class_name GameViewComposer
extends RefCounted
## 统一游戏画面绘制：布局 → HUD + Follow/Fit 地图

var maze_renderer: MazeRenderer
var mobile_renderer: MobileRenderer
var ui_panel: UIPanel
var hud_top_bar: HudTopBar
var mogao_view: Dictionary = {}

func _init(renderer: MazeRenderer, mobile: MobileRenderer, panel: UIPanel) -> void:
	maze_renderer = renderer
	mobile_renderer = mobile
	ui_panel = panel
	hud_top_bar = HudTopBar.new()


func draw(canvas: CanvasItem, layout: LayoutProfile, ctx: Dictionary) -> void:
	mogao_view = {}
	ui_panel.journey_objective = ctx.get("journey_objective", "")
	hud_top_bar.journey_objective = ctx.get("journey_objective", "")
	var vp: Vector2 = layout.viewport_size
	canvas.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.12, 0.10, 0.08))

	match layout.mode:
		LayoutProfile.Mode.DESKTOP_SIDE:
			_draw_desktop(canvas, layout, ctx)
		_:
			_draw_dynamic(canvas, layout, ctx)
	if ctx.get("mogao_focus", false):
		_draw_mogao_encounter(canvas, layout, ctx)

	if ctx.get("paused", false):
		ui_panel.draw_overlay(canvas, vp, "旅途暂停", "即时战斗已冻结", "按 P / Esc / 回车或暂停按钮继续", Color(0.9, 0.75, 0.3))
	elif ctx.get("game_over", false):
		ui_panel.draw_overlay(canvas, vp, "你倒下了...", "走了 %d 步" % ctx.get("move_count", 0), "按 R 重新尝试", Color(0.9, 0.3, 0.2))
	elif ctx.get("game_won", false):
		if ctx.get("first_journey", false): return # Interactive JourneyCard handles this chapter's ending.
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
		canvas, layout.maze_rect, layout.hud_rect, layout.ui_scale,
		ctx.maze, ctx.maze_width, ctx.maze_height,
		ctx.player, ctx.monsters, ctx.items, ctx.exit_pos,
		ctx.exit_visible, ctx.game_won, ctx.visited, ctx.is_revealed,
		ui_panel, ctx.levels_data, ctx.current_level_index,
		ctx.difficulty_name, ctx.move_count, ctx.terrain_name,
		ctx.buff_display, ctx.combat_log, ctx.inventory, ctx.key_tracker,
		ctx.selected_slot, ctx.guide_dir, ctx.low_hp_pulse,
	)

func _draw_mogao_encounter(canvas: CanvasItem, layout: LayoutProfile, ctx: Dictionary) -> void:
	var area := layout.maze_rect
	var compact := area.size.y < 360
	var header := 32.0 if compact else 54.0
	var footer := 80.0 if layout.is_portrait() or layout.is_side_hud() else 25.0
	canvas.draw_rect(area, Color("211a13"))
	var map_rect := Rect2(area.position + Vector2(0, header), area.size - Vector2(0, header + footer))
	var focus := Rect2i(2, 2, 5, 2) if compact else Rect2i(2, 0, 5, 5)
	if compact: focus.position.y = mini(ctx.player.pos.y, 2)
	var cell := minf(map_rect.size.x / focus.size.x, map_rect.size.y / focus.size.y)
	var map_origin := map_rect.position + (map_rect.size - Vector2(focus.size) * cell) / 2
	var gate_rect := Rect2(map_origin + Vector2(MogaoJourney.GATE - focus.position) * cell, Vector2.ONE * cell)
	var scarf_rect := Rect2(map_origin + Vector2(MogaoJourney.SCARF - focus.position) * cell, Vector2.ONE * cell)
	mogao_view = {"cellSize": cell, "gateLeft": gate_rect.position.x, "gateTop": gate_rect.position.y, "gateRight": gate_rect.end.x, "gateBottom": gate_rect.end.y, "scarfRight": scarf_rect.end.x, "scarfBottom": scarf_rect.end.y, "right": area.end.x, "bottom": area.end.y}
	# The local cut-in renders actual map cells and the actual player, not an illustration.
	# Keep the entire gate/scarf pair visible even in a portrait or short landscape view.
	mobile_renderer.draw_follow_in_rect(canvas, map_rect, ctx.maze, ctx.maze_width, ctx.maze_height,
		ctx.player, ctx.monsters, ctx.items, ctx.exit_pos, ctx.game_won, ctx.visited, ctx.is_revealed,
		ctx.guide_dir, layout.ui_scale, focus)
	var caption := "门后是哥哥的围巾"
	if ctx.get("gate_revealing", false): caption = "栈道通了！木门正在打开"
	elif ctx.get("gate_guiding", false): caption = "近路已开 · 沿蓝色箭头穿门"
	var fs := int(clampf(area.size.x / 23.0, 16, 22))
	canvas.draw_string(ThemeDB.fallback_font, area.position + Vector2(6, fs + 5), caption, HORIZONTAL_ALIGNMENT_CENTER, int(area.size.x - 12), fs, Color("f4d68c"))
	if not ctx.maze.landmarks[MogaoJourney.GATE].get("open", false):
		canvas.draw_string(ThemeDB.fallback_font, Vector2(area.position.x + 6, area.end.y - 7), "↓ 不解机关，也能绕行", HORIZONTAL_ALIGNMENT_CENTER, int(area.size.x - 12), 16, Color("d0bd9c"))
	if layout.is_portrait() and layout.hud_rect.size.y <= 112 and ctx.inventory.get_count() > 0:
		# In a short, large-text viewport, keep all five selectable inventory slots
		# without allowing the regular 176px header to squeeze away the actual door.
		var hud := layout.hud_rect
		canvas.draw_rect(hud, Color("211a13"))
		canvas.draw_string(ThemeDB.fallback_font, hud.position + Vector2(8, 22), "莫高窟 · 生命 %d/%d · 家人 %s" % [ctx.player.hp, ctx.player.max_hp, ctx.key_tracker.get_progress()], HORIZONTAL_ALIGNMENT_LEFT, int(hud.size.x - 16), 16, Color("f4d68c"))
		canvas.draw_string(ThemeDB.fallback_font, hud.position + Vector2(8, 47), ctx.journey_objective, HORIZONTAL_ALIGNMENT_LEFT, int(hud.size.x - 16), 15, Color("d0bd9c"))
		hud_top_bar.inventory_chip_rects.clear()
		hud_top_bar._draw_inventory_chips(canvas, hud, ctx.inventory, ctx.selected_slot, true, 15, true, 60)


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
	var density := clampf(rect.size.x / 390.0, 1.0, 2.0)
	var fs := int(clampf(rect.size.y * 0.30, 16.0 * density, 20.0 * density))
	canvas.draw_multiline_string(ThemeDB.fallback_font, rect.position + Vector2(12.0 * density, fs + 6.0 * density),
		msg, HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x - 24.0 * density), fs, 2, Color(0.82, 0.77, 0.68))


func get_inventory_slot_at(global_pos: Vector2, layout: LayoutProfile) -> int:
	if layout.is_side_hud():
		return ui_panel.get_inventory_slot_at(global_pos)
	return hud_top_bar.get_inventory_slot_at(global_pos)
