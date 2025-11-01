extends ItemRotator

signal deposited(item: Node3D)

@export var dump_trash_type: String = "general"  # Tipo: general, plastico, vidrio, papel, metal
@export var deposit_time: float = 1.0       # Segundos entre descargas (0 = inmediato)

var _is_unloading: bool = false             # Indica si actualmente se está descargando

func _ready():
	var area := $Area3D
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
	else:
		push_warning("[⚠️ DumpItem] Dump sin Area3D asignada: %s" % name)

func _on_body_entered(body):
	if body is VehicleBody3D and not _is_unloading:
		_is_unloading = true
		_start_unloading()

func _on_body_exited(body):
	if body is VehicleBody3D:
		_is_unloading = false

func _start_unloading() -> void:
	while _is_unloading:
		emit_signal("deposited", self, dump_trash_type)
		if deposit_time > 0:
			await get_tree().create_timer(deposit_time).timeout
		else:
			await get_tree().process_frame
