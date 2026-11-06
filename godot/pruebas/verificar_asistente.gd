extends "res://pruebas/verificar_flexion.gd"
const Model=preload("res://core/chemistry_model.gd")
const Expert=preload("res://core/chemistry_expert.gd")
const Journal=preload("res://bitacora/run_journal.gd")
class FailedJournal extends Journal:
	func save(_record:Dictionary)->Error:return ERR_CANT_CREATE
var p:Node
var assistant:Node
var answers:Array=[]

func ask(text:String)->Dictionary:
	var before:=digest()
	assistant.ask(text)
	var result:Dictionary=assistant.last_reply
	check(digest()==before,"La consulta no altera práctica ni bitácora: "+text)
	answers.append({"question":text,"answer":result,"phase":p.session.step,"session_id":p.session.session_id})
	return result

func digest()->String:
	return JSON.stringify({"session":p.session.session_id,"phase":p.session.step,"inputs":p.input_values(),"used":lab.challenges.transfer.poured_ml,"remaining":lab.challenges.transfer.remaining_ml,"pending":lab.experiment_panel.pending,"records":lab.experiment_panel._journal.recent().size()})

func click_control(control:Button)->void:
	await process_frame
	lab.garage_pointer.actors[0]._click(control.get_global_rect().get_center())
	await process_frame

