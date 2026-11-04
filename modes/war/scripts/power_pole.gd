extends StaticBody3D
class_name WarPowerPole
const HEIGHT:=8.2
const BREAK_HEIGHT:=3.6
var pole_id:=""
var hp:=120.0
var broken:=false
var broken_at:=0.0
var fall_yaw:=0.0
var energized:=false
var functional:=true
var upper: Node3D
var lamp: OmniLight3D
var bulb: MeshInstance3D
var glow:=StandardMaterial3D.new()
var upper_collision: CollisionShape3D
func _ready() -> void:
	collision_layer=1;collision_mask=0;set_meta("war_pole",pole_id);set_meta("surface","metal")
	upper=Node3D.new();upper.name="BrokenUpper";upper.position.y=BREAK_HEIGHT;add_child(upper)
	shape_segment(self,BREAK_HEIGHT,Vector3(0,BREAK_HEIGHT*.5,0))
	upper_collision=shape_segment(self,HEIGHT-BREAK_HEIGHT,Vector3(0,BREAK_HEIGHT+(HEIGHT-BREAK_HEIGHT)*.5,0))
	if DisplayServer.get_name()=="headless": return
	var concrete:=StandardMaterial3D.new();concrete.albedo_color=Color("737c77");concrete.roughness=.67;concrete.metallic=.7
	var steel:=StandardMaterial3D.new();steel.albedo_color=Color("313c39")
	var base:=CylinderMesh.new();base.top_radius=.13;base.bottom_radius=.22;base.height=BREAK_HEIGHT;base.radial_segments=8
	mesh(self,"Stump",base,Vector3.UP*BREAK_HEIGHT*.5,concrete)
	var shaft:=CylinderMesh.new();shaft.top_radius=.09;shaft.bottom_radius=.13;shaft.height=HEIGHT-BREAK_HEIGHT;shaft.radial_segments=8
	mesh(upper,"UpperShaft",shaft,Vector3.UP*(HEIGHT-BREAK_HEIGHT)*.5,concrete)
	var arm:=BoxMesh.new();arm.size=Vector3(2,.12,.12);mesh(upper,"CrossArm",arm,Vector3(0,HEIGHT-BREAK_HEIGHT-.7,0),steel)
	var housing:=BoxMesh.new();housing.size=Vector3(.65,.16,.4);mesh(upper,"LampHousing",housing,Vector3(.75,HEIGHT-BREAK_HEIGHT-.9,0),steel)
	var lens:=BoxMesh.new();lens.size=Vector3(.5,.07,.3);bulb=mesh(upper,"LampLens",lens,Vector3(.75,HEIGHT-BREAK_HEIGHT-1,0),glow)
	glow.albedo_color=Color("b3aa86");glow.emission_enabled=true;glow.emission=Color("ffdda0");glow.emission_energy_multiplier=0
	lamp=OmniLight3D.new();lamp.name="NightLamp";lamp.position=Vector3(.75,HEIGHT-BREAK_HEIGHT-1.15,0);lamp.omni_range=25;lamp.omni_attenuation=1.1;lamp.light_color=Color("ffdfa7");lamp.light_energy=4.2;lamp.shadow_enabled=false;lamp.distance_fade_enabled=true;lamp.distance_fade_begin=80;lamp.distance_fade_length=20;lamp.hide();upper.add_child(lamp)
func shape_segment(parent: Node3D,height: float,point: Vector3) -> CollisionShape3D:
	var collider:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.20;shape.height=height;collider.shape=shape;collider.position=point;parent.add_child(collider);return collider
func mesh(parent: Node3D,label: String,shape: Mesh,point: Vector3,material: Material) -> MeshInstance3D:
	var result:=MeshInstance3D.new();result.name=label;result.mesh=shape;result.position=point;result.material_override=material;result.visibility_range_end=260;parent.add_child(result);return result
func damage(amount: float,direction: Vector3,clock: float) -> bool:
	if broken or not is_finite(amount) or amount<=0: return false
	hp=maxf(0,hp-amount)
	if hp>0: return false
	apply_break(clock,atan2(direction.x,direction.z) if Vector2(direction.x,direction.z).length()>.1 else float(pole_id.hash()%628)*.01)
	return true
func apply_break(clock: float,yaw: float) -> void:
	if broken: return
	broken=true;hp=0;broken_at=clock;fall_yaw=yaw;energized=false;set_lit(false)
func animate(clock: float) -> bool:
	if not broken: return false
	var progress:=clampf((clock-broken_at)/1.6,0,1)
	upper.rotation=Vector3(acos((.18-BREAK_HEIGHT)/(HEIGHT-BREAK_HEIGHT))*progress*progress,fall_yaw,0)
	upper_collision.transform=upper.transform*Transform3D(Basis.IDENTITY,Vector3.UP*(HEIGHT-BREAK_HEIGHT)*.5)
	return progress<1
func attachment() -> Vector3: return upper.to_global(Vector3(0,HEIGHT-BREAK_HEIGHT-.5,0))
func set_lit(value: bool) -> void:
	if not is_instance_valid(lamp): return
	var lit:=value and not broken and energized and functional
	if lamp.visible==lit: return
	lamp.visible=lit
	glow.emission_energy_multiplier=2.0 if lamp.visible else 0.0

