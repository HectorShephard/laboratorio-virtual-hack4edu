extends Node3D

signal measurement_taken(data: Dictionary)
signal state_changed(state: String)

var _configured := false
var _result: Dictionary = {}
var _value := 0.0


func describe() -> Dictionary:
	return {
		"experiment_id": "prueba_tecnica",
		"title": "Práctica técnica",
		"model_version": "test-1",
		"source": "test",
		"validity": "prueba",
		"parameters": [{"id": "entrada", "label": "Valor de entrada", "unit": "u",
			"min": 0.0, "max": 10.0, "step": 1.0, "default": 3.0}],
		"assumptions": ["El resultado de prueba es el doble de la entrada."],
		"reference_ids": [],
	}


func configure(parameters: Dictionary) -> Dictionary:
	var input: Variant = parameters.get("entrada")
	if not (input is int or input is float):
		return {"ok": false, "error": "Introduce un valor numérico."}
	if not is_finite(float(input)) or float(input) < 0.0 or float(input) > 10.0:
		return {"ok": false, "error": "La entrada debe estar entre 0 y 10."}
	_value = float(input)
	_configured = true
	_result.clear()
	state_changed.emit("configured")
	return {"ok": true}


func start_run(run_id: String) -> Dictionary:
	if not _configured or run_id.is_empty():
		return {"ok": false, "error": "El ensayo todavía no está configurado."}
	_result = {"quantity": "salida_de_prueba", "value": _value * 2.0, "unit": "u"}
	state_changed.emit("completed")
	measurement_taken.emit(_result.duplicate(true))
	return {"ok": true}


func measure() -> Dictionary:
	return {"value": null} if _result.is_empty() else _result.duplicate(true)


func reset_run() -> void:
	_configured = false
	_value = 0.0
	_result.clear()
	state_changed.emit("idle")
