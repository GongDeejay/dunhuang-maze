class_name TurnResolver
extends RefCounted

## Unified post-move processing chain (terrain → combat → pickup → buff → visit → win).

static func resolve_after_move(game) -> void:
	game._apply_terrain_effect()
	if not _can_continue_turn(game):
		return

	var target = game._get_monster_at(game.player.pos)
	if target != null:
		game._combat(target)
		if not _can_continue_turn(game):
			game.move_count += 1
			_finish_turn(game)
			return

	game.move_count += 1
	game._update_guide_assist()

	if not _can_continue_turn(game):
		return

	var item = game._get_item_at(game.player.pos)
	if item != null:
		game._pick_up_item(item)

	if not _can_continue_turn(game):
		return

	game.player.tick_buff()
	game._mark_visited(game.player.pos)
	game.current_terrain_name = game.maze.get_terrain_name(game.player.pos.x, game.player.pos.y)

	if game.player.pos == game.exit_pos:
		if game.key_tracker.has_all_keys():
			game.game_won = true
			AudioManager.play_victory()
			var next_level: int = game.current_level_index + 1
			if next_level < game.levels_data.size():
				SaveManager.save_progress(
					next_level, game.selected_difficulty,
					game.player.level, game.player.xp,
				)
			else:
				SaveManager.clear_save()
			game._on_level_completed()
		else:
			game._add_log("家人还没到齐！还需要找到 %d 个人" % game.key_tracker.get_remaining())

	_finish_turn(game)

static func _can_continue_turn(game) -> bool:
	return game.player.is_alive() and not game.game_over and not game.game_won

static func _finish_turn(game) -> void:
	game._request_redraw()
	game._update_mobile_ui()
