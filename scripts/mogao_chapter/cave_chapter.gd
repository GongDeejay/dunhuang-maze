class_name MogaoChapter
extends Control
## Self-contained second chapter: route-making, pressure, then light and observation.
signal menu_requested
signal completed
signal checkpoint_changed(room_id: int)
const FONT = preload("res://assets/fonts/MogaoSubset.ttf")
const DAD = preload("res://assets/high_quality/player/dj.svg")
const BROTHER = preload("res://assets/high_quality/player/mac.svg")
const RABBITS = preload("res://assets/lore/three_hares.svg")
const DEER = preload("res://assets/lore/nine_deer.svg")
const Painter = preload("res://scripts/mogao_chapter/cave_painter.gd")
const ROOM_NAMES := {
	0: "入窟 · 转桥",
	1: "侧窟 · 共耳",
	2: "深窟 · 鹿影",
	3: "回廊 · 借路",
	4: "灯窟 · 接桥",
	5: "中央窟",
	7: "镜窟 · 折光",
}
const MoveBufferScript = preload("res://scripts/handlers/move_buffer.gd")
var model := CaveNetwork.new()
var input_handler := InputHandler.new()
var move_buffer = MoveBufferScript.new()
var heading: Label
var objective: Label
var hint: Label
var action_button: Button
var undo_button: Button
var note_button: Button
var pause_button: Button
var arrows: Array[Button] = []
var cranks: Array[Button] = []
var overlay: ColorRect
var panel: PanelContainer
var card_title: Label
var card_body: Label
var card_scroll: ScrollContainer
var primary: Button
var secondary: Button
var tertiary: Button
var mode := "playing"
var origin := Vector2.ZERO
var unit := 60.0
var area := Rect2()
var touch := false
var rescued_presented := false
var stopped := false
var frame := 0
var gate_visual := [0.0, 0.0]
var light_visual := 0.0
var painter := Painter.new()
var mirror_art: Control

func _ready() -> void:
	rescued_presented = model.rescued
	if OS.has_feature("web"):
		JavaScriptBridge.eval("var s=document.createElement('style');s.id='mogao-cave-viewport';s.textContent='#canvas{position:fixed;inset:0;width:100%!important;height:100%!important}';document.head.appendChild(s);")
	theme = Theme.new(); theme.default_font = FONT; theme.default_font_size = 18
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	heading = make_label("莫高窟", 25, Color("f5dba8"))
	objective = make_label("", 18, Color("eee1c8"))
	hint = make_label("", 16, Color("e1c49a"))
	action_button = make_button("转动栈桥", interact)
	undo_button = make_button("撤销", undo)
	note_button = make_button("窟图", show_note)
	pause_button = make_button("暂停", pause_game)
	for spec in [["↑", Vector2i.UP], ["←", Vector2i.LEFT], ["↓", Vector2i.DOWN], ["→", Vector2i.RIGHT]]:
		var d: Vector2i = spec[1]
		arrows.append(make_button(spec[0], func(): move(d)))
	make_modal()
	_add_mirror_art()
	rebuild_cranks()
	get_viewport().size_changed.connect(layout)
	layout(); refresh()

func make_label(text: String, font_size: int, color: Color, parent: Node = self) -> Label:
	var node := Label.new(); node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func make_button(text: String, callback: Callable, parent: Node = self, crank: bool = false) -> Button:
	var node: Button = preload("res://scripts/mogao_chapter/cave_crank.gd").new() if crank else Button.new()
	node.text = text; node.focus_mode = Control.FOCUS_NONE
	node.custom_minimum_size = Vector2(48, 48)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("3f514c") if state == "normal" else Color("607264")
		if state == "disabled": style.bg_color = Color("34372f")
		style.border_color = Color("a28a60"); style.set_border_width_all(1); style.set_corner_radius_all(9)
		if crank: style.bg_color = Color.TRANSPARENT; style.set_border_width_all(0)
		node.add_theme_stylebox_override(state, style)
	node.add_theme_color_override("font_color", Color("fff0d1"))
	node.add_theme_color_override("font_disabled_color", Color("a69a81"))
	node.pressed.connect(callback); parent.add_child(node)
	return node

