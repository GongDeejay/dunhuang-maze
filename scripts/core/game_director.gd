extends Node
## 会话级流程：难度、存档、续关（Autoload: GameDirector）

func needs_new_journey_confirm(selected_difficulty: String) -> bool:
	var save := SaveManager.load_progress()
	if save.is_empty():
		return false
	return str(save.get("difficulty", "")) != selected_difficulty


func get_continue_hint(levels_data: Array) -> String:
	var save := SaveManager.load_progress()
	if save.is_empty():
		return ""
	var level_idx := int(save.get("level_index", 0))
	var diff_key := str(save.get("difficulty", "normal"))
	var diff_name: String = GameState.DIFFICULTY_NAMES.get(diff_key, diff_key)
	var level_name := "关卡 %d" % (level_idx + 1)
	if level_idx < levels_data.size():
		level_name = levels_data[level_idx].get("name", level_name)
	return "关卡检查点: %s · %s · Lv.%d（从本关重新开始）" % [
		diff_name, level_name, int(save.get("player_level", 1)),
	]


func begin_session(
	selected_difficulty: String,
	game: GameState,
	player: PlayerController,
	force_new: bool,
	start_level: Callable,
) -> void:
	DataLoader.set_difficulty(selected_difficulty)
	game.start_game()
	var save := SaveManager.load_progress()
	if force_new or save.is_empty() or str(save.get("difficulty", "")) != selected_difficulty:
		player.xp = 0
		player.level = 1
		start_level.call(0)
	else:
		player.level = int(save.get("player_level", 1))
		player.xp = int(save.get("player_xp", 0))
		start_level.call(int(save.get("level_index", 0)))
