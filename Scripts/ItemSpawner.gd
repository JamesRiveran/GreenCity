extends Node3D

# Escenas que se pueden generar
@export var item_templates: Array[PackedScene] = []

# Puntos de aparición (Node3D o Vector3 referenciados por NodePath)
@export var spawn_points: Array[NodePath] = []

# Nodo raíz donde se guardarán los ítems generados
@export var items_root: Node3D

# Si true, se eliminarán los ítems viejos antes de generar nuevos
@export var clear_old_items: bool = false

# Si true, se ejecuta automáticamente al iniciar
@export var auto_spawn: bool = true

# Límite máximo de ítems a generar (-1 = sin límite)
@export var max_items: int = -1


func _ready():
	if auto_spawn:
		spawn_items()


func spawn_items():
	# Validaciones
	if item_templates.is_empty():
		push_warning("⚠️ No hay plantillas asignadas en item_templates.")
		return

	if spawn_points.is_empty():
		push_warning("⚠️ No hay puntos de aparición asignados en spawn_points.")
		return

	# Determinar el nodo donde se añadirán los ítems
	var parent_node: Node3D = items_root if items_root else self

	# Eliminar ítems antiguos si la opción está activada
	if clear_old_items:
		for child in parent_node.get_children():
			child.queue_free()

	var count := 0
	for path in spawn_points:
		if max_items > 0 and count >= max_items:
			break

		var point := get_node(path)
		if point == null:
			push_warning("No se encontró el nodo en la ruta: %s" % str(path))
			continue

		var spawn_pos: Vector3 = point.global_position
		var template: PackedScene = item_templates.pick_random()
		if template == null:
			continue

		var instance = template.instantiate()
		instance.global_position = spawn_pos
		parent_node.add_child(instance)
		count += 1
