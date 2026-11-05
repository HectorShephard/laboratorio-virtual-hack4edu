extends Node3D

const MODELS := [
	preload("res://recursos/modelos3d/cohete_agua.tscn"),
	preload("res://recursos/modelos3d/instrumental_quimica.tscn"),
	preload("res://recursos/modelos3d/sapo_exterior.tscn"),
]
const NAMES := ["Cohete de agua", "Instrumental de química", "Sapo exterior"]
const NOTES := [
	"Botella, aletas, boquilla y base de lanzamiento. Geometría provisional.",
	"Vaso abierto, recipiente y espátula. El nivel y las marcas son ilustrativos.",
	"Maqueta exterior. La especie, la escala y los órganos se definen con la referencia anatómica.",
]

var _pivot: Node3D
var _model: Node3D
var _select: OptionButton
var _angle: HSlider
var _note: Label


func _ready() -> void:
	_build_stage()
	_build_controls()
	_show_model(0)


func _build_stage() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("0d1a24")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("cbdff0")
	environment.environment.ambient_light_energy = 0.72
	add_child(environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-54, -27, 0)
	key.light_energy = 1.15
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-34, 150, 0)
	fill.light_energy = 0.5
	add_child(fill)

	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(6.5, 0.15, 5.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("213949")
	floor_material.roughness = 0.9
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.material_override = floor_material
	floor.position.y = -0.08
	add_child(floor)

	_pivot = Node3D.new()
	add_child(_pivot)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.8
	camera.position = Vector3(4.2, 3.2, 6.8)
	add_child(camera)
	camera.look_at(Vector3(0, 1.2, 0))
	camera.current = true


func _build_controls() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var screen := Control.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var header := PanelContainer.new()
	screen.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 22
	header.offset_top = 20
	header.offset_right = -22
	header.add_theme_stylebox_override("panel", _panel_style())
	var heading := VBoxContainer.new()
	header.add_child(heading)
	heading.add_child(_label("HACK4EDU   /   MESA DE REVISIÓN VISUAL", 12, Color("65dcc9")))
	heading.add_child(_label("Modelos 3D de las prácticas", 24, Color("f0f7fa")))

	var footer := PanelContainer.new()
	screen.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 22
	footer.offset_top = -122
	footer.offset_right = -22
	footer.offset_bottom = -20
	footer.add_theme_stylebox_override("panel", _panel_style())
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 9)
	footer.add_child(controls)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	controls.add_child(row)
	_select = OptionButton.new()
	_select.custom_minimum_size.x = 240
	for label in NAMES:
		_select.add_item(label)
	_select.item_selected.connect(_show_model)
	row.add_child(_select)
	row.add_child(_label("Girar", 14, Color("d9eaf0")))
	_angle = HSlider.new()
	_angle.min_value = -180
	_angle.max_value = 180
	_angle.step = 1
	_angle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_angle.value_changed.connect(_set_angle)
	row.add_child(_angle)
	_note = _label("", 14, Color("c0d7e3"))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(_note)
	controls.add_child(_label("1 / 2 / 3  ·  Cambiar modelo      Esc  ·  Salir", 12, Color("93adba")))


func _show_model(index: int) -> void:
	if index < 0 or index >= MODELS.size():
		return
	if _model != null:
		_pivot.remove_child(_model)
		_model.queue_free()
	_model = MODELS[index].instantiate() as Node3D
	_pivot.add_child(_model)
	_select.select(index)
	_angle.set_value_no_signal(0)
	_set_angle(0)
	_note.text = NOTES[index]


func _set_angle(degrees: float) -> void:
	_pivot.rotation.y = deg_to_rad(degrees)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _show_model(0)
			KEY_2: _show_model(1)
			KEY_3: _show_model(2)
			KEY_ESCAPE: get_tree().quit()


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142a37")
	style.set_corner_radius_all(13)
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		style.set_content_margin(side, 16)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		style.set_content_margin(side, 11)
	return style


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
