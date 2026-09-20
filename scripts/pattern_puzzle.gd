class_name PatternPuzzle
extends RefCounted
## Gameplay state only. No scores, reaction-time collection or assessment profile.

var phase := "intro"
var latches := 0
var slow := false
var simple := false
var seen_demo := false
var demo := false
var failures := 0
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
	return latches >= 2

func open() -> void:
	phase = "done" if completed() else ("ready" if seen_demo else "intro")
	remaining = 0.0
	message = ""

func begin_round(is_demo: bool = false) -> void:
	demo = is_demo
	board = [0, 1, 2, 3]
	for i in range(board.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var old: int = board[i]
		board[i] = board[j]
		board[j] = old
	var count := 2 if demo or simple else 4
	for i in range(count, 4): board[i] = -1
	target = rng.randi_range(0, count - 1)
	changed = true if demo else rng.randf() < 0.5
	probe = (int(board[target]) + rng.randi_range(1, 3)) % 4 if changed else int(board[target])
	phase = "observe"
	remaining = 1.8
	message = "先看这两枚纹样，点“看好了”再落帘。" if demo else "看清每一格的纹样。"

func advance() -> void:
	match phase:
		"intro": begin_round(true)
		"ready": begin_round()
		"observe": cover()
		"feedback":
			if demo:
				seen_demo = true
				demo = false
				phase = "ready"
			else: begin_round()

func cover() -> void:
	if phase != "observe": return
	phase = "cover"
	remaining = 0.7
	message = "护帘轻轻落下……"

func tick(delta: float) -> bool:
	if phase != "cover" and not (phase == "observe" and not slow and not demo): return false
	remaining -= delta
	if remaining > 0: return false
	if phase == "observe": cover()
	else:
		phase = "probe"
		message = "框出的这一格，还是刚才的纹样吗？"
	return true

func answer(says_changed: bool) -> bool:
	if phase != "probe": return false
	var correct := says_changed == changed
	phase = "feedback"
	if demo:
		message = "这一格换了纹样，应选“变了 · 复原”。看懂后就可以拨动木匣了。"
	elif correct:
		latches += 1
		failures = 0
		message = "咔哒，一枚纹扣扣好了。再看看另一处。"
		if completed():
			phase = "done"
			message = "两枚纹扣扣好了，旁边的栈道门已经打开！"
	else:
		failures += 1
		message = "这是刚才的纹样。再看一次，慢慢来。"
		if failures >= 2: message += "也可以慢慢看，或先沿栈道走。"
	return correct

func suspend() -> void:
	if phase != "done": phase = "suspended"
	remaining = 0.0
