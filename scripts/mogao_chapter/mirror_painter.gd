extends RefCounted
## Nearest-filtered mirror, lotus, beam, and one-segment preview.
## The texture already carries the cinnabar arrow. A code arrow is a separate hook and stays off.

const Beam = preload("res://scripts/mogao_chapter/mirror_beam.gd")
const DRAW_CODE_ARROW := false


static func draw_beams(canvas: CanvasItem, host) -> void:
	var model = host.model
	if model.room != CaveModel.MIRROR_ROOM:
		return
	var trace: Dictionary = model.beam_trace()
	_draw_beam(canvas, host, trace.get("cells", []))
	var kind := str(trace.get("stop_kind", ""))
	if kind == "back" or kind == "reverse":
		var end: Vector2 = host.point(trace.get("stop_cell", Vector2i.ZERO))
		canvas.draw_circle(end, maxf(4.0, host.unit * 0.08), Color(0.35, 0.28, 0.16, 0.9))


static func draw_previews(canvas: CanvasItem, host) -> void:
	var model = host.model
	if model.room != CaveModel.MIRROR_ROOM:
		return
	for seg in model.mirror_previews():
		var origin: Vector2 = host.point(seg["from"])
		var dir: Vector2 = Vector2(seg["dir"])
		var start: Vector2 = origin + dir * host.unit * 0.55
		var finish: Vector2 = host.point(seg["to"])
		var width := maxf(3.0, host.unit * 0.06)
		_draw_dashed(canvas, start, finish, Color(0.98, 0.86, 0.45, 0.8), width)
		var text := "还要转%d下" % int(seg["k"])
		var font_size := 16
		var text_size := MogaoChapter.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var label := preview_label_rect(origin, dir, host.unit, text_size)
		var baseline := label.position.y + MogaoChapter.FONT.get_ascent(font_size)
		canvas.draw_string(MogaoChapter.FONT, Vector2(label.position.x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("f5dba8"))


static func mirror_texture(rot: int, lit: bool) -> Texture2D:
	return _texture(AssetRegistry.mogao_sprite_path(Beam.sprite_key(rot, lit)))


static func lotus_texture(lit: bool) -> Texture2D:
	return _texture(AssetRegistry.mogao_sprite_path("lotus_stand_lit" if lit else "lotus_stand"))


static func draw_direction_mark(_canvas: CanvasItem, _center: Vector2, _rot: int, _length: float) -> void:
	# Reserved for a future code-drawn exit arrow. The PNG already shows one.
	if DRAW_CODE_ARROW:
		pass


static func mirror_sprite_rect(mirror: Vector2, unit: float) -> Rect2:
	return Rect2(mirror - Vector2(unit * 0.5, unit * 0.65), Vector2(unit, unit))


## The count belongs to the mirror the light is hitting, not the far end of the dashed line.
static func preview_label_rect(mirror: Vector2, beam_dir: Vector2, unit: float, text_size: Vector2) -> Rect2:
	var sprite := mirror_sprite_rect(mirror, unit)
	var gap := maxf(6.0, unit * 0.22)
	if absf(beam_dir.x) > absf(beam_dir.y):
		return Rect2(Vector2(sprite.get_center().x - text_size.x * 0.5, sprite.position.y - gap - text_size.y), text_size)
	return Rect2(Vector2(sprite.position.x - gap - text_size.x, sprite.get_center().y - text_size.y * 0.5), text_size)


static func segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var end := rect.position + rect.size
	var corners := [rect.position, Vector2(end.x, rect.position.y), end, Vector2(rect.position.x, end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false


static func _draw_beam(canvas: CanvasItem, host, cells: Array) -> void:
	if cells.size() < 2:
		return
	for i in range(cells.size() - 1):
		canvas.draw_line(host.point(cells[i]), host.point(cells[i + 1]), Color(1.0, 0.82, 0.35, 0.95), maxf(3.0, host.unit * 0.08), false)


static func _draw_dashed(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = 3.0) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 1.0:
		return
	var dir := delta / length
	var dash := 5.0
	var gap := 4.0
	var t := 0.0
	while t < length:
		var t2 := minf(t + dash, length)
		canvas.draw_line(a + dir * t, a + dir * t2, color, width, false)
		t += dash + gap


static func _texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)
