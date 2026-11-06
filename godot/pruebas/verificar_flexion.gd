extends "res://pruebas/lab_test_helpers.gd"
## Señales derivadas del clasificador Python + escena real. Sin pinza para objetos.
var fixture: Array=[]
var positions: Array[Vector2]=[Vector2(210,250),Vector2(620,250)]
var bent: Array[bool]=[false,false]
var visible_hand: Array[bool]=[true,true]
var angles: Array[float]=[0,0]

func signal_hand(id:int,screen:Vector2,closed:bool,angle:float=0)->void:
	var source: Dictionary=fixture[10 if closed else 4][id].duplicate(true)
	var normalized:=screen/root.get_visible_rect().size*.8+Vector2(.1,.1)
	var shift:=normalized-Vector2(source.cursor[0],source.cursor[1])
	for p in source.landmarks:
		p[0]+=shift.x
		p[1]+=shift.y
	source["cursor"]=[normalized.x,normalized.y]
	source.erase("sample_time")
	source["pinched"]=false # El pulgar queda libre: no hay flanco de pinza.
	source["middle_pinched"]=false
	source["roll"]=deg_to_rad(angle+(25 if id==0 else -40))
	lab.garage_pointer.actors[id].update_hand(source,true,dt)

func frames(count:int)->void:
	for i in count:
		for id in 2:
			if visible_hand[id]:signal_hand(id,positions[id],bent[id],angles[id])
			else:lab.garage_pointer.actors[id].update_hand({},false,dt)
		tick()

func click(caption:String)->void:
	await process_frame
	var control:=button(caption)
	check(control!=null,"Control de laboratorio accesible: "+caption)
	if control!=null:lab.garage_pointer.actors[0]._click(control.get_global_rect().get_center())
	await process_frame

func take(id:int,object:Node3D,already_bent:bool=false)->void:
	await physics_frame
	var screen:Vector2=lab.explore_camera.unproject_position(object.to_global(Vector3(0,.3,0)))
	if already_bent:
		positions[id]=Vector2(60,300)
		bent[id]=true
		frames(1)
		check(lab.garage_pointer.actors[id].held_object==null,"Flexionado fuera del área todavía no agarra")
	else:
		positions[id]=screen
		bent[id]=false
		frames(1)
	var before:Vector3=object.global_position
	positions[id]=screen
	bent[id]=true
	frames(1)
	check(lab.garage_pointer.actors[id].held_object==object,"ID %d agarra %s %s sin pinza" % [id,object.name,"entrando flexionado" if already_bent else "flexionando encima"])
	check(Vector2(before.x,before.z).distance_to(Vector2(object.global_position.x,object.global_position.z))<.00001,"Conserva desplazamiento al agarrar sin salto")
	check(is_equal_approx(before.y,object.global_position.y),"El agarre tampoco teletransporta la altura")

func move_to(id:int,destination:Vector3,count:int,angle:float=0)->void:
	positions[id]=target_screen(id,destination)
	angles[id]=angle
	frames(count)

