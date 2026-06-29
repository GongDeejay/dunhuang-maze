class_name MazeGenerator

const N = 1
const S = 2
const E = 4
const W = 8
const DX = {E: 1, W: -1, N: 0, S: 0}
const DY = {N: -1, S: 1, E: 0, W: 0}
const OPPOSITE = {N: S, S: N, E: W, W: E}

enum Terrain { SAND, DESERT, GROTTO, OASIS, ANCIENT_ROAD }

const TERRAIN_KEY = {
	Terrain.SAND: "sand",
	Terrain.DESERT: "desert",
	Terrain.GROTTO: "grotto",
	Terrain.OASIS: "oasis",
	Terrain.ANCIENT_ROAD: "ancient_road",
}

const TERRAIN_NAMES = {
	Terrain.SAND: "沙地",
	Terrain.DESERT: "荒漠",
	Terrain.GROTTO: "石窟",
	Terrain.OASIS: "绿洲",
	Terrain.ANCIENT_ROAD: "古道",
}

var width: int
var height: int
var grid: Array = []
var terrain: Array = []
var waypoints: Array = []

func _init(w: int, h: int):
	width = w
	height = h

func generate(seed_val: int = -1, waypoint_count: int = 3) -> Array:
	if seed_val >= 0:
		seed(seed_val)
	_init_grid()
	_generate_waypoints(waypoint_count)
	_build_main_path()
	_add_branches()
	_add_random_loops()
	_remove_enclosed_cells()
	_ensure_start_exit_open()
	_generate_terrain()
	return grid

func _init_grid():
	grid.clear()
	terrain.clear()
	for y in height:
		var row: Array = []
		var trow: Array = []
		for x in width:
			row.append(0)
			trow.append(Terrain.SAND)
		grid.append(row)
		terrain.append(trow)

func _generate_waypoints(count: int):
	waypoints.clear()
	waypoints.append(Vector2i(0, 0))
	waypoints.append(Vector2i(width - 1, height - 1))

	var zones: Array = []
	var zone_w: int = maxi(width / 3, 3)
	var zone_h: int = maxi(height / 3, 3)
	for zy in range(0, height, zone_h):
		for zx in range(0, width, zone_w):
			var zone_start = Vector2i(zx + 1, zy + 1)
			var zone_end = Vector2i(mini(zx + zone_w - 2, width - 2), mini(zy + zone_h - 2, height - 2))
			if zone_start.x < zone_end.x and zone_start.y < zone_end.y:
				zones.append([zone_start, zone_end])

	zones.shuffle()
	for i in mini(count, zones.size()):
		var zone = zones[i]
		var wp = Vector2i(
			randi_range(zone[0].x, zone[1].x),
			randi_range(zone[0].y, zone[1].y)
		)
		if not waypoints.has(wp):
			waypoints.append(wp)

func _build_main_path():
	for i in range(waypoints.size() - 1):
		var from_wp = waypoints[i]
		var to_wp = waypoints[i + 1]
		_connect_points(from_wp, to_wp)

func _connect_points(from: Vector2i, to: Vector2i):
	var cx: int = from.x
	var cy: int = from.y
	var tx: int = to.x
	var ty: int = to.y
	var step_count: int = 0

	while cx != tx or cy != ty:
		step_count += 1
		var possible_dirs: Array = []

		var dx: int = tx - cx
		var dy: int = ty - cy

		if dx != 0:
			possible_dirs.append(E if dx > 0 else W)
		if dy != 0:
			possible_dirs.append(S if dy > 0 else N)

		var perp_chance: float = 0.5 if step_count < 3 else 0.35
		if randf() < perp_chance:
			var perp_dirs: Array = []
			if absi(dx) > absi(dy):
				if cy > 0:
					perp_dirs.append(N)
				if cy < height - 1:
					perp_dirs.append(S)
			else:
				if cx > 0:
					perp_dirs.append(W)
				if cx < width - 1:
					perp_dirs.append(E)
			if not perp_dirs.is_empty():
				possible_dirs.append(perp_dirs[randi() % perp_dirs.size()])

		possible_dirs.shuffle()
		var moved = false
		for dir in possible_dirs:
			var nx: int = cx + DX[dir]
			var ny: int = cy + DY[dir]
			if _in_bounds(nx, ny):
				grid[cy][cx] |= dir
				grid[ny][nx] |= OPPOSITE[dir]
				cx = nx
				cy = ny
				moved = true
				break

		if not moved:
			break

