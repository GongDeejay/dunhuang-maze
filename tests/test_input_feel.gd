extends RefCounted

const HeldMoveScript = preload("res://scripts/handlers/held_move.gd")
const MainScript = preload("res://scripts/main.gd")


static func run(t: Node) -> void:
	print("\n[TEST] Keyboard hold, attack buffer, and cave step buffer")
	t.assert_eq(HeldMoveScript.REPEAT_SECONDS, 0.14, "held movement interval is 0.14 seconds")
	_test_hold_rhythm(t)
	_test_long_hold_keeps_rhythm(t)
	_test_duplicate_keydown_keeps_rhythm(t)
	_test_echo_and_latest_direction(t)
	_test_modal_does_not_catch_up(t)
	_test_attack_buffer(t)
	_test_cave_buffer(t)
	_test_cave_queue(t)
	_test_event_flush_keeps_every_press(t)
	_test_maze_rapid_taps(t)
	_test_hazard_hold_stop(t)
	_test_wall_hold_bumps_once(t)
	_test_one_second_hold(t)
	_test_bump_frames(t)
	_test_wall_cooldown_does_not_stall_hold(t)
	_test_cave_one_second_hold(t)


static func _test_hold_rhythm(t: Node) -> void:
	var controller = _maze(t)
	_press(controller, KEY_D, true)
	t.assert_eq(controller.player.pos, Vector2i(2, 2), "press steps immediately")
	controller._process(0.10)
	t.assert_eq(controller.player.pos, Vector2i(2, 2), "hold waits the full interval")
	_key(controller, KEY_D, true, true)
	t.assert_eq(controller.player.pos, Vector2i(2, 2), "echo is not an extra step")
	controller._process(0.04)
	t.assert_eq(controller.player.pos, Vector2i(3, 2), "echo does not reset the 0.14 timer")
	controller._process(HeldMoveScript.REPEAT_SECONDS)
	t.assert_eq(controller.player.pos, Vector2i(4, 2), "held key keeps stepping on the interval")
	controller._process(0.13)
	t.assert_eq(controller.player.pos, Vector2i(4, 2), "short hold gap does not step")
	var touch_pos: Vector2i = controller.player.pos
	controller._on_mobile_move(MazeGenerator.E)
	controller._on_mobile_move(MazeGenerator.E)
	t.assert_eq(controller.player.pos, touch_pos + Vector2i(2, 0), "touch still steps twice with no time debounce")
	_release(controller)
	controller.free()


static func _test_long_hold_keeps_rhythm(t: Node) -> void:
	var controller = _maze(t)
	controller.player.pos = Vector2i(0, 2)
	_press(controller, KEY_D, true)
	var elapsed := 0.0
	while elapsed < 0.9 - 0.0001:
		_key(controller, KEY_D, true, true)
		controller._process(0.05)
		elapsed += 0.05
	# Press plus one step each 0.14s. Echoes must not reset that clock.
	var repeats := int(0.9 / HeldMoveScript.REPEAT_SECONDS)
	t.assert_eq(repeats, 6, "0.9 seconds contains six repeat intervals")
	t.assert_eq(controller.player.pos, Vector2i(1 + repeats, 2), "small frames and echoes still match 0.14 seconds")
	_release(controller)
	controller.free()

	controller = _maze(t)
	controller.player.pos = Vector2i(0, 2)
	_press(controller, KEY_D, true)
	controller._process(0.9)
	t.assert_eq(controller.player.pos, Vector2i(1 + repeats, 2), "one 0.9 second frame matches the same rhythm")
	var stopped: Vector2i = controller.player.pos
	_release(controller)
	controller._process(0.9)
	t.assert_eq(controller.player.pos, stopped, "a key release stops further hold steps")
	controller.free()


