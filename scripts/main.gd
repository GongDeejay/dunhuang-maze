extends Node2D

const MeasureText = preload("res://scripts/presentation/measure_text.gd")

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
var level_elapsed := 0.0
var _cliff_hint_shown := false
var _bump_anim := -1.0
var _bump_anim_dir := -1
var low_hp_pulse: float = 0.0
const JourneyBranchesScript = preload("res://scripts/journey_branches.gd")
const WallFeedbackScript = preload("res://scripts/wall_feedback.gd")
const ATTACK_COOLDOWN := 0.35
const MoveBufferScript = preload("res://scripts/handlers/move_buffer.gd")
const HazardGateScript = preload("res://scripts/handlers/hazard_gate.gd")
var input_handler := InputHandler.new()
var attack_buffer = MoveBufferScript.new()
var hazard_gate = HazardGateScript.new()
var attack_cooldown := 0.0
var first_journey: FirstJourney
var _branch_visual_tick := 0.0
var wall_bumps := 0
var bump_tween: Tween
var _bumping := false
var _bump_wall_key := ""
var _bump_wall_at := -1.0
var _held_bump_dir := -2
var _held_bump_key := ""
var journey_card: JourneyCard
var advance_after_story := false
var third_chapter: ThirdChapter
var cave_chapter: MogaoChapter
var mogao_journey: MogaoJourney
var pattern_panel: PatternPanel
var pattern_prompt: Button
var route_notebook: RouteNotebook
var modal_release_guard := false
var modal_closed_frame := -1
var held_inputs: Dictionary = {}

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
	# 像素美术放大时保持硬边，避免浏览器缩放后的模糊插值。
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	journey_card = JourneyCard.new()
	add_child(journey_card)
	journey_card.dismissed.connect(_on_story_dismissed)
	pattern_panel = PatternPanel.new()
	add_child(pattern_panel)
	pattern_panel.dismissed.connect(_on_pattern_closed)
	pattern_panel.unlocked.connect(_on_pattern_unlocked)
	route_notebook = RouteNotebook.new()
	add_child(route_notebook)
	route_notebook.dismissed.connect(_on_pattern_closed)
	route_notebook.traced.connect(func():
		if first_journey and first_journey.study_route(maze):
			_add_log(TravelLore.text("roadbook", "reveal"))
			AudioManager.play_pickup()
			_request_redraw())
	var prompt_layer := CanvasLayer.new()
	prompt_layer.layer = 110
	add_child(prompt_layer)
	pattern_prompt = Button.new()
	pattern_prompt.text = "护纹木匣 · 查看纹样 [F]"
	pattern_prompt.add_theme_font_size_override("font_size", 17)
	pattern_prompt.custom_minimum_size.y = 48
	pattern_prompt.visible = false
	pattern_prompt.pressed.connect(_inspect_pattern)
	prompt_layer.add_child(pattern_prompt)
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
	if third_chapter != null or cave_chapter != null: return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		held_inputs.clear()
		input_handler.held.clear()
		attack_buffer.clear()
		hazard_gate.clear()
		if pattern_panel and pattern_panel.visible: pattern_panel.suspend()
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
	if third_chapter != null or cave_chapter != null: return
	if _modal_open() or _input_guarded(): return
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
	if mogao_journey and mogao_journey.encounter_focus(player.pos) and current_layout.is_portrait() and current_layout.maze_rect.size.y < 230:
		# Reclaim blank HUD space and the nonessential log strip only at the safe gate.
		# Keep the existing D-pad sizes and inventory chips intact.
		var hud_height := 112.0
		current_layout.hud_rect.size.y = hud_height
		current_layout.maze_rect = Rect2(0, hud_height, vp.x, current_layout.controls_rect.position.y - hud_height)
		current_layout.log_rect = Rect2()
	if mobile_controls:
		mobile_controls.drink_visible = first_journey != null and first_journey.water_skin > 0
		mobile_controls.apply_layout(current_layout)
		mobile_controls.visible = third_chapter == null and cave_chapter == null and not game.is_difficulty_select() and not show_new_journey_confirm and not _pattern_open() and not _gate_revealing() and not _notebook_open()
	if pattern_prompt:
		var resume_reveal := _gate_revealing() and game.is_paused()
		pattern_prompt.visible = resume_reveal or (mogao_journey != null and game.can_move() and not _modal_open() and mogao_journey.can_inspect(maze, player.pos))
		var note_label := "回看手记" if mogao_journey and mogao_journey.gate_open else "查看兔纹手记"
		if first_journey and first_journey.mural_found:
			pattern_prompt.visible = game.can_move() and not _modal_open()
			note_label = "回看壁画路书"
		pattern_prompt.text = "点击继续" if resume_reveal else (note_label if touch else note_label + " [F]")
		var area := current_layout.maze_rect
		pattern_prompt.size = Vector2(minf(180, maxf(0, area.size.x - 16)), 48)
		pattern_prompt.position = Vector2(area.get_center().x - pattern_prompt.size.x / 2, area.end.y - 78)
		if not current_layout.is_portrait() and not current_layout.is_side_hud():
			pattern_prompt.position.x = area.end.x - pattern_prompt.size.x - 8


