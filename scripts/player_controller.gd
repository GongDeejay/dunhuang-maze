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
var move_speed: float = 1.0
var xp: int = 0
var level: int = 1

func _ready():
	var stats = DataLoader.player_stats
	max_hp = stats.get("max_hp", 15)
	hp = max_hp
	atk = stats.get("base_atk", 4)
	crit_chance = stats.get("crit_chance", 0.10)
	crit_multiplier = stats.get("crit_multiplier", 2)
	dodge_chance = stats.get("dodge_chance", 0.05)
	move_speed = stats.get("move_speed", 1.0)

func initialize(start_pos: Vector2i) -> void:
	pos = start_pos
	hp = max_hp
	temp_atk_bonus = 0
	temp_def_bonus = 0
	temp_reveal_bonus = 0
	buff_timer = 0

func take_damage(amount: int) -> Dictionary:
	if randf() < dodge_chance:
		return {"dodged": true, "damage_taken": 0}
	var final_damage = maxi(amount - get_effective_def(), 0)
	hp = maxi(hp - final_damage, 0)
	is_hurt = true
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		died.emit()
	return {"dodged": false, "damage_taken": final_damage}

func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)

func is_alive() -> bool:
	return hp > 0

func roll_damage() -> Dictionary:
	var base = get_effective_atk()
	var is_crit = randf() < crit_chance
	var damage = base + randi_range(-1, 2)
	if is_crit:
		damage *= crit_multiplier
	return {"damage": maxi(damage, 1), "is_crit": is_crit}

func add_xp(amount: int) -> bool:
	xp += amount
	var leveled := false
	while xp >= _xp_for_next_level():
		xp -= _xp_for_next_level()
		level += 1
		max_hp += 2
		hp = mini(hp + 2, max_hp)
		atk += 1
		leveled = true
	hp_changed.emit(hp, max_hp)
	return leveled

func _xp_for_next_level() -> int:
	return 5 + level * 3

func get_effective_atk() -> int:
	return atk + temp_atk_bonus

func get_effective_def() -> int:
	return temp_def_bonus

func get_effective_reveal_bonus() -> int:
	return temp_reveal_bonus

func apply_item(key: String) -> String:
	var def = DataLoader.get_item_def(key)
	if def.is_empty():
		return "无法使用该物品"
	var type = def.get("type", "")
	var value = def.get("value", 0)
	var duration = def.get("duration", 0)
	var name = def.get("name", key)
	match type:
		"heal":
			heal(value)
			return "使用 %s: 恢复 %d HP" % [name, value]
		"defense":
			temp_def_bonus = value
			buff_timer = duration
			return "使用 %s: 防御+%d (%d回合)" % [name, value, duration]
		"attack":
			temp_atk_bonus = value
			buff_timer = duration
			return "使用 %s: 攻击+%d (%d回合)" % [name, value, duration]
		"reveal":
			if value >= 99:
				temp_reveal_bonus = 999
			else:
				temp_reveal_bonus = value
				buff_timer = duration
			return "使用 %s" % name
		"special":
			return "无法使用 %s" % name
		_:
			return "无法使用 %s" % name

func tick_buff() -> void:
	if buff_timer > 0:
		buff_timer -= 1
		if buff_timer <= 0:
			temp_atk_bonus = 0
			temp_def_bonus = 0
			if temp_reveal_bonus < 999:
				temp_reveal_bonus = 0
