extends Node

const PathGuideScript = preload("res://scripts/path_guide.gd")
const MainScript = preload("res://scripts/main.gd")

var passed := 0
var failed := 0

func _ready() -> void:
	if DataLoader.player_stats.is_empty():
		DataLoader._load_all()
	print("=== 敦煌迷途 自动测试 ===\n")
	test_json_loading()
	test_maze_generation()
	test_terrain_system()
	test_monster_data()
	test_level_data()
	test_combat_math()
	test_item_data()
	test_item_entity()
	test_player_buffs()
	test_key_tracker()
	test_combat_flow()
	test_dodge_single_roll()
	test_save_manager()
	test_entity_spawner()
	test_level_stats()
	test_inventory_clear()
	test_path_guide()
	test_inventory_slot()
	test_asset_registry()
	test_game_director()
	test_ui_layout_director()
	test_pause_state()
	test_difficulty_hitboxes()
	test_mobile_control_bounds()
	test_realtime_monster_intent()
	test_realtime_player_attack()
	test_web_font_payload()
	print("\n=== 测试完成: %d 通过, %d 失败 ===" % [passed, failed])
	get_tree().quit(failed)

func assert_eq(a, b, desc: String):
	if a == b:
		passed += 1
		print("  PASS: %s" % desc)
	else:
		failed += 1
		print("  FAIL: %s (got %s, expected %s)" % [desc, str(a), str(b)])

func assert_true(val: bool, desc: String):
	if val:
		passed += 1
		print("  PASS: %s" % desc)
	else:
		failed += 1
		print("  FAIL: %s" % desc)

func _make_data_loader() -> Node:
	var dl = Node.new()
	dl.set_script(load("res://scripts/data_loader.gd"))
	return dl

func test_json_loading():
	print("\n[TEST] JSON Loading")
	var dl = _make_data_loader()
	dl._ready()

	assert_true(not dl.player_stats.is_empty(), "player_stats loaded")
	assert_true(dl.player_stats.has("max_hp"), "player_stats has max_hp")
	assert_true(dl.player_stats.has("base_atk"), "player_stats has base_atk")
	assert_true(dl.player_stats.has("move_speed"), "player_stats has move_speed")
	assert_true(not dl.monster_data.is_empty(), "monster_data loaded")
	assert_true(not dl.terrain_data.is_empty(), "terrain_data loaded")
	assert_true(not dl.level_data.is_empty(), "level_data loaded")
	assert_eq(dl.level_data.size(), 3, "3 levels loaded")
	dl.free()

func test_maze_generation():
	print("\n[TEST] Maze Generation")
	var maze = MazeGenerator.new(10, 8)
	maze.generate()
	assert_eq(maze.grid.size(), 8, "grid has 8 rows")
	assert_eq(maze.grid[0].size(), 10, "grid has 10 columns")
	assert_true(maze.grid[0][0] != 0, "start cell is carved")
	assert_true(maze.grid[7][9] != 0, "end cell is carved")
	assert_true(maze.can_move(0, 0, MazeGenerator.E) or maze.can_move(0, 0, MazeGenerator.S), "start cell has exit")

func test_terrain_system():
	print("\n[TEST] Terrain System")
	var maze = MazeGenerator.new(15, 12)
	maze.generate()
	assert_eq(maze.terrain.size(), 12, "terrain grid has 12 rows")
	assert_eq(maze.terrain[0].size(), 15, "terrain grid has 15 columns")
	assert_eq(maze.get_terrain(0, 0), MazeGenerator.Terrain.ANCIENT_ROAD, "start is ANCIENT_ROAD")
	assert_eq(maze.get_terrain(14, 11), MazeGenerator.Terrain.OASIS, "end is OASIS")
	assert_eq(maze.get_terrain_name(0, 0), "古道", "start terrain name is 古道")
	assert_eq(maze.TERRAIN_KEY.size(), 5, "5 terrain keys defined")

func test_monster_data():
	print("\n[TEST] Monster Data")
	var dl = _make_data_loader()
	dl._ready()

	for key in ["sand", "desert", "grotto", "oasis", "ancient_road"]:
		var def = dl.get_monster_def(key)
		assert_true(not def.is_empty(), "monster def exists for %s" % key)
		assert_true(def.has("hp"), "%s has hp" % key)
		assert_true(def.has("atk"), "%s has atk" % key)
		assert_true(def.has("name"), "%s has name" % key)
		assert_true(def.has("xp"), "%s has xp" % key)
	dl.free()

