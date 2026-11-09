extends Control
## Foot halo for a carried lamp. Nearest because the chapter root filters linearly.
var host: Control
var sprite: Sprite2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite = Sprite2D.new()
	sprite.name = "Halo"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	var path := AssetRegistry.mogao_sprite_path("lamp_halo")
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	add_child(sprite)
	sprite.visible = false


func _process(_delta: float) -> void:
	sync()


func shows_halo() -> bool:
	return host != null and host.model.lamp_held and host.model.room in [2, 4] and sprite.texture != null


func sync() -> void:
	if sprite == null:
		return
	var show := shows_halo()
	sprite.visible = show
	if not show:
		return
	var width: float = host.unit * 1.15
	var size := Vector2(width, width * 0.72)
	var player: Vector2 = host.point(host.model.visual_player())
	var top_left := player - Vector2(width * 0.5, width * 0.35)
	sprite.position = top_left + size * 0.5
	var tex_size := Vector2(sprite.texture.get_width(), sprite.texture.get_height())
	sprite.scale = Vector2(size.x / tex_size.x, size.y / tex_size.y)