static func _test_duplicate_keydown_keeps_rhythm(t: Node) -> void:
	# A browser can emit another keydown for a key that is still held, with echo left false.
	var controller = _maze(t)
	controller.player.pos = Vector2i(0, 2)
	_press(controller, KEY_D, true)
	var elapsed := 0.0
	var resent := false
	while elapsed < 0.9 - 0.0001:
		if not resent and elapsed >= 0.10:
			var pos: Vector2i = controller.player.pos
			_key(controller, KEY_D, true, false)
			t.assert_eq(controller.player.pos, pos, "a repeated keydown without echo does not take an extra step")
			resent = true
		controller._process(0.05)
		elapsed += 0.05
	t.assert_true(resent, "the repeated keydown was inserted during the hold")
	var repeats := int(0.9 / HeldMoveScript.REPEAT_SECONDS)
	t.assert_eq(repeats, 6, "0.9 seconds still contains six repeat intervals")
	t.assert_eq(controller.player.pos, Vector2i(1 + repeats, 2), "first level stays on the 0.14 second rhythm after a non-echo resend")
	_release(controller)
	# Releasing and pressing again is a real new press, including into wind sand.
	controller.player.pos = Vector2i(0, 2)
	_press(controller, KEY_D, true)
	t.assert_eq(controller.player.pos, Vector2i(1, 2), "a press after release still steps")
	controller.free()

	SaveManager.clear_save()
	var host = MainScript.new()
	t.add_child(host)
	host.game.start_game()
	host._new_game(1)
	var chapter: MogaoChapter = host.cave_chapter
	var quiet := _cave_hold_moves(chapter, false)
	var noisy := _cave_hold_moves(chapter, true)
	t.assert_eq(noisy, quiet, "cave hold keeps the same number of steps when the browser resends the key")
	t.assert_true(noisy >= 4, "cave hold still finishes several steps in 0.9 seconds")
	host.free()
	SaveManager.clear_save()


static func _cave_hold_moves(chapter: MogaoChapter, resend: bool) -> int:
	_reset_cave(chapter, Vector2i(0, 6))
	for x in 12:
		chapter.model.land[Vector2i(x, 6)] = true
	chapter.model.player = Vector2i(0, 6)
	chapter.model.destination = chapter.model.player
	chapter.model.moves = 0
	_cave(chapter, KEY_RIGHT, true, false)
	var elapsed := 0.0
	var resent := false
	while elapsed < 0.9 - 0.0001:
		if resend and not resent and elapsed >= 0.10:
			var moves_now: int = chapter.model.moves
			var pos: Vector2i = chapter.model.player
			_cave(chapter, KEY_RIGHT, true, false)
			if moves_now != chapter.model.moves or pos != chapter.model.player:
				return -1
			resent = true
		chapter._process(0.05)
		elapsed += 0.05
	if resend and not resent:
		return -1
	return chapter.model.moves


static func _test_echo_and_latest_direction(t: Node) -> void:
	var controller = _maze(t)
	_press(controller, KEY_W, true)
	t.assert_eq(controller.player.pos, Vector2i(1, 1), "north press steps once")
	for echo in range(4):
		_key(controller, KEY_W, true, true)
		_key(controller, KEY_D, true, true)
	t.assert_eq(controller.player.pos, Vector2i(1, 1), "echoes never add a step")
	_press(controller, KEY_D, true)
	t.assert_eq(controller.player.pos, Vector2i(2, 1), "a newer press steps immediately")
	controller._process(HeldMoveScript.REPEAT_SECONDS)
	t.assert_eq(controller.player.pos, Vector2i(3, 1), "repeat follows the last pressed direction")
	_key(controller, KEY_D, false, false)
	controller._process(HeldMoveScript.REPEAT_SECONDS)
	t.assert_eq(controller.player.pos, Vector2i(3, 0), "releasing the latest key returns to the earlier hold")
	_release(controller)
	controller.game_over = true
	var stopped: Vector2i = controller.player.pos
	_press(controller, KEY_S, true)
	controller._process(1.0)
	t.assert_eq(controller.player.pos, stopped, "defeat blocks held movement")
	controller.free()


