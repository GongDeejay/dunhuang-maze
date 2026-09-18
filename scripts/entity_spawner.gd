class_name EntitySpawner
extends RefCounted

const POTTERY_KEYS: Array[String] = ["pottery_heal", "pottery_trap", "pottery_loot"]
const DIRECT_KEYS: Array[String] = ["heal_scroll", "piercing_arrow", "iron_talisman"]
const FAMILY_KEYS: Array[String] = ["family_1", "family_2", "family_3"]

static func spawn_monsters(
	parent: Node,
	maze: MazeGenerator,
	maze_width: int,
	maze_height: int,
	density: float,
	scale: float,
	on_defeated: Callable,
) -> Array[MonsterEntity]:
	for m in parent.get_children():
		if m is MonsterEntity and is_instance_valid(m):
			m.queue_free()

	var monsters: Array[MonsterEntity] = []
	var occupied: Dictionary = {
		Vector2i(0, 0): true,
		Vector2i(maze_width - 1, maze_height - 1): true,
	}
	var target_count := int(maze_width * maze_height * density)
	var spawned := 0
	var attempts := 0
	var max_attempts := target_count * 20

	while spawned < target_count and attempts < max_attempts:
		attempts += 1
		var pos := Vector2i(randi_range(0, maze_width - 1), randi_range(0, maze_height - 1))
		if occupied.has(pos):
			continue
		occupied[pos] = true

		var terrain_key: String = MazeGenerator.TERRAIN_KEY[maze.get_terrain(pos.x, pos.y)]
		var monster := MonsterEntity.new()
		var diff := DataLoader.get_difficulty()
		monster.setup(terrain_key, pos, scale * diff.get("monster_hp_multiplier", 1.0))
		monster.atk = int(monster.atk * diff.get("monster_atk_multiplier", 1.0))
		var move_speed: float = DataLoader.player_stats.get("move_speed", 1.0)
		monster.move_interval /= move_speed
		if on_defeated.is_valid():
			monster.defeated.connect(on_defeated)
		parent.add_child(monster)
		monsters.append(monster)
		spawned += 1

	return monsters

static func spawn_items(
	parent: Node,
	maze: MazeGenerator,
	maze_width: int,
	maze_height: int,
	monsters: Array[MonsterEntity],
	key_count: int,
	family_keys: Array = FAMILY_KEYS,
) -> Array[ItemEntity]:
	for child in parent.get_children():
		if child is ItemEntity and is_instance_valid(child):
			child.queue_free()

	var items: Array[ItemEntity] = []
	var occupied: Dictionary = {
		Vector2i(0, 0): true,
		Vector2i(maze_width - 1, maze_height - 1): true,
	}
	for m in monsters:
		if is_instance_valid(m):
			occupied[m.pos] = true

	var diff := DataLoader.get_difficulty()
	var pottery_ratio: float = diff.get("pottery_ratio", 0.70)
	var drop_mult: float = diff.get("item_drop_multiplier", 1.0)
	var target_count := int(maze_width * maze_height * 0.04 * drop_mult)
	var spawned := 0
	var attempts := 0
	var max_attempts := target_count * 20

	while spawned < target_count and attempts < max_attempts:
		attempts += 1
		var pos := Vector2i(randi_range(0, maze_width - 1), randi_range(0, maze_height - 1))
		if occupied.has(pos):
			continue
		occupied[pos] = true

		var key: String
		if randf() < pottery_ratio:
			key = POTTERY_KEYS[randi_range(0, POTTERY_KEYS.size() - 1)]
		else:
			key = DIRECT_KEYS[randi_range(0, DIRECT_KEYS.size() - 1)]

		var item := ItemEntity.new()
		item.setup(key, pos)
		parent.add_child(item)
		items.append(item)
		spawned += 1

	var reachable := maze.get_reachable_cells()
	for i in key_count:
		var pos := Vector2i(randi_range(0, maze_width - 1), randi_range(0, maze_height - 1))
		var key_attempts := 0
		while (occupied.has(pos) or not reachable.has(pos)) and key_attempts < 100:
			pos = Vector2i(randi_range(0, maze_width - 1), randi_range(0, maze_height - 1))
			key_attempts += 1
		if not occupied.has(pos) and reachable.has(pos):
			occupied[pos] = true
			var family_item := ItemEntity.new()
			family_item.setup(family_keys[i % family_keys.size()], pos)
			parent.add_child(family_item)
			items.append(family_item)

	for y in maze_height:
		for x in maze_width:
			if maze.get_terrain(x, y) == MazeGenerator.Terrain.GROTTO and randf() < 0.15:
				var grotto_pos := Vector2i(x, y)
				if not occupied.has(grotto_pos):
					occupied[grotto_pos] = true
					var grotto_key := POTTERY_KEYS[randi_range(0, POTTERY_KEYS.size() - 1)]
					var grotto_item := ItemEntity.new()
					grotto_item.setup(grotto_key, grotto_pos)
					parent.add_child(grotto_item)
					items.append(grotto_item)

	return items
