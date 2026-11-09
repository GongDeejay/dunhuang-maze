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

static func shared_ear_doors(t: Node) -> void:
	var m := CaveModel.new()
	m.load_room(1)
	route(t, m, "UUU")
	t.assert_eq(m.player, CaveModel.PLATE, "player stands on the shared plate")
	t.assert_true(m.gate_open(0) and m.gate_open(1), "body weight still powers both wires")
	t.assert_true(not m.gate_passable(0) and not m.gate_passable(1), "neither door stays open once that weight leaves")
	t.assert_true(not m.step(Vector2i.UP), "cannot walk through the door held only by the player")
	var c := MogaoChapter.new()
	t.add_child(c)
	c.model.load_room(1)
	c.model.player = CaveModel.PLATE
	c.model.destination = c.model.player
	c.model.box = Vector2i(2, 4)
	c.gate_visual = [1.0, 1.0]
	c._process(1.0)
	t.assert_true(c.model.gate_open() and not c.door_leaf_open(0) and not c.door_leaf_open(1), "pressed plate draws both shared doors shut")
	c.model.box = CaveModel.PLATE
	c.model.player = Vector2i(2, 2)
	c.model.destination = c.model.player
	c._process(1.0)
	t.assert_true(c.model.gate_passable(0) and c.door_leaf_open(0) and c.door_leaf_open(1), "crate on the shared plate draws both doors open")
	t.assert_true(c.model.step(Vector2i.RIGHT), "the drawn-open door can be entered from beside it")
	var relay := MogaoChapter.new()
	t.add_child(relay)
	relay.model.load_room(3)
	relay.model.player = CaveModel.RELAY_PLATES[0]
	relay.model.destination = relay.model.player
	relay.model.box = Vector2i(2, 6)
	relay._process(1.0)
	t.assert_true(not relay.model.gate_passable(0) and relay.gate_visual[0] > 0.9, "borrowed corridor still draws a pressed plate as an open leaf")
	c.free()
	relay.free()

static func cave_popup_layer(t: Node) -> void:
	var c := MogaoChapter.new()
	t.add_child(c)
	for room_id in [0, 1, 2, 3, 4, 5, CaveModel.MIRROR_ROOM]:
		c.close_card()
		c.model.load_room(room_id)
		c.rebuild_cranks()
		c.show_note()
		t.assert_true(c.overlay.visible, "room %s opens its note" % room_id)
		t.assert_true(c.overlay.get_parent() is CanvasLayer, "room %s note sits on a canvas layer" % room_id)
		var layer := c.overlay.get_parent() as CanvasLayer
		t.assert_true(layer.layer >= 40, "room %s note draws above the cave sprites" % room_id)
		t.assert_true(c.mirror_art.get_parent() != layer and c.lamp_halo.get_parent() != layer, "sprites stay off the popup layer")
	c.show_note()
	t.assert_eq(c.card_title.text.replace("\n", ""), "镜窟 · 铜镜折光", "reopening the solved mirror cave shows the refraction note")
	t.assert_true(c.mirror_art.preview_layer.z_index > 0, "mirror preview still stacks above the mirror sprites")
	t.assert_true((c.overlay.get_parent() as CanvasLayer).layer > c.mirror_art.preview_layer.z_index, "popup layer is above the preview")
	c.show_card("finish", "走出莫高窟", "这次走了 6 步\n用时 6 分 14 秒", "前往三危山", "再看看洞窟")
	t.assert_true(c.overlay.visible and c.overlay.get_parent() is CanvasLayer, "settlement uses the same top layer")
	c.free()

static func mirror_turn_queue(t: Node) -> void:
	var chapter := MogaoChapter.new()
	t.add_child(chapter)
	t.assert_eq(_mirror_presses(chapter, 2), 2, "two presses during the spin turn the mirror twice")
	t.assert_eq(chapter.model.busy, "", "the queued turn finishes")
	t.assert_eq(_mirror_presses(chapter, 3), 2, "a third press during the first spin does not add a third turn")
	t.assert_eq(chapter.model.busy, "", "three presses still finish after two turns")
	chapter.free()


