extends RefCounted
const Puzzle = preload("res://tests/test_cave_chapter.gd")
static func walk(t: Node, m: CaveNetwork, path: String) -> void:
	Puzzle.route(t, m, path)

static func reload(m: CaveNetwork) -> CaveNetwork:
	var copy := CaveNetwork.new()
	copy.resume_network(m.room, JSON.parse_string(JSON.stringify(m.save_network())))
	return copy

static func entrance(t: Node) -> CaveNetwork:
	var m := CaveNetwork.new()
	walk(t, m, "U"); m.turn(); m.advance(1); walk(t, m, "UUUUU")
	t.assert_true(m.travel() and m.room == 5, "entrance opens into shared hub")
	return m

static func run(t: Node) -> void:
	print("\n[TEST] six-cave connected graph and persistent state")
	var m := entrance(t)
	walk(t, m, "UUUUU")
	t.assert_true(not m.travel() and not m.shortcut, "hub cannot open back-side shortcut")
	var away := CaveNetwork.new()
	away.load_room(5)
	away.player = Vector2i(3, 5)
	t.assert_true(away.player != CaveModel.MIRROR_MAP_CELL, "standing in the hub is not standing on the cave map")
	away.player = CaveModel.MIRROR_MAP_CELL
	t.assert_eq(away.player, Vector2i(3, 1), "the cave map plaque is cell (3, 1)")
	walk(t, m, "DD")
	t.assert_true(m.reveal_secret() and m.secret, "optional common node can be discovered without story prerequisite")
	m = reload(m)
	t.assert_true(m.secret and m.player == Vector2i(3, 2), "secret and position survive JSON save")
	walk(t, m, "DLLL"); t.assert_true(m.travel() and m.room == 1, "left doorway enters shared ears")
	walk(t, m, "LLUUR")
	var box := m.box
	walk(t, m, "DRD"); t.assert_true(m.travel() and m.room == 5, "unsolved cave can be abandoned safely")
	t.assert_true(m.travel() and m.room == 1 and m.box == box, "reentering keeps unsolved crate state")
	t.assert_true(m.reset_current() and m.box == Vector2i(2, 4), "local reset affects only unsolved current room")
	walk(t, m, "LLUURDRULUURUU")
	t.assert_true(m.reached and not m.undo() and not m.reset_current(), "solved room is stable and cannot be reset accidentally")
	t.assert_true(m.travel() and m.room == 3, "left path reaches the plank cave")
	walk(t, m, "UULUUL"); t.assert_true(m.undo() and m.plank_count() == 0, "unfinished plank cave can still undo one flip")
	walk(t, m, "LUURRDDRRUULULU")
	t.assert_true(m.reached and m.plank_count() == 11, "plank cave completes normally in network")
	walk(t, m, "DDLL")
	t.assert_true(m.travel() and m.room == 5 and m.shortcut, "opening rear door creates physical loop back to hub")
	m = reload(m)
	t.assert_true(m.shortcut and m.secret and m.solved(1) and m.solved(3), "solved rooms and shortcut persist across reload")
	t.assert_true(m.travel() and m.room == 3 and m.reached and m.walkable(Vector2i(4, 1)), "shortcut returns to the nailed plank cave")
	walk(t, m, "RRUU"); t.assert_true(m.travel() and m.room == 2, "left route independently reaches deer")
	t.assert_true(not m.solved(4), "right route not required for left route completion")
	t.assert_true(m.travel() and m.room == 3, "deep cave can backtrack to arrived route")
	walk(t, m, "DDLL"); m.travel()
	walk(t, m, "DDDRRR"); t.assert_true(m.travel() and m.room == 4, "optional right route remains accessible after left completion")
	# A separate run proves the shorter right route needs neither rabbit secret nor left rooms.
	m = entrance(t)
	walk(t, m, "RRUUR"); m.travel()
	t.assert_eq(m.room, 4, "right hub door enters lamp bridge")
	m.use_lamp(); m.advance(1); walk(t, m, "LLU"); m.use_lamp(); m.advance(1)
	walk(t, m, "RRRR"); m.turn(); m.advance(1); 	walk(t, m, "LLUUUUUU")
	t.assert_true(m.reached and m.travel() and m.room == CaveModel.MIRROR_ROOM, "right route enters the mirror cave")
	t.assert_eq(m.player, Vector2i(4, 8), "mirror cave entry is one cell right of the door")
	walk(t, m, "R")
	for _i in CaveModel.turns_from_start("T"):
		t.assert_true(m.turn_mirror(), "teaching mirror turns from the south")
		m.advance(1)
	walk(t, m, "RUUUUUU")
	for _i in CaveModel.turns_from_start("A"):
		t.assert_true(m.turn_mirror(), "mirror A turns from the east")
		m.advance(1)
	walk(t, m, "ULLLLLLDDDD")
	for _i in CaveModel.turns_from_start("B"):
		t.assert_true(m.turn_mirror(), "mirror B turns from the west")
		m.advance(1)
	t.assert_true(m.lotus_lit(), "the second segment lights the lotus")
	walk(t, m, "UUUURRRU")
	t.assert_true(m.reached and m.travel() and m.room == 2, "mirror cave leads to deer")
	t.assert_true(not m.solved(1) and not m.solved(3) and not m.secret, "no all-room or secret completion gate")
	m = reload(m)
	t.assert_true(m.room == 2 and m.travel() and m.room == CaveModel.MIRROR_ROOM and m.reached, "deer returns into the solved mirror cave")
	walk(t, m, "DLLLDDDDDUUUUURRRRRRDDDDDDDLLL")
	t.assert_true(m.travel() and m.room == 4 and m.lit() and m.bridges[0].pose == 1, "return retains light and bridge alignment")
	walk(t, m, "DDDDDDD"); m.travel()
	t.assert_true(m.room == 5, "solved lamp bridge remains physically traversable back to hub")
	var legacy := CaveNetwork.new(); legacy.resume_network(4, {})
	t.assert_true(legacy.room == 4 and legacy.solved(0) and legacy.solved(1) and legacy.solved(3), "old linear save migrates completed rooms for safe backtracking")
	legacy.resume_network(3, {})
	t.assert_true(legacy.travel() and legacy.room == 1 and legacy.gate_open(), "legacy relay checkpoint can return to solved rabbit far bank")
	walk(t, legacy, "DDLDDDRD")
	t.assert_true(legacy.travel() and legacy.room == 5, "legacy save cannot become trapped behind reset pressure doors")
	legacy.resume_network(99, {"version": 1})
	t.assert_eq(legacy.room, 0, "invalid room and empty network safely use entrance")
	west_shortcut(t)
	solved_return(t)

