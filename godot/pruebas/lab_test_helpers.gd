extends SceneTree
const Session = preload("res://core/lab1_session.gd")
var lab: Node
var failures := 0
var dt := 1.0/60.0
var directory := "user://lab1-aceptacion/"+str(Time.get_unix_time_from_system())
func _initialize() -> void:
	call_deferred("run")
func check(ok:bool,text:String)->void:
	print(("OK: " if ok else "FALLO: ")+text)
	if not ok: failures+=1
func button(text:String)->Button:
	for node in lab.find_children("*","Button",true,false):
		if node.text.contains(text) and node.is_visible_in_tree():return node
	return null
func signal_hand(id:int,screen:Vector2,closed:bool,angle:float=0)->void:
	var normalized:=screen/root.get_visible_rect().size*.8+Vector2(.1,.1)
	lab.garage_pointer.actors[id].update_hand({"id":id,"present":true,"cursor":[normalized.x,normalized.y],"pinched":closed,"roll":deg_to_rad(angle),"landmarks":preload("res://pruebas/hand_fixture.gd").points(normalized,closed,deg_to_rad(angle),id),"filter":"one_euro_v1","identity_label":"Left" if id==0 else "Right"},true,dt)
func tick()->void:
	lab.challenges.update_transfer(dt)
	lab.chemistry_panel._refresh()
func click(caption:String)->void:
	await process_frame
	var control:=button(caption)
	check(control!=null,"Control accesible: "+caption)
	if control==null:return
	var screen:=control.get_global_rect().get_center()
	signal_hand(0,screen,false)
	signal_hand(0,screen,true)
	signal_hand(0,screen,false)
	await process_frame
func grip(id:int,object:Node3D)->Vector2:
	await physics_frame
	await process_frame
	var screen:Vector2=lab.explore_camera.unproject_position(object.to_global(Vector3(0,.3 if object==lab.challenges.bottle else .5,0)))
	var initial:Vector3=object.global_position
	signal_hand(id,screen,false)
	signal_hand(id,screen,true)
	check(lab.garage_pointer.actors[id].held_object==object,"ID %d agarra %s" % [id,object.name])
	check(Vector2(object.global_position.x,object.global_position.z).distance_to(Vector2(initial.x,initial.z))<.00001,"Agarre conserva X/Z sin salto")
	signal_hand(id,screen,true)
	check(Vector2(object.global_position.x,object.global_position.z).distance_to(Vector2(initial.x,initial.z))<.00001,"Cursor quieto no mueve el objeto tras elevarlo")
	return screen
func target_screen(id:int,position:Vector3)->Vector2:
	var point:Vector3=position-lab.garage_pointer.actors[id].offset
	point.y=0
	return lab.explore_camera.unproject_position(point)
func drive(id:int,screen:Vector2,angle:float,frames:int)->void:
	for i in frames:
		var object:Node3D=lab.garage_pointer.actors[id].held_object
		var before:Vector3=object.global_position if object!=null else Vector3.ZERO
		signal_hand(id,screen,true,angle)
		if object!=null:
			var change:Vector3=object.global_position-before
			if change.length()>2.2*dt+.00001 or change.z < -.85*dt-.00001:
				failures+=1
				print("FALLO: límite de movimiento por segundo")
		tick()
func release(id:int,screen:Vector2)->void:
	signal_hand(id,screen,false)
	tick()
func run()->void:
	pass

func test_pipeline_and_render()->void:
	var fixture:=ProjectSettings.globalize_path("res://../registros/manos_pipeline_fixture.json")
	var frames: Variant = JSON.parse_string(FileAccess.get_file_as_string(fixture))
	check(frames is Array,"Fixture generada por el pipeline Python real")
	if frames is not Array: return
	lab.garage_pointer.cancel()
	lab.hand_guards.clear()
	lab.last_frame_stamp=-1
	var timestamp:=Time.get_unix_time_from_system()
	var simultaneous:=0
	for source in frames:
		source["captured_unix"]=timestamp+float(source.seq)*.001
		lab._receive(source)
		lab.garage_pointer.update_hand(lab.packet,true,1.0/30)
		if lab.packet.hand_count==2: simultaneous+=1
	check(simultaneous>80,"Transporte JSON → guardas → dos cursores aceptados en el mismo cuadro")
	check(lab.preview.hands.size()==2 and lab.navigation_preview.hands.size()==2,"Las dos miniaturas preservan ambas manos")
	for id in 2:
		var visual: Node3D = lab.garage_pointer.overlay.hands[id]
		check(visual.visible and visual.joints.size()==21 and visual.bones.size()==21,"Mano %d: palma y cinco dedos articulados" % id)
		check(visual.screen_anchor.distance_to(lab.garage_pointer.actors[id].cursor)<.001,"La zona visible de palma coincide con el punto de interacción")
	await capture("manos-3d")