static func _test_modal_does_not_catch_up(t: Node) -> void:
	var controller = _maze(t)
	_press(controller, KEY_D, true)
	t.assert_eq(controller.player.pos, Vector2i(2, 2), "story setup starts from a real step")
	controller._show_story({"title": "停一下", "body": "读完再走。", "button": "继续"})
	_key(controller, KEY_D, true, true)
	_press(controller, KEY_W, true)
	controller._process(1.0)
	t.assert_eq(controller.player.pos, Vector2i(2, 2), "story card blocks held movement")
	controller.journey_card.close()
	controller._process(1.0)
	t.assert_eq(controller.player.pos, Vector2i(2, 2), "closing the story does not catch up held steps")
	_release(controller)
	_press(controller, KEY_D, true)
	t.assert_eq(controller.player.pos, Vector2i(3, 2), "a new press works after the story is closed")
	var points: Array[Vector2i] = []
	controller.route_notebook.open(points, false)
	controller._process(0.6)
	t.assert_eq(controller.player.pos, Vector2i(3, 2), "roadbook blocks held movement")
	controller.route_notebook.close()
	controller._process(0.6)
	t.assert_eq(controller.player.pos, Vector2i(3, 2), "closing the roadbook does not catch up")
	_release(controller)
	_press(controller, KEY_D, true)
	var paused: Vector2i = controller.player.pos
	controller.game.toggle_pause()
	controller._process(0.6)
	t.assert_eq(controller.player.pos, paused, "pause blocks held movement")
	controller.game.toggle_pause()
	controller._process(0.6)
	t.assert_eq(controller.player.pos, paused, "unpausing does not catch up a held key")
	_release(controller)
	controller.free()


static func _test_attack_buffer(t: Node) -> void:
	var controller = _maze(t)
	var monster := MonsterEntity.new()
	monster.hp = 500
	monster.max_hp = 500
	monster.atk = 1
	monster.pos = Vector2i(1, 0)
	monster.move_interval = 100.0
	monster.move_timer = 0.0
	controller.add_child(monster)
	controller.monsters.append(monster)
	controller.player.pos = Vector2i.ZERO
	controller.player.crit_chance = 0.0
	controller.attack_cooldown = 0.0
	_press(controller, KEY_D, true)
	_key(controller, KEY_D, false, false)
	t.assert_true(monster.hp < 500, "first bump attacks")
	t.assert_eq(controller.player.pos, Vector2i.ZERO, "attack does not enter the monster cell")
	var once: int = monster.hp
	for repeat in range(3):
		_press(controller, KEY_D, true)
		_key(controller, KEY_D, false, false)
	t.assert_eq(monster.hp, once, "presses during cooldown do not attack again")
	controller._process(0.34)
	t.assert_eq(monster.hp, once, "cooldown still blocks before 0.35 seconds")
	controller._process(0.02)
	t.assert_true(monster.hp < once, "the one buffered direction fires when cooldown ends")
	var fired: int = monster.hp
	controller._process(0.34)
	t.assert_eq(monster.hp, fired, "a buffered attack does not repeat without another press")

	monster.hp = 500
	controller.attack_cooldown = 0.0
	controller.attack_buffer.clear()
	controller.input_handler.held.clear()
	_press(controller, KEY_D, true)
	var previous: int = monster.hp
	var hits: Array[float] = [0.0]
	var clock := 0.0
	for step in range(16):
		controller._process(0.05)
		clock += 0.05
		if monster.hp < previous:
			hits.append(clock)
			previous = monster.hp
	t.assert_true(hits.size() >= 2 and hits.size() <= 3, "holding into a monster attacks, but only on the cooldown")
	for index in range(1, hits.size()):
		t.assert_true(float(hits[index]) - float(hits[index - 1]) >= 0.34, "held attacks stay at least 0.35 seconds apart")
	_release(controller)
	monster.free()
	controller.free()


