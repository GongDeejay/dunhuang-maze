class_name GameState
extends RefCounted

enum State { DIFFICULTY_SELECT, PLAYING, PAUSED }

const DIFFICULTY_OPTIONS: Array[String] = ["easy", "normal", "hard"]
const DIFFICULTY_NAMES: Dictionary = {
	"easy": "行者",
	"normal": "商旅",
	"hard": "亡命",
}

var state: State = State.DIFFICULTY_SELECT
var selected_difficulty: String = "normal"
var game_won: bool = false
var game_over: bool = false
var current_level_index: int = 0
var move_count: int = 0

func is_playing() -> bool:
	return state == State.PLAYING

func is_difficulty_select() -> bool:
	return state == State.DIFFICULTY_SELECT

func is_paused() -> bool:
	return state == State.PAUSED

func can_move() -> bool:
	return is_playing() and not game_won and not game_over

func start_game() -> void:
	state = State.PLAYING
	game_won = false
	game_over = false

func return_to_menu() -> void:
	state = State.DIFFICULTY_SELECT

func toggle_pause() -> void:
	if state == State.PLAYING:
		state = State.PAUSED
	elif state == State.PAUSED:
		state = State.PLAYING

func reset_round() -> void:
	game_won = false
	game_over = false
	move_count = 0

func cycle_difficulty(direction: int) -> void:
	var idx := DIFFICULTY_OPTIONS.find(selected_difficulty)
	idx = (idx + direction + DIFFICULTY_OPTIONS.size()) % DIFFICULTY_OPTIONS.size()
	selected_difficulty = DIFFICULTY_OPTIONS[idx]

func get_difficulty_name() -> String:
	return DIFFICULTY_NAMES.get(selected_difficulty, selected_difficulty)
