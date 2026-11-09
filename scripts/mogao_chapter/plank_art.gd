extends Control
## Nearest-filtered plank, demo tag, and rope gate. The chapter root stays linear.
var host: Control
var plank_sprites: Dictionary = {}
var stone_sprites: Dictionary = {}
var tag: Sprite2D
var gate: Sprite2D
var thread: Sprite2D
var west_door: Node2D
var side_gate: Sprite2D
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
				var hole := _make_sprite()
				hole.texture = _void_tex
				void_sprites[cell] = hole
			if _has_cliff_edge(cell):
				var lip := _make_sprite()
				lip.texture = _edge_tex
				edge_sprites[cell] = lip
	for cell in CaveModel.PLANK_STONES:
		stone_sprites[cell] = _make_sprite()
	for cell in CaveModel.PLANK_CELLS:
		plank_sprites[cell] = _make_sprite()
	plank_sprites[CaveModel.PLANK_DEMO] = _make_sprite()
	tag = _make_sprite()
	var tag_tex := _load_tex("plank_demo_tag")
	if tag_tex != null:
		tag.texture = tag_tex
	gate = _make_sprite()
	thread = _make_sprite()
	thread.texture = _load_tex("blue_thread")
	var doors := Node2D.new()
	doors.name = "WestDoor"
	doors.z_index = 0
	add_child(doors)
	doors.draw.connect(_draw_west_door)
	west_door = doors
	side_gate = _make_sprite()


func _make_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.z_index = 0
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
		if west_door:
			west_door.visible = false
		side_gate.visible = false
		if host.model.room == 5:
			_sync_side_gate()
		for cell in void_sprites:
			void_sprites[cell].visible = false
		for cell in edge_sprites:
			edge_sprites[cell].visible = false
		return
	for cell in void_sprites:
		_place_grid(void_sprites[cell], cell, _void_tex, false)
	for cell in edge_sprites:
		_place_grid(edge_sprites[cell], cell, _edge_tex, true)
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
	if west_door:
		west_door.visible = true
		west_door.queue_redraw()
	_sync_side_gate()


func _side_gate_cell() -> Vector2i:
	if host.model.room == 3:
		return CaveModel.PLANK_WEST
	if host.model.room == 5:
		return Vector2i(3, 0)
	return Vector2i(-99, -99)


func _side_gate_open() -> bool:
	var cell := _side_gate_cell()
	for door in host.model.doors():
		if door.cell == cell:
			return bool(door.open)
	return false


func _sync_side_gate() -> void:
	var cell := _side_gate_cell()
	if cell.x < 0 or not _side_gate_open() or _gates.size() < 2:
		side_gate.visible = false
		return
	_place(side_gate, cell, _gates[1], -host.unit * 0.35)


func _draw_west_door() -> void:
	if host == null or host.model.room != 3 or _side_gate_open():
		return
	host.painter.portal(host, host.point(CaveModel.PLANK_WEST), false, west_door)


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


func _place_grid(sprite: Sprite2D, cell: Vector2i, texture: Texture2D, lip: bool) -> void:
	if texture == null:
		sprite.visible = false
		return
	var u: float = host.unit
	sprite.texture = texture
	sprite.visible = true
	sprite.position = host.point(cell) + Vector2(0, u * 0.16 if lip else 0.0)
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