static func door_at(m: CaveNetwork, cell: Vector2i) -> Dictionary:
	for d in m.doors():
		if d.cell == cell:
			return d
	return {}

static func west_shortcut(t: Node) -> void:
	var locked := CaveNetwork.new()
	locked.load_room(3)
	t.assert_true(not door_at(locked, CaveModel.PLANK_WEST).open, "the west door stays locked before the rope opens")
	t.assert_true("从栈道窟西侧开启" in locked.map_note(), "the map keeps the lock note before the cave is solved")
	locked.remember_room()
	locked.load_room(5)
	locked.player = Vector2i(3, 0)
	locked.destination = locked.player
	t.assert_true(not door_at(locked, Vector2i(3, 0)).open, "the hub side stays locked before the plank cave is solved")
	var solved := CaveNetwork.new()
	solved.load_room(3)
	walk(t, solved, "UULUULUURRDDRRUULULU")
	t.assert_true(solved.reached and not solved.shortcut, "solving does not require walking the shortcut first")
	t.assert_true(door_at(solved, CaveModel.PLANK_WEST).open, "the west door opens together with the rope gate")
	t.assert_true(solved.map_note().contains("栈道捷径：已通") and not solved.map_note().contains("从栈道窟西侧开启"), "the map lock note disappears once the cave is solved")
	var saved := solved.save_network()
	t.assert_eq(int(saved["version"]), 4, "the solved plank cave is stored as version 4")
	var hub := CaveNetwork.new()
	hub.resume_network(5, saved)
	hub.player = Vector2i(3, 0)
	hub.destination = hub.player
	t.assert_true(door_at(hub, Vector2i(3, 0)).open, "a reloaded version 4 save opens the hub side of the shortcut")
	t.assert_true(hub.travel() and hub.room == 3 and hub.reached, "the hub side can enter the solved plank cave")
	hub.player = CaveModel.PLANK_WEST
	hub.destination = hub.player
	t.assert_true(door_at(hub, CaveModel.PLANK_WEST).open and hub.travel() and hub.room == 5, "the west side can return to the hub")

static func _open_gate_frame(sprite: Sprite2D) -> bool:
	return sprite.visible and sprite.texture is AtlasTexture and int((sprite.texture as AtlasTexture).region.position.x) == 16

