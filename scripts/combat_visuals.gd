extends Node3D
class_name GameCombatVisuals

# Visuals have no collision or damage authority. All physical shots still run.
const LIMIT:=256
var initial_pool:=12
var available: Array[Dictionary]=[]
var allocated:=0
var materials: Dictionary={}
var trail_materials: Dictionary={}
var sphere: SphereMesh
var cylinder: CylinderMesh
var outline_material: ShaderMaterial
var fx_available: Array[MeshInstance3D]=[]
var fx_active: Array[Dictionary]=[]
var fx_allocated:=0
var flash_material: ShaderMaterial
var smoke_material: ShaderMaterial
var blood_material: ShaderMaterial

func _ready() -> void:
	if DisplayServer.get_name()=="headless": return
	sphere=SphereMesh.new();sphere.radius=1;sphere.height=2;sphere.radial_segments=8;sphere.rings=3
	cylinder=CylinderMesh.new();cylinder.top_radius=1;cylinder.bottom_radius=1;cylinder.height=1;cylinder.radial_segments=6;cylinder.rings=1
	outline_material=ShaderMaterial.new();outline_material.shader=preload("res://shaders/projectile_trail.gdshader");outline_material.set_shader_parameter("tint",Color(.035,.05,.05,.6));outline_material.set_shader_parameter("energy",0.0)
	var shader:=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never; uniform vec4 tint: source_color; void fragment(){ float r=length(UV-vec2(.5))*2.; ALBEDO=tint.rgb; ALPHA=(1.-smoothstep(.2,1.,r))*tint.a; }"
	flash_material=ShaderMaterial.new();flash_material.shader=shader;flash_material.set_shader_parameter("tint",Color(.86,.44,.12,.65))
	smoke_material=ShaderMaterial.new();smoke_material.shader=shader;smoke_material.set_shader_parameter("tint",Color(.30,.34,.32,.20))
	blood_material=ShaderMaterial.new();blood_material.shader=shader;blood_material.set_shader_parameter("tint",Color(.55,.035,.025,.8))
	for index in initial_pool:
		var visual:=_new_projectile();available.append(visual)

func _material(color: Color,energy: float) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=color;material.emission_enabled=energy>0;material.emission=color;material.emission_energy_multiplier=energy
	return material

func _part(parent: Node3D,mesh: Mesh) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node);return node

func _new_projectile() -> Dictionary:
	var root:=Node3D.new();add_child(root);allocated+=1
	var quad:=QuadMesh.new();quad.size=Vector2.ONE
	var core:=_part(root,sphere);var trail:=_part(root,quad);var outline:=_part(root,quad)
	outline.material_override=outline_material;root.hide()
	return {"root":root,"node":core,"trace":trail,"outline":outline}

func acquire(weapon: String) -> Dictionary:
	weapon=GameWeapons.canonical(weapon)
	if DisplayServer.get_name()=="headless" or (available.is_empty() and allocated>=LIMIT): return {}
	var result: Dictionary=available.pop_back() if not available.is_empty() else _new_projectile()
	if not materials.has(weapon): materials[weapon]=_material(GameTracerStyle.color_for(weapon),GameTracerStyle.energy_for(weapon))
	if not trail_materials.has(weapon):
		var trail:=ShaderMaterial.new();trail.shader=preload("res://shaders/projectile_trail.gdshader");trail.set_shader_parameter("tint",GameTracerStyle.color_for(weapon));trail.set_shader_parameter("energy",GameTracerStyle.energy_for(weapon));trail_materials[weapon]=trail
	result.node.material_override=materials[weapon];result.trace.material_override=trail_materials[weapon];result.weapon=weapon
	result.root.show();result.node.show();result.trace.hide();result.outline.hide()
	return result

func release(visual: Dictionary) -> void:
	if visual.is_empty() or not is_instance_valid(visual.root): return
	visual.root.hide();available.append(visual)

func draw(visual: Dictionary,old: Vector3,point: Vector3,camera: Camera3D) -> void:
	if visual.is_empty(): return
	var radius:=GameTracerStyle.radius_for(point.distance_to(camera.global_position) if is_instance_valid(camera) else 0)
	if str(visual.get("weapon","")) in ["glock","ak","fal","g3"]: radius=GameTracerStyle.infantry_radius(camera,point)
	if str(visual.get("weapon",""))=="sniper": radius=GameTracerStyle.sniper_radius(camera,point)
	visual.node.global_position=point;visual.node.scale=Vector3.ONE*radius
	var eye_distance:=camera.global_position.distance_to(point) if is_instance_valid(camera) else 50.0
	var speed:=float(GameWeapons.ITEMS.get(str(visual.get("weapon","")),{}).get("speed",300))
	old=point-(point-old).limit_length(speed*(.012 if eye_distance<80 else .035))
	var movement:=point-old
	if movement.length_squared()<.000001: return
	var direction:=movement.normalized()
	var view: Vector3=(camera.global_position-old.lerp(point,.5)).normalized() if is_instance_valid(camera) else Vector3.RIGHT
	var side:=direction.cross(view).normalized()
	if side.length_squared()<.001: side=direction.cross(Vector3.RIGHT).normalized()
	var normal:=side.cross(direction).normalized()
	for part: MeshInstance3D in [visual.trace,visual.outline]:
		part.global_transform=Transform3D(Basis(side,direction,normal),old.lerp(point,.5)+normal*(radius*.08 if part==visual.trace else 0))
		part.scale=Vector3(radius*(3.3 if part==visual.outline else 1.7),movement.length(),1)
		part.show()

func _effect(point: Vector3,size: float,duration: float,smoke: bool,blood:=false) -> void:
	if DisplayServer.get_name()=="headless" or fx_active.size()>=64: return
	var node: MeshInstance3D
	if not fx_available.is_empty(): node=fx_available.pop_back()
	elif fx_allocated<64:
		node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);fx_allocated+=1
	else: return
	node.material_override=blood_material if blood else (smoke_material if smoke else flash_material)
	node.global_position=point;node.scale=Vector3.ONE*size;node.show()
	fx_active.append({"node":node,"left":duration,"total":duration,"size":size,"smoke":smoke})

func flash(point: Vector3) -> void:
	# A small sprite and bounded smoke replace a new light + dense sphere per shot.
	_effect(point,.16,.035,false)
	_effect(point,.12,.28,true)

func impact(point: Vector3,blood: bool) -> void:
	_effect(point,.14 if blood else .10,.16,true,blood)

func _process(delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	for index in range(fx_active.size()-1,-1,-1):
		var item: Dictionary=fx_active[index];item.left-=delta
		if item.left<=0:
			item.node.hide();fx_available.append(item.node);fx_active.remove_at(index);continue
		var progress: float=1-item.left/item.total
		item.node.scale=Vector3.ONE*item.size*(1+progress*2 if item.smoke else 1)
		if item.smoke: item.node.position.y+=delta*.16
		if is_instance_valid(camera): item.node.global_basis=camera.global_basis
