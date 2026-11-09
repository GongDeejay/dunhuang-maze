extends RefCounted

const Branches = preload("res://scripts/journey_branches.gd")
const Beam = preload("res://scripts/mogao_chapter/mirror_beam.gd")
const Painter = preload("res://scripts/mogao_chapter/mirror_painter.gd")
const Puzzle = preload("res://tests/test_cave_chapter.gd")
const DIR := {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}


static func run(t: Node) -> void:
	print("\n[TEST] Level round: branches, camp clue, single-faced mirror")
	_art(t)
	_silhouette_source(t)
	_branches(t)
	_rewards(t)
	_mirror_faces(t)
	_mirror_room(t)
	_input(t)
	DataLoader.set_difficulty("normal")


static func _art(t: Node) -> void:
	var expected := {
		"beacon": Vector2i(16, 32),
		"beacon_lit": Vector2i(16, 32),
		"stele": Vector2i(16, 16),
		"stele_read": Vector2i(16, 16),
		"caravan": Vector2i(32, 16),
		"caravan_searched": Vector2i(32, 16),
	}
	for key in expected:
		_image(t, AssetRegistry.landmark_path(key), expected[key])
	for key in ["bell", "fragment_1", "fragment_2", "fragment_3"]:
		_image(t, AssetRegistry.extra_item_path(key), Vector2i(16, 16))
	for facing in ["ne", "se", "sw", "nw"]:
		_image(t, AssetRegistry.mogao_sprite_path("mirror_" + facing), Vector2i(16, 16))
		_image(t, AssetRegistry.mogao_sprite_path("mirror_" + facing + "_lit"), Vector2i(16, 16))
	for direction in ["n", "e", "s", "w"]:
		_image(t, AssetRegistry.decal_path(direction), Vector2i(16, 16))
	_image(t, AssetRegistry.mogao_sprite_path("lotus_stand"), Vector2i(16, 16))
	_image(t, AssetRegistry.mogao_sprite_path("lotus_stand_lit"), Vector2i(16, 16))
	_image(t, AssetRegistry.fragment_sheet_path(), Vector2i(96, 64))
	_image(t, AssetRegistry.mother_silhouette_path(), Vector2i(16, 16))
	t.assert_eq(AssetRegistry.FRAGMENT_SHEET_REGIONS.size(), 3, "fragment sheet is three regions")
	t.assert_true(not Painter.DRAW_CODE_ARROW, "code arrow stays off; the texture already has one")


static func _image(t: Node, path: String, size: Vector2i) -> void:
	var image := Image.new()
	t.assert_eq(image.load(path), OK, path + " loads")
	t.assert_eq(Vector2i(image.get_width(), image.get_height()), size, path + " size")


static func _silhouette_source(t: Node) -> void:
	var dedicated := AssetRegistry.mother_silhouette_path()
	t.assert_eq(dedicated, "res://assets/sprites/landmark/mother_silhouette.png", "silhouette art has one registry path")
	t.assert_true(ResourceLoader.exists(dedicated), "dedicated silhouette is shipped")
	var live: Dictionary = AssetRegistry.family_silhouette_source()
	t.assert_eq(live.get("path", ""), dedicated, "shipped silhouette is used")
	t.assert_true(not bool(live.get("darken", true)), "shipped silhouette is not darkened")
	var fallback: Dictionary = AssetRegistry.family_silhouette_source(false)
	t.assert_eq(fallback.get("path", ""), AssetRegistry.character_sprite_path("le", false), "missing art falls back to le.png")
	t.assert_true(bool(fallback.get("darken", false)), "le fallback is darkened")
	t.assert_true(str(fallback.get("path", "")).ends_with("le.png"), "fallback is the pixel portrait, not a generic figure")
	var ready: Dictionary = AssetRegistry.family_silhouette_source(true)
	t.assert_eq(ready.get("path", ""), dedicated, "existing silhouette art is preferred")
	t.assert_true(not bool(ready.get("darken", true)), "dedicated silhouette is not recolored")
	t.assert_true(bool(ready.get("nearest", false)) and bool(live.get("nearest", false)) and bool(fallback.get("nearest", false)), "silhouette sources use nearest filtering")
	t.assert_eq(AssetRegistry.FAMILY_SILHOUETTE_SIZE, Vector2(0.64, 0.64), "silhouette occupies 64 percent of the cell")
	t.assert_eq(AssetRegistry.FAMILY_SILHOUETTE_TEX_PX, 16, "suggested silhouette texture is 16x16")


