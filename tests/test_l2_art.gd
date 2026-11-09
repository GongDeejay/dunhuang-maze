extends RefCounted

static func run(t: Node) -> void:
	print("\n[TEST] Level 2 mirror art and lamp halo")
	_mirrors(t)
	_mirror_back(t)
	_halo(t)


static func _mirrors(t: Node) -> void:
	for facing in ["ne", "se", "sw", "nw"]:
		var plain: Texture2D = load(AssetRegistry.mogao_sprite_path("mirror_" + facing))
		var lit: Texture2D = load(AssetRegistry.mogao_sprite_path("mirror_" + facing + "_lit"))
		t.assert_eq(plain.get_width(), 16, facing + " mirror stays 16 px")
		t.assert_eq(lit.get_height(), 16, facing + " lit mirror stays 16 px")
	var halo: Texture2D = load(AssetRegistry.mogao_sprite_path("lamp_halo"))
	t.assert_eq(Vector2i(halo.get_width(), halo.get_height()), Vector2i(32, 32), "lamp halo is 32 px")


static func _mirror_back(t: Node) -> void:
	var dedicated := false
	for ext in [".wav", ".ogg", ".mp3"]:
		if ResourceLoader.exists("res://assets/audio/mirror_back" + ext):
			dedicated = true
	if dedicated:
		t.assert_true(AudioManager.mirror_back_source().contains("mirror_back"), "a dedicated mirror-back sample wins")
	else:
		t.assert_eq(AudioManager.mirror_back_source(), AudioManager.wall_hit_source(), "mirror back reuses the wall-hit sample")


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
