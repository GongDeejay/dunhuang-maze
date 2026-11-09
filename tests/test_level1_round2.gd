extends RefCounted

const Branches = preload("res://scripts/journey_branches.gd")
const MainScript = preload("res://scripts/main.gd")
const WallFeedbackScript = preload("res://scripts/wall_feedback.gd")

const TRACE_BODY := "这是妈妈的脚印，一路向东。她要先到东边的石门，过了石门，就往北走了。\n前面有一份疗伤卷，走过去即可拾取；低血量时会自动使用。"
const SIGN_BODY := "↓ 古道：绕远，没有风沙，沿路有一眼清泉。\n→ 近路：更短，要过四格风沙，有沙蝎。\n↗ 远处有座烽燧，登台能望得更远。\n古道南头偏西，沙里半埋着一支驼队。\n古道东南的岔口，立着一块残碑。\n两条路都通石门，过了石门再往北找妈妈。"
const CAMP_BODY := "驿卒：见过妈妈，她过了石门往北去了。\n先去北边找到她，再一起回来歇脚。"
const STELE_BODY := "碑脚有一行新刻的小字：\n“弟弟追着九色鹿的画跑远了，我进窟里找他。——哥哥”\n你收起一块壁画残片。"


static func run(t: Node) -> void:
	print("\n[TEST] Level 1 round 2")
	_copy(t)
	_ranges(t)
	_audio(t)
	_bump_rules(t)
	_mobile(t)
	_play(t)
	DataLoader.set_difficulty("normal")


static func _copy(t: Node) -> void:
	var maze := MazeGenerator.new(FirstJourney.SIZE.x, FirstJourney.SIZE.y)
	var journey := FirstJourney.new()
	journey.build(maze)
	var player := _player(30, 30)
	var trace := journey.enter(Vector2i(2, 1), maze, player)
	t.assert_eq(trace.get("title", ""), "沙地里的足迹", "first trace title")
	t.assert_eq(trace.get("body", ""), TRACE_BODY, "first trace tells the gate then north")
	t.assert_true(trace.get("body", "").contains("石门") and trace.get("body", "").contains("往北"), "trace names the gate and north")
	t.assert_eq(trace.get("button", ""), "沿着足迹出发", "trace button")
	var sign := journey.enter(FirstJourney.FORK, maze, player)
	t.assert_eq(sign.get("body", ""), SIGN_BODY, "sign copy")
	t.assert_eq(sign.get("body", "").split("\n").size(), 6, "sign has six lines")
	var camp := Branches.camp_card()
	t.assert_eq(camp.get("title", ""), "驿站里的线索", "camp title")
	t.assert_eq(camp.get("body", ""), CAMP_BODY, "camp fallback copy")
	t.assert_eq(camp.get("button", ""), "去北边找妈妈", "camp button")
	var note := journey.enter(FirstJourney.STELE, maze, player)
	t.assert_eq(note.get("body", ""), STELE_BODY, "stele copy")
	t.assert_eq(note.get("button", ""), "记下哥哥的字", "stele button")
	t.assert_true(not note.get("body", "").contains("孩子们往莫高窟"), "stele drops the old rescue sentence")
	var unread_journey := FirstJourney.new()
	unread_journey.build(maze)
	var unread := unread_journey.rescue(maze, player)
	t.assert_true(unread.get("body", "").begins_with("“你没事，太好了！孩子们往莫高窟那边去了。”"), "rescue without the stele keeps the old line")
	var read := FirstJourney.new()
	read.build(maze)
	read.enter(FirstJourney.STELE, maze, player)
	var echoed := read.rescue(maze, player)
	t.assert_true(echoed.get("body", "").contains("你看到哥哥刻的字了"), "rescue after the stele answers the carving")
	t.assert_true(_shared_sentences(note.get("body", ""), unread.get("body", "")).is_empty(), "stele and unread rescue share no sentence")
	t.assert_true(_shared_sentences(note.get("body", ""), echoed.get("body", "")).is_empty(), "stele and read rescue share no sentence")
	player.free()


