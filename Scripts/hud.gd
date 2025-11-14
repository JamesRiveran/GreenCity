extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var timer_label: Label = $TimerLabel
@onready var game_timer: Timer = $GameTimer

@onready var collected_bar: ProgressBar = $CollectedBar
@onready var collected_label: Label = $CollectedBar/CountLabel
@onready var score_label: Label = $ScoreLabel
@onready var icon_general  : TextureRect = $Control/Trash/basuraGeneral
@onready var icon_plastico : TextureRect = $Control/Trash/basuraPlastico
@onready var icon_vidrio   : TextureRect = $Control/Trash/basuraVidrio
@onready var icon_metal    : TextureRect = $Control/Trash/basuraMetal
@onready var icon_papel    : TextureRect = $Control/Trash/basuraPapel

signal time_over


func _ready() -> void:
	update_health(health_bar.max_value, health_bar.max_value)
	update_collected(0, 1)  # inicializar barra
	update_score(0)         # inicializar texto
	hide_all_trash_icons()
	game_timer.timeout.connect(_on_game_timer_timeout)

	_update_timer_label()

	set_process(true)


func _process(_delta: float) -> void:
	_update_timer_label()

func update_collected(value: int, max_value: int) -> void:
	if not collected_bar:
		return
		
	# Caso sin límite
	if max_value <= 0:
		collected_bar.visible = true
		collected_bar.value = 1
		collected_bar.max_value = 1  # Evita divisiones por cero
		collected_label.text = "%d / ∞" % value
	else:
		collected_bar.max_value = max_value
		collected_bar.value = value
		collected_label.text = "%d / %d" % [value, max_value]

	# Color fijo para evitar confusión con la barra de vida
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.2, 0.6, 1.0)  # azul suave
	stylebox.corner_radius_top_left = 4
	stylebox.corner_radius_top_right = 4
	stylebox.corner_radius_bottom_left = 4
	stylebox.corner_radius_bottom_right = 4
	collected_bar.add_theme_stylebox_override("fill", stylebox)


func update_score(value: int) -> void:
	if not score_label:
		return
	score_label.text = "🏆 Puntaje: %d" % value

func update_health(value: int, max_value: int) -> void:
	if not health_bar:
		return

	health_bar.max_value = max_value
	health_bar.value = value

	var ratio := float(value) / float(max_value)
	var fill_color: Color

	if ratio > 0.6:
		fill_color = Color(0, 1, 0)      
	elif ratio > 0.3:
		fill_color = Color(1, 1, 0)   
	else:
		fill_color = Color(1, 0, 0)     

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = fill_color
	stylebox.corner_radius_top_left = 4
	stylebox.corner_radius_top_right = 4
	stylebox.corner_radius_bottom_left = 4
	stylebox.corner_radius_bottom_right = 4
	health_bar.add_theme_stylebox_override("fill", stylebox)

func hide_all_trash_icons():
	icon_general.visible = false
	icon_plastico.visible = false
	icon_vidrio.visible = false
	icon_metal.visible = false
	icon_papel.visible = false


func show_trash_icon(trash_type: String):
	hide_all_trash_icons()

	match trash_type:
		"general":
			icon_general.visible = true
		"plastico":
			icon_plastico.visible = true
		"vidrio":
			icon_vidrio.visible = true
		"metal":
			icon_metal.visible = true
		"papel":
			icon_papel.visible = true


func _update_timer_label() -> void:
	var time_left: float = game_timer.time_left
	var total_seconds: int = int(time_left)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60

	timer_label.text = "⏱ Tiempo: %02d:%02d" % [minutes, seconds]

	if time_left > game_timer.wait_time * 0.5:
		timer_label.add_theme_color_override("font_color", Color.WHITE)
	elif time_left > game_timer.wait_time * 0.2:
		timer_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		timer_label.add_theme_color_override("font_color", Color.RED)


func _on_game_timer_timeout() -> void:
	timer_label.text = "⏰ ¡Tiempo agotado!"
	timer_label.add_theme_color_override("font_color", Color.RED)
	print("[HUD] ¡Se acabó el tiempo!")
	emit_signal("time_over")
	
func add_time(extra_seconds: float) -> void:
	if not game_timer:
		return
	
	var remaining := game_timer.time_left + extra_seconds
	
	# Reiniciar el temporizador con el nuevo tiempo
	game_timer.stop()
	game_timer.start(remaining)
	print("[Hud] Tiempo agregado: +", extra_seconds, "s (nuevo total:", remaining, "s)")
	
	_update_timer_label()
