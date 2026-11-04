extends SceneTree
const REG=preload("res://scripts/attachments/registry.gd")
const STATE=preload("res://scripts/attachments/state.gd")
var checks:=0
var failures: Array[String]=[]
class Lamp extends RefCounted:
	var target: Node3D
	var on:=false
	var dead:=false
	func _init(context: Dictionary) -> void:target=context.node;on=bool(context.state.get("on",false));target.set_meta("lamp_on",on)
	func command(verb: String,data: Dictionary) -> void:
		if verb=="switch":on=bool(data.get("on",false));target.set_meta("lamp_on",on)
	func dispose() -> void:dead=true;target=null
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func socket(id: String,category: String,interface_id: String) -> GameAttachmentSocket:
	var value:=GameAttachmentSocket.new();value.id=id;value.categories=PackedStringArray([category]);value.interfaces=PackedStringArray([interface_id]);return value
func definition(id: String,category: String,interface_id: String) -> GameAttachmentDefinition:
	var value:=GameAttachmentDefinition.new();value.id=id;value.display_name=id;value.category=category;value.required_interfaces=PackedStringArray([interface_id]);value.production=false;REG.register_definition(value);return value
func scene() -> PackedScene:
	var module:=Node3D.new();module.name="QAModule";var mount:=Marker3D.new();mount.name="MountReference";module.add_child(mount);mount.owner=module
	mount.transform=Transform3D(Basis.from_euler(Vector3(.21,-.35,.17)),Vector3(.025,-.04,.06))
	var visual:=MeshInstance3D.new();visual.mesh=BoxMesh.new();module.add_child(visual);visual.owner=module
	var packed:=PackedScene.new();packed.pack(module);module.free();return packed
