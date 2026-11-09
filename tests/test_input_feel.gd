extends RefCounted

const HeldMoveScript = preload("res://scripts/handlers/held_move.gd")
const MainScript = preload("res://scripts/main.gd")


static func run(t: Node) -> void:
	print("\n[TEST] Keyboard hold, attack buffer, and cave step buffer")
	t.assert_eq(HeldMoveScript.REPEAT_SECONDS, 0.14, "held movement interval is 0.14 seconds")
	_test_hold_rhythm(t)
	_test_long_hold_keeps_rhythm(t)
	_test_echo_and_latest_direction(t)
	_test_modal_does_not_catch_up(t)
	_test_attack_buffer(t)
	_test_cave_buffer(t)
	_test_hazard_hold_stop(t)
	_test_wall_hold_bumps_once(t)


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
	t.assert_eq(chapter.model.moves, 0, "cave animation still lasts the full step")
	chapter._process(CaveModel.STEP_SECONDS)
	t.assert_eq(chapter.model.player, Vector2i(2, 6), "held cave key finishes the first step")
	t.assert_eq(chapter.model.busy, "step", "held cave key queues exactly one more step")
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
	t.assert_eq(chapter.model.moves, 1, "several presses during one cave step become one step")
	t.assert_eq(chapter.model.busy, "step", "the single buffered cave step starts after the animation")
	t.assert_eq(chapter.model.destination, Vector2i(2, 6), "the buffered cave step keeps the latest direction")
	chapter._process(CaveModel.STEP_SECONDS)
	t.assert_eq(chapter.model.player, Vector2i(2, 6), "the buffered cave step resolves once")
	t.assert_eq(chapter.model.busy, "", "a released buffer does not chain another step")
	t.assert_eq(chapter.model.moves, 2, "cave buffer executed one extra step, not three")

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
