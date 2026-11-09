class_name JourneyCard
extends CanvasLayer

const MeasureText = preload("res://scripts/presentation/measure_text.gd")
## Readable, dismissible story beats. Main suspends gameplay while this is open.

signal dismissed
var shade: ColorRect
var panel: PanelContainer
var title_label: Label
var body_label: Label
var fragment_row: HBoxContainer
var fragment_rects: Array[TextureRect] = []
var single_art: TextureRect
var caption: Label
var continue_button: Button

func _ready() -> void:
	layer = 120
	shade = ColorRect.new()
	shade.color = Color(0.04, 0.03, 0.02, 0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("211c16")
	style.border_color = Color("b89d63")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	# Wrapped labels recalculate their height after the container has its width.
	# Refit when that happens, including after a shorter card replaces a long one.
	panel.minimum_size_changed.connect(func(): _layout.call_deferred())
	shade.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	title_label = Label.new()
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color("efd78e"))
	box.add_child(title_label)
	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 18)
	body_label.add_theme_color_override("font_color", Color("efe6d3"))
	box.add_child(body_label)
	fragment_row = HBoxContainer.new()
	fragment_row.add_theme_constant_override("separation", 6)
	fragment_row.visible = false
	box.add_child(fragment_row)
	for _i in 3:
		var rect := TextureRect.new()
		rect.custom_minimum_size = Vector2(64, 128)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fragment_row.add_child(rect)
		fragment_rects.append(rect)
	single_art = TextureRect.new()
	single_art.custom_minimum_size = Vector2(64, 64)
	single_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	single_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	single_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	single_art.visible = false
	single_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(single_art)
	caption = Label.new()
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color("cbb892"))
	caption.visible = false
	box.add_child(caption)
	continue_button = Button.new()
	continue_button.custom_minimum_size.y = 48
	continue_button.add_theme_font_size_override("font_size", 19)
	continue_button.pressed.connect(close)
	box.add_child(continue_button)
	get_viewport().size_changed.connect(_layout)
	visible = false

func open_card(card: Dictionary) -> void:
	if card.is_empty(): return
	title_label.text = MeasureText.bind_units(str(card.title))
	body_label.text = MeasureText.bind_units(str(card.body))
	continue_button.text = card.get("button", "继续")
	_apply_art(card)
	visible = true
	_layout()
	_layout.call_deferred()
	continue_button.grab_focus()

func _apply_art(card: Dictionary) -> void:
	var sheet := str(card.get("sheet", ""))
	var mask: Array = card.get("fragment_mask", [])
	if sheet != "" and mask.size() == 3 and ResourceLoader.exists(sheet):
		var tex: Texture2D = load(sheet)
		fragment_row.visible = true
		for i in 3:
			var found: bool = bool(mask[i])
			fragment_rects[i].visible = found
			if not found:
				continue
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = AssetRegistry.FRAGMENT_SHEET_REGIONS[i]
			fragment_rects[i].texture = atlas
			fragment_rects[i].modulate = Color.WHITE
		single_art.visible = false
		caption.visible = true
		caption.text = str(card.get("image_caption", "非文物原图"))
		return
	fragment_row.visible = false
	var image := str(card.get("image", ""))
	if image != "" and ResourceLoader.exists(image):
		single_art.texture = load(image)
		single_art.visible = true
		caption.visible = str(card.get("image_caption", "")) != ""
		caption.text = str(card.get("image_caption", ""))
	else:
		single_art.visible = false
		caption.visible = false


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	shade.size = vp
	panel.size = Vector2(minf(520, vp.x - 32), 0)
	panel.position = Vector2((vp.x - panel.size.x) * 0.5, maxf(8, (vp.y - panel.size.y) * 0.5))

func close() -> void:
	visible = false
	continue_button.release_focus()
	dismissed.emit()
