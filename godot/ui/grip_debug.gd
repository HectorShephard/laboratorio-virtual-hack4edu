extends Control
## F3: interfaz y traza numérica. Nunca captura imagen o video.
var manager: Node
var labels: Array[Label]=[]
var trace: FileAccess
var traced: Dictionary={}
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for id in 2:
		var label:=Label.new()
		label.position=Vector2(24,440+id*74)
		label.add_theme_font_size_override("font_size",13)
		label.add_theme_color_override("font_color",Color("efbc70") if id==0 else Color("78cce4"))
		label.add_theme_color_override("font_outline_color",Color.BLACK)
		label.add_theme_constant_override("outline_size",5)
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(label)
		labels.append(label)
	hide()
func toggle() -> void:
	visible=not visible
	if visible:
		var path: String=manager.lab.base_dir.path_join("registros/agarre-control-%s.jsonl" % Time.get_ticks_msec())
		trace=FileAccess.open(path,FileAccess.WRITE)
		print("DEPURACIÓN F3: ",path)
	else:
		if trace!=null:trace.close()
		trace=null
func _process(_delta: float) -> void:
	if not visible:return
	for id in 2:
		var actor=manager.actors[id]
		var data: Dictionary=actor.debug.duplicate()
		data["viewport"]=[actor.cursor.x,actor.cursor.y]
		data["held"]=actor._caption(actor.held_object)
		data["age_ms"]=actor.camera_age_ms+maxf(0,actor.clock-actor.last_unique_clock)*1000
		labels[id].text="F3 · ID %d  MP:%s aceptada:%s útil:%s edad:%d ms (%s)\nFlexión:%s abierta:%s votos:%s/%s pide abrir:%s XY:(%.1f,%.1f)\nBajo:%s agarrado:%s" % [id,data.get("detected",false),data.get("accepted",false),data.get("usable",false),int(data.age_ms),data.get("representation","-"),data.get("flexed",false),data.get("hand_open",false),data.get("flexion",{}).get("bent_votes",0),data.get("flexion",{}).get("open_votes",0),actor.needs_open,actor.cursor.x,actor.cursor.y,data.get("under","-"),data.held]
		var key: String=str(actor.last_sample_id)+str(actor.suspended)+data.held
		if trace!=null and traced.get(id,"")!=key:
			traced[id]=key
			data["seconds"]=actor.clock
			data["id"]=id
			trace.store_line(JSON.stringify(data))
			trace.flush()
	queue_redraw()
func _draw() -> void:
	for actor in manager.actors:
		if not actor.initialized or actor.missing_for>actor.POSE_GRACE:continue
		var color:=Color("efbc70") if actor.hand_id==0 else Color("78cce4")
		draw_circle(actor.cursor,3,color)
		draw_line(actor.cursor-Vector2(9,0),actor.cursor+Vector2(9,0),color,1)
		draw_line(actor.cursor-Vector2(0,9),actor.cursor+Vector2(0,9),color,1)
