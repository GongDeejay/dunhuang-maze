extends RefCounted
static func walk(t: Node, m: CaveModel, directions: Array) -> void:
	for d in directions:
		t.assert_true(m.step(d), "authored solution step accepted")
		m.advance(1)

static func route(t: Node, m: CaveModel, text: String) -> void:
	for letter in text:
		walk(t, m, [{"U": Vector2i.UP, "D": Vector2i.DOWN, "L": Vector2i.LEFT, "R": Vector2i.RIGHT}[letter]])

static func expanded_rooms(t: Node, m: CaveModel) -> void:
	t.assert_eq(m.room, 3, "shared ears leads into relay cave")
	route(t, m, "LLUURDRURRUU")
	t.assert_true(m.latch and m.gate_open(0), "crossing the first relay door latches it permanently")
	m.undo()
	t.assert_true(not m.latch, "undo atomically restores the door latch")
	route(t, m, "UUDDDLLLURRDRUUULLUUU")
	t.assert_true(m.reached and m.box == CaveModel.RELAY_PLATES[1], "same crate transported through latched door to upper plate")
	t.assert_true(m.next_room() and m.room == 4, "relay leads to light bridge")
	m.use_lamp(); m.advance(1)
	route(t, m, "LLU"); m.use_lamp(); m.advance(1)
	t.assert_true(m.lit() and not m.walkable(Vector2i(3, 2)), "light alone cannot align the bridge")
	route(t, m, "RRRR"); m.turn(); m.advance(1)
	t.assert_true(m.undo() and m.bridges[0].pose == 0 and m.lit(), "undo rotation keeps placed light")
	m.turn(); m.advance(1)
	route(t, m, "LLUU")
	t.assert_true(not m.can_turn() and m.lamp_action().is_empty(), "cannot remove supporting lamp or turn from bridge")
	route(t, m, "UUUU")
	t.assert_true(m.reached and m.next_room() and m.room == 2, "combination cave leads to original deer finale")

static func pressure_graph(t: Node, room_id: int = 1) -> void:
	# Explore every reachable player/crate arrangement using the actual movement rules.
	var initial := CaveModel.new(); initial.load_room(room_id)
	var queue := [[initial.player, initial.box, false]]
	var seen := {str(queue[0]): true}
	var cursor := 0; var solved := false; var bypass := false
	while cursor < queue.size():
		var state: Array = queue[cursor]; cursor += 1
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var m := CaveModel.new(); m.load_room(room_id)
			m.player = state[0]; m.destination = state[0]; m.box = state[1]
			m.latch = state[2]
			if not m.step(direction): continue
			m.advance(1)
			if m.reached:
				solved = true
				if m.box != (CaveModel.PLATE if room_id == 1 else CaveModel.RELAY_PLATES[1]): bypass = true
				continue
			var next := [m.player, m.box, m.latch]; var key := str(next)
			if not seen.has(key):
				seen[key] = true; queue.append(next)
	t.assert_true(solved, "exhaustive pressure graph contains a winning route")
	t.assert_true(not bypass, "neither side plate nor body-only weight bypasses the shared crate solution")

