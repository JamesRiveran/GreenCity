extends Node3D

# Define ItemRotator como clase exportada
class_name ItemRotator

# --- ROTACIÓN ---
@export var rotation_enabled: bool = true
@export var rotation_speed: float = 45.0
@export var rotation_axis: Vector3 = Vector3.UP

# --- FLOTACIÓN ---
@export var floating_enabled: bool = false
@export var float_amplitude: float = 0.1  # altura máxima de movimiento
@export var float_speed: float = 2.0       # velocidad de oscilación

# --- VARIABLES INTERNAS ---
var _base_y: float
var _time: float = 0.0


func _ready():
	# Guardamos la altura inicial para usarla como punto de referencia
	_base_y = global_position.y


func _process(delta: float):
	# Rotación
	if rotation_enabled:
		rotate(rotation_axis, deg_to_rad(rotation_speed) * delta)
	
	# Flotación
	if floating_enabled:
		_time += delta * float_speed
		var offset_y = ((sin(_time) + 1.0) / 2.0) * float_amplitude
		var pos = global_position
		pos.y = _base_y + offset_y
		global_position = pos