func run()->void:
	fixture=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../registros/flexion_fixture.json")))
	check(fixture.size()==30,"Landmarks y estados generados por HandPipeline de Python")
	test_tail_model()
	lab=load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.synthetic=true
	lab.challenges.set_process(false)
	lab.garage_pointer.mouse.set_process(false)
	lab.experiment_panel._journal=preload("res://bitacora/run_journal.gd").new(directory)
	if OS.get_cmdline_user_args().has("--verify-read"):
		var saved_path:=FileAccess.get_file_as_string("user://flexion-ultima-ruta.txt")
		lab.experiment_panel._journal=preload("res://bitacora/run_journal.gd").new(saved_path)
		var saved:Array=lab.experiment_panel._journal.recent()
		check(saved.size()==2 and saved.all(func(r):return r.lab_completed),"Otro proceso recupera los dos ensayos completados")
		lab._open_experiment()
		var pages:=""
		for page in 2:
			pages+=lab.experiment_panel._history.text
			lab.experiment_panel.turn_page(1)
		check(pages.contains("25.0 mL") and pages.contains("50.0 mL"),"Cuaderno conserva el volumen real de ambos ensayos")
		lab.free()
		quit(failures)
		return
	var marker:=FileAccess.open("user://flexion-ultima-ruta.txt",FileAccess.WRITE)
	marker.store_string(directory)
	marker.close()
	await click("Química [C]")
	await selection_and_loss()
	await opening_during_tail()
	for trial in 2:
		lab.garage_pointer.cancel()
		bent=[false,false]
		visible_hand=[true,true]
		angles=[0,0]
		positions=[Vector2(210,250),Vector2(620,250)]
		if trial==1:await click("Repetir ensayo")
		lab.chemistry_panel.dose.value=25 if trial==0 else 50
		lab.chemistry_panel.bicarbonate.value=3
		await click("Preparar vaso")
		await click("Añadir bicarbonato")
		var vessel:Node3D=lab.challenges.beaker
		var bottle:Node3D=lab.challenges.bottle
		var vessel_id:=trial
		var bottle_id:=1-trial
		await take(vessel_id,vessel,trial==1)
		await take(bottle_id,bottle,trial==0)
		await capture("flexion-agarres-"+str(trial))
		var destination:=Vector3(vessel.global_position.x,1,vessel.global_position.z)
		move_to(bottle_id,destination,150)
		check(lab.challenges.transfer.poured_ml==0 and lab.challenges.receiving,"Acercar prepara el borde sin verter")
		angles[bottle_id]=20 if trial==0 else -20
		frames(20)
		var partial:float=lab.challenges.transfer.poured_ml
		check(partial>0 and partial<25,"Vierte parcialmente con vaso y frasco en manos distintas")
		if trial==0:
			var frozen:Vector3=bottle.global_position
			visible_hand[bottle_id]=false
			frames(8)
			var tail:float=lab.challenges.transfer.poured_ml-partial
			check(tail>0 and tail<=3.125 and bottle.global_position==frozen,"Pérdida breve: cola acotada, frasco congelado")
			check(lab.garage_pointer.actors[bottle_id].visual.visible and lab.garage_pointer.actors[bottle_id].held_object==bottle,"Pose y dueño permanecen durante la pérdida")
			await capture("flexion-pausa")
			visible_hand[bottle_id]=true
			positions[bottle_id]+=Vector2(15,10)
			frames(1)
			check(bottle.global_position==frozen,"Recuperación flexionada reancla el agarre existente sin salto")
			partial=lab.challenges.transfer.poured_ml
			frames(4)
			check(lab.challenges.transfer.poured_ml>partial,"Muestra nueva recuperada retoma el vertido sin re-agarrar")
		angles[bottle_id]=0
		frames(15)
		partial=lab.challenges.transfer.poured_ml
		frames(10)
		check(is_equal_approx(partial,lab.challenges.transfer.poured_ml),"Enderezar con señal válida para el volumen")
		angles[bottle_id]=20 if trial==0 else -20
		frames(360)
		var target:=25.0 if trial==0 else 50.0
		check(is_equal_approx(lab.challenges.transfer.poured_ml,target) and is_equal_approx(lab.challenges.transfer.remaining_ml,100-target),"Dosis %s mL: volumen conservado incluida la cola" % target)
		bent=[false,false]
		frames(1)
		check(lab.garage_pointer.held_object==null,"Abrir suelta solo los objetos de las manos abiertas")
		await click("Observar reacción")
		await click("Ver cuaderno")
		for key in ["question","hypothesis","notes","conclusion"]:lab.experiment_panel._fields[key].text="Flexión, dosis %s mL" % target
		await click("Anotar ensayo")
		check(lab.chemistry_panel.session.step==Session.Step.COMPLETED,"Laboratorio completado después de guardar")
	var records:Array=lab.experiment_panel._journal.recent()
	check(records.size()==2,"Dos ensayos guardados con roles invertidos")
	for record in records:
		var amount:float=record.parameters.vertido_ml
		check(absf(record.value-(20.815293412 if amount==25 else 35.711309772))<.0001,"CO₂ usa el volumen realmente recibido")
	await mouse_trial()
	test_acceptance_audit()
	await test_pipeline_and_render()
	await capture("flexion-final")
	lab.free()
	quit(failures)

