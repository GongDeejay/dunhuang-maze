class_name ThirdChapter
extends Node3D
## Isolated chapter controller. No writes into the first two chapters' movement model.
signal menu_requested
signal replay_requested
signal completed
const WALK_SPEED := 4.6
const INTERACT_RANGE := 3.8
var map := ThirdMap.new()
var world: DesertWorld
var body: CharacterBody3D
var camera: Camera3D
var hud: ThirdHUD
var ui_layer: CanvasLayer
var mode := "welcome"
var rescued := false
var relic_found := false
var route := ""
var hp := 18
var max_hp := 18
var difficulty := "normal"
var checkpoint := ThirdMap.world(ThirdMap.START)
var yaw := 0.0
var pitch := 0.0
var move_touch := -1
var look_touch := -1
var stick := Vector2.ZERO
var held: Dictionary = {}
var mouse_drag := false
var elapsed := 0.0
var travelled := 0.0
var step_timer := 0.0
var wind_timer := 0.0
var enemy_hp := 6
var enemy_phase := "idle"
var enemy_timer := 0.0
var attack_timer := 0.0
var ending_timer := 0.0
var message := "沿着脚印前进；右侧滑动观察 / 鼠标拖动观察"
var message_timer := 8.0
var current_target := ""
var damage_flash := 0.0
var _last_view := Vector2.ZERO
var _old_scale := 1.0
var _old_msaa := Viewport.MSAA_DISABLED
var _stopped := false
var wind_audio: AudioStreamPlayer
var golden_clue: GoldenClue
var cave_greeting := false

func _ready() -> void:
	world = DesertWorld.new()
	add_child(world)
	world.build(map)
	golden_clue = GoldenClue.new()
	add_child(golden_clue)
	golden_clue.build(map)
	body = CharacterBody3D.new()
	body.position = checkpoint + Vector3(0, 0.05, 0)
	add_child(body)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	collision.shape = capsule
	collision.position.y = 0.85
	body.add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.fov = 72
	camera.near = 0.08
	camera.far = 180
	body.add_child(camera)
	camera.current = true
	world.update_atmosphere(body.position, 1.0)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 110
	add_child(ui_layer)
	hud = ThirdHUD.new()
	ui_layer.add_child(hud)
	hud.action.connect(_on_action)
	_make_wind()
	_old_scale = get_viewport().scaling_3d_scale
	_old_msaa = get_viewport().msaa_3d
	var display := ConfigFile.new()
	if display.load("user://third_display.cfg") == OK: hud.set_quality(int(display.get_value("display", "quality", 1)))
	_update_render_size()
	message = "沿脚印前进；右侧滑动观察" if hud.touch else "沿脚印前进；点击场景后移动鼠标观察"
	hud.show_card("第三章 · 风中的归路", "弟弟还在三危山。妈妈和哥哥会在远处的塔下等你们。\n\n电脑：WASD 行走，拖动鼠标或点击场景后移动鼠标观察，E 互动。\n手机：左侧摇杆行走，右侧滑动观察。\n\n不需要跳跃。暂停中可以调整观察灵敏度。", "走进沙谷")
	_refresh_hud()

func _exit_tree() -> void:
	if _stopped: return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(get_viewport()):
		get_viewport().scaling_3d_scale = _old_scale
		get_viewport().msaa_3d = _old_msaa

func shutdown() -> void:
	_stopped = true
	reset_input()
	set_physics_process(false)
	set_process_input(false)
	ui_layer.hide()
	camera.current = false
	get_viewport().scaling_3d_scale = _old_scale
	get_viewport().msaa_3d = _old_msaa

func reset_input() -> void:
	held.clear()
	stick = Vector2.ZERO
	move_touch = -1
	look_touch = -1
	mouse_drag = false
	if body: body.velocity = Vector3.ZERO
	if hud: hud.stick_vector = Vector2.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if wind_audio: wind_audio.stream_paused = true

func _make_wind() -> void:
	# A quiet, precomputed PCM loop: no audio download, no per-frame synthesis.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 44100
	var data := PackedByteArray()
	data.resize(88200)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var value := 0.0
	for i in 44100:
		value = value * 0.96 + rng.randf_range(-1, 1) * 0.04
		var envelope := sin(float(i) / 44100.0 * PI)
		var sample := int(value * envelope * 9000)
		data.encode_s16(i * 2, sample)
	stream.data = data
	wind_audio = AudioStreamPlayer.new()
	wind_audio.stream = stream
	wind_audio.volume_db = -14
	add_child(wind_audio)
	wind_audio.play()
	wind_audio.stream_paused = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and hud != null:
		reset_input()
		if mode == "playing": _on_action("pause")

