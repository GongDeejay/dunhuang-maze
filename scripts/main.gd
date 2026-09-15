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
var game_view_composer: GameViewComposer
var current_layout: LayoutProfile = LayoutProfile.new()
var flash_tweens: Array[Tween] = []
var needs_redraw := true
var selected_inventory_slot: int = 0
var show_new_journey_confirm: bool = false
var tutorial_done: bool = false
var first_combat_warned: bool = false
var first_item_tip_shown: bool = false
var first_family_tip_shown: bool = false
var guide_assist_active: bool = false
var moves_since_progress: int = 0
var low_hp_pulse: float = 0.0
var input_handler := InputHandler.new()
var attack_cooldown := 0.0

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
	get:
		if game.is_difficulty_select():
			return "difficulty_select"
		if game.is_paused():
			return "paused"
		return "playing"
var selected_difficulty: String:
	get: return game.selected_difficulty
var current_level_index: int:
	get: return game.current_level_index

func _ready() -> void:
	_ensure_data_loaded()
	cell_size = PlatformService.get_target_cell_size(cell_size)
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
	inventory.inventory_changed.connect(_on_inventory_changed)
	key_tracker = KeyTracker.new()
	key_tracker.key_collected.connect(func(_c, _r): _update_mobile_ui())
	key_tracker.all_keys_collected.connect(_on_all_family_found)
	ui_panel = UIPanel.new()
	game_view_composer = GameViewComposer.new(maze_renderer, mobile_renderer, ui_panel)
	mobile_controls = MobileControls.new()
	mobile_controls.move_pressed.connect(_on_mobile_move)
	mobile_controls.action_pressed.connect(_on_mobile_action)
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 100
	touch_layer.name = "TouchLayer"
	add_child(touch_layer)
	touch_layer.add_child(mobile_controls)

	levels_data = DataLoader.get_level_data()
	if levels_data.is_empty():
		levels_data = [{"name": "未知", "maze_width": 20, "maze_height": 15, "monster_density": 0.12}]
	_try_load_save()
	_refresh_layout()
	_request_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and game != null and game.is_playing():
		game.toggle_pause()
		_request_redraw()

func _try_load_save() -> void:
	var save := SaveManager.load_progress()
	if save.is_empty():
		return
	game.current_level_index = int(save.get("level_index", 0))
	game.selected_difficulty = str(save.get("difficulty", "normal"))
	DataLoader.set_difficulty(game.selected_difficulty)

func _on_inventory_changed() -> void:
	if inventory.get_count() == 0:
		selected_inventory_slot = 0
	elif selected_inventory_slot >= inventory.get_count():
		selected_inventory_slot = inventory.get_count() - 1
	_request_redraw()

func _on_hp_changed(_new_hp: int, _max_hp: int) -> void:
	_update_mobile_ui()
	if _max_hp > 0 and float(_new_hp) / float(_max_hp) <= 0.3:
		low_hp_pulse = 1.0
	_request_redraw()

func _request_redraw() -> void:
	needs_redraw = true
	if mobile_controls:
		mobile_controls.queue_redraw()

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
	_refresh_layout()
	_request_redraw()


func _refresh_layout() -> void:
	var vp := get_viewport_rect().size
	PlatformService.refresh(vp)
	var touch := PlatformService.use_mobile_ui or DisplayServer.is_touchscreen_available() or PlatformService.is_portrait_viewport(vp)
	current_layout = UILayoutDirector.compute(vp, touch)
	if mobile_controls:
		mobile_controls.apply_layout(current_layout)
		mobile_controls.visible = not game.is_difficulty_select() and not show_new_journey_confirm


func _input(event: InputEvent) -> void:
	if game.is_difficulty_select():
		return
	if not current_layout.show_touch_controls:
		return
	if mobile_controls.try_handle_input(event):
		get_viewport().set_input_as_handled()

