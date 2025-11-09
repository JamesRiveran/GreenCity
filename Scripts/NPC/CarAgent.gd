extends CharacterBody3D

# =========================
#  Parámetros de movimiento
# =========================
@export var speed: float = 8.0                # velocidad base (m/s)
@export var arrive_radius: float = 1.0        # radio de llegada al nodo B
@export var turn_rate_deg: float = 360.0      # vel. máx de giro (grados/seg) para suavizar
@export var stop_on_raycast: bool = true      # si el RayFront ve algo (no self), detiene

# =========================
#  Estado de navegación
# =========================
@export var current_node: Node3D              # nodo A (actual)
var _next_node: Node3D = null                 # nodo B (destino)
var _last_node: Node3D = null                 # último nodo visitado (para señales)

@export var agent: NavigationAgent3D = null
@export var ray_front: RayCast3D = null

# =========================
#  Señales de gestión
# =========================
signal path_started(next_node: Node3D)
signal destination_changed(prev_node: Node3D, new_node: Node3D)
signal despawned(reason: String)

# ===== INIT =====
func _ready() -> void:
	if ray_front:
		ray_front.exclude_parent = true
		ray_front.enabled = true
		ray_front.add_exception(self)

	if agent:
		agent.path_desired_distance = 0.5
		agent.target_desired_distance = max(0.4, arrive_radius * 0.8)
		agent.avoidance_enabled = false  # si aún no usas avoidance

	# Si se asignó A en el editor, pedir B
	if _next_node == null and current_node != null:
		_request_next()

# ===== API PÚBLICA =====
func start_at_node(n: Node3D) -> void:
	current_node = n
	_request_next()

# ===== CICLO DE FÍSICA =====
func _physics_process(dt: float) -> void:
	if _next_node == null or agent == null:
		velocity = Vector3.ZERO
		return

	# ¿Llegó a B?
	var target_pos: Vector3 = _next_node.global_transform.origin
	if global_transform.origin.distance_to(target_pos) <= arrive_radius:
		_on_arrive_to_next()
		return

	# Punto guía: usa el agente; si no hay path aún, ir directo a B
	var guide: Vector3
	var path: PackedVector3Array = agent.get_current_navigation_path()
	if path.size() >= 2:
		guide = agent.get_next_path_position()
	else:
		guide = target_pos

	# Dirección deseada en XZ
	var to_vec: Vector3 = guide - global_transform.origin
	var dist: float = to_vec.length()
	var dir: Vector3 = (Vector3(to_vec.x, 0.0, to_vec.z).normalized()) if dist > 0.01 else Vector3.ZERO

	# Giro suave
	_smooth_face_towards(dir, dt)

	# Freno simple con Ray (ignora self)
	var local_speed: float = speed
	if stop_on_raycast and ray_front and ray_front.is_colliding():
		var col := ray_front.get_collider()
		if col != self:
			local_speed = 0.0

	# Avance
	velocity = (dir * local_speed) if (dist > 0.05 and local_speed > 0.0) else Vector3.ZERO
	velocity.y = 0.0
	move_and_slide()

# ===== LÓGICA DE NODOS =====
func _on_arrive_to_next() -> void:
	_last_node = current_node
	current_node = _next_node
	_request_next()  # B pasa a ser A y pedimos nuevo B

func _request_next() -> void:
	if current_node == null:
		_despawn("invalid_current"); return

	if current_node.has_method("is_sink_node") and current_node.is_sink_node():
		_despawn("sink"); return

	if current_node.has_method("pick_next_neighbor"):
		var nxt: Node3D = current_node.pick_next_neighbor() as Node3D
		if nxt != null:
			_set_destination(nxt)
		else:
			_despawn("dead_end")
	else:
		_despawn("no_pick_method")

func _set_destination(node_b: Node3D) -> void:
	if agent == null:
		print("[CarAgent] No se estableció destino: falta NavigationAgent3D")
		return
	if _next_node != null and node_b != _next_node:
		emit_signal("destination_changed", current_node, node_b)

	_next_node = node_b
	agent.set_target_position(node_b.global_transform.origin)
	emit_signal("path_started", node_b)

# ===== UTILIDAD: GIRO SUAVE =====
func _smooth_face_towards(dir: Vector3, dt: float) -> void:
	if dir == Vector3.ZERO:
		return
	var fwd: Vector3 = -global_transform.basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var tgt: Vector3 = dir

	var cross_y: float = (fwd.x * tgt.z - fwd.z * tgt.x)
	var dot: float = clamp(fwd.x * tgt.x + fwd.z * tgt.z, -1.0, 1.0)
	var angle: float = atan2(cross_y, dot)

	var max_step: float = deg_to_rad(turn_rate_deg) * dt
	var step: float = clamp(angle, -max_step, max_step)
	rotate_y(step)

# ===== DESPAWN =====
func _despawn(reason: String) -> void:
	emit_signal("despawned", reason)
	queue_free()
