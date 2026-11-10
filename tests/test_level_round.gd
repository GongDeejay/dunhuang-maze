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
	_one_mirror_label(t)
	_mirror_exit_to_deer(t)
	_ui_exit_every_cave(t)
	_settlement_enters_third(t)
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
	t.assert_eq(str(beacon.get("kind", "")), "hint", "beacon does not open a card")
	t.assert_eq(str(beacon.get("body", "")), JourneyBranches.BEACON_HINT, "beacon hint names the roadbook and minimap")
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
	for rot in 4:
		var incoming := _reflect_entry(rot)
		var outgoing: Vector2i = Beam.reflect(incoming, rot)
		var expected := Vector2(-incoming.x, -incoming.y) + Vector2(outgoing)
		var facing := Beam.facing(rot)
		for suffix in ["", "_lit"]:
			var offset := _arrow_offset("mirror_" + facing + suffix)
			t.assert_true(offset.dot(expected) > 2.0, "%s%s arrow follows the beam" % [facing, suffix])
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
	t.assert_eq(dark["stop_cell"], _def_cell("T"), "the opening beam stops on the teaching mirror")
	blocked.mirror_rots["T"] = _def_rot("T", "solution_rot")
	var at_a: Dictionary = MirrorBeam.trace(blocked.mirror_cfg(), 0, Vector2i(-999, -999))
	t.assert_eq(str(at_a["stop_kind"]), "back", "A starts with its back to the beam")
	t.assert_eq(at_a["stop_cell"], _def_cell("A"), "the beam next stops on A")
	blocked.mirror_rots["A"] = _def_rot("A", "solution_rot")
	var at_b: Dictionary = MirrorBeam.trace(blocked.mirror_cfg(), 0, Vector2i(-999, -999))
	t.assert_eq(str(at_b["stop_kind"]), "reverse", "B starts with the gold face against the arrow")
	t.assert_eq(at_b["stop_cell"], _def_cell("B"), "the beam then stops on B")
	t.assert_true(not dark["hit"], "the lotus stays dark until every mirror faces the beam")
	var solved := CaveNetwork.new()
	solved.load_room(CaveModel.MIRROR_ROOM)
	var previews: Array = solved.mirror_previews()
	t.assert_eq(previews.size(), 1, "only the teaching mirror previews")
	t.assert_eq(str(previews[0]["id"]), "T", "preview belongs to the teaching mirror")
	t.assert_eq(int(previews[0]["k"]), CaveModel.turns_from_start("T"), "the teaching preview counts the remaining turns")
	t.assert_eq(previews[0]["from"], _def_cell("T"), "the preview label follows the teaching mirror")
	var struck: Dictionary = Painter.struck_turn(solved)
	t.assert_true(struck.get("ok", false), "the lit mirror carries the turn count")
	t.assert_eq(struck["from"], _def_cell("T"), "the opening label sits on teaching mirror T")
	t.assert_eq("这面镜还要转%d下" % int(struck["k"]), "这面镜还要转%d下" % CaveModel.turns_from_start("T"), "the label names the remaining turns")
	solved.mirror_rots["T"] = _def_rot("T", "solution_rot")
	var next_struck: Dictionary = Painter.struck_turn(solved)
	t.assert_eq(next_struck.get("from", Vector2i.ZERO), _def_cell("A"), "the label moves when the light reaches A")
	solved.mirror_rots["T"] = _def_rot("T", "start_rot")
	_mirror_stall(t)
	_preview_label_clears_mirror(t, previews[0])
	t.assert_eq(blocked.player, CaveModel.MIRROR_ENTRY, "the mirror cave starts on the entry cell")
	t.assert_eq(CaveModel.MIRROR_ENTRY, Vector2i(4, 8), "entry moved one cell right of the door")
	t.assert_true(blocked.walkable(CaveModel.MIRROR_ENTRY), "the entry cell can be stood on")
	t.assert_true(not dark["cells"].has(CaveModel.MIRROR_ENTRY), "the entry cell is not on the opening beam")
	var lamp := CaveNetwork.new()
	lamp.load_room(4)
	lamp.reached = true
	var mirror_spawn := Vector2i(-1, -1)
	for door in lamp.doors():
		if int(door["target"]) == CaveModel.MIRROR_ROOM:
			mirror_spawn = door["spawn"]
	t.assert_eq(mirror_spawn, CaveModel.MIRROR_ENTRY, "walking in from the lamp cave uses the same entry")
	var on_beam := CaveNetwork.new()
	on_beam.load_room(CaveModel.MIRROR_ROOM)
	on_beam.player = Vector2i(3, 7)
	on_beam.destination = on_beam.player
	var clear_beam: Dictionary = MirrorBeam.trace(on_beam.mirror_cfg(), 0, Vector2i(-999, -999))
	var player_beam: Dictionary = MirrorBeam.trace(on_beam.mirror_cfg(), 0, on_beam.player)
	t.assert_eq(clear_beam["stop_cell"], Vector2i(5, 7), "without a blocker the opening beam reaches the teaching mirror")
	t.assert_true(player_beam["stop_cell"] != Vector2i(5, 7), "a player on the beam would stop a blocked trace")
	t.assert_eq(on_beam.mirror_previews().size(), 1, "the dashed preview ignores the player")
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
	t.assert_true(int(search["actions"]) > 0, "the mirror cave has a solution")
	t.assert_eq(int(search["actions"]), 33, "the recommended openings take 33 actions from the shifted entry")
	t.assert_true(int(search["turns"]) >= 6, "the mirror cave takes at least six turns")
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


static func _one_mirror_label(t: Node) -> void:
	var model := CaveNetwork.new()
	model.load_room(CaveModel.MIRROR_ROOM)
	var labels: Array = Painter.turn_labels(model)
	t.assert_eq(labels.size(), 1, "only the mirror the light is stopped on is labeled")
	t.assert_eq(labels[0]["cell"], _def_cell("T"), "the opening label hangs on T")
	model.player = Vector2i(0, 2)
	model.destination = model.player
	var stood: Array = Painter.turn_labels(model)
	t.assert_eq(stood.size(), 1, "standing elsewhere still shows one label")
	t.assert_eq(stood[0]["cell"], _def_cell("T"), "the label does not follow the player")
	model.mirror_rots["T"] = _def_rot("T", "solution_rot")
	var nxt: Array = Painter.turn_labels(model)
	t.assert_eq(nxt.size(), 1, "the light on the next mirror is still a single label")
	t.assert_eq(nxt[0]["cell"], _def_cell("A"), "the label moves to the mirror the light now stops on")
	var chapter := MogaoChapter.new()
	t.add_child(chapter)
	chapter.model.load_room(CaveModel.MIRROR_ROOM)
	chapter._tick_mirror_feedback(0.05)
	t.assert_eq(chapter.model.back_flash_cell, _def_cell("T"), "the labeled mirror flashes")
	t.assert_true(chapter.model.back_flash > 0.0, "the flash is visible")
	chapter.model.mirror_rots["T"] = _def_rot("T", "solution_rot")
	chapter._tick_mirror_feedback(0.05)
	t.assert_eq(chapter.mirror_label_cell, _def_cell("A"), "the chapter tracks the single labeled mirror")
	t.assert_eq(chapter.model.back_flash_cell, _def_cell("A"), "the flash follows the light to the next mirror")
	chapter.free()


static func _preview_label_clears_mirror(t: Node, seg: Dictionary) -> void:
	var font := MogaoChapter.FONT
	var text := "还要转%d下" % int(seg["k"])
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var mirror := Vector2(420, 280)
	var beam := Vector2(seg["dir"])
	var far := mirror + beam * 180.0
	for unit_value in [30.0, 56.0, 70.0]:
		var unit := float(unit_value)
		var label := Painter.preview_label_rect(mirror, beam, unit, text_size)
		var sprite := Painter.mirror_sprite_rect(mirror, unit)
		t.assert_true(not label.intersects(sprite), "turn count stays off the mirror at unit %s" % unit)
		var start := mirror + beam * unit * 0.55
		var stroke := maxf(3.0, unit * 0.06)
		t.assert_true(not Painter.segment_hits_rect(start, far, label.grow(stroke)), "turn count stays off the dashed line at unit %s" % unit)
		var incoming := mirror + Vector2(-180, 0)
		t.assert_true(not Painter.segment_hits_rect(incoming, mirror, label.grow(stroke)), "turn count stays off the incoming beam at unit %s" % unit)
		t.assert_true(label.get_center().distance_to(mirror) < label.get_center().distance_to(far), "turn count sits by the lit mirror")


