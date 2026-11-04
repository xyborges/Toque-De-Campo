extends Node3D
class_name NavalProjectileVisual
# A tracer is attached to its authoritative projectile, never a second bullet.
static var core_materials: Dictionary = {}
static var glow_materials: Dictionary = {}
var core: MeshInstance3D
var glow: MeshInstance3D
var tip: MeshInstance3D
var body: Node3D
var surface_wake: MeshInstance3D
var weapon := ""

func build() -> void:
	core = NavalGeometry.cylinder(self,"TraceCore",Vector3.ZERO,1.0,1.0,Color.WHITE)
	glow = NavalGeometry.cylinder(self,"TraceGlow",Vector3.ZERO,1.0,1.0,Color.WHITE)
	for part in [core,glow]:
		part.mesh.radial_segments = 6
		part.rotation.x = PI/2
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tip = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	tip.mesh = sphere
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tip)
	body = Node3D.new()
	add_child(body)
	var casing := NavalGeometry.cylinder(body,"Casing",Vector3.ZERO,0.16,1.6,Color("b8c7ba"),0.04)
	casing.rotation.x = PI/2
	NavalGeometry.box(body,"Fins",Vector3(0,0,0.4),Vector3(0.7,0.06,0.35),Color("687f7b"))
	surface_wake = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.8,5.0)
	surface_wake.mesh = plane
	surface_wake.material_override = NavalGeometry.material(Color("d7fbf1"))
	surface_wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface_wake)

func setup(id: String) -> void:
	weapon = id
	if not core_materials.has(id):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = GameTracerStyle.color_for(id)
		material.emission_enabled = true
		material.emission = GameTracerStyle.color_for(id)
		material.emission_energy_multiplier = GameTracerStyle.ENERGY
		core_materials[id] = material
		var halo := material.duplicate() as StandardMaterial3D
		halo.emission_enabled=false
		halo.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		halo.albedo_color = Color("182a2a")
		halo.albedo_color.a = 0.4
		glow_materials[id] = halo
	core.material_override = core_materials[id]
	tip.material_override = core_materials[id]
	glow.material_override = glow_materials[id]
	body.visible = id in ["missile","torpedo"]
	surface_wake.visible = id == "torpedo"
	visible = true

func update_shot(shot: Dictionary, age: float, camera_position: Vector3) -> void:
	var point := NavalBallistics.position(shot.origin,shot.velocity,shot.gravity,age,weapon,shot.time)
	var back := NavalBallistics.position(shot.origin,shot.velocity,shot.gravity,maxf(0.0,age-0.024),weapon,shot.time)
	var length := maxf(0.05,point.distance_to(back))
	global_position = point
	var velocity: Vector3 = NavalBallistics.instantaneous_velocity(shot.velocity,float(shot.gravity),age,weapon)
	if velocity.length_squared()>0.001: look_at(point+velocity.normalized())
	var radius := clampf(point.distance_to(camera_position)*0.00065,0.045,0.45)
	if weapon in ["missile","torpedo"]: radius = maxf(radius,0.09)
	# Positive local Z is behind the projectile because its forward is -Z.
	for part in [core,glow]:
		part.position = Vector3(0,0,length*0.5)
		part.scale = Vector3(radius,length,radius)*(Vector3(1.8,1,1.8) if part == glow else Vector3.ONE)
	tip.scale = Vector3.ONE*radius*1.5
	if weapon == "torpedo":
		surface_wake.global_position = Vector3(point.x,NavalCatalog.wave(point,shot.time+age)+0.08,point.z)
		surface_wake.global_rotation = Vector3(0,global_rotation.y,0)