static func _ranges(t: Node) -> void:
	var maze := MazeGenerator.new(FirstJourney.SIZE.x, FirstJourney.SIZE.y)
	var journey := FirstJourney.new()
	journey.build(maze)
	var player := _player(20, 20)
	t.assert_true(journey.roadbook_ranges().is_empty(), "roadbook stays blank before the beacon")
	journey.enter(FirstJourney.BEACON, maze, player)
	journey.map_seed = 7
	var areas: Array = journey.roadbook_ranges()
	t.assert_eq(areas.size(), 2, "beacon marks two areas")
	var again: Array = journey.roadbook_ranges()
	for i in areas.size():
		var area: Dictionary = areas[i]
		var target: Vector2i = area["target"]
		var center: Vector2i = area["cell"]
		t.assert_eq(center, again[i]["cell"], "survey offset repeats for the same map seed")
		t.assert_eq(absi(center.x - target.x) + absi(center.y - target.y) > 0, true, "circle center is not the target cell")
		t.assert_true(maxi(absi(center.x - target.x), absi(center.y - target.y)) == 1, "center is offset by one cell")
		t.assert_eq(float(area["radius"]), 2.0, "survey circle radius is two cells")
		t.assert_true(str(area["label"]) in ["驼", "碑"], "circles are labeled 驼 and 碑")
	journey.caravan_found = true
	var found: Array = journey.roadbook_ranges()
	t.assert_eq(str(found[0]["kind"]), "found", "finding the caravan replaces the circle")
	t.assert_eq(found[0]["cell"], FirstJourney.CARAVAN, "the found mark sits on the caravan")
	t.assert_true(not bool(maze.landmarks[FirstJourney.FAMILY].get("discovered", false)), "mother is not marked discovered")
	var sketch := Vector2(520, 230)
	var span := RouteSketch.range_span(2.2, sketch)
	var cell_w := (sketch.x - 40.0) / 14.0
	t.assert_true(span.x > cell_w * 2.0, "drawn range covers more than one map cell")
	player.free()


static func _audio(t: Node) -> void:
	var spec: Dictionary = AudioManager.wall_hit_fallback()
	t.assert_eq(spec.get("freq", 0), 70.0, "thud is about 70 Hz")
	t.assert_eq(spec.get("duration", 0), 0.09, "thud lasts 0.09 seconds")
	t.assert_eq(spec.get("volume", 0), 0.25, "thud volume")
	t.assert_true(float(spec.get("decay_at", 1.0)) < 0.3, "thud decays quickly")
	t.assert_eq(AudioManager.wall_hit_source(), "", "missing wall_hit file falls back to the thud")


static func _bump_rules(t: Node) -> void:
	t.assert_eq(WallFeedbackScript.offset(MazeGenerator.E), Vector2(3, 0), "east bump is 3 px")
	t.assert_eq(WallFeedbackScript.OUT_SECONDS + WallFeedbackScript.BACK_SECONDS, 0.12, "bump lasts 0.12 seconds")
	t.assert_true(not WallFeedbackScript.allow(true, "", -1.0, "a", 1.0), "hurt flash suppresses the bump")
	t.assert_true(not WallFeedbackScript.allow(false, "same", 1.0, "same", 1.1), "same wall waits 0.25 seconds")
	t.assert_true(WallFeedbackScript.allow(false, "same", 1.0, "other", 1.1), "another wall can bump inside the cooldown")
	t.assert_true(WallFeedbackScript.allow(false, "same", 1.0, "same", 1.25), "same wall bumps again after the cooldown")