static func _mirror_stall(t: Node) -> void:
	var chapter := MogaoChapter.new()
	t.add_child(chapter)
	chapter.model.load_room(CaveModel.MIRROR_ROOM)
	chapter._tick_mirror_feedback(0.01)
	chapter.model.mirror_rots["B"] = 0
	chapter._tick_mirror_feedback(40.0)
	t.assert_eq(chapter.hint.text, "铜镜背面不照光。", "spinning a mirror the light has not reached still reaches 40 seconds")
	chapter.model.mirror_rots["B"] = 2
	chapter._tick_mirror_feedback(40.0)
	t.assert_eq(chapter.hint.text, "光只会顺着红箭头拐出去。", "spinning without progress still reaches 80 seconds")
	var stuck: float = chapter.mirror_stuck
	chapter.model.mirror_rots["T"] = _def_rot("T", "solution_rot")
	chapter._tick_mirror_feedback(0.05)
	t.assert_true(chapter.mirror_stuck < stuck, "the light moving farther resets the stall timer")
	t.assert_true(chapter.model.back_flash > 0.0, "the newly lit mirror flashes")
	t.assert_eq(chapter.model.back_flash_cell, _def_cell("A"), "the flash follows the mirror the light now hits")
	chapter.free()


static func _turn_times(t: Node, model: CaveNetwork, id: String) -> void:
	var times := CaveModel.turns_from_start(id)
	for _i in times:
		t.assert_true(model.turn_mirror(), "%s turns from its stand" % id)
		model.advance(1)


static func _mirror_exit_to_deer(t: Node) -> void:
	var chapter := _solved_mirror_door(t)
	t.assert_true(chapter.model.lotus_lit() and chapter.model.reached, "solving the mirrors lights the lotus and opens the north cell")
	t.assert_eq(chapter.model.player, CaveModel.MIRROR_GOAL, "the solved route stands on the deer door")
	t.assert_true(not chapter.overlay.visible, "the lotus line is a hint, not a card left on top of the buttons")
	t.assert_eq(chapter.mirror_art.mouse_filter, Control.MOUSE_FILTER_IGNORE, "mirror sprites do not eat the door click")
	chapter.refresh()
	t.assert_eq(chapter.action_button.text, "进入鹿影窟", "the button offers the deer cave")
	t.assert_true(not chapter.action_button.disabled, "进入鹿影窟 is enabled")
	var spins := int(chapter.model.turns)
	chapter.action_button.pressed.emit()
	t.assert_eq(chapter.model.room, 2, "clicking 进入鹿影窟 enters the deer cave")
	t.assert_eq(chapter.model.player, Vector2i(5, 7), "the door leads to the deer cave landing")
	t.assert_eq(int(chapter.model.turns), spins, "the door click does not turn a mirror")
	chapter.free()

	chapter = _solved_mirror_door(t)
	_press_key(chapter, KEY_SPACE)
	t.assert_eq(chapter.model.room, 2, "space on the deer door enters")
	chapter.free()

	chapter = _solved_mirror_door(t)
	var accept := InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.physical_keycode = KEY_ENTER
	accept.pressed = true
	t.assert_true(accept.is_action_pressed("ui_accept"), "enter is the ui_accept key")
	chapter._unhandled_key_input(accept)
	t.assert_eq(chapter.model.room, 2, "ui_accept on the deer door enters")
	chapter.free()

	chapter = _solved_mirror_door(t)
	_press_key(chapter, KEY_UP)
	t.assert_eq(chapter.model.room, 2, "up from the deer door enters")
	t.assert_eq(chapter.model.player, Vector2i(5, 7), "up uses the deer door landing")
	chapter.free()

	chapter = _solved_mirror_door(t)
	chapter.arrows[0].pressed.emit()
	t.assert_eq(chapter.model.room, 2, "the on-screen up key enters the deer door")
	chapter.free()

	for solved in [false, true]:
		for how in ["button", "space", "enter", "down"]:
			chapter = _south_lamp_door(t, solved)
			var south_spins := int(chapter.model.turns)
			_ui_enter(chapter, how)
			t.assert_eq(chapter.model.room, 4, "south door %s returns to the lamp cave while solved=%s" % [how, solved])
			t.assert_eq(chapter.model.player, Vector2i(3, 0), "south door %s uses the lamp landing" % how)
			t.assert_eq(int(chapter.model.turns), south_spins, "the south door does not turn a mirror")
			t.assert_true(chapter.hint.text != "站到铜镜旁边再转", "the south door does not show the mirror hint")
			chapter.free()

	chapter = _solved_mirror_door(t)
	t.assert_true(chapter.model.step(Vector2i.DOWN), "step back off the door")
	chapter.model.advance(1)
	_press_key(chapter, KEY_UP)
	_release_key(chapter, KEY_UP)
	chapter._process(CaveModel.STEP_SECONDS)
	t.assert_eq(chapter.model.player, CaveModel.MIRROR_GOAL, "one north press walks onto the open door")
	t.assert_eq(chapter.model.room, CaveModel.MIRROR_ROOM, "landing on the door does not leave by itself")
	chapter.free()

	chapter = _solved_mirror_door(t)
	chapter.pause_game()
	chapter.modal_primary()
	t.assert_eq(chapter.mode, "playing", "continue closes the pause card")
	t.assert_true(not chapter.overlay.visible, "the pause mask is gone")
	chapter.refresh()
	chapter.action_button.pressed.emit()
	t.assert_eq(chapter.model.room, 2, "entering still works after pause and continue")
	chapter.free()

	chapter = _solved_mirror_door(t)
	chapter.model.remember_room()
	var saved: Dictionary = chapter.model.save_network()
	var loaded := MogaoChapter.new()
	t.add_child(loaded)
	loaded.model.resume_network(CaveModel.MIRROR_ROOM, saved)
	loaded.mode = "playing"
	loaded.refresh()
	t.assert_true(loaded.model.lotus_lit() and loaded.model.reached, "a save keeps the solved mirror cave")
	t.assert_eq(loaded.action_button.text, "进入鹿影窟", "the loaded door still offers the deer cave")
	t.assert_true(not loaded.action_button.disabled, "the loaded door button is enabled")
	loaded.action_button.pressed.emit()
	t.assert_eq(loaded.model.room, 2, "entering works after loading the save")
	t.assert_eq(loaded.model.player, Vector2i(5, 7), "the loaded door uses the same landing")
	loaded.free()
	chapter.free()


