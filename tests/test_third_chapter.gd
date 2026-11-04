extends RefCounted
## Deterministic level contracts and production-controller integration.
static func run(suite: Node) -> void:
	print("\n[TEST] Third chapter 3D contracts")
	var map := ThirdMap.new()
	var before := _reachable(map, false)
	var after := _reachable(map, true)
	suite.assert_true(before.has(ThirdMap.CHILD), "child reachable before rescue")
	suite.assert_true(before.has(ThirdMap.RELIC), "optional relic reachable")
	suite.assert_true(not before.has(ThirdMap.CAMP), "camp gated until rescue")
	suite.assert_true(after.has(ThirdMap.CAMP), "rescue connects camp")
	suite.assert_true(map.floor_cells.size() < 160, "compact authored map budget")
	suite.assert_true(map.is_windy(ThirdMap.world(Vector2i(7, 8))), "short path exposes wind")
	suite.assert_true(not map.is_windy(ThirdMap.world(Vector2i(1, 5))), "long path sheltered")
	var trail := map.clue_path()
	suite.assert_eq(trail[0], ThirdMap.RELIC, "gold trail starts at the optional hand-drawn clue")
	suite.assert_eq(trail[-1], ThirdMap.CHILD, "gold trail reaches the child's cave")
	for i in trail.size():
		suite.assert_true(map.can_enter(trail[i], false) and not map.is_windy(ThirdMap.world(trail[i])), "gold footprints stay on existing sheltered walkable floor")
		if i > 0: suite.assert_eq(trail[i].distance_to(trail[i - 1]), 1.0, "gold trail cannot cross walls diagonally")
	suite.assert_true(GoldenClue.in_view(Vector3(22.8, 1.6, 22.5), Vector3.FORWARD), "broad left viewpoint accepts natural facing")
	suite.assert_true(not GoldenClue.in_view(Vector3(22.8, 1.6, 22.5), Vector3.BACK), "looking away does not reveal clue")
	suite.assert_true(not GoldenClue.in_view(Vector3(24, 1.6, 22.5), Vector3.FORWARD), "must change viewpoint, not just collect old item")
	var main = load("res://scripts/main.gd").new()
	suite.add_child(main)
	main._new_game(1)
	main.game_won = true
	main._handle_regenerate()
	suite.assert_eq(main.current_level_index, 2, "second chapter completion advances to third")
	await suite.get_tree().physics_frame
	var chapter: ThirdChapter = main.third_chapter
	suite.assert_true(chapter != null and chapter.camera.current, "third chapter owns real 3D camera")
	var scenery := chapter.world.scenery
	suite.assert_true(scenery.wall_count > 20 and scenery.triangle_count < 6000, "valley uses bounded low-poly sandstone geometry")
	suite.assert_true(scenery.get_child_count() <= 20, "sandstone is batched into spatial chunks")
	suite.assert_eq(scenery.find_children("*", "CollisionObject3D", true, false).size(), 0, "visual polish adds no new colliders")
	# Reconstruct the original RNG stream: cosmetic geometry must not perturb collision heights.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7303
	for i in 28:
		rng.randf_range(14, 24)
		rng.randf_range(6, 13)
		rng.randf_range(12, 22)
	var colliders := chapter.world.find_children("*", "StaticBody3D", true, false)
	var boundary := 0
	for cell: Vector2i in map.floor_cells:
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if map.floor_cells.has(cell + direction): continue
			var height := rng.randf_range(0.8, 1.5) if cell.y >= 11 else rng.randf_range(3.2, 5.0)
			var pos := ThirdMap.world(cell) + Vector3(direction.x, 0, direction.y) * 2.0 + Vector3.UP * height * 0.5
			boundary += 1
			suite.assert_true(colliders[boundary].position.is_equal_approx(pos), "original boundary collider position and height preserved")
	suite.assert_eq(colliders.size(), boundary + 2, "only original ground, boundary and rescue-gate collisions exist")
	chapter.world.update_atmosphere(Vector3(8, 0, 24), 1)
	suite.assert_true(chapter.world.atmosphere.ambient_light_energy < 0.35, "sheltered bend has a cooler low-light beat")
	chapter.world.update_atmosphere(ThirdMap.world(ThirdMap.CAMP), 1)
	suite.assert_true(is_equal_approx(chapter.world.atmosphere.ambient_light_energy, 0.65), "outside slice restores original lighting")
	chapter.world.update_atmosphere(chapter.body.position, 1)
	suite.assert_eq(main.monsters.size(), 0, "no legacy invisible 2D monsters")
	suite.assert_true(not main.mobile_controls.visible, "old touch overlay disabled")
	suite.assert_eq(SaveManager.load_progress().get("level_index"), 2, "third entry checkpoint saved")
	var initial := chapter.body.position
	chapter.held[KEY_W] = true
	chapter._physics_process(1)
	suite.assert_eq(chapter.body.position, initial, "welcome freezes motion")
	chapter._on_action("primary")
	chapter.message_timer = 0
	chapter._refresh_hud()
	suite.assert_true(not chapter.hud.hint.visible and chapter.hud.interact_button.visible, "idle tutorial text clears without hiding controls")
	chapter.message_timer = 8
	chapter.move_touch = 0
	chapter.look_touch = 1
	chapter.stick = Vector2.UP
	var lift := InputEventScreenTouch.new()
	lift.index = 1
	lift.pressed = false
	chapter._input(lift)
	suite.assert_true(chapter.move_touch == 0 and chapter.look_touch == -1 and chapter.stick == Vector2.UP, "lifting look finger preserves movement owner")
	chapter._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	suite.assert_true(chapter.mode == "paused" and chapter.move_touch == -1 and chapter.stick == Vector2.ZERO, "focus loss pauses and clears touch")
	chapter._on_action("primary")
	chapter.held[KEY_W] = true
	chapter.held[KEY_D] = true
	suite.assert_true(chapter.movement().length() <= 1.001, "diagonal speed normalized")
	chapter._on_action("pause")
	suite.assert_true(chapter.held.is_empty() and chapter.stick == Vector2.ZERO, "pause clears held input")
	var clock := chapter.elapsed
	chapter._physics_process(1)
	suite.assert_eq(chapter.elapsed, clock, "pause freezes simulation time")
	chapter._on_action("primary")
	chapter.look(Vector2(0, 10000))
	suite.assert_true(chapter.pitch >= -0.85, "vertical view clamp avoids flipped camera")
	chapter.look(Vector2(0, -10000))
	suite.assert_true(chapter.pitch <= 0.8, "upper view clamp")
	chapter.interact()
	suite.assert_true(not chapter.rescued, "cannot rescue remotely")
	chapter.pitch = 0
	chapter.camera.rotation.x = 0
	chapter.body.position = Vector3(22.8, 0.1, 21.3)
	await suite.get_tree().physics_frame
	suite.assert_true(chapter.target() != "light", "gold discovery is not available before reading nearby note")
	chapter.relic_found = true
	var before_light_hp := chapter.hp
	suite.assert_eq(chapter.target(), "light", "viewpoint plus visible clue offers existing interaction")
	chapter.interact()
	suite.assert_true(chapter.golden_clue.found and chapter.golden_clue.trail.visible, "gold discovery visibly reveals physical footprint trail")
	suite.assert_eq(chapter.hp, before_light_hp, "gold clue never stacks another healing reward")
	suite.assert_true(not chapter.golden_clue.reveal(), "gold reveal is idempotent")
	suite.assert_true(chapter.golden_clue.trail.multimesh.visible_instance_count < chapter.golden_clue.trail.multimesh.instance_count, "footprints appear progressively rather than flashing the whole route")
	chapter._on_action("pause")
	var progress := chapter.golden_clue.reveal_progress
	chapter._physics_process(1.0)
	suite.assert_eq(chapter.golden_clue.reveal_progress, progress, "pause freezes clue animation")
	chapter._on_action("primary")
	chapter.golden_clue.advance(1.0)
	suite.assert_eq(chapter.golden_clue.trail.multimesh.visible_instance_count, chapter.golden_clue.trail.multimesh.instance_count, "all footprints appear within a second")
	suite.assert_true(not chapter.golden_clue.reveal() and chapter.golden_clue.reveal_progress == 1.0, "repeat interaction never restarts reveal")
	suite.assert_true(not chapter.rescued and chapter.world.gate.collision_layer != 0, "gold clue cannot bypass family rescue gate")
	# Real physics frames make ray queries reflect the new position.
	chapter.pitch = 0
	chapter.camera.rotation.x = 0
	chapter.body.position = ThirdMap.world(ThirdMap.CHILD) + Vector3(0, 0.1, 2.5)
	await suite.get_tree().physics_frame
	suite.assert_eq(chapter.target(), "child", "nearby visible child interactable")
	chapter.interact()
	suite.assert_true(chapter.rescued, "rescue flag set")
	suite.assert_true(not chapter.golden_clue.trail.visible, "rescue switches guidance to existing return tower")
	chapter.golden_clue.advance(1.0)
	suite.assert_true(not chapter.golden_clue.trail.visible, "animation cannot re-show obsolete outbound guidance")
	suite.assert_eq(chapter.world.gate.collision_layer, 0, "shortcut collision removed")
	chapter._on_action("primary")
	chapter._hurt(999)
	suite.assert_eq(chapter.mode, "recover", "failure offers local recovery")
	chapter._on_action("primary")
	suite.assert_eq(chapter.hp, chapter.max_hp, "checkpoint restores health")
	suite.assert_true(chapter.rescued, "recovery preserves rescue progress")
	chapter.body.position = ThirdMap.world(ThirdMap.CAMP)
	chapter._physics_process(0.016)
	suite.assert_eq(chapter.mode, "ending1", "camp starts ending")
	suite.assert_true(chapter.body.position.z < ThirdMap.world(ThirdMap.CAMP).z and is_equal_approx(chapter.yaw, PI), "ending films family from courtyard, not behind tower")
	suite.assert_true(not chapter.hud.interact_button.visible, "ending hides gameplay controls")
	suite.assert_eq(chapter.camera.keep_aspect, Camera3D.KEEP_WIDTH, "portrait ending keeps the whole family in frame")
	suite.assert_true(not SaveManager.has_save(), "completed journey does not resume stale chapter")
	chapter._on_action("primary")
	suite.assert_eq(chapter.mode, "complete", "skip lands on family photo")
	suite.assert_true(chapter.hud.photo.visible, "ending displays original family image")
	chapter._on_action("secondary")
	suite.assert_eq(chapter.mode, "replay_confirm", "replay requires confirmation")
	chapter._on_action("secondary")
	suite.assert_eq(chapter.mode, "complete", "cancel replay keeps ending")
	chapter._on_action("primary")
	suite.assert_true(main.third_chapter == null and main.game.is_difficulty_select(), "menu disposes 3D chapter")
	main._new_game(0)
	suite.assert_true(main.first_journey != null, "first chapter still starts after 3D")
	suite.assert_true(main._story_open(), "first chapter UI restored")
	main.free()
	await suite.get_tree().process_frame
	SaveManager.clear_save()

static func _reachable(map: ThirdMap, rescued: bool) -> Dictionary:
	var seen := {ThirdMap.START: true}
	var queue: Array[Vector2i] = [ThirdMap.START]
	while not queue.is_empty():
		var cell := queue.pop_front() as Vector2i
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + direction
			if map.can_enter(next, rescued) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen
