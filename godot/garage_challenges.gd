extends Node3D

const TITLES := ["Mesa libre", "Biología · Disección virtual", "Química · Reacción y CO₂", "Física · Cohete de agua"]
const KITS := [
	"",
	"Bandeja, sapo exterior, bisturí, pinzas, tijeras y alfileres.",
	"Vaso, bicarbonato, vinagre, espátula y bandeja.",
	"Cohete, base de lanzamiento, agua y recipiente graduado.",
]
const SAPO := preload("res://recursos/modelos3d/sapo_exterior.tscn")
const QUIMICA := preload("res://recursos/modelos3d/instrumental_quimica.tscn")
const COHETE := preload("res://recursos/modelos3d/cohete_agua.tscn")
const ChemistryModel=preload("res://core/chemistry_model.gd")
const STEEL := Color("c3c4bb")
const HANDLE := Color("60413a")

var active := 0
var kit: Node3D
var bubbles: Array[MeshInstance3D] = []
var bubble_time := 0.0
var transfer := preload("res://core/transfer_state.gd").new()
var beaker: Node3D
var bottle: Node3D
var liquid_level: MeshInstance3D
var bottle_level: MeshInstance3D
var bottle_caption: Label3D
var stream: MeshInstance3D
var receiver_material: StandardMaterial3D
var receiving := false
var flowing := false
var alignment_assist := false
var powder: MeshInstance3D
var stream_fade := 0.0
var stop_once := false
const STREAM_FADE_SECONDS := .10

func _hand_bottle() -> bool:
	return bottle!=null and int(bottle.get_meta("last_hand_id",-1)) in [0,1]

func assist_target(object: Node3D, target: Vector3) -> Vector3:
	if active != 2 or object != bottle:
		return target
	var spout := target + bottle.global_basis * Vector3(0, .6, 0)
	var rim := beaker.to_global(Vector3(0, 1, 0))
	var correction := Vector3(rim.x - spout.x, 0, rim.z - spout.z)
	var translating := Vector2(target.x-object.global_position.x,target.z-object.global_position.z).length()>.003
	var hand_approach := _hand_bottle() and (translating or absf(rad_to_deg(bottle.rotation.z))>2)
	alignment_assist = correction.length() < .52 and spout.y > rim.y - .15 and (hand_approach or (not _hand_bottle() and absf(rad_to_deg(bottle.rotation.z)) > 25))
	if alignment_assist:
		# Sesgo pequeño sobre el destino, nunca un teletransporte ni movimiento acumulado.
		target += correction.limit_length(.10)
	return target

func start_bubbles() -> void:
	clear_bubbles()
	if active != 2:
		return
	bubble_time = 5.0
	for index in 24:
		var sphere := SphereMesh.new()
		sphere.radius = .025 + (index % 3) * .008
		sphere.height = sphere.radius * 2
		sphere.radial_segments = 8
		sphere.rings = 4
		bubbles.append(_mesh(sphere, Vector3.ZERO, Color("e9f4e6")))

func clear_bubbles() -> void:
	for bubble in bubbles:
		if is_instance_valid(bubble):
			bubble.queue_free()
	bubbles.clear()
	bubble_time = 0

func _process(delta: float) -> void:
	if active == 2:
		update_transfer(delta)
	if bubble_time <= 0:
		return
	bubble_time -= delta
	for index in bubbles.size():
		var phase := fposmod(5.0 - bubble_time + index * .137, 1.2) / 1.2
		bubbles[index].position = beaker.position + Vector3(sin(index * 2.4) * .23, .25 + phase * .72, cos(index * 2.4) * .23)
	if bubble_time <= 0:
		clear_bubbles()


func select(index: int) -> void:
	if index < 0 or index >= TITLES.size() or index == active:
		return
	clear_bubbles()
	if kit != null:
		remove_child(kit)
		kit.queue_free()
		kit = null
	active = index
	if index == 0:
		return
	kit = Node3D.new()
	kit.name = "EquipoDelReto"
	add_child(kit)
	match index:
		1: _biology()
		2: _chemistry()
		3: _physics()


func _biology() -> void:
	_tray(Vector3(-.44, 0, .25), Vector2(2.08, 1.92), Color("666b62"))
	_model(SAPO, Vector3(-.44, .05, .25), .47)
	_box(Vector3(1.17, .032, 1.65), Vector3(1.37, .021, .25), Color("aeb4a1"))
	# Bisturí, pinzas, tijeras y cuatro alfileres sobre el tapete.
	_box(Vector3(.12, .055, .43), Vector3(1.02, .059, .38), HANDLE)
	_box(Vector3(.075, .021, .25), Vector3(1.02, .067, .06), STEEL)
	for side in [-1, 1]:
		var forceps := _box(Vector3(.034, .035, .58), Vector3(1.36 + side * .04, .062, .23), STEEL)
		forceps.rotation.y = side * .075
		var blade := _box(Vector3(.04, .033, .37), Vector3(1.67 + side * .045, .066, .17), STEEL)
		blade.rotation.y = side * .21
		var ring := TorusMesh.new()
		ring.inner_radius = .056
		ring.outer_radius = .078
		ring.rings = 12
		ring.ring_segments = 6
		_mesh(ring, Vector3(1.67 + side * .082, .069, .40), HANDLE)
	for x in [1.00, 1.19, 1.38, 1.57]:
		_box(Vector3(.025, .024, .25), Vector3(x, .062, .79), STEEL)
		_box(Vector3(.061, .045, .061), Vector3(x, .073, .91), Color("a95743"))


