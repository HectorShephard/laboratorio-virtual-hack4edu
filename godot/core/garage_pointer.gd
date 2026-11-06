extends Node
## Un solo propietario por pinza: interfaz u objeto, hasta soltar o perder la mano.
const Hand = preload("res://core/view_gesture.gd")
var lab: Node3D
var armed := false
var pressed := false
var initialized := false
var cursor := Vector2.ZERO
var held_object: Node3D
var offset := Vector3.ZERO
var mouse_drag := false
var injecting := false
var marker: Label
var highlight: Node3D
var modal_before: Control
var coordinator: Node
var hand_id := 0
var receive_mouse := false
var epoch := -1
var middle_down := false
var pinch_start := -1.0
var pending_control: Control
var roll_origin := 0.0
var current_roll := 0.0
var swipe_origin := Vector2.ZERO
var swipe_start := 0.0
var swipe_points: Array[Vector3] = []
var clock := 0.0
const BENCH_Y := 0.0
const MAX_SPEED := 2.2
const BACK_SPEED := 0.85
const FRONT_SPEED := 1.6
const HAND_LIFT_SPEED := 1.5
const HAND_PICK_MARGIN := 28.0
const CANDIDATE_GRACE := .20
const CANDIDATE_MARGIN := 44.0
var grip_height := 0.08
var mouse_position := Vector2.ZERO
var hand_label := ""
const LOSS_GRACE := .55
const POSE_GRACE := .55
var needs_open := false
var previous_flexed := false
var last_valid_clock := -100.0
var last_sample_id := -1.0
var last_unique_clock := -100.0
var last_sample_time := -1.0
var render_from := Vector2.ZERO
var render_target := Vector2.ZERO
var render_elapsed := 0.0
var render_duration := .033
var candidate: Node3D
var candidate_clock := -100.0
var debug: Dictionary = {}
var last_failure := ""
var camera_age_ms := 0.0
var missing_for := 0.0
var suspended := false
var visual: Node3D
var last_pose: Dictionary = {}

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	marker = Label.new()
	marker.text = "Mano " + str(hand_id + 1)
	marker.add_theme_font_size_override("font_size", 13)
	marker.add_theme_color_override("font_color", Color("e5ae58") if hand_id == 0 else Color("78cce4"))
	marker.add_theme_color_override("font_outline_color", Color.BLACK)
	marker.add_theme_constant_override("outline_size", 5)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(marker)
	marker.hide()
	if not receive_mouse:
		visual = coordinator.overlay.hands[hand_id]

func cancel() -> void:
	_release()
	mouse_drag = false
	armed = false
	pressed = false
	initialized = false
	last_sample_id = -1
	last_sample_time = -1
	candidate = null
	pending_control = null
	pinch_start = -1
	swipe_points.clear()
	missing_for = 0
	suspended = false
	_set_highlight(null)
	if marker != null:
		marker.hide()
	if visual != null: visual.hide()

func _process_grip_visual() -> void:
	if visual==null: return
	var holding:=is_instance_valid(held_object)
	var screen:=Vector2.ZERO
	if holding:
		var local_height:=.3 if held_object.get_meta("kind","")=="bottle" else .5
		screen=lab.explore_camera.unproject_position(held_object.to_global(Vector3(0,local_height,0)))
	visual.grip_target(screen,holding)

func _tracking_lost(delta: float) -> void:
	missing_for = maxf(0,clock-last_valid_clock)
	suspended = true
	armed = false
	pending_control = null
	swipe_points.clear()
	if is_instance_valid(held_object):
		held_object.set_meta("control_paused",true)
		held_object.set_meta("control_age",missing_for)
		held_object.set_meta("control_unique",false)
		if missing_for > LOSS_GRACE:
			_release()
			_set_highlight(null)
	if initialized and missing_for>LOSS_GRACE:
		needs_open=true
		candidate=null
		_set_highlight(null)
	elif is_instance_valid(candidate) and coordinator.owners.get(candidate.get_instance_id(),hand_id)!=hand_id:
		candidate=null
		_set_highlight(null)
	if missing_for <= POSE_GRACE and initialized:
		marker.text = "Pausa de muestra"
		if visual != null: visual.pose(last_pose,cursor,get_viewport().get_visible_rect().size,is_instance_valid(held_object),true)
	else:
		marker.hide()
		if visual != null: visual.hide()
	debug["usable"]=false
	debug["transition"]="-"
	debug["age_ms"]=maxf(0,clock-last_unique_clock)*1000
	debug["held"]=_caption(held_object)

