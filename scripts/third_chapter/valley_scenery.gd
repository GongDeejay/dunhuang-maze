class_name ValleyScenery
extends Node3D
## Render-only sandstone dressing. Never adds a collision or edits the authored floor plan.
var chunks: Dictionary = {}
var triangle_count := 0
var wall_count := 0
var material: ShaderMaterial

static func contains(cell: Vector2i) -> bool:
	return cell.x <= 6 and cell.y >= 4

static func dresses_wall(cell: Vector2i, direction: Vector2i) -> bool:
	# The north ridge is the backdrop seen from the clue; its walkable floor is untouched.
	return contains(cell) or (cell.x <= 6 and cell.y == 2 and direction == Vector2i.UP) or (cell.x >= 7 and cell.y <= 4) or cell.x >= 12

static func shelter(pos: Vector3) -> float:
	# A sheltered left-hand bend, then a sunlit pocket around the travel note.
	var west := 1.0 - smoothstep(9.0, 15.0, pos.x)
	var bend := smoothstep(17.0, 22.0, pos.z) * (1.0 - smoothstep(27.0, 35.0, pos.z))
	return west * bend

func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = preload("res://scripts/third_chapter/sandstone.gdshader")

func _builder(pos: Vector3) -> SurfaceTool:
	var key := Vector2i(floori(pos.x / 16), floori(pos.z / 16))
	if not chunks.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		chunks[key] = tool
	return chunks[key]

func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	# Godot front faces use clockwise winding; retain the outward-facing normal.
	for vertex in [a, c, b]:
		tool.set_color(color)
		tool.set_normal(normal)
		tool.add_vertex(vertex)
	triangle_count += 1

func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_tri(tool, a, b, c, color)
	_tri(tool, a, c, d, color)

func wall(cell: Vector2i, direction: Vector2i, map: ThirdMap) -> void:
	wall_count += 1
	var outward := Vector3(direction.x, 0, direction.y)
	var tangent := Vector3(-direction.y, 0, direction.x)
	# Front edge coincides with the old box's inner face; all thickness grows OUTSIDE.
	var origin := ThirdMap.world(cell) + outward * (ThirdMap.CELL / 2.0 - 0.325)
	var tool := _builder(origin)
	var rng := RandomNumberGenerator.new()
	rng.seed = cell.x * 733 + cell.y * 31 + direction.x * 17 + direction.y * 7
	var top := 1.5 if cell.y >= 11 else 4.9
	var xs: Array[float] = [-2.0, -0.8, 0.65, 2.0]
	if contains(cell): xs = [-2.0, -1.35, -.7, 0.0, .65, 1.3, 2.0]
	var peaks: Array[float] = []
	# Shared world-space heights join neighbouring panels instead of leaving sawtooth cracks.
	for i in xs.size():
		var p := origin + tangent * xs[i]
		peaks.append(top * (0.94 + 0.10 * sin(p.x * 0.31) + 0.06 * sin(p.z * 0.44)))
	var bands: Array[float] = [0.0, 0.12, 0.40, 0.46, 0.79, 1.0]
	var depths: Array[float] = [0.0, 0.04, 0.24, 0.07, 0.36, 0.65]
	var shaded := shelter(ThirdMap.world(cell))
	var base := Color("bd875f").lerp(Color("8e8580"), shaded * 0.72)
	if cell.x >= 11 and cell.y <= 4: base = Color("77757b")
	var colors := [base.darkened(0.16), base, base.lightened(0.13), base.darkened(0.07), base.lightened(0.07)]
	for band in 5:
		for i in xs.size() - 1:
			var a := origin + tangent * xs[i] + Vector3.UP * peaks[i] * bands[band] + outward * depths[band]
			var b := origin + tangent * xs[i + 1] + Vector3.UP * peaks[i + 1] * bands[band] + outward * depths[band]
			var c := origin + tangent * xs[i + 1] + Vector3.UP * peaks[i + 1] * bands[band + 1] + outward * depths[band + 1]
			var d := origin + tangent * xs[i] + Vector3.UP * peaks[i] * bands[band + 1] + outward * depths[band + 1]
			# Broad weathered facets, with continuous world-space offsets at adjoining panels.
			if contains(cell):
				a += outward * (.06 + .06 * sin(a.x * 1.1 + a.z * .8)) * sin(bands[band] * PI)
				b += outward * (.06 + .06 * sin(b.x * 1.1 + b.z * .8)) * sin(bands[band] * PI)
				c += outward * (.06 + .06 * sin(c.x * 1.1 + c.z * .8)) * sin(bands[band + 1] * PI)
				d += outward * (.06 + .06 * sin(d.x * 1.1 + d.z * .8)) * sin(bands[band + 1] * PI)
			_quad(tool, a, b, c, d, colors[band].darkened(rng.randf_range(0, 0.06)))
	# Top ledge and end caps prevent paper-thin silhouettes when walking around a bend.
	for i in xs.size() - 1:
		var a := origin + tangent * xs[i] + Vector3.UP * peaks[i] + outward * 0.65
		var b := origin + tangent * xs[i + 1] + Vector3.UP * peaks[i + 1] + outward * 0.65
		_quad(tool, b, a, a + outward * 1.2, b + outward * 1.2, base.lightened(0.18))
	for i: int in [0, xs.size() - 1]:
		var neighbour := cell + Vector2i(-direction.y, direction.x) * (-1 if i == 0 else 1)
		if map.floor_cells.has(neighbour) and not map.floor_cells.has(neighbour + direction) and dresses_wall(neighbour, direction):
			continue # No overlapping internal end caps between continuous wall panels.
		var foot := origin + tangent * xs[i]
		var crest := foot + Vector3.UP * peaks[i] + outward * 0.65
		_quad(tool, foot, crest, crest + outward * 1.2, foot + outward * 1.85, base.darkened(0.08))
	# Authored contact shade is opaque floor geometry, not a shadow map or transparency layer.
	var left := origin - tangent * 2.18 + Vector3.UP * 0.065
	var right := origin + tangent * 2.18 + Vector3.UP * 0.065
	var floor_color := Color("bda987") if cell.x < 3 or cell.y < 5 else Color("c29b6e")
	_quad(tool, right, left, left - outward * 0.20, right - outward * 0.20, floor_color.darkened(0.20))