func run() -> void:
	check(REG.ids()==["hensoldt4x","precision8x","prism4x","pso4x"],"all four production optics registered")
	for weapon in ["fal","ak","g3","sniper"]:
		for id in REG.ids():check(not STATE.from_legacy(weapon,id).is_empty(),"same interface accepts optic on "+weapon)
	check(STATE.from_legacy("glock","prism4x").is_empty(),"pistol without an optic mount rejects a scope")
	var original:=REG.profile("fal");var profile:=original.duplicate(true) as GameAttachmentProfile
	var side:=socket("arbitrary_side_name","light","qa_picatinny");side.transform=Transform3D(Basis.from_euler(Vector3(.4,.7,-.1)),Vector3(.2,.1,-.3));profile.sockets.append(side)
	var rail:=socket("long_rail","adapter","qa_picatinny");rail.allow_multiple=true;rail.rail_length=.4;profile.sockets.append(rail)
	var adapter_socket:=socket("receiver","adapter","qa_receiver");profile.sockets.append(adapter_socket);REG.register_profile(profile)
	var lamp:=definition("qa_lamp","light","qa_picatinny");lamp.scene_reference=scene();lamp.state_schema={"on":{"type":"bool","default":false}};lamp.behavior_type="qa_lamp";lamp.modifiers_percent={"recoil":-.15}
	var adapter:=definition("qa_adapter","adapter","qa_receiver");adapter.scene_reference=scene();var child:=socket("outlet","light","qa_picatinny");child.transform=Transform3D(Basis(Vector3.UP,.4),Vector3(.1,.05,0));adapter.provided_sockets.append(child)
	var short:=definition("qa_short_adapter","adapter","qa_picatinny");short.required_space=Vector3(.04,.04,.08)
	var cyclic:=socket("self","adapter","qa_receiver");adapter.provided_sockets.append(cyclic)
	var too_large:=definition("qa_big","light","qa_picatinny");too_large.required_space=Vector3(1,1,1)
	var configuration: Dictionary=STATE.install("fal",{},"receiver","qa_adapter").state
	check(not STATE.install("fal",configuration,"receiver/self","qa_adapter").get("ok",false),"adapter cannot recursively provide itself")
	configuration=STATE.install("fal",configuration,"receiver/outlet","qa_lamp",{"on":true}).state
	check(STATE.validate("fal",configuration).ok,"nested module state validates without weapon name special case")
	check(not STATE.can_install("fal",configuration,"arbitrary_side_name","qa_big").ok,"physical space enforced across arbitrary socket names")
	check(not STATE.valid_state("qa_lamp",{"on":1}) and not STATE.valid_state("qa_lamp",{"unknown":true}),"runtime state rejects wrong type and unknown fields")
	check(STATE.valid_state("qa_lamp",{}) and STATE.stateclean("qa_lamp",{}).on==false,"defaults are independent of optional supplied state")
	check(not STATE.validate("fal",{"arbitrary_side_name@forged":{"id":"qa_lamp","state":{},"position":0.}}).ok,"fake rail suffix cannot bypass single occupancy")
	var rail_state: Dictionary=STATE.install("fal",{},"long_rail","qa_short_adapter",{},-.12).state
	rail_state=STATE.install("fal",rail_state,"long_rail","qa_short_adapter",{},.12).state
	check(rail_state.size()==2 and STATE.validate("fal",rail_state).ok,"spaced modules can share one rail")
	check(not STATE.can_install("fal",rail_state,"long_rail","qa_short_adapter",.10).ok,"rail collisions reject overlapping footprint")
	var base:={"recoil":10.,"mag":20,"reload":6.,"name":"FAL"}
	for iteration in 50:
		check(is_equal_approx(float(STATE.effective(base,"fal",configuration).recoil),8.5),"modifiers recalculate from untouched base")
	check(base.recoil==10. and STATE.effective(base,"fal",{}).recoil==10.,"removal restores original attributes")
	var removed:=STATE.remove("fal",configuration,"receiver")
	check(removed.removed.size()==2 and removed.state.is_empty(),"adapter removal plans complete dependent subtree")
	GameAttachmentBehaviors.register_factory("qa_lamp",func(context: Dictionary):return Lamp.new(context))
	var game: WarGame=load("res://tests/war_optics_fixture.gd").new();root.add_child(game);await process_frame
	game.set_physics_process(false);game.vehicle_system.set_process(false)
	var actor:=game.local_player as WarPlayer;actor.set_physics_process(false);actor.set_process(false);actor.weapon_id="fal";actor._refresh_weapon()
	actor.set_meta("weapon_attachments",{"fal":configuration});actor.refresh_weapon_optics();actor._update_view()
	var manager: GameAttachmentManager=actor.weapon_optics.mounting
	check(manager.instances.size()==2 and manager.components.size()==1,"visual modules and registered behavior components instantiated only when equipped")
	var parent: Node3D=manager.instances.receiver;var parent_ref:=parent.get_node("MountReference") as Node3D
	var destination: Node3D=manager.markers.get_node("receiver")
	check(parent_ref.global_transform.is_equal_approx(destination.global_transform),"complete translated/rotated mount references align")
	var nested: Node3D=manager.instances["receiver/outlet"];var nested_ref:=nested.get_node("MountReference") as Node3D
	check(nested_ref.global_transform.is_equal_approx(parent.global_transform*child.transform),"nested mount uses parent module coordinate system")
	var component: Lamp=manager.components["receiver/outlet"]
	check(component.on and nested.get_meta("lamp_on",false),"registered component receives per-instance runtime state")
	check(manager.command("receiver/outlet","switch",{"on":false}) and not component.on,"new behavior handles command without editing firearm scripts")
	check(actor.view_root.find_children("*","Node3D",true,false).any(func(n):return n.has_meta("attachment_socket")),"FPP copy shares configuration with world model")
	actor.set_meta("weapon_attachments",{"fal":{}});actor.refresh_weapon_optics();actor._update_view()
	check(component.dead and manager.instances.is_empty() and manager.components.is_empty() and manager.copy_components.is_empty(),"removal disposes components commands and visuals")
	check(actor.weapon_spec("fal").recoil==CombatRules.weapon("fal").recoil,"live actor effective spec restores on removal")
	game.show_menu();game.queue_free();await create_timer(.3).timeout
	REG.register_profile(original)
	for id in ["qa_lamp","qa_adapter","qa_short_adapter","qa_big"]:REG.unregister_definition(id)
	GameAttachmentBehaviors.unregister_factory("qa_lamp")
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Generic Resource registry, arbitrary socket interfaces/categories, physical space/rail occupancy, cycles, nested removal, state validation, immutable stats, full 3D mount transforms, FPP/TPP and registered behavior lifecycle. Future modules are test-only definitions, not production loot."}
	NavalStorage.write_json("res://work/attachment-framework-validation.json",report);print("ATTACHMENT_FRAMEWORK ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
