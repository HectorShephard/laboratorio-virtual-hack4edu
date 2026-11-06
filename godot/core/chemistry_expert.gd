extends RefCounted
## Motor local: solo recibe hechos, nunca referencias al laboratorio ni acciones ejecutables.
const Model=preload("res://core/chemistry_model.gd")
var testing:=false
var case_index:=0

static func readonly(data:Dictionary)->Dictionary:
	var copy:=data.duplicate(true)
	_freeze(copy)
	return copy

static func _freeze(value:Variant)->void:
	if value is Dictionary or value is Array:
		for child in (value.values() if value is Dictionary else value):_freeze(child)
		value.make_read_only()

func _normal(text:String)->String:
	var normalized:=text.to_lower().strip_edges()
	for pair in [["á","a"],["é","e"],["í","i"],["ó","o"],["ú","u"],["ü","u"]]:normalized=normalized.replace(pair[0],pair[1])
	return normalized

func _has(text:String,words:Array)->bool:
	for word in words:
		if text.contains(word):return true
	return false

func _reply(text:String,rule:String)->Dictionary:return {"text":text,"rule":rule}

func _action(f:Dictionary,key:String)->String:
	var action:Dictionary=f.get("actions",{}).get(key,{})
	return str(action.get("label","")) if action.get("available",false) else ""

func answer(question:String,f:Dictionary)->Dictionary:
	var q:=_normal(question)
	var wants_save:=_has(q,["guard","registr","anotar","cuaderno"])
	var wants_restart:=_has(q,["reinici","repetir","otro ensayo","empezar de nuevo"])
	if not f.get("active",false) or f.get("experiment_id","")!=Model.EXPERIMENT_ID:
		return _reply("Ayudo con el Laboratorio 1 de " + Model.TITLE + ". Abre la práctica de química para consultar sus datos.","inactive")
	if _has(q,["fisica","biologia","fotosint","newton","cohete","sapo","matemat","historia universal","capital de","alcohol"]):
		return _reply("Mi especialidad es la práctica abierta de " + str(f.title) + ". Puedes volver a ella con «¿Qué hago ahora?».","scope")
	if _has(q,["modo normal","salir de modo pruebas","terminar pruebas"]):
		testing=false
		return _reply("Modo pruebas desactivado. Puedes preguntar por el siguiente paso de tu ensayo.","test_exit")
	if _has(q,["modo pruebas","modo prueba","siguiente caso","otro caso","comprobar caso"]):
		if _has(q,["siguiente caso","otro caso"]):case_index=mini(case_index+1,cases().size()-1)
		elif not testing:case_index=0
		testing=true
		return _reply(test_case(f),"test_case")
	# Preguntas puntuales se resuelven sin forzar la regla de fase.
	if _has(q,["unidad","en que se mide","mililitro","mmol"]):
		if not f.has("result_unit") or not f.has("fields"):return _reply("Faltan las unidades confirmadas por la práctica; vuelve a abrir Química para consultarlas.","missing_units")
		return _reply("El resultado del modelo se expresa en %s de CO₂ teórico; el vinagre se indica en %s y el bicarbonato en %s. La concentración se registra aparte, en %s." % [f.result_unit,f.fields.initial_ml.unit,f.fields.bicarbonate_g.unit,f.fields.concentration.unit],"units")
	if _has(q,["historial","ensayos anteriores","consultar"]):
		return _reply("Los ensayos guardados se consultan en la página derecha del cuaderno." if f.notebook_open else "Pulsa «%s» para consultar los ensayos guardados." % f.actions.notebook.label,"history")
	if _has(q,["material","reactivo","que necesito","que practica"]) and not _has(q,["limita","agota"]):
		return _reply(str(f.materials)+" La práctica abierta es «"+str(f.title)+"».","materials")
	if _has(q,["cantidades","cuanto vinagre","cuanto llevo","volumen recibido"]):
		if f.prepared.is_empty():return _reply("Todavía no has preparado cantidades para este ensayo. "+next_step(f),"not_prepared")
		return _reply("Preparaste %.1f mL iniciales y %.1f g de bicarbonato, con una dosis objetivo de %.1f mL. Entraron realmente %.1f mL al vaso; quedan %.1f mL en el frasco." % [f.prepared.initial_ml,f.prepared.bicarbonate_g,f.prepared.target_ml,f.used_ml,f.remaining_ml],"quantities")
	if _has(q,["resultado","medicion","co2","co₂","limita","agota","burbuja","significa","produjo"]) and not wants_save and not wants_restart:
		if testing:return _reply(test_case(f),"test_observation")
		if f.get("measurement",{}).is_empty():return _reply("Todavía no hay una medición de este ensayo. "+next_step(f),"missing_measurement")
		return _reply(describe(f.measurement),"measurement")
	if wants_save and not wants_restart:return _reply(save_help(f),"journal")
	if wants_restart:
		var action:=_action(f,"repeat")
		if action.is_empty() and not f.journal.saved.is_empty():return _reply("Pulsa «%s» para volver a los controles y repetir el ensayo." % f.actions.return_chemistry.label,"restart_controls")
		return _reply("Pulsa «%s» para comenzar un ensayo nuevo; su resultado estará pendiente." % action if not action.is_empty() else "Primero termina y registra el ensayo activo. "+save_help(f),"restart")
	if _has(q,["ahora","siguiente paso","que hago","continu","mezcl","vert","prepar","empez","iniciar"]):
		return _reply(next_step(f),"next_step")
	return _reply("¿Quieres consultar el siguiente paso, los materiales, las unidades, el resultado, guardar o reiniciar? También puedes elegir un acceso rápido.","clarify")

