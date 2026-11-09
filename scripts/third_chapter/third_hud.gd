class_name ThirdHUD
extends Control

const MeasureText = preload("res://scripts/presentation/measure_text.gd")
## Full-resolution UI stays separate from the reduced-resolution 3D viewport.
signal action(name: String)
var title: Label
var objective: Label
var status: Label
var hint: Label
var interact_button: Button
var pause_button: Button
var menu_button: Button
var overlay: ColorRect
var heading: Label
var copy: Label
var photo: TextureRect
var primary: Button
var secondary: Button
var sensitivity: HSlider
var sensitivity_label: Label
var quality: Button
var quality_index := 1
var content_margin: MarginContainer
var stick_center := Vector2.ZERO
var stick_radius := 58.0
var stick_vector := Vector2.ZERO
var touch := false
var _card_title_source := ""
var _card_body_source := ""
var danger := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title = _label(23, Color("f8dfa5"))
	objective = _label(18, Color("fff5db"))
	status = _label(16, Color("e7cfaa"))
	hint = _label(18, Color("fff2cf"))
	var hint_style := StyleBoxFlat.new()
	hint_style.bg_color = Color(0.08, 0.06, 0.04, 0.72)
	hint_style.content_margin_left = 10
	hint_style.content_margin_right = 10
	hint_style.content_margin_top = 6
	hint_style.content_margin_bottom = 6
	hint.add_theme_stylebox_override("normal", hint_style)
	interact_button = _button("靠近线索", "interact")
	pause_button = _button("暂停", "pause")
	menu_button = _button("菜单", "menu")
	overlay = ColorRect.new()
	overlay.color = Color(0.065, 0.055, 0.045, 0.96)
	add_child(overlay)
	content_margin = MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		content_margin.add_theme_constant_override("margin_" + edge, 20)
	overlay.add_child(content_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	content_margin.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color("f4d89a"))
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	body.add_child(heading)
	photo = TextureRect.new()
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.custom_minimum_size.y = 160
	photo.texture = load("res://assets/ending/family.webp")
	body.add_child(photo)
	copy = Label.new()
	copy.add_theme_font_size_override("font_size", 19)
	copy.add_theme_color_override("font_color", Color("f4ebd8"))
	copy.autowrap_mode = TextServer.AUTOWRAP_OFF
	body.add_child(copy)
	sensitivity_label = Label.new()
	sensitivity_label.text = "观察灵敏度"
	body.add_child(sensitivity_label)
	sensitivity = HSlider.new()
	sensitivity.min_value = 0.4
	sensitivity.max_value = 1.8
	sensitivity.step = 0.1
	sensitivity.value = 1
	sensitivity.custom_minimum_size.y = 40
	body.add_child(sensitivity)
	quality = _button("3D · 中 · 点击切换", "quality", body)
	primary = _button("出发", "primary", column)
	secondary = _button("返回", "secondary", column)
	overlay.hide()
	get_viewport().size_changed.connect(layout)
	layout()

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _button(text: String, event: String, parent: Node = self) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(func(): action.emit(event))
	parent.add_child(button)
	return button

func layout() -> void:
	size = get_viewport().get_visible_rect().size
	touch = PlatformService.use_mobile_ui or DisplayServer.is_touchscreen_available()
	title.position = Vector2(18, 14)
	title.size = Vector2(size.x - 36, 30)
	objective.position = Vector2(18, 46)
	objective.size = Vector2(size.x - 36, 46)
	status.position = Vector2(18, 94)
	status.size = Vector2(size.x - 36, 30)
	var compact := size.y < 460
	if compact:
		status.position.y = 78
		objective.size.y = 30
	stick_center = Vector2(78, size.y - 143 if not compact else size.y - 113)
	stick_radius = 48.0 if size.x < 340 else 58.0
	if size.x < 340: stick_center.x = 66
	pause_button.position = Vector2(size.x - 180, size.y - 60)
	pause_button.size = Vector2(76, 48)
	menu_button.position = Vector2(size.x - 94, size.y - 60)
	menu_button.size = Vector2(76, 48)
	var action_width := minf(172, size.x - stick_center.x - stick_radius - 30) if touch else 172.0
	interact_button.position = Vector2(size.x - action_width - 18, size.y - 121)
	interact_button.size = Vector2(action_width, 52)
	hint.position = Vector2(18, 136 if touch else size.y - 180)
	hint.size = Vector2(size.x - 36, 0)
	if touch and compact:
		hint.position = Vector2(160, maxf(116, size.y - 170))
		hint.size = Vector2(size.x - 370, 0)
	overlay.size = size
	var width := minf(620, size.x)
	_fit_card_copy(width)
	content_margin.position = Vector2((size.x - width) * 0.5, 0)
	content_margin.size = Vector2(width, size.y)
	photo.custom_minimum_size.y = clampf(size.y * 0.32, 100, 270)
	queue_redraw()

func ui_hit(pos: Vector2) -> bool:
	for button in [interact_button, pause_button, menu_button]:
		if button.get_global_rect().has_point(pos): return true
	return overlay.visible

func card_text_width() -> float:
	return maxf(40.0, minf(620.0, size.x) - 40.0)


func _fit_card_copy(column_width: float = -1.0) -> void:
	if copy == null:
		return
	var font := copy.get_theme_font("font")
	if font == null:
		return
	var width := column_width - 40.0 if column_width > 0.0 else card_text_width()
	heading.text = MeasureText.layout_text(_card_title_source, maxf(40.0, width), font, 26)
	copy.text = MeasureText.layout_text(_card_body_source, maxf(40.0, width), font, 19)


func show_card(card_title: String, text: String, first: String, second: String = "", with_photo: bool = false, settings: bool = false) -> void:
	_card_title_source = card_title
	_card_body_source = text
	_fit_card_copy()
	primary.text = first
	secondary.text = second
	secondary.visible = not second.is_empty()
	photo.visible = with_photo
	sensitivity.visible = settings
	sensitivity_label.visible = settings
	quality.visible = settings
	overlay.show()
	for control in [title, objective, status, hint, interact_button, pause_button, menu_button]: control.hide()
	primary.grab_focus()
	queue_redraw()

func close_card() -> void:
	overlay.hide()
	for control in [title, objective, status, hint, interact_button, pause_button, menu_button]: control.show()
	primary.release_focus()
	secondary.release_focus()
	quality.release_focus()
	queue_redraw()

func set_quality(index: int) -> void:
	quality_index = clampi(index, 0, 2)
	quality.text = "3D · %s · 点击切换" % ["低", "中", "高"][quality_index]

func _draw() -> void:
	if overlay != null and overlay.visible: return
	draw_rect(Rect2(0, 0, size.x, 126 if size.y >= 460 else 108), Color(0.09, 0.07, 0.05, 0.8))
	var center := size * 0.5
	draw_circle(center, 2.5, Color(1, 0.95, 0.8, 0.85))
	if danger > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.2, 0.05, danger * 0.13), false, 10)
	if touch:
		draw_circle(stick_center, stick_radius, Color(0.15, 0.11, 0.07, 0.65))
		draw_arc(stick_center, stick_radius, 0, TAU, 48, Color("e7c28b"), 2, true)
		draw_circle(stick_center + stick_vector * 36, 22, Color(0.9, 0.77, 0.55, 0.8))
		draw_string(ThemeDB.fallback_font, stick_center + Vector2(-18, 82), "移动", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("fff1ce"))
