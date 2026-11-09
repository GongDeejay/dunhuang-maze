extends Control
## Nearest-filtered plank, demo tag, and rope gate. The chapter root stays linear.
var host: Control
var plank_sprites: Dictionary = {}
var stone_sprites: Dictionary = {}
var tag: Sprite2D
var gate: Sprite2D
var thread: Sprite2D
var void_sprites: Dictionary = {}
var edge_sprites: Dictionary = {}
var _frames: Array[Texture2D] = []
var _stones: Array[Texture2D] = []
var _gates: Array[Texture2D] = []
var _nailed: Texture2D
var _void_tex: Texture2D
var _edge_tex: Texture2D


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
	_void_tex = _load_tex("cliff_void")
	_edge_tex = _load_tex("cliff_edge")
	for y in 9:
		for x in 7:
			var cell := Vector2i(x, y)
			if _is_void(cell):
				var hole := _make_sprite(0)
				hole.texture = _void_tex
				void_sprites[cell] = hole
			if _has_cliff_edge(cell):
				var lip := _make_sprite(1)
				lip.texture = _edge_tex
				edge_sprites[cell] = lip
	for cell in CaveModel.PLANK_CELLS:
		plank_sprites[cell] = _make_sprite(3)
	plank_sprites[CaveModel.PLANK_DEMO] = _make_sprite(3)
	for cell in CaveModel.PLANK_STONES:
		stone_sprites[cell] = _make_sprite(2)
	tag = _make_sprite(4)
	var tag_tex := _load_tex("plank_demo_tag")
	if tag_tex != null:
		tag.texture = tag_tex
	gate = _make_sprite(5)
	thread = _make_sprite(6)
	thread.texture = _load_tex("blue_thread")


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
		thread.visible = false
		for cell in void_sprites:
			void_sprites[cell].visible = false
		for cell in edge_sprites:
			edge_sprites[cell].visible = false
		return
	for cell in void_sprites:
		_place_grid(void_sprites[cell], cell, _void_tex)
	for cell in edge_sprites:
		_place_grid(edge_sprites[cell], cell, _edge_tex)
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
	var thread_tex: Texture2D = thread.texture if host.model.reached else null
	_place(thread, CaveModel.PLANK_LANDING, thread_tex, -host.unit * 0.08)


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


func _is_void(cell: Vector2i) -> bool:
	if cell == CaveModel.PLANK_GOAL or cell == CaveModel.PLANK_DEMO:
		return false
	if cell in CaveModel.PLANK_STONES or cell in CaveModel.PLANK_CELLS:
		return false
	return cell.x >= 0 and cell.x < 7 and cell.y >= 0 and cell.y < 9


func _has_cliff_edge(cell: Vector2i) -> bool:
	if not _is_void(cell):
		return false
	var above := Vector2i(cell.x, cell.y - 1)
	if above.y < 0:
		return false
	return above in CaveModel.PLANK_STONES or above in CaveModel.PLANK_CELLS or above == CaveModel.PLANK_DEMO


func _place_grid(sprite: Sprite2D, cell: Vector2i, texture: Texture2D) -> void:
	if texture == null:
		sprite.visible = false
		return
	var u: float = host.unit
	sprite.texture = texture
	sprite.visible = true
	var drop := u * 0.16 if sprite.z_index == 1 else 0.0
	sprite.position = host.point(cell) + Vector2(0, drop)
	sprite.scale = Vector2(u / 16.0, u * 0.72 / 16.0)


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
