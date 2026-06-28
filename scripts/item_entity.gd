class_name ItemEntity
extends Node2D

signal picked_up(item_key: String)

var pos := Vector2i(0, 0)
var item_key: String
var display_name: String
var symbol: String
var item_type: String
var value: int
var duration: int
var color: Color
var rarity: float

func setup(key: String, spawn_pos: Vector2i) -> void:
	item_key = key
	pos = spawn_pos
	var def = DataLoader.get_item_def(key)
	display_name = def.get("name", "未知")
	symbol = def.get("symbol", "?")
	item_type = def.get("type", "special")
	value = def.get("value", 0)
	duration = def.get("duration", 0)
	rarity = def.get("rarity", 0.1)
	color = _rarity_color(rarity)

func _rarity_color(r: float) -> Color:
	if r <= 0.03:
		return Color(0.6, 0.3, 0.9)
	elif r <= 0.08:
		return Color(0.3, 0.5, 0.95)
	return Color(0.85, 0.85, 0.85)