static func _test_cave_buffer(t: Node) -> void:
	SaveManager.clear_save()
	var controller = MainScript.new()
	t.add_child(controller)
	controller.game.start_game()
	controller._new_game(1)
	var chapter: MogaoChapter = controller.cave_chapter
	_reset_cave(chapter, Vector2i(2, 6))
	chapter.move(Vector2i.LEFT)
	chapter.move(Vector2i.RIGHT)
	chapter._process(CaveModel.STEP_SECONDS)
	t.assert_eq(chapter.model.player, Vector2i(1, 6), "touch move still ignores keys pressed during the step")
	t.assert_eq(chapter.model.busy, "", "touch move does not keep a buffered step")
	t.assert_eq(chapter.model.moves, 1, "touch move completes one step")

	_reset_cave(chapter, Vector2i(3, 6))
	_cave(chapter, KEY_LEFT, true, false)
	t.assert_eq(chapter.model.busy, "step", "cave press starts one step immediately")
	chapter._process(0.14)
	t.assert_eq(chapter.model.moves, 1, "a held cave step keeps the 0.14 second rhythm")
	t.assert_eq(chapter.model.player, Vector2i(2, 6), "held cave key finishes the first step")
	t.assert_eq(chapter.model.busy, "step", "held cave key starts the next step")
	t.assert_eq(chapter.model.destination, Vector2i(1, 6), "the queued cave step continues in the held direction")
	for echo in range(3):
		_cave(chapter, KEY_LEFT, true, true)
	chapter._process(CaveModel.STEP_SECONDS)
	t.assert_eq(chapter.model.moves, 2, "echoes do not add cave steps")
	t.assert_eq(chapter.model.player, Vector2i(1, 6), "held cave movement stops at the wall after the buffered step")
	_cave(chapter, KEY_LEFT, false, false)

	_reset_cave(chapter, Vector2i(2, 6))
	_cave(chapter, KEY_LEFT, true, false)
	_cave(chapter, KEY_LEFT, false, false)
	_cave(chapter, KEY_UP, true, false)
	_cave(chapter, KEY_UP, false, false)
	_cave(chapter, KEY_RIGHT, true, false)
	_cave(chapter, KEY_RIGHT, false, false)
	chapter._process(CaveModel.STEP_SECONDS)
	t.assert_eq(chapter.model.moves, 1, "the step already moving finishes before the queue")
	t.assert_eq(chapter.model.destination, Vector2i(1, 5), "a released press stays queued instead of being replaced")
	chapter._process(CaveModel.STEP_SECONDS)
	chapter._process(CaveModel.STEP_SECONDS)
	t.assert_eq(chapter.model.player, Vector2i(2, 5), "three released presses are three steps")
	t.assert_eq(chapter.model.moves, 3, "the queue walks every released press")
	t.assert_eq(chapter.model.busy, "", "the queue stops when those presses are done")

	_reset_cave(chapter, Vector2i(2, 6))
	_cave(chapter, KEY_LEFT, true, false)
	_cave(chapter, KEY_LEFT, false, false)
	_cave(chapter, KEY_RIGHT, true, false)
	_cave(chapter, KEY_RIGHT, false, false)
	chapter.show_note()
	chapter._process(1.0)
	chapter.close_card()
	chapter._process(CaveModel.STEP_SECONDS)
	t.assert_eq(chapter.model.player, Vector2i(1, 6), "a cave popup discards the buffered step")
	t.assert_eq(chapter.model.moves, 1, "closing the cave popup does not replay the buffer")
	t.assert_eq(chapter.model.busy, "", "cave movement stays idle after a discarded buffer")
	controller.free()
	SaveManager.clear_save()


static func _test_wall_hold_bumps_once(t: Node) -> void:
	var controller = _maze(t)
	controller.player.pos = Vector2i(9, 4)
	_press(controller, KEY_D, true)
	t.assert_eq(controller.wall_bumps, 1, "the first press into a wall bumps once")
	controller._process(0.3)
	t.assert_eq(controller.wall_bumps, 1, "the 0.25 second cooldown does not bump again")
	controller._process(1.0)
	t.assert_eq(controller.wall_bumps, 1, "holding the same wall counts one bump")
	_release(controller)
	_press(controller, KEY_D, true)
	t.assert_eq(controller.wall_bumps, 2, "releasing and pressing the wall bumps again")
	_press(controller, KEY_S, true)
	t.assert_eq(controller.wall_bumps, 3, "changing direction bumps the new wall")
	_release(controller)
	controller.free()


