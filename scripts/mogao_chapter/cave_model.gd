class_name CaveModel
extends RefCounted
## Authored, deterministic chapter. All positions are cells; rendering never decides collision.
const MirrorBeam = preload("res://scripts/mogao_chapter/mirror_beam.gd")
const STEP_SECONDS := .18
const TURN_SECONDS := .7
const ORDER := [0, 1, 3, 4, 2] # Stable room ids also serve as version-compatible checkpoints.
const ROOMS := [0, 1, 2, 3, 4, 5, 7]
const MIRROR_ROOM := 7
const MIRROR_EXTENT := Vector2(7, 9)
const MIRROR_STATES := 4
const MIRROR_MAX_BOUNCES := 4
const MIRROR_LAMP := Vector2i(0, 7)
const MIRROR_LAMP_DIR := Vector2i.RIGHT
const MIRROR_LOTUS := Vector2i(3, 5)
const MIRROR_ENTRY := Vector2i(3, 8)
const MIRROR_GOAL := Vector2i(3, 0)
const MIRROR_MAP_CELL := Vector2i(3, 1)
const MIRROR_LIT_PATH: Array[Vector2i] = [Vector2i(3, 0)]
## 虚线只开在教学镜 T。A、B 可转，F 固定。朝向 0ne 1se 2sw 3nw。
const MIRROR_DEFS := [
	{"id": "T", "cell": Vector2i(5, 7), "rotatable": true, "teaching": true, "show_preview": true, "start_rot": 1, "solution_rot": 3},
	{"id": "A", "cell": Vector2i(5, 2), "rotatable": true, "teaching": false, "show_preview": false, "start_rot": 3, "solution_rot": 2},
	{"id": "F", "cell": Vector2i(1, 2), "rotatable": false, "teaching": false, "show_preview": false, "start_rot": 1, "solution_rot": 1},
	{"id": "B", "cell": Vector2i(1, 5), "rotatable": true, "teaching": false, "show_preview": false, "start_rot": 3, "solution_rot": 0},
]
var connected := false
const RELAY_PLATES := [Vector2i(3, 5), Vector2i(5, 2)]
const RELAY_GATES := [Vector2i(5, 4), Vector2i(3, 1)]
var latch := false
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
var mirror_rots := {}
var turning_mirror := ""
var back_flash := 0.0
var back_flash_cell := Vector2i(-1, -1)

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
	room = index if index in ROOMS else 0
	latch = false
	scarf = room > 0; rescued = false
	land.clear(); bridges.clear(); cranks.clear(); visits.clear()
	history.clear(); box = Vector2i(-9, -9); lamp = Vector2i(3, 6); lamp_held = false; deer_seen = false; deer_time = -1
	busy = ""; progress = 0; turning = -1; paused = false; reached = false
	_reset_mirror_rots()
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
	elif room == 3:
		extent = Vector2(7, 9)
		fill(Rect2i(1, 5, 5, 4)); fill(Rect2i(1, 2, 5, 2)); land[Vector2i(3, 0)] = true
		player = Vector2i(3, 8); goal = Vector2i(3, 0); box = Vector2i(2, 6)
	elif room == 4:
		extent = Vector2(7, 8)
		fill(Rect2i(1, 5, 5, 3)); fill(Rect2i(1, 0, 5, 2))
		player = Vector2i(3, 7); goal = Vector2i(3, 0)
		add_bridge(Vector2i(3, 3), [[Vector2i.LEFT, Vector2i.RIGHT], [Vector2i.UP, Vector2i.DOWN]], PI / 2, [Vector2i(5, 5), Vector2i(5, 1)])
	elif room == 5:
		extent = Vector2(7, 7)
		fill(Rect2i(1, 1, 5, 5))
		for cell in [Vector2i(0, 3), Vector2i(6, 3), Vector2i(3, 6), Vector2i(3, 0)]: land[cell] = true
		player = Vector2i(3, 5); goal = Vector2i(-9, -9)
	elif room == MIRROR_ROOM:
		extent = MIRROR_EXTENT
		for x in range(2, 7):
			land[Vector2i(x, 8)] = true
		for y in range(1, 8):
			land[Vector2i(6, y)] = true
		for x in range(0, 7):
			land[Vector2i(x, 1)] = true
		for y in range(2, 7):
			land[Vector2i(0, y)] = true
		player = MIRROR_ENTRY
		goal = MIRROR_GOAL
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
	var length := 1
	for d in b.poses[b.pose]:
		for n in range(1, length + 1): result.append(b.pivot + d * n)
	return result

