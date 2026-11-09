class_name FirstJourney
extends RefCounted
## First-level authored beats. Other levels keep their existing maze generator.

const Branches = preload("res://scripts/journey_branches.gd")

const SIZE := Vector2i(17, 13)
const FORK := Vector2i(4, 3)
const JOIN := Vector2i(12, 8)
const FAMILY := Vector2i(14, 4)
const CAMP := Vector2i(16, 12)
const SPRING := Vector2i(1, 8)
const MURAL := Vector2i(7, 8)
const STONE_GATE := Vector2i(12, 8)
const BEACON := Vector2i(12, 1)
const CARAVAN := Vector2i(1, 12)
const STELE := Vector2i(7, 9)
const BEACON_PATH: Array = [Vector2i(9, 3), Vector2i(9, 1), BEACON]
const CARAVAN_PATH: Array = [Vector2i(5, 11), Vector2i(5, 12), CARAVAN]
const STELE_PATH: Array = [Vector2i(9, 10), Vector2i(7, 10), STELE]
const CARAVAN_GHOST: Array = [Vector2i(5, 9), Vector2i(5, 10), Vector2i(5, 11)]
const FOOTPRINTS: Array = [
	{"at": Vector2i(9, 3), "dir": "n", "pulse": true, "branch": "beacon"},
	{"at": Vector2i(9, 2), "dir": "n", "pulse": false, "branch": "beacon"},
	{"at": Vector2i(9, 1), "dir": "e", "pulse": false, "branch": "beacon"},
	{"at": Vector2i(10, 1), "dir": "e", "pulse": false, "branch": "beacon"},
	{"at": Vector2i(5, 11), "dir": "s", "pulse": true, "branch": "caravan"},
	{"at": Vector2i(5, 12), "dir": "w", "pulse": false, "branch": "caravan"},
	{"at": Vector2i(4, 12), "dir": "w", "pulse": false, "branch": "caravan"},
	{"at": Vector2i(3, 12), "dir": "w", "pulse": false, "branch": "caravan"},
	{"at": Vector2i(9, 10), "dir": "w", "pulse": true, "branch": "stele"},
	{"at": Vector2i(8, 10), "dir": "w", "pulse": false, "branch": "stele"},
	{"at": Vector2i(7, 10), "dir": "n", "pulse": false, "branch": "stele"},
]
const VISION_BONUS_CAP := 2
const FRAGMENTS_TOTAL := 3
const CARAVAN_HEAL := 5
const SILHOUETTE_SECONDS := 3.0
const BEACON_REVEAL := 1
const SPRING_HEAL := 6
const MURAL_HEAL := 8
const MURAL_REVEAL := 1
const RESCUE_HEAL := 4
const SCORPION_ATK_BASE := 2
const SCORPION_MOVE_INTERVAL := 2.4

var events_seen: Dictionary = {}
var rescued := false
var spring_used := false
var mural_found := false
var route_studied := false
var gate_reached := false
var route_taken := ""
var safe_route: Array[Vector2i] = []
var short_route: Array[Vector2i] = []
var beacon_found := false
var caravan_found := false
var stele_found := false
var bell_clue := false
var camp_clue := false
var journey_vision := 0
var silhouette_time := 0.0
var fragments: Dictionary = {}