func _update_render_size() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp == _last_view: return
	_last_view = vp
	PlatformService.refresh(vp)
	hud.layout()
	# Cap 3D pixel cost on high-DPI phones; CanvasLayer text remains native resolution.
	var pixels := get_viewport().get_texture().get_size()
	var target: float = [960.0, 1280.0, 1600.0][hud.quality_index] if hud.touch else [1440.0, 1920.0, 2560.0][hud.quality_index]
	get_viewport().scaling_3d_scale = clampf(target / maxf(pixels.x, pixels.y), 0.25, 1.0)
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if hud.quality_index == 0 else Viewport.MSAA_2X
	reset_input()
	if wind_audio and mode == "playing": wind_audio.stream_paused = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.echo: return
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if mode != "playing":
			if event.pressed and key in [KEY_ESCAPE, KEY_P] and mode == "paused": _on_action("primary")
			# Focused native buttons handle Enter/Space; do not fire their action twice.
			return
		if key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			if event.pressed: held[key] = true
			else: held.erase(key)
		elif event.pressed:
			if key in [KEY_ESCAPE, KEY_P]: _on_action("pause")
			elif key == KEY_E: interact()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if not event.pressed:
			if event.index == move_touch:
				move_touch = -1
				stick = Vector2.ZERO
			if event.index == look_touch: look_touch = -1
		elif mode == "playing" and not hud.ui_hit(event.position):
			if event.position.distance_to(hud.stick_center) <= hud.stick_radius + 12 and move_touch < 0:
				move_touch = event.index
				stick = ((event.position - hud.stick_center) / 48).limit_length()
			elif event.position.x > hud.size.x * 0.45 and look_touch < 0:
				look_touch = event.index
	elif event is InputEventScreenDrag and mode == "playing":
		if event.index == move_touch: stick = ((event.position - hud.stick_center) / 48).limit_length()
		elif event.index == look_touch: look(event.relative)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_drag = event.pressed and mode == "playing" and not hud.ui_hit(event.position)
			if mouse_drag and not hud.touch: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and mode == "playing":
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or mouse_drag: look(event.relative)

func look(delta: Vector2) -> void:
	yaw -= delta.x * 0.003 * hud.sensitivity.value
	pitch = clampf(pitch - delta.y * 0.003 * hud.sensitivity.value, -0.85, 0.8)
	body.rotation.y = yaw
	camera.rotation.x = pitch

func movement() -> Vector2:
	var value := stick
	if held.has(KEY_W) or held.has(KEY_UP): value.y -= 1
	if held.has(KEY_S) or held.has(KEY_DOWN): value.y += 1
	if held.has(KEY_A) or held.has(KEY_LEFT): value.x -= 1
	if held.has(KEY_D) or held.has(KEY_RIGHT): value.x += 1
	return value.limit_length() if value.length() > 0.16 else Vector2.ZERO

func _physics_process(delta: float) -> void:
	_update_render_size()
	if mode.begins_with("ending"):
		ending_timer += delta
		if ending_timer >= 8:
			ending_timer = 0
			_next_ending()
		return
	if mode != "playing": return
	var dt := minf(delta, 0.05)
	elapsed += dt
	attack_timer = maxf(0, attack_timer - dt)
	damage_flash = maxf(0, damage_flash - dt * 2)
	message_timer = maxf(0, message_timer - dt)
	var input := movement()
	var direction := body.basis * Vector3(input.x, 0, input.y)
	body.velocity.x = direction.x * WALK_SPEED
	body.velocity.z = direction.z * WALK_SPEED
	body.velocity.y = -2
	var before := body.position
	body.move_and_slide()
	world.update_atmosphere(body.position, dt)
	golden_clue.advance(dt)
	# The bend is quieter, without adding audio files or changing other chapters' audio.
	var shelter := maxf(ValleyScenery.shelter(body.position), HomewardScenery.cave_weight(body.position))
	if rescued: shelter = maxf(shelter, smoothstep(36.0, 50.0, body.position.z))
	wind_audio.volume_db = lerpf(-14.0, -22.0, shelter)
	travelled += Vector2(body.position.x - before.x, body.position.z - before.z).length()
	if body.position.distance_to(before) > 0.01 and input.length() > 0:
		step_timer += dt
		if step_timer > 0.5:
			step_timer = 0
			AudioManager.play_step()
	var cell := ThirdMap.cell_at(body.position)
	if cell.distance_to(ThirdMap.FORK) < 1.5: checkpoint = ThirdMap.world(ThirdMap.FORK)
	if route.is_empty():
		if cell.x <= 2 and cell.y <= 6: route = "避风古道"
		elif cell.x >= 6 and cell.y == 8: route = "风沙近路"
	wind_timer += dt
	if map.is_windy(body.position) and wind_timer > 2:
		wind_timer = 0
		_hurt(1)
		_notify("风沙很大，穿过前面的山口就能避风。")
	if mode != "playing": return
	if not rescued and not cave_greeting and body.position.distance_to(ThirdMap.world(ThirdMap.CHILD)) < 9 and _line_clear(ThirdMap.world(ThirdMap.CHILD)):
		cave_greeting = true
		_notify("石窟里传来弟弟的声音：“爸爸……是你吗？”", 5)
	_update_enemy(dt)
	if mode != "playing": return
	if rescued and body.position.distance_to(ThirdMap.world(ThirdMap.CAMP)) < 4:
		_begin_ending()
		return
	current_target = target()
	golden_clue.set_observable(current_target == "light")
	_refresh_hud()

