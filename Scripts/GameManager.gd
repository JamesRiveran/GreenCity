extends Node
class_name GameManager

var last_score: int = 0
var best_score: int = 0
var last_time: float = 0.0

const MAIN_MENU := "res://Assets/Scenes/ui/MainMenu.tscn"
const GAME_SCENE := "res://Assets/Scenes/root.tscn"   
const WIN_MENU  := "res://Assets/Scenes/ui/WinMenu.tscn"
const LOSE_MENU := "res://Assets/Scenes/ui/LoseMenu.tscn"

func start_game() -> void:
	last_score = 0
	last_time = 0.0
	get_tree().change_scene_to_file(GAME_SCENE)

func win(score: int, time_elapsed: float = 0.0) -> void:
	last_score = score
	last_time = time_elapsed
	if score > best_score: best_score = score
	get_tree().change_scene_to_file(WIN_MENU)

func lose(score: int, time_elapsed: float = 0.0) -> void:
	last_score = score
	last_time = time_elapsed
	if score > best_score: best_score = score
	get_tree().change_scene_to_file(LOSE_MENU)