func walkable(cell: Vector2i) -> bool:
	if room == MIRROR_ROOM:
		if _mirror_at(cell) != null or cell == MIRROR_LAMP or cell == MIRROR_LOTUS:
			return false
		if land.has(cell):
			return true
		if lotus_lit():
			for lit_cell in MIRROR_LIT_PATH:
				if lit_cell == cell:
					return true
		return false
	if land.has(cell): return true
	if room in [1, 3] and cell in gates(): return gate_open(gates().find(cell))
	if room == 2 and lit() and cell in LIGHT_PATH: return true
	for i in bridges.size():
		if cell in bridge_cells(i): return room != 4 or lit()
	return false

func gates() -> Array:
	return RELAY_GATES if room == 3 else GATES

func plates() -> Array:
	return RELAY_PLATES if room == 3 else PLATES

func stands() -> Array:
	return [STANDS[0]] if room == 4 else STANDS

func plate_active(index: int, actor: Vector2i = player) -> bool:
	return room in [1, 3] and (box == plates()[index] or actor == plates()[index])

func gate_open(index: int = -1, actor: Vector2i = player) -> bool:
	if room not in [1, 3]: return false
	if index < 0: return gate_open(0, actor) and gate_open(1, actor)
	if room == 3: return (latch or plate_active(0, actor)) if index == 0 else plate_active(1, actor)
	return plate_active(1, actor) or plate_active(0 if index == 0 else 2, actor)

func bank_lit() -> bool:
	return room == 2 and not lamp_held and lamp == STANDS[1]

func lit() -> bool:
	if room == 4: return not lamp_held and lamp == STANDS[0]
	return bank_lit() and deer_time >= DEER_SECONDS

func remember() -> void:
	history.append({"player": player, "box": box, "lamp": lamp, "held": lamp_held, "deer": deer_seen, "deer_time": deer_time, "rescued": rescued, "scarf": scarf, "reached": reached, "bridges": bridges.duplicate(true), "visits": visits.duplicate(), "moves": moves, "turns": turns, "mirror_rots": mirror_rots.duplicate(true)})
	history[-1]["latch"] = latch

func undo() -> bool:
	if paused or not busy.is_empty() or history.is_empty(): return false
	var s: Dictionary = history.pop_back()
	player = s.player; destination = player; box = s.box; box_destination = box
	lamp = s.lamp; lamp_held = s.held; deer_seen = s.deer; rescued = s.rescued
	deer_time = s.deer_time
	latch = s.latch
	if s.has("mirror_rots") and s["mirror_rots"] is Dictionary:
		mirror_rots = (s["mirror_rots"] as Dictionary).duplicate(true)
	elif s.has("mirror_rot"):
		_reset_mirror_rots()
		if bool(s.get("reached", reached)):
			mirror_rots = solution_rots()
	scarf = s.scarf; reached = s.reached; bridges = s.bridges; visits = s.visits
	moves = s.moves; turns = s.turns; progress = 0; turning = -1
	return true

func lamp_action() -> String:
	if room not in [2, 4] or paused or reached or not busy.is_empty() or not land.has(player): return ""
	if not lamp_held: return "pick" if distance(player, lamp) <= 1 else ""
	for stand in stands():
		if distance(player, stand) <= 1: return "place"
	return ""

func use_lamp() -> bool:
	var action := lamp_action()
	if action.is_empty(): return false
	remember()
	lamp_destination = Vector2i(-1, -1)
	if action == "place":
		for stand in stands():
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
	if paused or (reached and not connected) or not busy.is_empty() or distance(direction, Vector2i.ZERO) != 1: return false
	if not walkable(player + direction): return false
	# Evaluate the destination's weight, so stepping off a plate cannot slip through
	# a closing door. No crushing, trapping, or frame-dependent bypasses.
	if room in [1, 3] and player + direction in gates() and not gate_open(gates().find(player + direction), player + direction): return false
	box_destination = box
	if room in [1, 3] and player + direction == box:
		# Crates stay on stone, except the relay door after its latch is secured.
		if not land.has(box + direction) and not (room == 3 and latch and box + direction == RELAY_GATES[0]): return false
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
	elif busy == "mirror":
		if mirror_rots.has(turning_mirror):
			mirror_rots[turning_mirror] = posmod(int(mirror_rots[turning_mirror]) + 1, MIRROR_STATES)
		turns += 1
		_note_beam_stop()
	elif busy == "lamp":
		lamp_held = lamp_destination == Vector2i(-1, -1)
		if lamp_held and deer_time < DEER_SECONDS: deer_time = -1
		if not lamp_held:
			lamp = lamp_destination
			deer_seen = true
			if lamp == STANDS[1] and deer_time < DEER_SECONDS: deer_time = 0
	else:
		player = destination; box = box_destination; moves += 1; visits[player] = true
		if room == 3 and player == RELAY_GATES[0]: latch = true
		if player == goal:
			if room == 2: rescued = true
			else:
				reached = true
				if room == 0: scarf = true
		if room == 2 and rescued and player == exit_cell: reached = true
	busy = ""

