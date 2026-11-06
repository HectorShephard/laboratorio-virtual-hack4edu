extends Node3D
## Mano articulada en un viewport 3D transparente. El centro de palma ES el punto de interacción.
const LINKS := [[0,1],[1,2],[2,3],[3,4],[0,5],[5,6],[6,7],[7,8],[5,9],[9,10],[10,11],[11,12],[9,13],[13,14],[14,15],[15,16],[13,17],[0,17],[17,18],[18,19],[19,20]]
var joints: Array[MeshInstance3D] = []
var bones: Array[MeshInstance3D] = []
var palm: MeshInstance3D
var ring: MeshInstance3D
var grip_link: MeshInstance3D
var object_link: MeshInstance3D
var material: StandardMaterial3D
var accent: StandardMaterial3D
var hand_id := 0
var last_landmarks: Array = []
var screen_anchor := Vector2.ZERO

func _ready() -> void:
	material = StandardMaterial3D.new()
	material.albedo_color = Color("efbc70") if hand_id==0 else Color("78cce4")
	material.roughness = .5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = .86
	accent = material.duplicate()
	accent.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in 21:
		var sphere := SphereMesh.new()
		sphere.radius = 4.0 if index in [4,8] else 3.0
		sphere.height = sphere.radius*2
		sphere.radial_segments=8
		sphere.rings=4
		joints.append(_mesh(sphere,material))
	for link in LINKS:
		bones.append(_cylinder(2.5))
	palm = _mesh(ImmediateMesh.new(),material)
	var torus := TorusMesh.new()
	torus.inner_radius = 18
	torus.outer_radius = 22
	torus.rings = 24
	torus.ring_segments = 8
	ring = _mesh(torus,accent)
	ring.rotation.x=PI/2
	grip_link = _cylinder(3)
	object_link = _cylinder(1.8)
	object_link.material_override=accent
	object_link.hide()
	hide()

func grip_target(screen: Vector2, holding: bool) -> void:
	object_link.visible=holding
	if holding:
		var relative:=screen-screen_anchor
		_link(object_link,Vector3(0,0,29),Vector3(relative.x,-relative.y,29))

func _mesh(shape: Mesh, skin: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh=shape
	instance.material_override=skin
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

func _cylinder(radius: float) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius=radius
	shape.bottom_radius=radius
	shape.height=1
	shape.radial_segments=8
	return _mesh(shape,material)

func _link(mesh: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	mesh.position=(a+b)/2
	mesh.scale=Vector3(1,maxf(.01,a.distance_to(b)),1)
	if a.distance_to(b)>.01: mesh.quaternion=Quaternion(Vector3.UP,(b-a).normalized())

func pose(packet: Dictionary, screen: Vector2, viewport_size: Vector2, holding: bool, paused: bool=false) -> void:
	var points: Array = packet.get("landmarks",[])
	if points.size()!=21:
		hide()
		return
	last_landmarks=points
	screen_anchor=screen
	position=Vector3(screen.x-viewport_size.x/2,viewport_size.y/2-screen.y,0)
	var center:=Vector3.ZERO
	for i in [0,5,9,13,17]: center+=Vector3(points[i][0],points[i][1],points[i][2])/5.0
	# Profundidad SOLO de la representación de dedos, nunca del objeto ni del banco.
	var width:=Vector2(points[5][0]-points[17][0],points[5][1]-points[17][1]).length()
	var scale_value:=clampf(65.0/maxf(.01,width),250,650)
	var coords: Array[Vector3]=[]
	for i in 21:
		var relative:=Vector3(points[i][0],points[i][1],points[i][2])-center
		coords.append(Vector3(relative.x*scale_value,-relative.y*scale_value,clampf(-relative.z*scale_value,-25,25)))
		joints[i].position=coords[i]
	for i in LINKS.size(): _link(bones[i],coords[LINKS[i][0]],coords[LINKS[i][1]])
	var surface:=palm.mesh as ImmediateMesh
	surface.clear_surfaces()
	surface.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var contour:=[0,1,5,9,13,17]
	for i in contour.size():
		surface.surface_set_normal(Vector3.BACK)
		surface.surface_add_vertex(Vector3(0,0,-2))
		surface.surface_add_vertex(coords[contour[i]])
		surface.surface_add_vertex(coords[contour[(i+1)%contour.size()]])
	surface.surface_end()
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.albedo_color.a=.25 if paused else .86
	ring.position=Vector3(0,0,30)
	ring.scale=Vector3.ONE*(1.35 if holding else 1.0)
	grip_link.visible=false
	_link(grip_link,coords[4],coords[8])
	show()
