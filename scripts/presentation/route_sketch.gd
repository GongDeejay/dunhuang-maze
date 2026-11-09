class_name RouteSketch
extends Control
## A readable drawing of the actual local path, not a second puzzle or a full-map reveal.
var points: Array[Vector2i] = []
var studied := false
var gate_button: Button
var ranges: Array = []
const LABEL_FONT = preload("res://assets/fonts/NotoSansSC-GameSubset.ttf")

func map_point(cell: Vector2i) -> Vector2:
	return Vector2(20 + cell.x / 14.0 * (size.x - 40), 24 + (cell.y - 5) / 7.0 * (size.y - 48))

func _draw() -> void:
	draw_style_box(_paper(), Rect2(Vector2.ZERO, size))
	if points.size() > 1:
		var line := PackedVector2Array()
		for cell in points: line.append(map_point(cell))
		draw_polyline(line, Color("bd9660"), 10, true)
		draw_polyline(line, Color("f9ce66") if studied else Color("715f45"), 3, true)
	_draw_ranges()
	for spec in [[FirstJourney.MURAL, "石窟"], [FirstJourney.SPRING, "泉水"]]:
		var p := map_point(spec[0])
		draw_circle(p, 8, Color("487c78"))
		draw_string(ThemeDB.fallback_font, p + Vector2(-18, -15), spec[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("493b2b"))
	var top := Vector2(size.x - 48, 24)
	draw_line(top + Vector2(0, 16), top, Color("493b2b"), 2)
	draw_string(ThemeDB.fallback_font, top + Vector2(8, 10), "北", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("493b2b"))
	if gate_button:
		gate_button.position = map_point(FirstJourney.STONE_GATE) - gate_button.size / 2

static func range_span(radius: float, sketch_size: Vector2) -> Vector2:
	var cell := Vector2((sketch_size.x - 40.0) / 14.0, (sketch_size.y - 48.0) / 7.0)
	return cell * radius * 2.0


func _draw_ranges() -> void:
	for area in ranges:
		var cell: Vector2i = area["cell"]
		var center := map_point(cell)
		var span := range_span(float(area["radius"]), size)
		var rx := span.x * 0.5
		var ry := span.y * 0.5
		var pts := PackedVector2Array()
		for i in 28:
			var angle := TAU * float(i) / 28.0
			pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
		draw_colored_polygon(pts, Color(0.62, 0.38, 0.18, 0.34))
		pts.append(pts[0])
		draw_polyline(pts, Color("6b3d22"), 2.0, true)
		draw_string(LABEL_FONT, center + Vector2(-rx * 0.55, 5), str(area["label"]), HORIZONTAL_ALIGNMENT_LEFT, int(rx * 1.4), 15, Color("493b2b"))


func _paper() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("eee0bd")
	style.set_corner_radius_all(8)
	return style
