extends Node3D

const PreviewScript = preload("res://hand_preview.gd")
const TrackingGuard = preload("res://tracking_guard.gd")
const LabRoom = preload("res://lab_room.gd")
const INK := Color("d9eaf0")
const MUTED := Color("87a2af")
const TEAL := Color("48d5bc")
const GOLD := Color("ffce73")

var base_dir: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
var camera: Camera3D
var room: Node3D
var player: CharacterBody3D
var explore_camera: Camera3D
var exploring := false
var bench_start := false
var navigation_button: Button
var measure_button: Button
var subtitle_label: Label
var cube: RigidBody3D
var cube_material: StandardMaterial3D
var target_material: StandardMaterial3D
var pointer: MeshInstance3D
var hud: Control
var status_label: Label
var metrics_label: Label
var instruction_label: Label
var count_label: Label
var note_label: Label
var mode_button: Button
var preview: Control
var channel: Dictionary = {}
var stdout_pipe: FileAccess
var stderr_pipe: FileAccess
var text_buffer := ""
var stderr_text := ""
var packet: Dictionary = {}
var process_pid := -1
var mouse_mode := false
var synthetic := false
var ready_camera := false
var error_message := ""
var bridge_status := "Iniciando Python…"
var bridge_started := -1.0
var state_file := ""
var stop_file := ""
var pause_file := ""
var last_state_text := ""
var next_state_read := 0
var closing := false
var last_packet_time := -100.0
var last_seen_time := -100.0
var previous_pressed := false
var pinch_armed := false
var held := false
var cursor_world := Vector3.ZERO
var cursor_initialized := false
var grab_offset := Vector3.ZERO
var tracking_guard := TrackingGuard.new()
var reanchor_on_valid := false
var recovery_grip_until := -1.0
var grabs := 0
var releases := 0
var lost_grabs := 0
var ui_tick := 0.0
var camera_args: PackedStringArray = []
var measure_start := -1.0
var measure_frames := 0
var measure_packets: Array[Dictionary] = []
var measure_frame_ms: Array[float] = []
var measure_before := Vector3i.ZERO
var latest_report := ""
var test_exit_after := 0.0
var test_started := 0.0

func _ready() -> void:
	get_tree().auto_accept_quit = false
	Engine.max_fps = 60
	_build_world()
	_build_hud()
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i] == "--mouse":
			mouse_mode = true
		elif args[i] == "--bench":
			bench_start = true
		elif args[i] == "--test-stream":
			synthetic = true
		elif args[i] in ["--state-file", "--stop-file", "--pause-file"] and i + 1 < args.size():
			var key := args[i]
			i += 1
			if key == "--state-file":
				state_file = args[i]
			elif key == "--stop-file":
				stop_file = args[i]
			else:
				pause_file = args[i]
		elif args[i] == "--test-exit" and i + 1 < args.size():
			i += 1
			test_exit_after = float(args[i])
		elif args[i] in ["--camera", "--width", "--height", "--pinch"] and i + 1 < args.size():
			camera_args.append(args[i])
			i += 1
			camera_args.append(args[i])
		i += 1
	if not state_file.is_empty():
		bridge_started = Time.get_ticks_msec() / 1000.0
		bridge_status = "Esperando al seguimiento local…"
	elif not mouse_mode:
		_start_bridge()
	if not bench_start and not mouse_mode and not synthetic:
		_enter_explore()
	else:
		_enter_workbench()
	if test_exit_after > 0:
		test_started = Time.get_ticks_msec() / 1000.0
		_start_measure()

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	return material

