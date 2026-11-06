extends RefCounted
const Rules = preload("res://tests/bridge_slice/model.gd")

static func reachable(m) -> bool:
	var queue: Array[Vector2i] = [Rules.START]
	var seen := {Rules.START: true}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == Rules.SCARF: return true
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + d
			if not seen.has(next) and m.walkable(next):
				seen[next] = true
				queue.append(next)
	return false

static func run(suite: Node) -> void:
	print("\n[TEST] Turning Bridge Preview")
	var m = Rules.new()
	suite.assert_true(not reachable(m), "unturned bridge cannot be bypassed")
	suite.assert_true(not m.turn(), "distant player cannot operate a crank")
	suite.assert_true(not m.step(Vector2i(1, -1)), "diagonal commands cannot bypass floor rules")
	suite.assert_true(m.step(Vector2i.UP), "walk one step to the bank")
	suite.assert_true(not m.step(Vector2i.UP), "one gesture cannot queue a second step")
	m.advance(1)
	suite.assert_eq(m.player, Vector2i(2, 5), "single input settles at exactly one tile")
	suite.assert_true(not m.step(Vector2i.UP), "open gap blocks movement")
	suite.assert_true(m.turn(), "bank crank starts rotation")
	suite.assert_true(not m.turn() and not m.step(Vector2i.UP), "turning freezes movement and duplicate activations")
	m.advance(.2)
	var progress: float = m.progress
	m.paused = true
	m.advance(3)
	suite.assert_eq(m.progress, progress, "pause freezes bridge animation")
	m.paused = false
	m.advance(1)
	suite.assert_true(m.connected and reachable(m), "rotation creates an actual route to the scarf")
	suite.assert_eq(m.moves, 1, "rotation never teleports the player")
	suite.assert_true(not m.won, "opening a route is not reaching the goal")
	suite.assert_true(m.turn(), "rotation can be reversed from a safe bank")
	m.advance(1)
	suite.assert_true(not reachable(m), "reverse restores the original connectivity")
	m.turn()
	m.advance(1)
	m.step(Vector2i.UP)
	m.advance(1)
	suite.assert_true(not m.turn(), "player on bridge cannot disconnect own support")
	for i in 4:
		suite.assert_true(m.step(Vector2i.UP), "connected deck and far bank are walkable")
		m.advance(1)
	suite.assert_true(m.won and m.player == Rules.SCARF, "only physically reaching scarf finishes slice")
	suite.assert_true(not m.step(Vector2i.DOWN) and not m.turn(), "completed preview ignores late inputs")
