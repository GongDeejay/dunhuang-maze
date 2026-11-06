extends RefCounted
## Preview-only deterministic rules. Never reads or writes the campaign save.
const START := Vector2i(2, 6)
const SCARF := Vector2i(2, 0)
const TURN_SECONDS := 0.8
const STEP_SECONDS := 0.18
var player := START
var destination := START
var connected := false
var busy := ""
var progress := 0.0
var paused := false
var won := false
var moves := 0
var turns := 0

func land(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x <= 3 and cell.y in [0, 1, 5, 6]

func walkable(cell: Vector2i) -> bool:
	return land(cell) or (connected and cell.x == 2 and cell.y >= 2 and cell.y <= 4)

func can_turn() -> bool:
	return not paused and not won and busy.is_empty() and land(player) and (distance(player, Vector2i(3, 5)) <= 1 or distance(player, Vector2i(3, 1)) <= 1)

func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func turn() -> bool:
	if not can_turn(): return false
	busy = "turn"
	progress = 0
	return true

func step(direction: Vector2i) -> bool:
	if paused or won or not busy.is_empty() or distance(direction, Vector2i.ZERO) != 1: return false
	if not walkable(player + direction): return false
	destination = player + direction
	busy = "step"
	progress = 0
	return true

func advance(delta: float) -> void:
	if paused or busy.is_empty(): return
	progress = minf(1, progress + maxf(delta, 0) / (TURN_SECONDS if busy == "turn" else STEP_SECONDS))
	if progress < 1: return
	if busy == "turn":
		connected = not connected
		turns += 1
	else:
		player = destination
		moves += 1
		won = player == SCARF
	busy = ""

func angle() -> float:
	var start := PI / 2 if connected else 0.0
	return lerpf(start, 0.0 if connected else PI / 2, smoothstep(0, 1, progress)) if busy == "turn" else start

func visual_player() -> Vector2:
	return Vector2(player).lerp(Vector2(destination), smoothstep(0, 1, progress)) if busy == "step" else Vector2(player)