func _box(parent: Node3D, size: Vector3, position_value: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	mesh.position = position_value
	return mesh

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("0b141e")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("a5c7df")
	settings.ambient_light_energy = 0.75
	environment.environment = settings
	add_child(environment)
	room = LabRoom.new()
	add_child(room)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.3
	add_child(camera)
	camera.position = Vector3(0.7, 5.6, 6.7)
	camera.look_at(Vector3(0.7, 0.1, 0))
	camera.current = true
	_build_player()
	var table := StaticBody3D.new()
	add_child(table)
	_box(table, Vector3(7.1, .18, 4.7), Vector3(0, -.09, 0), Color("203849"))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(7.1, .18, 4.7)
	collision.shape = shape
	collision.position.y = -.09
	table.add_child(collision)
	for x in range(-6, 7):
		_box(self, Vector3(.012, .008, 4.4), Vector3(x * .5, .006, 0), Color("2c4758"))
	for z in range(-4, 5):
		_box(self, Vector3(6.8, .008, .012), Vector3(0, .007, z * .5), Color("2c4758"))
	for x in [-2.8, 2.8]:
		for z in [-1.7, 1.7]:
			_box(self, Vector3(.2, 1.0, .2), Vector3(x, -.65, z), Color("142633"))
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = .56
	torus.outer_radius = .61
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	target_material = _material(GOLD)
	ring.material_override = target_material
	ring.position = Vector3(1.4, .035, -.45)
	add_child(ring)
	cube = RigidBody3D.new()
	cube.mass = .4
	cube.linear_damp = 1.5
	cube.angular_damp = 3.0
	cube.continuous_cd = true
	add_child(cube)
	var body_mesh := _box(cube, Vector3(.55, .55, .55), Vector3.ZERO, TEAL)
	cube_material = body_mesh.material_override as StandardMaterial3D
	var body_collision := CollisionShape3D.new()
	var body_shape := BoxShape3D.new()
	body_shape.size = Vector3(.55, .55, .55)
	body_collision.shape = body_shape
	cube.add_child(body_collision)
	_box(cube, Vector3(.36, .012, .36), Vector3(0, .281, 0), Color("c5fff3"))
	pointer = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .075
	sphere.height = .15
	sphere.radial_segments = 12
	sphere.rings = 6
	pointer.mesh = sphere
	pointer.material_override = _material(Color("efffff"))
	add_child(pointer)
	pointer.visible = false
	_reset_cube()

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Visitante"
	player.floor_snap_length = .2
	add_child(player)
	player.position = Vector3(0, -1.15, 5.4)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .28
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = .9
	player.add_child(collider)
	explore_camera = Camera3D.new()
	explore_camera.fov = 72
	explore_camera.position = Vector3(0, 1.65, 0)
	player.add_child(explore_camera)

func _enter_explore() -> void:
	if measure_start >= 0:
		_save_measure(false)
	_drop(false)
	exploring = true
	pointer.visible = false
	previous_pressed = false
	pinch_armed = false
	cursor_initialized = false
	camera.current = false
	explore_camera.current = true
	room.set_workbench_view(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not state_file.is_empty():
		_write_flag(pause_file)
	_update_ui(Time.get_ticks_msec() / 1000.0, false, false, false)

func _enter_workbench() -> void:
	exploring = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	explore_camera.current = false
	camera.current = true
	room.set_workbench_view(true)
	tracking_guard.reset()
	previous_pressed = false
	pinch_armed = false
	cursor_initialized = false
	if not state_file.is_empty() and not mouse_mode:
		DirAccess.remove_absolute(pause_file)
		error_message = ""
	_update_ui(Time.get_ticks_msec() / 1000.0, false, false, false)

func _toggle_navigation() -> void:
	if exploring:
		_enter_workbench()
	else:
		_enter_explore()

func _physics_process(delta: float) -> void:
	if player == null:
		return
	if not player.is_on_floor():
		player.velocity.y -= 9.8 * delta
	else:
		player.velocity.y = 0
	var direction := Vector3.ZERO
	if exploring:
		direction.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		direction.z = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		direction = direction.normalized().rotated(Vector3.UP, player.rotation.y)
	player.velocity.x = move_toward(player.velocity.x, direction.x * 3.0, 16 * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.z * 3.0, 16 * delta)
	player.move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if not exploring:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.screen_relative.x * .002)
		explore_camera.rotation.x = clampf(explore_camera.rotation.x - event.screen_relative.y * .002, -1.05, 1.05)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_E, KEY_TAB]:
		_toggle_navigation()
		get_viewport().set_input_as_handled()

