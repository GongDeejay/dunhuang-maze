class_name GameCamera
extends Camera2D

var target: Node2D
var maze_pixel_w: float
var maze_pixel_h: float
var game_area_w: float
var game_area_h: float

func setup(target_node: Node2D, mpw: float, mph: float, gaw: float, gah: float):
	target = target_node
	maze_pixel_w = mpw
	maze_pixel_h = mph
	game_area_w = gaw
	game_area_h = gah
	make_current()

func _process(_delta: float):
	if target == null:
		return
	var target_pos = target.global_position + Vector2(game_area_w / 2, game_area_h / 2)
	var half_view = Vector2(game_area_w / 2, game_area_h / 2)
	target_pos.x = clampf(target_pos.x, half_view.x, maze_pixel_w - half_view.x)
	target_pos.y = clampf(target_pos.y, half_view.y, maze_pixel_h - half_view.y)
	global_position = global_position.lerp(target_pos, 0.1)
