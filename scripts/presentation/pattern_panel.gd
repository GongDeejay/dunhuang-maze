class_name PatternPanel
extends CanvasLayer

signal dismissed
signal unlocked
var puzzle: PatternPuzzle
var shade: ColorRect
var panel: PanelContainer
var scroll: ScrollContainer
var box: VBoxContainer
var board: PatternBoard
var title: Label
var message: Label
var same: Button
var different: Button
var leave: Button
var answers: HBoxContainer
var choice_boards: Array[PatternBoard] = []
var reference_label: Label
var footnote: Label
var comparison: GridContainer
var reference_box: VBoxContainer
var choice_box: VBoxContainer
var input_epoch := 0
var consumed_epoch := -1

func _ready() -> void:
	layer = 130
	shade = ColorRect.new()
	shade.color = Color(0.035, 0.028, 0.02, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("201d18")
	style.border_color = Color("bd9860")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	shade.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	title = _label("三兔共耳 · 旅行手记", 24, Color("f0d49d"))
	comparison = GridContainer.new()
	comparison.add_theme_constant_override("h_separation", 12)
	comparison.add_theme_constant_override("v_separation", 6)
	box.add_child(comparison)
	reference_box = VBoxContainer.new()
	reference_box.size_flags_horizontal = Control.SIZE_FILL
	comparison.add_child(reference_box)
	choice_box = VBoxContainer.new()
	choice_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_box.add_theme_constant_override("separation", 8)
	comparison.add_child(choice_box)
	reference_label = _label(RabbitLore.text("reference_label"), 15, Color("c8ba9d"), reference_box)
	board = PatternBoard.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reference_box.add_child(board)
	message = _label("", 17, Color("e9dfcd"), choice_box)
	answers = HBoxContainer.new()
	answers.add_theme_constant_override("separation", 8)
	choice_box.add_child(answers)
	same = _choice("左边门牌", 0)
	different = _choice("右边门牌", 1)
	footnote = _label(RabbitLore.text("fiction") + "\n参考：" + RabbitLore.text("source_title"), 13, Color("b5aa94"))
	leave = _button("先离开", func():
		if _accept_action(): close(), outer)
	get_viewport().size_changed.connect(_resized)
	visible = false

func _choice(caption: String, index: int) -> Button:
	var button := _button("", func(): _answer(index), answers)
	button.tooltip_text = caption
	var picture := PatternBoard.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.offset_left = 6
	picture.offset_right = -6
	picture.offset_top = 6
	picture.offset_bottom = -34
	button.add_child(picture)
	choice_boards.append(picture)
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -32
	label.offset_bottom = -4
	label.add_theme_font_size_override("font_size", 17)
	button.add_child(label)
	return button

func _label(text: String, font_size: int, color: Color, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	(parent if parent != null else box).add_child(label)
	return label

func _button(text: String, callback: Callable, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	for state in ["normal", "hover", "pressed", "focus"]:
		var skin := StyleBoxFlat.new()
		skin.bg_color = Color("393025") if state == "normal" else Color("55412c")
		skin.border_color = Color("e8c889") if state == "focus" else Color("957345")
		skin.set_border_width_all(2 if state == "focus" else 1)
		skin.set_corner_radius_all(7)
		button.add_theme_stylebox_override(state, skin)
	button.add_theme_color_override("font_color", Color("f2e5cb"))
	button.pressed.connect(callback)
	(parent if parent != null else box).add_child(button)
	return button

func _accept_action() -> bool:
	# One physical gesture owns one action, even if Godot emits a synthetic mouse event.
	if not visible or consumed_epoch == input_epoch: return false
	consumed_epoch = input_epoch
	return true

func _input(event: InputEvent) -> void:
	if not visible: return
	if event.device != InputEvent.DEVICE_ID_EMULATION:
		if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
			input_epoch += 1
		elif event is InputEventKey and event.pressed and not event.echo:
			input_epoch += 1
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not event.echo: close()
		get_viewport().set_input_as_handled()

func open(value: PatternPuzzle) -> void:
	puzzle = value
	puzzle.open()
	visible = true
	consumed_epoch = input_epoch
	scroll.scroll_vertical = 0
	_layout()
	_render()
	leave.grab_focus() # Enter cannot accidentally select a plate as the panel opens.

func _answer(value: int) -> void:
	if not _accept_action() or puzzle.phase != "inspect": return
	puzzle.answer(value)
	if puzzle.completed():
		unlocked.emit()
		close() # Reward plays on the map without another confirmation screen.
		return
	_render()

func suspend() -> void:
	if not visible: return
	puzzle.suspend()
	consumed_epoch = input_epoch

func _resized() -> void:
	_layout()
	if visible: suspend()

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var landscape := vp.y < 500 and vp.x > vp.y * 1.45
	shade.size = vp
	panel.size = Vector2(minf(720 if landscape else 520, vp.x - 16), minf(620, vp.y - 16))
	panel.position = (vp - panel.size) / 2
	comparison.columns = 2 if landscape else 1
	reference_box.custom_minimum_size.x = 160 if landscape else 0
	board.custom_minimum_size = Vector2(0, 128 if vp.y < 560 else 148)
	title.add_theme_font_size_override("font_size", 20 if landscape else 24)
	footnote.visible = not landscape or (puzzle != null and puzzle.completed())
	for button in [same, different]: button.custom_minimum_size.y = 164

func _render() -> void:
	message.text = puzzle.message
	answers.visible = puzzle.phase == "inspect"
	leave.text = "返回栈道" if puzzle.completed() else "先离开 · 也能绕路"
	reference_label.text = "已揭秘 · 近路已经打开" if puzzle.completed() else RabbitLore.text("reference_label")
	for i in choice_boards.size():
		choice_boards[i].shared = puzzle.board[i] == 0 if puzzle.board.size() == 2 else true
		choice_boards[i].queue_redraw()
	board.queue_redraw()

func close() -> void:
	if not visible: return
	visible = false
	for button in [same, different, leave]: button.release_focus()
	dismissed.emit()