static func _branches(t: Node) -> void:
	for sample in range(24):
		seed(sample)
		var maze := MazeGenerator.new(FirstJourney.SIZE.x, FirstJourney.SIZE.y)
		var journey := FirstJourney.new()
		journey.build(maze)
		var reachable := maze.get_reachable_cells()
		t.assert_true(reachable.has(FirstJourney.BEACON) and reachable.has(FirstJourney.CARAVAN) and reachable.has(FirstJourney.STELE), "seed %d branches reachable" % sample)
		t.assert_true(reachable.has(FirstJourney.CAMP) and maze.has_wall(FirstJourney.FAMILY.x, FirstJourney.FAMILY.y, MazeGenerator.E), "seed %d camp stays open and the rescue gate stays shut" % sample)
		t.assert_eq(_steps(maze, Vector2i(9, 3), FirstJourney.BEACON), 5, "beacon branch length")
		t.assert_eq(_steps(maze, Vector2i(5, 11), FirstJourney.CARAVAN), 5, "caravan branch length")
		t.assert_eq(_steps(maze, Vector2i(9, 10), FirstJourney.STELE), 3, "stele branch length")
	seed(0)
	var maze := MazeGenerator.new(FirstJourney.SIZE.x, FirstJourney.SIZE.y)
	var journey := FirstJourney.new()
	journey.build(maze)
	var start_fork := _steps(maze, Vector2i.ZERO, FirstJourney.FORK)
	var short_join := _steps(maze, FirstJourney.FORK, FirstJourney.JOIN)
	var join_family := _steps(maze, FirstJourney.JOIN, FirstJourney.FAMILY)
	var family_camp := _steps(maze, FirstJourney.FAMILY, FirstJourney.CAMP)
	var start_family := _steps(maze, Vector2i.ZERO, FirstJourney.FAMILY)
	var start_camp := _steps(maze, Vector2i.ZERO, FirstJourney.CAMP)
	t.assert_eq(short_join, journey.short_route.size() - 1, "short corridor is still the shortest fork-to-join")
	t.assert_eq(start_family, start_fork + short_join + join_family, "side branches do not shorten the road to mother")
	var spine := PathGuide.bfs_path(maze, Vector2i.ZERO, FirstJourney.FAMILY)
	t.assert_true(not spine.has(FirstJourney.BEACON) and not spine.has(FirstJourney.CARAVAN) and not spine.has(FirstJourney.STELE), "shortest road to mother skips the branches")
	var player := _player()
	journey.rescue(maze, player)
	var family_camp_after := _steps(maze, FirstJourney.FAMILY, FirstJourney.CAMP)
	t.assert_true(family_camp_after < family_camp, "rescue shortcut is still shorter")
	t.assert_eq(family_camp_after, 10, "rescue return stays ten steps")
	var beacon := _steps(maze, Vector2i(9, 3), FirstJourney.BEACON)
	var caravan := _steps(maze, Vector2i(5, 11), FirstJourney.CARAVAN)
	var stele := _steps(maze, Vector2i(9, 10), FirstJourney.STELE)
	print("MEASURE first-journey steps: start_to_fork=%d fork_to_join_short=%d fork_to_join_safe=%d join_to_family=%d family_to_camp_before=%d family_to_camp_after=%d start_to_family=%d start_to_camp_before=%d clear_short=%d beacon_one_way=%d beacon_round=%d caravan_one_way=%d caravan_round=%d stele_one_way=%d stele_round=%d" % [
		start_fork, short_join, journey.safe_route.size() - 1, join_family, family_camp, family_camp_after, start_family, start_camp, start_family + family_camp_after, beacon, beacon * 2, caravan, caravan * 2, stele, stele * 2,
	])
	_footprints(t, maze, Vector2i(9, 3), FirstJourney.BEACON, "beacon")
	_footprints(t, maze, Vector2i(5, 11), FirstJourney.CARAVAN, "caravan")
	_footprints(t, maze, Vector2i(9, 10), FirstJourney.STELE, "stele")
	var low := Branches.footprint_alpha(0.0, true)
	var high := Branches.footprint_alpha(Branches.PULSE_PERIOD * 0.25, true)
	t.assert_true(low >= 0.7 and low <= 1.0 and high >= 0.7 and high <= 1.0, "footprint pulse stays dim")
	t.assert_true(absf(high - low) <= 0.3 and absf(high - low) > 0.05, "footprint pulse is a small breath")
	t.assert_eq(Branches.footprint_alpha(1.2, false), 1.0, "inner footprint cells do not pulse")
	t.assert_true(bool(maze.landmarks[FirstJourney.BEACON].get("discovered", false)), "beacon is visible through fog")
	t.assert_true(not bool(maze.landmarks[FirstJourney.STELE].get("discovered", false)), "stele is not a distant lure")
	player.free()