static func _test_cave_queue(t: Node) -> void:
	var chapter := MogaoChapter.new()
	t.add_child(chapter)
	chapter.model.load_room(0)
	# Two steps west, at 125ms, 80ms, and 15ms. None of them may be dropped.
	for gap in [0.125, 0.08, 0.015]:
		_reset_cave(chapter, Vector2i(3, 6))
		for _step in 2:
			_cave(chapter, KEY_LEFT, true, false)
			_cave(chapter, KEY_LEFT, false, false)
			chapter._process(gap)
		for _drain in 8:
			if chapter.model.busy.is_empty() and not chapter.move_buffer.pending():
				break
			chapter._process(0.05)
		t.assert_eq(chapter.model.moves, 2, "two same-direction taps both count at %dms" % int(gap * 1000))
		t.assert_eq(chapter.model.player, Vector2i(1, 6), "two west taps land on the far stone at %dms" % int(gap * 1000))
	# Five lefts from the right stone: two walk, the third hits the wall and drops the rest.
	_reset_cave(chapter, Vector2i(3, 6))
	for _step in 5:
		_cave(chapter, KEY_LEFT, true, false)
		_cave(chapter, KEY_LEFT, false, false)
		chapter._process(0.02)
	for _drain in 12:
		chapter._process(CaveModel.STEP_SECONDS)
	t.assert_eq(chapter.model.player, Vector2i(1, 6), "the first wall stops the run")
	t.assert_eq(chapter.model.moves, 2, "steps after the wall are not walked")
	t.assert_true(not chapter.move_buffer.pending(), "hitting the wall clears the queue")
	t.assert_true(chapter.bump_count >= 1, "hitting the wall shakes")
	var stopped_at := chapter.model.player
	var bumps: int = chapter.bump_count
	chapter._process(0.5)
	t.assert_eq(chapter.model.player, stopped_at, "nothing moves after the wall")
	# One step is in progress, 24 may wait, the 25th shakes and leaves the 24 alone.
	_reset_cave(chapter, Vector2i(3, 6))
	chapter.bump_count = 0
	_cave(chapter, KEY_LEFT, true, false)
	t.assert_eq(chapter.model.busy, "step", "the cap test starts from a moving step")
	for _extra in MoveBuffer.MAX_PENDING_STEPS:
		_cave(chapter, KEY_LEFT, false, false)
		_cave(chapter, KEY_LEFT, true, false)
	t.assert_eq(chapter.move_buffer.pending_count(), MoveBuffer.MAX_PENDING_STEPS, "the queue fills to the cap")
	var filled: int = chapter.bump_count
	_cave(chapter, KEY_LEFT, false, false)
	_cave(chapter, KEY_LEFT, true, false)
	t.assert_eq(chapter.move_buffer.pending_count(), MoveBuffer.MAX_PENDING_STEPS, "a press on a full queue does not change the queued steps")
	t.assert_true(chapter.bump_count > filled, "a press on a full queue shakes like a wall")
	chapter.free()


static func _test_event_flush_keeps_every_press(t: Node) -> void:
	var ear := Node.new()
	ear.set_script(preload("res://tests/key_count.gd"))
	t.add_child(ear)
	Input.use_accumulated_input = false
	for _i in 8:
		_parse_key(KEY_D, true)
		_parse_key(KEY_D, false)
	Input.flush_buffered_events()
	t.assert_eq(ear.presses, 8, "eight press-release pairs in one frame all reach the game")
	ear.free()


static func _parse_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = false
	Input.parse_input_event(event)


static func _test_maze_rapid_taps(t: Node) -> void:
	var controller = _maze(t)
	_key(controller, KEY_D, true, false)
	_key(controller, KEY_D, false, false)
	controller._process(0.02)
	_key(controller, KEY_D, true, false)
	_key(controller, KEY_D, false, false)
	t.assert_eq(controller.player.pos, Vector2i(3, 2), "two quick taps on the road both step")
	controller.player.pos = Vector2i(9, 2)
	var bumps: int = controller.wall_bumps
	for _i in 5:
		_key(controller, KEY_D, true, false)
		_key(controller, KEY_D, false, false)
	t.assert_eq(controller.player.pos, Vector2i(9, 2), "mashing into a wall does not move")
	t.assert_true(controller.wall_bumps > bumps, "mashing into a wall shakes")
	controller.free()


