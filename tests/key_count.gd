extends Node

var presses := 0


func _ready() -> void:
	set_process_unhandled_key_input(true)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		presses += 1
