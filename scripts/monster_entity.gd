class_name MonsterEntity
extends Node2D

signal defeated(monster: MonsterEntity)

var pos := Vector2i(0, 0)
var monster_type: String
var display_name: String
var symbol: String
var hp: int
var max_hp: int
var atk: int
var color: Color
var xp: int
var move_timer: float = 0.0
var move_interval: float = 2.0

func setup(terrain_key: String, spawn_pos: Vector2i, scale: float = 1.0) -> void:
	pos = spawn_pos
	monster_type = terrain_key

	var def = DataLoader.get_monster_def(terrain_key)
	display_name = def.get("name", "未知")
	symbol = def.get("symbol", "?")
	hp = int(def.get("hp", 5) * scale)
	max_hp = hp
	atk = int(def.get("atk", 2) * scale)
	xp = int(def.get("xp", 1) * scale)
	color = DataLoader.color_from_array(def.get("color", [0.5, 0.5, 0.5]))
	move_interval = randf_range(1.5, 3.0)

func try_move(maze: MazeGenerator, occupied: Dictionary) -> void:
	move_timer += get_process_delta_time()
	if move_timer < move_interval:
		return
	move_timer = 0.0

	var dirs: Array = [MazeGenerator.N, MazeGenerator.S, MazeGenerator.E, MazeGenerator.W]
	dirs.shuffle()
	for d in dirs:
		if maze.can_move(pos.x, pos.y, d):
			var next = pos + Vector2i(MazeGenerator.DX[d], MazeGenerator.DY[d])
			if maze._in_bounds(next.x, next.y) and not occupied.has(next):
				pos = next
				break

func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	if hp <= 0:
		defeated.emit(self)

func is_alive() -> bool:
	return hp > 0
