extends Node2D

var maze: MazeGenerator
var renderer := MazeRenderer.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	renderer.cell_size = 40
	renderer.wall_thickness = 4
	renderer.load_sprites()
	maze = MazeGenerator.new(FirstJourney.SIZE.x, FirstJourney.SIZE.y)
	var journey := FirstJourney.new()
	journey.build(maze)
	queue_redraw()


func _draw() -> void:
	var visited := {}
	for y in maze.height:
		for x in maze.width:
			visited[Vector2i(x, y)] = true
	renderer.draw_cells(self, maze, maze.width, maze.height, Vector2.ZERO, 1.0, visited, func(_p): return true)
