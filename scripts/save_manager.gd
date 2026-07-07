class_name SaveManager
extends RefCounted

const SAVE_PATH := "user://dunhuang_save.json"

static func save_progress(level_index: int, difficulty: String, player_level: int, player_xp: int) -> bool:
	var data := {
		"level_index": level_index,
		"difficulty": difficulty,
		"player_level": player_level,
		"player_xp": player_xp,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

static func load_progress() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
