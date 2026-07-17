class_name InputHandler
extends RefCounted
## 将 InputEvent 转为 GameAction（Roguelike Basic Set EventHandler 模式）

func handle(
	event: InputEvent,
	ctx: Dictionary,
) -> GameAction:
	if ctx.get("show_confirm", false):
		return _handle_confirm(event)
	if ctx.get("difficulty_select", false):
		return _handle_difficulty_select(event)
	if ctx.get("game_won", false) or ctx.get("game_over", false):
		if event.is_action_pressed("regenerate"):
			return GameAction.regenerate()
		return GameAction.new()
	if event.is_action_pressed("regenerate"):
		return GameAction.regenerate()
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_E:
				return GameAction.use_item(int(ctx.get("selected_slot", 0)))
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				return GameAction.select_slot(event.keycode - KEY_1)
			KEY_Q:
				return GameAction.menu()
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		if ctx.get("use_mobile_ui", false):
			var hud: Rect2 = ctx.get("hud_rect", Rect2())
			if hud.size.y > 0.0 and hud.has_point(event.position):
				return GameAction.click_at(event.position)
			return GameAction.new()
		return GameAction.click_at(event.position)
	if event.is_action_pressed("move_up"):
		return GameAction.move(MazeGenerator.N)
	if event.is_action_pressed("move_down"):
		return GameAction.move(MazeGenerator.S)
	if event.is_action_pressed("move_left"):
		return GameAction.move(MazeGenerator.W)
	if event.is_action_pressed("move_right"):
		return GameAction.move(MazeGenerator.E)
	return GameAction.new()


func _handle_confirm(event: InputEvent) -> GameAction:
	if event.is_action_pressed("regenerate") or event.is_action_pressed("move_right"):
		return GameAction.confirm()
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
		return GameAction.cancel()
	return GameAction.new()


func _handle_difficulty_select(event: InputEvent) -> GameAction:
	if event.is_action_pressed("move_up"):
		return GameAction.cycle_difficulty(-1)
	if event.is_action_pressed("move_down"):
		return GameAction.cycle_difficulty(1)
	if event.is_action_pressed("regenerate") or event.is_action_pressed("move_right"):
		return GameAction.confirm()
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		return GameAction.click_at(event.position)
	return GameAction.new()
