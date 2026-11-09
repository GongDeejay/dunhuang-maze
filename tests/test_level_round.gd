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
	for diff in [["easy", 7], ["normal", 5], ["hard", 3]]:
		DataLoader.set_difficulty(diff[0])
		var healed := FirstJourney.new()
		var hp := _player()
		var amount := Branches.scaled_heal(FirstJourney.CARAVAN_HEAL)
		t.assert_eq(amount, diff[1], diff[0] + " caravan heal")
		healed.enter(FirstJourney.CARAVAN, maze, hp)
		t.assert_eq(hp.hp, 10 + diff[1], diff[0] + " heal applies immediately")
		healed.enter(FirstJourney.CARAVAN, maze, hp)
		t.assert_eq(hp.hp, 10 + diff[1], diff[0] + " caravan water is one-time")
		hp.free()
	DataLoader.set_difficulty("normal")
	var story := FirstJourney.new()
	var reader := _player()
	var note := story.enter(FirstJourney.STELE, maze, reader)
	t.assert_true(note.get("body", "").contains("莫高窟") and note.get("body", "").contains("哥哥") and note.get("body", "").contains("弟弟"), "stele foreshadows the next chapter")
	t.assert_eq(story.fragment_mask(), [false, false, true], "stele is fragment three")
	var camp := story.enter(FirstJourney.CAMP, maze, reader)
	t.assert_true(camp.get("body", "").contains("北边") and camp.get("body", "").contains("妈妈"), "camp gives a direction")
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
	t.assert_true(Beam.preview_allowed(CaveModel.MIRROR_DEFS[1]), "teaching mirror preview is on")
	t.assert_true(not Beam.preview_allowed(CaveModel.MIRROR_DEFS[0]), "other mirrors default preview off")
	var extra := {"id": "extra", "rotatable": true, "teaching": false, "show_preview": false}
	t.assert_true(not Beam.preview_allowed(extra), "a mirror can keep its own preview off")
	extra["show_preview"] = true
	t.assert_true(Beam.preview_allowed(extra), "each mirror's show_preview is an independent switch")


