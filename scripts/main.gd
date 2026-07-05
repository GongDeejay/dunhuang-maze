extends Node2D

@export var cell_size := 40
@export var wall_thickness := 4

var maze_width := 20
var maze_height := 15
var maze: MazeGenerator
var player: PlayerController
var monsters: Array[MonsterEntity] = []
var items: Array[ItemEntity] = []
var exit_pos := Vector2i(0, 0)
var move_count := 0
var game_won := false
var game_over := false

var combat_log: Array = []
var log_timer := 0.0

var visited: Dictionary = {}
var current_terrain_name := "古道"
var exit_blink_timer := 0.0
var exit_visible := true

var current_level_index := 0
var levels_data: Array = []
var level_monster_density := 0.12
var level_monster_scale := 1.0
var level_terrain_effects := {}
var level_key_count := 0

var game_state := "difficulty_select"
var selected_difficulty := "normal"
var difficulty_options := ["easy", "normal", "hard"]
var difficulty_names := {"easy": "行者", "normal": "商旅", "hard": "亡命"}

var inventory: Inventory
var key_tracker: KeyTracker
var ui_panel: UIPanel
var mobile_controls: MobileControls

var flash_tweens: Array[Tween] = []

func _ready():
	_ensure_data_loaded()
	_load_sprites()
	player = PlayerController.new()
	add_child(player)
	player.died.connect(_on_player_died)
	inventory = Inventory.new()
	key_tracker = KeyTracker.new()
	ui_panel = UIPanel.new()
	mobile_controls = MobileControls.new()
	mobile_controls.move_pressed.connect(_on_mobile_move)
	mobile_controls.action_pressed.connect(_on_mobile_action)
	add_child(mobile_controls)
	levels_data = DataLoader.get_level_data()
	if levels_data.is_empty():
		levels_data = [{"name": "未知", "maze_width": 20, "maze_height": 15, "monster_density": 0.12}]
	game_state = "difficulty_select"
	queue_redraw()

func _on_mobile_move(dir: int) -> void:
	if game_state == "difficulty_select":
		if dir == MazeGenerator.N:
			var idx = difficulty_options.find(selected_difficulty)
			idx = (idx - 1 + difficulty_options.size()) % difficulty_options.size()
			selected_difficulty = difficulty_options[idx]
			queue_redraw()
		elif dir == MazeGenerator.S:
			var idx = difficulty_options.find(selected_difficulty)
			idx = (idx + 1) % difficulty_options.size()
			selected_difficulty = difficulty_options[idx]
			queue_redraw()
		return

	if game_won or game_over:
		return

	if game_state == "playing":
		var moved = _try_move(dir)
		if moved:
			AudioManager.play_step()
			_apply_terrain_effect()
			var target = _get_monster_at(player.pos)
			if target != null:
				_combat(target)
			else:
				move_count += 1
			var item = _get_item_at(player.pos)
			if item != null:
				_pick_up_item(item)
			player.tick_buff()
			_mark_visited(player.pos)
			current_terrain_name = maze.get_terrain_name(player.pos.x, player.pos.y)
			if player.pos == exit_pos and not game_over:
				if key_tracker.has_all_keys():
					game_won = true
					AudioManager.play_victory()
				else:
					_add_log("家人还没到齐！还需要找到 %d 个人" % key_tracker.get_remaining())
			queue_redraw()

func _on_mobile_action(action: String) -> void:
	match action:
		"use_item":
			_use_item_from_inventory()
		"regenerate":
			if game_won:
				if current_level_index + 1 < levels_data.size():
					_new_game(current_level_index + 1)
				else:
					_new_game(0)
			elif game_over:
				_new_game(current_level_index)
			else:
				_new_game(current_level_index)
		"menu":
			game_state = "difficulty_select"
			queue_redraw()

func _ensure_data_loaded():
	if DataLoader.player_stats.is_empty():
		DataLoader._load_all()
	if DataLoader.player_stats.is_empty():
		push_warning("DataLoader: player_stats still empty after reload, using defaults")
		DataLoader.player_stats = {"max_hp": 20, "base_atk": 5, "reveal_radius": 3}

func _new_game(level_idx: int = -1):
	if level_idx >= 0:
		current_level_index = level_idx

	if levels_data.is_empty():
		levels_data = [{"name": "未知", "maze_width": 20, "maze_height": 15, "monster_density": 0.12, "key_count": 1}]

	var level = levels_data[current_level_index]
	maze_width = level.get("maze_width", 25)
	maze_height = level.get("maze_height", 20)
	level_monster_density = level.get("monster_density", 0.08)
	level_monster_scale = level.get("monster_scale", 1.0)
	level_terrain_effects = level.get("terrain_effect", {})
	level_key_count = level.get("key_count", 2)
	var waypoint_count = level.get("waypoints", 3)

	maze = MazeGenerator.new(maze_width, maze_height)
	maze.generate(-1, waypoint_count)

	var diff = DataLoader.get_difficulty()
	var hp_mult = diff.get("hp_multiplier", 1.0)
	var atk_mult = diff.get("atk_multiplier", 1.0)
	player.initialize(Vector2i(0, 0))
	player.max_hp = int(DataLoader.player_stats.get("max_hp", 18) * hp_mult)
	player.hp = player.max_hp
	player.atk = int(DataLoader.player_stats.get("base_atk", 5) * atk_mult)
	player.reveal_bonus = diff.get("reveal_radius_bonus", 0)
	exit_pos = Vector2i(maze_width - 1, maze_height - 1)
	move_count = 0
	game_won = false
	game_over = false
	visited = {}
	combat_log.clear()
	key_tracker.setup(level_key_count)
	_spawn_monsters()
	_spawn_items()
	_mark_visited(player.pos)
	current_terrain_name = maze.get_terrain_name(player.pos.x, player.pos.y)
	_add_log("进入 %s - 找到 %d 个家人，一起离开" % [level.get("name", ""), level_key_count])
	AudioManager.play_level_start()
	queue_redraw()

