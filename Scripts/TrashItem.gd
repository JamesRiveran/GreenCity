extends ItemRotator

signal collected(item: Node3D)

@export var trash_type: String = "general"  # Tipo: general, plastico, vidrio, papel, metal
@export var trash_type_score: int = 0  # Valor en puntos del tipo de basura

var target_vehicle: VehicleBody3D = null

func _ready():
	var area := $Area3D
	if area:
		area.body_entered.connect(_on_body_entered)
	else:
		push_warning("[⚠️ TrashItem] Item sin Area3D asignada: %s" % name)

func _on_body_entered(body):
	if body == target_vehicle:
		emit_signal("collected", self, trash_type, trash_type_score)

func set_vehicle(v: VehicleBody3D) -> void:
	target_vehicle = v
