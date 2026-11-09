class_name CaveNetwork
extends CaveModel
## Room graph and JSON-safe settled snapshots. Never serialize an animation or undo history.
var rooms: Dictionary = {}
var shortcut := false
var secret := false
var arrival := ""
var entry := Vector2i(2, 6)
const NAMES := {
	0: "入窟",
	1: "共耳窟",
	2: "鹿影窟",
	3: "栈道窟",
	4: "灯窟",
	5: "中央窟",
	7: "镜窟",
}

func _init() -> void:
	connected = true
	load_room(0)

func solved(id: int) -> bool:
	return reached if id == room else bool(rooms.get(str(id), {}).get("reached", false))

func door(cell: Vector2i, target: int, spawn: Vector2i, label: String, open: bool = true) -> Dictionary:
	return {"cell": cell, "target": target, "spawn": spawn, "label": label, "open": open}

func doors() -> Array:
	match room:
		0: return [door(goal, 5, Vector2i(3, 5), "中央窟", reached)]
		5: return [door(Vector2i(3, 6), 0, Vector2i(2, 0), "入窟"), door(Vector2i(0, 3), 1, Vector2i(3, 6), "共耳窟"), door(Vector2i(6, 3), 4, Vector2i(3, 7), "灯窟"), door(Vector2i(3, 0), 3, Vector2i(1, 2), "栈道捷径", shortcut)]
		1: return [door(Vector2i(3, 6), 5, Vector2i(0, 3), "中央窟"), door(goal, 3, Vector2i(3, 8), "栈道窟", reached)]
		3: return [door(Vector2i(3, 8), 1, Vector2i(3, 0), "共耳窟"), door(goal, 2, Vector2i(1, 7), "鹿影窟", reached), door(Vector2i(1, 2), 5, Vector2i(3, 0), "栈道捷径", reached)]
		4: return [door(Vector2i(3, 7), 5, Vector2i(6, 3), "中央窟"), door(goal, 7, Vector2i(4, 8), "镜窟", reached)]
		7: return [door(Vector2i(3, 8), 4, Vector2i(3, 0), "灯窟"), door(goal, 2, Vector2i(5, 7), "鹿影窟", reached)]
		2: return [door(Vector2i(1, 7), 3, Vector2i(3, 0), "栈道窟", solved(3)), door(Vector2i(5, 7), 7, Vector2i(3, 0), "镜窟", solved(7))]
	return []

func current_door() -> Dictionary:
	for d in doors():
		if player == d.cell: return d
	return {}

func at_secret() -> bool:
	return room == 5 and player == Vector2i(3, 2)

func reveal_secret() -> bool:
	if not at_secret() or paused or not busy.is_empty(): return false
	secret = true
	return true

func travel() -> bool:
	var d := current_door()
	if d.is_empty() or not d.open or paused or not busy.is_empty(): return false
	remember_room()
	arrival = ""
	if room == 3 and d.target == 5 and not shortcut:
		shortcut = true
		arrival = "原来绕回中央窟！捷径已开"
	var target: int = d.target
	var spawn: Vector2i = d.spawn
	load_room(target)
	if rooms.has(str(target)): restore_room(rooms[str(target)])
	player = spawn; destination = spawn; entry = spawn
	visits[player] = true
	remember_room()
	return true

func next_room() -> bool:
	return travel()

func step(direction: Vector2i) -> bool:
	# A crate may not obstruct a room transition, including an unsolved room's retreat.
	if room == 1 and player + direction == box:
		if reached: return false
		for d in doors():
			if box + direction == d.cell: return false
	return super.step(direction)

func undo() -> bool:
	# Completed rooms become stable traversal spaces, not puzzles to re-solve.
	if reached or rescued: return false
	return super.undo()

func lamp_action() -> String:
	if rescued: return ""
	return super.lamp_action()

func remember_room() -> void:
	if not busy.is_empty(): return
	var poses: Array = []
	for b in bridges: poses.append(b.pose)
	var ups: Array = []
	for cell in planks_up.keys():
		ups.append([cell.x, cell.y])
	rooms[str(room)] = {"player": [player.x, player.y], "box": [box.x, box.y], "lamp": [lamp.x, lamp.y], "held": lamp_held, "deer": deer_seen, "deer_time": deer_time, "rescued": rescued, "reached": reached, "scarf": scarf, "planks_up": ups, "poses": poses, "moves": moves, "turns": turns, "mirror_rots": mirror_rots.duplicate(true)}