func _spawn_monsters():
	for m in monsters:
		if is_instance_valid(m):
			m.queue_free()
	monsters.clear()

	var occupied: Dictionary = {Vector2i(0, 0): true, Vector2i(maze_width - 1, maze_height - 1): true}
	var count = int(maze_width * maze_height * level_monster_density)

	for i in count:
		var pos = Vector2i(randi_range(0, maze_width - 1), randi_range(0, maze_height - 1))
		if occupied.has(pos):
			continue
		occupied[pos] = true

		var terrain_key = MazeGenerator.TERRAIN_KEY[maze.get_terrain(pos.x, pos.y)]
		var m = MonsterEntity.new()
		var diff = DataLoader.get_difficulty()
		m.setup(terrain_key, pos, level_monster_scale * diff.get("monster_hp_multiplier", 1.0))
		m.atk = int(m.atk * diff.get("monster_atk_multiplier", 1.0))
		m.defeated.connect(_on_monster_defeated)
		add_child(m)
		monsters.append(m)

func _spawn_items():
	for it in items:
		if is_instance_valid(it):
			it.queue_free()
	items.clear()

	var occupied: Dictionary = {Vector2i(0, 0): true, Vector2i(maze_width - 1, maze_height - 1): true}
	for m in monsters:
		if is_instance_valid(m):
			occupied[m.pos] = true

	var diff = DataLoader.get_difficulty()
	var pottery_ratio = diff.get("pottery_ratio", 0.70)
	var pottery_keys = ["pottery_heal", "pottery_trap", "pottery_loot"]
	var direct_keys = ["heal_scroll", "piercing_arrow", "iron_talisman"]

	var count = int(maze_width * maze_height * 0.04)
	for i in count:
		var pos = Vector2i(randi_range(0, maze_width - 1), randi_range(0, maze_height - 1))
		if occupied.has(pos):
			continue
		occupied[pos] = true

		var key: String
		if randf() < pottery_ratio:
			key = pottery_keys[randi_range(0, pottery_keys.size() - 1)]
		else:
			key = direct_keys[randi_range(0, direct_keys.size() - 1)]

		var it = ItemEntity.new()
		it.setup(key, pos)
		add_child(it)
		items.append(it)

	var reachable = maze.get_reachable_cells()
	for i in level_key_count:
		var pos = Vector2i(randi_range(0, maze_width - 1), randi_range(0, maze_height - 1))
		var attempts = 0
		while (occupied.has(pos) or not reachable.has(pos)) and attempts < 100:
			pos = Vector2i(randi_range(0, maze_width - 1), randi_range(0, maze_height - 1))
			attempts += 1
		if not occupied.has(pos) and reachable.has(pos):
			occupied[pos] = true
			var it = ItemEntity.new()
			it.setup("ancient_key", pos)
			add_child(it)
			items.append(it)

	var grotto_count = 0
	for y in maze_height:
		for x in maze_width:
			if maze.get_terrain(x, y) == MazeGenerator.Terrain.GROTTO:
				if randf() < 0.15:
					var pos = Vector2i(x, y)
					if not occupied.has(pos):
						occupied[pos] = true
						var key = pottery_keys[randi_range(0, pottery_keys.size() - 1)]
						var it = ItemEntity.new()
						it.setup(key, pos)
						add_child(it)
						items.append(it)
						grotto_count += 1

func _get_item_at(pos: Vector2i) -> ItemEntity:
	for it in items:
		if is_instance_valid(it) and it.pos == pos:
			return it
	return null

func _pick_up_item(item: ItemEntity) -> void:
	AudioManager.play_pickup()

	if item.item_type == "key":
		key_tracker.add_key()
		_add_log("获得 %s (%s)" % [item.display_name, key_tracker.get_progress()])
		items.erase(item)
		if is_instance_valid(item):
			item.queue_free()
		return

	if item.item_type == "container":
		var def = DataLoader.get_item_def(item.item_key)
		var contains: Array = def.get("contains", [])
		if contains.is_empty():
			_add_log("破瓦罐是空的...")
		else:
			var inner_key: String = contains.pick_random()
			var inner_def = DataLoader.get_item_def(inner_key)
			var inner_name: String = inner_def.get("name", "???")
			if inner_def.get("type", "") == "trap":
				var trap_damage: int = inner_def.get("value", 3)
				_add_log("破瓦罐: %s! -%d HP" % [inner_name, trap_damage])
				player.take_damage(trap_damage)
				_flash_player_hurt()
				_try_auto_heal()
			else:
				if inventory.is_full():
					_add_log("背包已满，丢弃 %s" % inner_name)
				else:
					inventory.add_item(inner_key)
					_add_log("破瓦罐: 获得 %s" % inner_name)
	else:
		if inventory.is_full():
			_add_log("背包已满，丢弃 %s" % item.display_name)
		else:
			inventory.add_item(item.item_key)
			_add_log("获得 %s" % item.display_name)

	items.erase(item)
	if is_instance_valid(item):
		item.queue_free()

func _get_monster_at(pos: Vector2i) -> MonsterEntity:
	for m in monsters:
		if is_instance_valid(m) and m.pos == pos:
			return m
	return null