func _keyboard_move_allowed() -> bool:
	return game.can_move() and not _modal_open() and not _input_guarded()


func _input(event: InputEvent) -> void:
	if third_chapter != null or cave_chapter != null: return
	_track_held_input(event)
	# Track presses while a card is open so the close frame cannot replay them.
	input_handler.handle_direction(event, _keyboard_move_allowed())
	_sync_held_bump()
	if _modal_open(): return
	if _input_guarded():
		get_viewport().set_input_as_handled()
		return
	if game.is_difficulty_select():
		return
	if pattern_prompt and pattern_prompt.visible and (event is InputEventScreenTouch or event is InputEventMouseButton):
		if pattern_prompt.get_global_rect().has_point(event.position): return
	if not current_layout.show_touch_controls:
		return
	if mobile_controls.try_handle_input(event):
		get_viewport().set_input_as_handled()

func _on_mobile_action(action: String) -> void:
	if third_chapter != null or cave_chapter != null: return
	if _modal_open() or _input_guarded(): return
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
		"drink":
			if game.can_move():
				_drink_water_skin(false)

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
	_close_third_chapter()
	_close_cave_chapter()
	attack_cooldown = 0.0
	attack_buffer.clear()
	level_elapsed = 0.0
	_cliff_hint_shown = false
	_bump_anim = -1.0
	hazard_gate.clear()
	input_handler.held.clear()
	if journey_card: journey_card.visible = false
	advance_after_story = false
	first_journey = null
	mogao_journey = null
	if pattern_panel: pattern_panel.visible = false
	if route_notebook: route_notebook.visible = false
	held_inputs.clear()
	modal_release_guard = false
	if level_idx >= 0:
		game.current_level_index = level_idx
	if current_level_index == 1:
		_start_cave_chapter()
		return
	if current_level_index == 2:
		_start_third_chapter()
		return

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
	if current_level_index == 0:
		first_journey = FirstJourney.new()
		first_journey.map_seed = randi()
		first_journey.build(maze)
	elif current_level_index == 1:
		mogao_journey = MogaoJourney.new()
		mogao_journey.build(maze)
	else:
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
	if first_journey:
		for child in get_children():
			if child is MonsterEntity or child is ItemEntity: child.queue_free()
		var spawned := first_journey.spawn(self, _on_monster_defeated)
		monsters = spawned.monsters
		items = spawned.items
	else:
		monsters = EntitySpawner.spawn_monsters(
			self, maze, maze_width, maze_height,
			level_monster_density, level_monster_scale, _on_monster_defeated,
			mogao_journey.spawn_exclusions if mogao_journey else {},
		)
		items = EntitySpawner.spawn_items(
			self, maze, maze_width, maze_height, monsters, level_key_count,
			[str(level.get("family_key", "family_1"))],
			mogao_journey.spawn_exclusions if mogao_journey else {},
			MogaoJourney.FAMILY if mogao_journey else Vector2i(-1, -1),
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
	if first_journey:
		_show_story({"title": "第一章 · 古道上的足迹", "body": "风停了，妈妈和两个孩子还没有消息。\n先沿着脚印寻找妈妈，再到东南的营地会合。路口有路牌，不必走遍所有岔路。\n读提示时战斗暂停；关闭提示后继续。", "button": "出发，寻找妈妈"})
	elif mogao_journey:
		_show_story({"title": "第二章 · 莫高窟", "body": "哥哥的脚印伸向栈道深处。\n找到他，一起平安离开。", "button": "沿栈道寻找哥哥"})
	_request_redraw()

func _story_open() -> bool:
	return journey_card != null and journey_card.visible

func _pattern_open() -> bool:
	return pattern_panel != null and pattern_panel.visible

func _modal_open() -> bool:
	return _story_open() or _pattern_open() or _gate_revealing() or _notebook_open()

func _notebook_open() -> bool:
	return route_notebook != null and route_notebook.visible

func _gate_revealing() -> bool:
	return mogao_journey != null and mogao_journey.revealing()

func _input_guarded() -> bool:
	return modal_release_guard or (modal_closed_frame >= 0 and Engine.get_process_frames() <= modal_closed_frame + 1)

func _track_held_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION: return
	var token := ""
	var pressed := false
	if event is InputEventKey:
		token = "key:%d" % event.keycode
		pressed = event.pressed
	elif event is InputEventScreenTouch:
		token = "touch:%d" % event.index
		pressed = event.pressed
	elif event is InputEventMouseButton:
		if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]: return
		token = "mouse:%d" % event.button_index
		pressed = event.pressed
	if token.is_empty(): return
	if pressed: held_inputs[token] = true
	else: held_inputs.erase(token)
	if held_inputs.is_empty(): modal_release_guard = false

