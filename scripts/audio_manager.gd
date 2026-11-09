extends Node

var players: Array[AudioStreamGeneratorPlayback] = []
var generators: Array[AudioStreamPlayer] = []
var sample_players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS := 8
const SAMPLE_RATE := 22050
const AUDIO_DIR := "res://assets/audio/"

func _ready():
	for i in MAX_PLAYERS:
		var gen = AudioStreamPlayer.new()
		var stream = AudioStreamGenerator.new()
		stream.mix_rate = SAMPLE_RATE
		stream.buffer_length = 0.1
		gen.stream = stream
		# Generated streams cannot use Web sample playback; force stream mode.
		gen.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		gen.bus = "Master"
		add_child(gen)
		generators.append(gen)
		players.append(null)

	for i in 4:
		var sample_player = AudioStreamPlayer.new()
		sample_player.bus = "Master"
		add_child(sample_player)
		sample_players.append(sample_player)

func _play_sample(name: String) -> bool:
	var extensions: Array[String] = [".wav", ".ogg", ".mp3"]
	for ext in extensions:
		var path: String = AUDIO_DIR + name + ext
		if ResourceLoader.exists(path):
			var idx: int = _get_free_sample_index()
			var player_node: AudioStreamPlayer = sample_players[idx]
			player_node.stream = load(path)
			player_node.play()
			return true
	return false

func _get_free_sample_index() -> int:
	for i in sample_players.size():
		if not sample_players[i].playing:
			return i
	return 0

func _get_free_index() -> int:
	for i in generators.size():
		if not generators[i].playing:
			return i
	return 0

func _play_tone(freq: float, duration: float, volume: float = 0.3, waveform: int = 0, decay_at: float = 0.7) -> void:
	var idx = _get_free_index()
	var gen = generators[idx]
	gen.play()
	var playback = gen.get_stream_playback() as AudioStreamGeneratorPlayback
	players[idx] = playback
	_generate_tone(playback, freq, duration, volume, waveform, decay_at)

func _generate_tone(playback: AudioStreamGeneratorPlayback, freq: float, duration: float, volume: float, waveform: int, decay_at: float = 0.7) -> void:
	var frames = int(SAMPLE_RATE * duration)
	var increment = freq / SAMPLE_RATE
	var phase = 0.0
	for i in frames:
		var sample = 0.0
		match waveform:
			0: sample = sin(phase * TAU)
			1: sample = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			2: sample = 2.0 * absf(fmod(phase, 1.0) - 0.5) - 0.5
			_: sample = sin(phase * TAU)
		var envelope = 1.0
		var t = float(i) / frames
		if t < 0.05:
			envelope = t / 0.05
		elif t > decay_at:
			envelope = (1.0 - t) / maxf(0.001, 1.0 - decay_at)
		sample *= volume * envelope
		playback.push_frame(Vector2(sample, sample))
		phase += increment

func play_hit() -> void:
	if _play_sample("hit"):
		return
	_play_tone(200, 0.1, 0.4, 1)
	await get_tree().create_timer(0.05).timeout
	_play_tone(150, 0.08, 0.3, 1)

func play_pickup() -> void:
	if _play_sample("pickup"):
		return
	_play_tone(523, 0.08, 0.3, 0)
	await get_tree().create_timer(0.06).timeout
	_play_tone(659, 0.08, 0.3, 0)
	await get_tree().create_timer(0.06).timeout
	_play_tone(784, 0.12, 0.35, 0)

func play_gate_open() -> void:
	# Short wooden latch sound, synthesized locally: no download or late callbacks.
	_play_tone(145, 0.09, 0.22, 2)

func play_level_start() -> void:
	if _play_sample("level_start"):
		return
	_play_tone(392, 0.15, 0.3, 0)
	await get_tree().create_timer(0.12).timeout
	_play_tone(523, 0.15, 0.3, 0)
	await get_tree().create_timer(0.12).timeout
	_play_tone(659, 0.2, 0.35, 0)

func play_victory() -> void:
	if _play_sample("victory"):
		return
	_play_tone(523, 0.12, 0.35, 0)
	await get_tree().create_timer(0.1).timeout
	_play_tone(659, 0.12, 0.35, 0)
	await get_tree().create_timer(0.1).timeout
	_play_tone(784, 0.12, 0.35, 0)
	await get_tree().create_timer(0.1).timeout
	_play_tone(1047, 0.3, 0.4, 0)

func play_death() -> void:
	if _play_sample("death"):
		return
	_play_tone(440, 0.15, 0.35, 1)
	await get_tree().create_timer(0.12).timeout
	_play_tone(349, 0.15, 0.3, 1)
	await get_tree().create_timer(0.12).timeout
	_play_tone(294, 0.2, 0.3, 1)
	await get_tree().create_timer(0.15).timeout
	_play_tone(220, 0.4, 0.35, 1)

func play_step() -> void:
	if _play_sample("step"):
		return
	_play_tone(80, 0.05, 0.15, 2)

func wall_hit_source() -> String:
	var extensions: Array[String] = [".ogg", ".wav", ".mp3"]
	for ext in extensions:
		var path: String = AUDIO_DIR + "wall_hit" + ext
		if ResourceLoader.exists(path):
			return path
	return ""


func wall_hit_fallback() -> Dictionary:
	return {"freq": 70.0, "duration": 0.09, "volume": 0.25, "decay_at": 0.12}


func play_mirror_back() -> void:
	if _play_sample("mirror_back"):
		return
	_play_tone(90.0, 0.08, 0.25, 0, 0.12)


func play_wall_hit() -> void:
	if wall_hit_source() != "":
		_play_sample("wall_hit")
		return
	var spec := wall_hit_fallback()
	_play_tone(float(spec.freq), float(spec.duration), float(spec.volume), 0, float(spec.decay_at))