func _line_clear(pos: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, pos + Vector3(0, 1, 0))
	query.exclude = [body.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func in_reach(pos: Vector3, distance: float = INTERACT_RANGE) -> bool:
	var offset := pos + Vector3(0, 1.2, 0) - camera.global_position
	return offset.length() <= distance and -camera.global_basis.z.dot(offset.normalized()) > 0.25 and _line_clear(pos)

func target() -> String:
	if not rescued and in_reach(ThirdMap.world(ThirdMap.CHILD)): return "child"
	if relic_found and not rescued and not golden_clue.found and GoldenClue.in_view(camera.global_position, -camera.global_basis.z) and _line_clear(ThirdMap.world(ThirdMap.RELIC)): return "light"
	if not relic_found and in_reach(ThirdMap.world(ThirdMap.RELIC)): return "relic"
	if in_reach(ThirdMap.world(ThirdMap.FORK)): return "sign"
	if enemy_hp > 0 and in_reach(ThirdMap.world(ThirdMap.SCORPION)): return "enemy"
	return ""

func interact() -> void:
	if mode != "playing": return
	match target():
		"sign": _notify("← 古道较长、可以避风；→ 近路有风沙和沙蝎。两条路都能找到弟弟。", 9)
		"relic":
			relic_found = true
			hp = mini(max_hp, hp + 6)
			_notify(TravelLore.text("golden_light", "prompt") + "\n恢复 6 点体力。", 16)
			AudioManager.play_pickup()
		"light":
			if golden_clue.reveal():
				_notify(TravelLore.text("golden_light", "reveal"), 12)
				AudioManager.play_pickup()
		"child":
			rescued = true
			golden_clue.trail.hide() # Return route uses the existing tower landmark.
			world.open_gate()
			checkpoint = ThirdMap.world(ThirdMap.CHILD)
			hp = max_hp
			mode = "rescue"
			reset_input()
			var reunion := "弟弟：“爸爸，我听见你了。”\n爸爸：“走，我们回家。”"
			if golden_clue.found: reunion = "弟弟：“我画了小脚印，怕你找不到。”\n爸爸：“看见了。走，我们回家。”"
			hud.show_card("终于找到弟弟了", reunion + "\n\n旧门已经打开。沿暖色布条回到高塔下，妈妈和哥哥在灯下等你们。", "一起回营地")
		"enemy":
			if attack_timer > 0: return
			attack_timer = 0.5
			enemy_hp -= 3
			AudioManager.play_hit()
			if enemy_hp <= 0:
				world.scorpion_sprite.hide()
				_notify("沙蝎退进了石缝。前面的路安全了。")
	_refresh_hud()

func _update_enemy(dt: float) -> void:
	if enemy_hp <= 0: return
	var pos := ThirdMap.world(ThirdMap.SCORPION)
	var near := body.position.distance_to(pos) < 6 and _line_clear(pos)
	if enemy_phase == "idle":
		if near:
			enemy_phase = "warning"
			enemy_timer = 1.6
			_notify("沙蝎抬起尾巴！后退避开，再靠近反击。")
	else:
		enemy_timer -= dt
		if enemy_timer <= 0:
			if enemy_phase == "warning":
				if body.position.distance_to(pos) < 3.2 and _line_clear(pos): _hurt(3 if difficulty != "hard" else 4)
				enemy_phase = "rest"
				enemy_timer = 2.4
			else: enemy_phase = "idle"
	world.scorpion_sprite.scale = Vector3.ONE * (1.15 if enemy_phase == "warning" else 1.0)

func _hurt(amount: int) -> void:
	hp = maxi(0, hp - amount)
	damage_flash = 1
	if hp == 0:
		mode = "recover"
		reset_input()
		hud.show_card("先回避风处歇一歇", "你退回了最近的安全地点。已经发现的手记和救援进度都会保留，不必重走整关。", "恢复体力，继续寻找")

func _notify(text: String, duration: float = 5.0) -> void:
	message = text
	message_timer = duration

func _refresh_hud() -> void:
	hud.title.text = "三危山 · " + map.zone(body.position)
	hud.objective.text = "与弟弟回到高塔下的营地" if rescued else ("沿金色足迹前往北面石窟" if golden_clue.found else "寻找弟弟 · 留意足迹与石窟")
	hud.status.text = "体力 %d/%d  ·  %s" % [hp, max_hp, "已发现旅行手记" if relic_found else "手记可选探索"]
	hud.hint.text = message if message_timer > 0 else ("手记旁的暖光：退半步到左侧，转头看岩缝。" if relic_found and not golden_clue.found and not rescued and body.position.distance_to(ThirdMap.world(ThirdMap.RELIC)) < 7 else ("右侧滑动观察 · 靠近后互动" if hud.touch else "WASD 移动 · 鼠标观察 · E 互动 · Esc 暂停"))
	# Let the landscape breathe after teaching controls; keep contextual guidance and touch controls.
	if mode == "playing" and ValleyScenery.contains(ThirdMap.cell_at(body.position)):
		hud.hint.visible = message_timer > 0 or (relic_found and not golden_clue.found and not rescued and body.position.distance_to(ThirdMap.world(ThirdMap.RELIC)) < 7)
	elif mode == "playing": hud.hint.show()
	var names := {"child": "牵起弟弟的手", "relic": "查看旅行手记", "light": "看看光里的脚印", "sign": "读路牌", "enemy": "反击沙蝎"}
	hud.interact_button.text = names.get(current_target, "靠近线索")
	hud.interact_button.disabled = current_target.is_empty()
	hud.stick_vector = stick
	hud.danger = maxf(damage_flash, 0.45 if enemy_phase == "warning" else 0)
	hud.queue_redraw()

func _on_action(action: String) -> void:
	match action:
		"quality":
			hud.set_quality((hud.quality_index + 1) % 3)
			var display := ConfigFile.new()
			display.set_value("display", "quality", hud.quality_index)
			display.save("user://third_display.cfg")
			_last_view = Vector2.ZERO
			_update_render_size()
		"interact": interact()
		"pause":
			if mode != "playing": return
			mode = "paused"
			reset_input()
			hud.show_card("在沙谷歇一会儿", "移动与危险已暂停。恢复后点击场景继续观察。", "继续旅程", "返回首页", false, true)
		"menu":
			if mode != "playing": return
			mode = "menu_confirm"
			reset_input()
			hud.show_card("返回首页？", "本关保存的是入口检查点。再次进入第三关会从沙谷入口开始。", "返回首页", "留在这里")
		"primary":
			match mode:
				"welcome", "rescue", "paused": _resume()
				"recover":
					body.position = checkpoint + Vector3(0, 0.1, 0)
					hp = max_hp
					enemy_phase = "idle"
					_resume()
				"menu_confirm", "complete": menu_requested.emit()
				"ending1", "ending2": _finish_ending()
				"replay_confirm": replay_requested.emit()
		"secondary":
			match mode:
				"paused": menu_requested.emit()
				"menu_confirm": _resume()
				"complete":
					mode = "replay_confirm"
					hud.show_card("重温这一趟旅程？", "将从第一关重新出发。", "确认重玩", "留在合照")
				"replay_confirm": _finish_ending()

func _resume() -> void:
	reset_input()
	mode = "playing"
	hud.close_card()
	wind_audio.stream_paused = false

func _begin_ending() -> void:
	mode = "ending1"
	reset_input()
	ending_timer = 0
	# Film from inside the courtyard; the south side is occupied by the tower.
	body.position = ThirdMap.world(ThirdMap.CAMP) + Vector3(0, 0.1, -6)
	# Preserve the family's horizontal framing on narrow portrait screens.
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	world.camp_marker.hide()
	yaw = PI
	pitch = 0
	body.rotation.y = yaw
	camera.rotation.x = 0
	hud.show_card("营地的灯，一直亮着", "妈妈：“都回来了。”\n\n哥哥：“这次，我们一起走。”", "跳过演出，查看合照")
	hud.overlay.color = Color(0.04, 0.03, 0.02, 0.4)
	completed.emit()
	AudioManager.play_victory()

func _next_ending() -> void:
	if mode == "ending1":
		mode = "ending2"
		hud.show_card("一家四口，再次出发", "风停了，远处的沙丘渐渐安静。\n\n这一次，没有人再落在后面。", "跳过演出，查看合照")
	else: _finish_ending()

func _finish_ending() -> void:
	mode = "complete"
	reset_input()
	hud.overlay.color = Color(0.065, 0.055, 0.045, 0.96)
	var found := "你还找到了那本旅行手记。" if relic_found else "石窟里的小秘密，留待下一次旅行。"
	if golden_clue.found: found = "你换了个角度，看见金光照亮的小脚印，也找到了弟弟。"
	hud.show_card("敦煌迷途 · 全家团聚", "风沙会抹去脚印，但我们总会找到彼此。\n\n" + found, "返回首页", "重温旅程", true)