func test_level_data():
	print("\n[TEST] Level Data")
	var dl = _make_data_loader()
	dl._ready()

	var levels = dl.get_level_data()
	assert_eq(levels.size(), 3, "3 levels")
	assert_eq(levels[0].get("name", ""), "汉唐古道", "level 1 name")
	assert_eq(levels[1].get("name", ""), "无人区", "level 2 name")
	assert_eq(levels[2].get("name", ""), "三危山", "level 3 name")
	assert_eq(levels[0].get("maze_width", 0), 25, "level 1 width")
	assert_eq(levels[1].get("maze_width", 0), 30, "level 2 width")
	assert_eq(levels[2].get("maze_width", 0), 35, "level 3 width")
	var grotto_effect = levels[0].get("terrain_effect", {}).get("grotto", {})
	assert_true(grotto_effect.has("reveal_penalty"), "level 1 grotto has reveal_penalty")
	dl.free()

func test_combat_math():
	print("\n[TEST] Combat Math")
	var player = PlayerController.new()
	player.atk = 5
	player.crit_chance = 0.0
	player.crit_multiplier = 2
	var roll = player.roll_damage()
	assert_true(roll.has("damage"), "roll_damage returns damage key")
	assert_true(roll.has("is_crit"), "roll_damage returns is_crit key")
	assert_true(roll.damage >= 4 and roll.damage <= 7, "player damage in range 4-7 (atk=5)")
	assert_eq(roll.is_crit, false, "no crit when crit_chance=0")
	assert_eq(maxi(3, 5), 5, "maxi returns larger value")

func test_item_data():
	print("\n[TEST] Item Data")
	var dl = _make_data_loader()
	dl._ready()

	assert_true(not dl.item_data.is_empty(), "item_data loaded")
	assert_eq(dl.item_data.size(), 12, "12 items loaded")

	var heal_def = dl.get_item_def("heal_scroll")
	assert_true(not heal_def.is_empty(), "heal_scroll def exists")
	assert_eq(heal_def.get("type", ""), "heal", "heal_scroll type is heal")
	assert_eq(heal_def.get("value", 0), 8, "heal_scroll value is 8")

	var shield_def = dl.get_item_def("iron_talisman")
	assert_eq(shield_def.get("type", ""), "defense", "iron_talisman type is defense")
	assert_eq(shield_def.get("value", 0), 3, "iron_talisman value is 3")
	assert_eq(shield_def.get("duration", 0), 5, "iron_talisman duration is 5")

	var arrow_def = dl.get_item_def("piercing_arrow")
	assert_eq(arrow_def.get("type", ""), "attack", "piercing_arrow type is attack")
	assert_eq(arrow_def.get("value", 0), 3, "piercing_arrow value is 3")

	assert_true(dl.get_item_def("nonexistent").is_empty(), "nonexistent item returns empty")
	dl.free()

func test_item_entity():
	print("\n[TEST] Item Entity")
	var dl = _make_data_loader()
	dl._ready()

	var item = ItemEntity.new()
	item.setup("heal_scroll", Vector2i(3, 4))
	assert_eq(item.item_key, "heal_scroll", "item key set")
	assert_eq(item.pos, Vector2i(3, 4), "item pos set")
	assert_eq(item.item_type, "heal", "item type from def")
	assert_eq(item.display_name, "疗伤卷", "heal scroll display name")

	var family = ItemEntity.new()
	family.setup("family_1", Vector2i(1, 2))
	assert_eq(family.display_name, "乐僔", "family display name")
	family.free()
	item.free()
	dl.free()

func test_player_buffs():
	print("\n[TEST] Player Buffs")
	var player = PlayerController.new()
	player.atk = 5
	player.max_hp = 20
	player.hp = 20

	var msg = player.apply_item("piercing_arrow")
	assert_true("攻击" in msg, "attack item returns log message")
	assert_eq(player.temp_atk_bonus, 3, "attack buff applied")
	assert_eq(player.buff_timer, 5, "attack buff timer set")

	player.tick_buff()
	player.tick_buff()
	player.tick_buff()
	player.tick_buff()
	player.tick_buff()
	assert_eq(player.temp_atk_bonus, 0, "attack buff expired after timer")

	msg = player.apply_item("iron_talisman")
	assert_eq(player.temp_def_bonus, 3, "defense buff applied")

	msg = player.apply_item("heal_scroll")
	assert_true(player.hp > 0, "heal item restores hp")

