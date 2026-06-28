class_name PlayerController
extends Node2D

signal hp_changed(new_hp: int, max_hp: int)
signal died
signal moved(new_pos: Vector2i)

var pos := Vector2i(0, 0)
var hp: int
var max_hp: int
var atk: int
var crit_chance: float
var crit_multiplier: int
var dodge_chance: float

var temp_atk_bonus: int = 0
var temp_def_bonus: int = 0
var temp_reveal_bonus: int = 0
var reveal_bonus: int = 0
var buff_timer: int = 0
var is_hurt: bool = false

func _ready():
	var stats = DataLoader.player_stats
	max_hp = stats.get("max_hp", 15)
	hp = max_hp
	atk = stats.get("base_atk", 4)
	crit_chance = stats.get("crit_chance", 0.10)
	crit_multiplier = stats.get("crit_multiplier", 2)
	dodge_chance = stats.get("dodge_chance", 0.05)

func initialize(start_pos: Vector2i) -> void:
	pos = start_pos
	hp = max_hp
	temp_atk_bonus = 0
	temp_def_bonus = 0
	temp_reveal_bonus = 0
	buff_timer = 0

func take_damage(amount: int) -> void:
	if randf() < dodge_chance:
		return
	var final_damage = maxi(amount - get_effective_def(), 0)
	hp = maxi(hp - final_damage, 0)
	is_hurt = true
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		died.emit()

func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)

func is_alive() -> bool:
	return hp > 0

func roll_damage() -> int:
	var base = get_effective_atk()
	var is_crit = randf() < crit_chance
	var damage = base + randi_range(-1, 2)
	if is_crit:
		damage *= crit_multiplier
	return maxi(damage, 1)

func get_effective_atk() -> int:
	return atk + temp_atk_bonus

func get_effective_def() -> int:
	return temp_def_bonus

func get_effective_reveal_bonus() -> int:
	return temp_reveal_bonus

func apply_item(key: String) -> void:
	var def = DataLoader.get_item_def(key)
	var type = def.get("type", "")
	var value = def.get("value", 0)
	var duration = def.get("duration", 0)
	match type:
		"heal":
			heal(value)
		"defense":
			temp_def_bonus = value
			buff_timer = duration
		"attack":
			temp_atk_bonus = value
			buff_timer = duration
		"reveal":
			if value >= 99:
				temp_reveal_bonus = 999
			else:
				temp_reveal_bonus = value
				buff_timer = duration
		"special":
			pass

func tick_buff() -> void:
	if buff_timer > 0:
		buff_timer -= 1
		if buff_timer <= 0:
			temp_atk_bonus = 0
			temp_def_bonus = 0
			if temp_reveal_bonus < 999:
				temp_reveal_bonus = 0