func selection_and_loss()->void:
	lab.garage_pointer.cancel()
	var vessel:Node3D=lab.challenges.beaker
	var bottle:Node3D=lab.challenges.bottle
	await take(0,vessel,true)
	await take(1,bottle,true)
	var start_left:=positions[0]
	var start_right:=positions[1]
	for i in 20:
		var progress:=float(i)/19
		positions[0]=start_left.lerp(start_right,progress)
		positions[1]=start_right.lerp(start_left,progress)
		frames(1)
	check(lab.garage_pointer.actors[0].held_object==vessel and lab.garage_pointer.actors[1].held_object==bottle,"Cruzar cursores flexionados conserva ambos dueños fuera del área de selección")
	positions=[start_left,start_right]
	frames(150)
	var owner:Node=lab.garage_pointer.actors[0]
	visible_hand[0]=false
	frames(2)
	var before:Vector3=vessel.global_position
	positions[1]+=Vector2(20,0)
	frames(5)
	check(owner.held_object==vessel and vessel.global_position==before,"Dos cuadros perdidos no parpadean ni intercambian el dueño; la otra mano funciona")
	visible_hand[0]=true
	bent[0]=false
	frames(1)
	check(owner.held_object==null,"Apertura válida al volver gana a la tolerancia de agarre")
	bent[0]=true
	frames(1)
	check(owner.held_object==vessel,"Puede volver a flexionar para agarrar")
	visible_hand[0]=false
	frames(31)
	check(owner.held_object==vessel and owner.visual.visible,"Hasta 516 ms conserva pose y propiedad")
	frames(4)
	check(owner.held_object==null and not owner.visual.visible,"Más de 550 ms libera y oculta la mano")
	visible_hand[0]=true
	frames(2)
	check(owner.held_object==null and owner.needs_open,"Volver flexionado tras vencer no captura involuntariamente")
	bent[0]=false
	frames(1)
	bent[0]=true
	frames(1)
	check(owner.held_object==vessel,"Abrir realmente vuelve a habilitar el agarre automático")
	bent[0]=false
	frames(1)
	positions[0]=positions[1]
	bent[0]=true
	frames(1)
	check(owner.held_object==null and lab.garage_pointer.actors[1].held_object==bottle,"Un objeto ocupado queda excluido al llegar flexionado")
	lab.garage_pointer.cancel()
	bent=[false,false]
	visible_hand=[true,true]
	positions=[Vector2(210,250),Vector2(620,250)]
	# Dos objetos cercanos: el rayo directo prevalece frente al margen del vecino.
	var close:Vector3=vessel.global_position+Vector3(.55,0,0)
	bottle.global_position=close
	await physics_frame
	var actor=lab.garage_pointer.actors[0]
	var aim:Vector2=lab.explore_camera.unproject_position(bottle.to_global(Vector3(0,.3,0)))
	check(actor._object_at(aim)==bottle,"Con objetos cercanos prioriza el cuerpo directamente bajo la palma")
	var source:Dictionary=fixture[4][0].duplicate(true)
	var xy:=aim/root.get_visible_rect().size*.8+Vector2(.1,.1)
	source["cursor"]=[xy.x,xy.y]
	source["sample_id"]=111.0
	source["sample_time"]=111.0
	actor.update_hand(source,true,dt)
	source["flexed"]=true
	source["hand_open"]=false
	actor.update_hand(source,true,dt)
	check(actor.held_object==null,"Cambiar una muestra retenida no inicia agarre sin muestra nueva")
	source["sample_id"]=111.5
	actor.update_hand(source,true,dt)
	check(actor.held_object==null,"Otro sello de transporte no convierte la misma muestra de cámara en nueva")
	source["sample_id"]=112.0
	source["sample_time"]=112.0
	actor.update_hand(source,true,dt)
	check(actor.held_object==bottle,"La muestra nueva flexionada sí captura el candidato libre")
	lab.garage_pointer.cancel()
	lab.challenges.configure_transfer(100,150,"vinagre",5)