func details(map: ThirdMap) -> void:
	# Thin, embedded stone shards break the floor's square tile rhythm without tripping players.
	var rng := RandomNumberGenerator.new()
	rng.seed = 34517
	for cell: Vector2i in map.floor_cells:
		if not contains(cell): continue
		var center := ThirdMap.world(cell)
		var tool := _builder(center)
		if cell.x < 3 or cell.y < 5:
			for i in 2:
				var p := center + Vector3(rng.randf_range(-1.3, 1.3), 0.065, rng.randf_range(-1.3, 1.3))
				_quad(tool, p + Vector3(-0.7, 0, -0.27), p + Vector3(-0.54, 0, 0.35), p + Vector3(0.64, 0, 0.24), p + Vector3(0.8, 0, -0.3), Color("c6b594"))
		# Edge debris hugs solid walls, never the middle of a walking route.
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if map.floor_cells.has(cell + direction): continue
			var p := center + Vector3(direction.x, 0, direction.y) * 1.55
			rock(tool, p, Vector3(0.32, 0.19, 0.26), Color("ae8763"))
	# Two distant ridges outside every playable cell: a recognisable skyline above the fork.
	for spec in [[Vector3(-8, 0, -10), Vector3(20, 16, 9), Color("b99383")], [Vector3(14, 0, -16), Vector3(25, 22, 12), Color("a79796")]]:
		_ridge(_builder(spec[0]), spec[0], spec[1], spec[2])
	# A small cairn on the sheltered side of the fork, away from the route centre.
	for i in 3:
		rock(_builder(Vector3(8.6, 0, 33)), Vector3(8.6, 0.2 + i * 0.24, 33), Vector3(0.52 - i * 0.1, 0.27, 0.4 - i * 0.06), Color("8a8272"))

func rock(tool: SurfaceTool, pos: Vector3, size: Vector3, color: Color) -> void:
	var rim: Array[Vector3] = []
	for i in 6:
		var angle := i * TAU / 6
		rim.append(pos + Vector3(cos(angle) * size.x, 0, sin(angle) * size.z))
	var peak := pos + Vector3(-size.x * 0.18, size.y, size.z * 0.1)
	for i in 6: _tri(tool, rim[i], peak, rim[(i + 1) % 6], color.lightened(0.035 * (i % 3)))

func _ridge(tool: SurfaceTool, pos: Vector3, size: Vector3, color: Color) -> void:
	var heights: Array[float] = [0.08, 0.45, 0.64, 0.58, 0.86, 1.0, 0.55, 0.08]
	for i in 7:
		var a := pos + Vector3((float(i) / 7 * 2 - 1) * size.x, 0, size.z * 0.4)
		var b := pos + Vector3((float(i + 1) / 7 * 2 - 1) * size.x, 0, size.z * 0.4)
		var c := b + Vector3(0, heights[i + 1] * size.y, -size.z * 0.4)
		var d := a + Vector3(0, heights[i] * size.y, -size.z * 0.4)
		_quad(tool, a, b, c, d, color.lightened(0.03 * (i % 3)))

func finish() -> void:
	for key in chunks:
		var instance := MeshInstance3D.new()
		instance.mesh = chunks[key].commit()
		instance.material_override = material
		add_child(instance)
	chunks.clear()
