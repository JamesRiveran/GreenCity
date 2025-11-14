extends ItemSpawner

signal vehicle_assigned(vehicle)

@export var collected_count_max: int = -1  # Maximo de ítems recogidos
@export var vehicle: VehicleBody3D  # El camión de basura
@export var hud: NodePath
# Si es true, permite depositar en cualquier tipo de contenedor pero restando si no es el correcto.
@export var allow_cross_dump: bool = false
@export var subtract_score_cross_dump: bool = false
@export var allow_negative_score: bool = false
@export var add_time_correct_deposit: bool = false
@export var time_added_correct_deposit: int = 10
@export var dumps: Array[Node3D] = []  # Lista de basureros (con Area3D)

@onready var hud_node := get_node_or_null(hud)

var trash_type_transported: String # Tipo transportado: general, plastico, vidrio, papel, metal
var trash_type_transported_score: int = 0  # Valor en puntos del tipo de basura transportado

var collected_count: int = 0  # Contador de ítems recogidos
var score: int = 0  # Puntos ganados

func _ready():
	# Ejecuta la lógica del _ready del ItemSpawner 
	super._ready()
	
	# Registrar los ítems generados(Basura, Basureros)
	var items: Node3D = items_root if items_root else self
	for item in items.get_children():
		if item is Node3D:
			if item.has_signal("collected"):
				item.connect("collected", Callable(self, "_on_item_collected"))
			# Conectar la señal para asignar el vehículo
			if item.has_method("set_vehicle"):
				connect("vehicle_assigned", Callable(item, "set_vehicle"))
	for dump in dumps:
		if dump is Node3D:
			if dump.has_signal("deposited"):
				dump.connect("deposited", Callable(self, "_on_item_deposited"))
			# Conectar la señal para asignar el vehículo
			if dump.has_method("set_vehicle"):
				connect("vehicle_assigned", Callable(dump, "set_vehicle"))
				
	emit_signal("vehicle_assigned", vehicle)
	
	if hud_node:
		call_deferred("_sync_hud_initial")

func _on_item_collected(item: Node3D, trash_type, trash_type_score):
	if collected_count_max > collected_count or  collected_count_max == -1:
		collected_count += 1
		trash_type_transported = trash_type
		trash_type_transported_score = trash_type_score
		print("[✅ TrashManager] Ítem recolectado:", item.name)
		
		if hud_node and hud_node.has_method("show_trash_icon"):
			hud_node.show_trash_icon(trash_type)
			
		if hud_node and hud_node.has_method("update_collected"):
			hud_node.update_collected(collected_count, collected_count_max)
			
		var entry_arr = list_items.filter(func (entry):
			return entry.items.has(item)
		)
		if not entry_arr.is_empty():
			entry_arr[0].items.erase(item)
			item.queue_free()
	else:
		print("[❌ TrashManager] Maxima capasidad no se puede recolectar item:", item.name)

func _on_item_deposited(_item: Node3D, dump_type):
	if collected_count > 0 and (allow_cross_dump or trash_type_transported == dump_type):
		print("[✅ TrashManager] Depósito:", dump_type)
		print("[✅ TrashManager] Items depositados:", collected_count, " -> ", collected_count - 1)
		print("[✅ TrashManager] Score:", score, " -> ", score + trash_type_transported_score)

		if trash_type_transported == dump_type:
			score += trash_type_transported_score
			if add_time_correct_deposit:
				hud_node.add_time(time_added_correct_deposit)
		elif subtract_score_cross_dump and (score > 0 or allow_negative_score):
			score -= trash_type_transported_score

		count_items -= 1
		collected_count -= 1
		respawn_missing_items()

		if collected_count == 0:
			trash_type_transported = ""

		if hud_node:
			if hud_node.has_method("update_collected"):
				hud_node.update_collected(collected_count, collected_count_max)
			if hud_node.has_method("update_score"):
				hud_node.update_score(score)
			
			# --- APAGAR ICONOS DE BASURA ---
			if hud_node.has_method("hide_all_trash_icons"):
				hud_node.hide_all_trash_icons()

	elif collected_count == 0:
		print("[⚠️ TrashManager] Vehiculo vacio")
	else:
		print("[❌ TrashManager] Depósito incorrecto: llevaba ", trash_type_transported, " intentó en ", dump_type)

func _sync_hud_initial():
	if hud_node:
		if hud_node.has_method("update_collected"):
			hud_node.update_collected(collected_count, collected_count_max)
		if hud_node.has_method("update_score"):
			hud_node.update_score(score)

func respawn_missing_items():
	# Ejecuta la lógica base del ItemSpawner
	super.respawn_missing_items()

	# 🔹 Reconecta las señales de los nuevos ítems generados
	var items: Node3D = items_root if items_root else self
	for item in items.get_children():
		if item is Node3D and not item.is_connected("collected", Callable(self, "_on_item_collected")):
			if item.has_signal("collected"):
				item.connect("collected", Callable(self, "_on_item_collected"))
			if item.has_method("set_vehicle"):
				connect("vehicle_assigned", Callable(item, "set_vehicle"))

	# Reemitir el vehículo asignado
	emit_signal("vehicle_assigned", vehicle)
