class_name HeldMove
extends RefCounted
## Keyboard direction hold. A press steps immediately; while the key stays down,
## another step is due every REPEAT_SECONDS. Echo events are ignored so browser
## key-repeat cannot add extra steps. The most recently pressed direction wins.

const REPEAT_SECONDS := 0.14

var _order: Array[int] = []
var _elapsed := 0.0
var _blocked := false
var _last_signature := ""
var _last_immediate := -1

func feed(event: InputEvent, allowed: bool) -> int:
	if not event is InputEventKey:
		return -1
	var key_event := event as InputEventKey
	var signature := "%d|%s|%s|%s|%s" % [
		key_event.get_instance_id(), key_event.pressed, key_event.echo,
		key_event.keycode, key_event.physical_keycode,
	]
	if signature == _last_signature:
		return _last_immediate
	_last_signature = signature
	_last_immediate = -1
	if not allowed:
		# Opening or holding a modal must not turn held time into a catch-up step.
		_blocked = true
		_elapsed = 0.0
	if key_event.echo:
		return -1
	var direction := _direction(key_event)
	if direction < 0:
		return -1
	if key_event.pressed:
		# Browser key-repeat sometimes arrives without echo. The key is already
		# held, so keep the 0.14s clock instead of restarting it or stepping again.
		var already_holding := not _order.is_empty() and _order[_order.size() - 1] == direction
		_order.erase(direction)
		_order.append(direction)
		if already_holding:
			return -1
		_elapsed = 0.0
		if _blocked or not allowed:
			return -1
		_last_immediate = direction
		return direction
	_order.erase(direction)
	if _order.is_empty():
		_blocked = false
		_elapsed = 0.0
	return -1


func set_blocked(blocked: bool) -> void:
	if blocked:
		_blocked = true
		_elapsed = 0.0
		return
	# Stay latched until every direction key is released, so closing a card
	# does not replay the key that was held while it was open.
	if _blocked and _order.is_empty():
		_blocked = false
	elif _blocked:
		_elapsed = 0.0


func blocked() -> bool:
	return _blocked


func current() -> int:
	if _blocked or _order.is_empty():
		return -1
	return _order[_order.size() - 1]


func pull(delta: float) -> Array[int]:
	var steps: Array[int] = []
	if _blocked or _order.is_empty():
		_elapsed = 0.0
		return steps
	_elapsed += maxf(delta, 0.0)
	var guard := 0
	while _elapsed + 0.0000001 >= REPEAT_SECONDS and guard < 64:
		_elapsed -= REPEAT_SECONDS
		steps.append(_order[_order.size() - 1])
		guard += 1
	return steps


func clear() -> void:
	_order.clear()
	_elapsed = 0.0
	_blocked = false
	_last_signature = ""
	_last_immediate = -1


func _direction(event: InputEventKey) -> int:
	if event.is_action("move_up"):
		return MazeGenerator.N
	if event.is_action("move_down"):
		return MazeGenerator.S
	if event.is_action("move_left"):
		return MazeGenerator.W
	if event.is_action("move_right"):
		return MazeGenerator.E
	return -1