func make_modal() -> void:
	overlay = ColorRect.new(); overlay.color = Color(0.04, .04, .035, .86)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	panel = PanelContainer.new(); overlay.add_child(panel)
	var style := StyleBoxFlat.new(); style.bg_color = Color("303d39")
	style.border_color = Color("bea471"); style.set_border_width_all(2); style.set_corner_radius_all(14)
	style.content_margin_left = 18; style.content_margin_right = 18; style.content_margin_top = 14; style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 10); panel.add_child(column)
	card_title = make_label("", 23, Color("f5dba8"), column)
	card_scroll = ScrollContainer.new(); card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(card_scroll)
	card_body = make_label("", 18, Color("eee1c8"), card_scroll); card_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary = make_button("继续", modal_primary, column)
	secondary = make_button("", modal_secondary, column)
	tertiary = make_button("", modal_tertiary, column)
	overlay.hide()

func rebuild_cranks() -> void:
	for node in cranks: node.free()
	cranks.clear()
	for i in model.cranks.size():
		var index := i
		cranks.append(make_button("", func(): turn(index), self, true))
	# Modal must always intercept input above scenery and newly created cranks.
	if mirror_art:
		move_child(mirror_art, 0)
	move_child(overlay, -1)

func layout() -> void:
	size = get_viewport_rect().size
	touch = DisplayServer.is_touchscreen_available() or size.x < 900
	var short := size.y < 500
	heading.text = "莫高窟 · " + CaveNetwork.NAMES[model.room] if size.x < 400 else "莫高窟 · " + ROOM_NAMES[model.room]
	heading.position = Vector2(16, 12); heading.size = Vector2(size.x - 114, 35)
	heading.add_theme_font_size_override("font_size", 22 if size.x < 400 else 25)
	objective.position = Vector2(16, 66); objective.size = Vector2(size.x - 32, 44)
	pause_button.position = Vector2(size.x - 90, 12); pause_button.size = Vector2(74, 48)
	var top := 116.0 if not short else 100.0
	area = Rect2(10, top, size.x - 20 - (214 if short else 0), size.y - top - (176 if not short else 50))
	unit = maxf(12, minf(106, minf(area.size.x / (model.extent.x + .5), (area.size.y - 16) / (model.extent.y * .72 + .9))))
	origin = area.get_center() - Vector2((model.extent.x - 1) * unit / 2, (model.extent.y - 1) * unit * .36)
	var base := Vector2(maxf(8, size.x / 2 - 158), size.y - 112) if not short else Vector2(size.x - 206, size.y - 64)
	var offsets := [Vector2(54, -54), Vector2.ZERO, Vector2(54, 0), Vector2(108, 0)]
	for i in 4: arrows[i].position = base + offsets[i]; arrows[i].size = Vector2(50, 50)
	var right_width := minf(144, size.x - base.x - 180)
	action_button.position = base + Vector2(170, -54); action_button.size = Vector2(right_width, 50)
	undo_button.position = base + Vector2(170, 0); undo_button.size = Vector2(right_width / 2 - 2, 50)
	note_button.position = undo_button.position + Vector2(right_width / 2 + 2, 0); note_button.size = undo_button.size
	if short:
		action_button.position = Vector2(size.x - 206, 108); action_button.size = Vector2(190, 50)
		undo_button.position = Vector2(size.x - 206, 170); undo_button.size = Vector2(92, 48)
		note_button.position = Vector2(size.x - 108, 170); note_button.size = Vector2(92, 48)
	# Two lines at the enlarged system text scale still leave a bottom margin.
	hint.position = Vector2(16, size.y - 56); hint.size = Vector2(area.size.x if short else size.x - 32, 52)
	for i in cranks.size():
		cranks[i].position = point(model.cranks[i].cell) - Vector2(24, 28)
		cranks[i].size = Vector2(48, 48); cranks[i].visual_scale = clampf(unit / 70, .6, 1)
	if mirror_art:
		mirror_art.position = Vector2.ZERO
		mirror_art.size = size
	overlay.size = size
	panel.position = Vector2(maxf(8, (size.x - 530) / 2), maxf(8, (size.y - 500) / 2))
	panel.size = Vector2(minf(530, size.x - 16), minf(500, size.y - 16))
	settle_text.call_deferred(); queue_redraw()

func settle_text() -> void:
	for node in [heading, objective, hint]: node.size.y = 0
	# Container visibility/text updates can queue a sort using the old card size.
	# Refit after that sort so short landscape screens keep the action reachable.
	if overlay.visible:
		panel.size = Vector2(minf(530, size.x - 16), minf(500, size.y - 16))

