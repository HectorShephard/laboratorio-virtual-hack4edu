extends Node
## Dos cursores de manos y un cursor de ratón comparten reservas de objetos.
var lab: Node3D
var actors: Array[Node] = []
var mouse: Node
var owners: Dictionary = {}
var injecting := false
var overlay: CanvasLayer
var debug_overlay: Control
var last_owners := ""
var held_object: Node3D:
	get:
		for actor in actors + [mouse]:
			if is_instance_valid(actor.held_object):
				return actor.held_object
		return null

func _ready() -> void:
	overlay = preload("res://ui/hands_overlay.gd").new()
	add_child(overlay)
	for index in 3:
		var actor := preload("res://core/garage_pointer.gd").new()
		actor.lab = lab
		actor.coordinator = self
		actor.hand_id = index
		actor.receive_mouse = index == 2
		add_child(actor)
		if index == 2:
			mouse = actor
		else:
			actors.append(actor)
	var layer:=CanvasLayer.new()
	layer.layer=60
	add_child(layer)
	debug_overlay=preload("res://ui/grip_debug.gd").new()
	debug_overlay.manager=self
	layer.add_child(debug_overlay)

func _input(event: InputEvent) -> void:
	var focused:=get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F3:
		debug_overlay.toggle()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if lab.state_file.is_empty():return
	var ids: Array=[]
	for actor in actors:
		if is_instance_valid(actor.held_object):ids.append(actor.hand_id)
	var serialized:=JSON.stringify({"held_ids":ids})
	if serialized==last_owners:return
	last_owners=serialized
	var destination: String=lab.state_file+".owners"
	var file:=FileAccess.open(destination+".tmp",FileAccess.WRITE)
	if file!=null:
		file.store_string(serialized)
		file.close()
		DirAccess.rename_absolute(destination+".tmp",destination)

func claim(object: Node3D, id: int) -> bool:
	var key := object.get_instance_id()
	if owners.has(key) and owners[key] != id:
		return false
	owners[key] = id
	object.set_meta("held", true)
	object.set_meta("control_paused", false)
	object.set_meta("control_age",0.0)
	object.set_meta("control_unique",true)
	return true

func release(object: Node3D, id: int) -> void:
	if is_instance_valid(object) and owners.get(object.get_instance_id(), -1) == id:
		owners.erase(object.get_instance_id())
		object.set_meta("held", false)
		object.set_meta("control_paused", false)
		object.set_meta("control_age",0.0)
		object.set_meta("control_unique",false)

func cancel() -> void:
	for actor in actors + [mouse]:
		actor.cancel()

func interrupt_flow() -> void:
	if lab.challenges.active == 2:
		lab.challenges.transfer.interrupted = true
		lab.challenges.stop_emission()

func update_hand(packet: Dictionary, fresh: bool, delta: float) -> void:
	var hands: Array = packet.get("hands", [packet])
	for index in 2:
		var sample: Dictionary = {}
		for hand in hands:
			if int(hand.get("id", 0)) == index:
				sample = hand
		actors[index].update_hand(sample, fresh, delta)

func selection_text() -> String:
	var texts := PackedStringArray()
	for actor in actors + [mouse]:
		if is_instance_valid(actor.held_object):
			var caption: String = actor.held_object.name
			if actor.held_object.get_meta("kind", "") == "bottle":
				caption = "Frasco de " + lab.challenges.transfer.liquid
			texts.append(("Ratón" if actor.hand_id == 2 else ("Ámbar" if actor.hand_id==0 else "Azul")) + ": " + caption)
	return " · ".join(texts) if not texts.is_empty() else "Apunta al vaso, frasco o espátula"

func hands_status() -> String:
	var texts := PackedStringArray()
	for actor in actors:
		var state: String = "sin señal"
		if actor.initialized:
			state = "agarra " + str(actor.held_object.name) if is_instance_valid(actor.held_object) else ("abre para reactivar" if actor.needs_open else "flexiona sobre un objeto")
		if actor.suspended: state = "pausa · conserva agarre" if is_instance_valid(actor.held_object) else "sin señal"
		texts.append(("Ámbar" if actor.hand_id==0 else "Azul") + " · " + actor.hand_label + ": " + state)
	return "   |   ".join(texts)

func close_context() -> void:
	if lab.chemistry_assistant.visible:
		lab.chemistry_assistant.close_panel()
		return
	if lab.experiment_panel.visible:
		lab.experiment_panel.hide()
	elif lab.garage_menu.visible:
		lab.garage_menu.hide()
	elif lab.chemistry_panel.visible:
		lab.chemistry_panel.hide()
	cancel()
