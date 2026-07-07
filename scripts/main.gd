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

var combat_log: Array = []
var log_timer := 0.0
var visited: Dictionary = {}
var current_terrain_name := "古道"
var exit_blink_timer := 0.0
var exit_visible := true

var levels_data: Array = []
var level_monster_density := 0.12
var level_monster_scale := 1.0
var level_terrain_effects := {}
var level_key_count := 0

var game: GameState = GameState.new()
var inventory: Inventory
var key_tracker: KeyTracker
var ui_panel: UIPanel
var mobile_controls: MobileControls
var maze_renderer: MazeRenderer
var mobile_renderer: MobileRenderer
var flash_tweens: Array[Tween] = []
var needs_redraw := true

# Aliases for TurnResolver compatibility
var move_count: int:
	get: return game.move_count
	set(v): game.move_count = v
var game_won: bool:
	get: return game.game_won
	set(v): game.game_won = v
var game_over: bool:
	get: return game.game_over
	set(v): game.game_over = v
var game_state: String:
	get: return "difficulty_select" if game.is_difficulty_select() else "playing"
var selected_difficulty: String:
	get: return game.selected_difficulty
var current_level_index: int:
	get: return game.current_level_index

func _ready() -> void:
	_ensure_data_loaded()
	maze_renderer = MazeRenderer.new()
	maze_renderer.cell_size = cell_size
	maze_renderer.wall_thickness = wall_thickness
	maze_renderer.load_sprites()
	mobile_renderer = MobileRenderer.new(maze_renderer)

	player = PlayerController.new()
	add_child(player)
	player.died.connect(_on_player_died)
	player.hp_changed.connect(_on_hp_changed)

	inventory = Inventory.new()
	inventory.inventory_changed.connect(_request_redraw)
	key_tracker = KeyTracker.new()
	key_tracker.key_collected.connect(func(_c, _r): _update_mobile_ui())
	ui_panel = UIPanel.new()
	mobile_controls = MobileControls.new()
	mobile_controls.move_pressed.connect(_on_mobile_move)
	mobile_controls.action_pressed.connect(_on_mobile_action)
	add_child(mobile_controls)

	levels_data = DataLoader.get_level_data()
	if levels_data.is_empty():
		levels_data = [{"name": "未知", "maze_width": 20, "maze_height": 15, "monster_density": 0.12}]
	_try_load_save()
	_request_redraw()

func _try_load_save() -> void:
	var save := SaveManager.load_progress()
	if save.is_empty():
		return
	game.current_level_index = int(save.get("level_index", 0))
	game.selected_difficulty = str(save.get("difficulty", "normal"))
	DataLoader.set_difficulty(game.selected_difficulty)

func _on_hp_changed(_new_hp: int, _max_hp: int) -> void:
	_update_mobile_ui()
	_request_redraw()

func _request_redraw() -> void:
	needs_redraw = true

func _on_mobile_move(dir: int) -> void:
	if game.is_difficulty_select():
		if dir == MazeGenerator.N:
			game.cycle_difficulty(-1)
		elif dir == MazeGenerator.S:
			game.cycle_difficulty(1)
		_request_redraw()
		return

	if not game.can_move():
		return

	if _try_move(dir):
		AudioManager.play_step()
		TurnResolver.resolve_after_move(self)

func _update_mobile_ui() -> void:
	if mobile_controls and player:
		mobile_controls.update_values(
			player.hp, player.max_hp,
			key_tracker.collected_keys, game.move_count, level_key_count,
		)

func _on_mobile_action(action: String) -> void:
	match action:
		"use_item":
			_use_item_from_inventory()
		"regenerate":
			_handle_regenerate()
		"menu":
			game.return_to_menu()
			_request_redraw()

func _handle_regenerate() -> void:
	if game_won:
		if current_level_index + 1 < levels_data.size():
			_new_game(current_level_index + 1)
		else:
			_new_game(0)
	else:
		_new_game(current_level_index)

func _ensure_data_loaded() -> void:
	if DataLoader.player_stats.is_empty():
		DataLoader._load_all()
	if DataLoader.player_stats.is_empty():
		push_warning("DataLoader: player_stats still empty after reload, using defaults")
		DataLoader.player_stats = {"max_hp": 20, "base_atk": 5, "reveal_radius": 3}

func _new_game(level_idx: int = -1) -> void:
	if level_idx >= 0:
		game.current_level_index = level_idx

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
	game.reset_round()
	visited = {}
	combat_log.clear()
	key_tracker.setup(level_key_count)
	monsters = EntitySpawner.spawn_monsters(
		self, maze, maze_width, maze_height,
		level_monster_density, level_monster_scale,
		_on_monster_defeated,
	)
	items = EntitySpawner.spawn_items(
		self, maze, maze_width, maze_height, monsters, level_key_count,
	)
	_mark_visited(player.pos)
	current_terrain_name = maze.get_terrain_name(player.pos.x, player.pos.y)
	_add_log("进入 %s - 找到 %d 个家人，一起离开" % [level.get("name", ""), level_key_count])
	AudioManager.play_level_start()
	SaveManager.save_progress(current_level_index, selected_difficulty, player.level, player.xp)
	_request_redraw()

