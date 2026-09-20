class_name PatternBoard
extends Control
## Resolution-independent original motifs; no raster downloads or external fonts.
var puzzle: PatternPuzzle

func _draw() -> void:
	if puzzle == null: return
	var side := minf(size.x, size.y)
	var origin := (size - Vector2.ONE * side) / 2
	for i in 4:
		var rect := Rect2(origin + Vector2(i % 2, i / 2) * side / 2 + Vector2.ONE * 5, Vector2.ONE * (side / 2 - 10))
		draw_style_box(_tile_style(i), rect)
		var symbol := -1
		if puzzle.phase == "observe": symbol = puzzle.board[i]
		elif puzzle.phase == "probe" and i == puzzle.target: symbol = puzzle.probe
		elif puzzle.phase == "feedback" and i == puzzle.target: symbol = puzzle.board[i]
		elif puzzle.phase in ["intro", "ready", "done"]: symbol = i
		if symbol >= 0: _motif(symbol, rect.get_center(), rect.size.x * 0.3)
		else:
			for n in range(1, 5):
				var y := rect.position.y + rect.size.y * n / 5
				draw_line(Vector2(rect.position.x + 10, y), Vector2(rect.end.x - 10, y), Color("66533b"), 2)

func _tile_style(index: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("32291f")
	style.border_color = Color("dec48c") if puzzle.phase in ["probe", "feedback"] and index == puzzle.target else Color("79613f")
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	return style

func _motif(kind: int, c: Vector2, r: float) -> void:
	var color := [Color("e8ba83"), Color("90c8c6"), Color("a7c8dc"), Color("b8cf8c")][kind] as Color
	match kind:
		0: # Lotus: three pointed petals and a curved base.
			for angle in [-0.65, 0.0, 0.65]:
				var v := Vector2(sin(angle), -cos(angle))
				var p := Vector2(-v.y, v.x)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.5), c + v * r * 0.6 - p * r * 0.32, c + v * r, c + v * r * 0.6 + p * r * 0.32]), color)
			draw_arc(c, r * 0.7, 0, PI, 24, color, 3, true)
		1: # Cloud silhouette.
			draw_circle(c + Vector2(-r * 0.5, 0), r * 0.42, color)
			draw_circle(c + Vector2(0, -r * 0.3), r * 0.6, color)
			draw_circle(c + Vector2(r * 0.6, 0), r * 0.4, color)
			draw_line(c + Vector2(-r * 0.65, r * 0.35), c + Vector2(r * 0.7, r * 0.35), color, 4, true)
		2: # Three distinct waves.
			for row in [-1, 0, 1]:
				var points := PackedVector2Array()
				for n in 25:
					var x := -r + 2 * r * n / 24.0
					points.append(c + Vector2(x, row * r * 0.55 + sin(n / 24.0 * TAU) * r * 0.16))
				draw_polyline(points, color, 4, true)
		3: # Leaf, with a dark midrib.
			var points := PackedVector2Array()
			for n in 33:
				var a := n * TAU / 32
				points.append(c + Vector2(cos(a) * r * 0.55, sin(a) * r).rotated(0.5))
			draw_colored_polygon(points, color)
			draw_line(c + Vector2(-0.4, 0.75) * r, c + Vector2(0.4, -0.75) * r, Color("32291f"), 3, true)
