extends RefCounted
## Single-faced copper mirrors. Only the arrow's incident direction reflects.
## ne 北来东出, se 东来南出, sw 南来西出, nw 西来北出. Anything else stops the beam.

const FACINGS := ["ne", "se", "sw", "nw"]


static func facing(rot: int) -> String:
	return FACINGS[posmod(rot, 4)]


static func sprite_key(rot: int, lit: bool) -> String:
	return "mirror_" + facing(rot) + ("_lit" if lit else "")


static func reflect(incoming: Vector2i, rot: int) -> Vector2i:
	match posmod(rot, 4):
		0:
			if incoming == Vector2i.DOWN:
				return Vector2i.RIGHT
		1:
			if incoming == Vector2i.LEFT:
				return Vector2i.DOWN
		2:
			if incoming == Vector2i.UP:
				return Vector2i.LEFT
		3:
			if incoming == Vector2i.RIGHT:
				return Vector2i.UP
	return Vector2i.ZERO


static func preview_allowed(mirror: Dictionary) -> bool:
	return bool(mirror.get("rotatable", false)) and bool(mirror.get("show_preview", false))


static func trace(cfg: Dictionary, rot: int, blocker: Vector2i) -> Dictionary:
	var extent: Vector2 = cfg["extent"]
	var dir: Vector2i = cfg["dir"]
	var pos: Vector2i = cfg["lamp"]
	var cells: Array[Vector2i] = [pos]
	var hit_mirrors: Array[Vector2i] = []
	var bounces := 0
	var hit := false
	var max_bounces := int(cfg["bounces"])
	for _step in 24:
		var nxt := pos + dir
		if nxt.x < 0 or nxt.y < 0 or float(nxt.x) >= extent.x or float(nxt.y) >= extent.y:
			break
		if nxt == blocker:
			cells.append(nxt)
			break
		cells.append(nxt)
		pos = nxt
		if pos == cfg["lotus"]:
			hit = true
			break
		var mirror_rot := _rot_at(cfg, pos, rot)
		if mirror_rot >= 0:
			hit_mirrors.append(pos)
			var out := reflect(dir, mirror_rot)
			if out == Vector2i.ZERO:
				break
			bounces += 1
			if bounces > max_bounces:
				break
			dir = out
	return {"cells": cells, "hit": hit, "mirrors": hit_mirrors}


static func preview_cell(cfg: Dictionary, rot: int, blocker: Vector2i, mirror_cell: Vector2i) -> Vector2i:
	var traced := trace(cfg, rot, blocker)
	var cells: Array = traced["cells"]
	var idx := -1
	for i in cells.size():
		if cells[i] == mirror_cell:
			idx = i
			break
	if idx <= 0:
		return Vector2i(-99, -99)
	var incoming: Vector2i = cells[idx] - cells[idx - 1]
	var out := reflect(incoming, rot + 1)
	if out == Vector2i.ZERO:
		return Vector2i(-99, -99)
	var nxt := mirror_cell + out
	var extent: Vector2 = cfg["extent"]
	if nxt.x < 0 or nxt.y < 0 or float(nxt.x) >= extent.x or float(nxt.y) >= extent.y:
		return Vector2i(-99, -99)
	return nxt


static func _rot_at(cfg: Dictionary, cell: Vector2i, turn_rot: int) -> int:
	if cell == cfg["fixed"]:
		return int(cfg["fixed_rot"])
	if cell == cfg["turn"]:
		return turn_rot
	return -1