func _panel(color: Color, radius: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func _label(text: String, font_size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 32
	for state in {"normal": Color("263d4a"), "hover": Color("345462"), "pressed": Color("376e67")}:
		var colors := {"normal": Color("263d4a"), "hover": Color("345462"), "pressed": Color("376e67")}
		var style := _panel(colors[state], 9)
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", INK)
	button.pressed.connect(callback)
	return button

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	var header := PanelContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 24
	header.offset_top = 22
	header.offset_right = -24
	header.offset_bottom = 112
	header.add_theme_stylebox_override("panel", _panel(Color("13232f")))
	hud.add_child(header)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 3)
	header.add_child(top)
	top.add_child(_label("D U E L I S T A S   D E L   T A M A R I N D O", 11, TEAL))
	top.add_child(_label("Tu laboratorio de ciencias", 26))
	subtitle_label = _label("Cuarto de pruebas · mesa central · estaciones de ciencias", 14, MUTED)
	top.add_child(subtitle_label)
	var side := PanelContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -296
	side.offset_right = -24
	side.offset_top = 132
	side.offset_bottom = -76
	side.add_theme_stylebox_override("panel", _panel(Color("13232f")))
	var side_style := _panel(Color("13232f"))
	side_style.content_margin_top = 12
	side_style.content_margin_bottom = 12
	side.add_theme_stylebox_override("panel", side_style)
	hud.add_child(side)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	side.add_child(column)
	column.add_child(_label("CONTROL Y RENDIMIENTO", 12, MUTED))
	status_label = _label("Preparando seguimiento…", 18, GOLD)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status_label)
	preview = PreviewScript.new()
	preview.custom_minimum_size = Vector2(230, 76)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(preview)
	metrics_label = _label("Entorno 3D: —\nSeguimiento: —\nCámara: —\nInferencia: —", 15)
	column.add_child(metrics_label)
	count_label = _label("Agarres: 0  ·  Sueltas: 0", 13, TEAL)
	column.add_child(count_label)
	mode_button = _button("Comparar con ratón", _toggle_mode)
	column.add_child(mode_button)
	navigation_button = _button("Explorar sala [Tab]", _toggle_navigation)
	column.add_child(navigation_button)
	measure_button = _button("Medir 60 s [Espacio]", _start_measure)
	column.add_child(measure_button)
	note_label = _label("Señal local · Sin grabar video\nR: reiniciar  ·  Esc: salir", 11, MUTED)
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note_label)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_top = -60
	bottom.offset_right = -24
	bottom.offset_bottom = -18
	bottom.add_theme_stylebox_override("panel", _panel(Color("13232f"), 10))
	hud.add_child(bottom)
	instruction_label = _label("Prueba de interacción: escena 3D, control de la mano sobre un plano de trabajo.", 13, MUTED)
	bottom.add_child(instruction_label)

func _start_bridge() -> void:
	error_message = ""
	bridge_status = "Iniciando Python…"
	bridge_started = Time.get_ticks_msec() / 1000.0
	stderr_text = ""
	ready_camera = false
	packet = {}
	text_buffer = ""
	var interpreter := OS.get_environment("HACK4EDU_PYTHON")
	if interpreter.is_empty():
		interpreter = base_dir.path_join(".venv/Scripts/python.exe" if OS.get_name() == "Windows" else ".venv/bin/python")
	if not FileAccess.file_exists(interpreter):
		error_message = "Ejecuta primero 1_PREPARAR.bat. Puedes probar ahora con ratón."
		_write_bridge_log()
		return
	var arguments := PackedStringArray(["-u", base_dir.path_join("seguimiento.py")])
	arguments.append_array(camera_args)
	if synthetic:
		arguments.append("--test-stream")
	channel = OS.execute_with_pipe(interpreter, arguments, false)
	if channel.is_empty():
		error_message = "No se pudo iniciar Python. Revisa 1_PREPARAR.bat."
		_write_bridge_log()
		return
	stdout_pipe = channel["stdio"]
	stderr_pipe = channel["stderr"]
	process_pid = int(channel["pid"])
	_write_bridge_log()

