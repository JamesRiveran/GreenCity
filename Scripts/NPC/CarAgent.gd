extends CharacterBody3D

# =========================
#  Parámetros de movimiento
# =========================
@export var speed: float = 8.0                # velocidad base (m/s)
@export var arrive_radius: float = 1.0        # radio de llegada al nodo B
@export var turn_rate_deg: float = 360.0      # vel. máx de giro (grados/seg) para suavizar curvas
@export var stop_on_raycast: bool = true      # si el RayFront ve algo, detiene

# =========================
#  Estado de navegación
# =========================
@export var current_node: Node3D              # nodo A (actual)
var _next_node: Node3D = null                 # nodo B (destino)
var _last_node: Node3D = null                 # último nodo visitado (para señales)

@export var agent: NavigationAgent3D = null
@export var ray_front: RayCast3D = null

# =========================
#  Parámetros para curvas 
# =========================
@export var turn_radius: float = 2.2            # radio de la curva
@export var turn_trigger_dist: float = 3.0      # a qué distancia de B empezamos a curvar
@export var min_turn_angle_deg: float = 25.0    # umbral mínimo de giro
@export var max_turn_angle_deg: float = 160.0   # umbral máximo (evita U-turns)

# Estado de curva
var _turning: bool = false
var _turn_t: float = 0.0
var _turn_p0: Vector3
var _turn_p1: Vector3
var _turn_p2: Vector3
var _turn_len: float = 1.0
var _turn_target: Vector3 = Vector3.ZERO  # final real de la curva (p2)
var _y_plane: float = 0.0                 # Y “plana” para la curva

# =========================
#  Señales de gestión
# =========================
# 1) Inicia camino hacia un nodo (se emite cuando se fija _next_node)
signal path_started(next_node: Node3D)
# 2) Cambia de destino (se emite justo al confirmar llegada y pedir nuevo destino)
signal destination_changed(prev_node: Node3D, new_node: Node3D)
# 3) Se elimina/desaparece (por sink o sin salida)
signal despawned(reason: String)

# ===== API PÚBLICA =====
# El spawner llama esto con el nodo inicial (A)
func start_at_node(n: Node3D) -> void:
	current_node = n
	_request_next() # pedimos B y arrancamos

# ===== CICLO DE FÍSICA =====
func _physics_process(dt: float) -> void:
	if _next_node == null or agent == null or ray_front == null:
		velocity = Vector3.ZERO
		return

	# Objetivo de llegada:
	# - si estoy girando, el target es el final de la curva (p2)
	# - si no, el target es B
	var target_now: Vector3 = _turn_target if _turning else _next_node.global_transform.origin
	if global_transform.origin.distance_to(target_now) <= arrive_radius:
		_on_arrive_to_next()
		return

	# Si no estoy girando: evaluar si DEBO empezar un giro con C virtual
	if not _turning:
		_maybe_begin_turn_from_heading()

	# -------- GUIA (punto a seguir) --------
	var guide: Vector3
	if _turning:
		_turn_t = clamp(_turn_t + (speed * dt) / max(_turn_len, 0.001), 0.0, 1.0)
		guide = _bezier2(_turn_p0, _turn_p1, _turn_p2, _turn_t)
		# si acabó la curva, salimos al movimiento normal hacia B (aunque ya estaremos más allá de B)
		if _turn_t >= 1.0:
			_turning = false
	else:
		# seguimiento normal con el agente (suaviza discretizaciones del path)
		guide = agent.get_next_path_position()

	# Vector hacia la guía (en XZ)
	var to_vec: Vector3 = guide - global_transform.origin
	var dist: float = to_vec.length()
	var dir: Vector3 = (Vector3(to_vec.x, 0.0, to_vec.z).normalized()) if dist > 0.01 else Vector3.ZERO

	# Giro suave de la carrocería
	_smooth_face_towards(dir, dt)

	# Freno simple con Ray (ignora self)
	var local_speed := speed
	if stop_on_raycast and ray_front and ray_front.is_colliding():
		if ray_front.get_collider() != self:
			local_speed = 0.0

	# Avance en plano
	velocity = (dir * local_speed) if (dist > 0.05 and local_speed > 0.0) else Vector3.ZERO
	velocity.y = 0.0
	move_and_slide()

