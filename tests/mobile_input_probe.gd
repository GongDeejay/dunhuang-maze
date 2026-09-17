# Test-only browser fixture. Excluded from production exports with tests/**.
extends Node2D

var controls := MobileControls.new()
var moves: Array[int] = []
var actions: Array[String] = []
var events: Array[String] = []

func _ready() -> void:
	add_child(controls)
	controls.apply_layout(UILayoutDirector.compute(get_viewport_rect().size, true))
	controls.move_pressed.connect(func(dir: int): moves.append(dir))
	controls.action_pressed.connect(func(action: String): actions.append(action))
	_publish()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		events.append("%s:%d:%s" % [event.get_class(), event.device, event.pressed])
	if controls.try_handle_input(event):
		get_viewport().set_input_as_handled()
	_publish()

func _publish() -> void:
	if not OS.has_feature("web"):
		return
	var buttons: Array = []
	for entry in controls._dpad_centers:
		buttons.append({"x": entry.pos.x, "y": entry.pos.y, "dir": entry.dir})
	var center := controls.layout.maze_rect.get_center()
	JavaScriptBridge.eval("window.mobileInputProbe = " + JSON.stringify({
		"moves": moves, "actions": actions, "events": events, "buttons": buttons,
		"viewport": {"width": get_viewport_rect().size.x, "height": get_viewport_rect().size.y},
		"maze": {"x": center.x, "y": center.y}, "swipe": controls.swipe_threshold,
		"emulateMouse": Input.emulate_mouse_from_touch,
	}) + ";")