func test_key_tracker():
	print("\n[TEST] Key Tracker")
	var tracker = KeyTracker.new()
	tracker.setup(3)
	assert_eq(tracker.get_remaining(), 3, "3 keys required initially")
	tracker.add_key()
	tracker.add_key()
	assert_eq(tracker.get_progress(), "2/3", "progress after 2 keys")
	assert_true(not tracker.has_all_keys(), "not all keys yet")
	tracker.add_key()
	assert_true(tracker.has_all_keys(), "all keys collected")
	assert_eq(tracker.get_remaining(), 0, "0 remaining")

func test_combat_flow():
	print("\n[TEST] Combat Flow")
	var player = PlayerController.new()
	player.max_hp = 20
	player.hp = 20
	player.dodge_chance = 0.0

	var monster = MonsterEntity.new()
	monster.hp = 10
	monster.max_hp = 10
	monster.atk = 3

	var roll = player.roll_damage()
	monster.take_damage(roll.damage)
	assert_true(monster.hp < 10, "monster takes damage")

	var result = player.take_damage(5)
	assert_true(not result.dodged, "no dodge with 0 dodge chance")
	assert_eq(result.damage_taken, 5, "player takes 5 damage")
	assert_eq(player.hp, 15, "player hp reduced")

func test_dodge_single_roll():
	print("\n[TEST] Dodge Single Roll")
	var player = PlayerController.new()
	player.max_hp = 20
	player.hp = 20
	player.dodge_chance = 1.0
	player.temp_def_bonus = 0

	var result = player.take_damage(10)
	assert_true(result.dodged, "guaranteed dodge")
	assert_eq(player.hp, 20, "hp unchanged on dodge")
	assert_eq(result.damage_taken, 0, "zero damage on dodge")

func test_save_manager():
	print("\n[TEST] Save Manager")
	SaveManager.clear_save()
	assert_true(not SaveManager.has_save(), "no save after clear")

	var ok = SaveManager.save_progress(1, "hard", 3, 12)
	assert_true(ok, "save succeeds")
	assert_true(SaveManager.has_save(), "save file exists")

	var data = SaveManager.load_progress()
	assert_eq(int(data.get("level_index", -1)), 1, "saved level index")
	assert_eq(str(data.get("difficulty", "")), "hard", "saved difficulty")
	assert_eq(int(data.get("player_level", 0)), 3, "saved player level")
	assert_eq(int(data.get("player_xp", 0)), 12, "saved player xp")
	SaveManager.clear_save()

func test_entity_spawner():
	print("\n[TEST] Entity Spawner")
	var dl = _make_data_loader()
	dl._ready()
	DataLoader.set_difficulty("normal")

	var root = Node.new()
	var maze = MazeGenerator.new(12, 10)
	maze.generate()

	var monsters = EntitySpawner.spawn_monsters(root, maze, 12, 10, 0.1, 1.0, func(_m): pass)
	assert_true(monsters.size() > 0, "monsters spawned")
	assert_true(monsters.size() <= int(12 * 10 * 0.1) + 1, "monster count near target")

	var items = EntitySpawner.spawn_items(root, maze, 12, 10, monsters, 2)
	var key_count := 0
	for it in items:
		if it.item_type == "key":
			key_count += 1
	assert_eq(key_count, 2, "2 family keys spawned")

	root.free()
	dl.free()

func test_level_stats():
	print("\n[TEST] Level Stats")
	var player = PlayerController.new()
	player.level = 3
	player.apply_base_stats(20, 5)
	assert_eq(player.max_hp, 24, "level 3 adds +4 max hp")
	assert_eq(player.atk, 7, "level 3 adds +2 atk")
	assert_eq(player.hp, 24, "hp refilled to max")

func test_inventory_clear():
	print("\n[TEST] Inventory Clear")
	var inv = Inventory.new()
	inv.add_item("heal_scroll")
	inv.add_item("iron_talisman")
	assert_eq(inv.get_count(), 2, "two items added")
	inv.clear()
	assert_eq(inv.get_count(), 0, "inventory cleared")

func test_path_guide():
	print("\n[TEST] Path Guide")
	var maze = MazeGenerator.new(5, 5)
	maze.generate(42, 1)
	var from := Vector2i(0, 0)
	var to := Vector2i(maze.width - 1, maze.height - 1)
	var path: Array = PathGuideScript.bfs_path(maze, from, to)
	assert_true(path.size() >= 2, "path exists from start to exit")
	assert_eq(path[0], from, "path starts at origin")
	var dir: int = PathGuideScript.next_direction(maze, from, to)
	assert_true(dir >= 0, "next direction found")

