extends Control

@onready var vbox: VBoxContainer      = $CenterContainer/Panel/VBoxContainer
@onready var title_lbl: Label         = vbox.get_node("Title")
@onready var sc: ScrollContainer      = vbox.get_node("ScrollContainer")
@onready var body: RichTextLabel      = sc.get_node("Body")
@onready var back_hbox: HBoxContainer = vbox.get_node("HBoxContainer")
@onready var back_btn: Button         = back_hbox.get_node("BackButton")
@onready var panel: Panel             = $CenterContainer/Panel

func _ready() -> void:
	# Fondo personalizado para el texto de créditos
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.95, 0.95, 0.95, 0.35) # gris muy claro y casi transparente
	fondo.content_margin_left = 24
	fondo.content_margin_right = 24
	fondo.content_margin_top = 18
	fondo.content_margin_bottom = 18
	fondo.corner_radius_top_left = 12
	fondo.corner_radius_top_right = 12
	fondo.corner_radius_bottom_left = 12
	fondo.corner_radius_bottom_right = 12
	fondo.set_border_width(0, 2) # izquierda
	fondo.set_border_width(1, 2) # arriba
	fondo.set_border_width(2, 2) # derecha
	fondo.set_border_width(3, 2) # abajo
	fondo.border_color = Color(0.8, 0.8, 0.6)
	body.add_theme_stylebox_override("normal", fondo)
	# Título
	title_lbl.text = "Créditos y Atribuciones"
	title_lbl.add_theme_color_override("font_color", Color.BLACK)

	# Tamaño mínimo para que no se aplaste
	panel.custom_minimum_size = Vector2(720, 480)

	# ❌ Quitar fondo del Panel (sin color) pero con padding
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)

	# Solo el ScrollContainer crece en alto
	title_lbl.size_flags_vertical = 0
	back_hbox.size_flags_vertical = 0

	# ScrollContainer ocupa espacio
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size.y = 320

	# RichTextLabel configurado
	body.bbcode_enabled = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.fit_content = true
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size.x = 620
	body.add_theme_color_override("default_color", Color.BLACK)
	body.bbcode_text = CREDITS_TEXT   # ⬅️ importante para que se vea el BBCode
	if not body.meta_clicked.is_connected(_on_meta_clicked):
		body.meta_clicked.connect(_on_meta_clicked)

	# Botón
	if not back_btn.pressed.is_connected(_on_back):
		back_btn.pressed.connect(_on_back)

	# Espera 1 frame para que el layout calcule tamaños
	await get_tree().process_frame
	print("[CREDITS] panel=", panel.size, " sc=", sc.size, " body=", body.size, " text_len=", body.text.length())

func _on_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))

func _on_back() -> void:
	Game.go_main_menu()