func _get_item_at(pos: Vector2i) -> ItemEntity:
	for it in items:
		if is_instance_valid(it) and it.pos == pos:
			return it
	return null

func _pick_up_item(item: ItemEntity) -> void:
	AudioManager.play_pickup()
	item.picked_up.emit(item.item_key)

	if item.item_type == "key":
		key_tracker.add_key()
		_add_log("获得 %s (%s)" % [item.display_name, key_tracker.get_progress()])
		items.erase(item)
		if is_instance_valid(item):
			item.queue_free()
		_update_mobile_ui()
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
				_update_mobile_ui()
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
	var roll := player.roll_damage()
	var damage_to_monster: int = roll.damage
	var is_crit: bool = roll.is_crit
	var damage_to_player := target.atk + randi_range(-1, 1)

	AudioManager.play_hit()

	if is_crit:
		_add_log("暴击! 你攻击 %s 造成 %d 伤害" % [target.display_name, damage_to_monster])
	else:
		_add_log("你攻击 %s 造成 %d 伤害" % [target.display_name, damage_to_monster])
	target.take_damage(damage_to_monster)

	if damage_to_player > 0:
		var result := player.take_damage(damage_to_player)
		if result.dodged:
			_add_log("你闪避了 %s 的攻击!" % target.display_name)
		elif result.damage_taken > 0:
			_add_log("%s 攻击你造成 %d 伤害" % [target.display_name, result.damage_taken])
			_flash_player_hurt()
			_try_auto_heal()
			_update_mobile_ui()

func _on_monster_defeated(monster: MonsterEntity) -> void:
	_add_log("%s 被击败!" % monster.display_name)
	if player.add_xp(monster.xp):
		_add_log("升级! Lv.%d HP+2 ATK+1" % player.level)
	SaveManager.save_progress(current_level_index, selected_difficulty, player.level, player.xp)
	monsters.erase(monster)
	_animate_monster_death(monster)

func _on_player_died() -> void:
	AudioManager.play_death()
	game_over = true
	_add_log("你倒下了...")
	SaveManager.clear_save()
	_request_redraw()

