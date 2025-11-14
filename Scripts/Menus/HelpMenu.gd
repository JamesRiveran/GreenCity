extends Control

@onready var panel: Panel                   = $CenterContainer/Panel
@onready var vbox: VBoxContainer            = panel.get_node("VBoxContainer")
@onready var title_lbl: Label               = vbox.get_node("Title")
@onready var sc: ScrollContainer            = vbox.get_node("ScrollContainer")
@onready var help_txt: RichTextLabel        = sc.get_node("HelpText")
@onready var btns_hbox: HBoxContainer       = vbox.get_node("Buttons")
@onready var menu_btn: Button               = btns_hbox.get_node("MenuButton")

func _ready() -> void:
	# Título
	title_lbl.text = "Ayuda"

	#  Quitar fondo del Panel y dejar padding
	panel.custom_minimum_size = Vector2(720, 480)
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)

	# Solo el ScrollContainer crece en altura
	title_lbl.size_flags_vertical = 0
	btns_hbox.size_flags_vertical = 0

	# ScrollContainer ocupa el espacio disponible
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size.y = 320

	# Configurar RichTextLabel
	help_txt.bbcode_enabled = true
	help_txt.autowrap_mode = TextServer.AUTOWRAP_WORD
	help_txt.fit_content = true
	help_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_txt.custom_minimum_size.x = 620
	help_txt.add_theme_color_override("default_color", Color.BLACK)
	help_txt.bbcode_text = HELP_TEXT

	# Botones
	
	if not menu_btn.pressed.is_connected(_on_menu_pressed):
		menu_btn.text = "Volver al menú"
		menu_btn.pressed.connect(_on_menu_pressed)

	# Esperar un frame para que el layout calcule tamaños
	await get_tree().process_frame

func _on_play_pressed() -> void:
	Game.start_game()

func _on_menu_pressed() -> void:
	Game.go_main_menu()

const HELP_TEXT := """
[b]Objetivo[/b]
Recolecta una bolsa a la vez y deposítala en el contenedor correcto (general, plástico, vidrio, papel, metal).

[b]Controles[/b]
W/S: acelerar/retroceder · A/D: girar · [b]ESPACIO[/b]: freno

[b]Reglas[/b]
• Depósito correcto suma puntos (puede agregar tiempo si está activado).
• Chocar resta vida; si la vida llega a 0 → [color=red]pierdes[/color].
• Se acaba el tiempo → [color=red]pierdes[/color].
"""
