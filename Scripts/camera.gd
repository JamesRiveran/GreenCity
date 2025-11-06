extends Camera3D

@onready var truck = $"../Player"  # Ajusta la ruta si tu nodo tiene otro nombre
@export var height: float = 5.0    # Qué tan alto está la cámara
@export var distance: float = 10.0 # Qué tan lejos está detrás del camión
@export var follow_speed: float = 5.0  # Qué tan rápido sigue al camión

func _process(delta):
	if truck == null:
		return

	# Posición base del camión
	var truck_pos = truck.global_transform.origin

	# Dirección hacia adelante del camión (sin rotación vertical)
	var forward = truck.global_transform.basis.z.normalized()

	# Calculamos la posición deseada de la cámara
	var desired_pos = truck_pos - forward * distance + Vector3(0, height, 0)

	# Movimiento suave hacia la posición deseada
	global_transform.origin = global_transform.origin.lerp(desired_pos, delta * follow_speed)

	# Hacer que mire hacia adelante del camión
	var look_target = truck_pos + forward * 10.0
	look_at(look_target, Vector3.UP)
