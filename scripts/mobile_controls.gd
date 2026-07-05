class_name MobileControls
extends Node2D

signal move_pressed(dir: int)
signal action_pressed(action: String)

var is_mobile: bool = false
var is_portrait: bool = true
var btn_radius: float = 40.0
var btn_spacing: float = 90.0
var func_btn_size: float = 50.0
var touch_start: Vector2 = Vector2.ZERO
var swipe_threshold: float = 30.0
var font_scale: float = 1.0
var heart_full: Texture2D
var heart_empty: Texture2D

func _ready():
	is_mobile = OS.has_feature("mobile") or OS.has_feature("web")
	if not is_mobile:
		var vp = get_viewport_rect().size
		is_mobile = vp.x < 800 or vp.y < 600
	heart_full = load("res://assets/sprites/heart/full.png")
	heart_empty = load("res://assets/sprites/heart/empty.png")

func _process(_delta: float):
	var vp = get_viewport_rect().size
	var min_dim = minf(vp.x, vp.y)
	font_scale = clampf(min_dim / 200.0, 1.0, 3.0)
	btn_radius = clampf(min_dim * 0.07, 28.0, 50.0)
	btn_spacing = btn_radius * 2.3
	func_btn_size = clampf(min_dim * 0.09, 36.0, 55.0)

func _draw():
	if not is_mobile:
		return
	var vp = get_viewport_rect().size
	if is_portrait:
		_draw_portrait(vp)
	else:
		_draw_landscape(vp)
	_draw_toggle_button(vp)

func _draw_toggle_button(vp: Vector2) -> void:
	var btn_size = func_btn_size * 0.8
	var btn_x = vp.x - btn_size - 8
	var btn_y = 8.0
	var rect = Rect2(btn_x, btn_y, btn_size, btn_size)
	draw_rect(rect, Color(0, 0, 0, 0.6))
	draw_rect(rect, Color(1, 1, 1, 0.4), false, 2.0)
	var label = "横" if is_portrait else "竖"
	var fs = int(20 * font_scale)
	draw_string(ThemeDB.fallback_font, Vector2(btn_x + btn_size / 2 - fs / 2, btn_y + btn_size / 2 + fs / 3), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))

func _draw_portrait(vp: Vector2) -> void:
	var alpha = 0.5
	var fs = int(24 * font_scale)
	var small_fs = int(18 * font_scale)

	# D-pad in center
	var dpad_cx = vp.x / 2
	var dpad_cy = vp.y * 0.5
	var dirs = [
		["↑", Vector2(0, -1), Vector2(dpad_cx, dpad_cy - btn_spacing)],
		["←", Vector2(-1, 0), Vector2(dpad_cx - btn_spacing, dpad_cy)],
		["→", Vector2(1, 0), Vector2(dpad_cx + btn_spacing, dpad_cy)],
		["↓", Vector2(0, 1), Vector2(dpad_cx, dpad_cy + btn_spacing)]
	]
	for d in dirs:
		var pos = d[2] as Vector2
		draw_circle(pos, btn_radius, Color(1, 1, 1, alpha * 0.3))
		draw_circle(pos, btn_radius, Color(1, 1, 1, alpha * 0.15), false, 2.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-fs / 2, fs / 3), d[0] as String,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, alpha))

	# Bottom bar: info | dpad | buttons (all in one row)
	var bar_y = vp.y - 70.0
	var bar_center_x = vp.x / 2

	# Info - left side of bottom bar
	var info_x = 15.0
	draw_rect(Rect2(info_x - 5, bar_y - 10, 140 * font_scale, 65), Color(0, 0, 0, 0.5))
	
	# Hearts for HP
	var heart_size = 12.0 * font_scale
	for i in range(5):
		var heart_x = info_x + i * (heart_size + 4)
		var heart_sprite = heart_full if i < 3 else heart_empty
		if heart_sprite:
			draw_texture_rect(heart_sprite, Rect2(heart_x, bar_y, heart_size, heart_size), false)
	
	draw_string(ThemeDB.fallback_font, Vector2(info_x + 45 * font_scale, bar_y + 10), "家人", HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, Color(0.3, 0.8, 0.4))
	draw_string(ThemeDB.fallback_font, Vector2(info_x, bar_y + 30 * font_scale), "步数", HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, Color(0.7, 0.7, 0.7))

	# Function buttons - right side of bottom bar
	var func_x = vp.x - 20.0
	var func_buttons = [
		["E", "use_item"],
		["R", "regenerate"],
		["Q", "menu"]
	]
	for i in func_buttons.size():
		var bx = func_x - i * (func_btn_size + 8)
		var by = bar_y + 15
		var rect = Rect2(bx - func_btn_size / 2, by - func_btn_size / 2, func_btn_size, func_btn_size)
		draw_rect(rect, Color(1, 1, 1, alpha * 0.3))
		draw_rect(rect, Color(1, 1, 1, alpha * 0.15), false, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(bx - 6, by + 7), func_buttons[i][0] as String,
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * font_scale), Color(1, 1, 1, alpha))