func _inspect_pattern() -> void:
	if first_journey and first_journey.mural_found and game.can_move() and not _modal_open() and not _input_guarded():
		mobile_controls.maze_touch_active = false
		_open_roadbook()
		return
	if _gate_revealing() and game.is_paused():
		game.toggle_pause()
		_request_redraw()
		return
	if not mogao_journey or not game.can_move() or _modal_open() or _input_guarded(): return
	if not mogao_journey.can_inspect(maze, player.pos): return
	mobile_controls.maze_touch_active = false
	pattern_panel.open(mogao_journey.puzzle)
	_refresh_layout()

func _on_pattern_closed() -> void:
	mobile_controls.maze_touch_active = false
	modal_release_guard = not held_inputs.is_empty()
	modal_closed_frame = Engine.get_process_frames()
	if mogao_journey and mogao_journey.begin_reveal():
		AudioManager.play_gate_open()
	# Returning from a browser focus loss keeps the existing explicit pause intact.
	_refresh_layout()
	_request_redraw()

func _on_pattern_unlocked() -> void:
	if mogao_journey and mogao_journey.open_gate(maze):
		_prime_monster_intents()

func _close_third_chapter() -> void:
	if third_chapter == null: return
	third_chapter.shutdown()
	third_chapter.queue_free()
	third_chapter = null

func _close_cave_chapter() -> void:
	if cave_chapter == null: return
	cave_chapter.shutdown()
	cave_chapter.queue_free()
	cave_chapter = null

