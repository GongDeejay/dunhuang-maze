extends Button
## A physical handle inside a standard, accessible 48px button hit target.
var angle := 0.0
var visual_scale := 1.0

func _draw() -> void:
	draw_set_transform(size * .5, 0, Vector2.ONE * visual_scale)
	var center := Vector2.ZERO
	draw_circle(center, 21, Color("785a38"))
	draw_arc(center, 19, 0, TAU, 32, Color("d4b477"), 2, true)
	var end := center + Vector2(12, 0).rotated(angle - PI / 4)
	draw_line(center, end, Color("f2d39b"), 5, true)
	draw_circle(center, 5, Color("ae8751"))
	draw_circle(end, 5, Color("82b6ad") if not disabled else Color("a79a76"))