func _combat(target: MonsterEntity) -> void:
	var damage_to_monster = player.roll_damage()
	var is_crit = damage_to_monster >= player.get_effective_atk() * player.crit_multiplier

	var damage_to_player = target.atk + randi_range(-1, 1)
	var is_dodged = randf() < player.dodge_chance

	AudioManager.play_hit()

	if is_crit:
		_add_log("暴击! 你攻击 %s 造成 %d 伤害" % [target.display_name, damage_to_monster])
	else:
		_add_log("你攻击 %s 造成 %d 伤害" % [target.display_name, damage_to_monster])
	target.take_damage(damage_to_monster)

	if is_dodged:
		_add_log("你闪避了 %s 的攻击!" % target.display_name)
	elif damage_to_player > 0:
		_add_log("%s 攻击你造成 %d 伤害" % [target.display_name, damage_to_player])
		player.take_damage(damage_to_player)
		_flash_player_hurt()
		_try_auto_heal()

func _on_monster_defeated(monster: MonsterEntity) -> void:
	_add_log("%s 被击败!" % monster.display_name)
	monsters.erase(monster)
	_animate_monster_death(monster)

func _on_player_died() -> void:
	AudioManager.play_death()
	game_over = true
	_add_log("你倒下了...")
	queue_redraw()

func _add_log(msg: String) -> void:
	combat_log.append(msg)
	if combat_log.size() > 4:
		combat_log.remove_at(0)
	log_timer = 3.0

