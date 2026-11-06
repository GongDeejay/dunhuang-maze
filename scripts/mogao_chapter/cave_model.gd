class_name CaveModel
extends RefCounted
## Authored, deterministic chapter. All positions are cells; rendering never decides collision.
const STEP_SECONDS := .18
const TURN_SECONDS := .7
var room := 0
var land: Dictionary = {}
var bridges: Array = []
var cranks: Array = []
var player := Vector2i.ZERO
var destination := Vector2i.ZERO
var goal := Vector2i.ZERO
var exit_cell := Vector2i.ZERO
var extent := Vector2(5, 7)
var busy := ""
var progress := 0.0
var turning := -1
var paused := false
var reached := false
var rescued := false
var scarf := false
var moves := 0
var turns := 0
var visits: Dictionary = {}
var box := Vector2i(-9, -9)
var box_destination := Vector2i(-9, -9)
const PLATES := [Vector2i(1, 3), Vector2i(3, 3), Vector2i(5, 3)]
const PLATE := Vector2i(3, 3) # Shared node, kept as the solution landmark.
const GATES := [Vector2i(3, 2), Vector2i(3, 1)]
const GATE := Vector2i(3, 2)
const DEER_SECONDS := 3.6
const STANDS := [Vector2i(1, 5), Vector2i(5, 5)]
const LIGHT_PATH := [Vector2i(5, 4), Vector2i(4, 4), Vector2i(4, 3), Vector2i(3, 3), Vector2i(3, 2)]
var lamp := Vector2i(3, 6)
var lamp_held := false
var lamp_destination := Vector2i.ZERO
var deer_seen := false
var deer_time := -1.0
var history: Array = []

func _init() -> void:
	load_room(0)

func fill(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x): land[Vector2i(x, y)] = true

func add_bridge(pivot: Vector2i, poses: Array, angle: float, crank_cells: Array) -> void:
	var index := bridges.size()
	bridges.append({"pivot": pivot, "poses": poses, "pose": 0, "angle": angle})
	for cell in crank_cells: cranks.append({"cell": cell, "bridge": index})

func load_room(index: int) -> void:
	room = clampi(index, 0, 2)
	scarf = room > 0; rescued = false
	land.clear(); bridges.clear(); cranks.clear(); visits.clear()
	history.clear(); box = Vector2i(-9, -9); lamp = Vector2i(3, 6); lamp_held = false; deer_seen = false; deer_time = -1
	busy = ""; progress = 0; turning = -1; paused = false; reached = false
	if room == 0:
		extent = Vector2(5, 7)
		fill(Rect2i(1, 0, 3, 2)); fill(Rect2i(1, 5, 3, 2))
		player = Vector2i(2, 6); goal = Vector2i(2, 0)
		add_bridge(Vector2i(2, 3), [[Vector2i.LEFT, Vector2i.RIGHT], [Vector2i.UP, Vector2i.DOWN]], PI / 2, [Vector2i(3, 5), Vector2i(3, 1)])
	elif room == 1:
		extent = Vector2(7, 7)
		fill(Rect2i(1, 3, 5, 4)); fill(Rect2i(2, 0, 3, 1))
		land[Vector2i(2, 2)] = true; land[Vector2i(4, 2)] = true
		player = Vector2i(3, 6); goal = Vector2i(3, 0); box = Vector2i(2, 4)
	else:
		extent = Vector2(7, 8)
		fill(Rect2i(1, 5, 5, 3)); fill(Rect2i(1, 0, 5, 2))
		player = Vector2i(3, 7); goal = Vector2i(3, 0)
		rescued = false
	exit_cell = Vector2i(5, 0) if room == 2 else goal
	destination = player
	box_destination = box
	visits[player] = true

func bridge_cells(index: int) -> Array:
	var b: Dictionary = bridges[index]
	var result: Array = [b.pivot]
	var length := 1 if room == 0 or room == 2 else 2
	for d in b.poses[b.pose]:
		for n in range(1, length + 1): result.append(b.pivot + d * n)
	return result

func walkable(cell: Vector2i) -> bool:
	if land.has(cell): return true
	if room == 1 and cell in GATES: return gate_open(GATES.find(cell))
	if room == 2 and lit() and cell in LIGHT_PATH: return true
	for i in bridges.size():
		if cell in bridge_cells(i): return true
	return false

func plate_active(index: int, actor: Vector2i = player) -> bool:
	return room == 1 and (box == PLATES[index] or actor == PLATES[index])

func gate_open(index: int = -1, actor: Vector2i = player) -> bool:
	if room != 1: return false
	if index < 0: return gate_open(0, actor) and gate_open(1, actor)
	return plate_active(1, actor) or plate_active(0 if index == 0 else 2, actor)

func bank_lit() -> bool:
	return room == 2 and not lamp_held and lamp == STANDS[1]

