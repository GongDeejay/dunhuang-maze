extends RefCounted

static func run(t: Node) -> void:
	print("\n[TEST] Level 2 mirror art and lamp halo")
	_mirrors(t)
	_mirror_back(t)
	_halo(t)
	_planks(t)
	_player_above_tiles(t)


static func _mirrors(t: Node) -> void:
	for facing in ["ne", "se", "sw", "nw"]:
		var plain: Texture2D = load(AssetRegistry.mogao_sprite_path("mirror_" + facing))
		var lit: Texture2D = load(AssetRegistry.mogao_sprite_path("mirror_" + facing + "_lit"))
		t.assert_eq(plain.get_width(), 16, facing + " mirror stays 16 px")
		t.assert_eq(lit.get_height(), 16, facing + " lit mirror stays 16 px")
	var halo: Texture2D = load(AssetRegistry.mogao_sprite_path("lamp_halo"))
	t.assert_eq(Vector2i(halo.get_width(), halo.get_height()), Vector2i(32, 32), "lamp halo is 32 px")


static func _mirror_back(t: Node) -> void:
	t.assert_true(ResourceLoader.exists("res://assets/audio/mirror_back.ogg"), "mirror back sample is delivered")
	t.assert_eq(AudioManager.mirror_back_source(), "res://assets/audio/mirror_back.ogg", "mirror back plays its own sample")
	t.assert_true(AudioManager.mirror_back_source() != AudioManager.wall_hit_source(), "mirror back no longer reuses the wall hit")


static func _halo(t: Node) -> void:
	var chapter := MogaoChapter.new()
	t.add_child(chapter)
	t.assert_eq(chapter.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "chapter root stays linear")
	t.assert_eq(chapter.lamp_halo.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "lamp halo node is nearest")
	t.assert_eq(chapter.lamp_halo.sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "lamp halo sprite is nearest")
	t.assert_true(chapter.lamp_halo.get_index() < chapter.actor_layer.get_index(), "halo is drawn before the player")
	_expect(t, chapter, 2, true, true)
	_expect(t, chapter, 2, false, false)
	_expect(t, chapter, 4, true, true)
	_expect(t, chapter, 4, false, false)
	_expect(t, chapter, 0, true, false)
	_expect(t, chapter, CaveModel.MIRROR_ROOM, true, false)
	chapter.free()


static func _expect(t: Node, chapter: MogaoChapter, room: int, held: bool, visible: bool) -> void:
	chapter.model.load_room(room)
	chapter.model.lamp_held = held
	chapter.lamp_halo.sync()
	var label := "room %d lamp %s" % [room, "held" if held else "down"]
	t.assert_eq(chapter.lamp_halo.sprite.visible, visible, label)
	if not visible:
		return
	var sprite: Sprite2D = chapter.lamp_halo.sprite
	var shown := sprite.scale * Vector2(sprite.texture.get_width(), sprite.texture.get_height())
	t.assert_true(absf(shown.x - chapter.unit * 1.15) < 0.05, label + " halo width")
	t.assert_true(absf(shown.y - shown.x * 0.72) < 0.05, label + " halo height")


