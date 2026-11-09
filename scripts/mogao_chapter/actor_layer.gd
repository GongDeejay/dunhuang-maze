extends Control
## Characters drawn after the lamp halo so the ellipse stays under their feet.
var host: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if host == null:
		return
	host.painter.paint_actors(host, self)
