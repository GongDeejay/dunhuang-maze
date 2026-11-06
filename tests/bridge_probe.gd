extends "res://tests/bridge_slice/view.gd"
## Read-only browser telemetry; never included in the campaign export.
var frame := 0
func bounds(node: Control) -> Dictionary:
	var rect := node.get_global_rect()
	return {"x": rect.get_center().x, "y": rect.get_center().y, "left": rect.position.x, "top": rect.position.y, "right": rect.end.x, "bottom": rect.end.y, "disabled": node.disabled if node is Button else false}

func _process(delta: float) -> void:
	super._process(delta)
	frame += 1
	if not OS.has_feature("web"): return
	var data := {"width": size.x, "height": size.y, "x": model.player.x, "y": model.player.y, "connected": model.connected, "busy": model.busy, "progress": model.progress, "turns": model.turns, "moves": model.moves, "won": model.won, "paused": model.paused, "turn": bounds(turn_button), "restart": bounds(restart_button), "pause": bounds(pause_button), "cranks": cranks.map(bounds), "arrows": arrows.map(bounds), "goal": {"x": point(Vector2(2, 0)).x, "y": point(Vector2(2, 0)).y}, "hint": bounds(hint)}
	data["frame"] = frame
	JavaScriptBridge.eval("window.bridgeProbe = " + JSON.stringify(data) + ";")
