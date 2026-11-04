extends RefCounted

const CATALOG=preload("res://scripts/optic_catalog.gd")
const LENS_SHADER=preload("res://shaders/scope4x.gdshader")

static func shader_for(definition: GameAttachmentDefinition) -> Shader:
	var path:=str(definition.behavior_parameters.get("reticle_shader",""))
	return load(path) as Shader if not path.is_empty() else LENS_SHADER
const PRESENTATION_LAYER:=1<<18
const LENS_RADIUS:=.032
var view: SubViewport
var camera: Camera3D
var lens: MeshInstance3D
var glass: ShaderMaterial
var active:=false
var world_scope: Node3D
var selected_optic:=""
var selected_weapon:=""
var mounting:=GameAttachmentManager.new()
var optical: Dictionary={}
var aim_weight:=0.0

func presented() -> bool:
	return aim_weight>0.0

func blend() -> float:
	return smoothstep(0.,1.,aim_weight)

func advance(actor: Node,delta: float) -> void:
	var allowed: bool=not optical.is_empty() and actor.hp>0 and actor.reload_left<=0 and not actor._grenade_active() and actor.vehicle_id.is_empty()
	if actor is WarPlayer:allowed=allowed and actor.deployed and actor.utility_mode.is_empty() and not actor.in_water()
	if not allowed and actor.iron_sights and not optical.is_empty():actor.aiming=false;actor.iron_sights=false
	var target:=1.0 if allowed and actor.iron_sights else 0.0
	var seconds:=.18
	if not optical.is_empty():seconds=maxf(.01,float(optical.definition.behavior_parameters.get("ads_seconds",.18)))
	var previous:=aim_weight
	aim_weight=move_toward(aim_weight,target,maxf(0.,delta)/seconds) if allowed else 0.0
	if not allowed:stop()
	if previous!=aim_weight and actor.is_local:actor._update_view()

func enabled(actor: Node) -> bool:
	var config:=GameAttachmentManager.actor_configuration(actor,str(actor.weapon_id))
	return not GameAttachmentState.legacy_optic(str(actor.weapon_id),config).is_empty()

func _attachment(actor: Node) -> String:
	return GameAttachmentState.legacy_optic(str(actor.weapon_id),GameAttachmentManager.actor_configuration(actor,str(actor.weapon_id)))

func mount_position(weapon: String,optic_id:="") -> Vector3:
	var config:=GameAttachmentState.from_legacy(weapon,optic_id if not optic_id.is_empty() else (selected_optic if selected_weapon==weapon else "scope4x"))
	if config.is_empty():return Vector3.ZERO
	var path: String=config.keys()[0];var socket: GameAttachmentSocket=GameAttachmentState.sockets(weapon,config)[path]
	var definition:=GameAttachmentRegistry.definition(str(config[path].id));var module:=definition.scene_reference.instantiate() as Node3D
	var transform:=GameAttachmentManager.aligned_transform(socket.transform,module,definition);module.free();return transform.origin

static func configure_model(scope: Node3D,weapon: String,optic_id: String) -> void:
	GameAttachmentManager.configure_model(scope,weapon,optic_id)

func aimed_offset(weapon: String) -> Vector3:
	# Eye alignment uses the complete socket × inverse(MountReference) × Eye
	# transform. The mount and observation point remain separate resources.
	if selected_weapon!=weapon or optical.is_empty():return Vector3.ZERO
	var module:=optical.get("node") as Node3D
	var actor: Node=mounting.actor_ref.get_ref() if mounting.actor_ref else null
	var definition:=optical.get("definition") as GameAttachmentDefinition
	if not module or not actor or not definition:return Vector3.ZERO
	var eye:=module.get_node_or_null(definition.eye_reference) as Node3D
	return -actor.weapon_root.to_local(eye.global_position) if eye else Vector3.ZERO

func refresh(actor: Node) -> void:
	aim_weight=0.0
	stop();world_scope=null;optical.clear();selected_weapon=str(actor.weapon_id)
	var config:=GameAttachmentManager.actor_configuration(actor,selected_weapon)
	mounting.rebuild(actor,selected_weapon,config);optical=mounting.optical_record()
	selected_optic=str(optical.get("entry",{}).get("id",""));world_scope=optical.get("node") as Node3D
	if is_instance_valid(world_scope):
		var definition:=optical.definition as GameAttachmentDefinition
		var surface:=world_scope.get_node_or_null(definition.reticle_reference) as MeshInstance3D
		if surface:
			var material:=ShaderMaterial.new();material.shader=shader_for(definition);surface.material_override=material
	if is_instance_valid(actor.view_root):actor.view_root.set_meta("weapon","")
	_ensure_view(actor)