static func _mirror_presses(chapter: MogaoChapter, count: int) -> int:
	chapter.model.load_room(CaveModel.MIRROR_ROOM)
	chapter.model.player = Vector2i(5, 8)
	chapter.model.destination = chapter.model.player
	chapter.mirror_turn_queued = false
	chapter.mode = "playing"
	chapter.model.paused = false
	chapter.rebuild_cranks()
	var start := int(chapter.model.mirror_rot_of("T"))
	for _i in count:
		chapter.interact()
	for _step in 3:
		chapter._process(0.8)
	return int(chapter.model.mirror_rot_of("T")) - start


static func _key(chapter: MogaoChapter, keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	chapter._unhandled_key_input(event)


static func _open_lamp(chapter: MogaoChapter) -> void:
	chapter.model.load_room(4)
	chapter.model.entry = Vector2i(3, 7)
	chapter.model.player = CaveModel.STANDS[0]
	chapter.model.destination = chapter.model.player
	chapter.model.lamp = CaveModel.STANDS[0]
	chapter.model.lamp_held = false
	chapter.model.paused = false
	chapter.mode = "playing"
	chapter.overlay.hide()
	chapter.rebuild_cranks()
	chapter.refresh()


static func _turn_bridge(t: Node, chapter: MogaoChapter) -> void:
	chapter.input_handler.held.clear()
	chapter.model.player = Vector2i(5, 5)
	chapter.model.destination = chapter.model.player
	t.assert_true(chapter.model.busy.is_empty(), "the cave is idle before the bridge turns")
	t.assert_true(chapter.model.can_turn(), "the bridge crank accepts a turn after the wait")
	t.assert_true(chapter.model.turn(), "the bridge can be turned")
	chapter._process(0.8)
	t.assert_eq(chapter.model.bridges[0].pose, 1, "the bridge finishes its turn")
	t.assert_eq(chapter.model.busy, "", "the turn does not stay in the wait")


static func lamp_wait_recovers(t: Node) -> void:
	var chapter := MogaoChapter.new()
	t.add_child(chapter)
	# Old save: lamp already on the left stand, plus a stray wait field.
	var saved: Dictionary = {
		"version": 3,
		"shortcut": false,
		"secret": false,
		"entry": [3, 7],
		"rooms": {
			"4": {
				"player": [1, 5], "box": [-9, -9], "lamp": [1, 5], "held": false,
				"deer": true, "deer_time": -1, "rescued": false, "reached": false,
				"scarf": true, "latch": false, "poses": [0], "moves": 12, "turns": 0,
				"busy": "lamp",
			},
		},
	}
	chapter.model.busy = "lamp"
	chapter.model.paused = true
	chapter.model.resume_network(4, saved)
	chapter.rebuild_cranks()
	chapter.mode = "playing"
	chapter.refresh()
	t.assert_eq(chapter.model.busy, "", "an old lamp-cave save drops an in-progress wait")
	t.assert_true(not chapter.model.paused and chapter.model.lit(), "the saved lamp is placed and the cave is unpaused")
	t.assert_true(chapter.hint.text != "灯光正在安定下来……", "loading does not restore the settling hint")
	_turn_bridge(t, chapter)

	# Pause mid-wait, then continue. The bridge must turn afterwards.
	_open_lamp(chapter)
	chapter.model.lamp_held = true
	t.assert_true(chapter.model.use_lamp(), "placing the lamp starts its wait")
	chapter.pause_game()
	chapter.action_started_msec = Time.get_ticks_msec() - chapter.action_limit_msec - 50
	var frozen := chapter.model.progress
	chapter._process(5.0)
	t.assert_eq(chapter.model.busy, "lamp", "a visible pause keeps the lamp wait")
	t.assert_eq(chapter.model.progress, frozen, "a visible pause does not force-settle the lamp")
	chapter.close_card()
	chapter._process(0.8)
	t.assert_true(chapter.model.busy.is_empty() and chapter.model.lit(), "continuing finishes the lamp and leaves it on the stand")
	_turn_bridge(t, chapter)

	# The reported picture: light already on the stand, wait still saying it is settling.
	_open_lamp(chapter)
	t.assert_true(chapter.model.lit() and chapter.model.use_lamp(), "picking the placed lamp up starts the wait")
	chapter.refresh()
	var pose: int = int(chapter.model.bridges[0].pose)
	chapter.interact()
	t.assert_eq(chapter.hint.text, "灯光正在安定下来……", "the lamp wait is the settling hint")
	t.assert_eq(chapter.action_button.text, "转动栈桥", "the wait relabels the action as a bridge turn")
	t.assert_true(chapter.action_button.disabled, "the wait locks the bridge button")
	t.assert_eq(chapter.model.bridges[0].pose, pose, "clicking the bridge button during the wait does nothing")
	t.assert_eq(chapter.model.busy, "lamp", "the click leaves the wait in place")
	chapter.action_limit_msec = 0
	chapter.action_started_msec = 0
	chapter._process(0.0)
	chapter.action_limit_msec = 2000
	t.assert_true(chapter.model.busy.is_empty() and chapter.model.lamp_held, "a stalled lamp wait force-settles")
	chapter.refresh()
	t.assert_true(chapter.hint.text != "灯光正在安定下来……", "settling clears the stuck hint")
	t.assert_true(chapter.model.use_lamp(), "the lamp can be put back on the stand")
	chapter._process(0.8)
	t.assert_true(chapter.model.lit() and chapter.model.busy.is_empty(), "the lamp is placed again and idle")
	_turn_bridge(t, chapter)

	# Held direction plus a slow frame used to skip advance entirely.
	_open_lamp(chapter)
	t.assert_true(chapter.model.use_lamp(), "held-key case starts the lamp wait")
	_key(chapter, KEY_D, true)
	for _i in 4:
		chapter._process(0.2)
	_key(chapter, KEY_D, false)
	t.assert_eq(chapter.model.busy, "", "a held direction no longer freezes the lamp wait")
	t.assert_true(chapter.model.lamp_held, "the pick still finishes while the key is held")
	t.assert_true(chapter.model.use_lamp() and chapter.model.busy == "lamp", "the lamp can be placed after the held-key wait")
	chapter._process(0.8)
	_turn_bridge(t, chapter)

	# Reset this cave while the wait is on screen.
	_open_lamp(chapter)
	t.assert_true(chapter.model.use_lamp(), "reset case starts the lamp wait")
	chapter.show_card("reset", "重置这一窟？", "只重置当前洞窟的机关和位置，之前通过的洞窟不受影响。", "确认重置", "继续思考")
	chapter.modal_primary()
	t.assert_eq(chapter.model.busy, "", "reset clears the lamp wait")
	t.assert_true(chapter.mode == "playing" and not chapter.model.paused and not chapter.overlay.visible, "reset returns to the cave")
	t.assert_eq(chapter.model.player, Vector2i(3, 7), "reset returns the player to the cave entrance")
	t.assert_eq(chapter.model.lamp, Vector2i(3, 6), "reset puts the lamp back at its start")
	t.assert_true(chapter.hint.text != "灯光正在安定下来……", "reset clears the settling hint")
	_turn_bridge(t, chapter)

	# A pause flag with no card (the blur path failed to show one) must not lock the wait.
	_open_lamp(chapter)
	t.assert_true(chapter.model.use_lamp(), "hidden pause starts the lamp wait")
	chapter.model.paused = true
	chapter.mode = "playing"
	chapter.overlay.hide()
	chapter._process(0.0)
	chapter._process(0.8)
	t.assert_true(not chapter.model.paused and chapter.model.busy.is_empty() and chapter.model.lamp_held, "a pause with no card cannot lock the lamp")
	t.assert_true(chapter.model.use_lamp(), "the lamp can be replaced after the hidden pause")
	chapter._process(0.8)
	_turn_bridge(t, chapter)

	# Mirror wait uses the same lock. A zero-delta stall and a held key both recover.
	chapter.model.load_room(CaveModel.MIRROR_ROOM)
	chapter.model.player = Vector2i(5, 8)
	chapter.model.destination = chapter.model.player
	chapter.model.paused = false
	chapter.mode = "playing"
	chapter.rebuild_cranks()
	var start := int(chapter.model.mirror_rot_of("T"))
	t.assert_true(chapter.model.turn_mirror(), "mirror wait can start")
	chapter.action_limit_msec = 0
	chapter.action_started_msec = 0
	chapter._process(0.0)
	chapter.action_limit_msec = 2000
	t.assert_eq(chapter.model.busy, "", "a stalled mirror wait force-settles")
	t.assert_eq(int(chapter.model.mirror_rot_of("T")), start + 1, "the stalled mirror turn still applies")
	t.assert_true(chapter.model.turn_mirror(), "another mirror turn can start")
	_key(chapter, KEY_D, true)
	chapter._process(0.8)
	_key(chapter, KEY_D, false)
	t.assert_eq(chapter.model.busy, "", "a held key does not freeze the mirror")
	t.assert_eq(int(chapter.model.mirror_rot_of("T")), start + 2, "the held-key mirror turn applies")
	t.assert_true(chapter.model.turn_mirror(), "the mirror can be turned again after the wait")
	chapter.free()

	# Shared-ear leaves do not use the action wait. A stalled frame still catches up,
	# and a plate the player is standing on does not become a door.
	var ears := MogaoChapter.new()
	t.add_child(ears)
	ears.model.load_room(1)
	ears.model.box = CaveModel.PLATE
	ears.model.player = Vector2i(2, 2)
	ears.model.destination = ears.model.player
	ears.gate_visual = [0.0, 0.0]
	ears.action_limit_msec = 0
	ears.visual_since_msec = 0
	ears._process(0.0)
	t.assert_eq(ears.model.busy, "", "shared-ear plates do not enter an action wait")
	t.assert_true(ears.door_leaf_open(0) and ears.door_leaf_open(1), "a stalled shared-ear door catches up to the crate")
	t.assert_true(ears.model.step(Vector2i.RIGHT), "the caught-up shared door can be walked")
	ears._process(0.3)
	t.assert_eq(ears.model.player, Vector2i(3, 2), "the player finishes stepping through the shared door")
	t.assert_eq(ears.model.busy, "", "the shared-ear step does not stay locked")
	ears.model.load_room(1)
	ears.model.player = CaveModel.PLATE
	ears.model.destination = ears.model.player
	ears.model.box = Vector2i(2, 4)
	ears.gate_visual = [1.0, 1.0]
	ears.action_limit_msec = 0
	ears.visual_since_msec = 0
	ears._process(0.0)
	t.assert_true(not ears.door_leaf_open(0) and not ears.door_leaf_open(1), "body weight does not keep the shared door drawn open")
	t.assert_true(not ears.model.step(Vector2i.UP), "the fallback does not open a door held only by the player")
	ears.free()


static func run(t: Node) -> void:
	print("\n[TEST] Mogao three distinct cave mechanisms")
	shared_ear_doors(t)
	cave_popup_layer(t)
	mirror_turn_queue(t)
	lamp_wait_recovers(t)
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
	t.assert_eq(SaveManager.load_progress().cave_room, 7, "moving into the mirror cave saves its stable room id, not a sequence number")
	controller._new_game(2)
	t.assert_true(not SaveManager.load_progress().has("cave_room"), "third chapter removes cave-only checkpoint")
	controller.free(); SaveManager.clear_save()
