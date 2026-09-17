class_name HeartBar
extends RefCounted
## 心形 HP 条：固定颗数分段（非 1:1），按血量比例填充

const DEFAULT_SLOTS := 5
const MIN_SLOTS := 3
const MAX_SLOTS := 8

var heart_full: Texture2D
var heart_empty: Texture2D

func _init() -> void:
	var paths := AssetRegistry.heart_paths()
	if ResourceLoader.exists(paths.full):
		heart_full = load(paths.full)
	if ResourceLoader.exists(paths.empty):
		heart_empty = load(paths.empty)


func slot_count_for_width(max_width: float) -> int:
	if max_width < 110.0:
		return 4
	if max_width < 160.0:
		return 5
	return 6


func draw(
	canvas: CanvasItem,
	origin: Vector2,
	max_width: float,
	hp: int,
	max_hp: int,
	low_hp_pulse: float = 0.0,
	slot_count: int = -1,
	max_heart_size: float = 28.0,
) -> float:
	var count := slot_count if slot_count > 0 else slot_count_for_width(max_width)
	count = clampi(count, MIN_SLOTS, MAX_SLOTS)
	var hp_ratio := float(hp) / float(maxi(max_hp, 1))
	if heart_full == null or heart_empty == null:
		return _draw_fallback(canvas, origin, max_width, hp_ratio, low_hp_pulse)

	var gap := 3.0
	var size := clampf((max_width - gap * float(count - 1)) / float(count), 18.0, max_heart_size)
	var filled := int(round(hp_ratio * float(count)))
	filled = clampi(filled, 0, count)

	var x := origin.x
	for i in count:
		var is_filled := i < filled
		var tex := heart_full if is_filled else heart_empty
		var tint := Color.WHITE
		if is_filled and hp_ratio <= 0.3 and low_hp_pulse > 0.0:
			tint = Color.WHITE.lerp(Color(1.0, 0.35, 0.25), clampf(low_hp_pulse, 0.0, 1.0))
		canvas.draw_texture_rect(tex, Rect2(x, origin.y, size, size), false, tint)
		x += size + gap
	return size


func _draw_fallback(
	canvas: CanvasItem,
	origin: Vector2,
	max_width: float,
	hp_ratio: float,
	low_hp_pulse: float,
) -> float:
	var bar_h := 12.0
	canvas.draw_rect(Rect2(origin.x, origin.y, max_width, bar_h), Color(0.3, 0.1, 0.1))
	var bar_color := Color(0.2, 0.7, 0.3) if hp_ratio > 0.3 else Color(0.9, 0.15, 0.1)
	if hp_ratio <= 0.3 and low_hp_pulse > 0.0:
		bar_color = bar_color.lerp(Color(1.0, 0.2, 0.15), clampf(low_hp_pulse, 0.0, 1.0))
	canvas.draw_rect(Rect2(origin.x, origin.y, max_width * hp_ratio, bar_h), bar_color)
	return bar_h