const CREDITS_TEXT := """
[b]Atribuciones[/b]
[i]Este proyecto utiliza recursos con licencia de sus autores. Donde aplica CC-BY (p. ej. “Poly by Google”),
se incluye Título — Autor — Fuente.[/i]

[b]Camiones de basura[/b]
• [url=https://sketchfab.com/3d-models/garbage-truck-abc7705b46bd4e9fa7a245ea15f9d89a#download]Garbage Truck[/url] — iedalton — vía Sketchfab — [i]licencia en la página[/i].

[b]Basura[/b]
• [url=https://poly.pizza/m/eitNk4I4R1]Trash Bags[/url] — Quaternius — vía Poly Pizza — [i]licencia en la página[/i]. 
• [url=https://poly.pizza/m/jYrMKg2Q7C]Trash Bag[/url] — Quaternius — vía Poly Pizza — [i]licencia en la página[/i].
• [url=https://poly.pizza/m/JjC5l1gXMo]Can Broken[/url] — Quaternius — vía Poly Pizza — [i]licencia en la página[/i].
• [url=https://poly.pizza/m/MWvBbxYzJ]Soda Can Crushed[/url] — Kenney — vía Poly Pizza — [i]licencia en la página[/i].
• [url=https://poly.pizza/m/KOLcdOATw6]Soda Can[/url] — Kenney — vía Poly Pizza — [i]licencia en la página[/i].
• [url=https://poly.pizza/m/KpxDpidn1Z]Water Bottle[/url] — Quaternius — vía Poly Pizza — [i]licencia en la página[/i].
• [url=https://poly.pizza/m/V9KbWC8Vd6]Cardboard Boxes[/url] — Quaternius — vía Poly Pizza — [i]licencia en la página[/i].
• [url=https://poly.pizza/m/fxU6_KtzTiX]Rubbish[/url] — Poly by Google — vía Poly Pizza — [b]CC-BY[/b].

[b]Contenedores de basura[/b]
• [url=https://poly.pizza/m/IvvdNqXmAW]Trash Container Open[/url] — Quaternius — vía Poly Pizza — [i]licencia en la página[/i].
• [url=https://poly.pizza/m/PKsbolkZSr]Dumpster[/url] — Quaternius — vía Poly Pizza — [i]licencia en la página[/i].
• [url=https://poly.pizza/m/ASkP8wjEGs]Dumpster[/url] — KolosStudios — vía Poly Pizza — [i]licencia en la página[/i].
• [url=https://poly.pizza/m/3F0yCeWeTZP]Dumpster[/url] — Poly by Google — vía Poly Pizza — [b]CC-BY[/b].

[b]Vehículos / NPC[/b]
• [url=https://poly.pizza/m/BG0KAhmGDt]Coche hatchback[/url] — Kay Lousberg — vía Poly Pizza — [i]licencia en la página[/i].

[b]Edificios y entorno[/b]
• [url=https://oxycodonee.itch.io/gameready-low-poly-building-pack-part-2]Game-Ready Low Poly Building Pack Part 2[/url] — oxycodonee (itch.io) — [i]licencia en la página[/i].
• [url=https://oxycodonee.itch.io/bundle-buildings?download]Bundle Buildings[/url] — oxycodonee (itch.io) — [i]licencia en la página[/i].
• [url=https://sketchfab.com/3d-models/low-poly-public-buildings-pack-b51a75af7f4e41579ec16e28ee96b676]Low-Poly Public Buildings Pack[/url] — vía Sketchfab — [i]licencia en la página[/i].

[b]Otros recursos[/b]
• [url=https://poly.pizza/m/0-7U_RTHzKT]Jungle gym[/url] — Poly by Google — vía Poly Pizza — [b]CC-BY[/b].
• [url=https://poly.pizza/m/1VmmK6Gus8f]Ferris wheel[/url] — Poly by Google — vía Poly Pizza — [b]CC-BY[/b].
• [url=https://poly.pizza/m/4NYtgQKdVMy]Parking Lot[/url] — Alex Safayan — vía Poly Pizza — [b]CC-BY[/b].
• [url=https://poly.pizza/m/6TZCkGh76m5]Football stadium[/url] — Poly by Google — vía Poly Pizza — [b]CC-BY[/b].
• [url=https://poly.pizza/m/85FpUr2fHkH]Basketball court[/url] — Poly by Google — vía Poly Pizza — [b]CC-BY[/b].
• [url=https://poly.pizza/m/ee0cso-KZnC]Play Structure[/url] — Emmett “TawpShelf” Baber — vía Poly Pizza — [b]CC-BY[/b].
• [url=https://poly.pizza/m/fBaX63DY389]Seesaw[/url] — Poly by Google — vía Poly Pizza — [b]CC-BY[/b].
• [url=https://poly.pizza/m/0cRW-BhHD16]Gazebo[/url] — Poly by Google — vía Poly Pizza — [b]CC-BY[/b].
• [url=https://poly.pizza/m/sPY1OPVCAX]Town Center Second Age[/url] — Quaternius — vía Poly Pizza — [i]CC0 (dominio público)[/i].
• [url=https://poly.pizza/m/dIsZyy2FUY-]Skyscraper[/url] — Poly by Google — vía Poly Pizza — [b]CC-BY[/b].
• [url=https://poly.pizza/m/01lqee-dZAr]Apartment building[/url] — Poly by Google — vía Poly Pizza — [b]CC-BY[/b].
• [url=https://poly.pizza/m/8s2mfCSvF6t]Dumpster[/url] — Jarlan Perez — vía Poly Pizza — [b]CC-BY[/b].

"""
