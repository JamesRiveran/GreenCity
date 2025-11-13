extends Node
class_name GameManager

var last_score: int = 0
var best_score: int = 0
var last_time: float = 0.0

const MAIN_MENU := "res://Assets/Scenes/MainMenu.tscn"   # AJUSTA RUTAS REALES
const GAME_SCENE := "res://Assets/Scenes/root.tscn"
const WIN_MENU  := "res://Assets/Scenes/WinMenu.tscn"
const LOSE_MENU := "res://Assets/Scenes/LoseMenu.tscn"
const HELP_MENU := "res://Assets/Scenes/HelpMenu.tscn"

func _change_to(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("[Game] No existe: %s" % path)
		return
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("[Game] Dependencias rotas: %s" % path)
		return
	get_tree().change_scene_to_packed(packed)

func start_game() -> void:
	last_score = 0
	last_time = 0.0
	call_deferred("_change_to", GAME_SCENE)

func win(score: int, time_elapsed: float = 0.0) -> void:
	last_score = score
	last_time = time_elapsed
	if score > best_score:
		best_score = score
	call_deferred("_change_to", WIN_MENU)

func lose(score: int, time_elapsed: float = 0.0) -> void:
	last_score = score
	last_time = time_elapsed
	if score > best_score:
		best_score = score
	call_deferred("_change_to", LOSE_MENU)

# Helper para el botón "Menú"
func go_main_menu() -> void:
	call_deferred("_change_to", MAIN_MENU)

# Helper para el botón "Menú"
func help_menu() -> void:
	call_deferred("_change_to", HELP_MENU)