func opening_during_tail()->void:
	lab.garage_pointer.cancel()
	lab.challenges.configure_transfer(100,150,"vinagre",5)
	bent=[false,false]
	visible_hand=[true,true]
	angles=[0,0]
	positions=[Vector2(60,300),Vector2(650,250)]
	var vessel:Node3D=lab.challenges.beaker
	var bottle:Node3D=lab.challenges.bottle
	await take(0,vessel)
	await take(1,bottle)
	move_to(1,Vector3(vessel.global_position.x,1,vessel.global_position.z),150)
	angles[1]=20
	frames(10)
	visible_hand[1]=false
	frames(3)
	var amount:float=lab.challenges.transfer.poured_ml
	visible_hand[1]=true
	bent[1]=false
	frames(1)
	check(lab.garage_pointer.actors[1].held_object==null and is_equal_approx(amount,lab.challenges.transfer.poured_ml),"Apertura confirmada corta la cola y libera antes de vencer 550 ms")
	frames(10)
	check(not lab.challenges.stream.visible and is_equal_approx(amount,lab.challenges.transfer.poured_ml),"El tramo visual termina suavemente sin sumar volumen")
	bent[1]=true
	frames(1)
	move_to(1,Vector3(vessel.global_position.x,1,vessel.global_position.z),30,20)
	visible_hand[1]=false
	amount=lab.challenges.transfer.poured_ml
	frames(35)
	check(lab.garage_pointer.actors[1].held_object==null and lab.challenges.transfer.poured_ml-amount<=3.12501 and not lab.challenges.stream.visible,"Pérdida larga durante vertido termina cola, visual y agarre")
	lab.garage_pointer.cancel()
	visible_hand=[true,true]
	bent=[false,false]
	angles=[0,0]

func test_tail_model()->void:
	var totals:Array[float]=[]
	for fps in [10,30,60,120]:
		var model:=preload("res://core/transfer_state.gd").new()
		model.configure(100,150,"vinagre",5)
		var step:=1.0/float(fps)
		model.advance(step,true,true,20,true)
		var initial:float=model.poured_ml
		for i in fps:model.advance(step,true,true,20,true,false,(i+1)*step,false)
		totals.append(model.poured_ml-initial)
		check(model.poured_ml-initial<=3.12501 and not model.pouring,"Cola ≤250 ms / 3,125 mL a %d FPS" % fps)
		check(is_equal_approx(model.remaining_ml+model.poured_ml,100),"Contabiliza cada transferencia una vez")
		model.configure(100,150,"vinagre",5)
		check(model.advance(step,true,true,20,true,false,.05,false)==0,"Pose retenida no inicia un chorro")
		check(model.advance(step,true,true,20,true,true,0,false)==0,"Render duplicado no inicia vertido")
		model.advance(step,true,true,20,true)
		check(model.advance(step,true,false,20,true,false,.05,false)==0,"Vaso fuera de debajo corta incluso durante la cola")
	check(totals.all(func(amount):return absf(amount-3.125)<.0001),"Cola consistente a distintas tasas de cuadros")
	var small:=preload("res://core/transfer_state.gd").new()
	small.configure(1,1,"vinagre",5)
	small.advance(.1,true,true,20,true)
	check(small.remaining_ml==0 and small.advance(.1,true,true,20,true,false,.1,false)==0,"Frasco vacío o vaso lleno interrumpen la cola sin desbordar")
	small.configure(100,150,"vinagre",5)
	small.advance(.1,true,true,20,true)
	check(small.advance(.02,true,true,0,true,false,.05,true)==0,"Enderezar con muestra válida corta aunque la otra mano esté perdida")
