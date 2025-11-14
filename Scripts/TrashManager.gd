extends ItemSpawner
class_name TrashManager
signal vehicle_assigned(vehicle)

@export var collected_count_max: int = -1           # Máximo de ítems que puede llevar el camión (-1 = sin límite)
@export var vehicle: VehicleBody3D                  # El camión
@export var hud: NodePath                           # Nodo HUD (para actualizar UI / tiempo)

# Reglas de depósito
@export var allow_cross_dump: bool = false
@export var subtract_score_cross_dump: bool = false
@export var allow_negative_score: bool = false
@export var add_time_correct_deposit: bool = false
@export var time_added_correct_deposit: int = 10

@export var dumps: Array[Node3D] = []              # Basureros (escenas con señal "deposited")

# --- Metas de fin de partida ---
@export var meta_puntos: int = 50                   # Gana cuando alcance este puntaje (<=0 para desactivar)
@export var meta_depositos: int = -1                # Gana cuando haga esta cantidad de depósitos correctos (-1 para desactivar)

@onready var hud_node := get_node_or_null(hud)

var list_counters_deposit = []

# Estado
var depositos_correctos: int = 0
var fin: bool = false

var trash_type_transported: String = ""             # general, plastico, vidrio, papel, metal
var trash_type_transported_score: int = 0           # Puntos del tipo transportado
var collected_count: int = 0                        # Ítems cargados actualmente
var score: int = 0                                  # Puntaje total

func _ready() -> void:
	# Lógica base
	super._ready()
	# Registrarse en un grupo para que el vehículo pueda encontrarnos fácilmente
	add_to_group("trash_manager")

	# Registrar ítems (basuras)
	var items: Node3D = items_root if items_root else self
	for item in items.get_children():
		if item is Node3D:
			if item.has_signal("collected"):
				item.connect("collected", Callable(self, "_on_item_collected"))
			if item.has_method("set_vehicle"):
				connect("vehicle_assigned", Callable(item, "set_vehicle"))

	# Registrar basureros
	for dump in dumps:
		if dump is Node3D:
			if dump.has_signal("deposited"):
				dump.connect("deposited", Callable(self, "_on_item_deposited"))
			if dump.has_method("set_vehicle"):
				connect("vehicle_assigned", Callable(dump, "set_vehicle"))

	emit_signal("vehicle_assigned", vehicle)

	if hud_node:
		call_deferred("_sync_hud_initial")
		# ✅ Derrota por tiempo agotado (el HUD debe emitir "time_over")
		if hud_node.has_signal("time_over"):
			hud_node.connect("time_over", Callable(self, "_on_time_over"))

func _on_item_collected(item: Node3D, trash_type, trash_type_score) -> void:
	if collected_count_max > collected_count or collected_count_max == -1:
		collected_count += 1
		trash_type_transported = str(trash_type)
		trash_type_transported_score = int(trash_type_score)
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
		print("[❌ TrashManager] Capacidad máxima, no se puede recolectar:", item.name)

func _on_item_deposited(_item: Node3D, dump_type) -> void:
	if collected_count > 0 and (allow_cross_dump or trash_type_transported == dump_type):
		print("[✅ TrashManager] Depósito en:", dump_type)
		print("[✅ TrashManager] Items transportados:", collected_count, " -> ", collected_count - 1)

		if trash_type_transported == dump_type:
			# 🔵 Depósito correcto
			score += trash_type_transported_score
			depositos_correctos += 1

			# (Opcional) agregar tiempo al HUD
			if add_time_correct_deposit and hud_node and hud_node.has_method("add_time"):
				hud_node.add_time(time_added_correct_deposit)

			# ✅ ¿Victoria?
			if _check_victoria():
				_finalizar_victoria()
				return
		elif subtract_score_cross_dump and (score > 0 or allow_negative_score):
			score -= trash_type_transported_score

		count_items -= 1
		collected_count -= 1
		respawn_missing_items()
		var newCounter = true
		var typeCounter 
		for counter in list_counters_deposit:
			if counter.type == trash_type_transported:
				counter.count += 1
				newCounter = false
				typeCounter = counter

		if newCounter:
			typeCounter = {"type": trash_type_transported, "count": 1}
			list_counters_deposit.append(typeCounter)
		
		if collected_count == 0:
			trash_type_transported = ""
			trash_type_transported_score = 0

		if hud_node:
			if hud_node.has_method("update_collected"):
				hud_node.update_collected(collected_count, collected_count_max)
			if hud_node.has_method("update_score"):
				hud_node.update_score(score)
			if hud_node.has_method("update_trash_count"):
				hud_node.update_trash_count(typeCounter.type, typeCounter.count)

			# --- APAGAR ICONOS DE BASURA ---
			if hud_node.has_method("hide_all_trash_icons"):
				hud_node.hide_all_trash_icons()

	elif collected_count == 0:
		print("[⚠️ TrashManager] Vehículo vacío")
	else:
		print("[❌ TrashManager] Depósito incorrecto: llevaba ", trash_type_transported, " intentó en ", dump_type)

func _sync_hud_initial() -> void:
	if hud_node:
		if hud_node.has_method("update_collected"):
			hud_node.update_collected(collected_count, collected_count_max)
		if hud_node.has_method("update_score"):
			hud_node.update_score(score)

func respawn_missing_items() -> void:
	# Lógica base del ItemSpawner
	super.respawn_missing_items()

	# Reconectar señales de los nuevos ítems generados
	var items: Node3D = items_root if items_root else self
	for item in items.get_children():
		if item is Node3D and not item.is_connected("collected", Callable(self, "_on_item_collected")):
			if item.has_signal("collected"):
				item.connect("collected", Callable(self, "_on_item_collected"))
			if item.has_method("set_vehicle"):
				connect("vehicle_assigned", Callable(item, "set_vehicle"))

	emit_signal("vehicle_assigned", vehicle)

# -------------------------
#   Victoria / Derrota
# -------------------------

func _check_victoria() -> bool:
	if fin:
		return false
	var por_puntos := meta_puntos > 0 and score >= meta_puntos
	var por_depositos := meta_depositos > 0 and depositos_correctos >= meta_depositos
	return por_puntos or por_depositos

func _get_elapsed_time() -> float:
	# Si tu HUD expone get_elapsed_time() o tiene un Timer "GameTimer", úsalo
	if hud_node:
		if hud_node.has_method("get_elapsed_time"):
			return float(hud_node.get_elapsed_time())
		if hud_node.has_node("GameTimer"):
			var t := hud_node.get_node("GameTimer") as Timer
			if t and t.wait_time > 0.0:
				return t.wait_time - t.time_left
	return 0.0

func _finalizar_victoria() -> void:
	if fin:
		return
	fin = true
	Game.win(score, _get_elapsed_time())

func _on_time_over() -> void:
	if fin:
		return
	fin = true
	Game.lose(score, _get_elapsed_time())