func _unhandled_input(event: InputEvent) -> void:
	if game_state == "difficulty_select":
		if event.is_action_pressed("move_up"):
			var idx = difficulty_options.find(selected_difficulty)
			idx = (idx - 1 + difficulty_options.size()) % difficulty_options.size()
			selected_difficulty = difficulty_options[idx]
			queue_redraw()
		elif event.is_action_pressed("move_down"):
			var idx = difficulty_options.find(selected_difficulty)
			idx = (idx + 1) % difficulty_options.size()
			selected_difficulty = difficulty_options[idx]
			queue_redraw()
		elif event.is_action_pressed("regenerate") or event.is_action_pressed("move_right"):
			DataLoader.set_difficulty(selected_difficulty)
			game_state = "playing"
			_new_game(0)
		elif (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			var click_pos = event.position
			var vp = get_viewport_rect().size
			var min_dim = minf(vp.x, vp.y)
			var font_mult = clampf(min_dim / 400.0, 1.0, 2.5)
			var start_y = vp.y * 0.4
			for i in difficulty_options.size():
				var y = start_y + i * 80 * font_mult
				var btn_rect = Rect2(vp.x / 2 - 180 * font_mult, y - 10, 360 * font_mult, 65 * font_mult)
				if btn_rect.has_point(click_pos):
					selected_difficulty = difficulty_options[i]
					DataLoader.set_difficulty(selected_difficulty)
					game_state = "playing"
					_new_game(0)
					break
		return

	if game_won or game_over:
		if event.is_action_pressed("regenerate"):
			if game_won:
				if current_level_index + 1 < levels_data.size():
					_new_game(current_level_index + 1)
				else:
					_new_game(0)
			else:
				_new_game(current_level_index)
		return

	if event.is_action_pressed("regenerate"):
		_new_game(current_level_index)
		return

	# Use item from inventory
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_use_item_from_inventory()
		return

	# Return to main menu
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		game_state = "difficulty_select"
		queue_redraw()
		return

	var moved = false
	if event.is_action_pressed("move_up"):
		moved = _try_move(MazeGenerator.N)
	elif event.is_action_pressed("move_down"):
		moved = _try_move(MazeGenerator.S)
	elif event.is_action_pressed("move_left"):
		moved = _try_move(MazeGenerator.W)
	elif event.is_action_pressed("move_right"):
		moved = _try_move(MazeGenerator.E)

	if moved:
		AudioManager.play_step()
		_apply_terrain_effect()
		var target = _get_monster_at(player.pos)
		if target != null:
			_combat(target)
		else:
			move_count += 1
		var item = _get_item_at(player.pos)
		if item != null:
			_pick_up_item(item)
		player.tick_buff()
		_mark_visited(player.pos)
		current_terrain_name = maze.get_terrain_name(player.pos.x, player.pos.y)
		if player.pos == exit_pos and not game_over:
			if key_tracker.has_all_keys():
				game_won = true
				AudioManager.play_victory()
			else:
				_add_log("家人还没到齐！还需要找到 %d 个人" % key_tracker.get_remaining())
		queue_redraw()

func _apply_terrain_effect() -> void:
	var terrain_key = MazeGenerator.TERRAIN_KEY[maze.get_terrain(player.pos.x, player.pos.y)]
	if not level_terrain_effects.has(terrain_key):
		return
	var effect = level_terrain_effects[terrain_key]
	var diff = DataLoader.get_difficulty()
	if effect.has("move_damage") and effect.move_damage > 0:
		var dmg = int(effect.move_damage * diff.get("terrain_damage_multiplier", 1.0))
		player.take_damage(dmg)
		_add_log("%s: 受到 %d 环境伤害" % [effect.get("description", ""), dmg])
		_flash_player_hurt()
		_try_auto_heal()
	if effect.has("move_heal") and effect.move_heal > 0:
		var heal = int(effect.move_heal * diff.get("heal_multiplier", 1.0))
		player.heal(heal)
		_add_log("%s: 恢复 %d HP" % [effect.get("description", ""), heal])

func _use_item_from_inventory() -> void:
	if inventory.get_count() == 0:
		_add_log("背包是空的")
		return
	var key = inventory.use_item(0)
	if key == "":
		return
	var def = DataLoader.get_item_def(key)
	var type = def.get("type", "")
	var value = def.get("value", 0)
	var duration = def.get("duration", 0)
	match type:
		"heal":
			player.heal(value)
			_add_log("使用 %s: 恢复 %d HP" % [def.get("name", ""), value])
		"attack":
			player.temp_atk_bonus = value
			player.buff_timer = duration
			_add_log("使用 %s: 攻击+%d (%d回合)" % [def.get("name", ""), value, duration])
		"defense":
			player.temp_def_bonus = value
			player.buff_timer = duration
			_add_log("使用 %s: 防御+%d (%d回合)" % [def.get("name", ""), value, duration])
		"reveal":
			if value >= 99:
				player.temp_reveal_bonus = 999
			else:
				player.temp_reveal_bonus = value
				player.buff_timer = duration
			_add_log("使用 %s" % def.get("name", ""))
		_:
			_add_log("无法使用 %s" % def.get("name", ""))
	queue_redraw()

func _try_auto_heal() -> void:
	if player.hp <= 0:
		return
	var hp_ratio = float(player.hp) / float(player.max_hp)
	if hp_ratio > 0.3:
		return
	var key = inventory.use_first_heal()
	if key == "":
		return
	var def = DataLoader.get_item_def(key)
	player.heal(def.get("value", 0))
	_add_log("自动使用 %s: 恢复 %d HP" % [def.get("name", ""), def.get("value", 0)])
	queue_redraw()

func _try_move(dir: int) -> bool:
	if maze.can_move(player.pos.x, player.pos.y, dir):
		player.pos += Vector2i(MazeGenerator.DX[dir], MazeGenerator.DY[dir])
		player.moved.emit(player.pos)
		return true
	else:
		AudioManager.play_wall_hit()
	return false

func _mark_visited(pos: Vector2i) -> void:
	visited[pos] = true

func _is_revealed(pos: Vector2i) -> bool:
	var radius = DataLoader.player_stats.get("reveal_radius", 4) + player.reveal_bonus + player.get_effective_reveal_bonus()
	if player.get_effective_reveal_bonus() >= 999:
		return true
	return pos.distance_to(player.pos) <= radius

func _get_buff_display() -> String:
	var parts: Array = []
	if player.temp_atk_bonus > 0:
		parts.append("攻+%d(%d)" % [player.temp_atk_bonus, player.buff_timer])
	if player.temp_def_bonus > 0:
		parts.append("防+%d(%d)" % [player.temp_def_bonus, player.buff_timer])
	if player.temp_reveal_bonus > 0 and player.temp_reveal_bonus < 999:
		parts.append("视+%d(%d)" % [player.temp_reveal_bonus, player.buff_timer])
	if player.temp_reveal_bonus >= 999:
		parts.append("全图视野")
	if parts.is_empty():
		return ""
	return "Buff: " + " ".join(parts)

func _get_terrain_floor_color(t_key: String) -> Color:
	var cfg = DataLoader.get_terrain_config(t_key)
	return DataLoader.color_from_array(cfg.get("floor_color", [0.5, 0.5, 0.5]))

func _process(delta: float) -> void:
	if log_timer > 0:
		log_timer -= delta
		if log_timer <= 0:
			if combat_log.size() > 0:
				combat_log.remove_at(0)
	exit_blink_timer += delta
	if exit_blink_timer >= 2.0:
		exit_blink_timer = 0.0
		exit_visible = !exit_visible
	if game_state == "playing" and not game_won and not game_over:
		_move_monsters()
	queue_redraw()

func _move_monsters() -> void:
	var occupied: Dictionary = {player.pos: true}
	for m in monsters:
		if is_instance_valid(m):
			occupied[m.pos] = true
	for m in monsters:
		if is_instance_valid(m) and m.is_alive():
			m.try_move(maze, occupied)
			if m.pos == player.pos:
				_combat(m)

func _draw() -> void:
	if game_state == "difficulty_select":
		_draw_difficulty_select()
		return

	if maze == null or maze.grid.is_empty():
		_draw_error_screen()
		return

	var vp = get_viewport_rect().size
	var is_mobile_view = mobile_controls.is_mobile

	if is_mobile_view:
		_draw_mobile_view(vp)
	else:
		_draw_pc_view(vp)

func _draw_mobile_view(vp: Vector2) -> void:
	var is_portrait = mobile_controls.is_portrait
	var view_cols: int
	var view_rows: int

	if is_portrait:
		view_cols = 6
		view_rows = 10
	else:
		view_cols = 10
		view_rows = 6

	var game_w: float = vp.x
	var game_h: float = vp.y

	var cell_w: float = game_w / view_cols
	var cell_h: float = game_h / view_rows
	var cell_sz: float = minf(cell_w, cell_h)

	var center_x: int = player.pos.x
	var center_y: int = player.pos.y
	var half_cols: int = view_cols / 2
	var half_rows: int = view_rows / 2

	var start_x: int = center_x - half_cols
	var start_y: int = center_y - half_rows

	var wall_w: float = maxf(cell_sz * 0.08, 3.0)

	draw_rect(Rect2(0, 0, game_w, game_h), Color(0.12, 0.10, 0.08))

	for vy in view_rows:
		for vx in view_cols:
			var gx: int = start_x + vx
			var gy: int = start_y + vy

			var screen_x: float = vx * cell_sz
			var screen_y: float = vy * cell_sz

			if gx < 0 or gx >= maze_width or gy < 0 or gy >= maze_height:
				draw_rect(Rect2(screen_x, screen_y, cell_sz, cell_sz), Color(0.15, 0.12, 0.10))
				continue

			var t = maze.get_terrain(gx, gy)
			var t_key = MazeGenerator.TERRAIN_KEY[t]
			var cfg = DataLoader.get_terrain_config(t_key)
			var floor_color = DataLoader.color_from_array(cfg.get("floor_color", [0.8, 0.8, 0.8]))

			if not _is_revealed(Vector2i(gx, gy)) and not visited.get(Vector2i(gx, gy), false):
				floor_color = Color(0.15, 0.12, 0.10)

			# Draw floor to fill entire cell first
			draw_rect(Rect2(screen_x, screen_y, cell_sz, cell_sz), floor_color)

			# Draw terrain sprite if available
			var terrain_sprite = terrain_sprites.get(t_key)
			if terrain_sprite and _is_revealed(Vector2i(gx, gy)):
				draw_texture_rect(terrain_sprite, Rect2(screen_x, screen_y, cell_sz, cell_sz), false)

			var cell = maze.grid[gy][gx]
			var wall_color = Color(0.12, 0.08, 0.05)

			# Only draw walls where there is NO passage (bit NOT set)
			if (cell & MazeGenerator.N) == 0:
				draw_rect(Rect2(screen_x, screen_y, cell_sz, wall_w), wall_color)
			if (cell & MazeGenerator.S) == 0:
				draw_rect(Rect2(screen_x, screen_y + cell_sz - wall_w, cell_sz, wall_w), wall_color)
			if (cell & MazeGenerator.W) == 0:
				draw_rect(Rect2(screen_x, screen_y, wall_w, cell_sz), wall_color)
			if (cell & MazeGenerator.E) == 0:
				draw_rect(Rect2(screen_x + cell_sz - wall_w, screen_y, wall_w, cell_sz), wall_color)

			# Always draw boundary walls
			if gy == 0:
				draw_rect(Rect2(screen_x, screen_y, cell_sz, wall_w), wall_color)
			if gy == maze_height - 1:
				draw_rect(Rect2(screen_x, screen_y + cell_sz - wall_w, cell_sz, wall_w), wall_color)
			if gx == 0:
				draw_rect(Rect2(screen_x, screen_y, wall_w, cell_sz), wall_color)
			if gx == maze_width - 1:
				draw_rect(Rect2(screen_x + cell_sz - wall_w, screen_y, wall_w, cell_sz), wall_color)

			if gx == exit_pos.x and gy == exit_pos.y and (game_won or _is_revealed(exit_pos)):
				draw_rect(Rect2(screen_x + cell_sz * 0.2, screen_y + cell_sz * 0.2,
					cell_sz * 0.6, cell_sz * 0.6), Color(0.1, 0.8, 0.3))

			var key_idx = 0
			for it in items:
				if is_instance_valid(it) and it.pos == Vector2i(gx, gy) and _is_revealed(it.pos):
					if it.item_type == "key":
						_draw_mini_character(Vector2(screen_x, screen_y), cell_sz, key_idx)
						key_idx += 1
					else:
						_draw_item_sprite(Vector2(screen_x, screen_y), cell_sz, it)

			for m in monsters:
				if is_instance_valid(m) and m.pos == Vector2i(gx, gy) and _is_revealed(m.pos):
					var mcx = screen_x + cell_sz * 0.5
					var mcy = screen_y + cell_sz * 0.5
					var mr = cell_sz * 0.3
					draw_circle(Vector2(mcx, mcy), mr, m.color.darkened(0.4))
					draw_circle(Vector2(mcx, mcy), mr * 0.7, m.color.darkened(0.2))

					match m.monster_type:
						"sand":
							# 沙蝎 - claws and stinger
							draw_rect(Rect2(mcx - mr * 0.8, mcy - mr * 0.3, mr * 0.3, mr * 0.15), m.color)
							draw_rect(Rect2(mcx + mr * 0.5, mcy - mr * 0.3, mr * 0.3, mr * 0.15), m.color)
							draw_rect(Rect2(mcx - mr * 0.1, mcy + mr * 0.5, mr * 0.2, mr * 0.4), m.color.darkened(0.3))
						"desert":
							# 沙虫 - segmented body
							for i in range(3):
								var seg_y = mcy - mr * 0.4 + i * mr * 0.3
								draw_rect(Rect2(mcx - mr * 0.5, seg_y, mr, mr * 0.2), m.color.lightened(0.1))
						"grotto":
							# 石魔 - rocky spikes
							for i in range(4):
								var angle = i * PI / 2
								var spike_x = mcx + cos(angle) * mr * 0.8
								var spike_y = mcy + sin(angle) * mr * 0.8
								draw_circle(Vector2(spike_x, spike_y), mr * 0.15, m.color.lightened(0.2))
						"oasis":
							# 水妖 - water waves
							for i in range(3):
								var wave_y = mcy + mr * 0.3 + i * mr * 0.15
								draw_rect(Rect2(mcx - mr * 0.6, wave_y, mr * 1.2, mr * 0.08), Color(0.4, 0.7, 0.8, 0.6))
						"ancient_road":
							# 盗匪 - scarf and weapon
							draw_rect(Rect2(mcx - mr * 0.4, mcy - mr * 0.7, mr * 0.8, mr * 0.2), Color(0.8, 0.2, 0.1))
							draw_rect(Rect2(mcx + mr * 0.4, mcy - mr * 0.3, mr * 0.15, mr * 0.8), Color(0.5, 0.5, 0.5))

					draw_circle(Vector2(mcx - mr * 0.3, mcy - mr * 0.2), mr * 0.15, Color.WHITE)
					draw_circle(Vector2(mcx + mr * 0.3, mcy - mr * 0.2), mr * 0.15, Color.WHITE)
					draw_circle(Vector2(mcx - mr * 0.3, mcy - mr * 0.2), mr * 0.08, Color.BLACK)
					draw_circle(Vector2(mcx + mr * 0.3, mcy - mr * 0.2), mr * 0.08, Color.BLACK)
					
					# Monster name label on top
					var monster_names = {"sand":"蝎", "desert":"虫", "grotto":"魔", "oasis":"妖", "ancient_road":"匪"}
					var label = monster_names.get(m.monster_type, "?")
					var label_fs = int(cell_sz * 0.2)
					draw_string(ThemeDB.fallback_font, Vector2(mcx - label_fs / 2, screen_y + label_fs + 2), label,
						HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs, Color(1, 1, 1, 0.9))

	var player_screen_x: float = half_cols * cell_sz
	var player_screen_y: float = half_rows * cell_sz
	_draw_mini_character(Vector2(player_screen_x, player_screen_y), cell_sz, 1)

	_draw_mobile_hud_overlay(vp)

var player_sprite: Texture2D
var family_sprites: Array[Texture2D] = []
var terrain_sprites: Dictionary = {}

func _load_sprites():
	player_sprite = load("res://assets/sprites/player/dj.png")
	family_sprites = [
		load("res://assets/sprites/player/le.png"),
		load("res://assets/sprites/player/mac.png"),
		load("res://assets/sprites/player/mcking.png")
	]
	_load_item_sprites()
	_load_terrain_sprites()

func _load_terrain_sprites():
	terrain_sprites = {
		"sand": load("res://assets/sprites/terrain/sand.png"),
		"desert": load("res://assets/sprites/terrain/desert.png"),
		"grotto": load("res://assets/sprites/terrain/hole/line.png"),
		"oasis": load("res://assets/sprites/terrain/oasis/defult.png"),
		"ancient_road": load("res://assets/sprites/terrain/road/line.png")
	}

func _load_item_sprites():
	item_sprites = {
		"container": load("res://assets/sprites/item/pot.png"),
		"heal": load("res://assets/sprites/item/scroll.png"),
		"defense": load("res://assets/sprites/item/shield.png"),
		"attack": load("res://assets/sprites/item/sword.png"),
		"trap": load("res://assets/sprites/item/pot.png"),
		"key": null
	}

func _draw_mini_character(o: Vector2, s: float, char_type: int) -> void:
	var sprite: Texture2D
	if char_type == 1:
		sprite = player_sprite
	else:
		sprite = family_sprites[char_type % family_sprites.size()]
	
	if sprite:
		var tex_size = sprite.get_size()
		var scale_x = s / tex_size.x
		var scale_y = s / tex_size.y
		draw_texture_rect(sprite, Rect2(o, Vector2(s, s)), false)

var item_sprites: Dictionary = {}

func _draw_item_sprite(o: Vector2, s: float, item) -> void:
	var sprite = item_sprites.get(item.item_type)
	if sprite:
		draw_texture_rect(sprite, Rect2(o, Vector2(s, s)), false)
	else:
		var item_cx = o.x + s * 0.5
		var item_cy = o.y + s * 0.5
		var item_r = s * 0.25
		draw_circle(Vector2(item_cx, item_cy), item_r, item.color.darkened(0.2))
		draw_circle(Vector2(item_cx, item_cy), item_r * 0.6, item.color)

func _draw_mobile_hud_overlay(vp: Vector2) -> void:
	pass

func _draw_pc_view(vp: Vector2) -> void:
	var panel_w: float = 220
	var game_w: float = vp.x - panel_w
	var game_h: float = vp.y - 40

	var maze_pixel_w: float = maze_width * cell_size
	var maze_pixel_h: float = maze_height * cell_size

	var scale_x: float = game_w / maze_pixel_w
	var scale_y: float = game_h / maze_pixel_h
	var draw_scale: float = minf(scale_x, scale_y)
	draw_scale = minf(draw_scale, 1.0)

	var scaled_w: float = maze_pixel_w * draw_scale
	var scaled_h: float = maze_pixel_h * draw_scale
	var offset: Vector2 = Vector2((game_w - scaled_w) / 2, (game_h - scaled_h) / 2)

	draw_rect(Rect2(0, 0, game_w, game_h), Color(0.85, 0.80, 0.70))
	draw_rect(Rect2(offset.x - 2, offset.y - 2, scaled_w + 4, scaled_h + 4), Color(0.15, 0.12, 0.08))
	draw_rect(Rect2(offset, Vector2(scaled_w, scaled_h)), Color(0.92, 0.88, 0.78))

	_draw_cells(offset, draw_scale)
	_draw_pillars(offset, draw_scale)
	_draw_exit(offset, draw_scale)
	_draw_items(offset, draw_scale)
	_draw_monsters(offset, draw_scale)
	_draw_player(offset, draw_scale)

	draw_rect(Rect2(game_w, 0, panel_w, vp.y), Color(0.12, 0.10, 0.08))
	ui_panel.draw_panel(self, game_w, panel_w, vp.y,
		player, maze, maze_width, maze_height, exit_pos,
		levels_data, current_level_index, difficulty_names.get(selected_difficulty, ""),
		move_count, current_terrain_name, _get_buff_display(),
		visited, _is_revealed,
		combat_log, inventory)

	if game_over:
		ui_panel.draw_overlay(self, vp, "你倒下了...", "走了 %d 步" % move_count, "按 R 重新尝试", Color(0.9, 0.3, 0.2))
	elif game_won:
		var is_final = current_level_index + 1 >= levels_data.size()
		var title = "通关!" if is_final else "穿越成功!"
		var sub = "你穿越了所有关卡" if is_final else "%s 已通关" % levels_data[current_level_index].get("name", "")
		var hint = "按 R 重新开始" if is_final else "按 R 进入下一关"
		var c = Color(1.0, 0.85, 0.3) if is_final else Color.WHITE
		ui_panel.draw_overlay(self, vp, title, sub + "\n用了 %d 步" % move_count, hint, c)

func _draw_difficulty_select():
	var vp = get_viewport_rect().size
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.12, 0.1, 0.08))

	var min_dim = minf(vp.x, vp.y)
	var font_mult = clampf(min_dim / 400.0, 1.0, 2.5)

	var title_y = vp.y * 0.2
	draw_string(ThemeDB.fallback_font, Vector2(vp.x / 2 - 80 * font_mult, title_y),
		"敦煌迷途", HORIZONTAL_ALIGNMENT_LEFT, -1, int(36 * font_mult), Color(0.9, 0.8, 0.6))
	draw_string(ThemeDB.fallback_font, Vector2(vp.x / 2 - 60 * font_mult, title_y + 40 * font_mult),
		"选择旅途难度", HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * font_mult), Color(0.7, 0.65, 0.55))

	var start_y = vp.y * 0.4
	for i in difficulty_options.size():
		var key = difficulty_options[i]
		var name = difficulty_names[key]
		var diff = DataLoader.difficulty_data.get(key, {})
		var desc = diff.get("description", "")
		var is_selected = (key == selected_difficulty)

		var y = start_y + i * 80 * font_mult
		var bg_color = Color(0.25, 0.2, 0.15) if is_selected else Color(0.18, 0.15, 0.12)
		var text_color = Color(1.0, 0.9, 0.6) if is_selected else Color(0.6, 0.55, 0.45)

		draw_rect(Rect2(vp.x / 2 - 180 * font_mult, y - 10, 360 * font_mult, 65 * font_mult), bg_color)
		if is_selected:
			draw_rect(Rect2(vp.x / 2 - 180 * font_mult, y - 10, 4, 65 * font_mult), Color(0.9, 0.7, 0.2))

		draw_string(ThemeDB.fallback_font, Vector2(vp.x / 2 - 160 * font_mult, y + 15),
			name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * font_mult), text_color)
		draw_string(ThemeDB.fallback_font, Vector2(vp.x / 2 - 160 * font_mult, y + 40),
			desc, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * font_mult), Color(0.5, 0.48, 0.42))

	draw_string(ThemeDB.fallback_font, Vector2(vp.x / 2 - 100 * font_mult, vp.y * 0.85),
		"↑↓ 选择  回车/→ 确认", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * font_mult), Color(0.5, 0.48, 0.42))