func _ensure_view(actor: Node) -> void:
	if is_instance_valid(view) or optical.is_empty() or not actor.is_local or not actor.is_inside_tree() or DisplayServer.get_name()=="headless":return
	# Allocate the optical viewport while equipping/deploying, before aiming.
	var definition:=optical.definition as GameAttachmentDefinition
	view=SubViewport.new();view.name="OpticalLens4x";var resolution:=clampi(int(definition.behavior_parameters.get("viewport_size",384)),128,512);view.size=Vector2i(resolution,resolution)
	view.world_3d=actor.get_world_3d();view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	view.msaa_3d=Viewport.MSAA_DISABLED;view.gui_disable_input=true;view.audio_listener_enable_3d=false;actor.add_child(view)
	camera=Camera3D.new();camera.near=.08;camera.far=actor.camera.far;camera.cull_mask=actor.camera.cull_mask & ~PRESENTATION_LAYER;view.add_child(camera);camera.make_current()

func prepare_copy(actor: Node) -> void:
	if not is_instance_valid(actor.view_root):return
	for mesh: MeshInstance3D in actor.view_root.find_children("*","MeshInstance3D",true,false):mesh.layers=PRESENTATION_LAYER
	mounting.prepare_copy(actor)
	var scope:=_view_scope(actor)
	if not scope:return
	var definition:=optical.get("definition") as GameAttachmentDefinition
	if not definition:return
	var surface:=scope.get_node_or_null(definition.reticle_reference) as MeshInstance3D
	if not surface:return
	if surface.material_override is ShaderMaterial:surface.material_override=surface.material_override.duplicate()
	else:
		var material:=ShaderMaterial.new();material.shader=shader_for(definition);surface.material_override=material

func _view_scope(actor: Node) -> Node3D:
	if optical.is_empty() or not is_instance_valid(actor.view_root):return null
	for module: Node3D in actor.view_root.find_children("*","Node3D",true,false):
		if str(module.get_meta("attachment_socket",""))==str(optical.path):return module
	return null

func stop() -> void:
	active=false
	if is_instance_valid(view):view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if is_instance_valid(glass):glass.set_shader_parameter("live_view",false)

func update(actor: Node) -> void:
	var usable: bool=actor.is_local and actor.is_inside_tree() and not optical.is_empty() and actor.hp>0 and actor.iron_sights and aim_weight>=.999 and actor.reload_left<=0 and actor.vehicle_id.is_empty() and not actor._grenade_active()
	if actor is WarPlayer:usable=usable and actor.deployed and actor.vehicle_id.is_empty() and actor.utility_mode.is_empty() and not actor.in_water()
	if not usable or DisplayServer.get_name()=="headless" or not is_instance_valid(actor.view_root):stop();return
	var scope:=_view_scope(actor)
	if not is_instance_valid(scope) or not actor.view_root.is_visible_in_tree():stop();return
	var definition:=optical.definition as GameAttachmentDefinition
	var surface:=scope.get_node_or_null(definition.reticle_reference) as MeshInstance3D
	if not surface:stop();return
	_ensure_view(actor)
	if surface!=lens:
		if is_instance_valid(glass):glass.set_shader_parameter("live_view",false)
		lens=surface;glass=lens.material_override as ShaderMaterial;glass.set_shader_parameter("optical_view",view.get_texture())
	camera.global_transform=actor.camera.global_transform
	view.mesh_lod_threshold=maxf(.5,actor.get_viewport().mesh_lod_threshold*.5)
	var local_lens: Vector3=actor.camera.to_local(lens.global_position)
	var magnification:=maxf(1.,float(definition.behavior_parameters.get("magnification",1.)))
	var radius:=float(definition.behavior_parameters.get("lens_radius",LENS_RADIUS))
	camera.fov=rad_to_deg(2.*atan(radius/maxf(.04,-local_lens.z)/magnification))
	glass.set_shader_parameter("live_view",true);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;active=true