static func _footprints(t: Node, maze: MazeGenerator, entrance: Vector2i, goal: Vector2i, branch: String) -> void:
	var path := PathGuide.bfs_path(maze, entrance, goal)
	var marks: Array = []
	for spec in FirstJourney.FOOTPRINTS:
		if spec["branch"] == branch:
			marks.append(spec)
	t.assert_true(marks.size() >= 3 and marks.size() <= 4, branch + " footprints stay on the entrance")
	var pulsed := 0
	for spec in marks:
		var cell: Vector2i = spec["at"]
		var idx := path.find(cell)
		t.assert_true(idx >= 0 and idx <= 3, branch + " footprint is one of the first four cells")
		t.assert_true(cell != goal, branch + " reward cell has no footprint")
		t.assert_eq(maze.landmarks[cell].get("kind", ""), "footprint", "footprint landmark")
		if idx + 1 < path.size():
			t.assert_eq(cell + DIR[spec["dir"]], path[idx + 1], branch + " footprint faces forward")
		if spec["pulse"]:
			pulsed += 1
			t.assert_eq(cell, entrance, branch + " only the entrance pulses")
	t.assert_eq(pulsed, 1, branch + " has one pulsing entrance")


static func _rewards(t: Node) -> void:
	var maze := MazeGenerator.new(FirstJourney.SIZE.x, FirstJourney.SIZE.y)
	var journey := FirstJourney.new()
	journey.build(maze)
	var host := Node.new()
	t.add_child(host)
	var spawned: Dictionary = journey.spawn(host, func(_monster): pass)
	for item in spawned["items"]:
		t.assert_true(item.pos != FirstJourney.BEACON and item.pos != FirstJourney.CARAVAN and item.pos != FirstJourney.STELE, "branch rewards are not inventory pickups")
	host.free()
	var player := _player()
	var beacon := journey.enter(FirstJourney.BEACON, maze, player)
	t.assert_true(beacon.get("body", "").contains("妈妈的驼铃"), "beacon gives mother's bell")
	t.assert_eq(player.reveal_bonus, 1, "beacon grants one vision")
	t.assert_eq(journey.silhouette_time, FirstJourney.SILHOUETTE_SECONDS, "silhouette lasts three seconds")
	t.assert_true(bool(maze.landmarks[FirstJourney.FAMILY].get("silhouette", false)), "family silhouette is armed")
	t.assert_true(maze.charted_route.is_empty(), "silhouette does not draw a route")
	journey.tick_silhouette(3.1, maze)
	t.assert_eq(journey.silhouette_time, 0.0, "silhouette expires")
	t.assert_true(not bool(maze.landmarks[FirstJourney.FAMILY].get("silhouette", false)), "silhouette hides again")
	t.assert_true(maze.charted_route.is_empty(), "expired silhouette still draws no route")
	journey.enter(FirstJourney.BEACON, maze, player)
	t.assert_eq(player.reveal_bonus, 1, "beacon reward is one-time")
	journey.enter(FirstJourney.MURAL, maze, player)
	t.assert_eq(player.reveal_bonus, 2, "mural and beacon stack to the cap")
	t.assert_eq(journey.journey_vision, 2, "journey vision cap is two")
	var again := FirstJourney.new()
	again.build(maze)
	var capped := _player()
	again.enter(FirstJourney.MURAL, maze, capped)
	again.enter(FirstJourney.BEACON, maze, capped)
	t.assert_eq(capped.reveal_bonus, 2, "cap holds whichever reward comes second")
	capped.free()
	for diff in [["easy", 9], ["normal", 6], ["hard", 3]]:
		DataLoader.set_difficulty(diff[0])
		var healed := FirstJourney.new()
		var hp := _player()
		var amount := Branches.scaled_heal(FirstJourney.WATER_SKIN_HEAL)
		t.assert_eq(amount, diff[1], diff[0] + " water skin amount")
		var before := hp.hp
		healed.enter(FirstJourney.CARAVAN, maze, hp)
		t.assert_eq(hp.hp, before, diff[0] + " picking up the skin does not heal")
		t.assert_eq(healed.water_skin, 1, diff[0] + " water skin is carried")
		healed.enter(FirstJourney.CARAVAN, maze, hp)
		t.assert_eq(healed.water_skin, 1, diff[0] + " caravan skin is one-time")
		hp.free()
	DataLoader.set_difficulty("normal")
	var story := FirstJourney.new()
	var reader := _player()
	var note := story.enter(FirstJourney.STELE, maze, reader)
	t.assert_true(note.get("body", "").contains("九色鹿") and note.get("body", "").contains("哥哥") and note.get("body", "").contains("弟弟"), "stele foreshadows the deer and both children")
	t.assert_true(not note.get("body", "").contains("孩子们往莫高窟"), "stele no longer repeats the rescue line")
	t.assert_eq(story.fragment_mask(), [false, false, true], "stele is fragment three")
	var camp := story.enter(FirstJourney.CAMP, maze, reader)
	t.assert_true(camp.get("body", "").contains("过了石门往北") and camp.get("body", "").contains("妈妈"), "camp still points north past the gate")
	t.assert_eq(camp.get("button", ""), "去北边找妈妈", "camp button stays a fallback hint")
	t.assert_true(not story.rescued and _steps(maze, Vector2i.ZERO, FirstJourney.CAMP) > 0, "camp clue does not close the road")
	t.assert_true(story.enter(FirstJourney.CAMP, maze, reader).is_empty(), "camp clue is one-time")
	story.fragments[1] = true
	story.fragments[2] = true
	story.mural_found = true
	story.caravan_found = true
	story.stele_found = true
	t.assert_true(story.discovery_line().contains("妈妈说"), "three fragments add mother's line")
	reader.free()
	player.free()