func _draw_error_screen():
	var vp = get_viewport_rect().size
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.15, 0.1, 0.08))
	draw_string(ThemeDB.fallback_font, Vector2(vp.x / 2 - 100, vp.y / 2 - 20),
		"加载失败", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.9, 0.3, 0.2))

func _draw_cells(offset: Vector2, scale: float) -> void:
	var sc: float = scale
	var cs: float = cell_size * sc
	var wt: float = wall_thickness * sc
	for y in maze_height:
		for x in maze_width:
			var pos = Vector2i(x, y)
			var cell_pos = offset + Vector2(x * cs, y * cs)

			if not _is_revealed(pos) and not visited.get(pos, false):
				draw_rect(Rect2(cell_pos, Vector2(cs, cs)), Color(0.15, 0.12, 0.10, 0.85))
				continue

			var t = maze.get_terrain(x, y)
			var t_key = MazeGenerator.TERRAIN_KEY[t]
			var cfg = DataLoader.get_terrain_config(t_key)
			var floor_color = DataLoader.color_from_array(cfg.get("floor_color", [0.8, 0.8, 0.8]))
			if not _is_revealed(pos):
				floor_color = floor_color.darkened(0.4)

			draw_rect(Rect2(cell_pos + Vector2(wt, wt), Vector2(cs - wt * 2, cs - wt * 2)), floor_color)

			var detail_sym = cfg.get("detail_symbol", "")
			if detail_sym != "":
				var detail_color = _get_terrain_symbol_color(t_key, floor_color)
				draw_string(ThemeDB.fallback_font, cell_pos + Vector2(cs * 0.35, cs * 0.65),
					detail_sym, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * sc), detail_color)

			var cell = maze.grid[y][x]
			var wall_color = Color(0.12, 0.08, 0.05)

			# Only draw walls where there is NO passage (bit NOT set)
			if (cell & MazeGenerator.N) == 0:
				draw_rect(Rect2(cell_pos, Vector2(cs, wt)), wall_color)
			if (cell & MazeGenerator.S) == 0:
				draw_rect(Rect2(cell_pos + Vector2(0, cs - wt), Vector2(cs, wt)), wall_color)
			if (cell & MazeGenerator.W) == 0:
				draw_rect(Rect2(cell_pos, Vector2(wt, cs)), wall_color)
			if (cell & MazeGenerator.E) == 0:
				draw_rect(Rect2(cell_pos + Vector2(cs - wt, 0), Vector2(wt, cs)), wall_color)

			# Always draw boundary walls
			if y == 0:
				draw_rect(Rect2(cell_pos, Vector2(cs, wt)), wall_color)
			if y == maze_height - 1:
				draw_rect(Rect2(cell_pos + Vector2(0, cs - wt), Vector2(cs, wt)), wall_color)
			if x == 0:
				draw_rect(Rect2(cell_pos, Vector2(wt, cs)), wall_color)
			if x == maze_width - 1:
				draw_rect(Rect2(cell_pos + Vector2(cs - wt, 0), Vector2(wt, cs)), wall_color)