static func _planks(t: Node) -> void:
	var flip: Texture2D = load(AssetRegistry.mogao_sprite_path("plank_flip"))
	var tag: Texture2D = load(AssetRegistry.mogao_sprite_path("plank_demo_tag"))
	var gate: Texture2D = load(AssetRegistry.mogao_sprite_path("rope_gate"))
	t.assert_eq(Vector2i(flip.get_width(), flip.get_height()), Vector2i(48, 16), "plank sheet is 48 by 16")
	t.assert_eq(Vector2i(tag.get_width(), tag.get_height()), Vector2i(16, 16), "demo tag is 16 px")
	t.assert_eq(Vector2i(gate.get_width(), gate.get_height()), Vector2i(32, 16), "rope gate sheet is 32 by 16")
	t.assert_eq(FileAccess.get_md5("res://assets/sprites/mogao/plank_flip.png"), "ea6a7fe5309d6f7ce62a6ca199fa234c", "plank sheet matches the delivered art")
	t.assert_eq(FileAccess.get_md5("res://assets/sprites/mogao/plank_demo_tag.png"), "45e1565e2100897c9c96ed86ff4a3aa8", "demo tag matches the delivered art")
	t.assert_eq(FileAccess.get_md5("res://assets/sprites/mogao/rope_gate.png"), "f6c85ecdce04bf74d2fd52a6dd56f333", "rope gate matches the delivered art")
	t.assert_eq(FileAccess.get_md5("res://assets/audio/plank_flip.ogg"), "e3788de0d8c518edd51b90824b525f2c", "plank flip sample matches the delivered audio")
	t.assert_eq(FileAccess.get_md5("res://assets/sprites/mogao/plank_nailed.png"), "fc95320da532a67728183330d5c27648", "nailed plank matches the delivered art")
	t.assert_eq(FileAccess.get_md5("res://assets/sprites/mogao/ledge_stone.png"), "6eb03566a55c0a294badc364db30113b", "ledge stone matches the delivered art")
	t.assert_eq(FileAccess.get_md5("res://assets/audio/rope_gate.ogg"), "4e08937a369828f9d06d450b2b4809e7", "rope gate sample matches the delivered audio")
	t.assert_eq(FileAccess.get_md5("res://assets/sprites/mogao/cliff_void.png"), "e97c3c11a24548ca05e22a98705cbfa3", "cliff void matches the delivered art")
	t.assert_eq(FileAccess.get_md5("res://assets/sprites/mogao/cliff_edge.png"), "ebce1f279282f939b12f59ad85be5665", "cliff edge matches the delivered art")
	t.assert_eq(FileAccess.get_md5("res://assets/sprites/mogao/blue_thread.png"), "5ecf4b60e9f94ff0e5d5eb2e0e8a4d4e", "blue thread matches the delivered art")
	var nailed: Texture2D = load(AssetRegistry.mogao_sprite_path("plank_nailed"))
	var ledge: Texture2D = load(AssetRegistry.mogao_sprite_path("ledge_stone"))
	var cliff: Texture2D = load(AssetRegistry.mogao_sprite_path("cliff_void"))
	var lip: Texture2D = load(AssetRegistry.mogao_sprite_path("cliff_edge"))
	var thread: Texture2D = load(AssetRegistry.mogao_sprite_path("blue_thread"))
	t.assert_eq(Vector2i(nailed.get_width(), nailed.get_height()), Vector2i(16, 16), "nailed plank is 16 px")
	t.assert_eq(Vector2i(ledge.get_width(), ledge.get_height()), Vector2i(32, 16), "ledge stone is two 16 px frames")
	t.assert_eq(Vector2i(cliff.get_width(), cliff.get_height()), Vector2i(16, 16), "cliff void is 16 px")
	t.assert_eq(Vector2i(lip.get_width(), lip.get_height()), Vector2i(16, 16), "cliff edge is 16 px")
	t.assert_eq(Vector2i(thread.get_width(), thread.get_height()), Vector2i(16, 16), "blue thread is 16 px")
	t.assert_true(not _near_white(nailed.get_image().get_pixel(8, 8)), "nailed plank is not a white square")
	t.assert_true(not _near_white(cliff.get_image().get_pixel(8, 8)), "cliff void is not a white square")
	var pngs := 0
	for name in ["plank_flip.png", "plank_demo_tag.png", "rope_gate.png", "plank_nailed.png", "ledge_stone.png", "cliff_void.png", "cliff_edge.png", "blue_thread.png"]:
		pngs += FileAccess.get_file_as_bytes("res://assets/sprites/mogao/" + name).size()
	t.assert_true(pngs < 3072, "new plank images stay under 3 KB")
	var audio := FileAccess.get_file_as_bytes("res://assets/audio/plank_flip.ogg").size() + FileAccess.get_file_as_bytes("res://assets/audio/rope_gate.ogg").size()
	t.assert_true(audio < 11 * 1024, "new plank audio stays under 11 KB")
	var flip_img := flip.get_image()
	var gate_img := gate.get_image()
	var flat := _mean_gray(flip_img, Rect2i(0, 0, 16, 16))
	var raised := _mean_gray(flip_img, Rect2i(32, 0, 16, 16))
	var shut := _mean_gray(gate_img, Rect2i(0, 0, 16, 16))
	var open := _mean_gray(gate_img, Rect2i(16, 0, 16, 16))
	t.assert_true(_gray_gap(flat, raised) >= 0.30, "a raised plank differs from a flat one by at least 30 percent")
	t.assert_true(_gray_gap(shut, open) >= 0.30, "an open rope gate differs from a shut one by at least 30 percent")
	t.assert_true(not _near_white(flip_img.get_pixel(8, 8)) and not _near_white(gate_img.get_pixel(8, 8)), "plank and gate pixels are not blank white")
	var chapter := MogaoChapter.new()
	t.add_child(chapter)
	chapter.model.load_room(3)
	chapter.plank_art._process(0)
	t.assert_eq(chapter.plank_art.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "plank art is nearest filtered")
	var board: Sprite2D = chapter.plank_art.plank_sprites[CaveModel.PLANK_DEMO]
	t.assert_eq(board.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "each plank sprite is nearest filtered")
	t.assert_true(board.visible and board.texture != null and board.texture.get_width() == 16, "the demo plank shows a 16 px frame")
	var shown := board.scale * Vector2(board.texture.get_width(), board.texture.get_height())
	t.assert_true(absf(shown.x - chapter.unit) < 0.05 and absf(shown.y - chapter.unit) < 0.05, "a plank frame is one cell across")
	t.assert_true(chapter.plank_art.tag.visible, "the demo tag sits on the flat sample plank")
	t.assert_true(chapter.plank_art.gate.visible and chapter.plank_art.gate.texture.get_width() == 16, "the rope gate shows its closed frame")
	var hole: Sprite2D = chapter.plank_art.void_sprites[Vector2i(0, 0)]
	t.assert_eq(hole.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "cliff void is nearest filtered")
	t.assert_true(hole.visible and hole.texture.get_width() == 16, "empty cells show the cliff void")
	var edge: Sprite2D = chapter.plank_art.edge_sprites[Vector2i(2, 3)]
	t.assert_true(edge.visible and edge.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "a plank over the void grows a cliff lip")
	t.assert_true(not chapter.plank_art.thread.visible, "the blue thread stays hidden until the rope opens")
	chapter.model.reached = true
	chapter.plank_art._process(0)
	t.assert_true(chapter.plank_art.thread.visible and chapter.plank_art.thread.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "the solved cave shows the blue thread")
	var nailed_board: Sprite2D = chapter.plank_art.plank_sprites[CaveModel.PLANK_CELLS[0]]
	t.assert_eq(nailed_board.texture, nailed, "solved planks use the nailed sheet")
	chapter.free()