static func _settlement_enters_third(t: Node) -> void:
	SaveManager.clear_save()
	var host = load("res://scripts/main.gd").new()
	t.add_child(host)
	host._new_game(1)
	var cave: MogaoChapter = host.cave_chapter
	cave.model.load_room(2)
	cave.model.rescued = true
	cave.model.player = cave.model.exit_cell
	cave.model.destination = cave.model.player
	cave.mode = "playing"
	cave.model.paused = false
	cave.refresh()
	t.assert_eq(cave.action_button.text, "前往三危山", "the deer exit offers the third chapter")
	cave.action_button.pressed.emit()
	t.assert_eq(cave.primary.text, "前往三危山", "the settlement card is the third-chapter door")
	cave.primary.pressed.emit()
	t.assert_true(host.third_chapter != null, "the settlement button opens the third chapter")
	var third: ThirdChapter = host.third_chapter
	t.assert_true(third.camera.current, "the third chapter has a live camera")
	third._on_action("primary")
	t.assert_eq(third.mode, "playing", "the welcome card can be dismissed")
	third._physics_process(0.05)
	third.held[KEY_W] = true
	t.assert_true(third.movement().length() > 0.5, "the third chapter accepts a forward step")
	t.assert_eq(third.mode, "playing", "the third chapter stays playable after the welcome card")
	third.held.clear()
	third.rescued = true
	third.body.position = ThirdMap.world(ThirdMap.CAMP) + Vector3(0, 0.2, 0)
	third._physics_process(0.05)
	t.assert_true(str(third.mode).begins_with("ending"), "reaching the camp starts the ending")
	third._on_action("primary")
	t.assert_eq(third.mode, "complete", "the ending card can be finished")
	host.free()
	SaveManager.clear_save()


static func _south_lamp_door(t: Node, solved: bool) -> MogaoChapter:
	var chapter := MogaoChapter.new()
	t.add_child(chapter)
	chapter.model.load_room(CaveModel.MIRROR_ROOM)
	chapter.mode = "playing"
	chapter.model.paused = false
	chapter.rebuild_cranks()
	if solved:
		chapter.model.mirror_rots = CaveModel.solution_rots()
		chapter.model.reached = true
	chapter.model.player = Vector2i(3, 8)
	chapter.model.destination = chapter.model.player
	chapter.refresh()
	t.assert_eq(chapter.action_button.text, "进入灯窟", "the south door offers the lamp cave while solved=%s" % solved)
	t.assert_true(not chapter.action_button.disabled, "the south door button is enabled while solved=%s" % solved)
	return chapter