func _start_cave_chapter() -> void:
	for child in get_children():
		if child is MonsterEntity or child is ItemEntity: child.queue_free()
	monsters.clear(); items.clear(); maze = null
	inventory.clear(); key_tracker.setup(1)
	game.reset_round(); game.start_game()
	cave_chapter = MogaoChapter.new()
	var saved := SaveManager.load_progress()
	if int(saved.get("level_index", -1)) == 1:
		var network = saved.get("cave_network", {})
		cave_chapter.model.resume_network(int(saved.get("cave_room", 0)), network if network is Dictionary else {})
	cave_chapter.checkpoint_changed.connect(func(room_id: int): SaveManager.save_progress(1, selected_difficulty, player.level, player.xp, room_id, cave_chapter.model.save_network()))
	cave_chapter.menu_requested.connect(func():
		_close_cave_chapter()
		game.return_to_menu()
		_request_redraw())
	cave_chapter.completed.connect(func(): _new_game(2))
	add_child(cave_chapter)
	SaveManager.save_progress(1, selected_difficulty, player.level, player.xp, cave_chapter.model.room, cave_chapter.model.save_network())
	_refresh_layout(); queue_redraw()

func _start_third_chapter() -> void:
	for child in get_children():
		if child is MonsterEntity or child is ItemEntity: child.queue_free()
	monsters.clear()
	items.clear()
	maze = null
	game.start_game()
	third_chapter = ThirdChapter.new()
	third_chapter.difficulty = selected_difficulty
	third_chapter.max_hp = int(18 * float(DataLoader.get_difficulty().get("hp_multiplier", 1.0)))
	third_chapter.hp = third_chapter.max_hp
	third_chapter.menu_requested.connect(func():
		_close_third_chapter()
		game.return_to_menu()
		_request_redraw())
	third_chapter.replay_requested.connect(func():
		player.level = 1
		player.xp = 0
		_new_game(0))
	third_chapter.completed.connect(func():
		game.game_won = true
		SaveManager.clear_save())
	add_child(third_chapter)
	SaveManager.save_progress(2, selected_difficulty, player.level, player.xp)
	_refresh_layout()
	queue_redraw()

func _show_story(card: Dictionary) -> void:
	if journey_card and not card.is_empty():
		attack_buffer.clear()
		input_handler.held.set_blocked(true)
		journey_card.open_card(card)
		_request_redraw()

func _on_story_dismissed() -> void:
	if advance_after_story:
		advance_after_story = false
		_handle_regenerate()
	_request_redraw()

func _on_level_completed() -> void:
	if mogao_journey:
		advance_after_story = true
		_show_story({"title": "平安走出莫高窟", "body": "你们平安走出窟前栈道。哥哥将沿安全路线与妈妈会合。\n这次走了 %d 步\n%s\n还有弟弟。三危山的风里，或许能听见他的声音。" % [move_count, MeasureText.format_duration(level_elapsed)], "button": "继续 · 前往三危山"})
		return
	if not first_journey: return
	advance_after_story = true
	var discovery := first_journey.discovery_line()
	_show_story({
		"title": "与妈妈平安会合",
		"body": "你们沿着古道来到营地，终于能安心歇一口气。\n这次走了 %d 步\n%s\n%s\n妈妈先留在安全的营地。下一站：莫高窟，寻找哥哥。" % [move_count, MeasureText.format_duration(level_elapsed), discovery],
		"button": "继续 · 寻找哥哥",
		"sheet": AssetRegistry.fragment_sheet_path(),
		"fragment_mask": first_journey.fragment_mask(),
		"image_caption": "非文物原图",
	})

func _show_tutorial_if_needed() -> void:
	if first_journey: return
	if current_level_index != 0 or tutorial_done:
		return
	tutorial_done = true
	_add_tutorial("【目标】寻找散落的家人；用 WASD、方向键或滑动移动")


func _add_tutorial(message: String) -> void:
	_add_log(message)
	log_timer = 8.0