func _on_mobile_action(action: String) -> void:
	if not game.can_move() and action in ["use_item", "cycle_item"]:
		return
	match action:
		"use_item":
			_use_item_from_inventory(selected_inventory_slot)
		"cycle_item":
			_cycle_inventory_slot(1)
		"regenerate":
			_handle_regenerate()
		"pause":
			game.toggle_pause()
			_request_redraw()
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
	attack_cooldown = 0.0
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
	var base_max_hp := int(DataLoader.player_stats.get("max_hp", 18) * hp_mult)
	var base_atk := int(DataLoader.player_stats.get("base_atk", 5) * atk_mult)
	player.apply_base_stats(base_max_hp, base_atk)
	player.reveal_bonus = diff.get("reveal_radius_bonus", 0)
	inventory.clear()
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
	selected_inventory_slot = 0
	first_combat_warned = false
	first_item_tip_shown = false
	first_family_tip_shown = false
	guide_assist_active = false
	moves_since_progress = 0
	_add_log("进入 %s - 找到 %d 个家人，一起离开" % [level.get("name", ""), level_key_count])
	_show_tutorial_if_needed()
	_prime_monster_intents()
	AudioManager.play_level_start()
	SaveManager.save_progress(current_level_index, selected_difficulty, player.level, player.xp)
	_request_redraw()

func _show_tutorial_if_needed() -> void:
	if current_level_index != 0 or tutorial_done:
		return
	tutorial_done = true
	_add_tutorial("【目标】寻找散落的家人；用 WASD、方向键或滑动移动")


func _add_tutorial(message: String) -> void:
	_add_log(message)
	log_timer = 8.0


func _on_all_family_found() -> void:
	guide_assist_active = true
	_add_tutorial("【目标更新】家人已到齐！跟随蓝色指引前往出口「门」")


func _prime_monster_intents() -> void:
	var occupied: Dictionary = {player.pos: true}
	for m in monsters:
		if is_instance_valid(m):
			occupied[m.pos] = true
	for m in monsters:
		if not is_instance_valid(m):
			continue
		occupied.erase(m.pos)
		m.plan_next_move(maze, occupied, player.pos)
		occupied[m.pos] = true

func _cycle_inventory_slot(delta: int) -> void:
	if inventory.get_count() == 0:
		selected_inventory_slot = 0
		return
	selected_inventory_slot = (selected_inventory_slot + delta) % inventory.get_count()
	if selected_inventory_slot < 0:
		selected_inventory_slot += inventory.get_count()
	_request_redraw()

func _select_inventory_slot(index: int) -> void:
	if index < 0 or index >= inventory.get_count():
		return
	selected_inventory_slot = index
	_request_redraw()

func _get_guide_direction() -> int:
	if maze == null or game_won or game_over or not guide_assist_active:
		return -1
	var target := PathGuide.nearest_target(
		maze, player.pos, items, exit_pos,
		key_tracker.collected_keys, level_key_count,
	)
	return PathGuide.next_direction(maze, player.pos, target)

func _get_item_at(pos: Vector2i) -> ItemEntity:
	for it in items:
		if is_instance_valid(it) and it.pos == pos:
			return it
	return null

func _pick_up_item(item: ItemEntity) -> void:
	AudioManager.play_pickup()
	item.picked_up.emit(item.item_key)

	if item.item_type == "key":
		moves_since_progress = 0
		guide_assist_active = false
		key_tracker.add_key()
		_add_log("获得 %s (%s)" % [item.display_name, key_tracker.get_progress()])
		if not first_family_tip_shown:
			first_family_tip_shown = true
			_add_tutorial("【家人】小地图以绿色标记已发现的家人；集齐后才能离开")
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
	if item.item_type != "key" and not first_item_tip_shown:
		first_item_tip_shown = true
		_add_tutorial("【道具】已放入背包：数字键/「换」选择，E/「用」使用")

	items.erase(item)
	if is_instance_valid(item):
		item.queue_free()

func _get_monster_at(pos: Vector2i) -> MonsterEntity:
	for m in monsters:
		if is_instance_valid(m) and m.pos == pos:
			return m
	return null


func _update_guide_assist() -> void:
	moves_since_progress += 1
	if guide_assist_active or key_tracker.has_all_keys():
		return
	var threshold := 18
	match selected_difficulty:
		"easy": threshold = 10
		"hard": threshold = 24
	if moves_since_progress >= threshold:
		guide_assist_active = true
		_add_tutorial("【迷途指引】已显示通往最近家人的蓝色方向提示")

