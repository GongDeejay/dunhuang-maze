extends Control
## Nearest-filtered sprites for the mirror cave. Beam lines stay in _draw.
## Sprite2D is separate from the optional code arrow so the texture can be replaced alone.

const Painter = preload("res://scripts/mogao_chapter/mirror_painter.gd")
var host: Control
var fixed_mirror: Sprite2D
var turn_mirror: Sprite2D
var lotus: Sprite2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fixed_mirror = _make_sprite()
	turn_mirror = _make_sprite()
	lotus = _make_sprite()


func _make_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	add_child(sprite)
	return sprite


func _process(_delta: float) -> void:
	if host == null or not is_instance_valid(host):
		return
	var show: bool = host.model.room == CaveModel.MIRROR_ROOM
	if not show:
		fixed_mirror.visible = false
		turn_mirror.visible = false
		lotus.visible = false
		return
	_place(fixed_mirror, CaveModel.MIRROR_FIXED_CELL, Painter.mirror_texture(CaveModel.MIRROR_FIXED_ROT, _struck(CaveModel.MIRROR_FIXED_CELL)))
	_place(turn_mirror, CaveModel.MIRROR_TURN_CELL, Painter.mirror_texture(host.model.mirror_rot, _struck(CaveModel.MIRROR_TURN_CELL)))
	_place(lotus, CaveModel.MIRROR_LOTUS, Painter.lotus_texture(host.model.lotus_lit()))
	queue_redraw()


func _draw() -> void:
	if host == null or not is_instance_valid(host):
		return
	Painter.draw(self, host)


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
