extends Control
## Nearest-filtered plank, demo tag, and rope gate. The chapter root stays linear.
var host: Control
var plank_sprites: Dictionary = {}
var stone_sprites: Dictionary = {}
var tag: Sprite2D
var gate: Sprite2D
var _frames: Array[Texture2D] = []
var _stones: Array[Texture2D] = []
var _gates: Array[Texture2D] = []
var _nailed: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sheet := _load_tex("plank_flip")
	if sheet != null:
		for i in 3:
			_frames.append(_region(sheet, i * 16))
	var ledge := _load_tex("ledge_stone")
	if ledge != null:
		var count := maxi(1, ledge.get_width() / 16)
		for i in count:
			_stones.append(_region(ledge, i * 16))
	var rope := _load_tex("rope_gate")
	if rope != null:
		var count := maxi(1, rope.get_width() / 16)
		for i in count:
			_gates.append(_region(rope, i * 16))
	_nailed = _load_tex("plank_nailed")
	for cell in CaveModel.PLANK_CELLS:
		plank_sprites[cell] = _make_sprite(1)
	plank_sprites[CaveModel.PLANK_DEMO] = _make_sprite(1)
	for cell in CaveModel.PLANK_STONES:
		stone_sprites[cell] = _make_sprite(0)
	tag = _make_sprite(2)
	var tag_tex := _load_tex("plank_demo_tag")
	if tag_tex != null:
		tag.texture = tag_tex
	gate = _make_sprite(3)


func _make_sprite(z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.z_index = z
	add_child(sprite)
	sprite.visible = false
	return sprite


func _process(_delta: float) -> void:
	if host == null or not is_instance_valid(host):
		return
	var show: bool = host.model.room == 3
	if not show:
		for cell in plank_sprites:
			plank_sprites[cell].visible = false
		for cell in stone_sprites:
			stone_sprites[cell].visible = false
		tag.visible = false
		gate.visible = false
		return
	for cell in stone_sprites:
		var stone: Sprite2D = stone_sprites[cell]
		var variant: int = 0 if _stones.size() < 2 else int((cell.x + cell.y) % _stones.size())
		_place(stone, cell, _stones[variant] if not _stones.is_empty() else null, 0.0)
	for cell in plank_sprites:
		_place(plank_sprites[cell], cell, _plank_texture(cell), 0.0)
	var demo_flat: bool = _frame_index(CaveModel.PLANK_DEMO) == 0 and not host.model.reached
	_place(tag, CaveModel.PLANK_DEMO, tag.texture if demo_flat else null, 0.0)
	var open: bool = host.model.reached or host.model.plank_count() >= CaveModel.PLANK_CELLS.size()
	var gate_tex: Texture2D = null
	if not _gates.is_empty():
		gate_tex = _gates[1] if open and _gates.size() > 1 else _gates[0]
	_place(gate, host.model.goal, gate_tex, -host.unit * 0.12)


func _plank_texture(cell: Vector2i) -> Texture2D:
	if host.model.reached and _nailed != null:
		return _nailed
	if _frames.is_empty():
		return null
	return _frames[_frame_index(cell)]


func _frame_index(cell: Vector2i) -> int:
	var model: CaveModel = host.model
	if model.reached:
		return 0
	if model.busy == "step" and cell == model.player and cell != model.destination and model._plank_like(cell):
		return 1
	if model.planks_up.has(cell):
		return 2
	return 0


func _place(sprite: Sprite2D, cell: Vector2i, texture: Texture2D, lift: float) -> void:
	if texture == null:
		sprite.visible = false
		return
	var u: float = host.unit
	var p: Vector2 = host.point(cell)
	sprite.texture = texture
	sprite.visible = true
	sprite.position = Vector2(p.x, p.y + lift)
	sprite.scale = Vector2(u / 16.0, u / 16.0)


func _load_tex(key: String) -> Texture2D:
	var path := AssetRegistry.mogao_sprite_path(key)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)


func _region(sheet: Texture2D, x: int) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(x, 0, 16, 16)
	return atlas
