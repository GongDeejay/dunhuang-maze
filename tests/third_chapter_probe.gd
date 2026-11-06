# Test-only entry point plus read-only telemetry; tests/** is excluded from production.
extends "res://scripts/main.gd"

func _ready() -> void:
	super._ready()
	game.selected_difficulty = "normal"
	DataLoader.set_difficulty("normal")
	_new_game(2)

func _process(delta: float) -> void:
	super._process(delta)
	if not OS.has_feature("web"): return
	var state := {"active": third_chapter != null, "level": current_level_index, "menu": game.is_difficulty_select()}
	if third_chapter:
		var t := third_chapter
		state.merge({"x": t.body.position.x, "z": t.body.position.z, "yaw": t.yaw,
			"mode": t.mode, "target": t.current_target, "hp": t.hp, "rescued": t.rescued,
			"relic": t.relic_found, "route": t.route, "enemyHp": t.enemy_hp, "enemyPhase": t.enemy_phase,
			"gold": t.golden_clue.found, "trail": t.golden_clue.trail.visible,
			"revealProgress": t.golden_clue.reveal_progress, "trailCount": t.golden_clue.trail.multimesh.visible_instance_count,
			"trailTotal": t.golden_clue.trail.multimesh.instance_count,
			"sceneryTriangles": t.world.scenery.triangle_count, "sceneryChunks": t.world.scenery.get_child_count(),
			"ambient": t.world.atmosphere.ambient_light_energy, "hintVisible": t.hud.hint.visible,
			"returnMarkers": t.world.homeward.return_markers.visible, "greeting": t.cave_greeting,
			"childMarker": t.world.child_marker.visible, "hintText": t.hud.hint.text, "cardText": t.hud.copy.text,
			"homeTriangles": t.world.homeward.triangle_count,
			"beaconVisible": t.camera.is_position_in_frustum(HomewardScenery.BEACON),
			"lightVisible": t.camera.is_position_in_frustum(GoldenClue.RELIEF_POSITION),
			"elapsed": t.elapsed, "enemyTimer": t.enemy_timer, "moveTouch": t.move_touch, "lookTouch": t.look_touch,
			"scale3d": get_viewport().scaling_3d_scale, "fps": Engine.get_frames_per_second(),
			"quality": _point(t.hud.quality), "qualityIndex": t.hud.quality_index, "msaa": get_viewport().msaa_3d,
			"width": t.hud.size.x, "height": t.hud.size.y, "heading": t.hud.heading.text,
			"stick": {"x": t.hud.stick_center.x, "y": t.hud.stick_center.y, "radius": t.hud.stick_radius},
			"hint": _point(t.hud.hint),
			"primary": _point(t.hud.primary), "secondary": _point(t.hud.secondary),
			"pause": _point(t.hud.pause_button), "interact": _point(t.hud.interact_button),
			"photo": t.hud.photo.visible, "floor": t.map.floor_cells.keys().map(func(c): return [c.x,c.y]),
			"save": SaveManager.load_progress().get("level_index", -1)})
	JavaScriptBridge.eval("window.thirdChapterProbe = " + JSON.stringify(state) + ";")

func _point(control: Control) -> Dictionary:
	var rect := control.get_global_rect()
	return {"x": rect.get_center().x, "y": rect.get_center().y,
		"left": rect.position.x, "top": rect.position.y, "right": rect.end.x, "bottom": rect.end.y}
