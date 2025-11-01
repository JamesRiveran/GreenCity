extends VehicleBody3D

@export var front_left_wheel: VehicleWheel3D
@export var front_right_wheel: VehicleWheel3D
@export var rear_left_wheel: VehicleWheel3D
@export var rear_right_wheel: VehicleWheel3D

@export var engine_force_strength: float = 1200.0
@export var brake_force_strength: float = 60.0
@export var steering_angle_max: float = 0.40

@export var key_forward: Key = Key.KEY_W
@export var key_backward: Key = Key.KEY_S
@export var key_left: Key = Key.KEY_A
@export var key_right: Key = Key.KEY_D
@export var key_brake: Key = Key.KEY_SPACE

# --- Vida del vehículo ---
@export var max_health: int = 100
var health: int = max_health

# --- Daño por colisiones con StaticBody3D ---
@export var wall_damage: int = 10
@export var wall_range: int = 1
@export var wall_cooldown: float = 0.30
@export var static_bodies_nodes: Array[NodePath] = []  # Lista de nodos StaticBody3D para evaluar colisiones

var _static_bodies: Array = []  # Array para almacenar los StaticBody3D
var _wall_hit_cd_until := 0.0

func _ready():
	# Inicializar la lista de StaticBodies
	_static_bodies.clear()
	for node_path in static_bodies_nodes:
		var node = get_node_or_null(node_path)
		if node and node is StaticBody3D:
			_static_bodies.append(node)
			print("[Car:%s] StaticBody detectado: %s" % [name, node.name])

	# Vida inicial
	health = max_health
	print("[Car:%s] Vida inicial: %d" % [name, health])

func _physics_process(_delta: float) -> void:
	if not front_left_wheel or not front_right_wheel:
		return

	var accel := 0.0
	var steer := 0.0
	var brake_force := 0.0

	if Input.is_key_pressed(key_forward):
		accel = 2
	elif Input.is_key_pressed(key_backward):
		accel = -2

	if Input.is_key_pressed(key_brake):
		brake_force = brake_force_strength

	if Input.is_key_pressed(key_left):
		steer = 1.0
	elif Input.is_key_pressed(key_right):
		steer = -1.0

	engine_force = accel * engine_force_strength

	var steer_value := steer * steering_angle_max
	front_left_wheel.steering = steer_value
	front_right_wheel.steering = steer_value

	for wheel in [front_left_wheel, front_right_wheel, rear_left_wheel, rear_right_wheel]:
		if wheel:
			wheel.brake = brake_force

	# Detectar colisión con StaticBodies3D
	for static_body in _static_bodies:
		if is_colliding_with_static_body(static_body):
			_try_wall_damage()

# --- Daño y colisiones ---

func apply_damage(amount: int) -> void:
	health = max(health - amount, 0)
	print("[Car:%s] Daño: %d | Vida: %d" % [name, amount, health])
	if health == 0:
		print("[Car:%s] ¡Vehículo destruido!" % name)

# Función para detectar la colisión con un StaticBody3D
func is_colliding_with_static_body(static_body: StaticBody3D) -> bool:
	var vehicle_position = global_transform.origin
	var distance = vehicle_position.distance_to(static_body.global_transform.origin)
	if distance < wall_range:  # Distancia de colisión (ajustar según lo necesites)
		return true
	return false

func _try_wall_damage() -> void:
	var now := Time.get_unix_time_from_system()
	if now < _wall_hit_cd_until:
		return
	apply_damage(wall_damage)
	_wall_hit_cd_until = now + wall_cooldown
