class_name ThirdMap
extends RefCounted
## Authored floor plan. A cell is four metres; movement itself is continuous.
const CELL := 4.0
const START := Vector2i(3, 13)
const FORK := Vector2i(3, 8)
const RELIC := Vector2i(6, 5)
const CHILD := Vector2i(13, 2)
const CAMP := Vector2i(14, 13)
const GATE := Vector2i(13, 6)
const SCORPION := Vector2i(9, 6)
var floor_cells: Dictionary = {}

func _init() -> void:
	_room(Rect2i(1, 11, 5, 4))
	_room(Rect2i(2, 8, 2, 4))
	_room(Rect2i(1, 7, 5, 3))
	# Left: sheltered stone road. Right: shorter, wind and a single encounter.
	_room(Rect2i(1, 3, 2, 5))
	_room(Rect2i(1, 2, 9, 2))
	_room(Rect2i(5, 8, 5, 1))
	_room(Rect2i(9, 3, 1, 6))
	# Optional grotto, a cul-de-sac with a discoverable keepsake.
	_room(Rect2i(2, 4, 5, 2))
	_room(Rect2i(8, 1, 4, 4))
	_room(Rect2i(11, 2, 3, 2))
	_room(Rect2i(12, 1, 3, 4))
	# Rescue opens the return passage; this is not an escort/pathfinding quest.
	_room(Rect2i(13, 4, 1, 9))
	_room(Rect2i(12, 11, 4, 4))

func _room(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x): floor_cells[Vector2i(x, y)] = true

static func world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0, cell.y * CELL)

static func cell_at(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / CELL), roundi(pos.z / CELL))

func can_enter(cell: Vector2i, rescued: bool) -> bool:
	return floor_cells.has(cell) and (cell != GATE or rescued)

func is_windy(pos: Vector3) -> bool:
	var cell := cell_at(pos)
	return cell.x >= 6 and cell.x <= 8 and cell.y == 8

func zone(pos: Vector3) -> String:
	if pos.z > 40: return "落日沙谷" if pos.x < 35 else "营地灯火"
	if pos.z < 19: return "风蚀石窟"
	return "山口余光"
