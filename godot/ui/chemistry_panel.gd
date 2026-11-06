extends PanelContainer
signal mixed(record: Dictionary)
const Walnut = preload("res://ui/walnut_theme.gd")
const Session = preload("res://core/lab1_session.gd")
const Model = preload("res://core/chemistry_model.gd")
var session := Session.new()
var lab: Node
var vinegar: SpinBox
var bicarbonate: SpinBox
var concentration: SpinBox
var capacity: SpinBox
var dose: SpinBox
var liquid: OptionButton
var mix_button: Button
var add_button: Button
var notebook_button: Button
var repeat_button: Button
var prepare_button: Button
var config: VBoxContainer
var step_label: Label
var heading: Label
var status: Label
var volumes: Label
var selected_object: Label
var poured_value: Label
var remaining_value: Label
var free_value: Label
var prepared: Dictionary = {}
var last_validation:Dictionary={}
var active_measurement:Dictionary={}
var inputs:Dictionary={}
var edited_text:Dictionary={}
var predicted_input:Dictionary={}

func _ready() -> void:
	var skin := Walnut.panel()
	skin.set_content_margin_all(10)
	add_theme_stylebox_override("panel", skin)
	theme = Walnut.make_theme()
	var column := VBoxContainer.new()
	add_child(column)
	heading = _label(column, "LABORATORIO 1 · VINAGRE + BICARBONATO")
	step_label = _label(column, session.instruction())
	step_label.add_theme_color_override("font_color", Walnut.AMBER)
	selected_object = _label(column, "Apunta al vaso o frasco")
	var readings := HBoxContainer.new()
	column.add_child(readings)
	poured_value = _reading(readings, "mL VERTIDOS")
	remaining_value = _reading(readings, "mL RESTANTES")
	free_value = _label(column, "")
	volumes = _label(column, "")
	config = VBoxContainer.new()
	column.add_child(config)
	liquid = OptionButton.new()
	liquid.add_item("Alcohol · práctica de transferencia")
	liquid.add_item("Vinagre · Laboratorio 1")
	liquid.select(1)
	config.add_child(liquid)
	liquid.item_selected.connect(func(index: int): concentration.value = 70 if index == 0 else Model.INPUTS.concentration.default)
	var row := HBoxContainer.new()
	config.add_child(row)
	vinegar = _amount(row,"initial_ml")
	capacity = _amount(row,"capacity_ml")
	var second := HBoxContainer.new()
	config.add_child(second)
	concentration = _amount(second,"concentration")
	bicarbonate = _amount(second,"bicarbonate_g")
	var third := HBoxContainer.new()
	config.add_child(third)
	dose = _amount(third,"target_ml")
	prepare_button = _action(column, "Preparar vaso y ensayo", prepare)
	add_button = _action(column, "Añadir bicarbonato al vaso", add_bicarbonate)
	mix_button = _action(column, "Observar reacción", mix)
	notebook_button = _action(column, "Ver cuaderno", func(): lab._open_experiment())
	repeat_button = _action(column, "Repetir ensayo", repeat)
	status = _label(column, "Palma: apuntar · Flexiona dedos: agarrar/mover · Muñeca: inclinar · Abre: soltar.\nRatón: arrastrar + rueda.")
	status.add_theme_font_size_override("font_size", 12)
	_refresh()

