class_name MirrorBeam
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


static func exit_dir(rot: int) -> Vector2i:
	return reflect(_entry_dir(rot), rot)


static func stop_kind(incoming: Vector2i, rot: int) -> String:
	if reflect(incoming, rot) != Vector2i.ZERO:
		return "pass"
	if incoming == -exit_dir(rot):
		return "reverse"
	return "back"


static func preview_allowed(mirror: Dictionary) -> bool:
	return bool(mirror.get("rotatable", false)) and bool(mirror.get("show_preview", false))


static func trace(cfg: Dictionary, _rot: int = 0, blocker: Vector2i = Vector2i(-999, -999)) -> Dictionary:
	var extent: Vector2 = cfg["extent"]
	var dir: Vector2i = cfg["dir"]
	var pos: Vector2i = cfg["lamp"]
	var cells: Array[Vector2i] = [pos]
	var hit_mirrors: Array[Vector2i] = []
	var hit := false
	var bounces := 0
	var stop_kind_name := "edge"
	var stop_cell := pos
	var max_bounces := int(cfg["bounces"])
	for _step in 32:
		var nxt := pos + dir
		if nxt.x < 0 or nxt.y < 0 or float(nxt.x) >= extent.x or float(nxt.y) >= extent.y:
			stop_kind_name = "edge"
			stop_cell = pos
			break
		if blocker.x > -100 and nxt == blocker:
			cells.append(nxt)
			stop_kind_name = "block"
			stop_cell = nxt
			break
		cells.append(nxt)
		pos = nxt
		if pos == cfg["lotus"]:
			hit = true
			stop_kind_name = "lotus"
			stop_cell = pos
			break
		var mirror_rot := _rot_at(cfg, pos)
		if mirror_rot >= 0:
			hit_mirrors.append(pos)
			var kind := stop_kind(dir, mirror_rot)
			if kind != "pass":
				stop_kind_name = kind
				stop_cell = pos
				break
			bounces += 1
			if bounces > max_bounces:
				stop_kind_name = "edge"
				stop_cell = pos
				break
			dir = reflect(dir, mirror_rot)
	return {"cells": cells, "hit": hit, "mirrors": hit_mirrors, "stop_kind": stop_kind_name, "stop_cell": stop_cell}


static func preview_for(cfg: Dictionary, mirror: Dictionary) -> Dictionary:
	var empty := {"ok": false}
	if not preview_allowed(mirror):
		return empty
	var cell: Vector2i = mirror["cell"]
	var traced := trace(cfg, 0, Vector2i(-999, -999))
	var cells: Array = traced["cells"]
	var idx := -1
	for i in cells.size():
		if cells[i] == cell:
			idx = i
			break
	if idx <= 0:
		return empty
	if traced["stop_cell"] != cell or str(traced["stop_kind"]) not in ["back", "reverse"]:
		return empty
	var incoming: Vector2i = cells[idx] - cells[idx - 1]
	var rot := int(mirror["rot"])
	var turns := 0
	var out := Vector2i.ZERO
	for k in range(1, 4):
		var trial := reflect(incoming, rot + k)
		if trial != Vector2i.ZERO:
			turns = k
			out = trial
			break
	if turns == 0:
		return empty
	var end := cell
	var extent: Vector2 = cfg["extent"]
	for _step in 12:
		var nxt := end + out
		if nxt.x < 0 or nxt.y < 0 or float(nxt.x) >= extent.x or float(nxt.y) >= extent.y:
			break
		if _rot_at(cfg, nxt) >= 0 or nxt == cfg["lotus"]:
			end = nxt
			break
		end = nxt
	return {"ok": true, "from": cell, "to": end, "id": mirror["id"], "k": turns, "dir": out}


static func _entry_dir(rot: int) -> Vector2i:
	match posmod(rot, 4):
		0:
			return Vector2i.DOWN
		1:
			return Vector2i.LEFT
		2:
			return Vector2i.UP
		_:
			return Vector2i.RIGHT


static func _rot_at(cfg: Dictionary, cell: Vector2i) -> int:
	for mirror in cfg.get("mirrors", []):
		if mirror["cell"] == cell:
			return int(mirror["rot"])
	return -1