static func _mirror_faces(t: Node) -> void:
	t.assert_eq(Beam.reflect(Vector2i.DOWN, 0), Vector2i.RIGHT, "ne reflects north to east")
	t.assert_eq(Beam.reflect(Vector2i.LEFT, 0), Vector2i.ZERO, "ne blocks the bright-face reverse from the east")
	t.assert_eq(Beam.reflect(Vector2i.UP, 0), Vector2i.ZERO, "ne blocks the south back")
	t.assert_eq(Beam.reflect(Vector2i.RIGHT, 0), Vector2i.ZERO, "ne blocks the west back")
	t.assert_eq(Beam.reflect(Vector2i.LEFT, 1), Vector2i.DOWN, "se reflects east to south")
	t.assert_eq(Beam.reflect(Vector2i.UP, 1), Vector2i.ZERO, "se blocks other directions")
	t.assert_eq(Beam.reflect(Vector2i.UP, 2), Vector2i.LEFT, "sw reflects south to west")
	t.assert_eq(Beam.reflect(Vector2i.RIGHT, 2), Vector2i.ZERO, "sw blocks a west-coming beam")
	t.assert_eq(Beam.reflect(Vector2i.RIGHT, 3), Vector2i.UP, "nw reflects west to north")
	t.assert_eq(Beam.reflect(Vector2i.DOWN, 3), Vector2i.ZERO, "nw blocks the bright-face reverse from the north")
	t.assert_true(Beam.preview_allowed(CaveModel.MIRROR_DEFS[0]), "teaching mirror preview is on")
	t.assert_true(not Beam.preview_allowed(CaveModel.MIRROR_DEFS[1]), "rotatable A keeps preview off")
	t.assert_true(not Beam.preview_allowed(CaveModel.MIRROR_DEFS[2]), "fixed mirror keeps preview off")
	t.assert_true(not Beam.preview_allowed(CaveModel.MIRROR_DEFS[3]), "rotatable B keeps preview off")
	var extra := {"id": "extra", "rotatable": true, "teaching": false, "show_preview": false}
	t.assert_true(not Beam.preview_allowed(extra), "a mirror can keep its own preview off")
	extra["show_preview"] = true
	t.assert_true(Beam.preview_allowed(extra), "each mirror's show_preview is an independent switch")


