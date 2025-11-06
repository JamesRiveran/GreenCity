extends Node3D

func _ready():
	var meshes = get_tree().get_nodes_in_group("") # dummy

	# Recorre todos los nodos dentro del City
	for child in get_children_recursive(self):
		if child is MeshInstance3D and child.mesh:
			var static_body := StaticBody3D.new()
			child.add_child(static_body)
			static_body.owner = self

			var shape: Shape3D = child.mesh.create_trimesh_shape()
			var collision := CollisionShape3D.new()
			collision.shape = shape
			static_body.add_child(collision)
			collision.owner = self

func get_children_recursive(node: Node) -> Array:
	var arr: Array = []
	for c in node.get_children():
		arr.append(c)
		arr += get_children_recursive(c)
	return arr