func _on_all_family_found() -> void:
	guide_assist_active = true
	_add_tutorial("【目标更新】妈妈找到了！跟随指引到营地会合" if first_journey else "【目标更新】本关家人找到了！跟随蓝色指引前往出口「门」")


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
	if mogao_journey and mogao_journey.guiding_to_gate() and not game_won and not game_over:
		return PathGuide.next_direction(maze, player.pos, MogaoJourney.GATE)
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
		if first_journey:
			_show_story(first_journey.rescue(maze, player))
		elif mogao_journey:
			_show_story(mogao_journey.rescue())
		key_tracker.add_key()
		_add_log("找到 %s (%s)" % [item.display_name, key_tracker.get_progress()])
		if not first_family_tip_shown and not first_journey:
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
	# Discovering new ground is progress, not evidence of being lost.
	if first_journey and not visited.has(player.pos):
		moves_since_progress = 0
		return
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
	attack_cooldown = ATTACK_COOLDOWN
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
	if third_chapter != null or cave_chapter != null: return
	if _gate_revealing():
		# A focus-loss pause must remain resumable even while the reveal is frozen.
		if game.is_paused() and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_P, KEY_ESCAPE, KEY_ENTER]: game.toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if _pattern_open() or _notebook_open() or _input_guarded():
		get_viewport().set_input_as_handled()
		return
	if _story_open():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
			journey_card.close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_inspect_pattern()
		get_viewport().set_input_as_handled()
		return
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
	if third_chapter != null or cave_chapter != null: return
	if _modal_open() or _input_guarded(): return
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
		GameAction.Type.DRINK:
			if game.can_move():
				_drink_water_skin(false)
		GameAction.Type.MOVE:
			_apply_move_action(action.direction, false)

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
		# First-level water is a one-time encounter, not an infinite walking heal.
		if first_journey: return
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
		_drink_water_skin(true)
		return
	var def = DataLoader.get_item_def(key)
	player.heal(def.get("value", 0))
	_add_log("自动使用 %s: 恢复 %d HP" % [def.get("name", ""), def.get("value", 0)])
	_request_redraw()

func _open_roadbook() -> void:
	if route_notebook == null or first_journey == null:
		return
	route_notebook.sketch.ranges = first_journey.roadbook_ranges()
	route_notebook.open(first_journey.notebook_path(maze), first_journey.route_studied)
	_refresh_layout()


func _drink_water_skin(automatic: bool) -> void:
	if first_journey == null or first_journey.water_skin <= 0:
		if not automatic:
			_add_log("水囊已喝完")
		return
	if player.hp >= player.max_hp:
		if not automatic:
			_add_log("体力已满，水囊先留着")
		return
	var amount: int = JourneyBranchesScript.scaled_heal(FirstJourney.WATER_SKIN_HEAL)
	var before := player.hp
	player.heal(amount)
	first_journey.water_skin = 0
	AudioManager.play_drink()
	var gained := player.hp - before
	if automatic:
		_add_log("体力不支，自动喝下水囊：恢复 %d 点体力" % gained)
	else:
		_add_log("喝下水囊：恢复 %d 点体力" % gained)
	_update_mobile_ui()


func _maybe_cliff_hint(dir: int) -> void:
	if _cliff_hint_shown or first_journey == null or dir != MazeGenerator.N:
		return
	if player.pos.y != 11 or player.pos.x < 6 or player.pos.x > 8:
		return
	_cliff_hint_shown = true
	_add_log(JourneyBranches.CLIFF_HINT)


func _sync_held_bump() -> void:
	var held_dir := input_handler.held.current()
	if held_dir == _held_bump_dir:
		return
	_held_bump_dir = held_dir
	_held_bump_key = ""
	_bump_wall_key = ""
	_bump_wall_at = -1.0


func _bump_player(dir: int) -> void:
	_sync_held_bump()
	var now := Time.get_ticks_msec() / 1000.0
	var wall_key: String = WallFeedbackScript.wall_key(player.pos, dir)
	# A sustained press counts once. The 0.25s cooldown must not fire again.
	if input_handler.held.current() == dir and _held_bump_key == wall_key:
		return
	if not WallFeedbackScript.allow(player.is_hurt, _bump_wall_key, _bump_wall_at, wall_key, now):
		return
	if input_handler.held.current() == dir:
		_held_bump_key = wall_key
	_bump_wall_key = wall_key
	_bump_wall_at = now
	wall_bumps += 1
	_maybe_cliff_hint(dir)
	AudioManager.play_wall_hit()
	_bump_anim = 0.0
	_bump_anim_dir = dir
	_bumping = true
	player.bump_offset = WallFeedbackScript.offset(dir) * 0.35
	_request_redraw()