static func _mirror_room(t: Node) -> void:
	var blocked := CaveNetwork.new()
	blocked.load_room(CaveModel.MIRROR_ROOM)
	var dark: Dictionary = blocked.beam_trace()
	t.assert_eq(str(dark["stop_kind"]), "back", "teaching mirror starts with its back to the lamp")
	t.assert_eq(dark["stop_cell"], Vector2i(5, 7), "the opening beam stops on the teaching mirror")
	t.assert_true(not dark["hit"], "the lotus stays dark until every mirror faces the beam")
	var solved := CaveNetwork.new()
	solved.load_room(CaveModel.MIRROR_ROOM)
	var previews: Array = solved.mirror_previews()
	t.assert_eq(previews.size(), 1, "only the teaching mirror previews")
	t.assert_eq(str(previews[0]["id"]), "T", "preview belongs to the teaching mirror")
	t.assert_eq(int(previews[0]["k"]), 2, "the teaching preview asks for two turns")
	var pits := 0
	for cell in dark["cells"]:
		if _beam_fixture(cell):
			continue
		pits += 1
		t.assert_true(not blocked.land.has(cell), "the opening beam stays off the floor at %s" % cell)
	t.assert_true(pits > 0, "the opening beam crosses a dark pit")
	var only_b := CaveNetwork.new()
	only_b.load_room(CaveModel.MIRROR_ROOM)
	only_b.mirror_rots["B"] = 0
	t.assert_true(not only_b.lotus_lit(), "turning only B leaves the beam on an earlier mirror")
	t.assert_true(CaveModel.distance(previews[0]["from"], previews[0]["to"]) >= 1, "preview leaves the mirror edge")
	_solve_mirrors(t, solved)
	t.assert_true(solved.lotus_lit() and solved.mirror_previews().is_empty(), "a solved teaching mirror hides the preview")
	t.assert_true(solved.reached and not solved.undo(), "solved mirror cave cannot be undone into a trap")
	var search := _mirror_search(t)
	print("MEASURE mirror min_actions=%d min_turns=%d" % [search["actions"], search["turns"]])
	t.assert_eq(search["turns"], 6, "the official layout needs six mirror turns")
	t.assert_eq(search["actions"], 34, "bfs finds the 34-action solution")
	t.assert_eq(search["solutions"], 1, "only one facing triple lights the lotus")
	var saved := CaveNetwork.new()
	saved.load_room(CaveModel.MIRROR_ROOM)
	saved.mirror_rots = CaveModel.solution_rots()
	saved.player = CaveModel.MIRROR_GOAL
	saved.destination = saved.player
	saved.reached = true
	var copy := CaveNetwork.new()
	copy.resume_network(CaveModel.MIRROR_ROOM, JSON.parse_string(JSON.stringify(saved.save_network())))
	t.assert_true(copy.room == CaveModel.MIRROR_ROOM and copy.reached and copy.lotus_lit(), "mirror state survives a version 3 save")
	var legacy := CaveNetwork.new()
	legacy.resume_network(CaveModel.MIRROR_ROOM, {"version": 2, "rooms": {"7": {"mirror_rot": 2, "reached": true, "player": [3, 0]}}, "entry": [3, 8]})
	t.assert_true(legacy.reached and legacy.lotus_lit(), "a solved version 2 save migrates onto the solution facings")


static func _solve_mirrors(t: Node, model: CaveNetwork) -> void:
	Puzzle.route(t, model, "RR")
	t.assert_true(model.turn_mirror(), "south of the teaching mirror can turn it")
	model.advance(1)
	t.assert_true(model.turn_mirror(), "the teaching mirror turns a second time")
	model.advance(1)
	Puzzle.route(t, model, "RUUUUUU")
	t.assert_true(model.turn_mirror(), "A turns from the east wall")
	model.advance(1)
	t.assert_true(model.turn_mirror(), "A turns a second time")
	model.advance(1)
	t.assert_true(model.turn_mirror(), "A turns a third time")
	model.advance(1)
	Puzzle.route(t, model, "ULLLLLLDDDD")
	t.assert_true(model.turn_mirror(), "B turns from the west wall")
	model.advance(1)
	Puzzle.route(t, model, "UUUURRRU")


