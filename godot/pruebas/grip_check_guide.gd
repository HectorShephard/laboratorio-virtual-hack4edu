extends Node
## Intentos guiados REALES; sin confirmación humana no certifican intención ni lateralidad.
var lab: Node
var clock:=0.0
var started:=-1.0
var trial:=-1
var label: Label
var target: Node3D
var stats: Array=[]
var current: Dictionary={}
func _ready() -> void:
	lab._open_chemistry()
	lab.chemistry_panel.hide()
	lab.garage_pointer.debug_overlay.toggle()
	var layer:=CanvasLayer.new()
	layer.layer=55
	add_child(layer)
	label=Label.new()
	label.position=Vector2(24,175)
	label.add_theme_font_size_override("font_size",18)
	label.add_theme_color_override("font_outline_color",Color.BLACK)
	label.add_theme_constant_override("outline_size",5)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	label.text="Conectando webcam para 10 intentos por ID…"
func _process(delta: float) -> void:
	clock+=delta
	if started<0:
		if lab.received_frames>=10:started=clock
		elif clock>25:finish()
		return
	var elapsed:=clock-started
	if elapsed<4:
		label.text="Prepara ambas manos abiertas. Prueba guiada de 80 s.\nObserva el color/ID; alterna frente y canto. No se guarda video."
		return
	var next:=int((elapsed-4)/4)
	if next>=20:finish();return
	if next!=trial:
		if not current.is_empty():stats.append(current)
		trial=next
		lab.garage_pointer.cancel()
		lab.challenges.configure_transfer(100,150,"vinagre",5)
		target=lab.challenges.beaker if trial%2==0 else lab.challenges.bottle
		current={"trial":trial+1,"id":trial/10,"target":str(target.name),"orientation":"frente" if trial%10<5 else "canto","detected":false,"accepted":false,"close_seen":false,"candidate_seen":false,"success":false}
	var id:=int(trial/10)
	current["id"]=id
	var actor=lab.garage_pointer.actors[id]
	current.detected=current.detected or actor.debug.get("detected",false)
	current.accepted=current.accepted or actor.debug.get("accepted",false)
	current.close_seen=current.close_seen or actor.debug.get("flexed",false)
	current.candidate_seen=current.candidate_seen or actor.highlight==target
	current.success=current.success or actor.held_object==target
	lab.tracking_audit.phase="agarre_%d_%s_%s" % [trial+1,id,current.orientation]
	label.text="ID %d (%s) · intento %d/10 · %s · palma de %s\n%s Flexiona dedos para agarrar y abre para soltar. %s" % [id,"ámbar" if id==0 else "azul",trial%10+1,target.name,current.orientation,"Entra ya flexionado." if trial%2 else "Apunta abierto y flexiona sobre el objeto.","AGARRADO" if current.success else ""]
func finish() -> void:
	if not current.is_empty():stats.append(current)
	for row in stats:
		row["failure"]="" if row.success else ("detection" if not row.accepted else ("flexion" if not row.close_seen else "candidate_or_recovery"))
	var path: String=lab.base_dir.path_join("registros/agarre-webcam-intentos.json")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"source":"webcam real, instrucciones guiadas","human_compliance":"sin confirmar","attempts":stats,"successes_id0":stats.filter(func(row):return row.id==0 and row.success).size(),"successes_id1":stats.filter(func(row):return row.id==1 and row.success).size()},"  "))
	print("AGARRE REAL: ",path)
	print("AUDITORÍA REAL: ",lab.tracking_audit.stem)
	lab._close()