func point(cell: Vector2) -> Vector2:
	return origin + Vector2(cell.x * unit, cell.y * unit * .72)

func refresh() -> void:
	var locked := stopped or mode != "playing" or not model.busy.is_empty()
	for arrow in arrows: arrow.disabled = locked
	for i in cranks.size():
		cranks[i].disabled = locked or not model.can_turn(i)
		cranks[i].angle = model.angle(model.cranks[i].bridge); cranks[i].queue_redraw()
	undo_button.disabled = locked or model.history.is_empty() or model.reached or model.rescued
	note_button.disabled = locked
	action_button.text = "转动栈桥" if model.room == 0 else ("观察压盘" if model.room == 1 else ("放上灯座" if model.lamp_held else "提起灯笼"))
	action_button.disabled = locked or (not model.can_turn() if model.room == 0 else (model.lamp_action().is_empty() if model.room == 2 else false))
	if model.room == 3: action_button.text = "观察门闩"
	if model.room == 4:
		action_button.text = ("放上灯座" if model.lamp_held else "提起灯笼") if not model.lamp_action().is_empty() else "转动栈桥"
		action_button.disabled = locked or (model.lamp_action().is_empty() and not model.can_turn())
	if model.room == CaveModel.MIRROR_ROOM:
		action_button.text = "转动铜镜"
		action_button.disabled = locked or not model.can_turn_mirror()
	if model.reached:
		action_button.text = "机关已解"
		action_button.disabled = true
	if model.room == CaveModel.MIRROR_ROOM:
		objective.text = "把光从镜子正面折到莲花灯座"
	else:
		objective.text = ["蓝围巾在对岸 · 转桥接近它", "三兔共耳 · 找到两扇门共用的机关", "九色鹿回望河面 · 对岸还没有光", "一个木箱 · 先借路，再送到对岸", "先留下光 · 再把桥接向对岸", "左边推箱借路 · 右边提灯接桥"][model.room]
	hint.text = "点方向键走到岸边，再转动栈桥" if touch else "方向键 / WASD 移动 · 空格互动 · Z 撤销"
	if model.room == 0 and model.can_turn(): hint.text = "点转柄，看看桥会通向哪里"
	if model.room == 0 and model.bridges[0].pose == 1: hint.text = "桥接通了，亲自走过去"
	if model.room == 1:
		hint.text = "踩踩压盘，看看铜线通向哪扇门"
		if model.gate_open(0) != model.gate_open(1): hint.text = "亮起一条铜线 · 另一扇门还关着"
		if model.plate_active(1): hint.text = "原来，两边用的是同一处！"
		if model.box == CaveModel.PLATE: hint.text = "木箱留住共用压盘 · 两扇门都开了"
	if model.room == 2:
		hint.text = "河里有人挥手 · 提灯照照壁画"
		if model.lamp_held: hint.text = "鹿朝着对岸望去 · 把光带到那里"
		elif model.deer_seen and not model.bank_lit(): hint.text = "看清了河中的人 · 对岸仍暗着"
		if model.bank_lit() and not model.lit():
			objective.text = "对岸亮了 · 九色鹿正在渡河救人"
			hint.text = "你照亮了对岸 · 鹿正去帮助落水的人"
		if model.lit():
			objective.text = "鹿把人送到了岸边 · 沿足迹寻找哥哥"
			hint.text = "壁画里的光点，接上了脚下的路"
		if model.rescued: objective.text = "找到哥哥了 · 一起走向右侧亮着的窟口"
	if model.room == 3:
		hint.text = "先压住近处的盘，穿过右侧的门"
		if model.latch: hint.text = "门闩扣住了！把木箱运过这扇门"
		if model.gate_open(1): hint.text = "箱子到了远处压盘 · 窟口也打开了"
	if model.room == 4:
		hint.text = "把灯留在左岸灯座，看看桥下的石刻"
		if model.lit(): hint.text = "光照出了南北路标 · 去右岸转柄接桥"
		if model.lit() and model.bridges[0].pose == 1: hint.text = "灯留在岸边，沿亮起的桥走过去"
	if model.room == CaveModel.MIRROR_ROOM:
		hint.text = "右边的铜镜可以转。虚线只预告再转一下后的下一段，不是整条路。"
		if model.can_turn_mirror():
			hint.text = "站在教学镜旁边。虚线变成实线，就是这一转把光送出去的方向。"
		if model.lotus_lit():
			objective.text = "莲花亮了 · 沿光桥走向哥哥"
			hint.text = "光从镜子正面折了过去，北面的路亮了"
	if model.reached:
		hint.text = "机关保持开启，可自由折返"
	if model.room == 5:
		action_button.text = "查看窟图"; action_button.disabled = locked
		hint.text = "左右都可走，洞口按互动"
		if not model.arrival.is_empty(): hint.text = model.arrival
		if model.at_secret():
			action_button.text = "查看小画" if model.secret else "触碰节点"
			hint.text = "三条铜线，共用一个节点……"
	var door := model.current_door()
	if not door.is_empty():
		action_button.text = ("进入" if door.open else "未通") + door.label
		action_button.disabled = locked or not door.open
		if not door.open: hint.text = "门闩在回廊另一侧" if model.room == 5 else "此路未通，先走另一边"
	if model.room == 2 and model.rescued and model.player == model.exit_cell:
		action_button.text = "前往三危山"; action_button.disabled = locked
	if not model.busy.is_empty():
		if model.busy == "turn": hint.text = "栈桥正在转动……"
		elif model.busy == "lamp": hint.text = "灯光正在安定下来……"
		elif model.busy == "mirror": hint.text = "铜镜正在转动……"
	settle_text.call_deferred(); queue_redraw()

