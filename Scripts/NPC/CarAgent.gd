extends CharacterBody3D

# =========================
#  Parámetros de movimiento
# =========================
@export var speed: float = 8.0
@export var arrive_radius: float = 1.0
@export var turn_rate_deg: float = 360.0
@export var stop_on_raycast: bool = true

# =========================
#  Estado de navegación
# =========================
@export var current_node: Node3D
var _next_node: Node3D = null
var _last_node: Node3D = null

@export var agent: NavigationAgent3D = null
@export var ray_front: RayCast3D = null

# =========================
#  Detección de maniobra
# =========================
# Umbrales (en metros) para clasificar
@export var eps_forward: float = 1.0     # cuánto "adelante" cuenta como adelante
@export var eps_lateral: float = 0.5     # por debajo = recto; por encima = curva/giro
@export var eps_turn_forward: float = 0.6  # por debajo + lateral alto = giro
@export var uturn_angle_deg: float = 160.0 # ángulo para U-turn (aprox)

enum Maneuver { NONE, STRAIGHT, CURVE_LEFT, CURVE_RIGHT, TURN_LEFT, TURN_RIGHT, UTURN }
var _man_kind: int = Maneuver.NONE
var _man_angle: float = 0.0
var _incoming_dir: Vector3 = Vector3.ZERO   # rumbo del tramo anterior (en XZ)
var _prev_pos: Vector3 = Vector3.ZERO       # para medir desplazamiento real


@export var debug_curve_detection: bool = true

# =========================
#  Señales
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
		agent.avoidance_enabled = false

	if _next_node == null and current_node != null:
		_request_next()
		
	_prev_pos = global_transform.origin

# ===== API =====
func start_at_node(n: Node3D) -> void:
	current_node = n
	_request_next()

# ===== LOOP =====
func _physics_process(dt: float) -> void:
	if _next_node == null or agent == null:
		velocity = Vector3.ZERO
		return

	# Llegada
	var target_pos: Vector3 = _next_node.global_transform.origin
	if global_transform.origin.distance_to(target_pos) <= arrive_radius:
		_on_arrive_to_next()
		return

	# Guía (usar agente; si aún no hay path, ir directo)
	var guide: Vector3
	var path: PackedVector3Array = agent.get_current_navigation_path()
	if path.size() >= 2:
		guide = agent.get_next_path_position()
	else:
		guide = target_pos

	# Movimiento plano
	var to_vec: Vector3 = guide - global_transform.origin
	var dist: float = to_vec.length()
	var dir: Vector3 = (Vector3(to_vec.x, 0.0, to_vec.z).normalized()) if dist > 0.01 else Vector3.ZERO

	_smooth_face_towards(dir, dt)

	# Freno por Ray (ignora self)
	var local_speed: float = speed
	if stop_on_raycast and ray_front and ray_front.is_colliding():
		var col := ray_front.get_collider()
		if col != self:
			local_speed = 0.0

	velocity = (dir * local_speed) if (dist > 0.05 and local_speed > 0.0) else Vector3.ZERO
	velocity.y = 0.0
	move_and_slide()
	var now := global_transform.origin
	var disp := now - _prev_pos
	if disp.length_squared() > 0.0001:
		_incoming_dir = Vector3(disp.x, 0.0, disp.z).normalized()
		_prev_pos = now

# ===== NODOS =====
func _on_arrive_to_next() -> void:
	_last_node = current_node
	current_node = _next_node
	_request_next()

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
		print("[CarAgent] Falta NavigationAgent3D")
		return

	if _next_node != null and node_b != _next_node:
		emit_signal("destination_changed", current_node, node_b)

	_next_node = node_b
	agent.set_target_position(node_b.global_transform.origin)
	emit_signal("path_started", node_b)

	# Clasificar maniobra (para debug y futura curva)
	_classify_maneuver_to(node_b)

