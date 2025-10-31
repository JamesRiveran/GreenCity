extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	update_health(health_bar.max_value, health_bar.max_value)


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

	if ratio > 0.6 or ratio <= 0.4:
		health_bar.add_theme_color_override("font_color", Color.WHITE)
	else:
		health_bar.add_theme_color_override("font_color", Color.BLACK)

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = fill_color
	stylebox.corner_radius_top_left = 4
	stylebox.corner_radius_top_right = 4
	stylebox.corner_radius_bottom_left = 4
	stylebox.corner_radius_bottom_right = 4
	health_bar.add_theme_stylebox_override("fill", stylebox)
