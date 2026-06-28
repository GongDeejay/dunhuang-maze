extends Node

var player_stats: Dictionary = {}
var monster_data: Dictionary = {}
var terrain_data: Dictionary = {}
var item_data: Dictionary = {}
var level_data: Array = []
var difficulty_data: Dictionary = {}
var current_difficulty: String = "normal"

func _ready():
	_load_all()

func _load_all():
	player_stats = _load_json("res://assets/data/player_stats.json")
	monster_data = _load_json("res://assets/data/monster_data.json")
	terrain_data = _load_json("res://assets/data/terrain_data.json")
	item_data = _load_json("res://assets/data/item_data.json")
	var raw = _load_json("res://assets/data/levels.json")
	level_data = raw.get("levels", []) if raw is Dictionary else []
	difficulty_data = _load_json("res://assets/data/difficulty.json")
	print("[DataLoader] player_stats: ", player_stats.size(), " keys")
	print("[DataLoader] monster_data: ", monster_data.size(), " keys")
	print("[DataLoader] terrain_data: ", terrain_data.size(), " keys")
	print("[DataLoader] item_data: ", item_data.size(), " keys")
	print("[DataLoader] level_data: ", level_data.size(), " levels")
	print("[DataLoader] difficulty: ", difficulty_data.size(), " modes")

func _load_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: Failed to open %s" % path)
		return {}
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		push_error("DataLoader: JSON parse error in %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if json.data == null:
		push_error("DataLoader: JSON data is null in %s" % path)
		return {}
	return json.data

func get_monster_def(terrain_key: String) -> Dictionary:
	if monster_data.has(terrain_key):
		return monster_data[terrain_key]
	return {}

func get_terrain_config(terrain_key: String) -> Dictionary:
	if terrain_data.has(terrain_key):
		return terrain_data[terrain_key]
	return {}

func color_from_array(arr: Array) -> Color:
	if arr.size() < 3:
		return Color(0.5, 0.5, 0.5)
	return Color(arr[0], arr[1], arr[2])

func get_item_def(key: String) -> Dictionary:
	if item_data.has(key):
		return item_data[key]
	return {}

func get_level_data() -> Array:
	return level_data

func set_difficulty(key: String) -> void:
	current_difficulty = key

func get_difficulty() -> Dictionary:
	if difficulty_data.has(current_difficulty):
		return difficulty_data[current_difficulty]
	return difficulty_data.get("normal", {})
