extends ItemSpawner

signal vehicle_assigned(vehicle)

@export var collected_count_max: int = -1  # Maximo de ítems recogidos
@export var vehicle: VehicleBody3D  # El camión de basura
@export var dumps: Array[Node3D] = []  # Lista de basureros (con Area3D)

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

func _on_item_collected(item: Node3D, trash_type, trash_type_score):
	if collected_count_max > collected_count or  collected_count_max == -1:
		collected_count += 1
		trash_type_transported = trash_type
		trash_type_transported_score = trash_type_score
		print("[✅ TrashManager] Ítem recolectado:", item.name)
		var entry_arr = list_items.filter(func (entry):
			return entry.point.global_position == item.global_position
		)
		if not entry_arr.is_empty():
			entry_arr[0].items.erase(item)
		count_items -= 1
		item.queue_free()
	else:
		print("[❌ TrashManager] Maxima capasidad no se puede recolectar item:", item.name)

func _on_item_deposited(_item: Node3D, dump_type):
	if trash_type_transported == dump_type:
		print("[✅ TrashManager] Depósito correcto:", dump_type)
		print("[✅ TrashManager] Items transportados:", collected_count," -> ", collected_count-1)
		print("[✅ TrashManager] Score:", score, " -> ", score + trash_type_transported_score)
		score += trash_type_transported_score
		collected_count -= 1
		if collected_count == 0:
			trash_type_transported = ""
	elif collected_count == 0:
		print("[⚠️ TrashManager] Vehiculo vacio")
	else:
		print("[❌ TrashManager] Depósito incorrecto: llevaba", trash_type_transported, "intentó en", dump_type)
