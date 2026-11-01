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
var primary: Button
var same: Button
var different: Button
var leave: Button
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
	title = _label("守护纹样", 24, Color("f0d49d"))
	board = PatternBoard.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(board)
	message = _label("", 17, Color("e9dfcd"))
	primary = _button("记好了", func():
		if not _accept_action(): return
		if puzzle.phase == "done": close()
		else: puzzle.advance(); _render())
	var answers := HBoxContainer.new()
	answers.add_theme_constant_override("separation", 8)
	box.add_child(answers)
	same = _button("没变", func(): _answer(false), answers)
	different = _button("变了", func(): _answer(true), answers)
	leave = _button("先离开", func():
		if _accept_action(): close(), outer)
	get_viewport().size_changed.connect(_resized)
	visible = false

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	box.add_child(label)
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
	board.puzzle = puzzle
	visible = true
	consumed_epoch = input_epoch
	scroll.scroll_vertical = 0
	_layout()
	_render()
	primary.grab_focus()

func _answer(value: bool) -> void:
	if not _accept_action() or puzzle.phase != "probe": return
	puzzle.answer(value)
	if puzzle.completed():
		unlocked.emit()
		close() # Reward plays on the map without another confirmation screen.
		return
	_render()

func _process(delta: float) -> void:
	if visible and puzzle and puzzle.tick(delta): _render()

func suspend() -> void:
	if not visible: return
	puzzle.suspend()
	_render()

func _resized() -> void:
	_layout()
	if visible and puzzle.phase in ["observe", "cover", "probe"]:
		puzzle.suspend()
		_render()

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	shade.size = vp
	panel.size = Vector2(minf(480, vp.x - 16), minf(420, vp.y - 16))
	panel.position = (vp - panel.size) / 2
	board.custom_minimum_size = Vector2(0, clampf(vp.y * 0.23, 86, 156))

func _render() -> void:
	message.text = puzzle.message
	if puzzle.phase == "suspended": message.text = "刚才中断了，重新看一眼。"
	primary.visible = puzzle.phase in ["observe", "suspended", "done"]
	primary.text = "重新看" if puzzle.phase == "suspended" else "记好了"
	same.visible = puzzle.phase == "probe"
	different.visible = same.visible
	board.queue_redraw()
	# Focus never auto-answers the new stage; a new physical gesture is required.
	if same.visible: same.grab_focus()
	elif primary.visible: primary.grab_focus()

func close() -> void:
	if not visible: return
	visible = false
	puzzle.remaining = 0.0
	for button in [primary, same, different, leave]: button.release_focus()
	dismissed.emit()
