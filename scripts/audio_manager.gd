extends Node

var players: Array[AudioStreamGeneratorPlayback] = []
var generators: Array[AudioStreamPlayer] = []
const MAX_PLAYERS := 8
const SAMPLE_RATE := 22050

func _ready():
	for i in MAX_PLAYERS:
		var gen = AudioStreamPlayer.new()
		var stream = AudioStreamGenerator.new()
		stream.mix_rate = SAMPLE_RATE
		stream.buffer_length = 0.1
		gen.stream = stream
		gen.bus = "Master"
		add_child(gen)
		generators.append(gen)
		players.append(null)

func _get_free_index() -> int:
	for i in generators.size():
		if not generators[i].playing:
			return i
	return 0

func _play_tone(freq: float, duration: float, volume: float = 0.3, waveform: int = 0) -> void:
	var idx = _get_free_index()
	var gen = generators[idx]
	gen.play()
	var playback = gen.get_stream_playback() as AudioStreamGeneratorPlayback
	players[idx] = playback
	_generate_tone(playback, freq, duration, volume, waveform)

func _generate_tone(playback: AudioStreamGeneratorPlayback, freq: float, duration: float, volume: float, waveform: int) -> void:
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
		elif t > 0.7:
			envelope = (1.0 - t) / 0.3
		sample *= volume * envelope
		playback.push_frame(Vector2(sample, sample))
		phase += increment

func play_hit() -> void:
	_play_tone(200, 0.1, 0.4, 1)
	await get_tree().create_timer(0.05).timeout
	_play_tone(150, 0.08, 0.3, 1)

func play_pickup() -> void:
	_play_tone(523, 0.08, 0.3, 0)
	await get_tree().create_timer(0.06).timeout
	_play_tone(659, 0.08, 0.3, 0)
	await get_tree().create_timer(0.06).timeout
	_play_tone(784, 0.12, 0.35, 0)

func play_level_start() -> void:
	_play_tone(392, 0.15, 0.3, 0)
	await get_tree().create_timer(0.12).timeout
	_play_tone(523, 0.15, 0.3, 0)
	await get_tree().create_timer(0.12).timeout
	_play_tone(659, 0.2, 0.35, 0)

func play_victory() -> void:
	_play_tone(523, 0.12, 0.35, 0)
	await get_tree().create_timer(0.1).timeout
	_play_tone(659, 0.12, 0.35, 0)
	await get_tree().create_timer(0.1).timeout
	_play_tone(784, 0.12, 0.35, 0)
	await get_tree().create_timer(0.1).timeout
	_play_tone(1047, 0.3, 0.4, 0)

func play_death() -> void:
	_play_tone(440, 0.15, 0.35, 1)
	await get_tree().create_timer(0.12).timeout
	_play_tone(349, 0.15, 0.3, 1)
	await get_tree().create_timer(0.12).timeout
	_play_tone(294, 0.2, 0.3, 1)
	await get_tree().create_timer(0.15).timeout
	_play_tone(220, 0.4, 0.35, 1)

func play_step() -> void:
	_play_tone(80, 0.05, 0.15, 2)

func play_wall_hit() -> void:
	_play_tone(100, 0.06, 0.2, 1)