func test_inventory_slot():
	print("\n[TEST] Inventory Slot Use")
	var inv = Inventory.new()
	inv.add_item("heal_scroll")
	inv.add_item("iron_talisman")
	var used := inv.use_item(1)
	assert_eq(used, "iron_talisman", "uses selected slot 1")
	assert_eq(inv.get_count(), 1, "one item remains")
	assert_eq(inv.items[0], "heal_scroll", "slot 0 item kept")

func test_asset_registry():
	print("\n[TEST] Asset Registry")
	var dj := AssetRegistry.character_sprite_path("dj")
	assert_true(dj.begins_with("res://"), "character path valid")
	assert_true(AssetRegistry.character_sprite_path("dj", true).contains("high_quality"), "HQ character preferred")
	assert_true(ResourceLoader.exists(AssetRegistry.item_sprite_path("heal")), "heal item exists")
	assert_eq(AssetRegistry.CELL_SPRITE_PX, 16, "cell sprite standard")

func test_game_director():
	print("\n[TEST] Game Director")
	SaveManager.clear_save()
	assert_true(not GameDirector.needs_new_journey_confirm("normal"), "no save no confirm")
	SaveManager.save_progress(0, "normal", 1, 0)
	assert_true(not GameDirector.needs_new_journey_confirm("normal"), "same diff no confirm")
	assert_true(GameDirector.needs_new_journey_confirm("hard"), "diff change needs confirm")
	SaveManager.clear_save()

func test_ui_layout_director():
	print("\n[TEST] UI Layout Director")
	var portrait := UILayoutDirector.compute(Vector2(390, 844), true)
	assert_true(portrait.is_portrait(), "390x844 is portrait")
	assert_eq(portrait.maze_mode, LayoutProfile.MazeMode.FOLLOW, "portrait uses follow")
	assert_true(portrait.hud_rect.size.y >= 108.0, "portrait hud min height")
	assert_true(portrait.controls_rect.size.y > 0.0, "portrait touch controls")
	assert_true(portrait.maze_rect.size.y > 200.0, "portrait maze area")

	var desktop := UILayoutDirector.compute(Vector2(1280, 720), false)
	assert_eq(desktop.mode, LayoutProfile.Mode.DESKTOP_SIDE, "1280x720 desktop side")
	assert_true(desktop.is_side_hud(), "desktop side hud")
	assert_eq(desktop.maze_mode, LayoutProfile.MazeMode.FIT_FULL, "desktop fit full")
	assert_true(desktop.hud_rect.size.x >= 300.0, "desktop HUD stays readable")

	var large_desktop := UILayoutDirector.compute(Vector2(1920, 1080), false)
	assert_true(large_desktop.ui_scale > 1.0, "large desktop UI scales with browser")
	assert_true(large_desktop.maze_rect.end.x == large_desktop.hud_rect.position.x, "desktop regions meet without gap")

	var tablet := UILayoutDirector.compute(Vector2(800, 600), true)
	assert_eq(tablet.mode, LayoutProfile.Mode.TABLET_LANDSCAPE, "800x600 tablet landscape")
	assert_eq(tablet.maze_mode, LayoutProfile.MazeMode.FOLLOW, "tablet follow")

	var compact := UILayoutDirector.compute(Vector2(360, 780), true)
	assert_eq(compact.mode, LayoutProfile.Mode.PORTRAIT_COMPACT, "narrow portrait compact")
	assert_eq(compact.ui_scale, 2.0, "portrait ui scale 2x")

	var hidpi_phone := UILayoutDirector.compute(Vector2(780, 1688), true)
	assert_true(hidpi_phone.hud_rect.size.y >= 320.0, "HiDPI portrait HUD scales in physical pixels")
	assert_true(hidpi_phone.controls_rect.size.y >= 400.0, "HiDPI portrait controls scale in physical pixels")


func test_pause_state():
	print("\n[TEST] Pause State")
	var state := GameState.new()
	state.start_game()
	state.toggle_pause()
	assert_true(state.is_paused(), "playing toggles to paused")
	assert_true(not state.can_move(), "paused state blocks movement")
	state.toggle_pause()
	assert_true(state.is_playing(), "paused toggles back to playing")


