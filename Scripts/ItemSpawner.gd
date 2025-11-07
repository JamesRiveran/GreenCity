extends Node3D

# Define ItemSpawner como clase exportada
class_name ItemSpawner

# Escenas que se pueden generar
@export var item_templates: Array[PackedScene] = []

# Puntos de aparición (Node3D o Vector3 referenciados por NodePath)
@export var spawn_points_nodes: Array[NodePath] = []
@export var root_spawn_points: NodePath

# Nodo raíz donde se guardarán los ítems generados
@export var items_root: Node3D = self

# Si true, se eliminarán los ítems viejos antes de generar nuevos
@export var clear_old_items: bool = false

# Si true, se ejecuta automáticamente al iniciar
@export var auto_spawn: bool = true

# Límite máximo de ítems a generar (-1 = sin límite)
@export var max_items: int = -1

var spawn_points: Array[Node3D] = []
var list_items = []
var count_items: int = 0

func _ready():
	# Crear una colección temporal para evitar duplicados 
	var seen_points := {}

	# Agregar puntos definidos manualmente
	for path in spawn_points_nodes:
		var point := get_node_or_null(path)
		if point and not seen_points.has(point):
			seen_points[point] = true
			spawn_points.append(point)

	# Agregar puntos hijos del nodo raíz
	if root_spawn_points != NodePath(""):
		var root_node := get_node_or_null(root_spawn_points)
		if root_node:
			for child in root_node.get_children():
				if child is Node3D and not seen_points.has(child):
					seen_points[child] = true
					spawn_points.append(child)

	# Llenar la lista principal del spawner
	for point in spawn_points:
		list_items.append({"point": point, "items": []})

	# Auto-spawn si está activado
	if auto_spawn:
		spawn_items()

func clear_list_items():
	for entry in list_items:
		entry.items.clear()
	count_items = 0

func has_items_at_point(point: Node3D) -> bool:
	for entry in list_items:
		if entry.point == point:
			if entry.items.is_empty():
				break
			else:
				return true
	return false
	
func spawn_items():
	# Validaciones
	if item_templates.is_empty():
		push_warning("[⚠️ ItemSpawner] No hay plantillas asignadas en item_templates.")
		return

	if spawn_points.is_empty():
		push_warning("[⚠️ ItemSpawner] No hay puntos de aparición asignados en spawn_points.")
		return

	# Determinar el nodo donde se añadirán los ítems
	var parent_node: Node3D = items_root if items_root else self

	# Eliminar ítems antiguos si la opción está activada
	if clear_old_items:
		for entry in list_items:
			for item in entry.items:
				if is_instance_valid(item):
					item.queue_free()
		clear_list_items()
		
	# Se mezclan los puntos para aleatorizar el spawn.
	var randomized_points = spawn_points.duplicate()
	randomized_points.shuffle()

	for point in randomized_points:
		if max_items > 0 and count_items >= max_items:
			break
		
		var spawn_pos: Vector3 = point.global_position
		
		var template: PackedScene = item_templates.pick_random()
		if template == null:
			continue

		var instance = template.instantiate()
		# Asignar nombre único y legible
		instance.name = "%s_%d" % [template.resource_path.get_file().get_basename(), count_items + 1] 
		parent_node.add_child(instance)
		for entry in list_items:
			if entry.point == point:
				entry.items.append(instance)
				break
		instance.global_position = spawn_pos
		count_items += 1

func respawn_missing_items():
	# Determinar el nodo donde se añadirán los ítems
	var parent_node: Node3D = items_root if items_root else self
	
	# Se mezclan los puntos para aleatorizar el spawn.
	var randomized_points = list_items.filter(func(entry): return entry.items.is_empty())
	randomized_points.shuffle()
	
	for entry in randomized_points:
		if max_items > 0 and count_items >= max_items:
			break
			
		var template: PackedScene = item_templates.pick_random()
		if template == null:
			push_warning("[⚠️ ItemSpawner] No hay plantillas asignadas en item_templates.")
			continue
		var instance = template.instantiate()
		# Asignar nombre único y legible
		instance.name = "%s_%d" % [template.resource_path.get_file().get_basename(), count_items + 1] 
		parent_node.add_child(instance)
		instance.global_position = entry.point.global_position
		entry.items.append(instance)
		count_items += 1