func lit() -> bool:
	return bank_lit() and deer_time >= DEER_SECONDS

func remember() -> void:
	history.append({"player": player, "box": box, "lamp": lamp, "held": lamp_held, "deer": deer_seen, "deer_time": deer_time, "rescued": rescued, "scarf": scarf, "reached": reached, "bridges": bridges.duplicate(true), "visits": visits.duplicate(), "moves": moves, "turns": turns})

func undo() -> bool:
	if paused or not busy.is_empty() or history.is_empty(): return false
	var s: Dictionary = history.pop_back()
	player = s.player; destination = player; box = s.box; box_destination = box
	lamp = s.lamp; lamp_held = s.held; deer_seen = s.deer; rescued = s.rescued
	deer_time = s.deer_time
	scarf = s.scarf; reached = s.reached; bridges = s.bridges; visits = s.visits
	moves = s.moves; turns = s.turns; progress = 0; turning = -1
	return true

func lamp_action() -> String:
	if room != 2 or paused or reached or not busy.is_empty() or not land.has(player): return ""
	if not lamp_held: return "pick" if distance(player, lamp) <= 1 else ""
	for stand in STANDS:
		if distance(player, stand) <= 1: return "place"
	return ""

func use_lamp() -> bool:
	var action := lamp_action()
	if action.is_empty(): return false
	remember()
	lamp_destination = Vector2i(-1, -1)
	if action == "place":
		for stand in STANDS:
			if distance(player, stand) <= 1: lamp_destination = stand
	busy = "lamp"; progress = 0
	return true

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func nearby_crank() -> int:
	if not land.has(player): return -1
	var best := -1
	var closest := 2
	for i in cranks.size():
		var d := distance(player, cranks[i].cell)
		if d < closest:
			closest = d; best = i
	return best

func can_turn(index: int = -1) -> bool:
	if paused or reached or not busy.is_empty() or not land.has(player): return false
	if index < 0: index = nearby_crank()
	return index >= 0 and index < cranks.size() and distance(player, cranks[index].cell) <= 1

func turn(index: int = -1) -> bool:
	if not can_turn(index): return false
	if index < 0: index = nearby_crank()
	remember()
	turning = cranks[index].bridge
	busy = "turn"; progress = 0
	return true

func step(direction: Vector2i) -> bool:
	if paused or reached or not busy.is_empty() or distance(direction, Vector2i.ZERO) != 1: return false
	if not walkable(player + direction): return false
	# Evaluate the destination's weight, so stepping off a plate cannot slip through
	# a closing door. No crushing, trapping, or frame-dependent bypasses.
	if room == 1 and player + direction in GATES and not gate_open(GATES.find(player + direction), player + direction): return false
	box_destination = box
	if room == 1 and player + direction == box:
		# A crate stays on the broad stone floor, never inside the gate or a void.
		if not land.has(box + direction): return false
		box_destination = box + direction
	remember()
	destination = player + direction
	busy = "step"; progress = 0
	return true

func advance(delta: float) -> void:
	if paused: return
	if bank_lit() and deer_time >= 0:
		deer_time = minf(DEER_SECONDS + .8, deer_time + maxf(delta, 0))
	if busy.is_empty(): return
	progress = minf(1, progress + maxf(delta, 0) / (STEP_SECONDS if busy == "step" else TURN_SECONDS))
	if progress < 1: return
	if busy == "turn":
		bridges[turning].pose = 1 - bridges[turning].pose
		turns += 1
	elif busy == "lamp":
		lamp_held = lamp_destination == Vector2i(-1, -1)
		if lamp_held and deer_time < DEER_SECONDS: deer_time = -1
		if not lamp_held:
			lamp = lamp_destination
			deer_seen = true
			if lamp == STANDS[1] and deer_time < DEER_SECONDS: deer_time = 0
	else:
		player = destination; box = box_destination; moves += 1; visits[player] = true
		if player == goal:
			if room == 2: rescued = true
			else:
				reached = true
				if room == 0: scarf = true
		if room == 2 and rescued and player == exit_cell: reached = true
	busy = ""

func next_room() -> bool:
	if not reached or room >= 2 or paused: return false
	load_room(room + 1)
	return true

func angle(index: int) -> float:
	var b: Dictionary = bridges[index]
	var start: float = b.angle * b.pose
	return lerpf(start, b.angle * (1 - b.pose), smoothstep(0, 1, progress)) if busy == "turn" and turning == index else start

func visual_player() -> Vector2:
	return Vector2(player).lerp(Vector2(destination), smoothstep(0, 1, progress)) if busy == "step" else Vector2(player)

func visual_box() -> Vector2:
	return Vector2(box).lerp(Vector2(box_destination), smoothstep(0, 1, progress)) if busy == "step" else Vector2(box)