func move(direction: Vector2i) -> void:
	if mode == "playing" and not stopped and model.step(direction):
		AudioManager.play_step(); refresh()

func turn(index: int = -1) -> void:
	if mode == "playing" and not stopped and model.turn(index): refresh()

func interact() -> void:
	if stopped or mode != "playing" or not model.busy.is_empty(): return
	if model.room == 2 and model.rescued and model.player == model.exit_cell:
		show_card("finish", "走出莫高窟", "哥哥：“弟弟往三危山去了。”\n\n你把围巾交还给哥哥，让他沿安全路线去与妈妈会合。窟口的光里，是下一段寻找。", "前往三危山", "再看看洞窟")
	elif model.travel():
		rescued_presented = model.rescued; gate_visual = [0.0, 0.0]; light_visual = 0
		rebuild_cranks(); layout(); refresh(); AudioManager.play_level_start()
		checkpoint_changed.emit(model.room)
	elif model.at_secret() and model.reveal_secret():
		checkpoint_changed.emit(model.room)
		show_card("note", "藏在共用节点后的小画", "石龛轻轻打开，里面夹着一张哥哥的小画：三只兔子围成圈，旁边却画着四个牵手的小人。\n\n“少一个都不算合影。爸爸，等我们找齐，再拍一张。”\n\n你把小画夹进旅行手记。这里没有钥匙，也不影响前进。\n\n机关与小画均为游戏虚构。", "收好小画")
	elif model.room == 5: show_note()
	elif model.room == 0: turn()
	elif model.room in [1, 3]: show_note()
	elif model.room == 4 and model.lamp_action().is_empty(): turn()
	elif model.room == CaveModel.MIRROR_ROOM:
		if model.turn_mirror():
			refresh()
	elif model.use_lamp(): refresh()

func undo() -> void:
	if mode != "playing" or stopped: return
	if model.undo():
		rescued_presented = model.rescued; refresh(); checkpoint_changed.emit(model.room)