func _chemistry() -> void:
	var model := QUIMICA.instantiate() as Node3D
	kit.add_child(model)
	model.position = Vector3(-.37, 0, .19)
	model.scale = Vector3.ONE * .57
	beaker = Node3D.new()
	beaker.name = "Vaso"
	beaker.set_meta("kind", "beaker")
	kit.add_child(beaker)
	beaker.position = Vector3(-.7975, 0, .19)
	for part_name in ["Vaso", "BordeDelVaso", "Liquido", "Marca1", "Marca2", "Marca3", "Marca4", "Marca5"]:
		model.get_node(part_name).reparent(beaker, true)
	liquid_level = beaker.get_node("Liquido")
	powder = MeshInstance3D.new()
	beaker.add_child(powder)
	var powder_mesh := CylinderMesh.new()
	powder_mesh.top_radius = .22
	powder_mesh.bottom_radius = .22
	powder_mesh.height = .035
	powder.mesh = powder_mesh
	var powder_material := StandardMaterial3D.new()
	powder_material.albedo_color = Color("eee5d2")
	powder.material_override = powder_material
	powder.position.y = .13
	powder.visible = false
	_draggable(beaker, Vector3(.72, 1.0, .72), Vector3(0, .5, 0))
	receiver_material = StandardMaterial3D.new()
	receiver_material.albedo_color = Color("e5ae58")
	receiver_material.emission_enabled = true
	receiver_material.emission = Color("e5ae58")
	var spatula := Node3D.new()
	spatula.name = "Espatula"
	spatula.set_meta("kind","spatula")
	kit.add_child(spatula)
	spatula.position = Vector3(.2, .16, -.22)
	for part_name in ["MangoEspatula", "CucharaEspatula"]:
		model.get_node(part_name).reparent(spatula, true)
	_draggable(spatula, Vector3(.9, .18, .3), Vector3.ZERO)
	var before := kit.get_child_count()
	_container(Vector3(1.40, 0, .22), Color("704d3a"), "VINAGRE")
	bottle = Node3D.new()
	bottle.name = "FrascoVinagre"
	bottle.set_meta("kind", "bottle")
	var parts := kit.get_children().slice(before)
	kit.add_child(bottle)
	bottle.position = Vector3(1.4, 0, .22)
	for part in parts:
		part.reparent(bottle, true)
		if part is Label3D:
			bottle_caption = part
		if part is MeshInstance3D and part.mesh is CylinderMesh:
			var glass := part.material_override.duplicate() as StandardMaterial3D
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.albedo_color = Color(.65, .8, .83, .28)
			part.material_override = glass
	bottle_level = MeshInstance3D.new()
	bottle.add_child(bottle_level)
	var fluid := CylinderMesh.new()
	fluid.top_radius = .135
	fluid.bottom_radius = .135
	fluid.height = 1
	bottle_level.mesh = fluid
	bottle_level.material_override = _mat_liquid()
	_draggable(bottle, Vector3(.4, .62, .4), Vector3(0, .31, 0))
	_tray(Vector3(1.45, 0, -.79), Vector2(.82, .58), Color("767266"))
	stream = MeshInstance3D.new()
	kit.add_child(stream)
	var jet := CylinderMesh.new()
	jet.top_radius = .018
	jet.bottom_radius = .025
	jet.height = 1
	stream.mesh = jet
	stream.material_override = _mat_liquid()
	configure_transfer(ChemistryModel.INPUTS.initial_ml.default,ChemistryModel.INPUTS.capacity_ml.default,"vinagre",ChemistryModel.INPUTS.concentration.default)
	transfer.enabled = false

func _mat_liquid() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("66d9d1")
	material.roughness = .25
	return material

func configure_transfer(amount: float, capacity: float, kind: String, strength: float) -> void:
	transfer.configure(amount, capacity, kind, strength)
	stream_fade=0
	stop_once=false
	bottle.rotation = Vector3.ZERO
	bottle.position = Vector3(1.4, 0, .22)
	beaker.position = Vector3(-.7975, 0, .19)
	powder.visible = false
	for object in [beaker,bottle]:
		object.set_meta("last_hand_id",-1)
		object.set_meta("last_hand_label","")
		object.set_meta("control_age",0.0)
		object.set_meta("control_unique",false)
		object.set_meta("control_paused",false)
	bottle_caption.text = "ALCOHOL" if kind == "alcohol" else "VINAGRE"
	update_transfer(0)

