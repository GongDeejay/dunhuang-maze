class_name Inventory
extends RefCounted

signal item_added(item_key: String)
signal item_used(item_key: String)
signal inventory_changed()

var items: Array = []
var max_size: int = 5

func add_item(item_key: String) -> bool:
	if items.size() >= max_size:
		return false
	items.append(item_key)
	item_added.emit(item_key)
	inventory_changed.emit()
	return true

func use_item(index: int) -> String:
	if index < 0 or index >= items.size():
		return ""
	var key = items[index]
	items.remove_at(index)
	item_used.emit(key)
	inventory_changed.emit()
	return key

func use_first_heal() -> String:
	for i in items.size():
		var def = DataLoader.get_item_def(items[i])
		if def.get("type", "") == "heal":
			return use_item(i)
	return ""

func get_heal_count() -> int:
	var count = 0
	for key in items:
		var def = DataLoader.get_item_def(key)
		if def.get("type", "") == "heal":
			count += 1
	return count

func get_count() -> int:
	return items.size()

func is_full() -> bool:
	return items.size() >= max_size

func get_item_list() -> Array:
	var result: Array = []
	for key in items:
		var def = DataLoader.get_item_def(key)
		result.append({
			"key": key,
			"name": def.get("name", "???"),
			"symbol": def.get("symbol", "?"),
			"type": def.get("type", ""),
			"value": def.get("value", 0),
		})
	return result