func show_note() -> void:
	if mode != "playing" or stopped: return
	if model.room == CaveModel.MIRROR_ROOM:
		show_card("note", "镜窟 · 铜镜折光", model.map_note() + "\n\n本窟线索\n灯固定在北面，光沿直线走。铜镜只有正面反光：和箭头一致的方向才能折过去，打到镜背就停住。\n左边那面是固定的，右边这面可以转。站在教学镜旁边时，淡色虚线只画出再转一下之后的下一段。\n把光引到莲花灯座上，北面的路才会亮，通向哥哥所在的鹿影窟。\n转错可以撤销。\n\n本关为壁画幻境；机关为游戏虚构。", "回到洞窟")
		return
	if model.room == 5:
		show_card("note", "六窟相连 · 旅行窟图", model.map_note(), "回到洞窟")
		return
	var titles := ["哥哥的蓝围巾", "三兔共耳 · 共用的机关", "九色鹿 · 为渡河照亮对岸"]
	var bodies := ["围巾留在对岸，哥哥应该刚刚走过这里。\n\n靠近转柄，把栈桥接起来，再亲自走过去。", "三只兔子只有三只耳朵，相邻的兔子共用一耳。\n\n看看地上的铜线：两侧压盘各管一扇门，中间压盘被两扇门共用。让木箱代替你压住它，就能腾出身来过门。\n\n朝箱子走即可推动；推错可撤销。纹样取意于莫高窟第407窟。", "九色鹿救起了河中的落水者。后来，这个人却为赏赐背弃承诺，鹿最终向国王讲明真相。\n\n这一次，你可以给它照亮对岸：提起灯，走到右侧河岸灯座旁放下。鹿会把人送到安全的地方，足迹也会从壁画延伸到路上。\n\n左侧山林灯座能照清故事，不是陷阱。灯不会熄灭。壁画取意于第257窟。"]
	titles.append_array(["回廊 · 借来的路", "灯窟 · 灯与桥"])
	bodies.append_array(["一个木箱，可以帮你两次。\n\n先把它推到近处压盘，从右侧门穿过去。门闩会自动扣住，门不再落下。\n\n回头把箱子经右门运到上方压盘，打开窟口。推错可以撤销，不必重新走前面的洞窟。", "桥下的石刻藏在暗处。\n\n先提灯，放到左侧唯一的灯座上，让南北路标显现。再到右侧转柄，把桥转向对岸。\n\n灯必须留在岸边照路；桥上不能提灯或转桥。"])
	show_card("note", titles[model.room], model.map_note() + "\n\n本窟线索\n" + bodies[model.room] + "\n\n本关为壁画幻境；机关与引路情节为游戏虚构。", "回到洞窟")

func pause_game() -> void:
	if mode != "playing" or stopped: return
	show_card("pause", "在洞窟歇一会儿", "动作已暂停。\n位置与机关会在动作结束后保存；已解机关和捷径不会重置。", "继续", "重置这一窟" if not model.reached and not model.rescued and model.room != 5 else "", "返回首页")

func show_card(next_mode: String, title: String, body: String, first: String, second: String = "", third: String = "") -> void:
	mode = next_mode; model.paused = true
	# A popup invalidates the step that was waiting for the animation to finish.
	move_buffer.clear()
	input_handler.held.set_blocked(true)
	card_title.text = title; card_body.text = body
	primary.text = first; secondary.text = second; tertiary.text = third
	secondary.visible = not second.is_empty(); tertiary.visible = not third.is_empty()
	card_scroll.scroll_vertical = 0; overlay.show(); layout(); refresh()

func close_card() -> void:
	mode = "playing"; model.paused = false; overlay.hide(); refresh()

func modal_primary() -> void:
	if stopped: return
	match mode:
		"finish":
			stopped = true; completed.emit()
		"reset":
			model.reset_current(); rescued_presented = model.rescued; gate_visual = [0.0, 0.0]; light_visual = 0
			rebuild_cranks(); close_card(); layout()
			checkpoint_changed.emit(model.room)
		"menu": stopped = true; menu_requested.emit()
		_: close_card()

func modal_secondary() -> void:
	if mode == "pause": show_card("reset", "重置这一窟？", "只重置当前洞窟的机关和位置，之前通过的洞窟不受影响。", "确认重置", "继续思考")
	else: close_card()

func modal_tertiary() -> void:
	if mode == "pause": show_card("menu", "返回首页？", "下次从最近完成的动作继续；已解机关、捷径和小画都会保留。", "返回首页", "留在这里")

func shutdown() -> void:
	stopped = true; model.paused = true; hide(); set_process(false); set_process_unhandled_key_input(false)
	restore_browser_viewport()

func restore_browser_viewport() -> void:
	if OS.has_feature("web"): JavaScriptBridge.eval("document.getElementById('mogao-cave-viewport')?.remove();")

func _exit_tree() -> void:
	# A deferred old chapter must not remove the style of a newly started chapter.
	if not stopped: restore_browser_viewport()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(overlay): pause_game()