func update_transfer(delta: float) -> void:
	var spout := bottle.to_global(Vector3(0, .6, 0))
	var rim := beaker.to_global(Vector3(0, 1.0, 0))
	var to_center := Vector2(rim.x - spout.x, rim.z - spout.z)
	var distance := to_center.length()
	var axis := bottle.global_basis.y
	var direction := Vector2(axis.x, axis.z)
	var aims_inside := distance < .10 or (direction.length() > .01 and direction.normalized().dot(to_center.normalized()) > .15)
	# Con la inclinación corta basta que el pico esté sobre el interior del vaso.
	if _hand_bottle(): aims_inside=true
	var radius := .38 if transfer.pouring else .30
	var lower := -.08 if transfer.pouring else -.02
	var aligned := distance < radius and spout.y >= rim.y + lower and spout.y < rim.y + 1.2 and aims_inside
	receiving = (aligned or (distance < .52 and spout.y > rim.y - .15)) and transfer.poured_ml < transfer.capacity_ml and transfer.remaining_ml > 0
	var paused := bool(bottle.get_meta("control_paused",false)) or bool(beaker.get_meta("control_paused",false))
	var age:=float(bottle.get_meta("control_age",0)) if _hand_bottle() else 0.0
	if bool(beaker.get_meta("held",false)):age=maxf(age,float(beaker.get_meta("control_age",0)))
	var amount := transfer.advance(delta, bool(bottle.get_meta("held", false)) and not stop_once, aligned, rad_to_deg(bottle.rotation.z),_hand_bottle(),not paused,age,bool(bottle.get_meta("control_unique",true)))
	stop_once=false
	flowing = amount > 0
	if flowing:
		stream_fade=STREAM_FADE_SECONDS
		stream.visible=true
		stream.transparency=0
		stream.global_position = (spout + rim) / 2
		stream.scale = Vector3(1, spout.distance_to(rim), 1)
		if spout.distance_to(rim) > .01:
			stream.quaternion = Quaternion(Vector3.UP, (spout - rim).normalized())
	else:
		stream_fade=maxf(0,stream_fade-delta)
		stream.visible=stream_fade>0
		stream.transparency=1.0-stream_fade/STREAM_FADE_SECONDS
	beaker.get_node("BordeDelVaso").material_overlay = receiver_material if receiving else null
	var height := .82 * transfer.poured_ml / transfer.capacity_ml
	liquid_level.visible = height > .001
	liquid_level.scale.y = maxf(.001, height / .63)
	liquid_level.position.y = .1 + height / 2
	var bottle_height := .46 * transfer.remaining_ml / transfer.initial_ml
	bottle_level.visible = bottle_height > .001
	bottle_level.scale.y = maxf(.001, bottle_height)
	bottle_level.position.y = .02 + bottle_height / 2

func stop_emission() -> void:
	transfer.pouring=false
	flowing=false
	stop_once=true
	# El tramo visual ya emitido se desvanece sin transferir volumen adicional.

func _draggable(object: Node3D, size: Vector3, center: Vector3) -> void:
	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 0
	area.monitoring = false
	object.add_child(area)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center
	area.add_child(collision)


func _physics() -> void:
	_model(COHETE, Vector3(-.58, 0, .06), .63)
	_container(Vector3(.79, 0, -.13), Color("837f64"), "AGUA")
	_container(Vector3(1.35, 0, .30), Color("9eab9c"), "MEDIDA")
	for y in [.21, .29, .37, .45]:
		_box(Vector3(.10, .014, .013), Vector3(1.44, y, .446), Color("eee6d7"))


func _tray(position_value: Vector3, size: Vector2, color: Color) -> void:
	_box(Vector3(size.x, .05, size.y), position_value + Vector3.UP * .025, color)
	for side in [-1, 1]:
		_box(Vector3(size.x, .13, .045), position_value + Vector3(0, .065, side * size.y / 2), color)
		_box(Vector3(.045, .13, size.y), position_value + Vector3(side * size.x / 2, .065, 0), color)


func _container(position_value: Vector3, color: Color, caption: String) -> void:
	var body := CylinderMesh.new()
	body.top_radius = .15
	body.bottom_radius = .16
	body.height = .52
	body.radial_segments = 16
	_mesh(body, position_value + Vector3.UP * .26, color)
	_box(Vector3(.18, .07, .18), position_value + Vector3.UP * .55, Color("4d4940"))
	var label := Label3D.new()
	label.text = caption
	label.pixel_size = .0034
	label.font_size = 14
	label.position = position_value + Vector3(0, .29, .158)
	kit.add_child(label)


func _model(scene: PackedScene, position_value: Vector3, size: float) -> void:
	var model := scene.instantiate() as Node3D
	model.position = position_value
	model.scale = Vector3.ONE * size
	kit.add_child(model)


func _box(size: Vector3, position_value: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(mesh, position_value, color)


func _mesh(mesh: Mesh, position_value: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .62
	part.mesh = mesh
	part.material_override = material
	part.position = position_value
	kit.add_child(part)
	return part
