extends RefCounted
static func walk(t: Node, m: CaveModel, directions: Array) -> void:
	for d in directions:
		t.assert_true(m.step(d), "authored solution step accepted")
		m.advance(1)

static func route(t: Node, m: CaveModel, text: String) -> void:
	for letter in text:
		walk(t, m, [{"U": Vector2i.UP, "D": Vector2i.DOWN, "L": Vector2i.LEFT, "R": Vector2i.RIGHT}[letter]])

static func expanded_rooms(t: Node, m: CaveModel) -> void:
	t.assert_eq(m.room, 3, "shared ears leads into the plank cave")
	var before_moves := m.moves
	route(t, m, "UULUUL")
	t.assert_eq(m.plank_count(), 1, "leaving a counting plank flips it")
	t.assert_true(m.planks_up.has(CaveModel.PLANK_DEMO) and m.plank_count() == 1, "the demo plank flips and is not counted")
	m.undo()
	t.assert_eq(m.plank_count(), 0, "undo lowers the plank flipped by that step")
	t.assert_true(not m.planks_up.has(Vector2i(2, 4)), "the undone plank lies flat again")
	route(t, m, "LUURRDDRRUULULU")
	t.assert_true(m.reached and m.moves - before_moves == 20 and m.plank_count() == 11, "the authored route opens the rope gate in 20 steps")
	t.assert_true(m.walkable(Vector2i(2, 4)) and m.walkable(Vector2i(4, 1)) and m.walkable(m.goal), "solved planks are nailed and the gate stays open")
	t.assert_true(m.next_room() and m.room == 4, "plank cave leads to light bridge")
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
	var queue := [[initial.player, initial.box]]
	var seen := {str(queue[0]): true}
	var cursor := 0; var solved := false; var bypass := false
	while cursor < queue.size():
		var state: Array = queue[cursor]; cursor += 1
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var m := CaveModel.new(); m.load_room(room_id)
			m.player = state[0]; m.destination = state[0]; m.box = state[1]
			if not m.step(direction): continue
			m.advance(1)
			if m.reached:
				solved = true
				if m.box != CaveModel.PLATE: bypass = true
				continue
			var next := [m.player, m.box]; var key := str(next)
			if not seen.has(key):
				seen[key] = true; queue.append(next)
	t.assert_true(solved, "exhaustive pressure graph contains a winning route")
	t.assert_true(not bypass, "neither side plate nor body-only weight bypasses the shared crate solution")

static func _plank_key(pos: Vector2i, flips: Array) -> String:
	var parts: Array[String] = []
	for cell in flips:
		parts.append("%d:%d" % [cell.x, cell.y])
	parts.sort()
	return "%d,%d|%s" % [pos.x, pos.y, "|".join(parts)]

static func _plank_apply(m: CaveModel, pos: Vector2i, flips: Array) -> void:
	m.load_room(3)
	m.player = pos
	m.destination = pos
	m.planks_up.clear()
	for cell in flips:
		m.planks_up[cell] = true