func next_room() -> bool:
	if not reached or room == 2 or paused: return false
	load_room(ORDER[ORDER.find(room) + 1])
	return true

func angle(index: int) -> float:
	var b: Dictionary = bridges[index]
	var start: float = b.angle * b.pose
	return lerpf(start, b.angle * (1 - b.pose), smoothstep(0, 1, progress)) if busy == "turn" and turning == index else start

func visual_player() -> Vector2:
	return Vector2(player).lerp(Vector2(destination), smoothstep(0, 1, progress)) if busy == "step" else Vector2(player)

func visual_box() -> Vector2:
	return Vector2(box).lerp(Vector2(box_destination), smoothstep(0, 1, progress)) if busy == "step" else Vector2(box)

static func solution_rots() -> Dictionary:
	var rots := {}
	for mirror in MIRROR_DEFS:
		rots[str(mirror["id"])] = int(mirror["solution_rot"])
	return rots


## Clockwise turns from the authored opening to the authored solution. Opening facings live only in MIRROR_DEFS.
static func turns_from_start(id: String) -> int:
	for mirror in MIRROR_DEFS:
		if str(mirror["id"]) == id:
			return posmod(int(mirror["solution_rot"]) - int(mirror["start_rot"]), MIRROR_STATES)
	return 0


func _reset_mirror_rots() -> void:
	mirror_rots = {}
	for mirror in MIRROR_DEFS:
		mirror_rots[mirror["id"]] = int(mirror["start_rot"])


func _mirror_at(cell: Vector2i):
	for mirror in MIRROR_DEFS:
		if mirror["cell"] == cell:
			return mirror
	return null


func mirror_def(id: String) -> Dictionary:
	for mirror in MIRROR_DEFS:
		if mirror["id"] == id:
			return mirror
	return {}


func mirror_rot_of(id: String) -> int:
	return int(mirror_rots.get(id, mirror_def(id).get("start_rot", 0)))


func rotatable_neighbors() -> Array:
	var found: Array = []
	if not land.has(player):
		return found
	for mirror in MIRROR_DEFS:
		if bool(mirror["rotatable"]) and distance(player, mirror["cell"]) <= 1:
			found.append(mirror)
	return found


func mirror_cfg() -> Dictionary:
	var mirrors: Array = []
	for mirror in MIRROR_DEFS:
		mirrors.append({"id": mirror["id"], "cell": mirror["cell"], "rot": mirror_rot_of(mirror["id"])})
	return {
		"extent": extent,
		"lamp": MIRROR_LAMP,
		"dir": MIRROR_LAMP_DIR,
		"lotus": MIRROR_LOTUS,
		"bounces": MIRROR_MAX_BOUNCES,
		"mirrors": mirrors,
	}


func beam_trace() -> Dictionary:
	return MirrorBeam.trace(mirror_cfg(), 0, player)


func lotus_lit() -> bool:
	return room == MIRROR_ROOM and bool(beam_trace().get("hit", false))


func can_turn_mirror() -> bool:
	if room != MIRROR_ROOM or paused or reached or not busy.is_empty():
		return false
	return rotatable_neighbors().size() == 1


func turn_mirror() -> bool:
	if not can_turn_mirror():
		return false
	turning_mirror = rotatable_neighbors()[0]["id"]
	remember()
	busy = "mirror"
	progress = 0
	turning = -1
	return true


## Dashed preview. The trace inside preview_for never receives the player, so standing on the beam cannot hide it.
func mirror_previews() -> Array:
	var result: Array = []
	if room != MIRROR_ROOM or paused or reached or not busy.is_empty():
		return result
	for mirror in MIRROR_DEFS:
		if not MirrorBeam.preview_allowed(mirror):
			continue
		var spec: Dictionary = mirror.duplicate(true)
		spec["rot"] = mirror_rot_of(mirror["id"])
		var preview: Dictionary = MirrorBeam.preview_for(mirror_cfg(), spec)
		if preview.get("ok", false):
			result.append(preview)
	return result


func _note_beam_stop() -> void:
	var traced := MirrorBeam.trace(mirror_cfg(), 0, Vector2i(-999, -999))
	var kind := str(traced.get("stop_kind", ""))
	if kind == "back" or kind == "reverse":
		back_flash = 0.25
		back_flash_cell = traced.get("stop_cell", Vector2i(-1, -1))
