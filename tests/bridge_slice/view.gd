extends Control
## A self-contained, render-only 2D box garden. Deliberately excluded from production.
const Rules = preload("res://tests/bridge_slice/model.gd")
const FONT = preload("res://tests/bridge_slice/font.ttf")
const DAD = preload("res://assets/high_quality/player/dj.svg")
const RABBITS = preload("res://assets/lore/three_hares.svg")
var model = Rules.new()
var heading: Label
var objective: Label
var hint: Label
var turn_button: Button
var restart_button: Button
var pause_button: Button
var cranks: Array[Button] = []
var arrows: Array[Button] = []
var origin := Vector2.ZERO
var unit := 60.0
var area := Rect2()
var narrow := false

func _ready() -> void:
	theme = Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 18
	heading = label("莫高窟 · 转动栈桥", 26, Color("f5dba8"))
	objective = label("哥哥的蓝围巾，就在对岸", 18, Color("eee1c8"))
	hint = label("走到岸边，看看转柄", 17, Color("e1c49a"))
	turn_button = button("转动栈桥", turn_bridge)
	restart_button = button("重新试玩", restart)
	pause_button = button("暂停", toggle_pause)
	for cell in [Vector2i(3, 5), Vector2i(3, 1)]:
		var crank := button("", turn_bridge, true)
		crank.tooltip_text = "走到转柄旁，转动栈桥"
		cranks.append(crank)
	for spec in [["↑", Vector2i.UP], ["←", Vector2i.LEFT], ["↓", Vector2i.DOWN], ["→", Vector2i.RIGHT]]:
		var direction: Vector2i = spec[1]
		arrows.append(button(spec[0], func(): move(direction)))
	get_viewport().size_changed.connect(layout)
	layout()
	refresh()

