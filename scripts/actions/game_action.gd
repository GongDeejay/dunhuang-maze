class_name GameAction
extends RefCounted
## 输入层产出的游戏动作（对齐 godot-roguelike-basic-set 的 Action 模式）

enum Type {
	NONE,
	MOVE,
	USE_ITEM,
	SELECT_SLOT,
	REGENERATE,
	MENU,
	CYCLE_DIFFICULTY,
	CONFIRM,
	CANCEL,
	CLICK_AT,
}

var type: Type = Type.NONE
var direction: int = -1
var slot: int = -1
var diff_delta: int = 0
var position: Vector2 = Vector2.ZERO

static func move(dir: int) -> GameAction:
	var a := GameAction.new()
	a.type = Type.MOVE
	a.direction = dir
	return a

static func use_item(slot: int = -1) -> GameAction:
	var a := GameAction.new()
	a.type = Type.USE_ITEM
	a.slot = slot
	return a

static func select_slot(index: int) -> GameAction:
	var a := GameAction.new()
	a.type = Type.SELECT_SLOT
	a.slot = index
	return a

static func regenerate() -> GameAction:
	var a := GameAction.new()
	a.type = Type.REGENERATE
	return a

static func menu() -> GameAction:
	var a := GameAction.new()
	a.type = Type.MENU
	return a

static func cycle_difficulty(delta: int) -> GameAction:
	var a := GameAction.new()
	a.type = Type.CYCLE_DIFFICULTY
	a.diff_delta = delta
	return a

static func confirm() -> GameAction:
	var a := GameAction.new()
	a.type = Type.CONFIRM
	return a

static func cancel() -> GameAction:
	var a := GameAction.new()
	a.type = Type.CANCEL
	return a

static func click_at(pos: Vector2) -> GameAction:
	var a := GameAction.new()
	a.type = Type.CLICK_AT
	a.position = pos
	return a
