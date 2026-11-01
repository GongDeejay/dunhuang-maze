# Test/preview-only entry; exported from an isolated copy, never in the production pack.
extends "res://scripts/main.gd"

func _do_start_playing(_force_new: bool) -> void:
	DataLoader.set_difficulty(selected_difficulty)
	game.start_game()
	player.level = 1
	player.xp = 0
	_new_game(1)

func _rect(control: Control) -> Dictionary:
	var r := control.get_global_rect()
	return {"x": r.get_center().x, "y": r.get_center().y, "left": r.position.x, "top": r.position.y, "right": r.end.x, "bottom": r.end.y, "visible": control.is_visible_in_tree()}

func _process(delta: float) -> void:
	super._process(delta)
	if not OS.has_feature("web"): return
	var dpad: Array = []
	for entry in mobile_controls._dpad_centers:
		dpad.append({"x": entry.pos.x, "y": entry.pos.y, "dir": entry.dir})
	var enemies: Array = []
	for m in monsters:
		if is_instance_valid(m): enemies.append({"x": m.pos.x, "y": m.pos.y, "hp": m.hp, "clock": m.move_timer})
	var buttons := {}
	for key in ["primary", "same", "different", "leave"]:
		buttons[key] = _rect(pattern_panel.get(key))
	var p: PatternPuzzle = mogao_journey.puzzle if mogao_journey else null
	var normal_center := maze_renderer.get_difficulty_card_rects(get_viewport_rect().size)[1].get_center()
	var state := {
		"pos": {"x": player.pos.x, "y": player.pos.y}, "hp": player.hp,
		"grid": maze.grid if maze else [], "dpad": dpad, "enemies": enemies,
		"viewport": {"width": get_viewport_rect().size.x, "height": get_viewport_rect().size.y},
		"card": _rect(journey_card.continue_button), "cardOpen": _story_open(),
		"cardTitle": journey_card.title_label.text,
		"panel": _rect(pattern_panel.panel), "panelOpen": _pattern_open(), "scroll": _rect(pattern_panel.scroll),
		"prompt": _rect(pattern_prompt), "buttons": buttons,
		"phase": p.phase if p else "", "latches": p.latches if p else 0,
		"board": p.board if p else [], "probe": p.probe if p else -1, "target": p.target if p else -1,
		"gate": mogao_journey.gate_open if mogao_journey else false,
		"rescued": mogao_journey.rescued if mogao_journey else false,
		"won": game_won, "over": game_over, "cooldown": attack_cooldown,
		"moves": move_count, "level": current_level_index, "inventory": inventory.items,
		"buff": player.buff_timer, "paused": game.is_paused(),
		"normal": {"x": normal_center.x, "y": normal_center.y}, "difficulty": selected_difficulty,
		"third": third_chapter != null,
		"revealing": _gate_revealing(), "gatePresented": mogao_journey.gate_presented if mogao_journey else false,
		"gateVisual": maze.landmarks.get(MogaoJourney.GATE, {}).get("visual_open", 0.0) if maze else 0.0,
		"gateGuiding": mogao_journey.guiding_to_gate() if mogao_journey else false,
		"crossedGate": mogao_journey.crossed_gate if mogao_journey else false,
		"scarfFound": mogao_journey.scarf_found if mogao_journey else false,
		"guideDir": _get_guide_direction() if maze else -1,
		"encounterView": game_view_composer.mogao_view,
	}
	JavaScriptBridge.eval("window.mogaoProbe = " + JSON.stringify(state) + ";")
