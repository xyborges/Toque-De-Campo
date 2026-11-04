extends SubViewportContainer
class_name LoginBackdrop

var view: SubViewport
var camera: Camera3D
var elapsed:=0.
var camera_shift:=0.
var target_shift:=0.

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;stretch=true;stretch_shrink=2
	view=SubViewport.new();view.own_world_3d=true;view.gui_disable_input=true;view.msaa_3d=Viewport.MSAA_2X;add_child(view)
	var stage:=Node3D.new();view.add_child(stage);populate(stage)
	# The login uses the same human rig and helmet as gameplay. The former
	# hand-built 76 cm dome no longer matched the shared 30 cm human head.
	var actor:=GamePlayer.new();actor.body_root=Node3D.new();stage.add_child(actor.body_root)
	actor._build_avatar();WarUniform.apply(actor,0,"soldier")
	actor.body_root.position=Vector3(-.92,0,0);actor.body_root.rotation.y=-.14
	actor.weapon_root=Node3D.new();actor.body_root.add_child(actor.weapon_root);actor.weapon_id="ak";actor._refresh_weapon()
	actor.weapon_root.position=Vector3(.18,1.08,-.25);actor.weapon_root.rotation=Vector3(0,-.15,0)
	actor._pose_arm(actor.avatar_parts.arm_r,actor.body_root.to_global(Vector3(.22,1.02,-.32)),"armR")
	actor._pose_arm(actor.avatar_parts.arm_l,actor.body_root.to_global(Vector3(-.09,1.05,-.52)),"armL")
	actor.free()
	camera=Camera3D.new();stage.add_child(camera);camera.fov=45;camera.current=true;camera.far=120
	visibility_changed.connect(_visibility);_visibility();_process(0.)

# Shared menu-only trench scenery. It has no gameplay objects or physics.
# Both login and the interactive character background use this composition.
static func populate(stage: Node3D) -> void:
	var environment:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("414c4e")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("9eb2ba");env.ambient_light_energy=.55
	env.fog_enabled=true;env.fog_light_color=Color("66706a");env.fog_density=.019
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.environment=env;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-26,-48,0);sun.light_color=Color("e3d5b9");sun.light_energy=1.2;sun.shadow_enabled=true;stage.add_child(sun)
	var rim:=OmniLight3D.new();rim.position=Vector3(-2,3,1);rim.light_color=Color("94b9d3");rim.light_energy=1.3;rim.omni_range=9;stage.add_child(rim)
	var rng:=RandomNumberGenerator.new();rng.seed=74221
	box(stage,Vector3(0,-.20,15),Vector3(90,.4,110),Color("363b36"))
	for i in 22:
		var mound:=MeshInstance3D.new();var shape:=SphereMesh.new()
		shape.radius=rng.randf_range(2,6);shape.height=shape.radius*2;shape.radial_segments=12;shape.rings=5
		mound.mesh=shape;mound.position=Vector3(rng.randf_range(-30,30),-.1,rng.randf_range(7,65))-Vector3(0,shape.radius*.75,0)
		mound.scale=Vector3(1,.6,1.4);mound.material_override=material(Color("3c423a"));stage.add_child(mound)
	for i in 24:
		var tree:=Node3D.new();stage.add_child(tree);tree.position=Vector3(rng.randf_range(-24,24),0,rng.randf_range(7,52));tree.rotation.y=rng.randf_range(0,TAU)
		var height:=rng.randf_range(3,6)
		box(tree,Vector3(0,height*.5,0),Vector3(.14,height,.18),Color("242c2b")).rotation.z=rng.randf_range(-.18,.18)
		for branch in 3:
			box(tree,Vector3(0,height*(.4+branch*.15),0),Vector3(.09,1.5,.10),Color("242c2b")).rotation=Vector3(.3,branch*1.7,-.75 if branch%2==0 else .9)
	for side in [-1,1]:
		for i in 14:box(stage,Vector3(side*3.5,.38,3+i*.9),Vector3(1,.75,.30),Color("575947")).rotation.y=.14*side
	for i in 8:box(stage,Vector3(-5.5,.6,7+i*.48),Vector3(.2,1.2,.1),Color("3b3d34")).rotation.z=-.17
	box(stage,Vector3(8,1.15,24),Vector3(6,2.3,5),Color("3d4641"))
	box(stage,Vector3(8,2.5,24),Vector3(6.6,.4,5.7),Color("343b36"))
	box(stage,Vector3(8,1.5,21.45),Vector3(2.4,.35,.04),Color("141f22"))

static func material(color: Color,transparent:=false) -> StandardMaterial3D:
	var value:=StandardMaterial3D.new();value.albedo_color=color;value.roughness=.95
	if transparent:value.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	return value

static func box(parent: Node3D,at: Vector3,size_3d: Vector3,color: Color) -> MeshInstance3D:
	var item:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size_3d
	item.mesh=mesh;item.position=at;item.material_override=material(color);parent.add_child(item);return item

func _visibility() -> void:
	if not is_instance_valid(view):return
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	set_process(is_visible_in_tree())

func _process(delta: float) -> void:
	elapsed+=delta;camera_shift=move_toward(camera_shift,target_shift,delta*.15)
	camera.position=Vector3(1.45+camera_shift+sin(elapsed*.09)*.035,1.62,-3.8);camera.look_at(Vector3(0,1.07,0))

