class_name TravelLore
extends RefCounted
## Shared, local-only content. Loading and gameplay use the same texts and diagrams.
const DEER = preload("res://assets/lore/nine_deer.svg")
static var entries: Dictionary = {}

static func entry(id: String) -> Dictionary:
	if id not in ["roadbook", "golden_light", "nine_deer"]: return {}
	if not entries.has(id):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lore/" + id + ".json"))
		entries[id] = parsed if parsed is Dictionary else {}
	return entries[id]

static func text(id: String, key: String) -> String:
	return str(entry(id).get(key, ""))
