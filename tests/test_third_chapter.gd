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
	var main = load("res://scripts/main.gd").new()
	suite.add_child(main)
	main._new_game(2)
	await suite.get_tree().physics_frame
	var chapter: ThirdChapter = main.third_chapter
	suite.assert_true(chapter != null and chapter.camera.current, "third chapter owns real 3D camera")
	suite.assert_eq(main.monsters.size(), 0, "no legacy invisible 2D monsters")
	suite.assert_true(not main.mobile_controls.visible, "old touch overlay disabled")
	suite.assert_eq(SaveManager.load_progress().get("level_index"), 2, "third entry checkpoint saved")
	var initial := chapter.body.position
	chapter.held[KEY_W] = true
	chapter._physics_process(1)
	suite.assert_eq(chapter.body.position, initial, "welcome freezes motion")
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
	# Real physics frames make ray queries reflect the new position.
	chapter.pitch = 0
	chapter.camera.rotation.x = 0
	chapter.body.position = ThirdMap.world(ThirdMap.CHILD) + Vector3(0, 0.1, 2.5)
	await suite.get_tree().physics_frame
	suite.assert_eq(chapter.target(), "child", "nearby visible child interactable")
	chapter.interact()
	suite.assert_true(chapter.rescued, "rescue flag set")
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
