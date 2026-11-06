extends RefCounted
## Compara detector, asignación de identidad y aceptación del juego sin guardar imágenes.
var phase := "libre"
var stats: Dictionary = {}
var previous: Dictionary = {}
var stem := ""
var samples := 0
var file: FileAccess

func _init(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	stem = directory.path_join("manos_juego-%s-%s" % [OS.get_process_id(),Time.get_ticks_msec()])
	file = FileAccess.open(stem + ".jsonl",FileAccess.WRITE)
	if file != null:
		file.store_line(JSON.stringify({"kind":"configuration","mirror":"inferencia sin espejo; pantalla x=1-x una vez","same_rules_for_both":true,"bench_plane_y":0,"max_speed":2.2,"back_speed":.85,"front_speed":1.6}))

func observe_frame(source: Dictionary, accepted: Array) -> void:
	samples += 1
	for hand in accepted:
		var id := int(hand.id)
		var raw: Dictionary = {}
		for candidate in source.get("hands",[]):
			if int(candidate.id)==id: raw=candidate
		if not stats.has(id):
			stats[id] = {"frames":0,"raw_frames":0,"assigned_frames":0,"accepted_frames":0,"raw_losses":0,"accepted_losses":0,"rejections":0,"raw_jumps":0,"accepted_jumps":0,"epoch_changes":0,"identity_label_changes":0,"detector_label_changes":0,"uncertain_frames":0}
		var counts: Dictionary = stats[id]
		var before: Dictionary = previous.get(id,{})
		var events := PackedStringArray()
		var raw_present := bool(raw.get("raw_present",raw.get("present",false)))
		var game_present := bool(hand.get("present",false))
		counts.frames += 1
		counts.raw_frames += int(raw_present)
		counts.assigned_frames += int(bool(raw.get("present",false)))
		counts.accepted_frames += int(game_present)
		counts.rejections += int(raw_present and not game_present)
		counts.uncertain_frames += int(bool(raw.get("identity_uncertain",false)))
		if before.get("raw_present",false) and not raw_present:
			counts.raw_losses += 1
			events.append("raw_loss")
		if before.get("present",false) and not game_present:
			counts.accepted_losses += 1
			events.append("game_loss")
		var point: Array = raw.get("raw_cursor",raw.get("cursor",[]))
		var game_point: Array = hand.get("cursor",[])
		if game_present and before.get("present",false) and game_point.size()==2 and before.get("game_point",[]).size()==2:
			if Vector2(game_point[0],game_point[1]).distance_to(Vector2(before.game_point[0],before.game_point[1]))>.14:
				counts.accepted_jumps += 1
				events.append("accepted_jump")
		if point.size()==2 and before.get("point",[]).size()==2 and raw_present and before.get("raw_present",false):
			if Vector2(point[0],point[1]).distance_to(Vector2(before.point[0],before.point[1]))>.14:
				counts.raw_jumps += 1
				events.append("raw_jump")
		for key in ["hand_epoch","identity_label","handedness"]:
			if raw.has(key) and before.has(key) and raw[key]!=before[key]:
				var counter: String = {"hand_epoch":"epoch_changes","identity_label":"identity_label_changes","handedness":"detector_label_changes"}[key]
				counts[counter] += 1
				events.append(key+"_changed")
		var next: Dictionary = before.duplicate()
		next.merge({"raw_present":raw_present,"present":game_present,"point":point,"game_point":game_point},true)
		for key in ["hand_epoch","identity_label","handedness"]:
			if raw.has(key): next[key]=raw[key]
		previous[id]=next
		if file != null:
			file.store_line(JSON.stringify({"kind":"flexion_control","phase":phase,"seq":source.get("seq",0),"hand_id":id,"sample_time":raw.get("sample_time",0),"state":raw.get("flex_state","unknown"),"flexion":raw.get("flexion",{}),"gesture_valid":raw.get("gesture_valid",false)}))
			file.store_line(JSON.stringify({"kind":"pinch_control","phase":phase,"seq":source.get("seq",0),"hand_id":id,"sample_time":raw.get("sample_time",0),"ratio":raw.get("ratio",null),"ratio_legacy":raw.get("ratio_legacy",null),"representation":raw.get("ratio_representation",""),"palm_scale":raw.get("palm_scale",null),"pinched":raw.get("pinched",false),"open_confirmed":raw.get("open_confirmed",false)}))
			file.store_line(JSON.stringify({"phase":phase,"seq":source.get("seq",0),"captured_unix":source.get("captured_unix",0),"id":id,"raw_present":raw_present,"assigned":raw.get("present",false),"accepted":game_present,"uncertain":raw.get("identity_uncertain",false),"raw_cursor":point,"accepted_cursor":hand.get("cursor",[]),"wrist":raw.get("wrist",[]),"detector_label":raw.get("handedness",""),"identity_label":raw.get("identity_label",""),"events":events,"raw_detections":source.get("raw_detections",[])}))
	if samples%60==0: flush()

func flush() -> void:
	if file != null: file.flush()
	var summary := FileAccess.open(stem+".json",FileAccess.WRITE)
	if summary != null:
		summary.store_string(JSON.stringify({"samples":samples,"hands":stats,"note":"Los cambios de etiqueta y de época no equivalen a intercambios físicos confirmados."},"  "))
