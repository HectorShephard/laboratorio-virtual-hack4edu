extends PanelContainer
## Dos páginas: borrador actual e historial persistente compartido con la bitácora.
const Journal = preload("res://bitacora/run_journal.gd")
signal record_saved(record: Dictionary)
signal record_save_failed(record:Dictionary,message:String)
signal assistant_requested
const Walnut = preload("res://ui/walnut_theme.gd")
var _journal := Journal.new()
var _fields: Dictionary = {}
var _history: TextEdit
var _status: Label
var _result: Label
var _save_button: Button
var pending: Dictionary = {}
var page_index := 0
var page_label: Label
var close_button:Button
var last_saved:Dictionary={}
var save_error:Dictionary={}
var assistant_button:Button

func _ready() -> void:
	theme = Walnut.make_theme()
	var skin := Walnut.panel(Color("e9dbb9"), 8)
	skin.set_content_margin_all(22)
	add_theme_stylebox_override("panel", skin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var heading := HBoxContainer.new()
	var wood_heading := PanelContainer.new()
	wood_heading.add_theme_stylebox_override("panel", Walnut.panel())
	column.add_child(wood_heading)
	wood_heading.add_child(heading)
	var title := _label("CUADERNO DE HALLAZGOS", 24)
	title.add_theme_color_override("font_color", Walnut.IVORY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	assistant_button=_button("Asistente de química",func():assistant_requested.emit())
	assistant_button.hide()
	heading.add_child(assistant_button)
	close_button=_button("Cerrar [B / Esc]",hide)
	heading.add_child(close_button)
	column.add_child(_label("Pinza corta: activar · Pulgar + medio: cerrar · Desliza a los lados para pasar páginas", 13))
	var pages := HBoxContainer.new()
	pages.add_theme_constant_override("separation", 20)
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(pages)
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages.add_child(left_scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(form)
	form.add_child(_label("Ensayo actual · Pregunta y predicción", 17))
	_result = _label("Prepara una mezcla con C y vuelve aquí para registrar el resultado.", 15)
	form.add_child(_result)
	for field in [["question", "Pregunta"], ["hypothesis", "Hipótesis"], ["notes", "Observaciones"], ["conclusion", "Conclusión"]]:
		form.add_child(_label(field[1], 15))
		var input := TextEdit.new()
		input.custom_minimum_size = Vector2(0, 48)
		input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		_paper_input(input)
		form.add_child(input)
		_fields[field[0]] = input
	pages.add_child(VSeparator.new())
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(right)
	right.add_child(_label("Ensayos anteriores · Compara cantidades y CO₂", 17))
	_history = TextEdit.new()
	_history.editable = false
	_paper_input(_history)
	_history.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_history)
	var navigation := HBoxContainer.new()
	right.add_child(navigation)
	navigation.add_child(_button("‹ Anterior", turn_page.bind(-1)))
	page_label = _label("", 14)
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(page_label)
	navigation.add_child(_button("Siguiente ›", turn_page.bind(1)))
	_save_button = _button("Anotar ensayo en el cuaderno", save_pending)
	column.add_child(_save_button)
	_status = _label("Los ensayos se guardan en la bitácora local.", 14)
	column.add_child(_status)
	_refresh_history()

func open_panel() -> void:
	_refresh_history()
	show()

func set_result(record: Dictionary) -> void:
	save_error={}
	pending = record.duplicate(true)
	pending["run_id"] = _journal.new_id()
	_result.text = describe(pending)
	_save_button.disabled = false
	_status.text = "Resultado listo. Completa tus observaciones y conclusión antes de anotarlo."

func save_pending() -> void:
	if pending.is_empty():
		return
	var record := pending.duplicate(true)
	for key in _fields:
		record[key] = _fields[key].text.strip_edges()
	record["saved_at_utc"] = Time.get_datetime_string_from_system(true) + "Z"
	var error := _journal.save(record)
	if error != OK:
		_status.text = "No se pudo guardar: " + error_string(error)
		save_error={"session_id":record.get("lab1_session",""),"message":_status.text}
		record_save_failed.emit(record.duplicate(true),_status.text)
		return
	last_saved=record.duplicate(true)
	save_error={}
	pending = {}
	_save_button.disabled = true
	_status.text = "Ensayo anotado. Puedes preparar otra mezcla y comparar."
	for input: TextEdit in _fields.values():
		input.clear()
	_refresh_history()
	record_saved.emit(record)

func snapshot_for_session(session_id:String)->Dictionary:
	var current_pending:Dictionary=pending.duplicate(true) if pending.get("lab1_session","")==session_id else {}
	var current_saved:Dictionary=last_saved.duplicate(true) if last_saved.get("lab1_session","")==session_id else {}
	return {"pending":current_pending,"saved":current_saved,"error":save_error.get("message","") if save_error.get("session_id","")==session_id else "","open":visible}

static func describe(record: Dictionary) -> String:
	var text := "%s: %.3f %s · %s" % [record.get("quantity", "Resultado"), float(record.get("value", 0)), record.get("unit", ""), record.get("validity", "")]
	if record.get("lab_completed",false):
		text += "\nLaboratorio 1 completado"
	var parameters: Dictionary = record.get("parameters", {})
	if parameters.has("vinagre_ml"):
		text += "\nCantidades: %.1f mL de vinagre · %.1f g de bicarbonato" % [parameters.vinagre_ml, parameters.bicarbonato_g]
	elif parameters.has("vertido_ml"):
		text += "\n%s: %.1f mL vertidos de %.1f mL iniciales\n%.1f %% vertido · %.1f mL restantes" % [parameters.liquido, parameters.vertido_ml, parameters.volumen_inicial_ml, parameters.porcentaje_vertido, parameters.restante_ml]
	else:
		text += "\nCondiciones: " + JSON.stringify(parameters)
	if parameters.has("concentracion"):
		text += "\nConcentración: %.1f %s" % [parameters.concentracion, parameters.unidad_concentracion]
	if record.has("limiting_reagent"):
		text += "\nSe agota primero: " + str(record.limiting_reagent)
	return text + "\n" + str(record.get("assumptions", ""))

func _paper_input(input: TextEdit) -> void:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f3e9d0")
	paper.border_color = Color("bdab87")
	paper.border_width_bottom = 1
	paper.set_content_margin_all(6)
	input.add_theme_stylebox_override("normal", paper)
	input.add_theme_stylebox_override("read_only", paper)
	input.add_theme_color_override("font_color", Color("38291c"))
	input.add_theme_color_override("font_readonly_color", Color("38291c"))
	input.add_theme_color_override("caret_color", Color("38291c"))

func _refresh_history() -> void:
	var lines := PackedStringArray()
	var records := _journal.recent(200)
	page_index = clampi(page_index, 0, maxi(0, records.size() - 1))
	if page_label != null:
		page_label.text = "Ensayo %d / %d" % [page_index + 1 if not records.is_empty() else 0, records.size()]
	for record in records.slice(page_index, page_index + 1):
		lines.append(str(record.get("saved_at_utc", "")) + " · " + str(record.experiment_id))
		lines.append(describe(record))
		for field in [["question", "Pregunta"], ["hypothesis", "Hipótesis"], ["notes", "Observaciones"], ["conclusion", "Conclusión"]]:
			lines.append(field[1] + ": " + str(record.get(field[0], "")))
		lines.append("────────────────────")
	_history.text = "\n".join(lines) if not lines.is_empty() else "Aún no hay ensayos guardados."
	_save_button.disabled = pending.is_empty()

func turn_page(direction: int) -> void:
	page_index += direction
	_refresh_history()

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("38291c"))
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	return button
