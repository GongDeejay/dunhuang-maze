extends Node
## Web / 移动 / 桌面平台检测与显示参数（Autoload: PlatformService）

var is_web: bool = false
var is_mobile_os: bool = false
var is_touch_available: bool = false
var use_mobile_ui: bool = false

const MOBILE_VIEWPORT_MAX := 900


func _ready() -> void:
	refresh()


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
		return 1.0
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