static func run(t: Node) -> void:
	print("\n[TEST] Mogao three distinct cave mechanisms")
	pressure_graph(t)
	pressure_graph(t, 3)
	var dark := CaveModel.new(); dark.load_room(4)
	route(t, dark, "RRU"); dark.turn(); dark.advance(1)
	t.assert_true(not dark.walkable(Vector2i(3, 4)), "aligned bridge still requires the lamp to reveal its safe path")
	dark.load_room(3); dark.latch = true; dark.load_room(3)
	t.assert_true(not dark.latch, "reset clears latched gate")
	var m := CaveModel.new()
	t.assert_true(not m.turn() and m.history.is_empty(), "unavailable crank and can_turn checks do not create undo entries")
	walk(t, m, [Vector2i.UP])
	t.assert_true(not m.step(Vector2i.UP), "unconnected bridge blocks movement")
	t.assert_true(m.turn(), "bank crank turns bridge")
	t.assert_true(not m.step(Vector2i.UP) and not m.turn(), "rotation cannot queue movement or duplicate turns")
	m.advance(.2); m.paused = true
	var progress := m.progress; m.advance(3)
	t.assert_eq(m.progress, progress, "pause freezes rotation")
	m.paused = false; m.advance(1)
	t.assert_true(m.undo() and m.bridges[0].pose == 0, "undo restores bridge orientation")
	m.turn(); m.advance(1)
	walk(t, m, [Vector2i.UP])
	t.assert_true(not m.turn(), "cannot move supporting bridge under player")
	walk(t, m, [Vector2i.UP, Vector2i.UP, Vector2i.UP, Vector2i.UP])
	t.assert_true(m.reached and m.scarf and not m.rescued, "scarf is a clue, never a rescue")
	var completed_bridge := m
	var restart_bridge := CaveModel.new()
	restart_bridge.scarf = true; restart_bridge.load_room(0)
	t.assert_true(not restart_bridge.scarf and not restart_bridge.reached, "resetting first cave restores the visible scarf")
	m = completed_bridge
	t.assert_true(m.next_room() and m.room == 1 and m.history.is_empty(), "next cave clears local undo, not prior story")
	t.assert_true(m.bridges.is_empty() and not m.gate_open(), "pressure room is not another bridge")
	# Walk onto the plate: the body opens it but cannot hold it from across the room.
	walk(t, m, [Vector2i.LEFT, Vector2i.LEFT, Vector2i.UP, Vector2i.UP, Vector2i.UP])
	t.assert_true(m.gate_open(0) and not m.gate_open(1), "left plate powers only first door")
	walk(t, m, [Vector2i.DOWN])
	t.assert_true(not m.gate_open(), "leaving plate removes body weight")
	walk(t, m, [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.UP, Vector2i.UP])
	t.assert_true(not m.gate_open(0) and m.gate_open(1), "right plate powers only second door")
	walk(t, m, [Vector2i.LEFT, Vector2i.LEFT])
	t.assert_true(m.gate_open(), "shared middle plate powers both doors")
	t.assert_true(not m.step(Vector2i.UP), "cannot slip through a gate as own weight leaves shared plate")
	m.load_room(1)
	# Move around the crate; push right, then north onto the plate.
	walk(t, m, [Vector2i.LEFT, Vector2i.LEFT, Vector2i.UP, Vector2i.UP, Vector2i.RIGHT])
	t.assert_eq(m.box, Vector2i(3, 4), "walking into crate pushes exactly one cell")
	t.assert_true(m.undo() and m.box == Vector2i(2, 4) and m.player == Vector2i(1, 4), "undo restores crate and actor atomically")
	walk(t, m, [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP])
	t.assert_eq(m.box, CaveModel.PLATE, "crate can remain on plate")
	t.assert_true(m.gate_open(), "crate holds gate without player weight")
	walk(t, m, [Vector2i.LEFT, Vector2i.UP, Vector2i.UP, Vector2i.RIGHT, Vector2i.UP, Vector2i.UP])
	t.assert_true(m.reached and m.next_room(), "can physically pass the pressure gate")
	expanded_rooms(t, m)
	t.assert_eq(m.room, 2, "lamp room follows pressure puzzle")
	t.assert_true(not m.lit() and not m.walkable(Vector2i(5, 4)), "dark path cannot be brute-forced before lighting")
	t.assert_true(m.use_lamp(), "lamp can be picked up from entrance")
	m.advance(1)
	t.assert_true(m.lamp_held and not m.use_lamp(), "carried lamp can only be placed near a stand")
	walk(t, m, [Vector2i.LEFT, Vector2i.LEFT, Vector2i.UP])
	m.use_lamp(); m.advance(1)
	t.assert_true(m.deer_seen and not m.lit(), "left stand reveals optional mural, not forced success")
	t.assert_true(m.undo() and m.lamp_held and not m.deer_seen, "lamp placement is undoable")
	walk(t, m, [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT])
	m.use_lamp(); m.advance(1)
	t.assert_true(m.bank_lit() and not m.lit() and m.deer_time == 0, "lighting bank begins story, never instantly awards route")
	m.advance(.6); m.paused = true
	var crossing := m.deer_time; m.advance(8)
	t.assert_eq(m.deer_time, crossing, "pause freezes nonmodal deer crossing")
	m.paused = false
	t.assert_true(m.undo() and m.lamp_held and m.deer_time < 0, "undo removes pending story and route together")
	m.use_lamp(); m.advance(1); m.advance(4.5)
	t.assert_true(m.lit() and m.walkable(Vector2i(5, 4)), "right stand reveals real walkable footprint route")
	walk(t, m, [Vector2i.UP, Vector2i.UP])
	t.assert_true(not m.use_lamp(), "cannot remove light while standing on revealed route")
	walk(t, m, [Vector2i.LEFT, Vector2i.UP, Vector2i.LEFT, Vector2i.UP, Vector2i.UP, Vector2i.UP])
	t.assert_true(m.rescued and not m.reached, "brother rescue is distinct from chapter exit")
	walk(t, m, [Vector2i.RIGHT, Vector2i.RIGHT])
	t.assert_true(m.reached and not m.next_room(), "chapter exit requires physically reaching doorway, not a fourth room")
	# Crates can be mis-pushed into a corner, but every accepted action is reversible.
	m.load_room(1)
	walk(t, m, [Vector2i.LEFT, Vector2i.LEFT, Vector2i.UP, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP])
	t.assert_eq(m.box, Vector2i(3, 3), "crate stops before gate")
	t.assert_true(not m.step(Vector2i.UP), "crate cannot enter gate or void")
	t.assert_true(m.undo() and m.box == Vector2i(3, 4), "dead end is recoverable without replaying chapter")
	t.assert_true(not m.gate_open(), "undo also closes both shared doors")
	m.load_room(2)
	m.use_lamp(); m.advance(1)
	walk(t, m, [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.UP])
	m.use_lamp(); m.advance(1); m.advance(4.5)
	t.assert_true(m.lit(), "loading story and optional left stand are not prerequisites")
	m.use_lamp(); m.advance(1)
	t.assert_true(not m.lit() and m.deer_time >= CaveModel.DEER_SECONDS, "completed story remembered when picking lamp up")
	m.use_lamp(); m.advance(1)
	t.assert_true(m.lit(), "replacing lamp need not replay a completed rescue")
	m.load_room(2)
	t.assert_true(m.deer_time < 0 and not m.deer_seen and not m.lit(), "room reset clears animation and reveal atomically")
	var controller = load("res://scripts/main.gd").new(); t.add_child(controller)
	controller._new_game(1)
	t.assert_true(controller.cave_chapter != null and controller.maze == null, "campaign uses new chapter controller")
	t.assert_true(controller.monsters.is_empty() and not controller.mobile_controls.visible, "old combat and touch layer disabled")
	t.assert_eq(SaveManager.load_progress().level_index, 1, "legacy chapter checkpoint remains compatible")
	var c: MogaoChapter = controller.cave_chapter
	c.move(Vector2i.UP); c._process(1)
	c.turn(); c._process(.1); c._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var frozen := c.model.progress; c._process(5)
	t.assert_true(c.mode == "pause" and c.model.progress == frozen, "focus loss pauses new chapter")
	c.close_card(); c._process(1)
	c.show_note(); var pos := c.model.player; c.move(Vector2i.UP)
	t.assert_eq(c.model.player, pos, "reading a note blocks movement")
	c.close_card(); c.pause_game(); c.modal_tertiary(); c.modal_primary()
	t.assert_true(controller.cave_chapter == null and controller.game.is_difficulty_select(), "menu tears down cave and preserves checkpoint")
	controller._new_game(1)
	t.assert_eq(controller.cave_chapter.model.room, 0, "resuming chapter uses documented entrance checkpoint")
	controller._new_game(0)
	t.assert_true(controller.cave_chapter == null and controller.first_journey != null, "first chapter isolated after leaving cave")
	SaveManager.save_progress(1, "normal", 1, 0, 4)
	controller._new_game(1)
	t.assert_eq(controller.cave_chapter.model.room, 4, "new room entrance checkpoint resumes without repeating solved caves")
	controller.cave_chapter.model.reached = true
	controller.cave_chapter.model.player = controller.cave_chapter.model.goal
	controller.cave_chapter.interact()
	t.assert_eq(SaveManager.load_progress().cave_room, 2, "moving into deer cave saves stable room id, not sequence number")
	controller._new_game(2)
	t.assert_true(not SaveManager.load_progress().has("cave_room"), "third chapter removes cave-only checkpoint")
	controller.free(); SaveManager.clear_save()