func modal() -> Control:
	if lab.experiment_panel.visible:
		return lab.experiment_panel
	if lab.garage_menu.visible:
		return lab.garage_menu
	return null

func _caption(object: Node) -> String:
	return str(object.name) if is_instance_valid(object) else "-"

func _render_cursor(delta: float) -> void:
	render_elapsed += delta
	cursor = render_from.lerp(render_target,clampf(render_elapsed/maxf(.001,render_duration),0,1))
	marker.position = cursor+Vector2(15,14)
	marker.text=("Ámbar" if hand_id==0 else "Azul")+(" · agarre" if held_object!=null else " · palma")
	marker.show()
	if visual!=null: visual.pose(last_pose,cursor,get_viewport().get_visible_rect().size,held_object!=null)

func update_hand(packet: Dictionary, fresh: bool, delta: float) -> void:
	clock+=delta
	if is_instance_valid(held_object):
		held_object.set_meta("control_unique",false)
		held_object.set_meta("control_age",maxf(0,clock-last_valid_clock))
	if modal()!=modal_before:
		cancel()
		modal_before=modal()
	if mouse_drag: return
	var sample_id:=float(packet.get("sample_id",packet.get("sample_time",clock)))
	var unique:=sample_id>last_sample_id and (not packet.has("sample_time") or float(packet.sample_time)>last_sample_time)
	var valid:=fresh and bool(packet.get("present",false)) and bool(packet.get("gesture_valid",true)) and float(packet.get("camera_age_ms",0))<=200 and (unique or clock-last_unique_clock<.1)
	if not valid:
		debug["detected"]=packet.get("raw_present",false)
		debug["accepted"]=packet.get("present",false)
		_tracking_lost(delta)
		return
	if not unique:
		_render_cursor(delta)
		if is_instance_valid(held_object) and not suspended: _drag(cursor,delta)
		return # Una muestra retenida nunca genera flancos, clicks ni agarres.
	var new_epoch:=int(packet.get("hand_epoch",epoch))
	if initialized and not suspended and ((epoch>=0 and new_epoch!=epoch) or clock-last_unique_clock>LOSS_GRACE):
		_tracking_lost(maxf(0,clock-last_unique_clock) if clock-last_unique_clock>LOSS_GRACE else 0)
	epoch=new_epoch
	last_sample_id=sample_id
	last_unique_clock=clock
	camera_age_ms=float(packet.get("camera_age_ms",0))
	last_valid_clock=clock-camera_age_ms/1000.0
	var sample_time:=float(packet.get("sample_time",clock))
	var interval:=sample_time-last_sample_time if last_sample_time>=0 else .033
	last_sample_time=sample_time
	hand_label=str(packet.get("identity_label",packet.get("handedness",hand_label)))
	var raw: Array=packet.get("cursor",[.5,.5])
	var target:=((Vector2(raw[0],raw[1])-Vector2(.1,.1))/.8).clamp(Vector2.ZERO,Vector2.ONE)*get_viewport().get_visible_rect().size
	render_from=cursor if initialized else target
	render_target=target
	render_elapsed=0
	render_duration=clampf(interval,.016,.05) if packet.has("sample_id") else .001
	initialized=true
	last_pose=packet
	_render_cursor(delta)
	var pinched:=bool(packet.get("pinched",false))
	var ui_opened:=bool(packet.get("open_confirmed",Hand.is_open(packet.get("landmarks",[])))) and not pinched
	if lab.synthetic and packet.get("landmarks",[]).is_empty(): ui_opened=not pinched
	var opened:=bool(packet.get("hand_open",false))
	var flexed:=bool(packet.get("flexed",false))
	if opened:needs_open=false
	current_roll=float(packet.get("roll",0))
	var middle:=bool(packet.get("middle_pinched",false))
	var reanchored:=false
	if suspended:
		if is_instance_valid(candidate) and not needs_open and coordinator.owners.get(candidate.get_instance_id(),hand_id)==hand_id and _screen_distance(candidate,cursor)<=CANDIDATE_MARGIN:
			candidate_clock=clock
		if is_instance_valid(held_object) and not opened:
			var point: Variant=_point(cursor)
			if point==null:return
			offset=held_object.global_position-point
			offset.y=0
			roll_origin=current_roll-held_object.rotation.z
			held_object.set_meta("control_paused",false)
			reanchored=true
		elif is_instance_valid(held_object): _release()
		suspended=false
		missing_for=0
	var transition: String=("flex" if flexed else "open") if flexed!=previous_flexed else "-"
	previous_flexed=flexed
	debug={"id":hand_id,"detected":packet.get("raw_present",true),"assigned":packet.get("detector_present",true),"accepted":true,"usable":true,"age_ms":0,"ratio":packet.get("ratio",-1),"representation":packet.get("flexion",{}).get("representation","-"),"transition":transition,"pinched":pinched,"flexed":flexed,"hand_open":opened,"flexion":packet.get("flexion",{}),"needs_open":needs_open,"armed":armed,"viewport":[cursor.x,cursor.y],"held":_caption(held_object)}
	var motion:=InputEventMouseMotion.new()
	motion.position=cursor
	motion.global_position=cursor
	injecting=true
	coordinator.injecting=true
	get_viewport().push_input(motion,true)
	injecting=false
	coordinator.injecting=false
	if held_object!=null:
		if opened:
			_release()
			armed=opened
		elif not reanchored:
			_drag(cursor,delta)
			if held_object.get_meta("kind","")=="bottle":
				held_object.rotation.z=deg_to_rad(float(packet.tilt_degrees)) if packet.has("tilt_degrees") and lab.synthetic else clampf(wrapf(current_roll-roll_origin,-PI,PI),-1.9,1.9)
		pressed=pinched
		_mark_control()
		return
	var hovered:=get_viewport().gui_get_hovered_control()
	var under: Node3D=_object_at(cursor) if hovered==null and modal()==null else null
	debug["under"]=_caption(under)
	debug["ui"]=_caption(hovered)
	if under!=null:
		candidate=under
		candidate_clock=clock
	var chosen: Node3D=under if under!=null else (candidate if _candidate_near(cursor) else null)
	_set_highlight(chosen)
	if flexed and not needs_open and chosen!=null:
		_grab_at(cursor,chosen)
		_mark_control()
		pending_control=null
		pressed=pinched
		last_failure="" if held_object!=null else "occupied"
		debug["held"]=_caption(held_object)
		return
	# La pinza indice tiene prioridad sobre la pinza medio; no cerrar el panel al agarrar.
	if middle and ui_opened and not flexed and not middle_down and armed and (modal()!=null or lab.chemistry_panel.visible or lab.chemistry_assistant.visible):
		coordinator.close_context()
		middle_down=true
		return
	middle_down=middle
	if ui_opened:
		armed=true
		if lab.experiment_panel.visible:
			swipe_points.append(Vector3(clock,cursor.x,cursor.y))
			while not swipe_points.is_empty() and swipe_points[0].x<clock-.65:swipe_points.pop_front()
			swipe_origin=Vector2(swipe_points[0].y,swipe_points[0].z)
			if clock>=swipe_start and absf(cursor.x-swipe_origin.x)>170 and absf(cursor.y-swipe_origin.y)<100:
				lab.experiment_panel.turn_page(1 if cursor.x<swipe_origin.x else -1)
				swipe_start=clock+.7
				swipe_points.clear()
	if pinched and not pressed:
		last_failure="not_armed" if not armed else "no_candidate"
		if armed:
			armed=false
			if hovered!=null and (modal()==null or modal().is_ancestor_of(hovered) or hovered==modal() or (lab.chemistry_assistant.visible and lab.chemistry_assistant.is_ancestor_of(hovered))):
				pending_control=hovered
				pinch_start=clock
		debug["failure"]=last_failure
		debug["held"]=_caption(held_object)
	elif not pinched and pressed and is_instance_valid(pending_control):
		if clock-pinch_start<=.6 and pending_control.get_global_rect().has_point(cursor):_click(cursor)
		pending_control=null
	pressed=pinched
	if pinched and clock-pinch_start>.6:pending_control=null