static func _test_hazard_hold_stop(t: Node) -> void:
	for difficulty in ["easy", "normal", "hard"]:
		DataLoader.set_difficulty(difficulty)
		var controller = _maze(t)
		controller.player.dodge_chance = 0.0
		controller.player.max_hp = 80
		controller.player.hp = 80
		controller.maze = _terrain_row([
			MazeGenerator.Terrain.ANCIENT_ROAD,
			MazeGenerator.Terrain.ANCIENT_ROAD,
			MazeGenerator.Terrain.GROTTO,
			MazeGenerator.Terrain.DESERT,
			MazeGenerator.Terrain.DESERT,
			MazeGenerator.Terrain.DESERT,
			MazeGenerator.Terrain.ANCIENT_ROAD,
			MazeGenerator.Terrain.DESERT,
		])
		controller.player.pos = Vector2i(0, 0)
		var hp = controller.player.hp
		_press(controller, KEY_D, true)
		for echo in range(4):
			_key(controller, KEY_D, true, true)
		controller._process(1.0)
		t.assert_eq(controller.player.pos, Vector2i(2, 0), "hold enters a grotto and stops before wind sand on %s" % difficulty)
		t.assert_eq(controller.player.hp, hp, "stopping before wind sand deals no damage on %s" % difficulty)
		_key(controller, KEY_D, false, false)
		_press(controller, KEY_D, true)
		controller._process(1.0)
		t.assert_eq(controller.player.pos, Vector2i(6, 0), "one new press walks the whole sand patch on %s" % difficulty)
		t.assert_true(controller.player.pos.x < 7, "the next sand patch stops the same hold on %s" % difficulty)
		var dealt := int(1.0 * float(DataLoader.get_difficulty().get("terrain_damage_multiplier", 1.0)))
		t.assert_eq(controller.player.hp, hp - dealt * 3, "only the three sand cells just crossed deal damage on %s" % difficulty)
		_release(controller)
		controller.free()
	DataLoader.set_difficulty("normal")
	var turned = _maze(t)
	turned.player.dodge_chance = 0.0
	turned.player.max_hp = 80
	turned.player.hp = 80
	turned.maze = _sand_with_side_path()
	turned.player.pos = Vector2i(0, 1)
	_press(turned, KEY_D, true)
	turned._process(0.6)
	t.assert_eq(turned.player.pos, Vector2i(1, 1), "hold is waiting in front of the sand")
	_press(turned, KEY_W, true)
	turned._process(0.6)
	t.assert_eq(turned.player.pos, Vector2i(1, 0), "changing direction leaves the sand approach")
	t.assert_eq(turned.player.hp, 80, "changing direction does not enter wind sand")
	_release(turned)
	turned.free()
	var tapped = _maze(t)
	tapped.player.dodge_chance = 0.0
	tapped.player.max_hp = 80
	tapped.player.hp = 80
	tapped.maze = _terrain_row([
		MazeGenerator.Terrain.ANCIENT_ROAD,
		MazeGenerator.Terrain.DESERT,
		MazeGenerator.Terrain.DESERT,
	])
	tapped.player.pos = Vector2i(0, 0)
	_press(tapped, KEY_D, true)
	_key(tapped, KEY_D, false, false)
	t.assert_eq(tapped.player.pos, Vector2i(1, 0), "a tap enters wind sand")
	t.assert_eq(tapped.player.hp, 79, "a tap takes the sand damage")
	tapped._process(0.6)
	t.assert_eq(tapped.player.pos, Vector2i(1, 0), "a released tap does not keep walking")
	tapped.player.pos = Vector2i(0, 0)
	tapped.player.hp = 80
	tapped.hazard_gate.clear()
	tapped._on_mobile_move(MazeGenerator.E)
	tapped._on_mobile_move(MazeGenerator.E)
	t.assert_eq(tapped.player.pos, Vector2i(2, 0), "touch enters wind sand without a hold delay")
	t.assert_eq(tapped.player.hp, 78, "each touch step can take sand damage")
	tapped.free()


