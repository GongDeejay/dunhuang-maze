extends RefCounted
## Nearest-filtered mirror, lotus, beam, and one-segment preview.
## The texture already carries the cinnabar arrow. A code arrow is a separate hook and stays off.

const Beam = preload("res://scripts/mogao_chapter/mirror_beam.gd")
const DRAW_CODE_ARROW := false


static func draw(canvas: CanvasItem, host) -> void:
	var model = host.model
	if model.room != CaveModel.MIRROR_ROOM:
		return
	var trace: Dictionary = model.beam_trace()
	_draw_beam(canvas, host, trace.get("cells", []))
	for seg in model.mirror_previews():
		_draw_dashed(canvas, host.point(seg["from"]), host.point(seg["to"]), Color(0.98, 0.86, 0.45, 0.55))
	# Sprites are Sprite2D children. This canvas only draws the beam and the one-step preview.


static func mirror_texture(rot: int, lit: bool) -> Texture2D:
	return _texture(AssetRegistry.mogao_sprite_path(Beam.sprite_key(rot, lit)))


static func lotus_texture(lit: bool) -> Texture2D:
	return _texture(AssetRegistry.mogao_sprite_path("lotus_stand_lit" if lit else "lotus_stand"))


static func draw_direction_mark(_canvas: CanvasItem, _center: Vector2, _rot: int, _length: float) -> void:
	# Reserved for a future code-drawn exit arrow. The PNG already shows one.
	if DRAW_CODE_ARROW:
		pass


static func _draw_beam(canvas: CanvasItem, host, cells: Array) -> void:
	if cells.size() < 2:
		return
	for i in range(cells.size() - 1):
		canvas.draw_line(host.point(cells[i]), host.point(cells[i + 1]), Color(1.0, 0.82, 0.35, 0.95), maxf(3.0, host.unit * 0.08), false)


static func _draw_dashed(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color) -> void:
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
		canvas.draw_line(a + dir * t, a + dir * t2, color, 3.0, false)
		t += dash + gap


static func _texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)