static func _mobile(t: Node) -> void:
	for vp in [Vector2(390, 844), Vector2(844, 390), Vector2(360, 640)]:
		var profile := UILayoutDirector.compute(vp, true)
		if profile.controls_rect.size.y <= 1.0:
			continue
		var controls := MobileControls.new()
		controls.drink_visible = true
		controls.apply_layout(profile)
		t.assert_true(controls._func_centers.has("drink"), "drink button exists at %s" % vp)
		var center: Vector2 = controls._func_centers["drink"]
		var size := controls.func_btn_size
		t.assert_true(size >= 48.0, "drink button is at least 48 px at %s" % vp)
		var hit := Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size)
		t.assert_true(profile.controls_rect.encloses(hit), "drink button stays in the control area at %s" % vp)
		for entry in controls._dpad_centers:
			var dpad := Rect2((entry.pos as Vector2) - Vector2.ONE * controls.btn_radius, Vector2.ONE * controls.btn_radius * 2.0)
			t.assert_true(not hit.intersects(dpad), "drink button does not cover the d-pad at %s" % vp)
		controls.free()


static func _play(t: Node) -> void:
	SaveManager.clear_save()
	DataLoader.set_difficulty("normal")
	var main := MainScript.new()
	t.add_child(main)
	var maze := MazeGenerator.new(FirstJourney.SIZE.x, FirstJourney.SIZE.y)
	var journey := FirstJourney.new()
	journey.build(maze)
	main.maze = maze
	main.maze_width = maze.width
	main.maze_height = maze.height
	main.first_journey = journey
	main.game.start_game()
	main.player.pos = Vector2i(0, 0)
	main.player.max_hp = 30
	main.player.hp = 30
	main.move_count = 4
	main.moves_since_progress = 2
	main.player.buff_timer = 3
	var blocked := _blocked_dirs(maze, main.player.pos)
	t.assert_true(blocked.size() >= 2, "start cell has two walls")
	main._try_move(blocked[0])
	t.assert_eq(main.player.pos, Vector2i(0, 0), "wall bump does not move")
	t.assert_eq(main.player.hp, 30, "wall bump does not cost hp")
	t.assert_eq(main.move_count, 4, "wall bump does not count a step")
	t.assert_eq(main.moves_since_progress, 2, "wall bump does not count as being lost")
	t.assert_eq(main.player.buff_timer, 3, "wall bump does not tick buffs")
	t.assert_eq(main.wall_bumps, 1, "first hit on a wall counts")
	main._try_move(blocked[0])
	t.assert_eq(main.wall_bumps, 1, "holding into the same wall does not repeat")
	main._try_move(blocked[1])
	t.assert_eq(main.wall_bumps, 2, "a different wall still responds")
	main.player.is_hurt = true
	main._bump_wall_at = -1.0
	main._try_move(blocked[0])
	t.assert_eq(main.wall_bumps, 2, "hurt flash skips the bump")
	main.player.is_hurt = false
	var open := _open_neighbor(maze, main.player.pos)
	var monster := MonsterEntity.new()
	monster.setup("sand", open, 1.0)
	monster.hp = 30
	main.monsters.append(monster)
	var before_bumps := main.wall_bumps
	main._try_move(_dir_toward(main.player.pos, open))
	t.assert_eq(main.wall_bumps, before_bumps, "walking into a monster is combat, not a wall")
	t.assert_true(monster.hp < 30, "the monster took the attack")
	monster.free()
	main.monsters.clear()
	_skin(t, main, journey)
	main.free()