static func _sand_with_side_path() -> MazeGenerator:
	var maze := MazeGenerator.new(3, 2)
	maze._init_grid()
	for x in 3:
		maze.terrain[1][x] = MazeGenerator.Terrain.DESERT if x == 2 else MazeGenerator.Terrain.ANCIENT_ROAD
		if x + 1 < 3:
			maze.grid[1][x] |= MazeGenerator.E
			maze.grid[1][x + 1] |= MazeGenerator.W
	maze.terrain[0][1] = MazeGenerator.Terrain.ANCIENT_ROAD
	maze.grid[1][1] |= MazeGenerator.N
	maze.grid[0][1] |= MazeGenerator.S
	return maze


static func _terrain_row(kinds: Array) -> MazeGenerator:
	var maze := MazeGenerator.new(kinds.size(), 1)
	maze._init_grid()
	for x in kinds.size():
		maze.terrain[0][x] = kinds[x]
		if x + 1 < kinds.size():
			maze.grid[0][x] |= MazeGenerator.E
			maze.grid[0][x + 1] |= MazeGenerator.W
	return maze


static func _test_bump_frames(t: Node) -> void:
	var controller = _maze(t)
	controller.player.pos = Vector2i(0, 0)
	_press(controller, KEY_W, true)
	var samples: Array[Vector2] = [controller.player.bump_offset]
	var elapsed := 0.0
	while elapsed < 0.12 - 0.0001:
		controller._process(0.02)
		elapsed += 0.02
		samples.append(controller.player.bump_offset)
	t.assert_true(samples[0].y < -0.9 and samples[0].y > -1.2, "the first frame shoves about a third of the way, y=%s" % samples[0].y)
	t.assert_true(absf(samples[3].y + 3.0) < 0.05, "at 0.06s the shove is 3px up, y=%s" % samples[3].y)
	t.assert_eq(samples[samples.size() - 1], Vector2.ZERO, "at 0.12s the shove has returned")
	var strip := Image.create(samples.size() * 28, 36, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.12, 0.09, 0.07))
	for i in samples.size():
		var center := Vector2i(14 + i * 28, 18) + Vector2i(int(round(samples[i].x)), int(round(samples[i].y)))
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var px: int = center.x + dx
				var py: int = center.y + dy
				if px >= 0 and py >= 0 and px < strip.get_width() and py < strip.get_height():
					strip.set_pixel(px, py, Color(0.95, 0.82, 0.35))
	strip.save_png("/opt/cursor/artifacts/wall-bump-frames.png")
	print("BUMP frames %d peak_y %.2f" % [samples.size(), samples[3].y])
	_release(controller)
	controller.free()


static func _test_one_second_hold(t: Node) -> void:
	for trial in 5:
		var controller = _maze(t)
		controller.player.pos = Vector2i(0, 2)
		_press(controller, KEY_D, true)
		var elapsed := 0.0
		while elapsed < 1.0 - 0.0001:
			if int(elapsed * 20.0) % 4 == 0:
				_key(controller, KEY_D, true, false)
			controller._process(0.05)
			elapsed += 0.05
		var walked: int = controller.player.pos.x
		print("HOLD level1 trial %d cells %d" % [trial + 1, walked])
		t.assert_true(walked >= 7 and walked <= 8, "level 1 trial %d holds 1s for 7-8 cells, got %d" % [trial + 1, walked])
		_release(controller)
		controller.free()


