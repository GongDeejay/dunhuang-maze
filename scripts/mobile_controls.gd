class_name MobileControls
extends Node2D

signal move_pressed(dir: int)
signal action_pressed(action: String)

var is_mobile: bool = false
var layout: LayoutProfile = LayoutProfile.new()
var btn_radius: float = 40.0
var btn_spacing: float = 90.0
var func_btn_size: float = 50.0
var touch_start: Vector2 = Vector2.ZERO
var swipe_threshold: float = 30.0
var maze_touch_active: bool = false

var _dpad_centers: Array = []
var _func_centers: Dictionary = {}
var _func_labels: Dictionary = {}


func _ready() -> void:
	_refresh_mobile_flag()


func apply_layout(profile: LayoutProfile) -> void:
	layout = profile
	is_mobile = profile.show_touch_controls
	var scale := profile.ui_scale
	btn_radius = clampf(28.0 * scale, 28.0, 56.0)
	btn_spacing = btn_radius * 2.15
	func_btn_size = clampf(36.0 * scale, 36.0, 64.0)
	swipe_threshold = 24.0 * scale
	_rebuild_hit_zones()
	queue_redraw()


func _refresh_mobile_flag() -> void:
	PlatformService.refresh(get_viewport().get_visible_rect().size)
	is_mobile = PlatformService.use_mobile_ui or DisplayServer.is_touchscreen_available()


func _process(_delta: float) -> void:
	if is_mobile and layout.show_touch_controls:
		_rebuild_hit_zones()


func try_handle_input(event: InputEvent) -> bool:
	if not is_mobile or not layout.show_touch_controls:
		return false

	if event is InputEventScreenTouch:
		return _handle_pointer(event.position, event.pressed, not event.pressed)
	if event is InputEventScreenDrag and maze_touch_active:
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return _handle_pointer(event.position, event.pressed, not event.pressed)

	return false


func _handle_pointer(pos: Vector2, pressed: bool, released: bool) -> bool:
	if layout.controls_rect.size.y > 1.0 and layout.controls_rect.has_point(pos):
		if pressed:
			touch_start = pos
			if _handle_control_touch(pos):
				return true
		return true

	if layout.hud_rect.has_point(pos):
		return false

	if layout.maze_rect.size.y > 1.0 and layout.maze_rect.has_point(pos):
		if pressed:
			touch_start = pos
			maze_touch_active = true
			return true
		if released and maze_touch_active:
			maze_touch_active = false
			_handle_maze_swipe(pos)
			return true
		return true

	if released:
		maze_touch_active = false
	return false


func _handle_control_touch(pos: Vector2) -> bool:
	for entry in _dpad_centers:
		if pos.distance_to(entry.pos as Vector2) < btn_radius * 1.4:
			move_pressed.emit(entry.dir as int)
			return true
	for action in _func_centers:
		if pos.distance_to(_func_centers[action] as Vector2) < func_btn_size * 0.7:
			action_pressed.emit(action as String)
			return true
	return false


func _handle_maze_swipe(end_pos: Vector2) -> void:
	var diff := end_pos - touch_start
	if diff.length() < swipe_threshold:
		return
	if absi(diff.x) > absi(diff.y):
		move_pressed.emit(MazeGenerator.E if diff.x > 0 else MazeGenerator.W)
	else:
		move_pressed.emit(MazeGenerator.S if diff.y > 0 else MazeGenerator.N)


func _draw() -> void:
	if not is_mobile or layout.controls_rect.size.y <= 1.0:
		return
	_rebuild_hit_zones()
	var rect := layout.controls_rect
	var scale := layout.ui_scale
	draw_rect(rect, Color(0.08, 0.07, 0.06, 0.88))
	var alpha := 0.5
	var fs := int(clampf(rect.size.y * 0.22 * scale, 18, 36))

	if layout.is_portrait():
		_draw_portrait_controls(rect, alpha, fs)
	else:
		_draw_landscape_controls(rect, alpha, fs)


func _rebuild_hit_zones() -> void:
	_dpad_centers.clear()
	_func_centers.clear()
	_func_labels.clear()
	if not is_mobile or layout.controls_rect.size.y <= 1.0:
		return
	var rect := layout.controls_rect
	var alpha := 0.5
	var fs := int(clampf(rect.size.y * 0.22 * layout.ui_scale, 18, 36))
	if layout.is_portrait():
		_layout_portrait_zones(rect, alpha, fs)
	else:
		_layout_landscape_zones(rect, alpha, fs)