# ===== CLASIFICACIÓN DE MANIOBRA =====
func _classify_maneuver_to(node_b: Node3D) -> void:
	_man_kind = Maneuver.NONE
	_man_angle = 0.0
	if node_b == null:
		return

	var A: Vector3 = global_transform.origin
	var B: Vector3 = node_b.global_transform.origin
	var v: Vector3 = Vector3(B.x - A.x, 0.0, B.z - A.z)       # A->B en XZ
	var v_len: float = v.length()
	if v_len <= 0.0001:
		return

	# --- rumbo con prioridad: del tramo anterior ---
	var fwd: Vector3 = _incoming_dir

	# Fallbacks si aún no hemos tenido movimiento “real”
	if fwd == Vector3.ZERO:
		if _last_node != null and current_node != null:
			var from_last := current_node.global_transform.origin - _last_node.global_transform.origin
			fwd = Vector3(from_last.x, 0.0, from_last.z).normalized()
		elif agent and agent.get_current_navigation_path().size() >= 2:
			var ahead := agent.get_next_path_position() - global_transform.origin
			fwd = Vector3(ahead.x, 0.0, ahead.z).normalized()
		else:
			var vis := -global_transform.basis.z
			fwd = Vector3(vis.x, 0.0, vis.z).normalized()

	if fwd == Vector3.ZERO:
		return  # no podemos clasificar
	var right: Vector3 = Vector3(fwd.z, 0.0, -fwd.x)          # +X derecha respecto al fwd

	# Componentes: adelante/atrás y lateral derecha/izquierda
	var forward: float = v.dot(fwd)
	var lateral: float = v.dot(right)

	# Ángulo absoluto A->B vs rumbo (solo para U-turn/recto)
	var dotv: float = clamp(fwd.dot(v / v_len), -1.0, 1.0)
	var angle: float = rad_to_deg(acos(dotv))
	_man_angle = angle

	# Reglas:
	# 1) U-turn si está mayormente hacia atrás
	if angle >= uturn_angle_deg:
		_man_kind = Maneuver.UTURN
		if debug_curve_detection: print("⤵️  U-TURN (", round(angle), "°) hacia ", node_b.name)
		return

	# 2) Recto si lateral es pequeño
	if absf(lateral) <= eps_lateral and forward > 0.0:
		_man_kind = Maneuver.STRAIGHT
		if debug_curve_detection: 
			print("➡️  Recto (lat=", snapped(lateral, 0.01),
			", fwd=", snapped(forward, 0.01), ") hacia ", node_b.name)
		return

	# 3) Giro si casi no hay componente hacia adelante pero sí lateral
	if forward <= eps_turn_forward and absf(lateral) > eps_lateral:
		if lateral > 0.0:
			_man_kind = Maneuver.TURN_RIGHT
			if debug_curve_detection: 
				print("↱ Giro DERECHA (lat=", snapped(lateral, 0.01),
				  ", fwd=", snapped(forward, 0.01),
				  ", ang=", int(round(angle)), "°) hacia ", node_b.name)
		else:
			_man_kind = Maneuver.TURN_LEFT
			if debug_curve_detection: 
				print("↰ Giro IZQUIERDA (lat=", snapped(lateral, 0.01),
				  ", fwd=", snapped(forward, 0.01),
				  ", ang=", int(round(angle)), "°) hacia ", node_b.name)
		return

	# 4) Curva: hay componente hacia adelante y lateral significativo
	if forward > eps_forward and absf(lateral) > eps_lateral:
		if lateral > 0.0:
			_man_kind = Maneuver.CURVE_RIGHT
			if debug_curve_detection: 
				print("🟡 Curva DERECHA (fwd=", snapped(forward, 0.01),
				", lat=", snapped(lateral, 0.01), ") hacia ", node_b.name)
		else:
			_man_kind = Maneuver.CURVE_LEFT
			if debug_curve_detection: 
				print("🟡 Curva IZQUIERDA (fwd=", snapped(forward, 0.01),
				", lat=", snapped(lateral, 0.01), ") hacia ", node_b.name)
		return

	# Si nada calza, por defecto recto
	_man_kind = Maneuver.STRAIGHT
	if debug_curve_detection: print("➡️  Recto (fallback) hacia ", node_b.name)

# ===== GIRO SUAVE (visual)
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