static func solved_return(t: Node) -> void:
	var drifted := CaveNetwork.new()
	drifted.load_room(3)
	drifted.entry = Vector2i(1, 2)
	drifted.player = Vector2i(2, 4)
	drifted.planks_up[Vector2i(2, 4)] = true
	t.assert_true(drifted.reset_current(), "an unsolved plank cave can reset")
	t.assert_eq(drifted.player, CaveModel.PLANK_ENTRY, "reset ignores the shortcut spawn and returns to E")
	t.assert_true(drifted.planks_up.is_empty(), "reset flattens every plank")
	walk(t, drifted, "UULUULUURRDDRRUULULU")
	t.assert_true(drifted.reached and drifted.moves == 20, "the same 20-step route still solves from E")
	var c := MogaoChapter.new()
	t.add_child(c)
	c.model.load_room(3)
	c.rebuild_cranks()
	c.plank_art._process(0)
	t.assert_true(not c.plank_art.side_gate.visible, "a locked side door does not use the open rope gate")
	walk(t, c.model, "UULUULUURRDDRRUULULU")
	c.refresh()
	t.assert_eq(c.objective.text, "栈道钉牢了 · 11/11", "solving pins the progress line")
	c.plank_art._process(0)
	t.assert_true(_open_gate_frame(c.plank_art.side_gate), "the solved west door uses the open rope-gate frame")
	c.model.player = CaveModel.PLANK_WEST
	c.model.destination = c.model.player
	t.assert_true(c.model.travel() and c.model.room == 5, "the west door still leads back to the hub")
	c.model.player = Vector2i(3, 0)
	c.model.destination = c.model.player
	c.plank_art._process(0)
	t.assert_true(door_at(c.model, Vector2i(3, 0)).open and _open_gate_frame(c.plank_art.side_gate), "the hub arch uses the same open frame")
	t.assert_true(c.model.travel() and c.model.room == 3 and c.model.reached, "the shortcut returns into the solved cave")
	t.assert_eq(c.model.plank_count(), 0, "returning does not rebuild a flip count")
	c.refresh()
	t.assert_eq(c.objective.text, "栈道钉牢了 · 11/11", "the saved solved flag keeps 11/11")
	var again := CaveNetwork.new()
	again.resume_network(3, c.model.save_network())
	t.assert_true(again.reached and again.player == CaveModel.PLANK_WEST, "a version 4 save restores the open shortcut")
	c.model = again
	c.plank_art.host = c
	c.rebuild_cranks()
	c.refresh()
	c.plank_art._process(0)
	t.assert_eq(c.objective.text, "栈道钉牢了 · 11/11", "loading the save does not recount the boards")
	t.assert_true(_open_gate_frame(c.plank_art.side_gate), "loading the save still draws the open side gate")
	c.free()
	var old_room := {"player": [0, 0], "box": [2, 6], "latch": true, "reached": false, "moves": 4}
	var old := {"version": 3, "shortcut": false, "secret": false, "entry": [0, 0], "rooms": {"3": old_room}}
	var migrated := CaveNetwork.new()
	migrated.resume_network(3, old)
	t.assert_eq(migrated.room, 3, "a version 3 save still opens room 3")
	t.assert_true(not migrated.reached and migrated.plank_count() == 0 and migrated.box == Vector2i(-9, -9), "an unsolved borrowed-corridor save drops the crate and the latch")
	t.assert_eq(migrated.player, CaveModel.PLANK_ENTRY, "an unwalkable old position returns to the plank entrance")
	t.assert_true(migrated.step(Vector2i.UP), "the migrated room can be played under the plank rules")
	old_room["player"] = [2, 6]
	old["entry"] = [3, 8]
	migrated.resume_network(3, old)
	t.assert_eq(migrated.player, Vector2i(2, 6), "a still-walkable old position is kept")
	old_room["reached"] = true
	old_room["player"] = [3, 0]
	old_room["box"] = [5, 2]
	old_room["latch"] = true
	migrated.resume_network(3, old)
	t.assert_true(migrated.reached and migrated.walkable(Vector2i(2, 2)) and migrated.box == Vector2i(-9, -9), "a solved old room 3 is nailed and ignores the crate")
	var roundtrip := CaveNetwork.new()
	roundtrip.load_room(3)
	walk(t, roundtrip, "UULUU")
	var copy := reload(roundtrip)
	t.assert_eq(copy.save_network()["version"], 4, "plank saves use version 4")
	t.assert_eq(copy.player, roundtrip.player, "plank position survives a save")
	t.assert_eq(copy.plank_count(), roundtrip.plank_count(), "flipped planks survive a save")
	t.assert_true(copy.planks_up.has(CaveModel.PLANK_DEMO), "the demo plank survives a save")