func _get_terrain_symbol_color(t_key: String, floor_color: Color) -> Color:
	if floor_color.get_luminance() > 0.5:
		return Color(0.2, 0.15, 0.1)
	return Color(0.9, 0.85, 0.7)

func _draw_pillars(offset: Vector2, scale: float) -> void:
	var cs: float = cell_size * scale
	var wt: float = wall_thickness * scale
	for y in range(maze_height + 1):
		for x in range(maze_width + 1):
			var px = clampi(x, 0, maze_width - 1)
			var py = clampi(y, 0, maze_height - 1)
			var t_key = MazeGenerator.TERRAIN_KEY[maze.get_terrain(px, py)]
			var cfg = DataLoader.get_terrain_config(t_key)
			var pillar_color = DataLoader.color_from_array(cfg.get("wall_color", [0.2, 0.2, 0.2]))
			draw_rect(Rect2(offset + Vector2(x * cs - wt / 2, y * cs - wt / 2),
				Vector2(wt, wt)), pillar_color)

func _draw_exit(offset: Vector2, scale: float) -> void:
	if not _is_revealed(exit_pos) and not game_won:
		return
	if not exit_visible and not game_won:
		return
	var cs: float = cell_size * scale
	var ep = offset + Vector2(exit_pos.x * cs, exit_pos.y * cs)
	draw_rect(Rect2(ep + Vector2(cs * 0.15, cs * 0.15), Vector2(cs * 0.7, cs * 0.7)), Color(0.1, 0.8, 0.3))
	draw_string(ThemeDB.fallback_font, ep + Vector2(cs * 0.3, cs * 0.65),
		"门", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * scale), Color.WHITE)

