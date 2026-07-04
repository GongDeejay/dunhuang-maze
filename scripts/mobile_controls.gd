class_name MobileControls
extends Node2D

signal move_pressed(dir: int)
signal action_pressed(action: String)

var is_mobile: bool = false
var is_portrait: bool = false
var btn_radius: float = 40.0
var btn_spacing: float = 90.0
var func_btn_size: float = 55.0
var touch_start: Vector2 = Vector2.ZERO
var swipe_threshold: float = 30.0

func _ready():
	is_mobile = OS.has_feature("mobile") or OS.has_feature("web")
	if not is_mobile:
		var vp = get_viewport_rect().size
		is_mobile = vp.x < 800 or vp.y < 600

func _process(_delta: float):
	var vp = get_viewport_rect().size
	is_portrait = vp.y > vp.x

func _draw():
	if not is_mobile:
		return
	var vp = get_viewport_rect().size
	if is_portrait:
		_draw_portrait(vp)
	else:
		_draw_landscape(vp)

func _draw_portrait(vp: Vector2) -> void:
	var alpha = 0.5
	var dpad_center = Vector2(vp.x / 2, vp.y - 140)

	# D-pad
	var dirs = [
		["↑", Vector2(0, -1), dpad_center + Vector2(0, -btn_spacing)],
		["←", Vector2(-1, 0), dpad_center + Vector2(-btn_spacing, 0)],
		["→", Vector2(1, 0), dpad_center + Vector2(btn_spacing, 0)],
		["↓", Vector2(0, 1), dpad_center + Vector2(0, btn_spacing)]
	]
	for d in dirs:
		var pos = d[2] as Vector2
		draw_circle(pos, btn_radius, Color(1, 1, 1, alpha * 0.3))
		draw_circle(pos, btn_radius, Color(1, 1, 1, alpha * 0.15), false, 2.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-8, 8), d[0] as String,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, alpha))

	# Function buttons at bottom
	var func_y = vp.y - 40
	var func_start_x = vp.x / 2 - 80
	var func_buttons = [
		["E", "use_item"],
		["R", "regenerate"],
		["Q", "menu"]
	]
	for i in func_buttons.size():
		var pos = Vector2(func_start_x + i * 60, func_y)
		var rect = Rect2(pos.x - func_btn_size / 2, pos.y - func_btn_size / 2, func_btn_size, func_btn_size)
		draw_rect(rect, Color(1, 1, 1, alpha * 0.3))
		draw_rect(rect, Color(1, 1, 1, alpha * 0.15), false, 2.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-6, 7), func_buttons[i][0] as String,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, alpha))

func _draw_landscape(vp: Vector2) -> void:
	var alpha = 0.4
	var dpad_center = Vector2(80, vp.y / 2)

	# Smaller D-pad on left
	var small_spacing = 55.0
	var small_radius = 28.0
	var dirs = [
		["↑", Vector2(0, -1), dpad_center + Vector2(0, -small_spacing)],
		["←", Vector2(-1, 0), dpad_center + Vector2(-small_spacing, 0)],
		["→", Vector2(1, 0), dpad_center + Vector2(small_spacing, 0)],
		["↓", Vector2(0, 1), dpad_center + Vector2(0, small_spacing)]
	]
	for d in dirs:
		var pos = d[2] as Vector2
		draw_circle(pos, small_radius, Color(1, 1, 1, alpha * 0.3))
		draw_circle(pos, small_radius, Color(1, 1, 1, alpha * 0.1), false, 1.5)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-5, 5), d[0] as String,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, alpha))

	# Function buttons on right
	var func_x = vp.x - 40
	var func_buttons = [
		["E", Vector2(func_x, vp.y - 150), "use_item"],
		["R", Vector2(func_x, vp.y - 90), "regenerate"],
		["Q", Vector2(func_x, vp.y - 30), "menu"]
	]
	for b in func_buttons:
		var pos = b[1] as Vector2
		var rect = Rect2(pos.x - 25, pos.y - 25, 50, 50)
		draw_rect(rect, Color(1, 1, 1, alpha * 0.3))
		draw_rect(rect, Color(1, 1, 1, alpha * 0.1), false, 1.5)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-5, 6), b[0] as String,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, alpha))

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

	if is_portrait:
		_handle_touch_portrait(pos, vp)
	else:
		_handle_touch_landscape(pos, vp)

func _handle_touch_portrait(pos: Vector2, vp: Vector2) -> void:
	var dpad_center = Vector2(vp.x / 2, vp.y - 140)
	var dpad_dirs = [
		[MazeGenerator.N, dpad_center + Vector2(0, -btn_spacing)],
		[MazeGenerator.W, dpad_center + Vector2(-btn_spacing, 0)],
		[MazeGenerator.E, dpad_center + Vector2(btn_spacing, 0)],
		[MazeGenerator.S, dpad_center + Vector2(0, btn_spacing)]
	]
	for d in dpad_dirs:
		if pos.distance_to(d[1] as Vector2) < btn_radius * 1.5:
			move_pressed.emit(d[0] as int)
			return

	var func_y = vp.y - 40
	var func_start_x = vp.x / 2 - 80
	var func_names = ["use_item", "regenerate", "menu"]
	for i in func_names.size():
		var btn_pos = Vector2(func_start_x + i * 60, func_y)
		if pos.distance_to(btn_pos) < func_btn_size:
			action_pressed.emit(func_names[i])
			return

func _handle_touch_landscape(pos: Vector2, vp: Vector2) -> void:
	var dpad_center = Vector2(80, vp.y / 2)
	var small_spacing = 55.0
	var dpad_dirs = [
		[MazeGenerator.N, dpad_center + Vector2(0, -small_spacing)],
		[MazeGenerator.W, dpad_center + Vector2(-small_spacing, 0)],
		[MazeGenerator.E, dpad_center + Vector2(small_spacing, 0)],
		[MazeGenerator.S, dpad_center + Vector2(0, small_spacing)]
	]
	for d in dpad_dirs:
		if pos.distance_to(d[1] as Vector2) < 35:
			move_pressed.emit(d[0] as int)
			return

	var func_x = vp.x - 40
	var func_buttons = [
		["use_item", Vector2(func_x, vp.y - 150)],
		["regenerate", Vector2(func_x, vp.y - 90)],
		["menu", Vector2(func_x, vp.y - 30)]
	]
	for b in func_buttons:
		if pos.distance_to(b[1] as Vector2) < 30:
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