func _draw_landscape(vp: Vector2) -> void:
	var alpha = 0.4
	var fs = int(18 * font_scale)

	# D-pad on left
	var dpad_cx = 80.0
	var dpad_cy = vp.y / 2
	var dirs = [
		["↑", Vector2(0, -1), Vector2(dpad_cx, dpad_cy - btn_spacing)],
		["←", Vector2(-1, 0), Vector2(dpad_cx - btn_spacing, dpad_cy)],
		["→", Vector2(1, 0), Vector2(dpad_cx + btn_spacing, dpad_cy)],
		["↓", Vector2(0, 1), Vector2(dpad_cx, dpad_cy + btn_spacing)]
	]
	for d in dirs:
		var pos = d[2] as Vector2
		draw_circle(pos, btn_radius * 0.7, Color(1, 1, 1, alpha * 0.3))
		draw_circle(pos, btn_radius * 0.7, Color(1, 1, 1, alpha * 0.1), false, 1.5)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-5, 5), d[0] as String,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, alpha))

	# Function buttons on right
	var func_x = vp.x - 35
	var func_buttons = [
		["E", Vector2(func_x, vp.y - 150), "use_item"],
		["R", Vector2(func_x, vp.y - 90), "regenerate"],
		["Q", Vector2(func_x, vp.y - 30), "menu"]
	]
	for b in func_buttons:
		var pos = b[1] as Vector2
		var rect = Rect2(pos.x - 22, pos.y - 22, 44, 44)
		draw_rect(rect, Color(1, 1, 1, alpha * 0.3))
		draw_rect(rect, Color(1, 1, 1, alpha * 0.1), false, 1.5)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-5, 6), b[0] as String,
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * font_scale), Color(1, 1, 1, alpha))

	# System info - top left
	var info_x = 15.0
	var info_y = 25.0
	var info_fs = int(14 * font_scale)
	draw_rect(Rect2(info_x - 5, info_y - 15, 130 * font_scale, 55), Color(0, 0, 0, 0.5))
	draw_string(ThemeDB.fallback_font, Vector2(info_x, info_y), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, info_fs, Color(1, 0.8, 0.3))
	draw_string(ThemeDB.fallback_font, Vector2(info_x + 40 * font_scale, info_y), "家人", HORIZONTAL_ALIGNMENT_LEFT, -1, info_fs, Color(0.3, 0.8, 0.4))
	draw_string(ThemeDB.fallback_font, Vector2(info_x, info_y + 25 * font_scale), "步数", HORIZONTAL_ALIGNMENT_LEFT, -1, info_fs, Color(0.7, 0.7, 0.7))

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

	# Check toggle button
	var btn_size = func_btn_size * 0.8
	var btn_x = vp.x - btn_size - 8
	var btn_y = 8.0
	var toggle_rect = Rect2(btn_x - 15, btn_y - 15, btn_size + 30, btn_size + 30)
	if toggle_rect.has_point(pos):
		is_portrait = not is_portrait
		queue_redraw()
		return

	if is_portrait:
		_handle_touch_portrait(pos, vp)
	else:
		_handle_touch_landscape(pos, vp)

func _handle_touch_portrait(pos: Vector2, vp: Vector2) -> void:
	var dpad_cx = vp.x / 2
	var dpad_cy = vp.y * 0.5
	var dpad_dirs = [
		[MazeGenerator.N, Vector2(dpad_cx, dpad_cy - btn_spacing)],
		[MazeGenerator.W, Vector2(dpad_cx - btn_spacing, dpad_cy)],
		[MazeGenerator.E, Vector2(dpad_cx + btn_spacing, dpad_cy)],
		[MazeGenerator.S, Vector2(dpad_cx, dpad_cy + btn_spacing)]
	]
	for d in dpad_dirs:
		if pos.distance_to(d[1] as Vector2) < btn_radius * 1.5:
			move_pressed.emit(d[0] as int)
			return

	var func_x = vp.x - 20.0
	var bar_y = vp.y - 70.0
	var func_names = ["use_item", "regenerate", "menu"]
	for i in func_names.size():
		var bx = func_x - i * (func_btn_size + 8)
		var by = bar_y + 15
		if pos.distance_to(Vector2(bx, by)) < func_btn_size:
			action_pressed.emit(func_names[i])
			return

func _handle_touch_landscape(pos: Vector2, vp: Vector2) -> void:
	var dpad_cx = 80.0
	var dpad_cy = vp.y / 2
	var dirs = [
		[MazeGenerator.N, Vector2(dpad_cx, dpad_cy - btn_spacing)],
		[MazeGenerator.W, Vector2(dpad_cx - btn_spacing, dpad_cy)],
		[MazeGenerator.E, Vector2(dpad_cx + btn_spacing, dpad_cy)],
		[MazeGenerator.S, Vector2(dpad_cx, dpad_cy + btn_spacing)]
	]
	for d in dirs:
		if pos.distance_to(d[1] as Vector2) < btn_radius * 0.7 * 1.5:
			move_pressed.emit(d[0] as int)
			return

	var func_x = vp.x - 35
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