static func _test_wall_cooldown_does_not_stall_hold(t: Node) -> void:
	var controller = _maze(t)
	controller.player.pos = Vector2i(0, 0)
	_press(controller, KEY_W, true)
	t.assert_true(controller.wall_bumps >= 1, "the north wall records a bump")
	_release(controller)
	controller.player.pos = Vector2i(0, 2)
	_press(controller, KEY_D, true)
	var elapsed := 0.0
	while elapsed < 1.0 - 0.0001:
		controller._process(0.05)
		elapsed += 0.05
	t.assert_true(controller.player.pos.x >= 7 and controller.player.pos.x <= 8, "the 0.25s bump cooldown does not eat the hold clock, got x=%d" % controller.player.pos.x)
	_release(controller)
	controller.free()


static func _test_cave_one_second_hold(t: Node) -> void:
	SaveManager.clear_save()
	var host = MainScript.new()
	t.add_child(host)
	host.game.start_game()
	host._new_game(1)
	var chapter: MogaoChapter = host.cave_chapter
	for trial in 5:
		var walked := _cave_hold_seconds(chapter, 1.0)
		print("HOLD level2 trial %d cells %d" % [trial + 1, walked])
		t.assert_true(walked >= 7 and walked <= 8, "level 2 trial %d holds 1s for 7-8 cells, got %d" % [trial + 1, walked])
	host.free()
	SaveManager.clear_save()


static func _cave_hold_seconds(chapter: MogaoChapter, seconds: float) -> int:
	_reset_cave(chapter, Vector2i(0, 6))
	for x in 16:
		chapter.model.land[Vector2i(x, 6)] = true
	chapter.model.player = Vector2i(0, 6)
	chapter.model.destination = chapter.model.player
	chapter.model.moves = 0
	chapter.model.busy = ""
	_cave(chapter, KEY_RIGHT, true, false)
	var elapsed := 0.0
	while elapsed < seconds - 0.0001:
		if int(elapsed * 20.0) % 4 == 0:
			_cave(chapter, KEY_RIGHT, true, false)
		chapter._process(0.05)
		elapsed += 0.05
	_cave(chapter, KEY_RIGHT, false, false)
	return chapter.model.moves


static func _maze(t: Node):
	SaveManager.clear_save()
	var controller = MainScript.new()
	t.add_child(controller)
	controller.game.start_game()
	controller._new_game(0)
	controller.journey_card.close()
	controller.first_journey = null
	for monster in controller.monsters.duplicate():
		if is_instance_valid(monster):
			monster.free()
	controller.monsters.clear()
	for item in controller.items.duplicate():
		if is_instance_valid(item):
			item.free()
	controller.items.clear()
	controller.maze = _open(10, 5)
	controller.player.pos = Vector2i(1, 2)
	controller.exit_pos = Vector2i(99, 99)
	controller.attack_cooldown = 0.0
	controller.attack_buffer.clear()
	controller.input_handler.held.clear()
	controller.modal_release_guard = false
	return controller


static func _open(width: int, height: int) -> MazeGenerator:
	var maze := MazeGenerator.new(width, height)
	maze._init_grid()
	for y in height:
		for x in width:
			maze.terrain[y][x] = MazeGenerator.Terrain.ANCIENT_ROAD
			if x + 1 < width:
				maze.grid[y][x] |= MazeGenerator.E
				maze.grid[y][x + 1] |= MazeGenerator.W
			if y + 1 < height:
				maze.grid[y][x] |= MazeGenerator.S
				maze.grid[y + 1][x] |= MazeGenerator.N
	return maze


static func _press(controller, keycode: int, pressed: bool) -> void:
	_key(controller, keycode, pressed, false)


static func _key(controller, keycode: int, pressed: bool, echo: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	controller._input(event)
	controller._unhandled_input(event)


static func _release(controller) -> void:
	for keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]:
		_key(controller, keycode, false, false)


static func _cave(chapter: MogaoChapter, keycode: int, pressed: bool, echo: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	chapter._unhandled_key_input(event)


static func _reset_cave(chapter: MogaoChapter, pos: Vector2i) -> void:
	if chapter.mode != "playing":
		chapter.close_card()
	chapter.input_handler.held.clear()
	chapter.move_buffer.clear()
	chapter.model.busy = ""
	chapter.model.progress = 0.0
	chapter.model.paused = false
	chapter.model.player = pos
	chapter.model.destination = pos
	chapter.model.moves = 0
