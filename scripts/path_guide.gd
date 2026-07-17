class_name PathGuide
extends RefCounted

static func nearest_target(maze: MazeGenerator, from: Vector2i, items: Array, exit_pos: Vector2i, keys_collected: int, keys_total: int) -> Vector2i:
	if keys_collected >= keys_total:
		return exit_pos
	var best_pos := Vector2i(-1, -1)
	var best_len := 999999
	for it in items:
		if not is_instance_valid(it) or it.item_type != "key":
			continue
		var path_len := bfs_path(maze, from, it.pos).size()
		if path_len >= 2 and path_len < best_len:
			best_len = path_len
			best_pos = it.pos
	if best_pos != Vector2i(-1, -1):
		return best_pos
	return exit_pos

static func bfs_path(maze: MazeGenerator, from: Vector2i, to: Vector2i) -> Array:
	if from == to:
		return [from]
	var queue: Array = [from]
	var parent: Dictionary = {from: from}
	var found := false
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == to:
			found = true
			break
		for dir in [MazeGenerator.N, MazeGenerator.S, MazeGenerator.E, MazeGenerator.W]:
			if not maze.can_move(cur.x, cur.y, dir):
				continue
			var nxt := Vector2i(cur.x + MazeGenerator.DX[dir], cur.y + MazeGenerator.DY[dir])
			if parent.has(nxt):
				continue
			parent[nxt] = cur
			queue.append(nxt)
	if not found:
		return []
	var path: Array = []
	var step: Vector2i = to
	while step != from:
		path.push_front(step)
		step = parent[step]
	path.push_front(from)
	return path

static func next_direction(maze: MazeGenerator, from: Vector2i, to: Vector2i) -> int:
	var path: Array = bfs_path(maze, from, to)
	if path.size() < 2:
		return -1
	var delta: Vector2i = path[1] - path[0]
	for dir in [MazeGenerator.N, MazeGenerator.S, MazeGenerator.E, MazeGenerator.W]:
		if MazeGenerator.DX[dir] == delta.x and MazeGenerator.DY[dir] == delta.y:
			return dir
	return -1