func _write_bridge_log() -> void:
	var folder := base_dir.path_join("registros")
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder.path_join("seguimiento.log"), FileAccess.WRITE)
	if file != null:
		file.store_string("Estado: " + bridge_status + "\nError: " + error_message + "\n\n" + stderr_text)
		file.close()

func _pipe_chunk(pipe: FileAccess) -> PackedByteArray:
	var count := 4096
	if OS.get_name() == "Windows":
		# En Windows get_length() usa PeekNamedPipe: leer solo bytes disponibles.
		count = mini(count, int(pipe.get_length()))
	if count <= 0:
		return PackedByteArray()
	return pipe.get_buffer(count)

func _read_bridge() -> void:
	if not state_file.is_empty():
		_read_state_file()
		return
	if stdout_pipe == null:
		return
	for _i in range(8):
		var chunk := _pipe_chunk(stdout_pipe)
		if chunk.is_empty():
			break
		text_buffer += chunk.get_string_from_utf8()
	if text_buffer.length() > 262144:
		text_buffer = ""
		error_message = "El seguimiento envió datos incompletos. Reinicia la prueba."
	var newline := text_buffer.find("\n")
	while newline >= 0:
		var line := text_buffer.substr(0, newline)
		text_buffer = text_buffer.substr(newline + 1)
		var decoded: Variant = JSON.parse_string(line)
		if decoded is Dictionary:
			_receive(decoded)
		newline = text_buffer.find("\n")
	if stderr_pipe != null:
		var err := _pipe_chunk(stderr_pipe)
		if not err.is_empty():
			stderr_text = (stderr_text + err.get_string_from_utf8()).right(40000)
			_write_bridge_log()
	if process_pid > 0 and not OS.is_process_running(process_pid):
		if error_message.is_empty():
			error_message = "El seguimiento se cerró. Ejecuta 4_PROBAR_CAMARA_SOLA.bat y revisa registros/seguimiento.log."
		_write_bridge_log()
		_stop_bridge()
		return
	if packet.is_empty() and Time.get_ticks_msec() / 1000.0 - bridge_started > 20 and error_message.is_empty():
		error_message = "La cámara no envió datos. Ejecuta 4_PROBAR_CAMARA_SOLA.bat."
		_write_bridge_log()

