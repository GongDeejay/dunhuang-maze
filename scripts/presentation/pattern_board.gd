class_name PatternBoard
extends Control
## Shared original artwork, also used on the wooden gate.
var shared := true

func _draw() -> void:
	var side := minf(size.x, size.y)
	RabbitLore.draw_plate(self, Rect2((size - Vector2.ONE * side) / 2, Vector2.ONE * side), shared)
