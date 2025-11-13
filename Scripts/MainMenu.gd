extends Control

@onready var title_lbl: Label = $CenterContainer/Panel/VBoxContainer/Title
@onready var play_btn: Button = $CenterContainer/Panel/VBoxContainer/PlayButton
@onready var help_btn: Button = $CenterContainer/Panel/VBoxContainer/HelpButton
@onready var quit_btn: Button = $CenterContainer/Panel/VBoxContainer/QuitButton
@onready var credits_btn: Button = $CenterContainer/Panel/VBoxContainer/CreditsButton

func _ready() -> void:
	title_lbl.text = "Recycla City"
	play_btn.pressed.connect(_on_play_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	help_btn.pressed.connect(_on_help_pressed)
	credits_btn.pressed.connect(_on_credits_pressed)

func _on_play_pressed() -> void:
	Game.start_game()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_help_pressed() -> void:
	Game.help_menu()
	
func _on_credits_pressed() -> void:
	Game.help_menu()
