class_name TurnResolver
extends RefCounted

## Unified post-move processing chain (terrain → combat → pickup → buff → visit → win).

static func resolve_after_move(game) -> void:
	game._apply_terrain_effect()
	var target = game._get_monster_at(game.player.pos)
	if target != null:
		game._combat(target)
	else:
		game.move_count += 1
	var item = game._get_item_at(game.player.pos)
	if item != null:
		game._pick_up_item(item)
	game.player.tick_buff()
	game._mark_visited(game.player.pos)
	game.current_terrain_name = game.maze.get_terrain_name(game.player.pos.x, game.player.pos.y)
	if game.player.pos == game.exit_pos and not game.game_over:
		if game.key_tracker.has_all_keys():
			game.game_won = true
			AudioManager.play_victory()
		else:
			game._add_log("家人还没到齐！还需要找到 %d 个人" % game.key_tracker.get_remaining())
	game._request_redraw()
	game._update_mobile_ui()
