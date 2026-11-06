extends SceneTree

const Adapter = preload("res://core/experiment_adapter.gd")
const Journal = preload("res://bitacora/run_journal.gd")
const TEST_SCENE = preload("res://pruebas/modulo_prueba.tscn")
const LAB_SCENE = preload("res://main.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var adapter := Adapter.new()
	root.add_child(adapter)
	var directory := "user://pruebas_bitacora/" + Journal.new().new_id()
	var journal := Journal.new(directory)
	if not _check(adapter.mount(TEST_SCENE).is_empty(), "Montar el módulo técnico"):
		_finish(directory)
		return
	_check(not adapter.configure({"entrada": -1}).is_empty(), "Rechazar una condición inválida")
	_check(adapter.measurement().has("error"), "Rechazar medición sin iniciar")
	for input in [3, 7]:
		if not _check(adapter.configure({"entrada": input}).is_empty(), "Configurar ensayo"):
			break
		if not _check(adapter.start(journal.new_id()).is_empty(), "Iniciar ensayo"):
			break
		var result := adapter.measurement()
		if not _check(result.has("record"), "Recibir una medición"):
			break
		var record: Dictionary = result["record"]
		_check(record["value"] == input * 2, "Medición del caso de prueba")
		_check(record["source"] == "test" and record["validity"] == "prueba", "Identificar datos de prueba")
		record["notes"] = "Nota de prueba para %s" % input
		_check(journal.save(record) == OK, "Guardar un ensayo")
		_check(journal.save(record) == ERR_ALREADY_EXISTS, "Conservar el registro ante una repetición")
		adapter.mark_saved()
		_check(adapter.measurement().has("error"), "Impedir una segunda medición del ensayo guardado")
		adapter.reset()
		_check(adapter.phase == "idle", "Reiniciar el flujo")
	var loaded := Journal.new(directory).recent()
	_check(loaded.size() == 2, "Recuperar ambos ensayos con otra instancia de bitácora")
	var values: Array[float] = []
	for record in loaded:
		values.append(float(record["value"]))
		_check(str(record.get("notes", "")).begins_with("Nota de prueba"), "Recuperar las notas")
	values.sort()
	_check(values == [6.0, 14.0], "Conservar los dos resultados esperados")

	_check_workbench(journal)
	_finish(directory)


func _check_workbench(journal: RefCounted) -> void:
	var lab := LAB_SCENE.instantiate()
	root.add_child(lab)
	var panel: Control = lab.get("experiment_panel")
	_check(panel != null, "Encontrar el cuaderno")
	panel.set("_journal", journal)
	lab.call("_open_experiment")
	_check(panel.visible, "Abrir el cuaderno desde el laboratorio")
	var history: TextEdit = panel.get("_history")
	_check(history.text.contains("Nota de prueba para"), "Conservar registros técnicos anteriores en el cuaderno")
	lab.free()

func _check(condition: bool, label: String) -> bool:
	if condition:
		print("OK: " + label)
	else:
		_failed = true
		printerr("FALLO: " + label)
	return condition


func _finish(directory: String) -> void:
	var folder := DirAccess.open(directory)
	if folder != null:
		for name in folder.get_files():
			folder.remove(name)
		DirAccess.remove_absolute(directory)
	quit(1 if _failed else 0)
