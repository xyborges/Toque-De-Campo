extends SubViewportContainer
class_name GameItemPreview
var view: SubViewport
var stage: Node3D
var holder: Node3D
var camera: Camera3D
var actor: GamePlayer
var subject := ""
var held_slot:="primary"
func _ready() -> void:
	stretch = true
	stretch_shrink = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	view = SubViewport.new()
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_2X
	view.gui_disable_input = true
	add_child(view)
	stage = Node3D.new()
	view.add_child(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = FieldTheme.BASE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.7
	env.ambient_light_color = Color("97aaa9")
	environment.environment = env
	stage.add_child(environment)
	for angles in [Vector3(-35,-25,0),Vector3(-15,150,0)]:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = angles
		sun.light_energy = 1.5
		stage.add_child(sun)
	camera = Camera3D.new()
	camera.fov = 36
	stage.add_child(camera)
	camera.make_current()
	resized.connect(_fit_camera)
	visibility_changed.connect(func():
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	)
func show_item(kind: String, values: Dictionary = {}) -> void:
	if not is_instance_valid(stage): return
	subject = kind
	if is_instance_valid(holder): holder.free()
	if is_instance_valid(actor): actor.free()
	holder = CharacterBody3D.new() if kind in NavalCatalog.SHIPS else Node3D.new()
	stage.add_child(holder)
	if kind=="person":
		actor = GamePlayer.new()
		actor.is_local=false
		actor.body_root = Node3D.new()
		holder.add_child(actor.body_root)
		actor.camera_pivot=Node3D.new();actor.camera_pivot.position.y=1.68;holder.add_child(actor.camera_pivot)
		actor._build_avatar()
		actor.apply_body_proportions({})
		actor.apply_body_colors(values.get("colors",{}))
		holder.rotation.y = -0.35
		camera.position = Vector3(0,1.1,-4.3)
		camera.look_at(Vector3(0,1,0))
	elif kind in NavalCatalog.SHIPS:
		NavalGeometry.ship_details(holder,kind)
		holder.rotation.y = 0.6
		var length: float = NavalCatalog.SHIPS[kind].length
		var aspect := maxf(0.35,size.x/maxf(1.0,size.y))
		var distance := length*0.65/(tan(deg_to_rad(18))*minf(1.0,aspect))
		camera.position = Vector3(0.65,0.45,-0.65).normalized()*distance
		camera.look_at(Vector3(0,0.5,0))
	else:
		actor = GamePlayer.new()
		actor.weapon_id = kind
		actor.weapon_root = holder
		actor._refresh_weapon()
		holder.rotation = Vector3(0.1,1.1,0)
		camera.position = Vector3(0,0.15,-2.4 if kind in ["broom","squeegee","axe"] else -1.15)
		camera.look_at(Vector3(0,0.1,0))
func _exit_tree() -> void:
	if is_instance_valid(actor): actor.free()

func _fit_camera() -> void:
	if not is_instance_valid(camera) or subject not in NavalCatalog.SHIPS: return
	var length: float = NavalCatalog.SHIPS[subject].length
	var aspect := maxf(0.25,size.x/maxf(1.0,size.y))
	var distance := length*0.75/(tan(deg_to_rad(18))*minf(1.0,aspect))
	camera.position = Vector3(0.65,0.45,-0.65).normalized()*distance
	camera.look_at(Vector3(0,0.5,0))