func label(text: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func button(text: String, callback: Callable, is_crank: bool = false) -> Button:
	var node: Button = preload("res://tests/bridge_slice/crank.gd").new() if is_crank else Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.custom_minimum_size = Vector2(48, 48)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("4b5148") if state == "normal" else Color("646e59")
		if state == "disabled": style.bg_color = Color("36352f")
		style.border_color = Color("af976b")
		style.set_border_width_all(1)
		if is_crank:
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(0)
		style.set_corner_radius_all(10)
		node.add_theme_stylebox_override(state, style)
	node.add_theme_color_override("font_color", Color("fff0d1"))
	node.add_theme_color_override("font_disabled_color", Color("a69a81"))
	node.pressed.connect(callback)
	add_child(node)
	return node

func layout() -> void:
	size = get_viewport_rect().size
	narrow = size.x < 600
	heading.text = "莫高窟 · 栈桥" if size.x < 340 else "莫高窟 · 转动栈桥"
	var short := size.y < 500
	heading.position = Vector2(18, 12)
	heading.size = Vector2(size.x - 124, 36)
	heading.add_theme_font_size_override("font_size", 22 if narrow else 26)
	objective.position = Vector2(18, 68)
	objective.size = Vector2(size.x - 36, 48)
	pause_button.position = Vector2(size.x - 98, 12)
	pause_button.size = Vector2(80, 48)
	var footer := 176.0 if not short else 50.0
	area = Rect2(12, 128 if not short else 98, size.x - 24, size.y - (128 if not short else 98) - footer)
	if short: area.size.x -= 224
	unit = minf(112, minf(area.size.x / 5.0, (area.size.y - 20) / 5.6))
	origin = area.get_center() - Vector2(unit * 2, unit * 2.16)
	var base := Vector2(maxf(8, size.x / 2 - 158), size.y - 112) if not short else Vector2(size.x - 214, size.y - 64)
	var offsets := [Vector2(54, -54), Vector2.ZERO, Vector2(54, 0), Vector2(108, 0)]
	for i in 4:
		arrows[i].position = base + offsets[i]
		arrows[i].size = Vector2(50, 50)
	turn_button.position = base + Vector2(172, -54 if not short else -112)
	if short: turn_button.position = Vector2(size.x - 214, 102)
	turn_button.size = Vector2(minf(144, size.x - base.x - 180) if not short else 196, 50)
	restart_button.position = base + Vector2(172, 0)
	if short: restart_button.position = Vector2(size.x - 214, 12)
	restart_button.size = Vector2(minf(144, size.x - base.x - 180) if not short else 104, 50)
	hint.position = Vector2(18, size.y - 50)
	hint.size = Vector2(area.size.x if short else size.x - 36, 44)
	for i in 2:
		cranks[i].position = point(Vector2(3, 5 if i == 0 else 1)) - Vector2(24, 30)
		cranks[i].size = Vector2(48, 48)
		cranks[i].visual_scale = clampf(unit / 70.0, .65, 1.0)
		cranks[i].queue_redraw()
	settle_text.call_deferred()
	queue_redraw()

func settle_text() -> void:
	# A Label's previous narrow width can leave a stale, tall minimum on the first frame.
	for node in [heading, objective, hint]: node.size.y = 0

func point(cell: Vector2) -> Vector2:
	return origin + Vector2(cell.x * unit, cell.y * unit * 0.72)

func refresh() -> void:
	turn_button.disabled = not model.can_turn()
	for i in 2:
		var cell := Vector2i(3, 5 if i == 0 else 1)
		cranks[i].disabled = not model.can_turn() or model.distance(model.player, cell) > 1
		cranks[i].angle = model.angle()
		cranks[i].queue_redraw()
	for arrow in arrows: arrow.disabled = model.paused or model.won or not model.busy.is_empty()
	pause_button.text = "继续" if model.paused else "暂停"
	if model.won:
		objective.text = "找到围巾了！是你把路接通的"
		hint.text = "哥哥就在前方。此处是玩法试玩终点。"
	elif model.paused:
		hint.text = "已暂停 · 点击继续"
	elif model.busy == "turn":
		hint.text = "栈桥正在转动……"
	elif model.connected:
		hint.text = "路接通了，走过去拿围巾"
	elif model.can_turn():
		hint.text = "点击岸边的转柄" if narrow else "点击岸边的转柄，或按空格"
	else:
		hint.text = "点方向键，走到岸边" if narrow else "方向键 / WASD 移动 · 走到岸边"
	settle_text.call_deferred()
	queue_redraw()

func move(direction: Vector2i) -> void:
	if model.step(direction): refresh()

func turn_bridge() -> void:
	if model.turn(): refresh()

func restart() -> void:
	model = Rules.new()
	objective.text = "哥哥的蓝围巾，就在对岸"
	refresh()

func toggle_pause() -> void:
	model.paused = not model.paused
	refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hint):
		model.paused = true
		refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_W, KEY_UP: move(Vector2i.UP)
		KEY_A, KEY_LEFT: move(Vector2i.LEFT)
		KEY_S, KEY_DOWN: move(Vector2i.DOWN)
		KEY_D, KEY_RIGHT: move(Vector2i.RIGHT)
		KEY_SPACE, KEY_E: turn_bridge()
		KEY_P, KEY_ESCAPE: toggle_pause()
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var previous: String = model.busy
	model.advance(delta)
	if previous != model.busy: refresh()
	if not model.busy.is_empty():
		for crank in cranks:
			crank.angle = model.angle()
			crank.queue_redraw()
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("252b2b"))
	# Layered ochre cave silhouette, built from geometry instead of another image download.
	var top := area.position.y
	draw_colored_polygon(PackedVector2Array([Vector2(0, top), Vector2(size.x, top), Vector2(size.x, size.y - 180), Vector2(size.x * .8, top + 135), Vector2(size.x * .55, top + 56), Vector2(size.x * .2, top + 118), Vector2(0, size.y - 180)]), Color("715448"))
	var shadow := point(Vector2(2, 3))
	draw_circle(shadow, unit * 1.85, Color("182426"))
	draw_arc(shadow, unit * 1.75, 0, TAU, 60, Color("40504b"), 2, true)
	for y in [0, 1, 5, 6]:
		for x in range(1, 4): tile(Vector2(x, y))
	# Cave recess and three-hares motif keep the scene tied to the existing chapter.
	var niche := point(Vector2(1, 0))
	draw_style_box(niche_style(), Rect2(niche - Vector2(unit * .38, unit * .64), Vector2(unit * .76, unit * .75)))
	draw_texture_rect(RABBITS, Rect2(niche - Vector2(unit * .29, unit * .54), Vector2.ONE * unit * .58), false, Color("d9be8b"))
	# Timber support remains fixed; only the bridge deck turns.
	draw_circle(shadow + Vector2(0, unit * .18), unit * .38, Color("574337"))
	draw_circle(shadow, unit * .32, Color("a1835a"))
	bridge(shadow, model.angle())
	if model.connected and model.busy != "turn":
		for y in [2, 3, 4]: draw_circle(point(Vector2(2, y)), 3, Color("f3d494"))
	# Scarf on a short timber rail, visible from the start and never hidden by a popup.
	var scarf := point(Vector2(2, 0))
	draw_line(scarf + Vector2(-unit * .27, -unit * .28), scarf + Vector2(unit * .27, -unit * .28), Color("d7ba81"), 5, true)
	draw_line(scarf + Vector2(-unit * .2, -unit * .28), scarf + Vector2(-unit * .2, unit * .15), Color("83684b"), 4, true)
	if not model.won:
		draw_colored_polygon(PackedVector2Array([scarf + Vector2(-unit * .08, -unit * .32), scarf + Vector2(unit * .22, -unit * .25), scarf + Vector2(unit * .12, unit * .16), scarf + Vector2(-unit * .02, unit * .1)]), Color("72d5dc"))
	var actor := point(model.visual_player())
	draw_set_transform(actor, 0, Vector2(1, .4))
	draw_circle(Vector2.ZERO, unit * .23, Color(0.08, 0.07, 0.06, .45))
	draw_set_transform(Vector2.ZERO)
	var height := maxf(34, unit * .75)
	draw_texture_rect(DAD, Rect2(actor - Vector2(height * .5, height * .85), Vector2.ONE * height), false)
	if model.won:
		draw_line(actor + Vector2(5, -height * .42), actor + Vector2(12, -height * .1), Color("72d5dc"), 5, true)

