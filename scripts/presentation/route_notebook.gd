class_name RouteNotebook
extends CanvasLayer

const MeasureText = preload("res://scripts/presentation/measure_text.gd")
signal dismissed
signal traced
var panel: PanelContainer
var shade: ColorRect
var scroll: ScrollContainer
var sketch: RouteSketch
var copy: Label
var leave: Button
var epoch := 0
var consumed := -1

func _ready() -> void:
	layer = 130
	shade = ColorRect.new()
	shade.color = Color(0.035, 0.028, 0.02, 0.94)
	add_child(shade)
	panel = PanelContainer.new()
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("201d18")
	skin.border_color = Color("bd9860")
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(12)
	for edge in ["left", "right", "top", "bottom"]: skin.set("content_margin_" + edge, 12)
	panel.add_theme_stylebox_override("panel", skin)
	shade.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	_label(outer, "妈妈的壁画路书", 22)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	sketch = RouteSketch.new()
	sketch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sketch.custom_minimum_size.y = 230
	body.add_child(sketch)
	sketch.gate_button = _button(sketch, "石门 ◇", _trace)
	sketch.gate_button.size = Vector2(88, 48)
	copy = _label(body, "", 17)
	_label(body, TravelLore.text("roadbook", "fiction"), 13)
	leave = _button(outer, "先收起 · 随时回看", close)
	get_viewport().size_changed.connect(_layout)
	visible = false

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("eddfc4"))
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func open(points: Array[Vector2i], studied: bool) -> void:
	sketch.points = points
	sketch.studied = studied
	sketch.gate_button.text = "石门 ✓" if studied else "石门 ◇"
	visible = true
	consumed = epoch
	scroll.scroll_vertical = 0
	_layout()
	leave.grab_focus()

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	shade.size = vp
	panel.size = Vector2(minf(560, vp.x - 16), minf(600, vp.y - 16))
	panel.position = (vp - panel.size) / 2
	sketch.custom_minimum_size.y = 175 if vp.y < 450 else 230
	sketch.queue_redraw()
	consumed = epoch
	if copy != null and sketch != null:
		var font := copy.get_theme_font("font")
		var width := maxf(40.0, panel.size.x - 28.0)
		copy.autowrap_mode = TextServer.AUTOWRAP_OFF
		var source := TravelLore.text("roadbook", "reveal" if sketch.studied else "prompt")
		copy.text = MeasureText.layout_text(source, width, font, 17) if font != null else source

func _trace() -> void:
	if not visible or consumed == epoch: return
	consumed = epoch
	if not sketch.studied: traced.emit()
	close() # The reward is visible on the actual map, not another confirmation screen.

func close() -> void:
	if not visible: return
	visible = false
	leave.release_focus()
	sketch.gate_button.release_focus()
	dismissed.emit()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event.device != InputEvent.DEVICE_ID_EMULATION:
		if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed: epoch += 1
		elif event is InputEventKey and event.pressed and not event.echo: epoch += 1
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not event.echo: close()
		get_viewport().set_input_as_handled()
