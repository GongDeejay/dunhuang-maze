class_name MoveBuffer
extends RefCounted
## remember() keeps one direction for the attack cooldown; a later press replaces it.
## enqueue() stores taps that have not started moving. At most MAX_PENDING_STEPS.

const MAX_PENDING_STEPS := 24

var _direction := -1
var _pending := false
var _queue: Array[int] = []


func remember(direction: int) -> void:
	_direction = direction
	_pending = true


func enqueue(direction: int) -> bool:
	if _queue.size() >= MAX_PENDING_STEPS:
		return false
	_queue.append(direction)
	return true


func pending_count() -> int:
	return _queue.size()


func pending() -> bool:
	return _pending or not _queue.is_empty()


func take() -> int:
	if not _queue.is_empty():
		return int(_queue.pop_front())
	if not _pending:
		return -1
	_pending = false
	var direction := _direction
	_direction = -1
	return direction


func clear() -> void:
	_pending = false
	_direction = -1
	_queue.clear()