func _unhandled_key_input(event: InputEvent) -> void:
	if stopped or not event is InputEventKey: return
	var key_event := event as InputEventKey
	var playing := mode == "playing" and not model.paused
	var action := input_handler.handle_direction(key_event, playing)
	if key_event.echo or not key_event.pressed:
		get_viewport().set_input_as_handled()
		return
	var key: int = key_event.physical_keycode if key_event.physical_keycode else key_event.keycode
	if mode != "playing" or model.paused:
		if key == KEY_ESCAPE and mode in ["note", "pause", "reset", "menu"]: close_card()
		get_viewport().set_input_as_handled()
		return
	if model.room == CaveModel.MIRROR_ROOM:
		var feature := input_handler.handle_feature(event, {"mirror_cave": true})
		if feature.type == GameAction.Type.INTERACT:
			interact()
			get_viewport().set_input_as_handled()
			return
	if action.type == GameAction.Type.MOVE:
		_take_direction(action.direction)
		get_viewport().set_input_as_handled()
		return
	match key:
		KEY_SPACE, KEY_E: interact()
		KEY_Z: undo()
		KEY_F: show_note()
		KEY_P, KEY_ESCAPE: pause_game()
	get_viewport().set_input_as_handled()


func _take_direction(direction: int) -> void:
	if stopped or mode != "playing" or model.paused:
		move_buffer.clear()
		return
	if model.busy == "step":
		move_buffer.remember(direction)
		return
	if not model.busy.is_empty():
		return
	move(_direction_vector(direction))


func _direction_vector(direction: int) -> Vector2i:
	return Vector2i(MazeGenerator.DX[direction], MazeGenerator.DY[direction])


func _collect_step_repeat(delta: float) -> void:
	if stopped or mode != "playing" or model.paused:
		move_buffer.clear()
		input_handler.held.set_blocked(true)
		return
	input_handler.held.set_blocked(false)
	if model.busy != "step":
		return
	for direction in input_handler.held.pull(delta):
		move_buffer.remember(int(direction))


func _settle_buffered_step(previous: String) -> void:
	if stopped or mode != "playing" or model.paused:
		move_buffer.clear()
		input_handler.held.set_blocked(true)
		return
	if previous != "step" or not model.busy.is_empty():
		return
	var direction := int(move_buffer.take())
	if direction < 0:
		direction = int(input_handler.held.current())
	if direction >= 0:
		move(_direction_vector(direction))

func _process(delta: float) -> void:
	if stopped: return
	frame += 1
	_collect_step_repeat(delta)
	var previous := model.busy
	var was_lit := model.lit()
	var previous_deer := model.deer_time
	model.advance(delta)
	if previous != model.busy:
		if model.rescued and not rescued_presented:
			rescued_presented = true
			AudioManager.play_pickup()
			show_card("rescue", "终于找到哥哥了", "哥哥：“爸爸，我把灯留在路边，怕你找不到。”\n\n爸爸：“看见了。我们一起出去。”\n\n沿上方平台，走向右侧透光的窟口。", "一起走向窟口")
		refresh()
		if model.busy.is_empty(): checkpoint_changed.emit(model.room)
	_settle_buffered_step(previous)
	if was_lit != model.lit():
		refresh(); checkpoint_changed.emit(model.room)
	if previous_deer != model.deer_time: queue_redraw()
	if not model.paused:
		var old_light := light_visual
		for i in 2:
			var before: float = gate_visual[i]
			gate_visual[i] = move_toward(before, 1.0 if model.gate_open(i) else 0.0, delta * 3)
			if before != gate_visual[i]: queue_redraw()
		light_visual = move_toward(light_visual, 1.0 if model.lit() else 0.0, delta * 2)
		if old_light != light_visual: queue_redraw()
	if not model.busy.is_empty():
		for i in cranks.size(): cranks[i].angle = model.angle(model.cranks[i].bridge); cranks[i].queue_redraw()
		queue_redraw()
	if overlay.visible:
		var available := get_viewport_rect().size
		var target := Vector2(minf(530, available.x - 16), minf(500, available.y - 16))
		if panel.size != target: panel.size = target

func _add_mirror_art() -> void:
	var art := Control.new()
	art.name = "MirrorArt"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.set_script(preload("res://scripts/mogao_chapter/mirror_art.gd"))
	art.host = self
	add_child(art)
	move_child(art, 0)
	mirror_art = art

func _draw() -> void:
	if heading: painter.paint(self)
	if mirror_art:
		mirror_art.queue_redraw()
