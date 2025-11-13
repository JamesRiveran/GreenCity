extends VehicleBody3D

# --- Ruedas ---
@export var front_left_wheel: VehicleWheel3D
@export var front_right_wheel: VehicleWheel3D
@export var rear_left_wheel: VehicleWheel3D
@export var rear_right_wheel: VehicleWheel3D

# --- Control del vehículo ---
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

# --- Daño configurable ---
@export var collision_damage: int = 10      # Daño por colisiones físicas (paredes, edificios)
@export var area_damage: int = 5            # Daño por entrar a un Area3D
@export var wall_cooldown: float = 0.30     # Tiempo mínimo entre daños consecutivos

# --- Colisiones a ignorar ---
@export var ignored_nodes: Array[String] = ["Floor"]

# --- Paredes y Áreas de daño ---
@export var wall_bodies: Array[NodePath] = []  # <--- aquí asignas tus StaticBody3D (paredes)
@export var wall_areas: Array[NodePath] = []   # opcional, si tienes Area3D también

# --- HUD y TrashManager (para mandar tiempo/score al perder) ---
@export var hud_path: NodePath
@onready var hud := get_node_or_null(hud_path)

@export var trash_manager_path: NodePath
@onready var trash_manager := get_node_or_null(trash_manager_path)

var _wall_hit_cd_until := 0.0
var has_lost: bool = false

func _ready():
	# Configurar estabilidad del vehículo
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -1, 0)

	# Habilitar detección de colisiones físicas
	contact_monitor = true
	max_contacts_reported = max(max_contacts_reported, 8)

	connect("body_entered", Callable(self, "_on_body_entered_vehicle"))

	# Conectar todas las áreas configuradas
	for path in wall_areas:
		var area := get_node_or_null(path)
		if area and area is Area3D:
			area.monitoring = true
			area.monitorable = true
			if area.has_signal("body_entered"):
				area.body_entered.connect(_on_wall_area_body_entered.bind(area))
			print("[Car:%s] Área de daño conectada: %s" % [name, area.name])
		else:
			print("[Car:%s] ⚠️ Área inválida en path: %s" % [name, str(path)])

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

# ---------- Utilidad para tiempo transcurrido (opcional) ----------
func _elapsed_time() -> float:
	if hud and hud.has_method("get_elapsed_time"):
		return float(hud.get_elapsed_time())
	if hud and hud.has_node("GameTimer"):
		var t := hud.get_node("GameTimer") as Timer
		if t and t.wait_time > 0.0:
			return t.wait_time - t.time_left
	return 0.0

# --- Daño y colisiones ---
func apply_damage(amount: int, source: Node = null) -> void:
	health = max(health - amount, 0)
	var src_name = source.name if source else "Desconocido"
	print("[Car:%s] 💥 Daño recibido: %d | Fuente: %s | Vida restante: %d" % [name, amount, src_name, health])

	# ✅ Actualizar barra de vida
	if hud and hud.has_method("update_health"):
		hud.update_health(health, max_health)

	if health == 0:
		print("[Car:%s] 🚗💀 ¡Vehículo destruido!" % name)
		if not has_lost:
			has_lost = true
			var score := 0
			if trash_manager and ("score" in trash_manager):
				score = trash_manager.score
			Game.lose(score, _elapsed_time())

# Cuando una de las áreas detecta que el coche entró
func _on_wall_area_body_entered(body: Node, area: Area3D) -> void:
	if body != self:
		return

	print("[Car:%s] ⚠️ Entró en área '%s' (daño %d)" % [name, area.name, area_damage])
	_try_damage_with_amount(area_damage, area)

func _on_body_entered_vehicle(body: Node) -> void:
	if body is StaticBody3D:
		var safe := false

		if "is_safe_surface" in body and body.get("is_safe_surface"):
			safe = true
		elif body.get_parent() and "is_safe_surface" in body.get_parent() and body.get_parent().get("is_safe_surface"):
			safe = true

		if safe:
			return

		print("[Car:%s] 🚧 Colisión con '%s' (daño %d)" % [name, body.name, collision_damage])
		_try_damage_with_amount(collision_damage, body)

func _try_damage_with_amount(amount: int, source: Node = null) -> void:
	var now := Time.get_unix_time_from_system()
	if now < _wall_hit_cd_until:
		return
	apply_damage(amount, source if source else self)
	_wall_hit_cd_until = now + wall_cooldown
