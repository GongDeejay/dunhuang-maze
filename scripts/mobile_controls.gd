class_name MobileControls
extends Node2D

signal move_pressed(dir: int)
signal action_pressed(action: String)

var is_mobile: bool = false
var btn_radius: float = 36.0
var btn_spacing: float = 80.0
var func_btn_size: float = 50.0
var touch_start: Vector2 = Vector2.ZERO
var swipe_threshold: float = 30.0

func _ready():
	is_mobile = OS.has_feature("mobile") or OS.has_feature("web")
	if not is_mobile:
		var vp = get_viewport_rect().size
		is_mobile = vp.x < 800 or vp.y < 600

func _draw():
	if not is_mobile:
		return
	var vp = get_viewport_rect().size
	_draw_dpad(vp)
	_draw_func_buttons(vp)

func _draw_dpad(vp: Vector2) -> void:
	var center = Vector2(vp.x / 2, vp.y - 100)
	var alpha = 0.5
	var dirs = [
		["↑", Vector2(0, -1), center + Vector2(0, -btn_spacing)],
		["←", Vector2(-1, 0), center + Vector2(-btn_spacing, 0)],
		["→", Vector2(1, 0), center + Vector2(btn_spacing, 0)],
		["↓", Vector2(0, 1), center + Vector2(0, btn_spacing)]
	]
	for d in dirs:
		var pos = d[2] as Vector2
		draw_circle(pos, btn_radius, Color(1, 1, 1, alpha * 0.3))
		draw_circle(pos, btn_radius, Color(1, 1, 1, alpha * 0.1), false, 2.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-6, 6), d[0] as String,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, alpha))

func _draw_func_buttons(vp: Vector2) -> void:
	var x = vp.x - 60
	var alpha = 0.5
	var buttons = [
		["E", Vector2(x, vp.y - 200), "use_item"],
		["R", Vector2(x, vp.y - 130), "regenerate"],
		["Q", Vector2(x, vp.y - 60), "menu"]
	]
	for b in buttons:
		var pos = b[1] as Vector2
		var rect = Rect2(pos.x - func_btn_size / 2, pos.y - func_btn_size / 2, func_btn_size, func_btn_size)
		draw_rect(rect, Color(1, 1, 1, alpha * 0.3))
		draw_rect(rect, Color(1, 1, 1, alpha * 0.1), false, 2.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-5, 6), b[0] as String,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, alpha))

func _input(event: InputEvent) -> void:
	if not is_mobile:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
			_handle_touch(event.position)
		else:
			_handle_swipe(event.position)
	elif event is InputEventScreenDrag:
		var diff = event.position - touch_start
		if diff.length() > swipe_threshold:
			_handle_swipe(event.position)
			touch_start = event.position

func _handle_touch(pos: Vector2) -> void:
	var vp = get_viewport_rect().size
	var center = Vector2(vp.x / 2, vp.y - 100)

	if pos.distance_to(center) < btn_radius * 2:
		return

	var dpad_dirs = [
		[MazeGenerator.N, center + Vector2(0, -btn_spacing)],
		[MazeGenerator.W, center + Vector2(-btn_spacing, 0)],
		[MazeGenerator.E, center + Vector2(btn_spacing, 0)],
		[MazeGenerator.S, center + Vector2(0, btn_spacing)]
	]
	for d in dpad_dirs:
		if pos.distance_to(d[1] as Vector2) < btn_radius * 1.5:
			move_pressed.emit(d[0] as int)
			return

	var func_x = vp.x - 60
	var func_buttons = [
		["use_item", Vector2(func_x, vp.y - 200)],
		["regenerate", Vector2(func_x, vp.y - 130)],
		["menu", Vector2(func_x, vp.y - 60)]
	]
	for b in func_buttons:
		if pos.distance_to(b[1] as Vector2) < func_btn_size:
			action_pressed.emit(b[0] as String)
			return

func _handle_swipe(end_pos: Vector2) -> void:
	var diff = end_pos - touch_start
	if diff.length() < swipe_threshold:
		return
	if absi(diff.x) > absi(diff.y):
		move_pressed.emit(MazeGenerator.E if diff.x > 0 else MazeGenerator.W)
	else:
		move_pressed.emit(MazeGenerator.S if diff.y > 0 else MazeGenerator.N)

func handle_click移动(click_pos: Vector2, player_pos: Vector2i, cell_size: float, offset: Vector2, scale: float) -> int:
	var cs = cell_size * scale
	var grid_x = int((click_pos.x - offset.x) / cs)
	var grid_y = int((click_pos.y - offset.y) / cs)
	var diff_x = grid_x - player_pos.x
	var diff_y = grid_y - player_pos.y

	if absi(diff_x) + absi(diff_y) != 1:
		return -1

	if diff_x == 1:
		return MazeGenerator.E
	elif diff_x == -1:
		return MazeGenerator.W
	elif diff_y == 1:
		return MazeGenerator.S
	elif diff_y == -1:
		return MazeGenerator.N
	return -1
