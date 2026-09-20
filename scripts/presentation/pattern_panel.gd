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
var subtitle: Label
var status: Label
var message: Label
var primary: Button
var same: Button
var different: Button
var slow_button: Button
var simple_button: Button
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
	subtitle = _label("窟前护纹木匣 · 这里可以安心查看", 15, Color("9dc1bd"))
	board = PatternBoard.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(board)
	status = _label("", 18, Color("dfbb78"))
	message = _label("", 17, Color("e9dfcd"))
	primary = _button("揭帘看看", func():
		if not _accept_action(): return
		if puzzle.phase == "done": close()
		elif puzzle.phase == "suspended": puzzle.open(); _render()
		else: puzzle.advance(); _render())
	var answers := HBoxContainer.new()
	answers.add_theme_constant_override("separation", 8)
	box.add_child(answers)
	same = _button("没变 · 保留", func(): _answer(false), answers)
	different = _button("变了 · 复原", func(): _answer(true), answers)
	slow_button = _button("慢慢看", func():
		if not _accept_action(): return
		puzzle.slow = not puzzle.slow
		if puzzle.phase in ["cover", "probe"]: puzzle.phase = "ready"
		_render())
	simple_button = _button("先看两枚纹样", func():
		if not _accept_action(): return
		puzzle.simple = true
		puzzle.slow = true
		puzzle.phase = "ready"
		_render())
	leave = _button("先沿栈道走", func():
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
	if puzzle.completed(): unlocked.emit()
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
	panel.size = Vector2(minf(520, vp.x - 16), minf(680, vp.y - 16))
	panel.position = (vp - panel.size) / 2
	subtitle.visible = vp.y >= 700
	board.custom_minimum_size = Vector2(0, clampf(vp.y * 0.25, 112, 220))

func _render() -> void:
	status.text = "纹扣  %s  %s" % ["◆" if puzzle.latches >= 1 else "◇", "◆" if puzzle.latches >= 2 else "◇"]
	message.text = puzzle.message
	if puzzle.phase == "intro": message.text = "先看清纹样，护帘落下后，看看露出的这一格变没变。先试一下，不会扣血。"
	elif puzzle.phase == "ready": message.text = "拨正两处纹扣，就能打开旁边的栈道门。"
	elif puzzle.phase == "suspended": message.text = "旅途已暂停。准备好了，再从观察开始。"
	primary.visible = puzzle.phase in ["intro", "ready", "feedback", "done", "suspended"] or (puzzle.phase == "observe" and (puzzle.slow or puzzle.demo))
	primary.text = {"intro": "看一次演示（不解锁）", "ready": "揭帘 · 查看纹样", "observe": "看好了 · 落下护帘", "feedback": "演示结束 · 开始拨纹扣" if puzzle.demo else "继续拨动纹扣", "done": "看看打开的通道", "suspended": "继续查看"}.get(puzzle.phase, "继续")
	same.visible = puzzle.phase == "probe"
	different.visible = same.visible
	slow_button.visible = puzzle.phase in ["intro", "ready", "feedback"]
	slow_button.text = "慢看已开启 · 恢复自动" if puzzle.slow else "慢慢看（手动落帘）"
	simple_button.visible = puzzle.failures >= 2 and not puzzle.simple and puzzle.phase != "suspended"
	leave.text = "返回栈道" if puzzle.completed() else "先沿栈道走"
	board.queue_redraw()
	# Focus never auto-answers the new stage; a new physical gesture is required.
	if same.visible: same.grab_focus()
	elif primary.visible: primary.grab_focus()

func close() -> void:
	if not visible: return
	visible = false
	puzzle.remaining = 0.0
	for button in [primary, same, different, slow_button, simple_button, leave]: button.release_focus()
	dismissed.emit()