func next_step(f:Dictionary)->String:
	if not f.has("phase"):return "Falta la fase actual de la práctica; vuelve a abrir Química para obtenerla."
	if not f.get("validation",{}).is_empty():return str(f.validation.message)+" Corrige ese campo antes de preparar."
	if not f.get("journal",{}).get("error","").is_empty():return save_help(f)
	if f.get("notebook_open",false):
		if not f.journal.pending.is_empty():return save_help(f)
		var close:=_action(f,"close_book")
		if not close.is_empty():return "Pulsa «%s» para volver al banco." % close
	if not f.get("bank_view",false) and not _action(f,"bench").is_empty():return "Pulsa «%s» para trabajar con los recipientes." % _action(f,"bench")
	var key:String={"PREPARE":"prepare","BICARBONATE":"add","OBSERVE":"observe","REGISTER":"notebook"}.get(f.get("phase",""),"")
	if f.phase=="POUR":
		if f.flowing:return "Observa los mL recibidos hasta alcanzar la dosis de %s mL." % f.prepared.get("target_ml",f.inputs.target_ml)
		if not f.bottle_held:
			return "Apunta la palma al frasco y flexiona los dedos para agarrarlo." if f.mode=="webcam" else "Mantén clic izquierdo sobre el cuerpo del frasco para agarrarlo."
		if not f.receiving:return "Acerca el pico al vaso hasta que su borde se resalte."
		return "Inclina la muñeca unos %s° desde la postura de agarre para verter." % f.hand_start_angle if f.mode=="webcam" else "Usa la rueda del ratón para inclinar el frasco sobre el vaso."
	if f.phase=="OBSERVE" and (f.bottle_held or f.vessel_held):
		return "Abre la mano que sostiene el recipiente para soltarlo antes de observar." if f.mode=="webcam" else "Suelta el clic izquierdo antes de observar la reacción."
	if f.phase=="REGISTER":return save_help(f)
	if f.phase=="COMPLETED":return save_help(f)
	var action:=_action(f,key)
	if not action.is_empty():return "Pulsa «%s»." % action
	var return_action:=_action(f,"return_chemistry")
	return "Pulsa «%s» para mostrar los controles de la práctica." % return_action if not return_action.is_empty() else "Falta un control visible para indicar el siguiente paso; vuelve a la práctica de química."

func describe(m:Dictionary)->String:
	var text:="El modelo estima %.3f %s de CO₂ teórico" % [m.value,m.unit]
	if m.has("limiting_reagent"):text+="; se agota primero: %s" % m.limiting_reagent
	text+="."
	var p:Dictionary=m.get("parameters",{})
	if p.has("vertido_ml"):text+=" Se usaron %.1f mL realmente vertidos de %.1f mL iniciales y %.1f g de bicarbonato." % [p.vertido_ml,p.volumen_inicial_ml,p.bicarbonato_g]
	return text+" Las burbujas son una ilustración, no una medición de gas."

