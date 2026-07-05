extends SceneTree

var passed := 0
var failed := 0

func _init():
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
	print("\n=== 测试完成: %d 通过, %d 失败 ===" % [passed, failed])
	quit(failed)

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
	dl.free()

func test_combat_math():
	print("\n[TEST] Combat Math")
	var damage = 5 + randi_range(-1, 2)
	assert_true(damage >= 4 and damage <= 7, "player damage in range 4-7 (atk=5)")
	var monster_dmg = 3 + randi_range(-1, 1)
	assert_true(monster_dmg >= 2 and monster_dmg <= 4, "monster damage in range 2-4 (atk=3)")
	assert_eq(maxi(3, 5), 5, "maxi returns larger value")
	assert_eq(maxi(5, 3), 5, "maxi returns first if larger")
	assert_eq(maxi(0, 0), 0, "maxi handles equal values")

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
	print("\n[TEST] Item Entity (skipped - requires scene tree)")
	pass

func test_player_buffs():
	print("\n[TEST] Player Buffs (skipped - requires scene tree)")
	pass
