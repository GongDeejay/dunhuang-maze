extends Node

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
	assert_eq(item.display_name, "疗伤卷", "item display name")
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
