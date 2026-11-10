extends RefCounted

const Branches = preload("res://scripts/journey_branches.gd")
const MeasureText = preload("res://scripts/presentation/measure_text.gd")
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
	_measures(t)
	_keep_words(t)
	_popup_layout(t)
	_camp_pictures(t)
	_roadbook_log(t)
	_clock(t)
	_beacon_hint(t)
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
		t.assert_eq(str(area["kind"]), "area", "an unfound mark is a circle")
		t.assert_eq(float(area["radius"]), 2.0, "survey circle radius is two cells")
		t.assert_true(str(area["label"]) in ["驼", "碑"], "circles are labeled 驼 and 碑")
		for page in [Vector2(520, 230), Vector2(360, 175)]:
			var bounds := RouteSketch.range_rect(center, float(area["radius"]), page)
			t.assert_true(Rect2(Vector2.ZERO, page).grow(-1.0).encloses(bounds), "%s circle stays on the page" % area["label"])
	var neighbors: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	for target in [FirstJourney.CARAVAN, FirstJourney.STELE]:
		for offset in neighbors:
			var fitted := RouteSketch.range_rect(target + offset, 2.0, Vector2(520, 230))
			t.assert_true(Rect2(Vector2.ZERO, Vector2(520, 230)).grow(-1.0).encloses(fitted), "radius 2 around %s fits" % [target + offset])
	journey.caravan_found = true
	var found: Array = journey.roadbook_ranges()
	t.assert_eq(str(found[0]["kind"]), "found", "finding the caravan replaces the circle")
	t.assert_eq(str(found[1]["kind"]), "area", "the stele stays a circle until it is found")
	t.assert_eq(found[0]["cell"], FirstJourney.CARAVAN, "the found mark sits on the caravan")
	journey.caravan_found = false
	journey.stele_found = true
	var stele_only: Array = journey.roadbook_ranges()
	t.assert_eq(str(stele_only[0]["kind"]), "area", "the caravan stays a circle until it is found")
	t.assert_eq(str(stele_only[1]["kind"]), "found", "finding the stele replaces its circle")
	journey.caravan_found = true
	var both: Array = journey.roadbook_ranges()
	t.assert_eq(str(both[0]["kind"]), "found", "a found caravan stays a point")
	t.assert_eq(str(both[1]["kind"]), "found", "a found stele stays a point")
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
	t.assert_eq(AudioManager.wall_hit_source(), "res://assets/audio/wall_hit.ogg", "wall hit plays the recorded sample")
	t.assert_true(ResourceLoader.exists("res://assets/audio/drink.ogg"), "drink sample is available")


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
		t.assert_eq(controls.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "drink icon is nearest")
		t.assert_true(controls._func_centers.has("drink"), "drink button exists at %s" % vp)
		var center: Vector2 = controls._func_centers["drink"]
		var size := controls.func_btn_size
		t.assert_true(size >= 48.0, "drink button is at least 48 px at %s" % vp)
		var hit := Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size)
		t.assert_true(profile.controls_rect.encloses(hit), "drink button stays in the control area at %s" % vp)
		var icon := controls.drink_icon_rect(hit)
		t.assert_true(hit.encloses(icon), "waterskin icon sits inside the drink button at %s" % vp)
		t.assert_true(icon.size.x >= 28.0 and icon.size.x <= 34.0, "drink icon is about twice the 16px art at %s" % vp)
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
	main._process(0.04)
	t.assert_true(main.player.bump_offset.length() > 1.0, "a wall bump shifts the sprite by about 3px")
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
	var panel := UIPanel.new()
	panel.water_skin_filled = true
	t.assert_eq(panel.water_skin_icon_key(), "water_skin", "a full skin uses waterskin.png")
	var full := panel.water_skin_texture()
	t.assert_eq(Vector2i(full.get_width(), full.get_height()), Vector2i(16, 16), "waterskin.png is 16x16")
	journey.water_skin = 0
	t.assert_eq(journey.water_skin_hud(), "水囊 已空", "hud shows an empty skin")
	panel.water_skin_filled = false
	t.assert_eq(panel.water_skin_icon_key(), "water_skin_empty", "an empty skin uses waterskin_empty.png")
	var empty := panel.water_skin_texture()
	t.assert_eq(Vector2i(empty.get_width(), empty.get_height()), Vector2i(16, 16), "waterskin_empty.png is 16x16")
	var empty_image := empty.get_image()
	var tinted := 0
	for py in empty_image.get_height():
		for px in empty_image.get_width():
			var pixel := empty_image.get_pixel(px, py)
			if pixel.a > 0.4 and pixel.g < 0.95:
				tinted += 1
	t.assert_true(tinted > 8, "the empty waterskin is not a white square")
	journey.water_skin = 1
	t.assert_true(journey.discovery_line().contains("水囊没喝完，留给了妈妈。"), "settlement mentions a leftover skin")
	_discovery_counts(t)
	var paused := InputHandler.new()
	var ctx := {"paused": true}
	var held := InputEventKey.new()
	held.pressed = true
	held.keycode = KEY_H
	t.assert_eq(paused.handle(held, ctx).type, GameAction.Type.NONE, "pause ignores H")


