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
#  Clasificación (debug opcional)
# =========================
@export var eps_forward: float = 1.0
@export var eps_lateral: float = 0.5
@export var eps_turn_forward: float = 0.6
@export var uturn_angle_deg: float = 160.0
enum Maneuver { NONE, STRAIGHT, CURVE_LEFT, CURVE_RIGHT, TURN_LEFT, TURN_RIGHT, UTURN }
var _man_kind: int = Maneuver.NONE
var _man_angle: float = 0.0
var _incoming_dir: Vector3 = Vector3.ZERO
var _prev_pos: Vector3 = Vector3.ZERO
@export var debug_curve_detection: bool = true

# ===== Car-following (frenado progresivo) =====
@export var follow_safe_dist: float = 3.0        # umbral de parada
@export var follow_brake_range: float = 10.0     # dónde empezar a frenar ( > safe )
@export var max_accel: float = 25.0              # m/s^2 aprox. para acelerar
@export var max_decel: float = 50.0              # m/s^2 aprox. para frenar
@export var min_speed_floor: float = 0.5         # piso para evitar jitter si aún no toca parar
@export var speed_match: bool = true             # igualar velocidad del líder
@export var match_margin: float = 0.3            # pequeño extra para no quedarte pegado

var _cur_speed: float = 0.0                      # velocidad real aplicada (suavizada)

# =========================
#  Señales propias
# =========================
signal path_started(next_node: Node3D)
signal destination_changed(prev_node: Node3D, new_node: Node3D)
signal despawned(reason: String)

# =========================
#  Solo por señal del RoadNode *current*
# =========================
const STATE_SIGNAL := &"state_changed"  # (blocked: bool, is_sink: bool)
var _current_blocked: bool = false

func _on_current_state_changed(blocked: bool, _is_sink: bool) -> void:
	_current_blocked = blocked
	# print("[CarAgent] CURRENT ", current_node and current_node.name, " blocked=", blocked)

func _connect_state_signal_for_current() -> void:
	_disconnect_state_signal_for_current()
	if current_node:
		# Estado inicial
		var v = current_node.get("blocked")
		_current_blocked = (typeof(v) == TYPE_BOOL) and v
		# Conexión a la señal oficial
		if current_node.has_signal(STATE_SIGNAL):
			var cb := Callable(self, "_on_current_state_changed")
			if not current_node.is_connected(STATE_SIGNAL, cb):
				current_node.connect(STATE_SIGNAL, cb)

func _disconnect_state_signal_for_current() -> void:
	if current_node and current_node.has_signal(STATE_SIGNAL):
		var cb := Callable(self, "_on_current_state_changed")
		if current_node.is_connected(STATE_SIGNAL, cb):
			current_node.disconnect(STATE_SIGNAL, cb)

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

	# Conectar al estado del CURRENT antes de pedir siguiente
	if current_node != null:
		_connect_state_signal_for_current()
		_request_next()

	_prev_pos = global_transform.origin

# ===== API =====
func start_at_node(n: Node3D) -> void:
	_disconnect_state_signal_for_current()
	current_node = n
	_connect_state_signal_for_current()
	_request_next()

# ===== LOOP =====
func _physics_process(dt: float) -> void:
	if _next_node == null or agent == null:
		velocity = Vector3.ZERO
		return

	# Si el CURRENT está bloqueado, nos quedamos quietos (no confirmamos llegada ni avanzamos)
	if _current_blocked:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Llegada (solo si el CURRENT no está bloqueado)
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

	# ==== Control de velocidad con car-following ====
	var desired_speed: float = speed  # libre por defecto
	if stop_on_raycast and ray_front:
		var lead: Dictionary = _get_lead_info(dir)
		if bool(lead.get("has", false)) and float(lead.get("dist", INF)) < INF:
			var d: float = float(lead.get("dist", INF))
			var safe: float = max(0.1, follow_safe_dist)
			var start_brake: float = max(safe + 0.01, follow_brake_range)  # > safe

			if d <= safe:
				desired_speed = 0.0
			elif d < start_brake:
				var t: float = clamp((d - safe) / (start_brake - safe), 0.0, 1.0)
				desired_speed = speed * t
				if desired_speed < min_speed_floor:
					desired_speed = min_speed_floor
			else:
				desired_speed = speed

			if speed_match:
				var lead_speed_on_dir: float = float(lead.get("lead_speed", 0.0))
				desired_speed = min(desired_speed, lead_speed_on_dir + match_margin)

	# Suavizado por rampas
	if desired_speed > _cur_speed:
		_cur_speed = min(desired_speed, _cur_speed + max_accel * dt)
	else:
		_cur_speed = max(desired_speed, _cur_speed - max_decel * dt)

	# Aplicar movimiento
	var apply_speed: float = (_cur_speed if (dist > 0.05 and _cur_speed > 0.0) else 0.0)
	velocity = dir * apply_speed
	velocity.y = 0.0
	move_and_slide()