func test_difficulty_hitboxes():
	print("\n[TEST] Difficulty Hitboxes")
	var renderer := MazeRenderer.new()
	for vp in [Vector2(1280, 720), Vector2(390, 844)]:
		var cards := renderer.get_difficulty_card_rects(vp)
		assert_eq(cards.size(), 3, "three difficulty cards at %s" % vp)
		for i in cards.size():
			assert_true(Rect2(Vector2.ZERO, vp).encloses(cards[i]), "difficulty card %d stays in viewport" % i)
			if i > 0:
				assert_true(not cards[i - 1].intersects(cards[i]), "difficulty cards do not overlap")


func test_mobile_control_bounds():
	print("\n[TEST] Mobile Control Bounds")
	var profile := UILayoutDirector.compute(Vector2(390, 844), true)
	var controls := MobileControls.new()
	controls.apply_layout(profile)
	assert_true(controls.btn_radius >= 32.0, "portrait dpad has a large visual target")
	assert_true(controls.func_btn_size >= 54.0, "portrait tool buttons meet touch target size")
	for entry in controls._dpad_centers:
		var center: Vector2 = entry.pos
		var hit := Rect2(center - Vector2.ONE * controls.btn_radius, Vector2.ONE * controls.btn_radius * 2.0)
		assert_true(profile.controls_rect.encloses(hit), "portrait dpad stays in controls area")
	for action in controls._func_centers:
		var center: Vector2 = controls._func_centers[action]
		var half := controls.func_btn_size * 0.5
		var hit := Rect2(center - Vector2.ONE * half, Vector2.ONE * half * 2.0)
		assert_true(profile.controls_rect.encloses(hit), "portrait function button stays in controls area")
		for entry in controls._dpad_centers:
			var dpad_hit := Rect2((entry.pos as Vector2) - Vector2.ONE * controls.btn_radius, Vector2.ONE * controls.btn_radius * 2.0)
			assert_true(not hit.intersects(dpad_hit), "tool button does not overlap dpad")
	controls.free()


func test_realtime_monster_intent():
	print("\n[TEST] Realtime Monster Intent")
	var maze := MazeGenerator.new(2, 1)
	maze.grid = [[MazeGenerator.E, MazeGenerator.W]]
	var monster := MonsterEntity.new()
	monster.pos = Vector2i(0, 0)
	monster.move_interval = 0.0
	var target := Vector2i(1, 0)
	var occupied := {target: true}
	monster.plan_next_move(maze, occupied, target)
	assert_eq(monster.next_move_dir, MazeGenerator.E, "monster telegraphs attack toward player")
	var result := monster.try_move(maze, occupied, target, 0.1)
	assert_true(result.attacked, "monster attacks when intent reaches player")
	assert_eq(monster.pos, Vector2i(0, 0), "attacking monster remains adjacent")
	monster.free()


func test_web_font_payload():
	print("\n[TEST] Web Font Payload")
	var path := "res://assets/fonts/NotoSansSC-GameSubset.ttf"
	assert_true(FileAccess.file_exists(path), "subset font exists")
	assert_true(FileAccess.get_file_as_bytes(path).size() < 400_000, "subset font stays below 400 KB")


func test_realtime_player_attack():
	print("\n[TEST] Realtime Player Attack")
	var controller = MainScript.new()
	controller.first_combat_warned = true
	controller.player = PlayerController.new()
	controller.player.hp = 100
	controller.player.atk = 5
	controller.player.crit_chance = 0.0
	controller.maze = MazeGenerator.new(2, 1)
	controller.maze.grid = [[MazeGenerator.E, MazeGenerator.W]]
	var monster := MonsterEntity.new()
	monster.hp = 100
	monster.atk = 10
	monster.pos = Vector2i(1, 0)
	controller.monsters.append(monster)
	assert_true(not controller._try_move(MazeGenerator.E), "bump attacks without moving")
	assert_eq(controller.player.pos, Vector2i.ZERO, "player never overlaps enemy")
	assert_true(monster.hp < 100, "direction input damages adjacent enemy")
	assert_eq(controller.player.hp, 100, "player attack does not trigger immediate retaliation")
	var remaining_hp := monster.hp
	controller._try_move(MazeGenerator.E)
	assert_eq(monster.hp, remaining_hp, "attack cooldown blocks input spam")
	controller.player.free()
	monster.free()
	controller.free()
