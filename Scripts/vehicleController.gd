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

# --- Daño por “wall” (Area3D) ---
@export var wall_damage: int = 10
@export var wall_cooldown: float = 0.30
@export var wall_area_path: NodePath      # arrastra aquí tu Area3D
@export var wall_area_name: String = ""   # opcional: si prefieres filtrar por nombre

@onready var wall_area: Area3D = get_node_or_null(wall_area_path)
var _wall_hit_cd_until := 0.0


func _ready():
	# Estabilidad del coche
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -1, 0)

	# (Opcional) habilitar monitor de contactos por si también chocas con cuerpos
	contact_monitor = true
	max_contacts_reported = max(max_contacts_reported, 4)

	# Conexión directa al Area3D de la wall
	if wall_area:
		wall_area.monitoring = true
		wall_area.monitorable = true
		if wall_area.has_signal("body_entered"):
			wall_area.body_entered.connect(_on_wall_area_body_entered)

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


# --- Daño y colisiones ---

func apply_damage(amount: int, source: Node = null) -> void:
	health = max(health - amount, 0)
	print("[Car:%s] Daño: %d | Vida: %d" % [name, amount, health])
	if health == 0:
		print("[Car:%s] ¡Vehículo destruido!" % name)


# Cuando el Area3D (wall) detecta que el coche entró
func _on_wall_area_body_entered(body: Node) -> void:
	if body != self:
		return
	_try_wall_damage()


# (Opcional) si no asignas wall_area_path y quieres filtrar por nombre desde el coche
func _on_area_entered_vehicle(area: Area3D) -> void:
	if wall_area and area != wall_area:
		return
	if wall_area == null and wall_area_name != "" and area.name != wall_area_name:
		return
	_try_wall_damage()


func _try_wall_damage() -> void:
	var now := Time.get_unix_time_from_system()
	if now < _wall_hit_cd_until:
		return
	apply_damage(wall_damage, wall_area if wall_area else self)
	_wall_hit_cd_until = now + wall_cooldown
