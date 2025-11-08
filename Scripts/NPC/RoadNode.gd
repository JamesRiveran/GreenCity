@tool
extends Node3D

@export var neighbors: Array[NodePath] = []   # salidas (one-way)
@export var is_sink: bool = false
@export var blocked: bool = false

# Pesos opcionales: si no coinciden tamaños, se usa uniforme
@export var use_weights: bool = false
@export var neighbor_weights: Array[float] = []

@export var warn_bidirectional: bool = true

signal state_changed(blocked: bool, is_sink: bool)

func is_sink_node() -> bool:
	return is_sink

func set_blocked(v: bool) -> void:
	if blocked == v: return
	blocked = v
	emit_signal("state_changed", blocked, is_sink)

func pick_next_neighbor() -> Node3D:
	if blocked:
		return null

	var opts: Array[Node3D] = []
	for p in neighbors:
		var n: Node3D = get_node_or_null(p) as Node3D
		if n != null:
			opts.append(n)

	if opts.is_empty():
		return null

	# --- Uniforme si no hay pesos válidos ---
	if (not use_weights) or (neighbor_weights.size() != neighbors.size()):
		return opts[randi() % opts.size()]

	# --- Ponderado ---
	var weighted: Array[Dictionary] = []
	var total: float = 0.0

	for i in range(neighbors.size()):
		var n: Node3D = get_node_or_null(neighbors[i]) as Node3D
		if n == null:
			continue
		# if-expression -> casteado explícito a float para evitar Variant
		var base_w: float = (float(neighbor_weights[i]) if i < neighbor_weights.size() else 0.0)
		var w: float = max(0.0, base_w)
		if w <= 0.0:
			continue
		weighted.append({ "node": n, "w": w })
		total += w

	if total <= 0.0 or weighted.is_empty():
		return opts[randi() % opts.size()]

	var pick: float = randf() * total
	var acc: float = 0.0
	for d in weighted:
		acc += float(d["w"])
		if pick <= acc:
			return d["node"] as Node3D

	return weighted.back()["node"] as Node3D

func _ready() -> void:
	if Engine.is_editor_hint() and warn_bidirectional:
		for p in neighbors:
			var n: Node3D = get_node_or_null(p) as Node3D
			if n == null: continue
			var back_list = n.get("neighbors")
			if typeof(back_list) == TYPE_ARRAY:
				for q in back_list:
					var back: Node3D = n.get_node_or_null(q) as Node3D
					if back == self:
						push_warning("Arista bidireccional detectada: %s <-> %s" % [name, n.name])
