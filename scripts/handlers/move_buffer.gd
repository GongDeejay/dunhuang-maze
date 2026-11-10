class_name MoveBuffer
extends RefCounted
## One replaceable direction, plus a queue for taps that each have to happen.
## remember() is the single slot (a later press replaces it).
## enqueue() keeps every press, so a released key can be pressed again during a step.

var _direction := -1
var _pending := false
var _queue: Array[int] = []


func remember(direction: int) -> void:
	_direction = direction
	_pending = true


func enqueue(direction: int) -> void:
	_queue.append(direction)


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
