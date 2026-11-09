class_name MoveBuffer
extends RefCounted
## One pending direction. A later press replaces the earlier one; nothing queues.

var _direction := -1
var _pending := false


func remember(direction: int) -> void:
	_direction = direction
	_pending = true


func pending() -> bool:
	return _pending


func take() -> int:
	if not _pending:
		return -1
	_pending = false
	var direction := _direction
	_direction = -1
	return direction


func clear() -> void:
	_pending = false
	_direction = -1
