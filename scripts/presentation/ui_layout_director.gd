class_name UILayoutDirector
extends RefCounted
## 视口 → LayoutProfile（Follow + 比例顶栏）

const BREAKPOINT_NARROW := 400
const BREAKPOINT_DESKTOP := 900

const HUD_TOP_RATIO := 0.24
const HUD_TOP_MIN := 108.0
const HUD_TOP_MAX := 200.0

const HUD_SIDE_RATIO := 0.18
const HUD_SIDE_MIN := 200.0
const HUD_SIDE_MAX := 280.0

const HUD_STRIP_RATIO := 0.12
const HUD_STRIP_MIN := 56.0
const HUD_STRIP_MAX := 84.0

const LOG_RATIO := 0.08
const LOG_MIN := 32.0
const LOG_MAX := 56.0

const CONTROLS_RATIO := 0.14
const CONTROLS_MIN := 72.0
const CONTROLS_MAX := 120.0


static func compute(viewport: Vector2, touch_controls: bool = false) -> LayoutProfile:
	var profile := LayoutProfile.new()
	profile.viewport_size = viewport
	profile.show_touch_controls = touch_controls
	profile.ui_scale = PlatformService.get_ui_scale(viewport) if touch_controls else 1.0
	var vp_w := viewport.x
	var vp_h := viewport.y
	if vp_w <= 0.0 or vp_h <= 0.0:
		return profile

	var aspect := vp_h / vp_w
	if aspect > 1.05:
		_build_portrait(profile, vp_w, vp_h, touch_controls)
	elif vp_w >= BREAKPOINT_DESKTOP and aspect <= 1.05:
		_build_desktop_side(profile, vp_w, vp_h)
	else:
		_build_tablet_landscape(profile, vp_w, vp_h, touch_controls)
	return profile


static func _build_portrait(profile: LayoutProfile, vp_w: float, vp_h: float, touch: bool) -> void:
	profile.mode = LayoutProfile.Mode.PORTRAIT_COMPACT if vp_w < BREAKPOINT_NARROW else LayoutProfile.Mode.PORTRAIT_TOP
	profile.maze_mode = LayoutProfile.MazeMode.FOLLOW

	var hud_h := clampf(vp_h * HUD_TOP_RATIO * clampf(profile.ui_scale / 2.0, 1.0, 1.15), HUD_TOP_MIN, HUD_TOP_MAX)
	if profile.mode == LayoutProfile.Mode.PORTRAIT_COMPACT:
		hud_h = 166.0
	hud_h = maxf(hud_h, 166.0)

	var controls_h := 0.0
	if touch:
		controls_h = clampf(vp_h * 0.20 * clampf(profile.ui_scale / 2.0, 1.0, 1.2), 112.0, 180.0)
	var log_h := clampf(vp_h * LOG_RATIO, LOG_MIN, LOG_MAX)

	profile.hud_rect = Rect2(0.0, 0.0, vp_w, hud_h)
	var maze_top := hud_h
	var maze_bottom := vp_h - controls_h - log_h
	profile.maze_rect = Rect2(0.0, maze_top, vp_w, maxf(0.0, maze_bottom - maze_top))
	profile.log_rect = Rect2(0.0, maze_bottom, vp_w, log_h)
	profile.controls_rect = Rect2(0.0, vp_h - controls_h, vp_w, controls_h)


static func _build_desktop_side(profile: LayoutProfile, vp_w: float, vp_h: float) -> void:
	profile.mode = LayoutProfile.Mode.DESKTOP_SIDE
	profile.maze_mode = LayoutProfile.MazeMode.FIT_FULL
	var hud_w := clampf(vp_w * HUD_SIDE_RATIO, HUD_SIDE_MIN, HUD_SIDE_MAX)
	profile.maze_rect = Rect2(0.0, 0.0, vp_w - hud_w, vp_h)
	profile.hud_rect = Rect2(vp_w - hud_w, 0.0, hud_w, vp_h)
	profile.log_rect = Rect2()
	profile.controls_rect = Rect2()


static func _build_tablet_landscape(profile: LayoutProfile, vp_w: float, vp_h: float, touch: bool) -> void:
	profile.mode = LayoutProfile.Mode.TABLET_LANDSCAPE
	profile.maze_mode = LayoutProfile.MazeMode.FOLLOW

	var strip_h := clampf(vp_h * 0.14, 64.0, 96.0)
	var controls_h := clampf(vp_h * 0.12, 56.0, 96.0) if touch else 0.0
	var log_h := clampf(vp_h * 0.06, 28.0, 44.0)

	profile.hud_rect = Rect2(0.0, 0.0, vp_w, strip_h)
	var maze_top := strip_h
	var maze_bottom := vp_h - controls_h - log_h
	profile.maze_rect = Rect2(0.0, maze_top, vp_w, maxf(0.0, maze_bottom - maze_top))
	profile.log_rect = Rect2(0.0, maze_bottom, vp_w, log_h)
	profile.controls_rect = Rect2(0.0, vp_h - controls_h, vp_w, controls_h)
