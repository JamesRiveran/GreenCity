extends Node3D

## =========================
##  Configuración
## =========================
@export var car_scenes: Array[PackedScene] = []      # múltiples templates de autos
@export var spawn_points: Array[NodePath] = []       # nodos/Marker3D/RoadNode
@export var max_cars: int = 20                       # cupo simultáneo
@export var spawn_interval: float = 1.5              # ritmo de reposición inicial/progresiva
@export var refill_on_exit: bool = true              # reponer inmediatamente al salir un auto

@export var cars_root: Node3D = self         # contenedor (puede ser null)

## =========================
##  Estado
## =========================
var _t: float = 0.0
var _count: int = 0
var _rr_index: int = 0                               # round-robin para spawn points

## =========================
##  Ciclo
## =========================
func _process(dt: float) -> void:
	_t += dt
	if _t >= spawn_interval and _count < max_cars:
		_t = 0.0
		_spawn()

## =========================
##  Lógica de spawn
## =========================
func _spawn() -> void:
	var ps: PackedScene = _choose_scene()
	if ps == null:
		return
	var sp: Node3D = _choose_spawn_point()
	if sp == null:
		return

	var car_inst: Node3D = ps.instantiate() as Node3D
	if car_inst == null:
		return

	var parent: Node = (cars_root if cars_root != null else self)
	parent.add_child(car_inst)

	car_inst.global_transform = sp.global_transform
	_count += 1

	# Cuando salga del árbol, reducimos conteo y reponemos si procede
	car_inst.tree_exited.connect(_on_car_exit)

	# Si el coche soporta API start_at_node, arrancamos
	if car_inst.has_method("start_at_node"):
		car_inst.start_at_node(sp)

func _on_car_exit() -> void:
	_count = max(0, _count - 1)
	# Reponer inmediatamente si hay cupo
	if refill_on_exit and _count < max_cars:
		_spawn()

## =========================
##  Utilidades internas
## =========================
func _choose_scene() -> PackedScene:
	# Elige una plantilla al azar; si está vacío, no spawnea
	if car_scenes.is_empty():
		return null
	var idx: int = randi() % car_scenes.size()
	var scn: PackedScene = car_scenes[idx]
	return scn

func _choose_spawn_point() -> Node3D:
	if spawn_points.is_empty():
		return null
	# Round-robin simple para distribuir apariciones
	if _rr_index >= spawn_points.size():
		_rr_index = 0
	var path: NodePath = spawn_points[_rr_index]
	_rr_index += 1
	var sp: Node3D = get_node_or_null(path) as Node3D
	return sp
