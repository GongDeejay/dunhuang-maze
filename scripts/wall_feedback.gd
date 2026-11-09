class_name WallFeedback
extends RefCounted
## A short shove into a blocked edge. Same edge ignores repeats inside the cooldown.

const OFFSET_PX := 3.0
const OUT_SECONDS := 0.06
const BACK_SECONDS := 0.06
const COOLDOWN_SECONDS := 0.25


static func wall_key(cell: Vector2i, dir: int) -> String:
	return "%d,%d,%d" % [cell.x, cell.y, dir]


static func allow(hurt: bool, previous_key: String, previous_at: float, key: String, now: float) -> bool:
	if hurt:
		return false
	if previous_key == key and now - previous_at < COOLDOWN_SECONDS:
		return false
	return true


static func offset(dir: int) -> Vector2:
	return Vector2(MazeGenerator.DX[dir], MazeGenerator.DY[dir]) * OFFSET_PX