static func _skin(t: Node, main, journey: FirstJourney) -> void:
	for _i in 5:
		main.inventory.add_item("heal_scroll")
	var packed: int = main.inventory.get_count()
	var hp: int = main.player.hp
	var card := journey.enter(FirstJourney.CARAVAN, main.maze, main.player)
	t.assert_eq(main.player.hp, hp, "full hp pickup does not heal")
	t.assert_eq(journey.water_skin, 1, "full inventory still receives the skin")
	t.assert_eq(main.inventory.get_count(), packed, "the skin does not enter or discard inventory")
	t.assert_true(card.get("body", "").contains("水囊"), "pickup card names the skin")
	main.journey_card.visible = true
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_H
	main._unhandled_input(ev)
	t.assert_eq(journey.water_skin, 1, "H does nothing while a story card is open")
	main.journey_card.visible = false
	main._drink_water_skin(false)
	t.assert_eq(journey.water_skin, 1, "drinking at full hp keeps the skin")
	t.assert_true(main.combat_log[main.combat_log.size() - 1] == "体力已满，水囊先留着", "full hp drink explains itself")
	main.player.hp = 12
	main._drink_water_skin(false)
	t.assert_eq(main.player.hp, 18, "normal drink restores 6 and stops at max hp")
	t.assert_eq(journey.water_skin, 0, "the drink consumes the skin")
	t.assert_eq(main.combat_log[main.combat_log.size() - 1], "喝下水囊：恢复 6 点体力", "drink log")
	main._drink_water_skin(false)
	t.assert_eq(main.combat_log[main.combat_log.size() - 1], "水囊已喝完", "empty skin log")
	journey.water_skin = 1
	main.player.hp = 9
	main.inventory.clear()
	main._try_auto_heal()
	t.assert_eq(journey.water_skin, 0, "low hp without a scroll drinks the skin")
	t.assert_true(str(main.combat_log[main.combat_log.size() - 1]).begins_with("体力不支，自动喝下水囊"), "auto drink log")
	journey.water_skin = 1
	main.player.hp = 9
	main.inventory.add_item("heal_scroll")
	main._try_auto_heal()
	t.assert_eq(journey.water_skin, 1, "a heal scroll is used before the skin")
	t.assert_eq(main.inventory.get_count(), 0, "the scroll was consumed")
	t.assert_eq(journey.water_skin_hud(), "水囊 ×1（H 喝）", "hud shows the remaining skin")
	journey.water_skin = 0
	t.assert_eq(journey.water_skin_hud(), "水囊 已空", "hud shows an empty skin")
	journey.water_skin = 1
	t.assert_true(journey.discovery_line().contains("水囊没喝完，留给了妈妈。"), "settlement mentions a leftover skin")
	var paused := InputHandler.new()
	var ctx := {"paused": true}
	var held := InputEventKey.new()
	held.pressed = true
	held.keycode = KEY_H
	t.assert_eq(paused.handle(held, ctx).type, GameAction.Type.NONE, "pause ignores H")


static func _blocked_dirs(maze: MazeGenerator, pos: Vector2i) -> Array[int]:
	var dirs: Array[int] = []
	for dir in [MazeGenerator.N, MazeGenerator.E, MazeGenerator.S, MazeGenerator.W]:
		if not maze.can_move(pos.x, pos.y, dir):
			dirs.append(dir)
	return dirs


static func _open_neighbor(maze: MazeGenerator, pos: Vector2i) -> Vector2i:
	for dir in [MazeGenerator.N, MazeGenerator.E, MazeGenerator.S, MazeGenerator.W]:
		if maze.can_move(pos.x, pos.y, dir):
			return pos + Vector2i(MazeGenerator.DX[dir], MazeGenerator.DY[dir])
	return pos


static func _dir_toward(from: Vector2i, to: Vector2i) -> int:
	var delta := to - from
	if delta.x > 0:
		return MazeGenerator.E
	if delta.x < 0:
		return MazeGenerator.W
	if delta.y > 0:
		return MazeGenerator.S
	return MazeGenerator.N


static func _shared_sentences(a: String, b: String) -> Array[String]:
	var shared: Array[String] = []
	for sentence in _sentences(a):
		if _sentences(b).has(sentence):
			shared.append(sentence)
	return shared


static func _sentences(text: String) -> Array[String]:
	var parts: Array[String] = []
	var buf := ""
	for i in text.length():
		var ch := text.substr(i, 1)
		if ch == "\n" or ch == "。" or ch == "！" or ch == "？":
			var sentence := buf.strip_edges()
			if sentence != "":
				parts.append(sentence)
			buf = ""
		else:
			buf += ch
	var tail := buf.strip_edges()
	if tail != "":
		parts.append(tail)
	return parts


static func _player(max_hp: int, hp: int) -> PlayerController:
	var player := PlayerController.new()
	player.max_hp = max_hp
	player.hp = hp
	return player
