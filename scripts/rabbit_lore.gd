class_name RabbitLore
extends RefCounted
## One source for the loading notebook, reference plate and physical gate.
const TEXTURE = preload("res://assets/lore/three_hares.svg")
static var _entry: Dictionary = {}

static func entry() -> Dictionary:
	if _entry.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lore/three_hares.json"))
		if parsed is Dictionary: _entry = parsed
	return _entry

static func text(key: String) -> String:
	return str(entry().get(key, ""))

static func draw_plate(canvas: CanvasItem, rect: Rect2, shared: bool = true) -> void:
	canvas.draw_texture_rect(TEXTURE, rect, false)
	if shared: return
	# Split the three common ears into six; colour and bodies remain identical.
	var center := rect.get_center()
	var scale := rect.size.x / 320.0
	for i in 3:
		var angle := i * TAU / 3.0
		var points := PackedVector2Array()
		for point in [Vector2(160, 117), Vector2(176, 140), Vector2(190, 164), Vector2(197, 181)]:
			points.append(center + (point - Vector2(160, 160)).rotated(angle) * scale)
		canvas.draw_polyline(points, Color("294f50"), maxf(3.0, scale * 9.0), true)