# ===== Frenado ====
func _get_lead_info(dir: Vector3) -> Dictionary:
	var info: Dictionary = {"has": false, "dist": INF, "lead_speed": 0.0}

	if not (stop_on_raycast and ray_front and ray_front.is_colliding()):
		return info

	var hit_point: Vector3 = ray_front.get_collision_point()
	var d: float = global_transform.origin.distance_to(
		Vector3(hit_point.x, global_transform.origin.y, hit_point.z)
	)
	var col := ray_front.get_collider()

	var lead_v: Vector3 = Vector3.ZERO
	if col != null:
		if col is CharacterBody3D:
			lead_v = (col as CharacterBody3D).velocity
		elif col.has_method("get") and col.has_property("velocity"):
			var v = col.get("velocity")
			if typeof(v) == TYPE_VECTOR3:
				lead_v = v

	var dir2D: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized()
	var lead_v2D: Vector3 = Vector3(lead_v.x, 0.0, lead_v.z)
	var lead_speed_on_dir: float = max(0.0, lead_v2D.dot(dir2D))

	info["has"] = true
	info["dist"] = d
	info["lead_speed"] = lead_speed_on_dir
	return info

# ===== NODOS =====
func _on_arrive_to_next() -> void:
	# Al llegar, el NEXT se vuelve CURRENT: reconectar a su señal y *luego* pedir nuevo NEXT.
	_disconnect_state_signal_for_current()
	_last_node = current_node
	current_node = _next_node
	_connect_state_signal_for_current()
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

	# (Opcional) clasificación de maniobra para debug
	_classify_maneuver_to(node_b)

# ===== CLASIFICACIÓN (debug opcional)
func _classify_maneuver_to(node_b: Node3D) -> void:
	_man_kind = Maneuver.NONE
	_man_angle = 0.0
	if node_b == null: return

	var A: Vector3 = global_transform.origin
	var B: Vector3 = node_b.global_transform.origin
	var v: Vector3 = Vector3(B.x - A.x, 0.0, B.z - A.z)
	var v_len: float = v.length()
	if v_len <= 0.0001: return

	var fwd: Vector3 = _incoming_dir
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

	if fwd == Vector3.ZERO: return
	var right: Vector3 = Vector3(fwd.z, 0.0, -fwd.x)

	var forward: float = v.dot(fwd)
	var lateral: float = v.dot(right)

	var dotv: float = clamp(fwd.dot(v / v_len), -1.0, 1.0)
	var angle: float = rad_to_deg(acos(dotv))
	_man_angle = angle

	if angle >= uturn_angle_deg:
		_man_kind = Maneuver.UTURN
		if debug_curve_detection: print("⤵️  U-TURN (", round(angle), "°) hacia ", node_b.name)
		return

	if absf(lateral) <= eps_lateral and forward > 0.0:
		_man_kind = Maneuver.STRAIGHT
		if debug_curve_detection:
			print("➡️  Recto (lat=", snapped(lateral, 0.01),
			", fwd=", snapped(forward, 0.01), ") hacia ", node_b.name)
		return

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
	_disconnect_state_signal_for_current()
	emit_signal("despawned", reason)
	queue_free()