func _combat(target: MonsterEntity) -> void:
	if attack_cooldown > 0.0 or not target.is_alive():
		return
	attack_cooldown = 0.35
	if not first_combat_warned:
		first_combat_warned = true
		_add_tutorial("【即时战斗】怪物会持续行动；黄色箭头表示下一步意图，P 可暂停")
	var roll := player.roll_damage()
	var damage_to_monster: int = roll.damage
	var is_crit: bool = roll.is_crit

	AudioManager.play_hit()

	if is_crit:
		_add_log("暴击! 你攻击 %s 造成 %d 伤害" % [target.display_name, damage_to_monster])
	else:
		_add_log("你攻击 %s 造成 %d 伤害" % [target.display_name, damage_to_monster])
	target.take_damage(damage_to_monster)
	player.tick_buff()
	_request_redraw()


func _monster_attack(target: MonsterEntity) -> void:
	var damage_to_player := target.atk + randi_range(-1, 1)
	if target.is_alive() and damage_to_player > 0:
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
	var action := input_handler.handle(event, _input_context())
	if action.type == GameAction.Type.NONE:
		return
	_apply_game_action(action)

func _input_context() -> Dictionary:
	var confirm_rects := ui_panel.get_confirm_button_rects(get_viewport_rect().size)
	return {
		"show_confirm": show_new_journey_confirm,
		"difficulty_select": game.is_difficulty_select(),
		"game_won": game_won,
		"game_over": game_over,
		"paused": game.is_paused(),
		"selected_slot": selected_inventory_slot,
		"use_mobile_ui": current_layout.show_touch_controls,
		"allow_hud_click": not current_layout.is_side_hud(),
		"hud_rect": current_layout.hud_rect,
		"confirm_yes_rect": confirm_rects.yes,
		"confirm_no_rect": confirm_rects.no,
	}

func _apply_game_action(action: GameAction) -> void:
	match action.type:
		GameAction.Type.CONFIRM:
			if show_new_journey_confirm:
				show_new_journey_confirm = false
				_do_start_playing(true)
				_request_redraw()
			elif game.is_difficulty_select():
				_start_playing()
		GameAction.Type.CANCEL:
			show_new_journey_confirm = false
			_request_redraw()
		GameAction.Type.CYCLE_DIFFICULTY:
			game.cycle_difficulty(action.diff_delta)
			_request_redraw()
		GameAction.Type.CLICK_AT:
			if game.is_difficulty_select():
				_handle_difficulty_click(action.position)
			else:
				var slot := game_view_composer.get_inventory_slot_at(action.position, current_layout)
				if slot >= 0:
					_select_inventory_slot(slot)
		GameAction.Type.REGENERATE:
			if game_won or game_over:
				_handle_regenerate()
			elif not game.is_difficulty_select():
				_new_game(current_level_index)
		GameAction.Type.USE_ITEM:
			_use_item_from_inventory(action.slot)
		GameAction.Type.SELECT_SLOT:
			_select_inventory_slot(action.slot)
		GameAction.Type.MENU:
			game.return_to_menu()
			_request_redraw()
		GameAction.Type.TOGGLE_PAUSE:
			game.toggle_pause()
			_request_redraw()
		GameAction.Type.MOVE:
			if not game.can_move():
				return
			if _try_move(action.direction):
				AudioManager.play_step()
				TurnResolver.resolve_after_move(self)

func _start_playing() -> void:
	if GameDirector.needs_new_journey_confirm(selected_difficulty):
		show_new_journey_confirm = true
		_request_redraw()
		return
	_do_start_playing(false)

func _do_start_playing(force_new: bool) -> void:
	GameDirector.begin_session(
		selected_difficulty, game, player, force_new,
		func(level_idx: int): _new_game(level_idx),
	)

func _handle_difficulty_click(click_pos: Vector2) -> void:
	var cards := maze_renderer.get_difficulty_card_rects(get_viewport_rect().size)
	for i in cards.size():
		if cards[i].has_point(click_pos):
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

func _use_item_from_inventory(slot: int = -1) -> void:
	if inventory.get_count() == 0:
		_add_log("背包是空的")
		return
	var index := slot if slot >= 0 else selected_inventory_slot
	if index >= inventory.get_count():
		index = 0
	var key = inventory.use_item(index)
	if key == "":
		return
	if index < inventory.get_count():
		selected_inventory_slot = mini(index, inventory.get_count() - 1)
	elif inventory.get_count() > 0:
		selected_inventory_slot = mini(selected_inventory_slot, inventory.get_count() - 1)
	else:
		selected_inventory_slot = 0
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
		var destination := player.pos + Vector2i(MazeGenerator.DX[dir], MazeGenerator.DY[dir])
		var target := _get_monster_at(destination)
		if target != null:
			_combat(target)
			return false
		player.pos = destination
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