func _draw_items(offset: Vector2, scale: float) -> void:
	var cs: float = cell_size * scale
	var wt: float = wall_thickness * scale
	var key_palettes = [
		[Color(0.86, 0.24, 0.24), Color(0.2, 0.2, 0.2), Color(1.0, 0.85, 0.72)],
		[Color(0.31, 0.71, 0.31), Color(0.39, 0.27, 0.16), Color(1.0, 0.85, 0.72)],
		[Color(0.59, 0.31, 0.71), Color(0.86, 0.86, 0.86), Color(1.0, 0.85, 0.72)]
	]
	var key_index = 0
	for it in items:
		if not is_instance_valid(it) or not _is_revealed(it.pos):
			continue
		var ip = offset + Vector2(it.pos.x * cs, it.pos.y * cs)
		if it.item_type == "key":
			var pal = key_palettes[key_index % 3]
			_draw_character(ip, cs / 16.0, pal[0], pal[1], pal[2])
			key_index += 1
		else:
			draw_rect(Rect2(ip + Vector2(wt, wt), Vector2(cs - wt * 2, cs - wt * 2)), it.color.darkened(0.2))
			draw_string(ThemeDB.fallback_font, ip + Vector2(cs * 0.3, cs * 0.65),
				it.symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * scale), it.color)

