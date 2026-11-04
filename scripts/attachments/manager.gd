extends RefCounted
class_name GameAttachmentManager

var instances: Dictionary={}
var components: Dictionary={}
var copy_components: Dictionary={}
var markers: Node3D
var hidden_base: Dictionary={}
var configuration: Dictionary={}
var weapon:=""
var actor_ref: WeakRef

static func relative_transform(node: Node3D,root_node: Node3D) -> Transform3D:
	var result:=Transform3D.IDENTITY
	var cursor: Node=node
	while cursor and cursor!=root_node:
		if cursor is Node3D:result=cursor.transform*result
		cursor=cursor.get_parent()
	return result

static func _seat_supports(module: Node3D,bottoms: Dictionary) -> void:
	# Contact heights are prepared from the weapon geometry, not raycast at
	# equip time. Every observer and FPP copy receives the same fitted mesh.
	if bottoms.is_empty():return
	var contacts: Array=[]
	for label: String in bottoms:
		var foot:=module.get_node_or_null(label) as MeshInstance3D
		if not foot or not foot.visible or not foot.mesh is BoxMesh:continue
		var size: Vector3=foot.mesh.size
		var bottom:=float(bottoms[label])
		var top:=maxf(foot.position.y+size.y*.5,bottom+.008)
		foot.position.y=(top+bottom)*.5;foot.scale.y=(top-bottom)/size.y
		contacts.append({"foot":label,"bottom":bottom,"top":top})
	module.set_meta("support_contacts",contacts)

static func actor_configuration(actor: Node,weapon_id: String) -> Dictionary:
	var canonical: Variant=actor.get_meta("weapon_attachments",{})
	if canonical is Dictionary and canonical.has(weapon_id):
		var validated:=GameAttachmentState.validate(weapon_id,canonical[weapon_id])
		return validated.get("state",{}) if validated.get("ok",false) else {}
	var legacy: Variant=actor.get_meta("weapon_optics",{})
	return GameAttachmentState.from_legacy(weapon_id,str(legacy.get(weapon_id,""))) if legacy is Dictionary else {}

static func configure_model(module: Node3D,weapon_id: String,id: String,socket: GameAttachmentSocket=null) -> void:
	var definition:=GameAttachmentRegistry.definition(GameAttachmentRegistry.resolve_legacy(id,weapon_id))
	if not definition:return
	if not socket:
		var profile:=GameAttachmentRegistry.profile(weapon_id)
		if not profile:return
		for value: Resource in profile.sockets:
			var candidate:=value as GameAttachmentSocket
			if candidate and definition.category in candidate.categories:
				socket=candidate;break
	var fitting:=GameAttachmentRegistry.fitting(definition,socket)
	for name_text in fitting.get("hide",[]):
		var part:=module.get_node_or_null(str(name_text)) as Node3D
		if part:part.hide()
	for name_text in fitting.get("show",[]):
		var part:=module.get_node_or_null(str(name_text)) as Node3D
		if part:part.show()
	var extra_scene:=str(fitting.get("extra_scene",""));var extra_name:=str(fitting.get("extra_name","Adapter"))
	if not extra_scene.is_empty() and not module.has_node(extra_name):
		var packed:=load(extra_scene) as PackedScene
		if packed:
			var extra:=packed.instantiate();extra.name=extra_name;module.add_child(extra)
	module.set_meta("attachment_id",definition.id);module.set_meta("optic_id",definition.id);module.set_meta("weapon_id",weapon_id)
	_seat_supports(module,fitting.get("support_bottoms",{}))

static func aligned_transform(socket_transform: Transform3D,module: Node3D,definition: GameAttachmentDefinition) -> Transform3D:
	var reference:=module.get_node_or_null(definition.mount_reference) as Node3D
	var relative:=Transform3D.IDENTITY
	var cursor: Node=reference
	while cursor and cursor!=module:
		if cursor is Node3D:relative=cursor.transform*relative
		cursor=cursor.get_parent()
	return socket_transform*(relative.affine_inverse() if reference and cursor==module else Transform3D.IDENTITY)

func rebuild(actor: Node,weapon_id: String,raw: Dictionary) -> void:
	_rebuild(actor.weapon_root,weapon_id,raw,actor)

func rebuild_visual(weapon_root: Node3D,weapon_id: String,raw: Dictionary) -> void:
	_rebuild(weapon_root,weapon_id,raw,null)