static func _keep_words(t: Node) -> void:
	var font := load("res://assets/fonts/NotoSansSC-GameSubset.ttf") as FontFile
	font.allow_system_fallback = false
	var words := MeasureText.keep_words()
	var shortcut := -1
	var cave := -1
	for i in words.size():
		if words[i] == "栈道捷径":
			shortcut = i
		elif words[i] == "栈道窟":
			cave = i
	t.assert_true(shortcut >= 0 and cave > shortcut, "栈道捷径 is matched before the shorter 栈道窟")
	var missing := ""
	var seen := {}
	for word in words:
		for i in word.length():
			var code := word.unicode_at(i)
			if seen.has(code):
				continue
			seen[code] = true
			if not font.has_char(code):
				missing += word.substr(i, 1)
	t.assert_eq(missing, "", "keep words are missing web font glyphs: %s" % missing)
	var prefix := "北面通向"
	var sentence := prefix + "鹿影窟。"
	var width := font.get_string_size(prefix + "鹿", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 0.5
	t.assert_true(font.get_string_size(prefix + "鹿影", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x > width, "the boundary cuts through 鹿影窟")
	t.assert_true(font.get_string_size("鹿影窟。", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x <= width + 0.01, "鹿影窟 still fits on a line of its own")
	var wrapped := MeasureText.layout_text(sentence, width, font, 18)
	t.assert_eq(_plain(wrapped).replace("\n", ""), sentence, "the deer-cave sentence keeps every character")
	var intact := false
	for line in _plain(wrapped).split("\n"):
		if line.contains("鹿影窟"):
			intact = true
	t.assert_true(intact, "鹿影窟 stays together: %s" % _plain(wrapped))
	_assert_lines(t, wrapped, "deer cave boundary")
	var narrow := font.get_string_size("栈", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 0.5
	var overlong := MeasureText.layout_text("栈道捷径。", narrow, font, 18)
	t.assert_eq(_plain(overlong).replace("\n", ""), "栈道捷径。", "an overlong name falls back to characters")
	t.assert_true(_plain(overlong).split("\n").size() > 1 and _plain(overlong).split("\n").size() <= 8, "an overlong name breaks by character and stops")
	_assert_lines(t, overlong, "overlong keep word")


static func _popup_layout(t: Node) -> void:
	var mom := "“你没事，太好了！孩子们往莫高窟那边去了。”\n妈妈帮你包扎，恢复 4 点体力，并指出右侧通往营地的旧路。\n捷径已经打开。先一起到营地，再去找孩子们。"
	var mirror := "灯固定在西南角，光沿直线走。\n铜镜亮金的一面是正面：光照上来，会顺着红箭头拐出去；打到深青绿的背面，或逆着箭头照来，光就停住。\n带石座的那面嵌在石里，转不动；另外三面站在旁边就能转。转错可以撤销。\n把光引到莲花灯座上，北面窟门的光帘才会散开，通向鹿影窟。\n\n本关为壁画幻境；机关为游戏虚构。"
	for size in [Vector2i(1280, 720), Vector2i(844, 390)]:
		var host := SubViewport.new()
		host.size = size
		host.disable_3d = true
		t.add_child(host)
		var card := JourneyCard.new()
		host.add_child(card)
		card.open_card({"title": "终于找到妈妈了", "body": mom, "button": "一起回营地"})
		_assert_lines(t, card.body_label.text, "mom popup %s" % size)
		var chapter := MogaoChapter.new()
		host.add_child(chapter)
		chapter.model.load_room(CaveModel.MIRROR_ROOM)
		chapter.show_note()
		_assert_lines(t, chapter.card_body.text, "mirror popup %s" % size)
		host.free()


static func _assert_lines(t: Node, text: String, label: String) -> void:
	var plain := _plain(text)
	var lines := plain.split("\n")
	for i in lines.size():
		var line: String = lines[i]
		if line.is_empty():
			continue
		t.assert_true(not "。，、！？；：」』）".contains(line.substr(0, 1)), "%s line starts with punctuation: %s" % [label, line])
		if i + 1 < lines.size() and not lines[i + 1].is_empty():
			var tail := line.substr(line.length() - 1, 1)
			var head := lines[i + 1].substr(0, 1)
			var digit := tail >= "0" and tail <= "9"
			var unit := "点下片格秒分步伤%".contains(head) or lines[i + 1].begins_with("HP")
			t.assert_true(not (digit and unit), "%s breaks after a number: %s / %s" % [label, line, lines[i + 1]])


static func _camp_pictures(t: Node) -> void:
	for pictures in [2, 3]:
		SaveManager.clear_save()
		var main = MainScript.new()
		t.add_child(main)
		main.game.start_game()
		main._new_game(0)
		main.journey_card.close()
		var journey: FirstJourney = main.first_journey
		journey.mural_found = true
		journey.fragments[1] = true
		journey.caravan_found = true
		journey.fragments[2] = true
		if pictures == 3:
			journey.stele_found = true
			journey.fragments[3] = true
		main._on_level_completed()
		var word := "两" if pictures == 2 else "三"
		var body := _plain(main.journey_card.body_label.text).replace("\n", "")
		t.assert_true(body.contains("这%s片画" % word), "camp card with %d pictures says so" % pictures)
		var shown := 0
		for rect in main.journey_card.fragment_rects:
			if rect.visible:
				shown += 1
		t.assert_eq(shown, pictures, "camp card shows %d thumbnails" % pictures)
		main.free()


static func _roadbook_log(t: Node) -> void:
	SaveManager.clear_save()
	var main = MainScript.new()
	t.add_child(main)
	main.game.start_game()
	main._new_game(0)
	main.journey_card.close()
	main.player.pos = FirstJourney.MURAL
	main._mark_visited(main.player.pos)
	t.assert_true(main.first_journey.mural_found, "the mural was found")
	main.route_notebook.traced.emit()
	var reveal := ""
	var pickup := ""
	for msg in main.combat_log:
		var text := str(msg)
		if text.contains("不代表前方没有危险"):
			reveal = text
		if text.contains("找到路书与补给"):
			pickup = text
	t.assert_true(reveal != "" and pickup != "", "tracing and finding the roadbook are both logged")
	t.assert_true(reveal != pickup, "the two roadbook lines stay separate strings")
	t.assert_true(not reveal.contains("找到路书与补给"), "the trace line does not swallow the pickup")
	t.assert_true(not pickup.contains("不代表前方没有危险"), "the pickup line does not swallow the trace")
	var font: Font = load("res://assets/fonts/NotoSansSC-GameSubset.ttf")
	var blocks := UIPanel.log_blocks([reveal, pickup], 168, font, 15)
	t.assert_eq(blocks.size(), 2, "the log lays the two messages out as two blocks")
	var trace_block := _plain(blocks[0])
	var heal_block := _plain(blocks[1])
	t.assert_true(trace_block.contains("再向北找妈妈") and not trace_block.contains("路书与补给"), "the trace block finishes on its own")
	t.assert_true(heal_block.contains("恢复") and heal_block.contains("点体力") and not heal_block.contains("危险"), "the pickup block is only the heal")
	main.free()
	SaveManager.clear_save()


static func _measures(t: Node) -> void:
	var font: Font = load("res://assets/fonts/NotoSansSC-GameSubset.ttf")
	var cases := [
		["恢复 4 点体力，这眼泉水只能取用一次。", "4 点体力"],
		["妈妈帮你包扎，恢复 4 点体力，并指出右侧通往营地的旧路。", "4 点体力"],
		["这次走了 226 步，沿古道回去。", "226 步"],
		["用时 12 分 34 秒，这次走了 8 步。", "12 分"],
		["喝下水囊：恢复 6 点体力", "6 点体力"],
		["你攻击沙蝎造成 12 伤害", "12 伤害"],
	]
	for row in cases:
		var sample: String = row[0]
		var token: String = row[1]
		var width := font.get_string_size(token, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 6.0
		var wrapped := MeasureText.wrapped_text(MeasureText.bind_units(sample), width, font, 18)
		t.assert_true(wrapped.contains("\n"), "narrow width wraps the sentence around %s" % token)
		t.assert_true(not _break_follows_digit(wrapped), "a number is not followed by a line break in %s" % sample)


static func _discovery_counts(t: Node) -> void:
	var words := ["", "一", "两", "三", "四"]
	var card := JourneyCard.new()
	t.add_child(card)
	for count in [1, 2, 3, 4]:
		var journey := FirstJourney.new()
		if count >= 1:
			journey.mural_found = true
			journey.fragments[1] = true
		if count >= 2:
			journey.beacon_found = true
		if count >= 3:
			journey.caravan_found = true
			journey.fragments[2] = true
		if count >= 4:
			journey.stele_found = true
			journey.fragments[3] = true
		var line := journey.discovery_line()
		var names := ["石窟壁画", "烽燧驼铃", "商队遗驼", "残碑留言"]
		var listed := 0
		for name in names:
			if line.contains(name):
				listed += 1
		t.assert_eq(listed, count, "the discovery list has %d names" % count)
		# Beacon has no fragment. One, two, three, four discoveries show 1, 1, 2, 3 pictures.
		var expected: int = [0, 1, 1, 2, 3][count]
		var pictures := 0
		for bit in journey.fragment_mask():
			if bit:
				pictures += 1
		t.assert_eq(pictures, expected, "beacon does not add a fourth picture")
		t.assert_true(line.contains("这%s片画" % words[pictures]), "finding %d things names %d pictures" % [count, pictures])
		t.assert_eq(JourneyBranches.picture_count(journey), pictures, "picture count matches the mask")
		card.open_card({
			"title": "与妈妈平安会合",
			"body": line,
			"sheet": AssetRegistry.fragment_sheet_path(),
			"fragment_mask": journey.fragment_mask(),
		})
		var shown := 0
		for rect in card.fragment_rects:
			if rect.visible:
				shown += 1
		t.assert_eq(shown, pictures, "%d discoveries show %d thumbnails" % [count, pictures])
		if count == 4:
			t.assert_true(line.contains("烽燧驼铃") and not line.contains("四片画"), "the beacon is listed and is not a fourth picture")
	card.free()


static func _plain(text: String) -> String:
	return text.replace(MeasureText.WORD_JOINER, "").replace(MeasureText.NO_BREAK_SPACE, " ")


static func _break_follows_digit(wrapped: String) -> bool:
	var plain := wrapped.replace(MeasureText.WORD_JOINER, "")
	var i := 0
	while i < plain.length():
		var code := plain.unicode_at(i)
		if code >= 0x30 and code <= 0x39:
			var j := i + 1
			while j < plain.length():
				var gap := plain.unicode_at(j)
				if gap != 0x20 and gap != 0xA0 and gap != 0x2060:
					break
				j += 1
			if j < plain.length() and plain.unicode_at(j) == 0x0A:
				return true
		i += 1
	return false


static func _clock(t: Node) -> void:
	SaveManager.clear_save()
	var main := MainScript.new()
	t.add_child(main)
	main.game.start_game()
	main.level_elapsed = 0.0
	main._process(2.0)
	t.assert_true(main.level_elapsed >= 1.9 and main.level_elapsed <= 2.2, "level time counts while playing")
	var stamped: float = main.level_elapsed
	main.game.toggle_pause()
	main._process(3.0)
	t.assert_eq(main.level_elapsed, stamped, "pause does not count")
	main.game.toggle_pause()
	main.journey_card.visible = true
	main._process(4.0)
	t.assert_eq(main.level_elapsed, stamped, "a story card does not count")
	main.journey_card.visible = false
	main.route_notebook.visible = true
	main._process(2.0)
	t.assert_eq(main.level_elapsed, stamped, "the roadbook does not count")
	main.route_notebook.visible = false
	main._process(1.0)
	t.assert_true(main.level_elapsed > stamped, "time resumes after the popup closes")
	t.assert_eq(MeasureText.format_duration(12.0 * 60.0 + 34.0), "用时 12 分 34 秒", "duration reads as minutes and seconds")
	t.assert_eq(MeasureText.format_duration(29.0 * 60.0 + 50.0), "用时 29 分 50 秒", "two-digit minutes keep the spaces")
	t.assert_eq(MeasureText.format_duration(60.0), "用时 1 分 0 秒", "a whole minute still has both units")
	main.move_count = 226
	main.level_elapsed = 12.0 * 60.0 + 34.0
	main.first_journey = FirstJourney.new()
	main._on_level_completed()
	var level_one := _plain(main.journey_card.body_label.text)
	t.assert_true(level_one.contains("这次走了 226 步"), "level 1 settlement names the steps")
	t.assert_true(level_one.contains("用时 12 分 34 秒"), "level 1 settlement names the time")
	main.level_elapsed = 29.0 * 60.0 + 50.0
	main.move_count = 40
	main._on_level_completed()
	t.assert_true(_plain(main.journey_card.body_label.text).replace("\n", "").contains("29 分 50 秒"), "level 1 settlement keeps spaces around a two-digit minute")
	main.free()
	var chapter := MogaoChapter.new()
	t.add_child(chapter)
	chapter.level_elapsed = 0.0
	chapter._process(1.5)
	t.assert_true(chapter.level_elapsed >= 1.4, "cave time counts while playing")
	var cave_stamp: float = chapter.level_elapsed
	chapter.show_card("note", "记", "看一眼", "继续")
	chapter._process(3.0)
	t.assert_eq(chapter.level_elapsed, cave_stamp, "a cave card does not count")
	chapter.close_card()
	chapter._process(0.5)
	t.assert_true(chapter.level_elapsed > cave_stamp, "cave time resumes")
	chapter.level_elapsed = 75.0
	chapter.model.moves = 18
	chapter.model.room = 2
	chapter.model.rescued = true
	chapter.model.player = chapter.model.exit_cell
	chapter.interact()
	var level_two := _plain(chapter.card_body.text).replace("\n", "")
	t.assert_true(level_two.contains("这次走了 18 步"), "level 2 settlement names the steps")
	t.assert_true(level_two.contains("用时 1 分 15 秒"), "level 2 settlement names the time")
	chapter.close_card()
	chapter.mode = "playing"
	chapter.level_elapsed = 29.0 * 60.0 + 50.0
	chapter.model.moves = 18
	chapter.model.room = 2
	chapter.model.rescued = true
	chapter.model.player = chapter.model.exit_cell
	chapter.interact()
	var long_time := _plain(chapter.card_body.text).replace("\n", "")
	t.assert_true(long_time.contains("29 分 50 秒"), "level 2 settlement keeps spaces around a two-digit minute")
	chapter.free()


static func _beacon_hint(t: Node) -> void:
	SaveManager.clear_save()
	var main := MainScript.new()
	t.add_child(main)
	var maze := MazeGenerator.new(FirstJourney.SIZE.x, FirstJourney.SIZE.y)
	var journey := FirstJourney.new()
	journey.build(maze)
	journey.map_seed = 7
	main.maze = maze
	main.first_journey = journey
	main.game.start_game()
	t.assert_true(journey.roadbook_ranges().is_empty(), "the minimap stays clear before the beacon")
	t.assert_true(main._draw_context()["survey_ranges"].is_empty(), "the side map has no circles yet")
	main.player.pos = FirstJourney.BEACON
	main._mark_visited(FirstJourney.BEACON)
	t.assert_true(not main.route_notebook.visible, "lighting the beacon does not open the roadbook")
	t.assert_true(not main.journey_card.visible, "lighting the beacon does not open a card")
	t.assert_eq(str(main.combat_log[main.combat_log.size() - 1]), JourneyBranches.BEACON_HINT, "the hint is the bottom line")
	var book: Array = journey.roadbook_ranges()
	var shown: Array = main._draw_context()["survey_ranges"]
	t.assert_eq(shown.size(), 2, "both circles appear after the beacon")
	for i in 2:
		t.assert_eq(shown[i]["cell"], book[i]["cell"], "minimap and roadbook share the center")
		t.assert_eq(str(shown[i]["kind"]), "area", "unfound marks are circles")
		var rect := UIPanel.survey_circle_rect(shown[i]["cell"], float(shown[i]["radius"]), Vector2(40, 180), 5.0)
		t.assert_eq(rect.size, Vector2(20, 20), "the circle keeps its full radius")
	var maze_rect := Rect2(40, 180, 17 * 5, 13 * 5)
	var edge := UIPanel.survey_circle_rect(Vector2i(0, 13), 2.0, maze_rect.position, 5.0)
	t.assert_eq(edge.size, Vector2(20, 20), "an edge circle is not cropped")
	t.assert_true(not maze_rect.encloses(edge), "the caravan circle may extend past the map bitmap")
	journey.caravan_found = true
	var found: Array = main._draw_context()["survey_ranges"]
	t.assert_eq(str(found[0]["kind"]), "found", "finding the caravan turns its minimap mark into a point")
	t.assert_eq(str(found[1]["kind"]), "area", "the stele circle remains")
	main.player.pos = Vector2i(7, 11)
	main._try_move(MazeGenerator.N)
	t.assert_eq(str(main.combat_log[main.combat_log.size() - 1]), JourneyBranches.CLIFF_HINT, "the south cliff explains the way up")
	var logs_before: int = main.combat_log.size()
	main._bump_wall_at = -1.0
	main._held_bump_key = ""
	main._try_move(MazeGenerator.N)
	t.assert_eq(main.combat_log.size(), logs_before, "the cliff hint does not repeat")
	main.free()


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