func _apply_move_action(direction: int, repeated: bool) -> void:
	if not game.can_move():
		return
	if repeated and hazard_gate.blocks_repeat(direction, _standing_on_hazard(), _step_enters_hazard(direction)):
		# Hold-repeat stops on the safe cell. A later real press may enter.
		return
	if _try_move(direction):
		AudioManager.play_step()
		TurnResolver.resolve_after_move(self)
		if repeated:
			hazard_gate.note_after_repeat(direction, _standing_on_hazard())
		else:
			hazard_gate.authorize(direction, _standing_on_hazard())


func _step_enters_hazard(direction: int) -> bool:
	if maze == null or not maze.can_move(player.pos.x, player.pos.y, direction):
		return false
	var destination := player.pos + Vector2i(MazeGenerator.DX[direction], MazeGenerator.DY[direction])
	return _cell_hazard_damage(destination) > 0


func _standing_on_hazard() -> bool:
	return maze != null and _cell_hazard_damage(player.pos) > 0


func _cell_hazard_damage(cell: Vector2i) -> int:
	if maze == null or not maze.in_bounds(cell.x, cell.y):
		return 0
	var terrain_key: String = MazeGenerator.TERRAIN_KEY[maze.get_terrain(cell.x, cell.y)]
	var effect: Dictionary = level_terrain_effects.get(terrain_key, {})
	# Level data marks the damaging terrains. Easy's multiplier can round the
	# dealt damage to zero; the cell is still a wind-sand stop for hold-repeat.
	return int(effect.get("move_damage", 0))


func _try_move(dir: int) -> bool:
	if maze.can_move(player.pos.x, player.pos.y, dir):
		var destination := player.pos + Vector2i(MazeGenerator.DX[dir], MazeGenerator.DY[dir])
		var target := _get_monster_at(destination)
		if target != null:
			# A living enemy on cooldown keeps one direction, then strikes once it ends.
			if target.is_alive() and attack_cooldown > 0.0:
				attack_buffer.remember(dir)
				return false
			attack_buffer.clear()
			_combat(target)
			return false
		attack_buffer.clear()
		player.pos = destination
		player.moved.emit(player.pos)
		return true
	attack_buffer.clear()
	_bump_player(dir)
	return false

