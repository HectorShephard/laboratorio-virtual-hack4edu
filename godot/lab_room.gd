extends Node3D

const FLOOR_Y := -1.2
var materials: Dictionary = {}
var front_meshes: Array[Node3D] = []

func _ready() -> void:
	_build()

func _mat(color: Color, unlit: bool = false) -> StandardMaterial3D:
	var key := str(color) + str(unlit)
	if materials.has(key):
		return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .8
	if unlit:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materials[key] = material
	return material

func _box(size: Vector3, location: Vector3, color: Color, solid: bool = false, unlit: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(color, unlit)
	add_child(mesh)
	mesh.position = location
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
		body.position = location
	return mesh

func _label(text: String, location: Vector3, scale_value: float = .009, color: Color = Color("e5f6f6")) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = scale_value
	label.modulate = color
	label.outline_size = 3
	label.no_depth_test = false
	add_child(label)
	label.position = location
	return label

func surface(color: Color, asset: String, repeat: float) -> StandardMaterial3D:
	var material := _mat(color).duplicate() as StandardMaterial3D
	var texture_path := "res://recursos/garaje/texturas/" + asset
	if ResourceLoader.exists(texture_path):
		material.albedo_texture = load(texture_path) as Texture2D
	elif FileAccess.file_exists(texture_path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(texture_path))
		if image != null and not image.is_empty():
			image.generate_mipmaps()
			material.albedo_texture = ImageTexture.create_from_image(image)
	if material.albedo_texture != null:
		material.albedo_color = Color.WHITE
		material.uv1_scale = Vector3(repeat, repeat, repeat)
	return material

func _build() -> void:
	name = "Garaje"
	var floor_mesh := _box(Vector3(14.2, .16, 13.8), Vector3(0, FLOOR_Y - .08, 0), Color.WHITE, true)
	floor_mesh.material_override = surface(Color("80796d"), "concreto_diff_1k.jpg", 6)
	for x in [-3.5, 3.5]:
		_box(Vector3(.019, .007, 13.3), Vector3(x, FLOOR_Y + .002, 0), Color("635e54"))
	for z in [-3.35, 3.35]:
		_box(Vector3(13.65, .007, .019), Vector3(0, FLOOR_Y + .002, z), Color("635e54"))
	_box(Vector3(14.2, 4.2, .18), Vector3(0, .9, -6.8), Color("a69b89"), true)
	for x in [-7.0, 7.0]:
		_box(Vector3(.18, 4.2, 13.8), Vector3(x, .9, 0), Color("b7ac98"), true)
		var inner_x: float = x * .98
		_box(Vector3(.09, .34, 13.3), Vector3(inner_x, -1.02, 0), Color("60594e"))
		for z in [-4.3, 0, 4.3]:
			_box(Vector3(.14, 4.12, .18), Vector3(inner_x, .87, z), Color("574f42"))
	front_meshes.append(_box(Vector3(14.2, 4.2, .18), Vector3(0, .9, 6.8), Color("9c9180"), true))
	front_meshes.append(_box(Vector3(14.2, .12, 13.8), Vector3(0, 3.06, 0), Color("8a8274")))
	_build_porton()
	for z in [-4.1, 0, 4.1]:
		front_meshes.append(_box(Vector3(13.8, .24, .18), Vector3(0, 2.79, z), Color("514a40")))
	for x in [-2.1, 2.1]:
		front_meshes.append(_box(Vector3(1.45, .11, .27), Vector3(x, 2.65, .98), Color("514b40")))
		front_meshes.append(_box(Vector3(1.27, .028, .17), Vector3(x, 2.582, .98), Color("fff0c9"), false, true))
	_build_storage()
	_build_tool_wall()
	_box(Vector3(3.6, 1.0, .06), Vector3(3.65, 1.43, -6.65), Color("373b35"))
	_label("BITÁCORA DEL TALLER", Vector3(3.65, 1.63, -6.60), .005, Color("f1d3a1"))
	_label("01  /  PREPARAR EL BANCO    ·    02  /  PROBAR", Vector3(3.65, 1.31, -6.59), .0027)

func _build_porton() -> void:
	front_meshes.append(_box(Vector3(5.56, 3.12, .18), Vector3(0, .34, 6.63), Color("494640")))
	for row in 13:
		var y := -1.02 + row * .218
		front_meshes.append(_box(Vector3(5.28, .20, .10), Vector3(0, y, 6.51), Color("817a6b")))
	for x in [-2.69, 2.69]:
		front_meshes.append(_box(Vector3(.13, 2.98, .16), Vector3(x, .25, 6.47), Color("635d51")))
	front_meshes.append(_box(Vector3(.38, .077, .13), Vector3(0, -.78, 6.38), Color("3b3934")))

func _build_storage() -> void:
	var center := Vector3(-4.35, 0, -5.93)
	for y in [-.92, -.18, .56, 1.29]:
		_box(Vector3(2.95, .09, .83), center + Vector3.UP * float(y), Color("625a4b"), true)
	for x in [-1.44, 1.44]:
		_box(Vector3(.09, 2.45, .83), center + Vector3(x, .03, 0), Color("504c43"), true)
	for x in [-.95, -.05, .87]:
		for y in [-.72, .02]:
			_box(Vector3(.64, .29, .57), center + Vector3(x, y, 0), Color("9c8057"))
			_box(Vector3(.23, .056, .012), center + Vector3(x, y + .04, .291), Color("dbcbad"))

func _build_tool_wall() -> void:
	_box(Vector3(4.05, 1.68, .09), Vector3(-.2, .99, -6.62), Color("5c4936"))
	var board := QuadMesh.new()
	board.size = Vector2(4.02, 1.65)
	var holes := Image.create(360, 150, false, Image.FORMAT_RGB8)
	holes.fill(Color("5c4936"))
	for x in range(14, 360, 19):
		for y in range(12, 150, 18):
			holes.fill_rect(Rect2i(x, y, 3, 3), Color("372d24"))
	var perforation := MeshInstance3D.new()
	perforation.mesh = board
	var board_material := _mat(Color.WHITE).duplicate() as StandardMaterial3D
	board_material.albedo_texture = ImageTexture.create_from_image(holes)
	perforation.material_override = board_material
	add_child(perforation)
	perforation.position = Vector3(-.2, .99, -6.569)
	for x in [-1.64, -1.04, -.44, .16, .76]:
		_box(Vector3(.10, .49, .09), Vector3(x, .95, -6.49), Color("aa7644"))
		_box(Vector3(.29, .11, .12), Vector3(x, 1.20, -6.48), Color("b0aa99"))
	_box(Vector3(.84, .13, .44), Vector3(1.17, .42, -6.44), Color("9b7651"))
	_label("HERRAMIENTAS", Vector3(-.27, 1.63, -6.55), .0039, Color("ead4ac"))

func set_workbench_view(enabled: bool) -> void:
	for item in front_meshes:
		item.visible = not enabled