func _mark_control() -> void:
	if is_instance_valid(held_object):
		held_object.set_meta("control_paused",false)
		held_object.set_meta("control_age",maxf(0,clock-last_valid_clock))
		held_object.set_meta("control_unique",true)

func _candidate_near(position: Vector2) -> bool:
	return is_instance_valid(candidate) and clock-candidate_clock<=CANDIDATE_GRACE and coordinator.owners.get(candidate.get_instance_id(),hand_id)==hand_id and _screen_distance(candidate,position)<=CANDIDATE_MARGIN

func _release() -> void:
	if is_instance_valid(held_object) and coordinator != null:
		coordinator.release(held_object, hand_id)
		if held_object.get_meta("kind", "") in ["bottle","beaker"] and lab.challenges.active==2:
			lab.challenges.stop_emission()
	held_object = null
	if visual!=null and initialized:
		visual.pose(last_pose,cursor,get_viewport().get_visible_rect().size,false)

func _click(position: Vector2) -> void:
	injecting = true
	coordinator.injecting = true
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = position
		event.global_position = position
		get_viewport().push_input(event, true)
	injecting = false
	coordinator.injecting = false

func _object_at(position: Vector2) -> Node3D:
	if not lab.exploring or lab.fixed_view != 1 or lab.challenges.active != 2:
		return null
	var camera: Camera3D = lab.explore_camera
	var origin := camera.project_ray_origin(position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(position) * 30, 8)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var excluded: Array[RID] = []
	for object in lab.challenges.kit.get_children():
		if coordinator.owners.get(object.get_instance_id(),hand_id)!=hand_id:
			for area in object.find_children("*","Area3D",true,false): excluded.append(area.get_rid())
	query.exclude=excluded
	var hit := lab.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var object: Node3D = hit.collider.get_parent()
		return object if coordinator.owners.get(object.get_instance_id(),hand_id)==hand_id else null
	var closest: Node3D
	var distance:=18.0 if receive_mouse else HAND_PICK_MARGIN
	for object in lab.challenges.kit.get_children():
		if object is not Node3D or not object.has_meta("kind"):continue
		if coordinator.owners.get(object.get_instance_id(),hand_id)!=hand_id:continue
		var separation:=_screen_distance(object,position)
		if separation<distance:
			distance=separation
			closest=object
	return closest