func _read_state_file() -> void:
	if mouse_mode:
		return
	var now := Time.get_ticks_msec()
	if now < next_state_read:
		return
	next_state_read = now + 25
	var file := FileAccess.open(state_file, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	if text == last_state_text:
		return
	last_state_text = text
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		if data.get("type", "") == "frame":
			if Time.get_unix_time_from_system() - float(data.get("captured_unix", 0)) > .5:
				return
			ready_camera = true
			synthetic = bool(data.get("synthetic", false))
		_receive(data)

func _write_flag(path: String) -> void:
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("1")
		file.close()

func _receive(data: Dictionary) -> void:
	if data.get("type", "") == "status":
		bridge_status = str(data.get("message", "Iniciando seguimiento…"))
		_write_bridge_log()
		return
	if data.get("type", "") == "error":
		error_message = str(data.get("message", "Error de cámara."))
		_write_bridge_log()
		return
	if data.get("type", "") == "ready":
		ready_camera = true
		synthetic = bool(data.get("synthetic", false))
		return
	if data.get("type", "") != "frame":
		return
	last_packet_time = Time.get_ticks_msec() / 1000.0
	packet = data.duplicate()
	var detected := bool(data.get("present", false))
	var quality: Dictionary
	if detected:
		var raw: Array = data.get("cursor", [.5, .5])
		quality = tracking_guard.evaluate(Vector2(float(raw[0]), float(raw[1])), data.get("landmarks", []), last_packet_time)
	else:
		quality = tracking_guard.missing()
	packet["present"] = detected and bool(quality["stable"])
	packet["unstable"] = detected and not bool(quality["stable"])
	if bool(quality["reacquired"]):
		cursor_initialized = false
		reanchor_on_valid = held
	if bool(packet["present"]):
		last_seen_time = last_packet_time
	preview.points = packet.get("landmarks", [])
	preview.active = bool(packet.get("present", false))
	preview.closed = bool(packet.get("pinched", false))
	preview.queue_redraw()
	if measure_start >= 0:
		measure_packets.append({"segundo": last_packet_time - measure_start,
			"mano": detected, "control_estable": bool(packet["present"]), "inferencia_ms": float(packet.get("inference_ms", 0)),
			"seguimiento_hz": float(packet.get("tracking_hz", 0)), "camara_hz": float(packet.get("camera_hz", 0)),
			"edad_software_ms": maxf(0, (Time.get_unix_time_from_system() - float(packet.get("captured_unix", 0))) * 1000)})

func _work_rect() -> Rect2:
	var size := get_viewport().get_visible_rect().size
	return Rect2(30, 134, maxf(300, size.x - 358), maxf(260, size.y - 218))

func _point_on_table(screen: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var intersection: Variant = Plane(Vector3.UP, 0.02).intersects_ray(origin, direction)
	return intersection as Vector3 if intersection != null else Vector3.ZERO

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if exploring:
		ui_tick += delta
		if ui_tick >= .12:
			ui_tick = 0
			_update_ui(now, false, false, false)
		if test_exit_after > 0 and now - test_started >= test_exit_after:
			_close()
		return
	_read_bridge()
	var valid := false
	var pressed := false
	var target := Vector3.ZERO
	if mouse_mode:
		var screen := get_viewport().get_mouse_position()
		valid = _work_rect().has_point(screen)
		pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if valid:
			target = _point_on_table(screen)
	else:
		valid = not packet.is_empty() and bool(packet.get("present", false)) and now - last_packet_time < .35
		pressed = bool(packet.get("pinched", false)) if valid else false
		if valid:
			var xy: Array = packet.get("cursor", [0.5, 0.5])
			var normalized := Vector2(float(xy[0]), float(xy[1])).clamp(Vector2.ZERO, Vector2.ONE)
			var rect := _work_rect()
			target = _point_on_table(rect.position + normalized * rect.size)
	if valid:
		target.x = clampf(target.x, -2.9, 2.9)
		target.z = clampf(target.z, -1.85, 1.85)
		if not cursor_initialized:
			cursor_world = target
			cursor_initialized = true
		else:
			cursor_world = cursor_world.lerp(target, 1.0 - exp(-delta / .045))
		pointer.visible = true
		pointer.position = cursor_world + Vector3(0, .055, 0)
		if reanchor_on_valid:
			if held:
				grab_offset = Vector3(cube.position.x - cursor_world.x, 0, cube.position.z - cursor_world.z)
				recovery_grip_until = now + .18
			reanchor_on_valid = false
		if not pressed:
			pinch_armed = true
		if pressed and not previous_pressed and pinch_armed:
			var flat_distance := Vector2(cube.position.x - cursor_world.x, cube.position.z - cursor_world.z).length()
			if flat_distance < .55:
				_grab()
		if held and not pressed and now > recovery_grip_until:
			_drop(false)
		if held:
			var destination := cursor_world + grab_offset
			destination.y = .95
			destination.x = clampf(destination.x, -2.9, 2.9)
			destination.z = clampf(destination.z, -1.85, 1.85)
			cube.position = cube.position.lerp(destination, 1.0 - exp(-delta / .035))
		previous_pressed = pressed
	else:
		pointer.visible = false
		cursor_initialized = false
		if held and (mouse_mode or now - last_seen_time > .6):
			_drop(true)
			pinch_armed = false
		previous_pressed = false
	if cube.position.y < -3:
		_reset_cube()
	var in_zone := Vector2(cube.position.x - 1.4, cube.position.z + .45).length() < .56 and cube.position.y < .55 and not held
	target_material.albedo_color = TEAL if in_zone else GOLD
	cube_material.albedo_color = GOLD if held else TEAL
	if measure_start >= 0:
		measure_frames += 1
		measure_frame_ms.append(delta * 1000)
		if now - measure_start >= 60:
			_save_measure(true)
	ui_tick += delta
	if ui_tick >= .12:
		ui_tick = 0
		_update_ui(now, valid, pressed, in_zone)
	if test_exit_after > 0 and now - test_started >= test_exit_after:
		_close()

func _grab() -> void:
	if held:
		return
	held = true
	grabs += 1
	cube.freeze = true
	cube.linear_velocity = Vector3.ZERO
	cube.angular_velocity = Vector3.ZERO
	grab_offset = Vector3(cube.position.x - cursor_world.x, 0, cube.position.z - cursor_world.z)

func _drop(lost: bool) -> void:
	if not held:
		return
	held = false
	reanchor_on_valid = false
	recovery_grip_until = -1
	cube.freeze = false
	cube.sleeping = false
	cube.linear_velocity = Vector3.ZERO
	cube.angular_velocity = Vector3.ZERO
	if lost:
		lost_grabs += 1
	else:
		releases += 1

func _reset_cube() -> void:
	held = false
	reanchor_on_valid = false
	recovery_grip_until = -1
	pinch_armed = false
	previous_pressed = false
	cube.freeze = true
	cube.position = Vector3(-1.35, .32, .4)
	cube.rotation = Vector3.ZERO
	cube.linear_velocity = Vector3.ZERO
	cube.angular_velocity = Vector3.ZERO
	cube.freeze = false
	cube.sleeping = false

func _update_ui(now: float, valid: bool, pressed: bool, in_zone: bool) -> void:
	navigation_button.text = "Ir a la mesa [E]" if exploring else "Explorar sala [Tab]"
	measure_button.disabled = exploring
	mode_button.disabled = exploring
	if exploring:
		subtitle_label.text = "Recorre la sala y pulsa E cuando quieras trabajar en la mesa."
		preview.visible = false
		status_label.text = "Explorando la sala"
		status_label.add_theme_color_override("font_color", TEAL)
		metrics_label.text = "Entorno 3D: %d FPS\nManos: en pausa" % Engine.get_frames_per_second()
		count_label.text = "Mesa central: interactiva\nEstaciones laterales: ambientación"
		note_label.text = "WASD: caminar\nE / Tab: ir a la mesa\nEsc: cursor libre  ·  Q: salir"
		instruction_label.text = "Haz clic en la sala para mirar con el ratón. WASD para moverte. E para usar la mesa."
		return
	subtitle_label.text = "Haz pinza sobre el cubo, muévelo al círculo y abre los dedos para soltarlo."
	mode_button.text = "Volver a la cámara" if mouse_mode else "Comparar con ratón"
	preview.visible = not mouse_mode and error_message.is_empty()
	if not error_message.is_empty() and not mouse_mode:
		status_label.text = error_message.left(140)
		status_label.add_theme_color_override("font_color", GOLD)
	elif mouse_mode:
		status_label.text = "Modo ratón"
		status_label.add_theme_color_override("font_color", TEAL)
	elif synthetic:
		status_label.text = "ENTRADA SIMULADA"
		status_label.add_theme_color_override("font_color", GOLD)
	elif valid:
		status_label.text = "Cubo agarrado" if held else ("Pinza cerrada" if pressed else "Mano detectada")
		status_label.add_theme_color_override("font_color", TEAL)
	elif held or bool(packet.get("unstable", false)):
		status_label.text = "Recuperando la mano…"
		status_label.add_theme_color_override("font_color", GOLD)
	else:
		status_label.text = "Muestra tu mano" if ready_camera and not packet.is_empty() else bridge_status
		status_label.add_theme_color_override("font_color", GOLD)
	var fresh := now - last_packet_time < .5 and not mouse_mode
	var hz := "%.1f Hz" % float(packet.get("tracking_hz", 0)) if fresh else "—"
	var camera_hz := "%.1f FPS" % float(packet.get("camera_hz", 0)) if fresh else "—"
	var inference := "%.1f ms" % float(packet.get("inference_ms", 0)) if fresh else "—"
	metrics_label.text = "Entorno 3D: %d FPS\nSeguimiento: %s\nLectura cámara: %s\nInferencia: %s" % [Engine.get_frames_per_second(), hz, camera_hz, inference]
	count_label.text = "Agarres: %d  ·  Sueltas: %d\nPérdidas durante agarre: %d" % [grabs, releases, lost_grabs]
	if measure_start >= 0:
		note_label.text = "Midiendo: %d / 60 s\nEsc: guardar y salir" % int(now - measure_start)
	elif not latest_report.is_empty():
		note_label.text = "Informe guardado en resultados.\nPuedes repetir con Espacio."
	else:
		note_label.text = "Tab: recorrer sala  ·  R: reiniciar\nEsc: salir  ·  Espacio: medir"
	if mouse_mode:
		instruction_label.text = "Ratón: acerca el cursor al cubo y mantén clic izquierdo para moverlo. Suelta el clic para dejarlo caer."
	elif in_zone:
		instruction_label.text = "¡Cubo colocado en la zona! Repite el agarre y compara movimientos lentos y moderados."
	else:
		instruction_label.text = "Muestra primero la mano abierta. Lleva el cursor al cubo y haz pinza para agarrarlo."

func _stop_bridge() -> void:
	if not state_file.is_empty():
		_write_flag(stop_file if closing else pause_file)
		ready_camera = false
		packet = {}
		preview.active = false
		preview.queue_redraw()
		return
	var alive := process_pid > 0 and OS.is_process_running(process_pid)
	if stdout_pipe != null and alive:
		stdout_pipe.store_line("stop")
		stdout_pipe.flush()
	if alive:
		OS.kill(process_pid)
	process_pid = -1
	stdout_pipe = null
	stderr_pipe = null
	channel = {}
	ready_camera = false
	packet = {}
	preview.active = false
	preview.queue_redraw()

func _toggle_mode() -> void:
	if measure_start >= 0:
		_save_measure(false)
	_drop(true)
	_stop_bridge()
	tracking_guard.reset()
	mouse_mode = not mouse_mode
	pinch_armed = false
	previous_pressed = false
	if not mouse_mode:
		if not state_file.is_empty():
			DirAccess.remove_absolute(pause_file)
			error_message = ""
			bridge_status = "Reabriendo cámara…"
		else:
			_start_bridge()

func _start_measure() -> void:
	if exploring:
		return
	if measure_start >= 0:
		_save_measure(false)
	measure_start = Time.get_ticks_msec() / 1000.0
	measure_frames = 0
	measure_packets = []
	measure_frame_ms = []
	measure_before = Vector3i(grabs, releases, lost_grabs)

func _quantile(values: Array[float], ratio: float) -> float:
	if values.is_empty():
		return 0
	var copy := values.duplicate()
	copy.sort()
	return copy[int(round((copy.size() - 1) * ratio))]

func _save_measure(completed: bool) -> void:
	if measure_start < 0:
		return
	var elapsed := maxf(.001, Time.get_ticks_msec() / 1000.0 - measure_start)
	var times: Array[float] = []
	var camera_rates: Array[float] = []
	var detected := 0
	var rejected := 0
	for sample in measure_packets:
		times.append(sample["inferencia_ms"])
		camera_rates.append(sample["camara_hz"])
		if sample["mano"]:
			detected += 1
			if not sample.get("control_estable", true):
				rejected += 1
	var folder := base_dir.path_join("resultados")
	DirAccess.make_dir_recursive_absolute(folder)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var stem := folder.path_join("lab3d_" + stamp + "_" + str(Time.get_ticks_msec()))
	var data := {"modo": "raton" if mouse_mode else ("simulado" if synthetic else "camara"),
		"duracion_s": elapsed, "completo": completed,
		"fps_entorno_3d": measure_frames / elapsed,
		"actualizaciones_seguimiento_hz": measure_packets.size() / elapsed,
		"camara_fps_mediana": _quantile(camera_rates, .5),
		"inferencia_ms_mediana": _quantile(times, .5), "inferencia_ms_p95": _quantile(times, .95),
		"frame_3d_ms_p95": _quantile(measure_frame_ms, .95),
		"datos_con_mano_pct": detected * 100.0 / maxi(1, measure_packets.size()),
		"muestras_de_control_descartadas": rejected,
		"agarres": grabs - measure_before.x, "sueltas": releases - measure_before.y,
		"perdidas_durante_agarre": lost_grabs - measure_before.z,
		"godot": Engine.get_version_info()["string"], "renderizador": "gl_compatibility",
		"notas": ["Los FPS 3D y la frecuencia del detector son medidas distintas.",
		"La presencia de mano no mide precision; depende de que la mano permanezca visible.",
		"La inferencia y la edad software del dato no miden la latencia completa de camara a pantalla.",
		"Los controles mueven el objeto en X/Z y lo levantan a una altura fija al agarrar; no hay medicion de profundidad real.",
		"No se guardan fotos ni video."]}
	var file := FileAccess.open(stem + ".json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))
		file.close()
		latest_report = stem + ".json"
	else:
		error_message = "No se pudo guardar el informe. Revisa permisos de la carpeta."
	var csv := FileAccess.open(stem + ".csv", FileAccess.WRITE)
	if csv != null:
		csv.store_csv_line(PackedStringArray(["segundo", "mano", "inferencia_ms", "seguimiento_hz", "camara_hz", "edad_software_ms", "control_estable"]))
		for sample in measure_packets:
			csv.store_csv_line(PackedStringArray([str(sample["segundo"]), str(sample["mano"]), str(sample["inferencia_ms"]), str(sample["seguimiento_hz"]), str(sample["camara_hz"]), str(sample["edad_software_ms"]), str(sample.get("control_estable", true))]))
		csv.close()
	measure_start = -1
	print("Informe: ", stem + ".json")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_close()
		elif event.keycode == KEY_R and not exploring:
			_reset_cube()
		elif event.keycode == KEY_SPACE:
			_start_measure()
		elif event.keycode == KEY_ESCAPE:
			if exploring:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				_close()

func _close() -> void:
	if closing:
		return
	closing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if measure_start >= 0:
		_save_measure(false)
	_stop_bridge()
	if not stderr_text.is_empty():
		var folder := base_dir.path_join("registros")
		DirAccess.make_dir_recursive_absolute(folder)
		var file := FileAccess.open(folder.path_join("seguimiento.log"), FileAccess.WRITE)
		if file != null:
			file.store_string("Estado: " + bridge_status + "\nError: " + error_message + "\n\n" + stderr_text)
			file.close()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close()

func _exit_tree() -> void:
	if process_pid > 0 and OS.is_process_running(process_pid):
		OS.kill(process_pid)
