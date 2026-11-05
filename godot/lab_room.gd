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

func _cylinder(location: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 12
	mesh.mesh = cylinder
	mesh.material_override = _mat(color)
	add_child(mesh)
	mesh.position = location
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

func _flask(location: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .14
	sphere.height = .27
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh.mesh = sphere
	mesh.material_override = _mat(color)
	add_child(mesh)
	mesh.position = location + Vector3(0, .15, 0)
	_cylinder(location + Vector3(0, .35, 0), .055, .19, Color("c3e5ea"))

func _bench(location: Vector3, size: Vector2) -> void:
	_box(Vector3(size.x, .14, size.y), location, Color("496d78"), true)
	_box(Vector3(size.x - .12, .78, size.y - .12), location + Vector3(0, -.46, 0), Color("b3c9cd"), true)
	_box(Vector3(size.x + .02, .04, size.y + .02), location + Vector3(0, .09, 0), Color("dfebec"))

func _tile_material() -> StandardMaterial3D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	image.fill(Color("bfcbd0"))
	for index in range(64):
		image.set_pixel(index, 0, Color("94a7ae"))
		image.set_pixel(0, index, Color("94a7ae"))
	var material := _mat(Color.WHITE).duplicate() as StandardMaterial3D
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.uv1_scale = Vector3(14, 14, 1)
	return material

func _build() -> void:
	name = "CuartoDePruebas"
	var floor_mesh := _box(Vector3(14.2, .16, 13.8), Vector3(0, FLOOR_Y - .08, 0), Color.WHITE, true)
	floor_mesh.material_override = _tile_material()
	_box(Vector3(14.2, 4.2, .18), Vector3(0, .9, -6.8), Color("b1cbd1"), true)
	_box(Vector3(.18, 4.2, 13.8), Vector3(-7, .9, 0), Color("bad3d7"), true)
	_box(Vector3(.18, 4.2, 13.8), Vector3(7, .9, 0), Color("9cbfc8"), true)
	var front := _box(Vector3(14.2, 4.2, .18), Vector3(0, .9, 6.8), Color("b1cbd1"), true)
	front_meshes.append(front)
	front_meshes.append(_box(Vector3(14.2, .12, 13.8), Vector3(0, 3.06, 0), Color("dce8e9")))
	front_meshes.append(_box(Vector3(2.0, 2.65, .06), Vector3(0, .125, 6.68), Color("315c6a")))
	front_meshes.append(_box(Vector3(.7, 1.1, .035), Vector3(.35, .6, 6.63), Color("a1d6df"), false, true))
	front_meshes.append(_box(Vector3(.12, .045, .08), Vector3(-.7, .05, 6.6), Color("e9d5a4")))
	var entrance := _label("ENTRADA", Vector3(0, 1.68, 6.55), .006)
	entrance.rotation.y = PI
	front_meshes.append(entrance)
	# Zocalos y una franja de color organizan el cuarto sin texturas grandes.
	for x in [-6.88, 6.88]:
		_box(Vector3(.05, .18, 13.3), Vector3(x, -1.06, 0), Color("547e89"))
		_box(Vector3(.04, .08, 13.3), Vector3(x, .6, 0), Color("3aa69c"))
	_box(Vector3(13.6, .18, .05), Vector3(0, -1.06, -6.66), Color("547e89"))
	_box(Vector3(7.4, 1.2, .07), Vector3(0, 1.8, -6.65), Color("183d4b"))
	_label("LABORATORIO DE CIENCIAS", Vector3(0, 1.95, -6.58), .009)
	_label("OBSERVA  ·  EXPERIMENTA  ·  COMPRUEBA", Vector3(0, 1.52, -6.57), .0045, Color("71e1c6"))
	# Ventanas con material opaco claro: no requieren transparencias ni reflejos.
	for x in [-5.1, 5.1]:
		_box(Vector3(2.2, 1.65, .06), Vector3(x, 1.45, -6.61), Color("e1eff0"))
		_box(Vector3(2.02, 1.45, .035), Vector3(x, 1.45, -6.56), Color("91c8dc"), false, true)
		_box(Vector3(.055, 1.5, .045), Vector3(x, 1.45, -6.52), Color("e1eff0"))
		_box(Vector3(2.05, .055, .045), Vector3(x, 1.45, -6.51), Color("e1eff0"))
	for x in [-3.7, 0, 3.7]:
		_box(Vector3(2.4, .06, .5), Vector3(x, 2.88, -.8), Color("e8f6ef"), false, true)
	# Muebles laterales y material de ambientacion.
	_bench(Vector3(-5.7, -.12, -1.4), Vector2(1.25, 3.6))
	_bench(Vector3(5.7, -.12, -1.4), Vector2(1.25, 3.6))
	for z in [-2.5, -1.8, -.8]:
		_flask(Vector3(-5.7, 0, z), Color("61c7bd"))
		_cylinder(Vector3(-5.7, .18, z + .32), .13, .32, Color("b7e0e7"))
	# Pequeña maqueta de un pendulo y una placa de circuitos: aun decorativos.
	_box(Vector3(.7, .06, .55), Vector3(5.7, .02, -2.5), Color("284851"))
	_box(Vector3(.05, .8, .05), Vector3(5.45, .45, -2.5), Color("b6d5da"))
	_box(Vector3(.55, .05, .05), Vector3(5.7, .85, -2.5), Color("b6d5da"))
	_cylinder(Vector3(5.85, .55, -2.5), .012, .5, Color("45616b"))
	_flask(Vector3(5.85, .13, -2.5), Color("e9b965"))
	_box(Vector3(.95, .035, .7), Vector3(5.7, .025, -.6), Color("2b8275"))
	for x in [5.4, 5.7, 6.0]:
		_box(Vector3(.13, .07, .22), Vector3(x, .08, -.6), Color("d9bf87"))
	# Estanteria baja al fondo: deja despejada la franja superior del letrero.
	for y in [-.85, -.1, .65]:
		_box(Vector3(7.0, .08, .7), Vector3(0, y, -5.9), Color("4a727d"), true)
	for x in [-3.4, 3.4]:
		_box(Vector3(.1, 2.2, .7), Vector3(x, -.15, -5.9), Color("4a727d"), true)
	for x in [-2.6, -1.6, -.6, .6, 1.6, 2.6]:
		_box(Vector3(.38, .48, .43), Vector3(x, .19, -5.9), Color("6da7ae") if x < 0 else Color("e2bc7f"))
	var chemistry := _label("QUÍMICA\nZona en preparación", Vector3(-6.84, 1.55, -1.4), .005, Color("214e5b"))
	chemistry.rotation.y = PI / 2
	var physics := _label("FÍSICA Y ELECTRICIDAD\nZona en preparación", Vector3(6.84, 1.55, -1.4), .0045, Color("214e5b"))
	physics.rotation.y = -PI / 2
	# Referencia visual de la mesa de trabajo central.
	_box(Vector3(3.2, .6, .08), Vector3(0, -.54, 2.4), Color("285f6a"))
	_label("MESA DE PRUEBAS", Vector3(0, -.48, 2.46), .0045)
	_label("Acércate o pulsa E para trabajar", Vector3(0, -.72, 2.47), .0028, Color("8de6d0"))

func set_workbench_view(enabled: bool) -> void:
	for item in front_meshes:
		item.visible = not enabled
