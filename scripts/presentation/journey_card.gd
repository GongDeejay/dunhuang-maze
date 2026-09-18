class_name JourneyCard
extends CanvasLayer
## Readable, dismissible story beats. Main suspends gameplay while this is open.

signal dismissed
var shade: ColorRect
var panel: PanelContainer
var title_label: Label
var body_label: Label
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
	continue_button = Button.new()
	continue_button.custom_minimum_size.y = 48
	continue_button.add_theme_font_size_override("font_size", 19)
	continue_button.pressed.connect(close)
	box.add_child(continue_button)
	get_viewport().size_changed.connect(_layout)
	visible = false

func open_card(card: Dictionary) -> void:
	if card.is_empty(): return
	title_label.text = card.title
	body_label.text = card.body
	continue_button.text = card.get("button", "继续")
	visible = true
	_layout()
	_layout.call_deferred()
	continue_button.grab_focus()

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	shade.size = vp
	panel.size = Vector2(minf(520, vp.x - 32), 0)
	panel.position = Vector2((vp.x - panel.size.x) * 0.5, maxf(8, (vp.y - panel.size.y) * 0.5))

func close() -> void:
	visible = false
	continue_button.release_focus()
	dismissed.emit()