func _mark_visited(pos: Vector2i) -> void:
	visited[pos] = true
	if first_journey:
		first_journey.sync_visibility(pos, maze)
		var card := first_journey.enter(pos, maze, player)
		if card.get("kind", "") == "roadbook":
			_add_log(card.body)
			mobile_controls.maze_touch_active = false
			_open_roadbook()
		elif card.get("kind", "") == "hint":
			_add_log(str(card.get("body", "")))
		else: _show_story(card)
	elif mogao_journey:
		var had_scarf := mogao_journey.scarf_found
		_show_story(mogao_journey.enter(pos))
		if not had_scarf and mogao_journey.scarf_found:
			_add_log("是哥哥的围巾，他就在前面。")
	if first_journey or mogao_journey:
		for landmark_pos in maze.landmarks:
			if _is_revealed(landmark_pos): maze.landmarks[landmark_pos]["discovered"] = true

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
	if ui_panel != null and first_journey != null:
		ui_panel.prepare_water_skin(first_journey.water_skin > 0)
	if third_chapter != null or cave_chapter != null: return
	var was_revealing := _gate_revealing()
	if was_revealing and game.can_move():
		mogao_journey.tick_reveal(maze, delta)
		if not _gate_revealing():
			modal_release_guard = not held_inputs.is_empty()
			modal_closed_frame = Engine.get_process_frames()
		_request_redraw()
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
	if game.can_move() and not _modal_open() and not was_revealing:
		level_elapsed += delta
		attack_cooldown = maxf(0.0, attack_cooldown - delta)
		if _input_guarded():
			input_handler.held.set_blocked(true)
			attack_buffer.clear()
		else:
			input_handler.held.set_blocked(false)
			_flush_attack_buffer()
			_repeat_held_move(delta)
		var monster_delta := delta
		if maze != null:
			var terrain_key: String = MazeGenerator.TERRAIN_KEY[maze.get_terrain(player.pos.x, player.pos.y)]
			var effect: Dictionary = level_terrain_effects.get(terrain_key, {})
			monster_delta *= maxf(0.45, 1.0 - float(effect.get("move_speed_bonus", 0.0)))
		if _move_monsters(monster_delta):
			dirty = true
	else:
		input_handler.held.set_blocked(true)
		attack_buffer.clear()
	if first_journey and maze != null and game.can_move() and not _story_open():
		if first_journey.silhouette_time > 0.0:
			first_journey.tick_silhouette(delta, maze)
			dirty = true
		_branch_visual_tick += delta
		if _branch_visual_tick >= 0.1:
			_branch_visual_tick = 0.0
			dirty = true
	if _bump_anim >= 0.0 and is_instance_valid(player):
		_bump_anim += delta
		var out_t := WallFeedbackScript.OUT_SECONDS
		var back_t := WallFeedbackScript.BACK_SECONDS
		if _bump_anim >= out_t + back_t:
			player.bump_offset = Vector2.ZERO
			_bump_anim = -1.0
			_bumping = false
		elif _bump_anim <= out_t:
			player.bump_offset = WallFeedbackScript.offset(_bump_anim_dir) * (_bump_anim / out_t)
		else:
			var back := (_bump_anim - out_t) / back_t
			player.bump_offset = WallFeedbackScript.offset(_bump_anim_dir) * (1.0 - back)
		dirty = true
	elif _bumping:
		dirty = true
	if dirty:
		_request_redraw()
	if needs_redraw:
		queue_redraw()
		needs_redraw = false

func _flush_attack_buffer() -> void:
	if attack_cooldown > 0.0 or not attack_buffer.pending():
		return
	if not _keyboard_move_allowed():
		attack_buffer.clear()
		return
	_apply_move_action(attack_buffer.take(), false)


func _repeat_held_move(delta: float) -> void:
	hazard_gate.sync_held(input_handler.held.current())
	for direction in input_handler.held.pull(delta):
		if not _keyboard_move_allowed():
			input_handler.held.set_blocked(true)
			attack_buffer.clear()
			return
		_apply_move_action(direction, true)
		if not _keyboard_move_allowed():
			input_handler.held.set_blocked(true)
			attack_buffer.clear()
			return


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
	if third_chapter != null or cave_chapter != null: return
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
		"paused": game.is_paused() and not _pattern_open(),
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
		"journey_objective": first_journey.objective() if first_journey else (mogao_journey.objective() if mogao_journey else ""),
		"water_skin_line": first_journey.water_skin_hud() if first_journey else "",
		"water_skin_filled": first_journey != null and first_journey.water_skin > 0,
		"survey_ranges": first_journey.roadbook_ranges() if first_journey else [],
		"first_journey": first_journey != null or mogao_journey != null,
		"mogao_focus": mogao_journey != null and mogao_journey.encounter_focus(player.pos),
		"gate_revealing": _gate_revealing(),
		"gate_guiding": mogao_journey != null and mogao_journey.guiding_to_gate(),
	}


func _get_terrain_display() -> String:
	if maze == null:
		return current_terrain_name
	var terrain_key: String = MazeGenerator.TERRAIN_KEY[maze.get_terrain(player.pos.x, player.pos.y)]
	if mogao_journey: return mogao_journey.terrain_name(terrain_key)
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