func save_help(f:Dictionary)->String:
	var journal:Dictionary=f.get("journal",{})
	if not journal.get("error","").is_empty():
		return str(journal.error).trim_suffix(".")+". Puedes reintentar con «%s» cuando el cuaderno esté abierto." % f.actions.save.label
	if not journal.get("saved",{}).is_empty():
		return "El cuaderno confirmó el guardado de este ensayo. Consúltalo con «%s»; para otro ensayo usa «%s» cuando esté visible." % [f.actions.notebook.label,f.actions.repeat.label]
	if not journal.get("pending",{}).is_empty():
		var action:=_action(f,"save")
		if not action.is_empty():return "El resultado sigue pendiente de registro. Pulsa «%s»." % action
		return "El resultado está pendiente: abre «%s» para anotarlo." % f.actions.notebook.label
	if f.get("measurement",{}).is_empty():return "Todavía no hay un resultado de este ensayo para guardar. "+next_step_without_book(f)
	return "Falta la confirmación del cuaderno para este ensayo; no puedo afirmar que esté guardado."

func next_step_without_book(f:Dictionary)->String:
	if not f.get("validation",{}).is_empty():return str(f.validation.message)
	if f.get("phase","") in ["REGISTER","COMPLETED"]:return "Falta una medición válida del ensayo activo; vuelve a la práctica para obtenerla."
	return "Vuelve al banco con «%s» y sigue la fase actual." % f.actions.close_book.label if f.get("notebook_open",false) else next_step(f)

func cases()->Array:
	var definitions:=[{"name":"Ensayo válido","ml":50.0,"g":3.0},{"name":"Cambia el limitante","ml":50.0,"g":5.0},{"name":"Falta vinagre","ml":0.0,"g":3.0},{"name":"Dato fuera del rango","ml":50.0,"g":-1.0},{"name":"Recuperación y cuaderno","ml":50.0,"g":3.0}]
	var result:Array=[]
	for definition in definitions:
		var values:Dictionary={}
		for key in Model.INPUTS:values[key]=Model.INPUTS[key].default
		values.target_ml=definition.ml
		values.bicarbonate_g=definition.g
		result.append({"name":definition.name,"inputs":values,"expected":Model.estimate(definition.ml,definition.g,values.concentration),"validation":Model.validate_preparation(values)})
	return result

func test_case(f:Dictionary)->String:
	var c:Dictionary=cases()[case_index]
	var text:="Caso %d/%d · %s. Entradas: %.1f mL de vinagre a %.1f %% m/v y %.1f g de bicarbonato (frasco inicial %.1f mL). " % [case_index+1,cases().size(),c.name,c.inputs.target_ml,c.inputs.concentration,c.inputs.bicarbonate_g,c.inputs.initial_ml]
	if not c.validation.is_empty():
		text+="Acción: intenta introducir el dato en su campo. Esperado por el modelo/interfaz actual: rechazo. "+str(c.validation.message)
		text+=" Observado: "+(str(f.validation.message) if not f.validation.is_empty() and f.validation.get("field","")==c.validation.field else "pendiente; no hay un rechazo confirmado para este caso.")
		return text
	text+="Acción: prepara, añade bicarbonato, vierte la dosis y observa. Esperado: %.3f %s teóricos; limitante: %s. " % [c.expected.value,c.expected.unit,c.expected.limiting_reagent]
	if f.measurement.is_empty():return text+"Observado: pendiente de medición en el ensayo actual."
	var m:Dictionary=f.measurement
	var p:Dictionary=m.parameters
	if not is_equal_approx(float(p.get("vertido_ml",-1)),float(c.inputs.target_ml)) or not is_equal_approx(float(p.get("bicarbonato_g",-1)),float(c.inputs.bicarbonate_g)) or not is_equal_approx(float(p.get("concentracion",-1)),float(c.inputs.concentration)):
		return text+"El ensayo actual tiene otras cantidades; no corresponde a este caso."
	text+="Observado: %.3f %s; limitante: %s." % [m.value,m.unit,m.get("limiting_reagent","no informado")]
	if case_index==4:text+=" Cuaderno: "+("guardado confirmado para este ensayo." if not f.journal.saved.is_empty() else "pendiente de confirmación de guardado.")
	return text
