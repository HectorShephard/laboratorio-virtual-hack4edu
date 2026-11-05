extends PanelContainer
## Technical practice and local history. The workbench pauses grabs while it is open.

const Adapter = preload("res://core/experiment_adapter.gd")
const Journal = preload("res://bitacora/run_journal.gd")
const TECHNICAL_SCENE = preload("res://pruebas/modulo_prueba.tscn")

var _adapter := Adapter.new()
var _journal := Journal.new()
var _editors: Dictionary = {}
var _fields: Dictionary = {}
var _status: Label
var _history: TextEdit
var _configure_button: Button
var _start_button: Button
var _measure_button: Button
var _reset_button: Button
var _available := false


func _ready() -> void:
	add_child(_adapter)
	var mount_error := _adapter.mount(TECHNICAL_SCENE)
	_available = mount_error.is_empty()
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("13232f")
	skin.set_corner_radius_all(14)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		skin.set_content_margin(side, 20)
	add_theme_stylebox_override("panel", skin)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := _label("Práctica técnica", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_button("Volver a la mesa", hide))
	column.add_child(_label("Datos de prueba · Comprueba la configuración, la medición y el guardado.", 15))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 7)
	scroll.add_child(form)
	form.add_child(_label("Condiciones del ensayo", 17))
	for parameter in _adapter.description().get("parameters", []):
		form.add_child(_label("%s [%s]" % [parameter["label"], parameter["unit"]], 14))
		var input := SpinBox.new()
		input.min_value = float(parameter["min"])
		input.max_value = float(parameter["max"])
		input.step = float(parameter["step"])
		input.value = float(parameter["default"])
		form.add_child(input)
		_editors[parameter["id"]] = input
	for field in [["question", "Pregunta"], ["hypothesis", "Hipótesis"],
			["notes", "Notas"], ["conclusion", "Conclusión"]]:
		var input := LineEdit.new()
		input.placeholder_text = field[1]
		input.max_length = 400
		form.add_child(input)
		_fields[field[0]] = input

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	_configure_button = _button("Configurar", _configure)
	_start_button = _button("Iniciar", _start)
	_measure_button = _button("Medir y guardar", _measure_and_save)
	_reset_button = _button("Reiniciar ensayo", _reset)
	for button in [_configure_button, _start_button, _measure_button, _reset_button]:
		actions.add_child(button)
	_status = _label(mount_error if not _available else "Ajusta la entrada y pulsa Configurar.", 15)
	column.add_child(_status)

	var records := VBoxContainer.new()
	records.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(records)
	records.add_child(_label("Bitácora local · Últimos 20 ensayos", 17))
	_history = TextEdit.new()
	_history.editable = false
	_history.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	records.add_child(_history)
	records.add_child(_label("Cada ensayo se conserva al reiniciar la aplicación.", 13))
	_update_actions()


func open_panel() -> void:
	_refresh_history()
	show()
	_configure_button.grab_focus()


func _configure() -> void:
	var parameters: Dictionary = {}
	for id in _editors:
		var input: SpinBox = _editors[id]
		parameters[id] = input.value
	var error := _adapter.configure(parameters)
	_status.text = "Condiciones aceptadas. Pulsa Iniciar." if error.is_empty() else error
	_update_actions()


func _start() -> void:
	var error := _adapter.start(_journal.new_id())
	_status.text = "Ensayo iniciado. Pulsa Medir y guardar." if error.is_empty() else error
	_update_actions()


func _measure_and_save() -> void:
	var result := _adapter.measurement()
	if result.has("error"):
		_status.text = result["error"]
		return
	if result.get("pending", false):
		_status.text = "La medición está pendiente. Intenta medir cuando termine el ensayo."
		return
	var record: Dictionary = result["record"]
	for field in _fields:
		var input: LineEdit = _fields[field]
		record[field] = input.text.strip_edges()
	record["saved_at_utc"] = Time.get_datetime_string_from_system(true) + "Z"
	var error := _journal.save(record)
	if error != OK:
		_status.text = "No se guardó el ensayo. %s. Puedes intentar guardarlo de nuevo." % error_string(error)
		return
	_adapter.mark_saved()
	_status.text = "Ensayo guardado. Resultado de prueba: %s %s." % [record["value"], record["unit"]]
	_refresh_history()
	_update_actions()


func _reset() -> void:
	_adapter.reset()
	for field in _fields:
		var input: LineEdit = _fields[field]
		input.clear()
	_status.text = "Ensayo listo para configurar. Los registros guardados se conservan."
	_update_actions()


func _update_actions() -> void:
	_configure_button.disabled = not _available or _adapter.phase != "idle"
	_start_button.disabled = not _available or _adapter.phase != "configured"
	_measure_button.disabled = not _available or _adapter.phase != "running"
	_reset_button.disabled = not _available or _adapter.phase == "idle"
	for input: SpinBox in _editors.values():
		input.editable = _adapter.phase == "idle"
	for input: LineEdit in _fields.values():
		input.editable = _adapter.phase != "saved"


func _refresh_history() -> void:
	var lines := PackedStringArray()
	for record in _journal.recent():
		lines.append("%s · %s" % [record["experiment_id"], record.get("saved_at_utc", "")])
		lines.append("%s = %s %s · %s / %s" % [record["quantity"], record["value"],
			record["unit"], record["source"], record["validity"]])
		lines.append("Condiciones: " + JSON.stringify(record["parameters"]))
		for field in [["question", "Pregunta"], ["hypothesis", "Hipótesis"],
				["notes", "Notas"], ["conclusion", "Conclusión"]]:
			var value := str(record.get(field[0], ""))
			if not value.is_empty():
				lines.append("%s: %s" % [field[1], value])
		lines.append("")
	_history.text = "\n".join(lines) if not lines.is_empty() else "Aún no hay ensayos guardados."


func _label(value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	return label


func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 34
	button.pressed.connect(action)
	return button