static func _mirror_room(t: Node) -> void:
	var blocked := CaveNetwork.new()
	blocked.load_room(CaveModel.MIRROR_ROOM)
	var dark: Dictionary = blocked.beam_trace()
	t.assert_true(dark["cells"].has(CaveModel.MIRROR_TURN_CELL), "a back-facing mirror still receives the beam")
	t.assert_true(not dark["cells"].has(Vector2i(5, 2)) and not dark["hit"], "the beam stops on the mirror back")
	t.assert_true(not blocked.walkable(Vector2i(6, 2)), "the north bridge stays closed until the front face is used")
	blocked.player = Vector2i(4, 3)
	blocked.destination = blocked.player
	blocked.mirror_rot = 3
	var shaded: Dictionary = blocked.beam_trace()
	t.assert_true(shaded["cells"].has(Vector2i(4, 3)) and not shaded["cells"].has(CaveModel.MIRROR_TURN_CELL), "a person standing in the beam blocks it")
	var solved := CaveNetwork.new()
	solved.load_room(CaveModel.MIRROR_ROOM)
	Puzzle.route(t, solved, "UURRRU")
	var previews: Array = solved.mirror_previews()
	t.assert_eq(previews.size(), 1, "only the teaching mirror previews")
	t.assert_eq(previews[0]["id"], "teaching", "preview belongs to the teaching mirror")
	t.assert_eq(CaveModel.distance(previews[0]["from"], previews[0]["to"]), 1, "preview is a single segment")
	t.assert_true(previews[0]["to"] != CaveModel.MIRROR_LOTUS, "preview does not draw the rest of the path")
	var before: Vector2i = previews[0]["to"]
	t.assert_true(solved.turn_mirror(), "adjacent crank turns the mirror")
	solved.advance(1)
	var lit: Dictionary = solved.beam_trace()
	var index: int = lit["cells"].find(CaveModel.MIRROR_TURN_CELL)
	t.assert_eq(lit["cells"][index + 1], before, "the preview segment becomes the solid beam")
	t.assert_true(lit["cells"].size() > index + 2 and lit["hit"], "the solid beam continues to the lotus")
	t.assert_eq(lit["cells"][lit["cells"].find(CaveModel.MIRROR_FIXED_CELL) + 1] - CaveModel.MIRROR_FIXED_CELL, Vector2i.RIGHT, "fixed mirror exits east, matching ne")
	t.assert_eq(lit["cells"][index + 1] - CaveModel.MIRROR_TURN_CELL, Vector2i.UP, "teaching mirror exits north, matching nw")
	t.assert_true(solved.mirror_previews().is_empty(), "the next turn would leave the front, so no reverse preview")
	var rot := solved.mirror_rot
	t.assert_true(solved.undo() and solved.mirror_rot != rot, "undo restores the mirror")
	solved.turn_mirror()
	solved.advance(1)
	Puzzle.route(t, solved, "UUULLL")
	t.assert_true(solved.reached and solved.lotus_lit() and not solved.undo(), "solved mirror cave cannot be undone into a trap")
	var best := _mirror_search(t)
	print("MEASURE mirror min_steps=%d" % best)
	t.assert_true(best > 0 and best <= 14, "mirror cave has a solution within 14 actions")
	var saved := CaveNetwork.new()
	saved.load_room(CaveModel.MIRROR_ROOM)
	saved.mirror_rot = 3
	saved.player = CaveModel.MIRROR_GOAL
	saved.destination = saved.player
	saved.reached = true
	var copy := CaveNetwork.new()
	copy.resume_network(CaveModel.MIRROR_ROOM, JSON.parse_string(JSON.stringify(saved.save_network())))
	t.assert_true(copy.room == CaveModel.MIRROR_ROOM and copy.mirror_rot == 3 and copy.reached and copy.lotus_lit(), "mirror state survives a version 2 save")


static func _mirror_search(t: Node) -> int:
	var queue: Array = [{"p": CaveModel.MIRROR_ENTRY, "r": CaveModel.MIRROR_START_ROT, "s": 0}]
	var seen := {_key(queue[0]["p"], queue[0]["r"]): true}
	var best := -1
	var cursor := 0
	while cursor < queue.size():
		var state: Dictionary = queue[cursor]
		cursor += 1
		if int(state["s"]) > 24:
			continue
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var step := _mirror_at(state)
			if not step.step(direction):
				continue
			step.advance(1)
			if step.reached:
				t.assert_true(step.lotus_lit(), "reaching the goal requires the lotus")
				var cost := int(state["s"]) + 1
				if best < 0 or cost < best:
					best = cost
				continue
			var key := _key(step.player, step.mirror_rot)
			if seen.has(key):
				continue
			seen[key] = true
			queue.append({"p": step.player, "r": step.mirror_rot, "s": int(state["s"]) + 1})
		var turn := _mirror_at(state)
		if turn.can_turn_mirror() and turn.turn_mirror():
			turn.advance(1)
			var turned := _key(turn.player, turn.mirror_rot)
			if not seen.has(turned):
				seen[turned] = true
				queue.append({"p": turn.player, "r": turn.mirror_rot, "s": int(state["s"]) + 1})
	t.assert_true(seen.has(_key(CaveModel.MIRROR_ENTRY, CaveModel.MIRROR_START_ROT)), "the entrance never gets sealed")
	return best


static func _mirror_at(state: Dictionary) -> CaveNetwork:
	var model := CaveNetwork.new()
	model.load_room(CaveModel.MIRROR_ROOM)
	model.player = state["p"]
	model.destination = state["p"]
	model.mirror_rot = state["r"]
	return model


static func _key(cell: Vector2i, rot: int) -> String:
	return "%d,%d,%d" % [cell.x, cell.y, rot]


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