func _screen_distance(object: Node3D, screen: Vector2) -> float:
	var bounds:=Rect2()
	var first:=true
	for shape in object.find_children("*","CollisionShape3D",true,false):
		if shape.shape is not BoxShape3D:continue
		var half: Vector3=shape.shape.size/2
		for x in [-1,1]:
			for y in [-1,1]:
				for z in [-1,1]:
					var point: Vector2=lab.explore_camera.unproject_position(shape.to_global(half*Vector3(x,y,z)))
					if first:
						bounds=Rect2(point,Vector2.ZERO)
						first=false
					else:bounds=bounds.expand(point)
	if first:return INF
	var nearest:=screen.clamp(bounds.position,bounds.end)
	return screen.distance_to(nearest)

func _point(position: Vector2, _height: float = BENCH_Y) -> Variant:
	var camera: Camera3D = lab.explore_camera
	var ray := camera.project_ray_normal(position)
	if absf(ray.y) < .015:
		return null
	# Todas las manos y objetos usan el mismo plano, independiente de la altura de agarre.
	return Plane(Vector3.UP, BENCH_Y).intersects_ray(camera.project_ray_origin(position), ray)

func _grab_at(position: Vector2, chosen: Node3D=null) -> void:
	var object := chosen if is_instance_valid(chosen) else _object_at(position)
	if object == null:
		return
	if not coordinator.claim(object, hand_id):
		return
	var point: Variant = _point(position, object.global_position.y)
	if point == null:
		coordinator.release(object, hand_id)
		return
	held_object = object
	object.set_meta("last_hand_id",hand_id)
	object.set_meta("last_hand_label",hand_label if hand_id!=2 else "mouse")
	roll_origin = current_roll
	offset = object.global_position - point
	offset.y = 0
	grip_height = 1.0 if object.get_meta("kind", "") == "bottle" else (.08 if object.get_meta("kind", "") == "beaker" else .18)
	if receive_mouse:object.global_position.y = grip_height
	if object.get_meta("kind", "") == "bottle":
		object.rotation.z = 0
	_set_highlight(object)
	if visual!=null:
		visual.pose(last_pose,cursor,get_viewport().get_visible_rect().size,true)
		marker.text=("Ámbar" if hand_id==0 else "Azul")+" · agarre"

