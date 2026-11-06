extends Node
## Se ejecuta con el MISMO lanzador y puente del jugador: --audit-hands.
var lab: Node
var started := -1.0
var elapsed := 0.0
var label: Label
const PHASES := ["izquierda_sola","derecha_sola","entra_izquierda_derecha","entra_derecha_izquierda","cruzadas","perdida_temporal"]
const MESSAGES := ["Muestra SOLO tu mano IZQUIERDA","Muestra SOLO tu mano DERECHA","Izquierda abierta; añade la DERECHA","Derecha abierta; añade la IZQUIERDA","Muestra AMBAS y crúzalas despacio","Mantén ambas; oculta una brevemente y vuelve"]
func _ready() -> void:
	lab.audit_only=true
	lab._open_chemistry()
	lab.chemistry_panel.hide()
	var layer:=CanvasLayer.new()
	add_child(layer)
	var panel:=PanelContainer.new()
	layer.add_child(panel)
	panel.position=Vector2(210,175)
	panel.custom_minimum_size=Vector2(650,100)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",preload("res://ui/walnut_theme.gd").panel())
	label=Label.new()
	label.add_theme_font_size_override("font_size",20)
	panel.add_child(label)
	label.text="Conectando webcam real…"
func _process(delta: float) -> void:
	elapsed+=delta
	if started<0:
		if lab.received_frames>=10: started=elapsed
		elif elapsed>25:
			print("AUDITORÍA: no llegaron fotogramas reales")
			lab._close()
		return
	var time:=elapsed-started
	if time>=PHASES.size()*8:
		print("AUDITORÍA REAL: ",lab.tracking_audit.stem)
		lab._close()
		return
	var index:=mini(PHASES.size()-1,int(time/8))
	var local:=fmod(time,8)
	lab.tracking_audit.phase=("preparar_" if local<3 else "")+PHASES[index]
	label.text=("En %d s: " % (3-int(local)) if local<3 else "Observación %d/5 s: " % int(local-2))+MESSAGES[index]+"\nÁmbar = ID 0 · Azul = ID 1 · No se activan objetos"
	# Presentación real y misma calibración, con acciones inhibidas durante la medición.
	var presentation: Dictionary = lab.packet.duplicate(true)
	for hand in presentation.get("hands",[]):
		hand["pinched"]=false
		hand["middle_pinched"]=false
	lab.garage_pointer.update_hand(presentation,Time.get_ticks_msec()/1000.0-lab.last_packet_time<.35,delta)
	for hand in lab.packet.get("hands",[]):
		if hand.get("present",false):
			var actor=lab.garage_pointer.actors[int(hand.id)]
			actor.visual.pose(hand,actor.cursor,get_viewport().get_visible_rect().size,false)
