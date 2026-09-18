# Read-only test bridge. tests/** is excluded from production exports.
extends "res://scripts/main.gd"

func _process(delta: float) -> void:
	super._process(delta)
	if not OS.has_feature("web"): return
	var buttons: Array = []
	for entry in mobile_controls._dpad_centers:
		buttons.append({"x": entry.pos.x, "y": entry.pos.y, "dir": entry.dir})
	var enemy_data: Array = []
	for enemy in monsters:
		if is_instance_valid(enemy): enemy_data.append({"x": enemy.pos.x, "y": enemy.pos.y, "hp": enemy.hp})
	var rect := journey_card.continue_button.get_global_rect()
	var panel_rect := journey_card.panel.get_global_rect()
	var difficulty_center := maze_renderer.get_difficulty_card_rects(get_viewport_rect().size)[1].get_center()
	var state := {
		"pos": {"x": player.pos.x, "y": player.pos.y}, "hp": player.hp,
		"grid": maze.grid if maze else [], "buttons": buttons, "enemies": enemy_data,
		"viewport": {"width": get_viewport_rect().size.x, "height": get_viewport_rect().size.y},
		"card": {"open": _story_open(), "title": journey_card.title_label.text,
			"x": rect.get_center().x, "y": rect.get_center().y,
			"left": panel_rect.position.x, "top": panel_rect.position.y,
			"right": panel_rect.end.x, "bottom": panel_rect.end.y},
		"won": game_won, "over": game_over, "cooldown": attack_cooldown,
		"moves": move_count, "level": current_level_index,
		"difficulty": selected_difficulty,
		"normalButton": {"x": difficulty_center.x, "y": difficulty_center.y},
		"objective": first_journey.objective() if first_journey else "",
		"mural": first_journey.mural_found if first_journey else false,
		"rescued": first_journey.rescued if first_journey else false,
		"route": first_journey.route_taken if first_journey else "",
	}
	JavaScriptBridge.eval("window.firstJourneyProbe = " + JSON.stringify(state) + ";")
