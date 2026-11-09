class_name HazardGate
extends RefCounted
## Hold-repeat stops before a damaging cell. One real press may enter, and
## holding that same direction may finish the contiguous patch. Leaving the
## patch, releasing, or changing direction arms the stop again.

var pass_direction := -1


func blocks_repeat(direction: int, standing_on_hazard: bool, entering_hazard: bool) -> bool:
	if not entering_hazard:
		return false
	return not (pass_direction == direction and standing_on_hazard)


func authorize(direction: int, on_hazard: bool) -> void:
	pass_direction = direction if on_hazard else -1


func note_after_repeat(direction: int, on_hazard: bool) -> void:
	if pass_direction == direction and not on_hazard:
		pass_direction = -1


func sync_held(direction: int) -> void:
	if direction != pass_direction:
		pass_direction = -1


func clear() -> void:
	pass_direction = -1
