extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var timer_label: Label = $TimerLabel
@onready var game_timer: Timer = $GameTimer

@onready var collected_bar: ProgressBar = $CollectedBar
@onready var collected_label: Label = $CollectedBar/CountLabel
@onready var score_label: Label = $ScoreLabel

signal time_over


func _ready() -> void:
	update_health(health_bar.max_value, health_bar.max_value)
	update_collected(0, 1)  # inicializar barra
	update_score(0)         # inicializar texto

	game_timer.timeout.connect(_on_game_timer_timeout)

	_update_timer_label()

	set_process(true)


func _process(_delta: float) -> void:
	_update_timer_label()

func update_collected(value: int, max_value: int) -> void:
	if not collected_bar:
		return

	collected_bar.max_value = max_value
	collected_bar.value = value

	# Texto dentro de la barra
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