func _add_branches():
	for y in height:
		for x in width:
			if randf() > 0.15:
				continue
			var cell_val: int = grid[y][x]
			var dirs: Array = [N, S, E, W]
			dirs.shuffle()

			for dir in dirs:
				if cell_val & dir:
					continue

				var nx: int = x + DX[dir]
				var ny: int = y + DY[dir]
				if not _in_bounds(nx, ny):
					continue
				if grid[ny][nx] != 0:
					continue

				grid[y][x] |= dir
				grid[ny][nx] |= OPPOSITE[dir]

				var bx: int = nx
				var by: int = ny
				var branch_len: int = randi_range(3, 6)
				var prev_dir: int = OPPOSITE[dir]

				for _step in branch_len:
					var next_dirs: Array = []
					for d in [N, S, E, W]:
						if d == prev_dir:
							continue
						var nnx: int = bx + DX[d]
						var nny: int = by + DY[d]
						if _in_bounds(nnx, nny) and grid[nny][nnx] == 0:
							next_dirs.append(d)
					if next_dirs.is_empty():
						break
					next_dirs.shuffle()
					var nd: int = next_dirs[0]
					var nnx: int = bx + DX[nd]
					var nny: int = by + DY[nd]
					grid[by][bx] |= nd
					grid[nny][nnx] |= OPPOSITE[nd]
					prev_dir = OPPOSITE[nd]
					bx = nnx
					by = nny

				break

func _add_random_loops():
	var candidates: Array = []
	for y in height:
		for x in width:
			if x < width - 1 and (grid[y][x] & E) == 0:
				candidates.append(Vector3i(x, y, E))
			if y < height - 1 and (grid[y][x] & S) == 0:
				candidates.append(Vector3i(x, y, S))
	candidates.shuffle()
	var count: int = int(candidates.size() * 0.12)
	for i in count:
		var c: Vector3i = candidates[i]
		var a: Vector2i = Vector2i(int(c.x), int(c.y))
		var dir: int = int(c.z)
		var b: Vector2i = a + Vector2i(DX[dir], DY[dir])
		if _in_bounds(b.x, b.y):
			grid[a.y][a.x] |= dir
			grid[b.y][b.x] |= OPPOSITE[dir]

func _count_openings(x: int, y: int) -> int:
	var count: int = 0
	for d in [N, S, E, W]:
		if grid[y][x] & d:
			count += 1
	return count

func _remove_enclosed_cells():
	for y in height:
		for x in width:
			if _count_openings(x, y) == 0:
				_ensure_cell_open(Vector2i(x, y))

func _ensure_start_exit_open():
	_ensure_cell_open(Vector2i(0, 0))
	_ensure_cell_open(Vector2i(width - 1, height - 1))

func _ensure_cell_open(cell: Vector2i):
	var attempts: int = 0
	while _count_openings(cell.x, cell.y) < 2 and attempts < 20:
		attempts += 1
		var options: Array = []
		for d in [N, S, E, W]:
			if grid[cell.y][cell.x] & d:
				continue
			var nb: Vector2i = cell + Vector2i(DX[d], DY[d])
			if _in_bounds(nb.x, nb.y):
				options.append(d)
		if options.is_empty():
			break
		options.shuffle()
		var d: int = options[0]
		var nb: Vector2i = cell + Vector2i(DX[d], DY[d])
		grid[cell.y][cell.x] |= d
		grid[nb.y][nb.x] |= OPPOSITE[d]

func _generate_terrain():
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.12
	noise.seed = randi()

	var noise2 := FastNoiseLite.new()
	noise2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise2.frequency = 0.20
	noise2.seed = randi()

	var centers: Array = []
	for i in 5:
		centers.append(Vector2(randf_range(0, width - 1), randf_range(0, height - 1)))

	for y in height:
		for x in width:
			var n1: float = noise.get_noise_2d(x, y)
			var n2: float = noise2.get_noise_2d(x, y)
			var min_dist: float = 999.0
			for c in centers:
				var d: float = Vector2(x, y).distance_to(c)
				if d < min_dist:
					min_dist = d
			if n1 > 0.3 and min_dist < 5.0:
				terrain[y][x] = Terrain.GROTTO
			elif n1 < -0.3 and n2 > 0.1:
				terrain[y][x] = Terrain.DESERT
			elif n2 < -0.4:
				terrain[y][x] = Terrain.OASIS
			elif min_dist < 3.0 and n1 > 0.0:
				terrain[y][x] = Terrain.ANCIENT_ROAD
			else:
				terrain[y][x] = Terrain.SAND

	terrain[0][0] = Terrain.ANCIENT_ROAD
	terrain[height - 1][width - 1] = Terrain.OASIS

func get_terrain(cx: int, cy: int) -> int:
	if _in_bounds(cx, cy):
		return terrain[cy][cx]
	return Terrain.SAND

func get_terrain_name(cx: int, cy: int) -> String:
	return TERRAIN_NAMES[get_terrain(cx, cy)]

func has_wall(cx: int, cy: int, dir: int) -> bool:
	if not _in_bounds(cx, cy):
		return true
	return (grid[cy][cx] & dir) == 0

func can_move(cx: int, cy: int, dir: int) -> bool:
	return not has_wall(cx, cy, dir)

func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height

func get_reachable_cells() -> Dictionary:
	var reachable: Dictionary = {}
	var queue: Array = [Vector2i(0, 0)]
	reachable[Vector2i(0, 0)] = true

	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		for d in [N, S, E, W]:
			if can_move(current.x, current.y, d):
				var next: Vector2i = current + Vector2i(DX[d], DY[d])
				if _in_bounds(next.x, next.y) and not reachable.has(next):
					reachable[next] = true
					queue.append(next)

	return reachable