func _action(parent: Node, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _reading(parent: Node, caption: String) -> Label:
	var card := PanelContainer.new()
	var skin := Walnut.panel(Color("211d19"), 3)
	skin.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", skin)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var column := VBoxContainer.new()
	card.add_child(column)
	var small := _label(column, caption)
	small.add_theme_font_size_override("font_size", 11)
	var number := _label(column, "0")
	number.add_theme_font_size_override("font_size", 26)
	return number

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _amount(parent: Node, key:String) -> SpinBox:
	var spec:Dictionary=Model.INPUTS[key]
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	_label(column, spec.label)
	var input := SpinBox.new()
	input.min_value = spec.min
	input.max_value = spec.max
	input.step = spec.step
	input.value = spec.default
	inputs[key]=input
	input.get_line_edit().gui_input.connect(_capture_number_input.bind(key,input.get_line_edit()))
	input.value_changed.connect(func(_value:float):
		if not last_validation.is_empty():
			last_validation={}
			if status!=null:status.text="Dato corregido. Revisa las cantidades y prepara el ensayo.")
	input.get_line_edit().text_changed.connect(func(text:String):
		if input.get_line_edit().has_focus() and not predicted_input.get(key,false):edited_text[key]=text)
	input.get_line_edit().text_submitted.connect(func(text:String):
		_validate_text(key,edited_text.get(key,text))
		edited_text.erase(key)
		predicted_input.erase(key))
	input.get_line_edit().focus_exited.connect(func():
		if edited_text.has(key):
			_validate_text(key,edited_text[key])
			edited_text.erase(key)
		predicted_input.erase(key))
	column.add_child(input)
	return input

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if lab == null or lab.challenges.active != 2 or lab.garage_pointer == null:
		return
	var state = lab.challenges.transfer
	var guided: bool = liquid.selected == 1
	heading.text = "LABORATORIO 1 · VINAGRE + BICARBONATO" if guided else "ALCOHOL · PRÁCTICA DE TRANSFERENCIA"
	dose.get_parent().visible = guided
	if guided:
		session.update_volume(state.poured_ml)
	step_label.text = session.instruction() if guided else "Práctica de transferencia · Alcohol sin reacción de CO₂"
	selected_object.text = lab.garage_pointer.selection_text()
	poured_value.text = String.num(state.poured_ml, 1)
	remaining_value.text = String.num(state.remaining_ml, 1)
	free_value.text = "Todavía caben %s mL en el vaso" % String.num(maxf(0, state.capacity_ml-state.poured_ml),1)
	volumes.text = state.summary()
	if lab.challenges.receiving:
		volumes.text += " · Borde alineado"
	if state.interrupted and not state.mixed:
		volumes.text += " · Endereza el frasco para reanudar"
	var idle := session.step == Session.Step.PREPARE
	config.visible = idle or not guided
	prepare_button.visible = idle or not guided
	add_button.visible = guided and session.step == Session.Step.BICARBONATE
	mix_button.visible = not guided or session.step == Session.Step.OBSERVE
	mix_button.text = "Observar reacción" if guided else "Registrar transferencia"
	mix_button.disabled = state.poured_ml <= 0 or state.mixed or lab.garage_pointer.held_object != null
	notebook_button.visible = guided and session.step in [Session.Step.REGISTER,Session.Step.COMPLETED]
	repeat_button.visible = guided and session.step == Session.Step.COMPLETED

func prepare() -> void:
	if not lab.experiment_panel.pending.is_empty():
		_validation_error({"message":"Anota primero el ensayo pendiente en el cuaderno."})
		return
	if lab.garage_pointer.held_object != null:
		_validation_error({"message":"Suelta los objetos antes de preparar."})
		return
	if liquid.selected==1:
		var error:=Model.validate_preparation(input_values())
		if not error.is_empty():
			_validation_error(error)
			return
	last_validation={}
	active_measurement={}
	lab.challenges.configure_transfer(vinegar.value,capacity.value,"alcohol" if liquid.selected==0 else "vinagre",concentration.value)
	prepared = {"bicarbonate":bicarbonate.value}
	prepared.merge(input_values())
	if liquid.selected == 1:
		session.prepare(dose.value,bicarbonate.value)
		lab.challenges.transfer.enabled = false
		lab.challenges.transfer.dose_limit_ml = dose.value
	status.text = "Vaso preparado. Sigue el paso indicado."
	_refresh()

func add_bicarbonate() -> void:
	if session.add_bicarbonate():
		lab.challenges.powder.visible = true
		lab.challenges.transfer.enabled = true
		status.text = "%s g de bicarbonato añadidos. Agarra vaso y frasco con cualquiera de las manos." % String.num(session.bicarbonate_g,1)
	_refresh()

func mix() -> void:
	var state = lab.challenges.transfer
	if lab.garage_pointer.held_object != null:
		return
	var guided: bool = liquid.selected == 1
	session.update_volume(state.poured_ml)
	if guided and session.step != Session.Step.OBSERVE:
		return
	var result: Dictionary = state.record(session.bicarbonate_g if guided else 0)
	if result.is_empty():
		return
	if guided:
		session.observe()
		result["laboratory_id"] = "quimica-1"
		result["lab1_session"] = session.session_id
		result["lab_completed"] = true
		result.parameters["dosis_objetivo_ml"] = session.target_ml
		result.parameters["mano_vaso"] = lab.challenges.beaker.get_meta("last_hand_id",-1)
		result.parameters["mano_frasco"] = lab.challenges.bottle.get_meta("last_hand_id",-1)
		result.parameters["etiqueta_vaso"] = lab.challenges.beaker.get_meta("last_hand_label","")
		result.parameters["etiqueta_frasco"] = lab.challenges.bottle.get_meta("last_hand_label","")
		active_measurement=result.duplicate(true)
	state.mixed = true
	lab.challenges.powder.visible = false
	status.text = "Observa las burbujas. Abre el cuaderno y anota el resultado teórico." if guided else "Transferencia medida. Abre el cuaderno para anotar el volumen."
	mixed.emit(result)
	_refresh()

func on_saved(record: Dictionary) -> void:
	if session.saved(record):
		status.text = "Laboratorio completado · Ensayo guardado en la bitácora."
		lab.experiment_panel.hide()
		show()
		_refresh()

func repeat() -> void:
	if not lab.experiment_panel.pending.is_empty():
		return
	lab.garage_pointer.cancel()
	session.reset()
	last_validation={}
	active_measurement={}
	prepared.clear()
	lab.challenges.configure_transfer(vinegar.value,capacity.value,"vinagre",concentration.value)
	lab.challenges.transfer.enabled = false
	status.text = "Elige la dosis del siguiente ensayo y prepara el vaso."
	_refresh()

func reset_for_new_kit() -> void:
	session.reset()
	last_validation={}
	active_measurement={}
	liquid.select(1)
	concentration.value = Model.INPUTS.concentration.default
	prepared.clear()
	status.text = "Prepara el vaso para comenzar el Laboratorio 1."
	_refresh()

func _validation_error(error:Dictionary)->void:
	last_validation=error.duplicate(true)
	last_validation["session_id"]=session.session_id
	status.text=error.message

func _validate_text(key:String,text:String)->void:
	var spec:Dictionary=Model.INPUTS[key]
	var normalized:=text.strip_edges().replace(",",".")
	var error:=Model.validate_field(key,float(normalized)) if normalized.is_valid_float() else {"field":key,"unit":spec.unit,"min":spec.min,"max":spec.max,"message":"%s: introduce un número entre %s y %s %s." % [spec.label,spec.min,spec.max,spec.unit]}
	if not error.is_empty():_validation_error(error)
	elif last_validation.get("field","")==key:
		last_validation={}
		status.text="Dato corregido. Revisa las cantidades y prepara el ensayo."

func _capture_number_input(event:InputEvent,key:String,edit:LineEdit)->void:
	if not event is InputEventKey or not event.pressed:return
	if event.keycode in [KEY_UP,KEY_DOWN]:
		edited_text.erase(key)
		predicted_input.erase(key)
		return
	var insert:=""
	if event.ctrl_pressed and event.keycode==KEY_V:insert=DisplayServer.clipboard_get()
	elif not event.ctrl_pressed and not event.meta_pressed and event.unicode>=32:insert=String.chr(event.unicode)
	elif event.keycode not in [KEY_BACKSPACE,KEY_DELETE]:return
	var start:=edit.get_selection_from_column() if edit.has_selection() else edit.caret_column
	var end:=edit.get_selection_to_column() if edit.has_selection() else edit.caret_column
	if insert.is_empty() and start==end:
		if event.keycode==KEY_BACKSPACE:start=maxi(0,start-1)
		elif event.keycode==KEY_DELETE:end=mini(edit.text.length(),end+1)
	# Guardar el intento antes de que SpinBox lo limite/formatee.
	edited_text[key]=edit.text.left(start)+insert+edit.text.substr(end)
	predicted_input[key]=true

func input_values()->Dictionary:
	var values:Dictionary={}
	for key in inputs:values[key]=inputs[key].value
	return values

func assistant_available()->bool:
	return lab!=null and lab.exploring and lab.challenges.active==2 and liquid.selected==1

func _action_fact(button:Button)->Dictionary:
	return {"label":button.text,"available":button.is_visible_in_tree() and not button.disabled}

func expert_snapshot()->Dictionary:
	var journal:Dictionary=lab.experiment_panel.snapshot_for_session(session.session_id)
	var measurement:Dictionary=active_measurement.duplicate(true) if active_measurement.get("lab1_session","")==session.session_id else {}
	var state=lab.challenges.transfer
	var held_bottle:bool=lab.challenges.active==2 and bool(lab.challenges.bottle.get_meta("held",false))
	var held_vessel:bool=lab.challenges.active==2 and bool(lab.challenges.beaker.get_meta("held",false))
	var actions:Dictionary={"prepare":_action_fact(prepare_button),"add":_action_fact(add_button),"observe":_action_fact(mix_button),"repeat":_action_fact(repeat_button),"notebook":_action_fact(lab.notebook_open_button),"save":_action_fact(lab.experiment_panel._save_button),"close_book":_action_fact(lab.experiment_panel.close_button),"return_chemistry":_action_fact(lab.chemistry_open_button)}
	actions["bench"]=_action_fact(lab.view_buttons[1])
	var data:Dictionary={"active":assistant_available(),"experiment_id":Model.EXPERIMENT_ID,"title":Model.TITLE,"session_id":session.session_id,"phase":Session.Step.keys()[session.step],"inputs":input_values(),"prepared":prepared.duplicate(true),"fields":Model.INPUTS.duplicate(true),"validation":last_validation.duplicate(true) if last_validation.get("session_id","")==session.session_id else {},"measurement":measurement,"journal":journal,"actions":actions,"materials":lab.challenges.KITS[2],"result_unit":Model.UNIT,"model_version":Model.MODEL_VERSION,"mode":"mouse" if lab.mouse_mode else "webcam","used_ml":state.poured_ml if session.step!=Session.Step.PREPARE else 0.0,"remaining_ml":state.remaining_ml,"bottle_held":held_bottle,"vessel_held":held_vessel,"receiving":lab.challenges.receiving,"flowing":lab.challenges.flowing,"hand_start_angle":state.HAND_START_ANGLE,"hand_stop_angle":state.HAND_STOP_ANGLE,"notebook_open":lab.experiment_panel.visible}
	data["bank_view"]=lab.fixed_view==1
	return preload("res://core/chemistry_expert.gd").readonly(data)
