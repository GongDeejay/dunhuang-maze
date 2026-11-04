class_name MogaoJourney
extends RefCounted
## A bounded authored gate encounter embedded in the existing random second chapter.

const TABLE := Vector2i(4, 2)
const GATE := Vector2i(5, 2)
const FAMILY := Vector2i(14, 4)
const SIGN := Vector2i(3, 2)
const SCARF := Vector2i(6, 2)
const REVEAL_SECONDS := 1.6
const MODULE := Rect2i(0, 0, 11, 10)
var puzzle := PatternPuzzle.new()
var safe_cells: Dictionary = {}
var spawn_exclusions: Dictionary = {}
var events_seen: Dictionary = {}
var rescued := false
var gate_open := false
var gate_presented := false
var reveal_elapsed := -1.0
var crossed_gate := false
var scarf_found := false
var previous_pos := Vector2i.ZERO

func build(maze: MazeGenerator) -> void:
	maze.generate(-1, 4)
	maze.theme_key = "mogao"
	# Disconnect only the encounter module; the rest remains the generated maze.
	for y in MODULE.size.y:
		for x in MODULE.size.x:
			for d in [maze.N, maze.S, maze.E, maze.W]:
				var n := Vector2i(x + maze.DX[d], y + maze.DY[d])
				if maze.in_bounds(n.x, n.y): maze.grid[n.y][n.x] &= ~maze.OPPOSITE[d]
			maze.grid[y][x] = 0
			maze.terrain[y][x] = maze.Terrain.GROTTO
			spawn_exclusions[Vector2i(x, y)] = true
	var entry := _carve(maze, [Vector2i.ZERO, Vector2i(2, 0), Vector2i(2, 2), TABLE])
	var bypass := _carve(maze, [TABLE, Vector2i(4, 8), Vector2i(8, 8), Vector2i(8, 2), GATE])
	var onward := _carve(maze, [SCARF, Vector2i(6, 0), Vector2i(10, 0), Vector2i(10, 4), FAMILY])
	# Guaranteed connection outside the module, without creating another gate bypass.
	_carve(maze, [FAMILY, Vector2i(maze.width - 1, 4), Vector2i(maze.width - 1, maze.height - 1)])
	for pos in entry + bypass + onward:
		safe_cells[pos] = true
		spawn_exclusions[pos] = true
	for pos in [Vector2i(4, 6), Vector2i(4, 7), Vector2i(8, 6)]:
		maze.terrain[pos.y][pos.x] = maze.Terrain.GROTTO
	for y in range(2, 7):
		for x in range(12, 17):
			safe_cells[Vector2i(x, y)] = true
			spawn_exclusions[Vector2i(x, y)] = true
	maze.landmarks = {
		SIGN: {"symbol": "路", "kind": "fork"},
		TABLE: {"symbol": "纹", "kind": "pattern"},
		GATE: {"symbol": "近路", "kind": "pattern_gate", "open": false, "visual_open": 0.0, "discovered": false},
		SCARF: {"symbol": "围巾", "kind": "scarf", "discovered": false},
		Vector2i(4, 5): {"symbol": "廊", "kind": "cave"},
	}
	for pos in [TABLE, GATE, SCARF]:
		maze.landmarks[pos]["light"] = 0.0

func _carve(maze: MazeGenerator, corners: Array) -> Array:
	var cells: Array = [corners[0]]
	for i in range(1, corners.size()):
		var p: Vector2i = corners[i - 1]
		var end: Vector2i = corners[i]
		while p != end:
			var d := maze.E if end.x > p.x else maze.W
			if p.x == end.x: d = maze.S if end.y > p.y else maze.N
			var n := p + Vector2i(maze.DX[d], maze.DY[d])
			maze.grid[p.y][p.x] |= d
			maze.grid[n.y][n.x] |= maze.OPPOSITE[d]
			maze.terrain[p.y][p.x] = maze.Terrain.ANCIENT_ROAD
			maze.terrain[n.y][n.x] = maze.Terrain.ANCIENT_ROAD
			cells.append(n)
			p = n
	return cells

func can_inspect(maze: MazeGenerator, pos: Vector2i) -> bool:
	if pos.distance_to(TABLE) > 1.0: return false
	if pos == TABLE: return true
	for d in [maze.N, maze.S, maze.E, maze.W]:
		if pos + Vector2i(maze.DX[d], maze.DY[d]) == TABLE:
			return maze.can_move(pos.x, pos.y, d)
	return false

func open_gate(maze: MazeGenerator) -> bool:
	if gate_open or not puzzle.completed(): return false
	gate_open = true
	maze.grid[TABLE.y][TABLE.x] |= maze.E
	maze.grid[GATE.y][GATE.x] |= maze.W
	maze.landmarks[GATE].merge({"open": true, "discovered": true}, true)
	maze.landmarks[TABLE]["symbol"] = "匣"
	return true

func revealing() -> bool:
	return reveal_elapsed >= 0.0 and not gate_presented

func begin_reveal() -> bool:
	if not gate_open or gate_presented or revealing(): return false
	reveal_elapsed = 0.0
	return true

func tick_reveal(maze: MazeGenerator, delta: float) -> bool:
	if not revealing(): return false
	reveal_elapsed = minf(REVEAL_SECONDS, reveal_elapsed + delta)
	maze.landmarks[GATE]["visual_open"] = clampf(reveal_elapsed / 0.85, 0.0, 1.0)
	for i in 3:
		var pos := TABLE + Vector2i(i, 0)
		maze.landmarks[pos]["light"] = clampf((reveal_elapsed - 0.65 - i * 0.18) / 0.25, 0.0, 1.0)
		maze.landmarks[pos]["discovered"] = true
	if reveal_elapsed >= REVEAL_SECONDS:
		gate_presented = true
	return true

func guiding_to_gate() -> bool:
	return gate_presented and not crossed_gate and not scarf_found and not rescued

func encounter_focus(pos: Vector2i) -> bool:
	return revealing() or (not scarf_found and Rect2i(3, 1, 4, 3).has_point(pos))

func enter(pos: Vector2i) -> Dictionary:
	if gate_open and previous_pos == TABLE and pos == GATE: crossed_gate = true
	previous_pos = pos
	if pos == SCARF and not scarf_found:
		scarf_found = true
	# The visible door/scarf and local route caption replace two interrupting cards.
	if pos == SIGN: events_seen["fork"] = true
	return {}

func rescue() -> Dictionary:
	if rescued: return {}
	rescued = true
	return {"title": "终于找到哥哥了", "body": "哥哥：“爸爸！弟弟往三危山那边去了。”\n先到窟群外的会合点，再继续寻找弟弟。\n跟随蓝色指引前往出口。", "button": "一起走出栈道"}

func objective() -> String:
	if revealing(): return "木门打开了 · 栈道通了！"
	if guiding_to_gate(): return "三兔共用三耳 · 沿蓝色箭头穿门"
	return "与哥哥前往会合点" if rescued else "沿栈道寻找哥哥"

func terrain_name(key: String) -> String:
	return {"sand": "窟前积沙", "desert": "风口·风沙伤害", "grotto": "暗廊·视野受限", "oasis": "补给水点", "ancient_road": "檐下栈道"}.get(key, "栈道")
