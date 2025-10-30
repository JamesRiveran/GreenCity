extends VehicleBody3D

# --- Wheels ---
@export var front_left_wheel: VehicleWheel3D
@export var front_right_wheel: VehicleWheel3D
@export var rear_left_wheel: VehicleWheel3D
@export var rear_right_wheel: VehicleWheel3D

# --- Adjustable parameters ---
@export var engine_force_strength: float = 1200.0
@export var brake_force_strength: float = 60.0
@export var steering_angle_max: float = 0.4

# --- Key bindings ---
@export var key_forward: Key = Key.KEY_W
@export var key_backward: Key = Key.KEY_S
@export var key_left: Key = Key.KEY_A
@export var key_right: Key = Key.KEY_D
@export var key_brake: Key = Key.KEY_SPACE

func _ready():
	# Reduce la probabilidad de vuelco
	center_of_mass = Vector3(0, -0.5, 0)

func _physics_process(delta: float) -> void:
	if not front_left_wheel or not front_right_wheel:
		return

	var accel := 0.0
	var steer := 0.0
	var brake_force := 0.0

	# Aceleración y reversa
	if Input.is_key_pressed(key_forward):
		accel = 1.0
	elif Input.is_key_pressed(key_backward):
		accel = -1.0

	# Freno
	if Input.is_key_pressed(key_brake):
		brake_force = brake_force_strength

	# Dirección
	if Input.is_key_pressed(key_left):
		steer = 1.0
	elif Input.is_key_pressed(key_right):
		steer = -1.0

	# Aplicar fuerza del motor
	engine_force = accel * engine_force_strength

	# Aplicar dirección (solo ruedas delanteras)
	var steer_value := steer * steering_angle_max
	front_left_wheel.steering = steer_value
	front_right_wheel.steering = steer_value

	# Aplicar freno a todas las ruedas
	for wheel in [front_left_wheel, front_right_wheel, rear_left_wheel, rear_right_wheel]:
		if wheel:
			wheel.brake = brake_force