func _get_continue_hint() -> String:
	return GameDirector.get_continue_hint(levels_data)

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
	var vp := get_viewport_rect().size
	PlatformService.refresh(vp)
	_refresh_layout()
	var dirty := false
	if log_timer > 0:
		log_timer -= delta
		if log_timer <= 0:
			if combat_log.size() > 0:
				combat_log.remove_at(0)
				dirty = true
	if low_hp_pulse > 0.0:
		low_hp_pulse = maxf(0.0, low_hp_pulse - delta * 0.8)
		dirty = true
	elif player.max_hp > 0 and float(player.hp) / float(player.max_hp) <= 0.3:
		low_hp_pulse = 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
		dirty = true
	exit_blink_timer += delta
	if exit_blink_timer >= 2.0:
		exit_blink_timer = 0.0
		exit_visible = !exit_visible
		dirty = true
	if game.can_move():
		attack_cooldown = maxf(0.0, attack_cooldown - delta)
		var monster_delta := delta
		if maze != null:
			var terrain_key: String = MazeGenerator.TERRAIN_KEY[maze.get_terrain(player.pos.x, player.pos.y)]
			var effect: Dictionary = level_terrain_effects.get(terrain_key, {})
			monster_delta *= maxf(0.45, 1.0 - float(effect.get("move_speed_bonus", 0.0)))
		if _move_monsters(monster_delta):
			dirty = true
	if dirty:
		_request_redraw()
	if needs_redraw:
		queue_redraw()
		needs_redraw = false

func _move_monsters(delta: float) -> bool:
	var changed := false
	var occupied: Dictionary = {player.pos: true}
	for m in monsters:
		if is_instance_valid(m):
			occupied[m.pos] = true
	for m in monsters.duplicate():
		if is_instance_valid(m) and m.is_alive():
			occupied.erase(m.pos)
			var previous_intent: int = m.next_move_dir
			var result: Dictionary = m.try_move(maze, occupied, player.pos, delta)
			changed = changed or result.moved or previous_intent != m.next_move_dir
			if result.attacked:
				_monster_attack(m)
				changed = true
			occupied[m.pos] = true
			if not player.is_alive():
				break
	return changed

func _draw() -> void:
	if game.is_difficulty_select():
		var save_hint := _get_continue_hint()
		maze_renderer.draw_difficulty_select(self, get_viewport_rect().size, selected_difficulty, save_hint)
		if show_new_journey_confirm:
			ui_panel.draw_confirm_overlay(
				self, get_viewport_rect().size,
				"切换难度将开始新旅途",
				"当前存档将被覆盖",
				"回车/→ 确认 · Esc/← 取消",
			)
		return

	if maze == null or maze.grid.is_empty():
		maze_renderer.draw_error_screen(self, get_viewport_rect().size)
		return

	game_view_composer.draw(self, current_layout, _draw_context())

func _draw_context() -> Dictionary:
	return {
		"maze": maze,
		"maze_width": maze_width,
		"maze_height": maze_height,
		"player": player,
		"monsters": monsters,
		"items": items,
		"exit_pos": exit_pos,
		"exit_visible": exit_visible,
		"game_won": game_won,
		"game_over": game_over,
		"paused": game.is_paused(),
		"visited": visited,
		"is_revealed": _is_revealed,
		"levels_data": levels_data,
		"current_level_index": current_level_index,
		"difficulty_name": game.get_difficulty_name(),
		"move_count": move_count,
		"terrain_name": _get_terrain_display(),
		"buff_display": _get_buff_display(),
		"combat_log": combat_log,
		"inventory": inventory,
		"key_tracker": key_tracker,
		"selected_slot": selected_inventory_slot,
		"guide_dir": _get_guide_direction(),
		"low_hp_pulse": low_hp_pulse,
	}


func _get_terrain_display() -> String:
	if maze == null:
		return current_terrain_name
	var terrain_key: String = MazeGenerator.TERRAIN_KEY[maze.get_terrain(player.pos.x, player.pos.y)]
	var effect: Dictionary = level_terrain_effects.get(terrain_key, {})
	var description := str(effect.get("description", ""))
	return current_terrain_name if description.is_empty() else "%s·%s" % [current_terrain_name, description]


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