func _draw_portrait_controls(rect: Rect2, alpha: float, fs: int) -> void:
	_layout_portrait_zones(rect, alpha, fs)
	for entry in _dpad_centers:
		var pos: Vector2 = entry.pos
		var label: String = entry.label
		draw_circle(pos, btn_radius, Color(1, 1, 1, alpha * 0.28))
		draw_circle(pos, btn_radius, Color(1, 1, 1, alpha * 0.14), false, 2.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-fs / 2, fs / 3), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, alpha))

	for action in _func_centers:
		var pos: Vector2 = _func_centers[action]
		var label: String = _func_labels[action]
		var btn_rect := Rect2(pos.x - func_btn_size / 2, pos.y - func_btn_size / 2, func_btn_size, func_btn_size)
		draw_rect(btn_rect, Color(1, 1, 1, alpha * 0.22))
		draw_rect(btn_rect, Color(1, 1, 1, alpha * 0.14), false, 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(pos.x - func_btn_size * 0.38, pos.y + fs * 0.28), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.72), Color(1, 1, 1, alpha))


func _layout_portrait_zones(rect: Rect2, _alpha: float, _fs: int) -> void:
	var dpad_cx := rect.position.x + rect.size.x * 0.5
	var dpad_cy := rect.position.y + rect.size.y * 0.38
	var dirs := [
		["↑", MazeGenerator.N, Vector2(dpad_cx, dpad_cy - btn_spacing)],
		["←", MazeGenerator.W, Vector2(dpad_cx - btn_spacing, dpad_cy)],
		["→", MazeGenerator.E, Vector2(dpad_cx + btn_spacing, dpad_cy)],
		["↓", MazeGenerator.S, Vector2(dpad_cx, dpad_cy + btn_spacing)],
	]
	for d in dirs:
		_dpad_centers.append({"dir": d[1], "pos": d[2], "label": d[0]})

	var funcs := [
		["换", "cycle_item"], ["用", "use_item"], ["重开", "regenerate"], ["菜单", "menu"],
	]
	var btn_y := rect.position.y + rect.size.y * 0.82
	var gap := func_btn_size + 12.0
	var total_w := funcs.size() * gap - 12.0
	var start_x := rect.position.x + (rect.size.x - total_w) * 0.5 + func_btn_size * 0.5
	for i in funcs.size():
		var bx := start_x + i * gap
		_func_centers[funcs[i][1]] = Vector2(bx, btn_y)
		_func_labels[funcs[i][1]] = funcs[i][0]


func _draw_landscape_controls(rect: Rect2, alpha: float, fs: int) -> void:
	_layout_landscape_zones(rect, alpha, fs)
	for entry in _dpad_centers:
		var pos: Vector2 = entry.pos
		draw_circle(pos, btn_radius * 0.9, Color(1, 1, 1, alpha * 0.24))
		draw_string(ThemeDB.fallback_font, pos + Vector2(-6, 6), entry.label as String,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, alpha))
	for action in _func_centers:
		var pos: Vector2 = _func_centers[action]
		var btn_rect := Rect2(pos.x - func_btn_size / 2, pos.y - func_btn_size / 2, func_btn_size, func_btn_size)
		draw_rect(btn_rect, Color(1, 1, 1, alpha * 0.22))
		draw_string(ThemeDB.fallback_font, Vector2(pos.x - func_btn_size * 0.35, pos.y + fs * 0.25),
			_func_labels[action], HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.7), Color(1, 1, 1, alpha))


func _layout_landscape_zones(rect: Rect2, _alpha: float, _fs: int) -> void:
	var dpad_cx := rect.position.x + rect.size.x * 0.14
	var dpad_cy := rect.position.y + rect.size.y * 0.5
	var dirs := [
		["↑", MazeGenerator.N, Vector2(dpad_cx, dpad_cy - btn_spacing * 0.85)],
		["←", MazeGenerator.W, Vector2(dpad_cx - btn_spacing * 0.85, dpad_cy)],
		["→", MazeGenerator.E, Vector2(dpad_cx + btn_spacing * 0.85, dpad_cy)],
		["↓", MazeGenerator.S, Vector2(dpad_cx, dpad_cy + btn_spacing * 0.85)],
	]
	for d in dirs:
		_dpad_centers.append({"dir": d[1], "pos": d[2], "label": d[0]})

	var func_x := rect.position.x + rect.size.x * 0.86
	var funcs := [
		["换", "cycle_item", 0.12],
		["用", "use_item", 0.35],
		["重开", "regenerate", 0.58],
		["菜单", "menu", 0.81],
	]
	for f in funcs:
		var pos := Vector2(func_x, rect.position.y + rect.size.y * f[2])
		_func_centers[f[1]] = pos
		_func_labels[f[1]] = f[0]
