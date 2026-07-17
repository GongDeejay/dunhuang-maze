class_name LayoutProfile
extends RefCounted
## 一帧 UI 布局快照：各区域矩形 + 模式

enum Mode {
	DESKTOP_SIDE,
	TABLET_LANDSCAPE,
	PORTRAIT_TOP,
	PORTRAIT_COMPACT,
}

enum MazeMode {
	FIT_FULL,
	FOLLOW,
}

var mode: Mode = Mode.DESKTOP_SIDE
var maze_mode: MazeMode = MazeMode.FIT_FULL
var viewport_size: Vector2 = Vector2.ZERO
var maze_rect: Rect2 = Rect2()
var hud_rect: Rect2 = Rect2()
var log_rect: Rect2 = Rect2()
var controls_rect: Rect2 = Rect2()
var show_touch_controls: bool = false
var ui_scale: float = 1.0

func is_portrait() -> bool:
	return mode == Mode.PORTRAIT_TOP or mode == Mode.PORTRAIT_COMPACT

func is_side_hud() -> bool:
	return mode == Mode.DESKTOP_SIDE
