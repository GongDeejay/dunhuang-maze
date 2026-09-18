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
var next_move_dir: int = -1
var patrol_cells: Dictionary = {}

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

func plan_next_move(maze: MazeGenerator, occupied: Dictionary, target_pos: Vector2i) -> void:
	if maze == null:
		return
	var dirs: Array = [MazeGenerator.N, MazeGenerator.S, MazeGenerator.E, MazeGenerator.W]
	dirs.shuffle()
	next_move_dir = -1
	var best_distance := 999999
	var chase := pos.distance_to(target_pos) <= 6.0
	for d in dirs:
		if maze.can_move(pos.x, pos.y, d):
			var next := pos + Vector2i(MazeGenerator.DX[d], MazeGenerator.DY[d])
			if not maze.in_bounds(next.x, next.y):
				continue
			if not patrol_cells.is_empty() and not patrol_cells.has(next):
				continue
			if occupied.has(next) and next != target_pos:
				continue
			var distance := absi(next.x - target_pos.x) + absi(next.y - target_pos.y)
			if not chase:
				next_move_dir = d
				break
			if distance < best_distance:
				best_distance = distance
				next_move_dir = d


func try_move(maze: MazeGenerator, occupied: Dictionary, target_pos: Vector2i, delta: float) -> Dictionary:
	move_timer += delta
	if next_move_dir < 0:
		plan_next_move(maze, occupied, target_pos)
	if move_timer < move_interval:
		return {"moved": false, "attacked": false}
	move_timer = 0.0
	var dir := next_move_dir
	next_move_dir = -1
	if dir < 0 or not maze.can_move(pos.x, pos.y, dir):
		plan_next_move(maze, occupied, target_pos)
		return {"moved": false, "attacked": false}
	var next := pos + Vector2i(MazeGenerator.DX[dir], MazeGenerator.DY[dir])
	if next == target_pos:
		return {"moved": false, "attacked": true}
	if not maze.in_bounds(next.x, next.y) or occupied.has(next):
		plan_next_move(maze, occupied, target_pos)
		return {"moved": false, "attacked": false}
	pos = next
	plan_next_move(maze, occupied, target_pos)
	return {"moved": true, "attacked": false}

func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	if hp <= 0:
		defeated.emit(self)

func is_alive() -> bool:
	return hp > 0

func get_intent_arrow() -> String:
	match next_move_dir:
		MazeGenerator.N: return "↑"
		MazeGenerator.S: return "↓"
		MazeGenerator.E: return "→"
		MazeGenerator.W: return "←"
		_: return ""
