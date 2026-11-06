extends "res://scripts/main.gd"
## Isolated preview uses the real campaign controller and read-only telemetry.
func _ready() -> void:
	super._ready()
	game.start_game()
	_new_game(1)

func rect(node: Control) -> Dictionary:
	var r := node.get_global_rect()
	return {"x": r.get_center().x, "y": r.get_center().y, "left": r.position.x, "right": r.end.x, "top": r.position.y, "bottom": r.end.y, "visible": node.is_visible_in_tree(), "disabled": node.disabled if node is Button else false}

func _process(delta: float) -> void:
	super._process(delta)
	if not OS.has_feature("web"): return
	var data := {"active": cave_chapter != null, "third": third_chapter != null, "level": current_level_index, "menu": game.is_difficulty_select()}
	if cave_chapter:
		var c := cave_chapter; var m := c.model
		data.merge({"gates": [m.gate_open(0), m.gate_open(1)], "gateVisual": c.gate_visual, "shared": m.plate_active(1), "bankLit": m.bank_lit(), "deerTime": m.deer_time, "latch": m.latch, "checkpoint": SaveManager.load_progress().get("cave_room", -1)})
		data.merge({"width": c.size.x, "height": c.size.y, "frame": c.frame, "room": m.room, "x": m.player.x, "y": m.player.y, "busy": m.busy, "progress": m.progress, "mode": c.mode, "moves": m.moves, "turns": m.turns, "reached": m.reached, "rescued": m.rescued, "scarf": m.scarf, "box": [m.box.x, m.box.y], "gate": m.gate_open(), "lit": m.lit(), "held": m.lamp_held, "lamp": [m.lamp.x, m.lamp.y], "deer": m.deer_seen, "history": m.history.size(), "arrows": c.arrows.map(rect), "action": rect(c.action_button), "undo": rect(c.undo_button), "note": rect(c.note_button), "pause": rect(c.pause_button), "cranks": c.cranks.map(rect), "primary": rect(c.primary), "secondary": rect(c.secondary), "tertiary": rect(c.tertiary), "panel": rect(c.panel), "scroll": rect(c.card_scroll), "hint": rect(c.hint), "heading": rect(c.heading), "objective": rect(c.objective), "hintText": c.hint.text})
	JavaScriptBridge.eval("window.caveProbe = " + JSON.stringify(data) + ";")