func niche_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("454439")
	style.set_corner_radius_all(18)
	return style

func tile(cell: Vector2) -> void:
	var p := point(cell)
	var rect := Rect2(p - Vector2(unit * .5, unit * .36), Vector2(unit, unit * .72))
	draw_rect(Rect2(rect.position + Vector2(0, unit * .18), rect.size), Color("795a45"))
	draw_rect(rect.grow(-1), Color("bf9b71") if int(cell.x + cell.y) % 2 else Color("caa77a"))
	draw_line(rect.position + Vector2(5, 5), rect.position + Vector2(unit - 5, 5), Color("dfbe8a"), 2, true)

func bridge(center: Vector2, angle: float) -> void:
	# Project a rotating top-down deck onto the same shallow perspective as the land.
	var ends := [Vector2(-1.48, -.32), Vector2(1.48, -.32), Vector2(1.48, .32), Vector2(-1.48, .32)]
	var polygon := PackedVector2Array()
	for p in ends:
		var v: Vector2 = p.rotated(angle)
		polygon.append(center + Vector2(v.x, v.y * .72) * unit)
	var drop := PackedVector2Array()
	for p in polygon: drop.append(p + Vector2(0, 8))
	draw_colored_polygon(drop, Color("624a34"))
	draw_colored_polygon(polygon, Color("d0aa70"))
	for i in range(-7, 8):
		var a := Vector2(i * .19, -.30).rotated(angle)
		var b := Vector2(i * .19, .30).rotated(angle)
		draw_line(center + Vector2(a.x, a.y * .72) * unit, center + Vector2(b.x, b.y * .72) * unit, Color("997343"), 2, true)
	for side in [-.31, .31]:
		var a := Vector2(-1.48, side).rotated(angle)
		var b := Vector2(1.48, side).rotated(angle)
		draw_line(center + Vector2(a.x, a.y * .72) * unit, center + Vector2(b.x, b.y * .72) * unit, Color("edcc94"), 3, true)
