extends Control

@onready var title_lbl: Label = $CenterContainer/Panel/VBoxContainer/Title
@onready var score_lbl: Label = $CenterContainer/Panel/VBoxContainer/ScoreLabel
@onready var best_lbl:  Label = $CenterContainer/Panel/VBoxContainer/BestLabel
@onready var retry_btn: Button = $CenterContainer/Panel/VBoxContainer/Buttons/RetryButton
@onready var menu_btn:  Button = $CenterContainer/Panel/VBoxContainer/Buttons/MenuButton

func _ready() -> void:
	title_lbl.text = "Game Over"
	score_lbl.text = "Puntaje: %d" % Game.last_score
	best_lbl.text  = "Mejor puntaje: %d" % Game.best_score
	retry_btn.text = "Reintentar"
	menu_btn.text  = "Menú"
	retry_btn.pressed.connect(_on_retry_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)

func _on_retry_pressed() -> void:
	Game.start_game()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(Game.MAIN_MENU)