static func _mirror_search(t: Node) -> Dictionary:
	var start := "%d,%d,%d" % [_def_rot("T", "start_rot"), _def_rot("A", "start_rot"), _def_rot("B", "start_rot")]
	var queue: Array = [{"p": CaveModel.MIRROR_ENTRY, "r": start, "s": 0, "turns": 0}]
	var seen := {"%s|%s" % [CaveModel.MIRROR_ENTRY, start]: true}
	var best_actions := -1
	var best_turns := -1
	var lit := 0
	var cursor := 0
	while cursor < queue.size():
		var state: Dictionary = queue[cursor]
		cursor += 1
		if best_actions >= 0 and int(state["s"]) > best_actions:
			continue
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var step := _mirror_at(state)
			if not step.step(direction):
				continue
			step.advance(1)
			if step.reached:
				t.assert_true(step.lotus_lit(), "reaching the goal requires the lotus")
				var cost := int(state["s"]) + 1
				if best_actions < 0 or cost < best_actions:
					best_actions = cost
					best_turns = int(state["turns"])
				continue
			var key := "%s|%s" % [step.player, _rot_key(step)]
			if seen.has(key):
				continue
			seen[key] = true
			queue.append({"p": step.player, "r": _rot_key(step), "s": int(state["s"]) + 1, "turns": int(state["turns"])})
		var turn := _mirror_at(state)
		if turn.can_turn_mirror() and turn.turn_mirror():
			turn.advance(1)
			var turned := "%s|%s" % [turn.player, _rot_key(turn)]
			if not seen.has(turned):
				seen[turned] = true
				queue.append({"p": turn.player, "r": _rot_key(turn), "s": int(state["s"]) + 1, "turns": int(state["turns"]) + 1})
	for ta in range(4):
		for aa in range(4):
			for ba in range(4):
				var probe := CaveNetwork.new()
				probe.load_room(CaveModel.MIRROR_ROOM)
				probe.mirror_rots = {"T": ta, "A": aa, "F": 1, "B": ba}
				if probe.lotus_lit():
					lit += 1
	t.assert_true(seen.has("%s|%s" % [CaveModel.MIRROR_ENTRY, start]), "the entrance never gets sealed")
	return {"actions": best_actions, "turns": best_turns, "solutions": lit}


static func _mirror_at(state: Dictionary) -> CaveNetwork:
	var model := CaveNetwork.new()
	model.load_room(CaveModel.MIRROR_ROOM)
	model.player = state["p"]
	model.destination = state["p"]
	var parts: PackedStringArray = str(state["r"]).split(",")
	model.mirror_rots = {"T": int(parts[0]), "A": int(parts[1]), "F": 1, "B": int(parts[2])}
	return model


static func _def_rot(id: String, field: String) -> int:
	for mirror in CaveModel.MIRROR_DEFS:
		if str(mirror["id"]) == id:
			return int(mirror[field])
	return 0


static func _beam_fixture(cell: Vector2i) -> bool:
	if cell == CaveModel.MIRROR_LAMP or cell == CaveModel.MIRROR_LOTUS:
		return true
	for mirror in CaveModel.MIRROR_DEFS:
		if mirror["cell"] == cell:
			return true
	return false


static func _rot_key(model: CaveNetwork) -> String:
	return "%d,%d,%d" % [model.mirror_rot_of("T"), model.mirror_rot_of("A"), model.mirror_rot_of("B")]


static func _input(t: Node) -> void:
	var handler := InputHandler.new()
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	t.assert_eq(handler.handle_feature(event, {"mirror_cave": true}).type, GameAction.Type.INTERACT, "mirror interact goes through InputHandler")
	t.assert_eq(handler.handle(event, {}).type, GameAction.Type.USE_ITEM, "main game still treats E as an item")
	t.assert_eq(handler.handle_feature(event, {}).type, GameAction.Type.NONE, "mirror interact stays inside the mirror cave")


static func _player() -> PlayerController:
	var player := PlayerController.new()
	player.max_hp = 30
	player.hp = 10
	player.reveal_bonus = 0
	return player


static func _steps(maze: MazeGenerator, from: Vector2i, to: Vector2i) -> int:
	var path := PathGuide.bfs_path(maze, from, to)
	return path.size() - 1 if not path.is_empty() else -1