func build(maze: MazeGenerator) -> void:
	assert(Vector2i(maze.width, maze.height) == SIZE)
	maze._init_grid()
	_carve(maze, [Vector2i(0, 0), Vector2i(2, 0), Vector2i(2, 2), Vector2i(4, 2), FORK], MazeGenerator.Terrain.ANCIENT_ROAD)
	safe_route = _carve(maze, [FORK, Vector2i(4, 6), Vector2i(1, 6), Vector2i(1, 9), Vector2i(5, 9), Vector2i(5, 11), Vector2i(9, 11), Vector2i(9, 8), JOIN], MazeGenerator.Terrain.ANCIENT_ROAD)
	short_route = _carve(maze, [FORK, Vector2i(9, 3), Vector2i(9, 5), Vector2i(12, 5), JOIN], MazeGenerator.Terrain.SAND)
	for pos in [Vector2i(7, 3), Vector2i(8, 3), Vector2i(9, 3), Vector2i(9, 4)]:
		maze.terrain[pos.y][pos.x] = MazeGenerator.Terrain.DESERT
	_carve(maze, [Vector2i(4, 6), Vector2i(7, 6), MURAL], MazeGenerator.Terrain.GROTTO)
	maze.terrain[6][4] = MazeGenerator.Terrain.ANCIENT_ROAD
	_carve(maze, [JOIN, Vector2i(12, 10), Vector2i(14, 10), FAMILY], MazeGenerator.Terrain.ANCIENT_ROAD)
	_carve(maze, [Vector2i(9, 11), Vector2i(9, 12), CAMP], MazeGenerator.Terrain.ANCIENT_ROAD)
	maze.terrain[SPRING.y][SPRING.x] = MazeGenerator.Terrain.OASIS
	maze.terrain[FAMILY.y][FAMILY.x] = MazeGenerator.Terrain.OASIS
	maze.terrain[CAMP.y][CAMP.x] = MazeGenerator.Terrain.OASIS
	# Small optional alcoves vary; neither route nor a story beat can be cut off.
	var alcove_y := 7 if randi() % 2 == 0 else 8
	_carve(maze, [Vector2i(1, alcove_y), Vector2i(0, alcove_y)], MazeGenerator.Terrain.SAND)
	maze.landmarks = {
		Vector2i(2, 1): {"symbol": "迹", "kind": "clue"},
		FORK: {"symbol": "路", "kind": "fork"},
		SPRING: {"symbol": "泉", "kind": "spring"},
		Vector2i(4, 6): {"symbol": "窟", "kind": "cave"},
		MURAL: {"symbol": "画", "kind": "mural"},
		STONE_GATE: {"symbol": "门", "kind": "stone_gate"},
		Vector2i(1, 7): {"symbol": "鹿", "kind": "deer"},
		CAMP: {"symbol": "营", "kind": "camp"},
	}
	Branches.carve(self, maze)

func spawn(parent: Node, on_defeated: Callable) -> Dictionary:
	var monsters: Array[MonsterEntity] = []
	var items: Array[ItemEntity] = []
	# Enemies remain in encounter areas: waiting at a sign cannot pull them into spawn.
	var encounters := [
		[Vector2i(10, 5), [Vector2i(10, 5), Vector2i(11, 5), Vector2i(12, 5)]],
		[Vector2i(6, 6), [Vector2i(6, 6), Vector2i(7, 6), Vector2i(7, 7)]],
		[Vector2i(12, 9), [Vector2i(12, 8), Vector2i(12, 9), Vector2i(12, 10)]],
	]
	var diff := DataLoader.get_difficulty()
	for encounter in encounters:
		var monster := MonsterEntity.new()
		monster.setup("sand", encounter[0], float(diff.get("monster_hp_multiplier", 1.0)))
		monster.atk = maxi(1, int(SCORPION_ATK_BASE * float(diff.get("monster_atk_multiplier", 1.0))))
		monster.move_interval = SCORPION_MOVE_INTERVAL
		for pos in encounter[1]:
			monster.patrol_cells[pos] = true
		monster.defeated.connect(on_defeated)
		parent.add_child(monster)
		monsters.append(monster)
	for spec in [["heal_scroll", Vector2i(3, 2)], ["heal_scroll", Vector2i(5, 9)], ["family_1", FAMILY]]:
		var item := ItemEntity.new()
		item.setup(spec[0], spec[1])
		parent.add_child(item)
		items.append(item)
	return {"monsters": monsters, "items": items}

func sync_visibility(pos: Vector2i, maze: MazeGenerator) -> void:
	Branches.sync(self, maze, pos)

