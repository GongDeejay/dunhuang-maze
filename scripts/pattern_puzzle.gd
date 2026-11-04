class_name PatternPuzzle
extends RefCounted
## Self-paced matching. Reading the loader is never required.

var phase := "inspect"
var latches := 0
var board: Array = [] # 0 = common ears; 1 = split ears (practice decoy).
var message := ""
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func completed() -> bool:
	return latches >= 1

func open() -> void:
	if completed():
		phase = "done"
		message = RabbitLore.text("reveal") + "\n" + RabbitLore.text("history")
		return
	# Leaving, resizing or missing once must not reshuffle the plates.
	if board.is_empty(): board = [0, 1] if rng.randi_range(0, 1) == 0 else [1, 0]
	phase = "inspect"
	message = RabbitLore.text("question")

func answer(index: int) -> bool:
	if phase != "inspect" or index < 0 or index >= board.size(): return false
	if board[index] != 0:
		message = RabbitLore.text("retry")
		return false
	latches = 1
	phase = "done"
	message = RabbitLore.text("reveal")
	return true

func suspend() -> void:
	# No hidden/timed stimulus; focus changes preserve the reference.
	pass
