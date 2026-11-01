class_name PatternPuzzle
extends RefCounted
## One self-paced observation and one comparison open the optional shortcut.

var phase := "observe"
var latches := 0
var board: Array = []
var target := 0
var probe := 0
var changed := false
var remaining := 0.0
var message := ""
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func completed() -> bool:
	return latches >= 1

func open() -> void:
	if completed(): phase = "done"
	else: begin_round()

func begin_round() -> void:
	var first := rng.randi_range(0, 3)
	board = [first, (first + rng.randi_range(1, 3)) % 4]
	target = rng.randi_range(0, 1)
	changed = rng.randf() < 0.5
	probe = (int(board[target]) + rng.randi_range(1, 3)) % 4 if changed else int(board[target])
	phase = "observe"
	remaining = 0.0
	message = "记住左右两个图案，不着急。"

func advance() -> void:
	if phase == "observe": cover()
	elif phase == "suspended": begin_round()

func cover() -> void:
	if phase != "observe": return
	phase = "cover"
	remaining = 0.45
	message = "……"

func tick(delta: float) -> bool:
	if phase != "cover": return false
	remaining -= delta
	if remaining > 0: return false
	phase = "probe"
	message = "亮框里的图案变了吗？"
	return true

func answer(says_changed: bool) -> bool:
	if phase != "probe": return false
	if says_changed == changed:
		latches = 1
		phase = "done"
		message = "门开了！"
		return true
	begin_round()
	message = "没关系，再看一眼。"
	return false

func suspend() -> void:
	if phase != "done": phase = "suspended"
	remaining = 0.0