static func _effective_z(item: CanvasItem) -> int:
	if not item.z_as_relative:
		return item.z_index
	var parent := item.get_parent()
	var base := _effective_z(parent as CanvasItem) if parent is CanvasItem else 0
	return base + item.z_index


static func _collect_art(node: Node, into: Array) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			into.append(child)
		_collect_art(child, into)


static func _player_above_tiles(t: Node) -> void:
	var chapter := MogaoChapter.new()
	t.add_child(chapter)
	for room_id in [3, CaveModel.MIRROR_ROOM]:
		chapter.model.load_room(room_id)
		chapter.rebuild_cranks()
		var player_z := _effective_z(chapter.actor_layer)
		var art: Array = []
		_collect_art(chapter.plank_art, art)
		_collect_art(chapter.mirror_art, art)
		_collect_art(chapter.lamp_halo, art)
		art.append(chapter.plank_art)
		art.append(chapter.mirror_art)
		art.append(chapter.lamp_halo)
		for node in art:
			var canvas := node as CanvasItem
			t.assert_true(_effective_z(canvas) < player_z, "room %s %s stays under the player" % [room_id, canvas.name])
		t.assert_true(chapter.actor_layer.get_index() > chapter.plank_art.get_index(), "the player is ordered after the plank tiles")
		t.assert_true(chapter.actor_layer.get_index() > chapter.mirror_art.get_index(), "the player is ordered after the mirrors")
	chapter.free()


static func _mean_gray(img: Image, rect: Rect2i) -> float:
	var sum := 0.0
	var n := 0
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var color := img.get_pixel(x, y)
			if color.a < 0.2:
				continue
			sum += color.r * 0.299 + color.g * 0.587 + color.b * 0.114
			n += 1
	return sum / maxf(1.0, float(n))


static func _gray_gap(a: float, b: float) -> float:
	return absf(a - b) / maxf(a, b)


static func _near_white(color: Color) -> bool:
	return color.a > 0.9 and color.r > 0.95 and color.g > 0.95 and color.b > 0.95
