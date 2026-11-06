extends Button
var angle := 0.0
var visual_scale := 1.0
func _draw() -> void:
	draw_set_transform(size * .5, 0, Vector2.ONE * visual_scale)
	draw_circle(Vector2.ZERO, 20, Color("664a30"))
	draw_arc(Vector2.ZERO, 18, 0, TAU, 32, Color("d9bc7d"), 2, true)
	var end := Vector2(12, 0).rotated(angle - PI / 4)
	draw_line(Vector2.ZERO, end, Color("f6dca7"), 5, true)
	draw_circle(Vector2.ZERO, 5, Color("bd9656"))
	draw_circle(end, 5, Color("8cccbc") if not disabled else Color("ac9d7c"))