func _rebuild(weapon_root: Node3D,weapon_id: String,raw: Dictionary,actor: Node=null) -> void:
	clear();actor_ref=weakref(actor) if actor else null;weapon=weapon_id
	var checked:=GameAttachmentState.validate(weapon,raw)
	if not checked.get("ok",false) or not is_instance_valid(weapon_root):return
	configuration=checked.state
	if configuration.is_empty():return
	GameAttachmentBehaviors.ensure_defaults()
	var model:=weapon_root.get_node_or_null("Imported_"+GameWeapons.canonical(weapon)) as Node3D
	if not model:model=weapon_root
	markers=Node3D.new();markers.name="AttachmentSockets";model.add_child(markers)
	var rest:=Transform3D(Basis(model.get_meta("rest_basis",model.basis)),Vector3(model.get_meta("rest_position",model.position))) if model!=weapon_root else Transform3D.IDENTITY
	var socket_map:=GameAttachmentState.sockets(weapon,configuration)
	for path: String in socket_map:
		if "/" in path:continue
		var socket: GameAttachmentSocket=socket_map[path]
		var marker:=Marker3D.new();marker.name=path;markers.add_child(marker);marker.transform=rest.affine_inverse()*socket.transform
	var paths:=configuration.keys();paths.sort_custom(func(a,b):return str(a).count("/")<str(b).count("/"))
	for path: String in paths:
		var entry: Dictionary=configuration[path];var definition:=GameAttachmentRegistry.definition(str(entry.id))
		if not definition or not definition.scene_reference:continue
		var base_path:=GameAttachmentState._base_path(path);var socket:=socket_map.get(base_path) as GameAttachmentSocket
		if not socket:continue
		var parent: Node3D;var target:=Transform3D.IDENTITY
		if "/" in path:
			var parent_path:=path.rsplit("/",true,1)[0];parent=instances.get(parent_path) as Node3D;target=socket.transform
		else:parent=markers.get_node_or_null(base_path) as Node3D
		if not parent:continue
		target.origin+=socket.rail_axis*float(entry.position)
		var module:=definition.scene_reference.instantiate() as Node3D
		if not module:continue
		parent.add_child(module);configure_model(module,weapon,definition.id,socket)
		module.transform=aligned_transform(target,module,definition)
		module.set_meta("attachment_socket",path);module.set_meta("attachment_state",entry.state.duplicate(true));module.set_meta("attachment_behavior",definition.behavior_type)
		instances[path]=module
		for base_name: String in socket.hide_base_when_occupied:
			var base:=model.get_node_or_null(base_name) as Node3D
			if base and not hidden_base.has(base):hidden_base[base]=base.visible;base.hide()
		var component:=GameAttachmentBehaviors.create(definition.behavior_type,{"actor":actor,"weapon":weapon,"node":module,"definition":definition,"state":entry.state,"first_person":false}) if actor else null
		if component:components[path]=component

func prepare_copy(actor: Node) -> void:
	for component: Object in copy_components.values():GameAttachmentBehaviors.release(component)
	copy_components.clear()
	if not is_instance_valid(actor.view_root):return
	for module: Node3D in actor.view_root.find_children("*","Node3D",true,false):
		if not module.has_meta("attachment_socket"):continue
		var path:=str(module.get_meta("attachment_socket"));var definition:=GameAttachmentRegistry.definition(str(module.get_meta("attachment_id","")))
		if not definition:continue
		var component:=GameAttachmentBehaviors.create(definition.behavior_type,{"actor":actor,"weapon":weapon,"node":module,"definition":definition,"state":module.get_meta("attachment_state",{}),"first_person":true})
		if component:copy_components[path]=component

func optical_record() -> Dictionary:
	var paths:=configuration.keys();paths.sort()
	for path: String in paths:
		var entry: Dictionary=configuration[path];var definition:=GameAttachmentRegistry.definition(str(entry.id))
		if definition and definition.behavior_type=="optical":return {"path":path,"entry":entry,"definition":definition,"node":instances.get(path)}
	return {}

func command(path: String,verb: String,data: Dictionary={}) -> bool:
	var component: Object=components.get(path)
	if not is_instance_valid(component) or not component.has_method("command"):return false
	component.call("command",verb,data.duplicate(true))
	var copy: Object=copy_components.get(path)
	if is_instance_valid(copy) and copy.has_method("command"):copy.call("command",verb,data.duplicate(true))
	return true

func clear() -> void:
	for group: Dictionary in [components,copy_components]:
		for component: Object in group.values():GameAttachmentBehaviors.release(component)
		group.clear()
	for base: Node3D in hidden_base:
		if is_instance_valid(base):base.visible=bool(hidden_base[base])
	hidden_base.clear()
	if is_instance_valid(markers):
		var parent:=markers.get_parent()
		if is_instance_valid(parent):parent.remove_child(markers)
		markers.queue_free()
	markers=null;instances.clear();configuration.clear()

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE:
		for group: Dictionary in [components,copy_components]:
			for component: Object in group.values():GameAttachmentBehaviors.release(component)
		if is_instance_valid(markers):markers.queue_free()