func _draw_monsters(offset: Vector2, scale: float) -> void:
	var cs: float = cell_size * scale
	var wt: float = wall_thickness * scale
	for m in monsters:
		if not is_instance_valid(m) or not _is_revealed(m.pos):
			continue
		var mp = offset + Vector2(m.pos.x * cs, m.pos.y * cs)
		draw_rect(Rect2(mp + Vector2(wt, wt), Vector2(cs - wt * 2, cs - wt * 2)), m.color.darkened(0.3))
		draw_string(ThemeDB.fallback_font, mp + Vector2(cs * 0.3, cs * 0.65),
			m.symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * scale), m.color)
		var hp_ratio = float(m.hp) / float(m.max_hp)
		var bar_w = cs - wt * 2 - 4
		var bar_x = mp.x + wt + 2
		var bar_y = mp.y + cs - wt - 6
		draw_rect(Rect2(bar_x, bar_y, bar_w, 4), Color(0.2, 0.1, 0.1))
		draw_rect(Rect2(bar_x, bar_y, bar_w * hp_ratio, 4), Color(0.8, 0.2, 0.2))

func _draw_player(offset: Vector2, scale: float) -> void:
	var cs: float = cell_size * scale
	var pp = offset + Vector2(player.pos.x * cs, player.pos.y * cs)
	var s: float = cs / 16.0
	_draw_character(pp, s, Color(0.27, 0.51, 0.71), Color(0.85, 0.65, 0.13), Color(1.0, 0.85, 0.72))

func _draw_character(o: Vector2, s: float, robe: Color, hair: Color, skin: Color) -> void:
	# Hair
	draw_rect(Rect2(o.x + 4*s, o.y + 1*s, 8*s, 5*s), hair)
	# Face
	draw_rect(Rect2(o.x + 5*s, o.y + 4*s, 6*s, 4*s), skin)
	# Eyes
	draw_rect(Rect2(o.x + 6*s, o.y + 5*s, 1*s, 1*s), Color.WHITE)
	draw_rect(Rect2(o.x + 9*s, o.y + 5*s, 1*s, 1*s), Color.WHITE)
	draw_rect(Rect2(o.x + 6*s, o.y + 6*s, 1*s, 1*s), Color.BLACK)
	draw_rect(Rect2(o.x + 9*s, o.y + 6*s, 1*s, 1*s), Color.BLACK)
	# Mouth
	draw_rect(Rect2(o.x + 7*s, o.y + 7*s, 2*s, 1*s), Color(0.8, 0.4, 0.4))
	# Body/robe
	draw_rect(Rect2(o.x + 4*s, o.y + 8*s, 8*s, 6*s), robe)
	# Belt
	draw_rect(Rect2(o.x + 4*s, o.y + 10*s, 8*s, 1*s), hair)
	# Arms
	draw_rect(Rect2(o.x + 2*s, o.y + 9*s, 2*s, 3*s), skin)
	draw_rect(Rect2(o.x + 12*s, o.y + 9*s, 2*s, 3*s), skin)
	# Legs
	draw_rect(Rect2(o.x + 5*s, o.y + 14*s, 2*s, 2*s), hair.darkened(0.2))
	draw_rect(Rect2(o.x + 9*s, o.y + 14*s, 2*s, 2*s), hair.darkened(0.2))

func _flash_player_hurt() -> void:
	player.is_hurt = true
	var tw = create_tween()
	flash_tweens.append(tw)
	tw.tween_property(player, "is_hurt", false, 0.3).set_delay(0.3)
	tw.finished.connect(func():
		player.is_hurt = false
		flash_tweens.erase(tw)
		queue_redraw())
	queue_redraw()

func _animate_monster_death(monster: MonsterEntity) -> void:
	if not is_instance_valid(monster):
		return
	var tw = create_tween()
	flash_tweens.append(tw)
	tw.tween_property(monster, "color", Color.WHITE, 0.1)
	tw.tween_property(monster, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN)
	tw.finished.connect(func():
		flash_tweens.erase(tw)
		if is_instance_valid(monster):
			monster.queue_free())
	queue_redraw()