func run()->void:
	fixture=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../registros/flexion_fixture.json")))
	lab=load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.synthetic=true
	lab.challenges.set_process(false)
	lab.garage_pointer.mouse.set_process(false)
	var journal:=Journal.new("user://asistente-aceptacion/"+str(Time.get_unix_time_from_system()))
	lab.experiment_panel._journal=journal
	p=lab.chemistry_panel
	assistant=lab.chemistry_assistant
	assistant._process(.2)
	check(not lab.chemistry_assistant_button.visible,"Asistente inactivo fuera de Laboratorio 1")
	await click("Química [C]")
	assistant._process(.2)
	check(lab.chemistry_assistant_button.visible,"Botón de asistente disponible en la práctica correcta")
	await click_control(lab.chemistry_assistant_button)
	check(assistant.visible,"El botón real abre el panel")
	var facts:Dictionary=p.expert_snapshot()
	check(facts.is_read_only() and facts.inputs.is_read_only() and facts.fields.bicarbonate_g.is_read_only(),"Instantánea recursivamente de solo lectura")
	check(facts.experiment_id==Model.EXPERIMENT_ID and facts.phase=="PREPARE","Identificador y fase proceden del controlador activo")
	check(ask("¿En qué unidad se mide?").text.contains("mmol"),"Unidades puntuales antes de preparar")
	check(ask("¿Qué materiales necesito?").text.contains("Vaso"),"Materiales de la escena actual")
	check(ask("¿Qué significa el resultado?").rule=="missing_measurement","Resultado antes de mezclar se declara pendiente")
	check(ask("Explícame la fotosíntesis").rule=="scope","Pregunta de otra materia queda fuera del alcance")
	check(ask("Ayuda").rule=="clarify","Pregunta ambigua ofrece opciones")
	check(ask("¿Qué hago ahora?").text.contains(p.prepare_button.text),"Un solo paso con el nombre real del botón")
	lab._set_fixed_view(0)
	check(ask("qué hago ahora").text.contains(lab.view_buttons[1].text),"No recomienda agarrar recipientes desde un encuadre que no permite seleccionarlos")
	lab._set_fixed_view(1)
	# Texto escrito no dispara navegación ni salida.
	assistant.question.grab_focus()
	var initial_view:int=lab.fixed_view
	for code in [KEY_B,KEY_C,KEY_E,KEY_Q,KEY_R,KEY_1,KEY_2,KEY_3,KEY_F3]:
		var event:=InputEventKey.new()
		event.keycode=code
		event.unicode=code+32 if code in [KEY_B,KEY_C,KEY_E,KEY_Q,KEY_R] else (code if code in [KEY_1,KEY_2,KEY_3] else 0)
		event.pressed=true
		root.push_input(event,true)
	check(lab.fixed_view==initial_view and not lab.experiment_panel.visible and not lab.garage_menu.visible and not lab.closing and not lab.garage_pointer.debug_overlay.visible,"Escribir b/c/e/q/1/2/3 no activa atajos del juego")
	assistant.question.clear()
	await click_control(assistant.test_button)
	check(assistant.expert.testing and assistant.test_button.button_pressed,"Acceso rápido activa Modo pruebas en la interfaz")
	await click_control(assistant.test_button)
	check(not assistant.expert.testing and not assistant.test_button.button_pressed,"Segundo clic sale del modo pruebas")
	var plan:=ask("Modo pruebas")
	check(plan.text.contains("35.711") and plan.text.contains("pendiente"),"Caso normal: esperado del mismo modelo, observado pendiente")
	var change:=ask("siguiente caso")
	check(change.text.contains("41.631") and change.text.contains("Ácido"),"Cambio de limitante esperado calculado por el modelo")
	check(ask("siguiente caso").text.contains("rechazo"),"Cero mL usa el rechazo de esta versión, sin inventar medición cero")
	check(ask("siguiente caso").text.contains("0.1"),"Dato negativo usa el intervalo activo de bicarbonato")
	assistant.expert.testing=false
	# Error real de interfaz, después de que SpinBox limite el valor.
	p.bicarbonate.value=-1
	p.bicarbonate.get_line_edit().text_submitted.emit("-1")
	var invalid:=ask("¿Qué hago ahora?")
	check(p.bicarbonate.value>=Model.INPUTS.bicarbonate_g.min and invalid.text.contains("Bicarbonato") and invalid.text.contains("20"),"Interfaz impide negativo y asistente muestra campo, g y rango real")
	p.bicarbonate.value=3
	var edit:LineEdit=p.bicarbonate.get_line_edit()
	edit.grab_focus()
	edit.select_all()
	for pair in [[KEY_MINUS,45],[KEY_1,49]]:
		var typed:=InputEventKey.new()
		typed.keycode=pair[0]
		typed.unicode=pair[1]
		typed.pressed=true
		root.push_input(typed,true)
	await process_frame
	assistant.question.grab_focus()
	await process_frame
	check(p.bicarbonate.value==Model.INPUTS.bicarbonate_g.min and ask("qué hago ahora").text.contains("Bicarbonato"),"Teclas reales y cambio de foco conservan el rechazo de -1 g")
	p.bicarbonate.value=3
	p.dose.value=0
	p.dose.get_line_edit().text_submitted.emit("0")
	check(p.dose.value==Model.INPUTS.target_ml.min and ask("qué hago ahora").text.contains("Dosis"),"Interfaz impide dosis cero y explica su límite")
	check(Model.estimate(0,3).is_empty(),"El modelo activo rechaza cero mL")
	p.dose.value=50
	await capture("asistente-panel")
	await click_control(assistant.close_button)
	check(not assistant.visible,"Cerrar con un clic deja el banco disponible")
	for trial in 2:
		if trial==1:
			lab._open_chemistry()
			await click("Repetir ensayo")
		var before_id:String=p.session.session_id
		positions=[Vector2(60,300),Vector2(650,250)]
		angles=[0,0]
		bent=[false,false]
		visible_hand=[true,true]
		p.bicarbonate.value=3 if trial==0 else 5
		p.dose.value=50
		p.concentration.value=5
		await click("Preparar vaso")
		check(p.session.session_id!=before_id and ask("qué hago ahora").text.contains(p.add_button.text),"Preparación crea ensayo y el siguiente paso es añadir bicarbonato")
		await click("Añadir bicarbonato")
		lab.mouse_mode=false # Señales de webcam simuladas, sin abrir otra cámara.
		check(ask("qué hago ahora").text.contains("flexiona"),"Control de agarre confirmado según modo webcam")
		await take(trial,lab.challenges.beaker,true)
		await take(1-trial,lab.challenges.bottle,true)
		var held=lab.garage_pointer.held_object
		assistant.open_panel()
		ask("¿Qué hago ahora?")
		check(lab.garage_pointer.held_object==held,"Abrir y consultar no suelta ni modifica objetos agarrados")
		await click_control(assistant.close_button)
		move_to(1-trial,Vector3(lab.challenges.beaker.global_position.x,1,lab.challenges.beaker.global_position.z),150)
		check(ask("qué hago ahora").text.contains(str(lab.challenges.transfer.HAND_START_ANGLE)),"Orientación usa el ángulo del controlador")
		angles[1-trial]=20
		frames(60)
		var partial:Dictionary=p.expert_snapshot()
		check(partial.prepared.initial_ml==100 and partial.used_ml>0 and partial.used_ml<50 and partial.measurement.is_empty(),"Distingue cantidad preparada, realmente usada y medición")
		check(ask("¿Qué cantidades llevo?").rule=="quantities","Pregunta puntual de cantidades responde durante el vertido")
		frames(300)
		check(ask("resultado").rule=="missing_measurement","Volumen preparado no se confunde con medición antes de observar")
		bent=[false,false]
		frames(1)
		await click("Observar reacción")
		var m:Dictionary=p.expert_snapshot().measurement
		check(absf(m.value-(35.711309772 if trial==0 else 41.630586824))<.0001,"Medición observada: %.6f mmol, %s" % [m.value,m.limiting_reagent])
		var explained:=ask("¿Qué significa el resultado?")
		check(explained.text.contains("realmente vertidos") and explained.text.contains("ilustración") and explained.text.contains(m.limiting_reagent),"Explica cantidad inicial/usada, teoría, burbujas y limitante")
		check(ask("¿Qué reactivo se agota primero?").text.contains(m.limiting_reagent),"Pregunta por limitante no se confunde con lista de materiales")
		assistant.expert.testing=true
		assistant.expert.case_index=trial
		var observed:=ask("¿Qué significa el resultado?")
		check(observed.text.contains("Esperado:") and observed.text.contains("Observado:"),"Modo pruebas separa esperado del modelo y observado actual")
		assistant.expert.testing=false
		check(ask("¿Cómo guardo el resultado?").rule=="journal","Guardar resultado se reconoce como petición de registro")
		check(ask("guardar").text.contains("pendiente"),"Antes de guardar informa pendiente")
		await click("Ver cuaderno")
		assistant._process(.2)
		await click_control(lab.experiment_panel.assistant_button)
		check(assistant.visible and ask("guardar").text.contains(lab.experiment_panel._save_button.text),"Asistente accesible desde el cuaderno y usa su control de registro")
		var mode_before:bool=assistant.expert.testing
		gesture_ui(assistant.test_button)
		check(assistant.expert.testing!=mode_before and lab.experiment_panel.visible,"Pinza de HUD simulada alcanza al asistente sobre el cuaderno")
		assistant.expert.testing=false
		await click_control(assistant.close_button)
		if trial==0:
			lab.experiment_panel._journal=FailedJournal.new()
			await click("Anotar ensayo")
			var failed:=ask("guardar")
			check(failed.text.contains(lab.experiment_panel._status.text) and p.session.step==Session.Step.REGISTER,"Fallo real de guardado sin confirmación falsa")
			lab.experiment_panel._journal=journal
		await click("Anotar ensayo")
		check(ask("¿Se guardó?").text.contains("confirmó") and p.session.step==Session.Step.COMPLETED,"Solo confirma tras respuesta exitosa del cuaderno")
		if trial==0:
			assistant.expert.testing=true
			assistant.expert.case_index=4
			check(ask("resultado").text.contains("guardado confirmado"),"Caso de recuperación distingue medición y guardado observados")
			check(ask("modo normal").rule=="test_exit","Puede salir del modo pruebas sin modificar la práctica")
		assistant.open_panel()
		await capture("asistente-guardado-"+str(trial))
		assistant.close_panel()
		await click("Ver cuaderno")
		check(lab.experiment_panel._history.text.contains("50.0 mL"),"Registro consultable con volumen realmente recibido")
		lab.experiment_panel.hide()
	check(journal.recent().size()==2,"Dos ensayos registrados, sin duplicados causados por conversación")
	lab._open_chemistry()
	var old_session:String=p.session.session_id
	await click("Repetir ensayo")
	check(p.session.session_id!=old_session and p.expert_snapshot().measurement.is_empty() and p.expert_snapshot().journal.saved.is_empty(),"Reiniciar invalida resultado y confirmación del ensayo anterior")
	check(ask("resultado").rule=="missing_measurement" and not ask("guardar").text.contains("confirmó"),"Tras reiniciar no presenta resultado ni guardado anterior como actual")
	assistant.open_panel()
	check(not assistant.history.text.contains("35.711") and not assistant.history.text.contains("41.631"),"Historial conversacional se reinicia con el identificador de ensayo")
	assistant.close_panel()
	p.liquid.select(0)
	assistant._process(.2)
	check(not lab.chemistry_assistant_button.visible and not assistant.visible,"Transferencia de alcohol no activa el asistente de Laboratorio 1")
	lab._select_challenge(3)
	assistant._process(.2)
	check(not lab.chemistry_assistant_button.visible,"Otra práctica permanece fuera de alcance")
	var report:=FileAccess.open(lab.base_dir.path_join("registros/asistente-aceptacion.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"failures":failures,"answers":answers,"records":journal.recent(),"zero_rejected_by_model":Model.estimate(0,3).is_empty(),"negative_rejected_by_model":Model.estimate(50,-1).is_empty(),"input_limits":Model.INPUTS,"source":"Godot local, controles y manos simulados"},"  "))
	lab.free()
	quit(failures)

func gesture_ui(control:Button)->void:
	var xy:=control.get_global_rect().get_center()/root.get_visible_rect().size*.8+Vector2(.1,.1)
	for closed in [false,true,false]:
		lab.garage_pointer.actors[0].update_hand({"present":true,"cursor":[xy.x,xy.y],"pinched":closed,"open_confirmed":not closed,"flexed":false,"hand_open":true,"landmarks":[],"filter":"one_euro_v1"},true,dt)