func _add_log(msg: String) -> void:
	combat_log.append(msg)
	if combat_log.size() > 4:
		combat_log.remove_at(0)
	log_timer = 3.0
	_request_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if game.is_difficulty_select():
		if event.is_action_pressed("move_up"):
			game.cycle_difficulty(-1)
			_request_redraw()
		elif event.is_action_pressed("move_down"):
			game.cycle_difficulty(1)
			_request_redraw()
		elif event.is_action_pressed("regenerate") or event.is_action_pressed("move_right"):
			_start_playing()
		elif (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			_handle_difficulty_click(event.position)
		return

	if game_won or game_over:
		if event.is_action_pressed("regenerate"):
			_handle_regenerate()
		return

	if event.is_action_pressed("regenerate"):
		_new_game(current_level_index)
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_use_item_from_inventory()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		game.return_to_menu()
		_request_redraw()
		return

	var moved := false
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
		TurnResolver.resolve_after_move(self)

func _start_playing() -> void:
	DataLoader.set_difficulty(selected_difficulty)
	game.start_game()
	var save := SaveManager.load_progress()
	if save.is_empty() or str(save.get("difficulty", "")) != selected_difficulty:
		player.xp = 0
		player.level = 1
		_new_game(0)
	else:
		player.level = int(save.get("player_level", 1))
		player.xp = int(save.get("player_xp", 0))
		_new_game(int(save.get("level_index", 0)))

func _handle_difficulty_click(click_pos: Vector2) -> void:
	var vp = get_viewport_rect().size
	var min_dim = minf(vp.x, vp.y)
	var font_mult = clampf(min_dim / 400.0, 1.0, 2.5)
	var start_y = vp.y * 0.4
	for i in GameState.DIFFICULTY_OPTIONS.size():
		var y = start_y + i * 80 * font_mult
		var btn_rect = Rect2(vp.x / 2 - 180 * font_mult, y - 10, 360 * font_mult, 65 * font_mult)
		if btn_rect.has_point(click_pos):
			game.selected_difficulty = GameState.DIFFICULTY_OPTIONS[i]
			_start_playing()
			break

func _apply_terrain_effect() -> void:
	var terrain_key = MazeGenerator.TERRAIN_KEY[maze.get_terrain(player.pos.x, player.pos.y)]
	if not level_terrain_effects.has(terrain_key):
		return
	var effect = level_terrain_effects[terrain_key]
	var diff = DataLoader.get_difficulty()
	if effect.has("move_damage") and effect.move_damage > 0:
		var dmg = int(effect.move_damage * diff.get("terrain_damage_multiplier", 1.0))
		var result := player.take_damage(dmg)
		if not result.dodged:
			_add_log("%s: 受到 %d 环境伤害" % [effect.get("description", ""), result.damage_taken])
			_flash_player_hurt()
			_try_auto_heal()
			_update_mobile_ui()
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
	var msg := player.apply_item(key)
	_add_log(msg)
	_request_redraw()

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
	_request_redraw()

func _try_move(dir: int) -> bool:
	if maze.can_move(player.pos.x, player.pos.y, dir):
		player.pos += Vector2i(MazeGenerator.DX[dir], MazeGenerator.DY[dir])
		player.moved.emit(player.pos)
		return true
	AudioManager.play_wall_hit()
	return false

func _mark_visited(pos: Vector2i) -> void:
	visited[pos] = true

func _is_revealed(pos: Vector2i) -> bool:
	if player.get_effective_reveal_bonus() >= 999:
		return true
	var radius: float = DataLoader.player_stats.get("reveal_radius", 4)
	radius += player.reveal_bonus + player.get_effective_reveal_bonus()
	var player_terrain_key = MazeGenerator.TERRAIN_KEY[maze.get_terrain(player.pos.x, player.pos.y)]
	if level_terrain_effects.has(player_terrain_key):
		var effect = level_terrain_effects[player_terrain_key]
		if effect.has("reveal_penalty"):
			radius += effect.reveal_penalty
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
	if player.level > 1:
		parts.append("Lv.%d" % player.level)
	if parts.is_empty():
		return ""
	return "Buff: " + " ".join(parts)

func _process(delta: float) -> void:
	var dirty := false
	if log_timer > 0:
		log_timer -= delta
		if log_timer <= 0:
			if combat_log.size() > 0:
				combat_log.remove_at(0)
				dirty = true
	exit_blink_timer += delta
	if exit_blink_timer >= 2.0:
		exit_blink_timer = 0.0
		exit_visible = !exit_visible
		dirty = true
	if game.can_move():
		if _move_monsters():
			dirty = true
	if dirty:
		_request_redraw()
	if needs_redraw:
		queue_redraw()
		needs_redraw = false

func _move_monsters() -> bool:
	var did_combat := false
	var occupied: Dictionary = {player.pos: true}
	for m in monsters:
		if is_instance_valid(m):
			occupied[m.pos] = true
	for m in monsters:
		if is_instance_valid(m) and m.is_alive():
			var old_pos := m.pos
			m.try_move(maze, occupied)
			if m.pos == player.pos and m.pos != old_pos:
				_combat(m)
				did_combat = true
	return did_combat

func _draw() -> void:
	if game.is_difficulty_select():
		maze_renderer.draw_difficulty_select(self, get_viewport_rect().size, selected_difficulty)
		return

	if maze == null or maze.grid.is_empty():
		maze_renderer.draw_error_screen(self, get_viewport_rect().size)
		return

	var vp = get_viewport_rect().size
	if mobile_controls.is_mobile:
		mobile_renderer.draw_mobile_view(
			self, vp, maze, maze_width, maze_height,
			player, monsters, items, exit_pos,
			game_won, game_over, visited, _is_revealed,
			mobile_controls.is_portrait,
			levels_data, current_level_index, move_count,
		)
	else:
		maze_renderer.draw_pc_view(
			self, vp, maze, maze_width, maze_height,
			player, monsters, items, exit_pos,
			exit_visible, game_won, visited, _is_revealed,
			ui_panel, levels_data, current_level_index,
			game.get_difficulty_name(), move_count, current_terrain_name,
			_get_buff_display(), combat_log, inventory,
		)
		if game_over:
			ui_panel.draw_overlay(self, vp, "你倒下了...", "走了 %d 步" % move_count, "按 R 重新尝试", Color(0.9, 0.3, 0.2))
		elif game_won:
			var is_final = current_level_index + 1 >= levels_data.size()
			var title = "通关!" if is_final else "穿越成功!"
			var sub = "你穿越了所有关卡" if is_final else "%s 已通关" % levels_data[current_level_index].get("name", "")
			var hint = "按 R 重新开始" if is_final else "按 R 进入下一关"
			var c = Color(1.0, 0.85, 0.3) if is_final else Color.WHITE
			ui_panel.draw_overlay(self, vp, title, sub + "\n用了 %d 步" % move_count, hint, c)

func _flash_player_hurt() -> void:
	player.is_hurt = true
	var tw = create_tween()
	flash_tweens.append(tw)
	tw.tween_property(player, "is_hurt", false, 0.3).set_delay(0.3)
	tw.finished.connect(func():
		player.is_hurt = false
		flash_tweens.erase(tw)
		_request_redraw())
	_request_redraw()

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
	_request_redraw()
