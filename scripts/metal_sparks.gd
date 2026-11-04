extends Node3D
class_name GameMetalSparks
const LIMIT:=128
var particles: Array[Dictionary]=[]
var pool: MultiMesh
var cursor:=0
func _ready() -> void:
	if DisplayServer.get_name()=="headless": set_process(false);return
	for index in LIMIT: particles.append({})
	var mesh:=BoxMesh.new();mesh.size=Vector3(.025,.025,.13)
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.vertex_color_use_as_albedo=true;mat.emission_enabled=true;mat.emission=Color(1,.48,.06);mat.emission_energy_multiplier=1.4
	mesh.material=mat;pool=MultiMesh.new();pool.transform_format=MultiMesh.TRANSFORM_3D;pool.use_colors=true;pool.mesh=mesh;pool.instance_count=LIMIT;pool.visible_instance_count=0
	var view:=MultiMeshInstance3D.new();view.multimesh=pool;view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;view.custom_aabb=AABB(Vector3(-2100,-100,-2100),Vector3(4200,500,4200));add_child(view)
func burst(point: Vector3,normal: Vector3,event: String) -> void:
	if pool==null: return
	var camera:=get_viewport().get_camera_3d()
	if camera and camera.global_position.distance_to(point)>450: return
	var rng:=RandomNumberGenerator.new();rng.seed=hash(event)
	for index in 8:
		var velocity: Vector3=(normal.normalized()*rng.randf_range(2,5)+Vector3(rng.randf_range(-2,2),rng.randf_range(.2,3),rng.randf_range(-2,2)))
		particles[cursor]={"point":point+normal*.04,"velocity":velocity,"life":rng.randf_range(.18,.4)};cursor=(cursor+1)%LIMIT
func _process(delta: float) -> void:
	var count:=0
	for p in particles:
		if p.is_empty(): continue
		p.life=float(p.life)-delta
		if float(p.life)<=0: p.clear();continue
		p.velocity+=Vector3.DOWN*10*delta;p.point+=p.velocity*delta
		var basis:=Basis.looking_at(Vector3(p.velocity).normalized(),Vector3.UP)
		pool.set_instance_transform(count,Transform3D(basis,p.point));pool.set_instance_color(count,Color(1,.65,.18));count+=1
	pool.visible_instance_count=count
