class_name KeyTracker
extends RefCounted

signal key_collected(collected: int, required: int)
signal all_keys_collected()

var required_keys: int = 0
var collected_keys: int = 0

func setup(count: int) -> void:
	required_keys = count
	collected_keys = 0

func add_key() -> void:
	if collected_keys < required_keys:
		collected_keys += 1
		key_collected.emit(collected_keys, required_keys)
		if collected_keys >= required_keys:
			all_keys_collected.emit()

func has_all_keys() -> bool:
	return collected_keys >= required_keys

func get_progress() -> String:
	return "%d/%d" % [collected_keys, required_keys]

func get_remaining() -> int:
	return maxi(required_keys - collected_keys, 0)