func mouse_event(screen:Vector2,pressed:bool)->void:
	var movement:=InputEventMouseMotion.new()
	movement.position=screen
	movement.global_position=screen
	root.push_input(movement,true)
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=screen
	event.global_position=screen
	event.pressed=pressed
	root.push_input(event,true)
	await process_frame
func mouse_trial()->void:
	lab.chemistry_panel.repeat()
	lab.chemistry_panel.dose.value=25
	lab.chemistry_panel.prepare()
	lab.chemistry_panel.add_bicarbonate()
	await physics_frame
	await process_frame
	var bottle:Node3D=lab.challenges.bottle
	var screen:Vector2=lab.explore_camera.unproject_position(bottle.to_global(Vector3(0,.3,0)))
	await mouse_event(screen,true)
	check(lab.garage_pointer.mouse.held_object==bottle,"Ratón agarra el frasco")
	var desired:Vector3=lab.challenges.beaker.global_position+Vector3(sin(PI/3)*.6,0,0)
	desired.y=0
	var target:Vector3=desired-lab.garage_pointer.mouse.offset
	target.y=0
	var destination:Vector2=lab.explore_camera.unproject_position(target)
	var motion:=InputEventMouseMotion.new()
	motion.position=destination
	motion.global_position=destination
	root.push_input(motion,true)
	for i in 180:
		lab.garage_pointer.mouse._process(dt)
		tick()
	for i in 6:
		var wheel:=InputEventMouseButton.new()
		wheel.button_index=MOUSE_BUTTON_WHEEL_UP
		wheel.pressed=true
		root.push_input(wheel,true)
	for i in 240:
		lab.garage_pointer.mouse._process(dt)
		tick()
	check(is_equal_approx(lab.challenges.transfer.poured_ml,25),"Ratón: proyección, movimiento limitado y rueda completan el vertido")
	await mouse_event(destination,false)

func test_acceptance_audit()->void:
	lab.last_frame_stamp=-1
	lab.hand_guards.clear()
	var timestamp:float=Time.get_unix_time_from_system()
	for seq in 3:
		lab._receive({"type":"frame","seq":seq,"captured_unix":timestamp+seq*.001,"hands":[{"id":0,"raw_present":true,"present":true,"hand_epoch":0,"identity_label":"Left","handedness":"Left","raw_cursor":[.3,.5],"cursor":[.3,.5],"landmarks":[]},{"id":1,"raw_present":true,"present":true,"hand_epoch":0,"identity_label":"Right","handedness":"Right","raw_cursor":[.7,.5],"cursor":[.7,.5],"landmarks":[]}]})
	check(lab.tracking_audit.stats[0].accepted_frames==lab.tracking_audit.stats[1].accepted_frames,"Ambas manos tienen la misma regla de aceptación")
	lab._receive({"type":"frame","seq":4,"captured_unix":timestamp+.004,"hands":[{"id":0,"raw_present":false,"present":false,"hand_epoch":1},{"id":1,"raw_present":true,"present":true,"hand_epoch":0,"identity_label":"Right","handedness":"Right","raw_cursor":[.99,.01],"cursor":[.99,.01],"landmarks":[]}]})
	check(lab.tracking_audit.stats[0].raw_losses==1 and lab.tracking_audit.stats[0].accepted_losses==1,"Auditoría distingue pérdida cruda y pérdida en el juego")
	check(lab.tracking_audit.stats[1].raw_jumps==1 and lab.tracking_audit.stats[1].rejections>0,"Auditoría registra salto y rechazo por mano")

func capture(caption:String)->void:
	if not OS.get_cmdline_user_args().has("--capture"):return
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("lab1-"+caption+".png"))