func _drag(position: Vector2, delta: float) -> void:
	if not is_instance_valid(held_object):
		held_object = null
		return
	var point: Variant = _point(position)
	if point == null:
		return
	var destination: Vector3 = point + offset
	destination.y = grip_height
	destination.x = clampf(destination.x, -2.8, 2.8)
	destination.z = clampf(destination.z, -1.8, 1.8)
	destination = lab.challenges.assist_target(held_object, destination)
	destination.x = clampf(destination.x, -2.8, 2.8)
	destination.z = clampf(destination.z, -1.8, 1.8)
	var dt := clampf(delta, 0, .1)
	var displacement := destination - held_object.global_position
	displacement.y = 0
	displacement.z = clampf(displacement.z, -BACK_SPEED * dt, FRONT_SPEED * dt)
	displacement = displacement.limit_length(MAX_SPEED * dt)
	held_object.global_position += displacement
	held_object.global_position.y = grip_height if receive_mouse else move_toward(held_object.global_position.y,grip_height,HAND_LIFT_SPEED*dt)

func _process(delta: float) -> void:
	if receive_mouse and mouse_drag:
		_drag(mouse_position, delta)
	_process_grip_visual()

func _set_highlight(object: Node3D) -> void:
	if highlight == object:
		return
	if is_instance_valid(highlight):
		for mesh in highlight.find_children("*", "MeshInstance3D", true, false):
			mesh.material_overlay = null
	highlight = object
	if is_instance_valid(highlight):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(.90, .68, .34, .22)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for mesh in highlight.find_children("*", "MeshInstance3D", true, false):
			mesh.material_overlay = material

func _input(event: InputEvent) -> void:
	if injecting or coordinator.injecting or not receive_mouse:
		return
	if mouse_drag:
		if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			held_object.rotation.z = clampf(held_object.rotation.z + (.1745 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -.1745), -1.9, 1.9)
			get_viewport().set_input_as_handled()
		if event is InputEventMouseMotion:
			mouse_position = event.position
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			cancel()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if injecting or coordinator.injecting or not receive_mouse or modal() != null:
		return
	if event is InputEventMouseMotion:
		_set_highlight(_object_at(event.position))
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_grab_at(event.position)
		if held_object != null:
			mouse_drag = true
			mouse_position = event.position
			get_viewport().set_input_as_handled()
