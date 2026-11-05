extends Node
## Connects an experiment scene to a single session in the workbench.

const METHODS := ["describe", "configure", "start_run", "measure", "reset_run"]
const SIGNALS := ["measurement_taken", "state_changed"]

var phase := "idle"
var _module: Node3D
var _description: Dictionary = {}
var _parameters: Dictionary = {}
var _run_id := ""


func mount(scene: PackedScene) -> String:
	var instance := scene.instantiate()
	if not instance is Node3D:
		instance.free()
		return "La raíz de la práctica debe ser Node3D."
	for method in METHODS:
		if not instance.has_method(method):
			instance.free()
			return "Falta el método %s en la práctica." % method
	for signal_name in SIGNALS:
		if not instance.has_signal(signal_name):
			instance.free()
			return "Falta la señal %s en la práctica." % signal_name
	var info: Variant = instance.call("describe")
	if not _valid_description(info):
		instance.free()
		return "La práctica tiene metadatos o parámetros inválidos."
	if _module != null:
		remove_child(_module)
		_module.queue_free()
	_module = instance as Node3D
	_description = info.duplicate(true)
	add_child(_module)
	reset()
	return ""


func description() -> Dictionary:
	return _description.duplicate(true)


func configure(parameters: Dictionary) -> String:
	if _module == null or phase != "idle":
		return "Reinicia el ensayo antes de cambiar sus condiciones."
	var error := _reply_error(_module.call("configure", parameters.duplicate(true)))
	if error.is_empty():
		_parameters = parameters.duplicate(true)
		phase = "configured"
	return error


func start(run_id: String) -> String:
	if _module == null or phase != "configured" or run_id.is_empty():
		return "Configura las condiciones antes de iniciar."
	var error := _reply_error(_module.call("start_run", run_id))
	if error.is_empty():
		_run_id = run_id
		phase = "running"
	return error


func measurement() -> Dictionary:
	if _module == null or phase != "running":
		return {"error": "Inicia un ensayo antes de medir."}
	var data: Variant = _module.call("measure")
	if not data is Dictionary or not data.has("value"):
		return {"error": "El módulo entregó una medición inválida."}
	if data["value"] == null:
		return {"pending": true}
	var time_s: Variant = data.get("time_s")
	if not _number(data["value"]) or not _nonempty_text(data.get("quantity")) or not _nonempty_text(data.get("unit")):
		return {"error": "La medición requiere una magnitud, un valor finito y una unidad."}
	if time_s != null and (not _number(time_s) or float(time_s) < 0):
		return {"error": "El instante de medición es inválido."}
	return {"record": {
		"schema_version": 1,
		"experiment_id": _description["experiment_id"],
		"run_id": _run_id,
		"model_version": _description["model_version"],
		"parameters": _parameters.duplicate(true),
		"quantity": data["quantity"],
		"value": float(data["value"]),
		"unit": data["unit"],
		"source": _description["source"],
		"validity": _description["validity"],
		"time_s": time_s,
		"assumptions": _description.get("assumptions", []),
		"reference_ids": _description.get("reference_ids", []),
	}}


func mark_saved() -> void:
	if phase == "running":
		phase = "saved"


func reset() -> void:
	if _module != null:
		_module.call("reset_run")
	_parameters.clear()
	_run_id = ""
	phase = "idle"


func _valid_description(info: Variant) -> bool:
	if not info is Dictionary:
		return false
	for field in ["experiment_id", "title", "model_version", "validity"]:
		if not _nonempty_text(info.get(field)):
			return false
	if info.get("source") not in ["test", "simulation"] or not info.get("parameters") is Array:
		return false
	if info["source"] == "test" and info["validity"] != "prueba":
		return false
	var seen: Dictionary = {}
	for parameter in info["parameters"]:
		if not parameter is Dictionary:
			return false
		for field in ["id", "label", "unit"]:
			if not _nonempty_text(parameter.get(field)):
				return false
		for field in ["min", "max", "step", "default"]:
			if not _number(parameter.get(field)):
				return false
		if seen.has(parameter["id"]) or parameter["step"] <= 0:
			return false
		if parameter["default"] < parameter["min"] or parameter["default"] > parameter["max"]:
			return false
		seen[parameter["id"]] = true
	return true


func _reply_error(reply: Variant) -> String:
	if not reply is Dictionary or not reply.get("ok") is bool:
		return "La práctica no confirmó la operación."
	if reply["ok"]:
		return ""
	var error := str(reply.get("error", "La práctica rechazó la operación.")).strip_edges()
	return error if not error.is_empty() else "La práctica rechazó la operación."


func _nonempty_text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()


func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