static func _dirs() -> Array:
	return [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

static func plank_graph(t: Node) -> void:
	var expected: Array[Vector2i] = [
		Vector2i(2, 4), Vector2i(1, 4), Vector2i(1, 3), Vector2i(2, 2), Vector2i(3, 2),
		Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(5, 3), Vector2i(4, 2), Vector2i(4, 1),
	]
	var solved_model := CaveModel.new()
	solved_model.load_room(3)
	route(t, solved_model, "UULUULUURRDDRRUULULU")
	var authored: Array[Vector2i] = []
	for cell in solved_model.planks_up.keys():
		if cell in CaveModel.PLANK_CELLS:
			authored.append(cell)
	t.assert_eq(authored, expected, "authored route flips the planks in the only order")
	t.assert_eq(solved_model.moves, 20, "authored route is 20 steps")
	var stair := CaveModel.new()
	stair.load_room(3)
	route(t, stair, "LUUUULUURRDDRRUULULU")
	t.assert_true(stair.reached and stair.moves == 20, "skipping the demo plank still solves in 20 steps")
	var m := CaveModel.new()
	m.load_room(3)
	var queue: Array = [[m.player, []]]
	var seen := {_plank_key(m.player, []): true}
	var dist := {_plank_key(m.player, []): 0}
	var states: Array = [[m.player, []]]
	var edges := {}
	var orders := {}
	var min_moves := 999
	var head := 0
	while head < queue.size():
		var state: Array = queue[head]
		head += 1
		var pos: Vector2i = state[0]
		var flips: Array = state[1]
		var key := _plank_key(pos, flips)
		var depth: int = dist[key]
		var nexts: Array = []
		for direction in _dirs():
			_plank_apply(m, pos, flips)
			if not m.step(direction):
				continue
			m.advance(1)
			if m.reached:
				nexts.append("WIN")
				min_moves = mini(min_moves, depth + 1)
				var seq: Array[Vector2i] = []
				for cell in m.planks_up.keys():
					if cell in CaveModel.PLANK_CELLS:
						seq.append(cell)
				orders[str(seq)] = seq
				continue
			var next_flips: Array = []
			for cell in m.planks_up.keys():
				next_flips.append(cell)
			var nxt := _plank_key(m.player, next_flips)
			nexts.append(nxt)
			if not seen.has(nxt):
				seen[nxt] = true
				dist[nxt] = depth + 1
				var stored: Array = [m.player, next_flips]
				queue.append(stored)
				states.append(stored)
		edges[key] = nexts
	t.assert_eq(seen.size(), 206, "plank cave has the authored 206 reachable states")
	t.assert_eq(orders.size(), 1, "only one plank order wins")
	t.assert_eq(min_moves, 20, "shortest win is 20 steps")
	t.assert_eq(orders.values()[0], expected, "the winning plank order is fixed")
	var winning := {}
	var rev := {}
	for from_key in edges:
		for nxt in edges[from_key]:
			if nxt == "WIN":
				winning[from_key] = true
			else:
				if not rev.has(nxt):
					rev[nxt] = []
				rev[nxt].append(from_key)
	var good := winning.duplicate()
	var gq: Array = winning.keys()
	var gi := 0
	while gi < gq.size():
		var cur = gq[gi]
		gi += 1
		for prev in rev.get(cur, []):
			if not good.has(prev):
				good[prev] = true
				gq.append(prev)
	var harm := 0
	var pairs := 0
	var demo := CaveModel.PLANK_DEMO
	var frontier := {}
	var live_mismatch := ""
	for state in states:
		var pos: Vector2i = state[0]
		var flips: Array = state[1]
		var key := _plank_key(pos, flips)
		_plank_apply(m, pos, flips)
		var live := m.plank_live()
		if live != good.has(key) and live_mismatch.is_empty():
			live_mismatch = key
		if good.has(key):
			for nxt in edges[key]:
				if nxt != "WIN" and not good.has(nxt):
					frontier[nxt] = true
		var alt: Array = []
		var has_demo := false
		for cell in flips:
			if cell == demo:
				has_demo = true
			else:
				alt.append(cell)
		if not has_demo:
			alt.append(demo)
		var alt_key := _plank_key(pos, alt)
		if seen.has(alt_key):
			pairs += 1
			if good.has(key) != good.has(alt_key):
				harm += 1
	t.assert_true(live_mismatch.is_empty(), "stuck means the remaining planks cannot be finished: %s" % live_mismatch)
	t.assert_eq(pairs, 204, "every demo on/off pair that can occur is checked")
	t.assert_eq(harm, 0, "the demo plank never changes whether the cave can be solved")
	t.assert_eq(frontier.size(), 14, "fourteen first wrong steps are dead")
	var walled := 0
	var open_trap := 0
	for key in frontier:
		var parts: PackedStringArray = String(key).split("|")
		var xy: PackedStringArray = parts[0].split(",")
		var pos := Vector2i(int(xy[0]), int(xy[1]))
		var flips: Array = []
		for i in range(1, parts.size()):
			if parts[i] == "":
				continue
			var pair: PackedStringArray = parts[i].split(":")
			flips.append(Vector2i(int(pair[0]), int(pair[1])))
		_plank_apply(m, pos, flips)
		t.assert_true(not m.plank_live(), "a frontier state is impossible to finish")
		if m.plank_can_move():
			open_trap += 1
		else:
			walled += 1
	t.assert_eq(walled, 6, "six first traps have no legal step")
	t.assert_eq(open_trap, 8, "eight first traps can still walk and are still dead")
	var straight := CaveModel.new()
	straight.load_room(3)
	route(t, straight, "UULUURUUU")
	t.assert_true(not straight.reached and not straight.plank_live() and straight.plank_can_move(), "running up the middle is a dead end that still has a step")
	var blocked := CaveModel.new()
	blocked.load_room(3)
	route(t, blocked, "UULUULUURL")
	t.assert_true(not blocked.plank_live() and not blocked.plank_can_move(), "backing onto the west stone leaves no step")
	var net := CaveNetwork.new()
	net.load_room(3)
	net.entry = CaveModel.PLANK_ENTRY
	route(t, net, "UULUUL")
	t.assert_true(net.undo() and net.plank_count() == 0, "network undo lowers one plank")
	route(t, net, "LUURRDDRRUULULU")
	t.assert_true(net.reached and not net.undo() and not net.reset_current(), "a solved plank cave is nailed and cannot be undone")
	t.assert_true(net.walkable(Vector2i(1, 4)) and net.walkable(net.goal), "nailed planks and the open gate can be walked")
	var fresh := CaveNetwork.new()
	fresh.load_room(3)
	fresh.entry = CaveModel.PLANK_ENTRY
	route(t, fresh, "UU")
	t.assert_true(fresh.planks_up.has(CaveModel.PLANK_DEMO), "stepping off the demo plank flips it")
	t.assert_true(fresh.reset_current() and fresh.planks_up.is_empty() and fresh.player == CaveModel.PLANK_ENTRY, "reset returns every plank to flat")

static func _play(c: MogaoChapter, text: String) -> void:
	for letter in text:
		var direction: Vector2i = {"U": Vector2i.UP, "D": Vector2i.DOWN, "L": Vector2i.LEFT, "R": Vector2i.RIGHT}[letter]
		c.move(direction)
		c._process(0.2)

static func _rewind(c: MogaoChapter) -> void:
	while c.model.history.size() > 0:
		c.undo()

static func plank_hints(t: Node) -> void:
	var c := MogaoChapter.new()
	t.add_child(c)
	c.model.load_room(3)
	c.model.entry = CaveModel.PLANK_ENTRY
	c.rebuild_cranks()
	_play(c, "U")
	t.assert_true("试板" in c.hint.text, "standing on the demo plank explains that it is safe")
	_play(c, "U")
	t.assert_true("试板不计数" in c.hint.text, "leaving the demo plank shows the safe flip")
	_rewind(c)
	_play(c, "UULUURUUU")
	t.assert_true(c.plank_stuck and c.plank_undo_flash and not c.undo_button.disabled, "a dead route flashes the undo button")
	t.assert_true("剩下的翻板连不成一条路了" in c.hint.text, "a trap with steps left says the route cannot be finished")
	var style := c.undo_button.get_theme_stylebox("normal")
	var got := "null"
	if style is StyleBoxFlat:
		got = str((style as StyleBoxFlat).bg_color)
	t.assert_true(style is StyleBoxFlat and (style as StyleBoxFlat).bg_color.r > 0.45, "the undo button turns gold while the route is dead (%s modulate %s)" % [got, c.undo_button.modulate])
	_rewind(c)
	_play(c, "UULUULUURL")
	t.assert_true("无路可走了" in c.hint.text, "a walled trap says there is no step")
	t.assert_true(c.plank_traps == 2, "each new dead step counts once")
	_rewind(c)
	_play(c, "UULUURUUU")
	t.assert_true("先绕左" in c.hint.text and not c.hint.text.contains("中间下"), "the third trap adds the first part of the rhyme")
	_rewind(c)
	_play(c, "UULUURUUU")
	_rewind(c)
	_play(c, "UULUURUUU")
	t.assert_true("先绕左，中间下，右边上" in c.hint.text, "the fifth trap gives the whole rhyme")
	c.free()

static func _front_at(node: Node, point: Vector2) -> Control:
	var found: Array = []
	_collect_hit(node, point, found)
	var best: Control = null
	var best_z := -999
	var best_i := -1
	for i in found.size():
		var item := found[i] as Control
		if best == null or item.z_index > best_z or (item.z_index == best_z and i > best_i):
			best = item
			best_z = item.z_index
			best_i = i
	return best

static func _collect_hit(node: Node, point: Vector2, into: Array) -> void:
	if not (node is Control):
		return
	var control := node as Control
	if not control.visible or control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	if not control.get_global_rect().has_point(point):
		return
	into.append(control)
	for child in control.get_children():
		_collect_hit(child, point, into)

static func reset_confirm(t: Node) -> void:
	var c := MogaoChapter.new()
	t.add_child(c)
	c.model.load_room(3)
	c.model.player = Vector2i(2, 4)
	c.model.destination = c.model.player
	c.model.entry = Vector2i(1, 2)
	c.model.planks_up[Vector2i(2, 4)] = true
	c.pause_game()
	c.modal_secondary()
	c._process(0.05)
	t.assert_eq(c.primary.text, "确认重置", "the reset card offers confirm")
	t.assert_eq(c.primary.action_mode, BaseButton.ACTION_MODE_BUTTON_PRESS, "confirm fires on press, not on a release that can miss")
	var hit := _front_at(c.overlay, c.primary.get_global_rect().get_center())
	t.assert_eq(hit, c.primary, "nothing covers the confirm-reset button")
	c.modal_primary()
	t.assert_eq(c.mode, "playing", "one confirm closes the reset card")
	t.assert_eq(c.model.player, CaveModel.PLANK_ENTRY, "reset returns to the entrance under the demo plank")
	t.assert_true(c.model.planks_up.is_empty(), "reset lays the planks flat")
	c.free()

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
	c.free()

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
	t.assert_eq(c.card_title.text, "镜窟 · 铜镜折光", "reopening the solved mirror cave shows the refraction note")
	t.assert_true(c.mirror_art.preview_layer.z_index > 0, "mirror preview still stacks above the mirror sprites")
	t.assert_true((c.overlay.get_parent() as CanvasLayer).layer > c.mirror_art.preview_layer.z_index, "popup layer is above the preview")
	c.show_card("finish", "走出莫高窟", "这次走了 6 步\n用时 6 分 14 秒", "前往三危山", "再看看洞窟")
	t.assert_true(c.overlay.visible and c.overlay.get_parent() is CanvasLayer, "settlement uses the same top layer")
	c.free()

static func run(t: Node) -> void:
	print("\n[TEST] Mogao three distinct cave mechanisms")
	shared_ear_doors(t)
	reset_confirm(t)
	cave_popup_layer(t)
	pressure_graph(t)
	plank_graph(t)
	plank_hints(t)
	var dark := CaveModel.new(); dark.load_room(4)
	route(t, dark, "RRU"); dark.turn(); dark.advance(1)
	t.assert_true(not dark.walkable(Vector2i(3, 4)), "aligned bridge still requires the lamp to reveal its safe path")
	dark.load_room(3); dark.planks_up[Vector2i(2, 4)] = true; dark.load_room(3)
	t.assert_true(dark.planks_up.is_empty() and dark.player == CaveModel.PLANK_ENTRY, "reset lays every plank flat at the entrance")
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