func restore_room(s: Dictionary) -> void:
	player = cell_value(s.get("player"), player)
	box = cell_value(s.get("box"), box)
	lamp = cell_value(s.get("lamp"), lamp)
	lamp_held = bool(s.get("held", false)); deer_seen = bool(s.get("deer", false))
	deer_time = clampf(float(s.get("deer_time", -1)), -1, DEER_SECONDS + .8)
	rescued = bool(s.get("rescued", false)); reached = bool(s.get("reached", false))
	scarf = bool(s.get("scarf", room > 0))
	if room == 3:
		# Old borrowed-corridor saves stored a crate and a latch. Both are ignored.
		box = Vector2i(-9, -9)
		planks_up.clear()
		if not reached:
			var ups = s.get("planks_up", [])
			if ups is Array:
				for item in ups:
					var cell := cell_value(item, Vector2i(-99, -99))
					if _plank_like(cell):
						planks_up[cell] = true
	var poses = s.get("poses", [])
	if poses is Array:
		for i in mini(poses.size(), bridges.size()): bridges[i].pose = clampi(int(poses[i]), 0, 1)
	moves = maxi(0, int(s.get("moves", 0))); turns = maxi(0, int(s.get("turns", 0)))
	if room == MIRROR_ROOM:
		if s.has("mirror_rots") and s["mirror_rots"] is Dictionary:
			mirror_rots = (s["mirror_rots"] as Dictionary).duplicate(true)
		elif s.has("mirror_rot"):
			_reset_mirror_rots()
			if bool(s.get("reached", false)):
				mirror_rots = solution_rots()
	if not walkable(player) or player == box: player = entry
	if room == 3 and not walkable(player): player = PLANK_ENTRY
	destination = player; box_destination = box
	history.clear()

static func cell_value(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array and value.size() == 2 and (value[0] is float or value[0] is int) and (value[1] is float or value[1] is int):
		return Vector2i(int(value[0]), int(value[1]))
	return fallback

func save_network() -> Dictionary:
	remember_room()
	return {"version": 4, "rooms": rooms.duplicate(true), "shortcut": shortcut, "secret": secret, "entry": [entry.x, entry.y]}

func resume_network(id: int, data: Dictionary) -> void:
	load_room(id); entry = player
	rooms.clear(); shortcut = false; secret = false
	var version := int(data.get("version", 0))
	if version < 1 or version > 4 or not data.get("rooms", {}) is Dictionary:
		migrate_linear_save(room)
		return
	var saved_rooms: Dictionary = data.get("rooms", {})
	for key in saved_rooms:
		if str(key).is_valid_int() and int(key) in ROOMS and saved_rooms[key] is Dictionary: rooms[str(key)] = saved_rooms[key].duplicate(true)
	shortcut = bool(data.get("shortcut", false)); secret = bool(data.get("secret", false))
	entry = cell_value(data.get("entry"), entry)
	if rooms.has(str(room)): restore_room(rooms[str(room)])

func migrate_linear_save(id: int) -> void:
	# Old saves only identify the next room in the five-room linear sequence.
	# Rebuild already-cleared rooms before enabling travel back into their far bank.
	var index := ORDER.find(id)
	for i in maxi(0, index):
		load_room(ORDER[i])
		reached = true; scarf = true
		player = goal; destination = player
		for b in bridges: b.pose = 1
		if room == 1: box = PLATE
		if room == 3: box = Vector2i(-9, -9); planks_up.clear()
		if room == 4: lamp = STANDS[0]; deer_seen = true
		remember_room()
	load_room(id); entry = player

func reset_current() -> bool:
	if reached or rescued or room == 5: return false
	var start := entry
	load_room(room); player = start; destination = start
	remember_room()
	return true

func map_note() -> String:
	var text := "洞窟相连，左右任一路都能找到哥哥。\n\n入窟 ↔ 中央窟\n左路：中央 ↔ 共耳 ↔ 栈道 ↔ 鹿影\n右路：中央 ↔ 灯窟 ↔ 镜窟 ↔ 鹿影\n栈道捷径：" + ("已通" if shortcut else "从栈道窟西侧开启") + "\n\n"
	for id in [0, 5, 1, 3, 4, 7, 2]:
		text += ("● " if id == room else "○ ") + NAMES[id] + (" · 当前" if id == room else (" · 已通" if solved(id) else (" · 来过" if rooms.has(str(id)) else " · 未探索"))) + "\n"
	return text + ("\n手记里多了一张小兔合影。" if secret else "\n中央窟有三条铜线，汇向同一个小节点。")