func enter(pos: Vector2i, maze: MazeGenerator, player: PlayerController) -> Dictionary:
	if pos == STONE_GATE: gate_reached = true
	if route_taken.is_empty():
		if pos == Vector2i(4, 4): route_taken = "古道"
		elif pos == Vector2i(5, 3): route_taken = "风沙近路"
	Branches.sync(self, maze, pos)
	if events_seen.has(pos):
		return {}
	events_seen[pos] = true
	var branch := Branches.reward(self, pos, maze, player)
	if not branch.is_empty():
		return branch
	match pos:
		Vector2i(2, 1):
			return {"title": "沙地里的足迹", "body": "这是妈妈的脚印！她应该往古道深处去了。\n前面有一份疗伤卷，走过去即可拾取。低血量时会自动使用，也可以主动使用。", "button": "沿着足迹出发"}
		FORK:
			return {"title": "路牌前，选一条路", "body": "↓ 古道：绕远，但没有风沙伤害，沿路有一眼清泉。\n→ 近路：更短，要经过四格风沙，还会遇到沙蝎。\n↗ 远处有座烽燧，站上去能望得更远。\n两条路都能找到妈妈，可以随时折返。", "button": "我来选路"}
		Vector2i(4, 6):
			return {"title": "古道旁的石窟", "body": "← 沿古道继续，前面有清泉。\n→ 石窟里有壁画和补给，但有沙蝎守着。\n探索石窟不是必需的，想去看看吗？", "button": "继续探索"}
		SPRING:
			spring_used = true
			player.heal(SPRING_HEAL)
			return {"title": "鹿形路标旁的清泉", "body": TravelLore.text("nine_deer", "reveal") + "\n恢复 %d 点体力，这眼泉水只能取用一次。\n" % SPRING_HEAL + TravelLore.text("nine_deer", "fiction"), "button": "继续寻找妈妈"}
		MURAL:
			mural_found = true
			fragments[1] = true
			if maze.landmarks.has(MURAL):
				maze.landmarks[MURAL]["found"] = true
			player.heal(MURAL_HEAL)
			Branches.grant_vision(self, player, MURAL_REVEAL)
			return {"title": "妈妈的壁画路书", "body": "找到路书与补给：恢复 %d 点体力，本关视野 +1。" % MURAL_HEAL, "kind": "roadbook"}
		CAMP:
			if not rescued:
				camp_clue = true
				return Branches.camp_card()
	return {}

func tick_silhouette(delta: float, maze: MazeGenerator) -> void:
	Branches.tick(self, delta, maze)

func rescue(maze: MazeGenerator, player: PlayerController) -> Dictionary:
	if rescued:
		return {}
	rescued = true
	player.heal(RESCUE_HEAL)
	_carve(maze, [FAMILY, Vector2i(16, 4), CAMP], MazeGenerator.Terrain.ANCIENT_ROAD)
	maze.landmarks[Vector2i(16, 4)] = {"symbol": "归", "kind": "shortcut"}
	return {"title": "终于找到妈妈了", "body": "“你没事，太好了！孩子们往莫高窟那边去了。”\n妈妈帮你包扎，恢复 %d 点体力，并指出右侧通往营地的旧路。\n捷径已经打开。先一起到营地，再去找孩子们。" % RESCUE_HEAL, "button": "一起回营地"}

func objective() -> String:
	if rescued: return "与妈妈前往营地"
	if route_studied: return "石门到了 · 沿古道向北找妈妈" if gate_reached else "沿路书金线走到石门"
	return "沿足迹寻找妈妈"

func discovery_line() -> String:
	return Branches.discovery_line(self)

func fragment_mask() -> Array:
	return [fragments.has(1), fragments.has(2), fragments.has(3)]

func notebook_path(maze: MazeGenerator) -> Array[Vector2i]:
	# Stay on the existing southern ancient road; no new corridors or safer combat rules.
	var path: Array[Vector2i] = [MURAL]
	for target in [Vector2i(4, 6), Vector2i(1, 9), Vector2i(5, 11), Vector2i(9, 11), STONE_GATE]:
		var segment := PathGuide.bfs_path(maze, path[-1], target)
		for cell in segment:
			if cell != path[-1]: path.append(cell)
	return path

func study_route(maze: MazeGenerator) -> bool:
	if not mural_found or route_studied: return false
	route_studied = true
	for cell in notebook_path(maze): maze.charted_route[cell] = true
	maze.landmarks[STONE_GATE]["discovered"] = true
	return true

func _carve(maze: MazeGenerator, corners: Array, terrain: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [corners[0]]
	for i in range(1, corners.size()):
		var pos: Vector2i = corners[i - 1]
		var end: Vector2i = corners[i]
		assert(pos.x == end.x or pos.y == end.y)
		while pos != end:
			var dir := MazeGenerator.E if end.x > pos.x else MazeGenerator.W
			if pos.x == end.x: dir = MazeGenerator.S if end.y > pos.y else MazeGenerator.N
			var next := pos + Vector2i(MazeGenerator.DX[dir], MazeGenerator.DY[dir])
			maze.grid[pos.y][pos.x] |= dir
			maze.grid[next.y][next.x] |= MazeGenerator.OPPOSITE[dir]
			maze.terrain[pos.y][pos.x] = terrain
			maze.terrain[next.y][next.x] = terrain
			cells.append(next)
			pos = next
	return cells
