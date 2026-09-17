extends Node
## Web / 移动 / 桌面平台检测与显示参数（Autoload: PlatformService）

var is_web: bool = false
var is_mobile_os: bool = false
var is_touch_available: bool = false
var use_mobile_ui: bool = false

const MOBILE_VIEWPORT_MAX := 900
var _metrics_elapsed := 0.0


func _ready() -> void:
	refresh()
	if is_web:
		_sync_browser_scale()
	set_process(is_web)


func _process(delta: float) -> void:
	_metrics_elapsed += delta
	if _metrics_elapsed >= 0.5:
		_metrics_elapsed = 0.0
		_sync_browser_scale()


static func browser_content_scale(pixel_ratio: float, font_px: float) -> float:
	# Layout is measured in browser CSS pixels at the user's default text size.
	# Keep the full-resolution canvas; Godot also transforms pointer hit testing.
	return maxf(pixel_ratio, 0.25) * clampf(font_px / 16.0, 0.75, 2.0)


func _sync_browser_scale() -> void:
	var metrics = JavaScriptBridge.eval("""
		JSON.stringify({
			ratio: window.devicePixelRatio || 1,
			font: parseFloat(getComputedStyle(document.documentElement).fontSize) || 16
		})
	""")
	if not metrics is String:
		return
	var values = JSON.parse_string(metrics)
	if not values is Dictionary:
		return
	var scale := browser_content_scale(float(values.get("ratio", 1.0)), float(values.get("font", 16.0)))
	var root := get_tree().root
	if not is_equal_approx(root.content_scale_factor, scale):
		root.content_scale_factor = scale


func refresh(viewport_size: Vector2 = Vector2.ZERO) -> void:
	is_web = OS.has_feature("web")
	is_mobile_os = OS.has_feature("mobile")
	is_touch_available = DisplayServer.is_touchscreen_available()
	use_mobile_ui = _compute_mobile_ui(viewport_size)


func _compute_mobile_ui(viewport_size: Vector2) -> bool:
	if is_mobile_os:
		return true
	if viewport_size == Vector2.ZERO:
		var tree := get_tree()
		if tree != null and tree.root != null:
			viewport_size = tree.root.get_visible_rect().size
	if viewport_size == Vector2.ZERO:
		return false
	# Web 上 iPhone Safari 常检测不到触摸屏，用视口形态兜底
	if is_web:
		if is_portrait_viewport(viewport_size) or viewport_size.x < MOBILE_VIEWPORT_MAX:
			return true
	if is_touch_available and viewport_size.x < MOBILE_VIEWPORT_MAX:
		return true
	return viewport_size.x < 800 or viewport_size.y < 600


func get_ui_scale(viewport_size: Vector2 = Vector2.ZERO) -> float:
	if viewport_size == Vector2.ZERO:
		var tree := get_tree()
		if tree != null and tree.root != null:
			viewport_size = tree.root.get_visible_rect().size
	if not use_mobile_ui and not is_portrait_viewport(viewport_size):
		if is_web:
			return 1.0 # Browser text scale is already applied to the root canvas.
		return clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 1.0, 1.4)
	if is_portrait_viewport(viewport_size):
		return 2.0
	if use_mobile_ui:
		return 1.5
	return 1.0


func get_target_cell_size(base: int = 40) -> int:
	if use_mobile_ui:
		return base + 4
	return base


func is_portrait_viewport(viewport_size: Vector2) -> bool:
	if viewport_size == Vector2.ZERO:
		return false
	return viewport_size.y / viewport_size.x > 1.05


func get_platform_label() -> String:
	if is_web and use_mobile_ui:
		return "web-mobile"
	if is_web:
		return "web-desktop"
	if is_mobile_os:
		return "native-mobile"
	return "desktop"
