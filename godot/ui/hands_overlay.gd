extends CanvasLayer
## Un mundo 3D común, dos mallas independientes, sin capturar eventos del HUD.
var viewport: SubViewport
var camera: Camera3D
var texture: TextureRect
var hands: Array[Node3D] = []
func _ready() -> void:
	layer=40
	viewport=SubViewport.new()
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.position.z=400
	camera.near=.1
	camera.far=800
	viewport.add_child(camera)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-25,-20,0)
	light.light_energy=1.5
	viewport.add_child(light)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0,0,0,0)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.65
	viewport.add_child(environment)
	for id in 2:
		var hand:=preload("res://ui/hand_cursor_3d.gd").new()
		hand.hand_id=id
		viewport.add_child(hand)
		hands.append(hand)
	texture=TextureRect.new()
	texture.texture=viewport.get_texture()
	texture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(texture)
	_resize()
	get_viewport().size_changed.connect(_resize)
func _resize() -> void:
	var size:=get_viewport().get_visible_rect().size
	viewport.size=Vector2i(size)
	texture.size=size
	camera.size=size.y