static func _ui_enter(chapter: MogaoChapter, how: String) -> void:
	match how:
		"button":
			chapter.action_button.pressed.emit()
		"space":
			_press_key(chapter, KEY_SPACE)
		"enter":
			_press_key(chapter, KEY_ENTER)
		"up":
			_press_key(chapter, KEY_UP)
		"down":
			_press_key(chapter, KEY_DOWN)
		_:
			chapter.action_button.pressed.emit()


static func _ui_exit_every_cave(t: Node) -> void:
	var probe := MogaoChapter.new()
	t.add_child(probe)
	for room_id in CaveModel.ROOMS:
		probe.model.load_room(room_id)
		var doors: Array = probe.model.doors()
		for door in doors:
			if not _exit_can_open(probe.model, door):
				continue
			for how in ["button", "space", "enter"]:
				var chapter := _stand_on_exit(t, room_id, door)
				var target := int(door.target)
				var spawn := door.spawn as Vector2i
				_ui_enter(chapter, how)
				t.assert_eq(chapter.model.room, target, "room %s %s enters %s" % [room_id, how, door.label])
				t.assert_eq(chapter.model.player, spawn, "room %s %s lands on the next door" % [room_id, how])
				chapter.free()
	probe.free()


static func _exit_can_open(model: CaveNetwork, door: Dictionary) -> bool:
	model.reached = true
	if model.room == CaveModel.MIRROR_ROOM:
		model.mirror_rots = CaveModel.solution_rots()
	model.player = door.cell
	model.destination = model.player
	return not model.current_door().is_empty() and bool(model.current_door().open)


static func _stand_on_exit(t: Node, room_id: int, door: Dictionary) -> MogaoChapter:
	var chapter := MogaoChapter.new()
	t.add_child(chapter)
	chapter.model.load_room(room_id)
	chapter.mode = "playing"
	chapter.model.paused = false
	chapter.rebuild_cranks()
	chapter.model.reached = true
	if room_id == CaveModel.MIRROR_ROOM:
		chapter.model.mirror_rots = CaveModel.solution_rots()
	chapter.model.player = door.cell
	chapter.model.destination = chapter.model.player
	chapter.refresh()
	t.assert_true(chapter.action_button.text.begins_with("进入"), "room %s shows an enter button, got %s" % [room_id, chapter.action_button.text])
	t.assert_true(not chapter.action_button.disabled, "room %s enter button is enabled" % room_id)
	return chapter


static func _solved_mirror_door(t: Node) -> MogaoChapter:
	var chapter := MogaoChapter.new()
	t.add_child(chapter)
	chapter.model.load_room(CaveModel.MIRROR_ROOM)
	chapter.mode = "playing"
	chapter.model.paused = false
	chapter.rebuild_cranks()
	_solve_mirrors(t, chapter.model)
	return chapter


static func _press_key(chapter: MogaoChapter, keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	chapter._unhandled_key_input(event)


static func _release_key(chapter: MogaoChapter, keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = false
	chapter._unhandled_key_input(event)


static func _solve_mirrors(t: Node, model: CaveNetwork) -> void:
	Puzzle.route(t, model, "R")
	_turn_times(t, model, "T")
	Puzzle.route(t, model, "RUUUUUU")
	_turn_times(t, model, "A")
	Puzzle.route(t, model, "ULLLLLLDDDD")
	_turn_times(t, model, "B")
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
				probe.mirror_rots = {"T": ta, "A": aa, "F": _def_rot("F", "start_rot"), "B": ba}
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


static func _reflect_entry(rot: int) -> Vector2i:
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if Beam.reflect(dir, rot) != Vector2i.ZERO:
			return dir
	return Vector2i.ZERO


static func _arrow_offset(key: String) -> Vector2:
	var image := (load(AssetRegistry.mogao_sprite_path(key)) as Texture2D).get_image()
	var total := Vector2.ZERO
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.8 and pixel.r > 0.7 and pixel.g < 0.4 and pixel.b < 0.35:
				total += Vector2(x, y)
				count += 1
	return total / float(count) - Vector2((image.get_width() - 1) * 0.5, (image.get_height() - 1) * 0.5)


static func _def_rot(id: String, field: String) -> int:
	for mirror in CaveModel.MIRROR_DEFS:
		if str(mirror["id"]) == id:
			return int(mirror[field])
	return 0


static func _def_cell(id: String) -> Vector2i:
	for mirror in CaveModel.MIRROR_DEFS:
		if str(mirror["id"]) == id:
			return mirror["cell"]
	return Vector2i.ZERO


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