# ===== LÓGICA DE CURVAS =====
func _bezier2(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return (p0 * (u*u)) + (p1 * (2.0*u*t)) + (p2 * (t*t))
	
func _maybe_begin_turn_from_heading() -> void:
	# Distancia a B: solo preparo curva si ya estoy cerca
	var Bpos: Vector3 = _next_node.global_transform.origin
	var dist_to_B: float = global_transform.origin.distance_to(Bpos)
	if dist_to_B > turn_trigger_dist:
		return

	# Dirección actual (forward = -Z), en plano XZ
	var fwd: Vector3 = -global_transform.basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	if fwd == Vector3.ZERO:
		return

	# Vector hacia B, en plano XZ
	var toB: Vector3 = (Bpos - global_transform.origin)
	toB = Vector3(toB.x, 0.0, toB.z)
	var dir_toB := toB.normalized()
	if dir_toB == Vector3.ZERO:
		return

	# Ángulo entre "hacia donde voy" y "hacia B"
	var ang: float = rad_to_deg(acos(clamp(fwd.dot(dir_toB), -1.0, 1.0)))
	if ang < min_turn_angle_deg or ang > max_turn_angle_deg:
		# recto o U-turn: no curvamos
		return

	# Lado del giro según dónde cae B respecto a mi rumbo actual
	# cross_y > 0  => B a la derecha; cross_y < 0 => B a la izquierda
	var cross_y: float = (fwd.x * dir_toB.z - fwd.z * dir_toB.x)
	var side: float = signf(cross_y)
	if side == 0.0:
		return

	# Vectores de entrada/salida del giro:
	var v_in:  Vector3 = fwd                                            # desde A (rumbo actual)
	var v_out: Vector3 = Vector3(side * fwd.z, 0.0, -side * fwd.x)      # perpendicular a fwd (±90°)

	# Construcción de la Bezier alrededor de B
	_y_plane = global_transform.origin.y
	var entry: Vector3 = Bpos - v_in  * turn_radius   # p0: antes de B, sobre la calle actual
	var exit:  Vector3 = Bpos + v_out * turn_radius   # p2: después de B, sobre la calle destino (virtual)

	_turn_p0 = Vector3(entry.x, _y_plane, entry.z)
	_turn_p1 = Vector3(Bpos.x,  _y_plane, Bpos.z)     # B como control
	_turn_p2 = Vector3(exit.x,  _y_plane, exit.z)
	_turn_len = _turn_p0.distance_to(_turn_p2)
	_turn_t = 0.0
	_turn_target = _turn_p2            # llegaremos a "fin de la curva" para considerar llegada a B
	_turning = true

# ===== LÓGICA DE NODOS =====
func _on_arrive_to_next() -> void:
	_last_node = current_node
	current_node = _next_node
	_request_next() # al llegar a B, B pasa a ser A y pedimos el nuevo B

func _request_next() -> void:
	# ¿nodo inválido?
	if current_node == null:
		_despawn("invalid_current")
		return

	# ¿sumidero?
	if current_node.has_method("is_sink_node") and current_node.is_sink_node():
		_despawn("sink")
		return

	# ¿puede dar un vecino?
	if current_node.has_method("pick_next_neighbor"):
		var nxt: Node3D = current_node.pick_next_neighbor() as Node3D
		if nxt != null:
			print("[CarAgent] Nodo actual: ", current_node.name, ", Nodo siguiente: ", nxt.name)
			_set_destination(nxt)
		else:
			_despawn("dead_end")
	else:
		_despawn("no_pick_method")

func _set_destination(node_b: Node3D) -> void:
	# Si NavigationAgent3D no establece destino
	if agent == null :
		print("[CarAgent] No se establecio destino porque no se le asigno NavigationAgent3D")
		return
	# Emitimos cambio de destino solo si ya teníamos un next previo (gestión/analytics)
	if _next_node != null and node_b != _next_node:
		emit_signal("destination_changed", current_node, node_b)

	_next_node = node_b
	agent.set_target_position(node_b.global_transform.origin)
	emit_signal("path_started", node_b)

# ===== UTILIDAD: GIRO SUAVE =====

func _smooth_face_towards(dir: Vector3, dt: float) -> void:
	if dir == Vector3.ZERO:
		return
	# forward actual del coche (−Z en Godot)
	var fwd: Vector3 = -global_transform.basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var tgt: Vector3 = dir

	# ángulo con signo en Y (plano XZ)
	var cross_y: float = (fwd.x * tgt.z - fwd.z * tgt.x)
	var dot: float = clamp(fwd.x * tgt.x + fwd.z * tgt.z, -1.0, 1.0)
	var angle: float = atan2(cross_y, dot) # rad

	# limitar velocidad angular
	var max_step: float = deg_to_rad(turn_rate_deg) * dt
	var step: float = clamp(angle, -max_step, max_step)
	rotate_y(step)

# ===== DESPAWN =====

func _despawn(reason: String) -> void:
	emit_signal("despawned", reason)
	print("[CarAgent] Carro desaparecion por ",reason)
	queue_free()
