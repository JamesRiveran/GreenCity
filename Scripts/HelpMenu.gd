extends Control

@onready var title_lbl: Label  = $CenterContainer/Panel/VBoxContainer/Title
@onready var play_btn: Button  = $CenterContainer/Panel/VBoxContainer/Buttons/PlayButton
@onready var menu_btn: Button  = $CenterContainer/Panel/VBoxContainer/Buttons/MenuButton
@onready var help_txt: RichTextLabel = get_node_or_null("CenterContainer/Panel/VBoxContainer/ScrollContainer/HelpText") as RichTextLabel

func _ready() -> void:
	# Título
	if title_lbl:
		title_lbl.text = "Ayuda"

	# Texto de ayuda (si existe)
	if help_txt:
		help_txt.bbcode_enabled = true
		help_txt.autowrap_mode = TextServer.AUTOWRAP_WORD
		help_txt.text = """
[b]Objetivo[/b]
Recolecta una bolsa a la vez y deposítala en el contenedor correcto (general, plástico, vidrio, papel, metal).

[b]Controles[/b]
W/S o ↑/↓: acelerar/retroceder · A/D o ←/→: girar · SPACE: freno

[b]Reglas[/b]
• Depósito correcto suma puntos (puede agregar tiempo si está activado).
• Chocar resta vida; vida = 0 → pierdes.
• Se acaba el tiempo → pierdes.
"""

	if play_btn and not play_btn.pressed.is_connected(_on_play_pressed):
		play_btn.text = "Jugar"
		play_btn.pressed.connect(_on_play_pressed)

	if menu_btn and not menu_btn.pressed.is_connected(_on_menu_pressed):
		menu_btn.text = "Menú"
		menu_btn.pressed.connect(_on_menu_pressed)

func _on_play_pressed() -> void:
	Game.start_game()

func _on_menu_pressed() -> void:
	Game.go_main_menu()
