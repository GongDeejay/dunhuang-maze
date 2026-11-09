extends Control
## Nearest-filtered sprites for the mirror cave. Beam lines stay in _draw.
## Sprite2D is separate from the optional code arrow so the texture can be replaced alone.

const Painter = preload("res://scripts/mogao_chapter/mirror_painter.gd")
var host: Control
var lotus: Sprite2D
var mirror_sprites: Dictionary = {}
var preview_layer: Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for mirror in CaveModel.MIRROR_DEFS:
		mirror_sprites[mirror["id"]] = _make_sprite()
	lotus = _make_sprite()
	preview_layer = Node2D.new()
	preview_layer.z_index = 1
	add_child(preview_layer)
	preview_layer.draw.connect(_draw_preview)


func _make_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.z_index = 0
	add_child(sprite)
	return sprite


func _process(_delta: float) -> void:
	if host == null or not is_instance_valid(host):
		return
	var show: bool = host.model.room == CaveModel.MIRROR_ROOM
	if not show:
		for id in mirror_sprites:
			mirror_sprites[id].visible = false
		lotus.visible = false
		return
	for mirror in CaveModel.MIRROR_DEFS:
		var sprite: Sprite2D = mirror_sprites[mirror["id"]]
		var tint := Color(1, 1, 1, 1)
		if host.model.back_flash > 0.0 and host.model.back_flash_cell == mirror["cell"]:
			var blink := 0.5 + 0.5 * absf(sin(host.model.back_flash * 28.0))
			tint = Color(1.0, 0.96, 0.72).lerp(Color(1.55, 1.35, 0.7), blink)
		_place(sprite, mirror["cell"], Painter.mirror_texture(host.model.mirror_rot_of(mirror["id"]), _struck(mirror["cell"])))
		sprite.modulate = tint
	_place(lotus, CaveModel.MIRROR_LOTUS, Painter.lotus_texture(host.model.lotus_lit()))
	queue_redraw()
	preview_layer.queue_redraw()


func _draw() -> void:
	if host == null or not is_instance_valid(host):
		return
	Painter.draw_beams(self, host)


func _draw_preview() -> void:
	if host == null or not is_instance_valid(host):
		return
	Painter.draw_previews(preview_layer, host)


func _struck(cell: Vector2i) -> bool:
	var mirrors: Array = host.model.beam_trace().get("mirrors", [])
	return mirrors.has(cell)


func _place(sprite: Sprite2D, cell: Vector2i, texture: Texture2D) -> void:
	if texture == null:
		sprite.visible = false
		return
	var u: float = host.unit
	var p: Vector2 = host.point(cell)
	sprite.texture = texture
	sprite.visible = host.model.room == CaveModel.MIRROR_ROOM
	sprite.position = Vector2(p.x, p.y - u * 0.15)
	var px := float(texture.get_width())
	sprite.scale = Vector2(u / px, u / px)
