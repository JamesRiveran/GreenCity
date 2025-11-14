extends Control

@onready var score_lbl: Label = $CenterContainer/Panel/VBoxContainer/ScoreLabel
@onready var best_lbl:  Label = $CenterContainer/Panel/VBoxContainer/BestLabel
@onready var retry_btn: Button = $CenterContainer/Panel/VBoxContainer/Buttons/RetryButton
@onready var menu_btn:  Button = $CenterContainer/Panel/VBoxContainer/Buttons/MenuButton

func _ready() -> void:
	# Leer datos del autoload Game (GameManager)
	score_lbl.text = "Puntaje: %d" % Game.last_score
	best_lbl.text  = "Mejor puntaje: %d" % Game.best_score

	retry_btn.pressed.connect(_on_retry_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)

func _on_retry_pressed() -> void:
	Game.start_game()

func _on_menu_pressed() -> void:
	Game.go_main_menu()
