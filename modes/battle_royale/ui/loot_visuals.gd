extends Node3D
class_name BRLootVisuals

const LIMIT:=96
const RADIUS:=80.0
const AMMO=preload("res://modes/battle_royale/ui/equipment/ammo_box.tscn")
const HEAL=preload("res://modes/battle_royale/ui/equipment/medkit.tscn")
const BAG=preload("res://modes/battle_royale/ui/equipment/backpack.tscn")
var game: Node
var active: Dictionary={}
var pools: Dictionary={}
var models: Dictionary={}
var configurations: Dictionary={}
var module_ids: Dictionary={}
var created:=0
var pending: Dictionary={}
const CREATION_BUDGET_USEC:=1500
const CREATIONS_PER_FRAME:=2

func prepare() -> void:
	# Construct procedural weapons once during map loading; duplicates share
	# their meshes/materials. Never rebuild FAL geometry on a pickup snapshot.
	if DisplayServer.get_name()=="headless" and not bool(get_meta("test_visuals",false)): return
	for id in ["fal","glock"]:
		var model:=FALModel.create() if id=="fal" else GlockModel.create()
		var scene:=PackedScene.new()
		_own(model,model)
		scene.pack(model);models[id]=scene;model.free()
	for id in ["ak","sniper"]: models[id]=load("res://assets/weapons/%s.glb"%("ak_animated" if id=="ak" else id))
	for id in ["stinger","rpg"]:
		var model:=WarLauncherModels.build(id);var pieces: Array[Node]=[]
		for child in model.get_children():
			if child is MeshInstance3D:pieces.append(child)
		WarRenderBatch.merge(model,"br-loot-"+id,pieces)
		var scene:=PackedScene.new();_own(model,model);scene.pack(model);models[id]=scene;model.free()

func _own(node: Node,root_node: Node) -> void:
	for child in node.get_children(): child.owner=root_node;_own(child,root_node)

func _process(_delta: float) -> void:
	var start:=Time.get_ticks_usec();var count:=0
	for id: int in pending.keys():
		var record: Dictionary=pending[id]
		var node:=_acquire(_key(record));active[id]=node
		node.position=record.get("position",record.get("pos",Vector3.ZERO))+Vector3.UP*.025
		node.rotation.y=fmod(float(id)*2.39996,TAU);node.show();pending.erase(id)
		count+=1
		if count>=CREATIONS_PER_FRAME or Time.get_ticks_usec()-start>=CREATION_BUDGET_USEC:break

func _key(record: Dictionary) -> String:
	var kind:=str(record.get("kind",record.get("type","ammo")))
	if kind in ["vest","helmet","pack"]:return "%s:%d"%[kind,clampi(int(record.get("level",1)),1,3)]
	if kind in ["optic","attachment"]:
		var id:=str(record.get("attachment",record.get("optic","")));var key:="attachment:"+id;module_ids[key]=id;return key
	if kind=="weapon":
		var weapon:=str(record.get("weapon","glock"));var config: Dictionary=record.get("weapon_attachments",{})
		if config.is_empty() and not str(record.get("optic","")).is_empty():config=GameAttachmentState.from_legacy(weapon,str(record.optic))
		var key:="weapon:"+weapon+":"+str(hash(config));configurations[key]=config.duplicate(true);return key
	return kind

func update_visible(records: Array,viewer: Vector3) -> void:
	if DisplayServer.get_name()=="headless" and not bool(get_meta("test_visuals",false)): return
	var nearby: Array[Dictionary]=[]
	for raw: Variant in records:
		if not raw is Dictionary: continue
		var record: Dictionary=raw
		# A corpse is its own loot visual. A second bag would stay visible
		# even after its actual backpack had been removed from the body.
		if not str(record.get("corpse_key","")).is_empty():continue
		var point: Variant=record.get("position",record.get("pos",Vector3.INF))
		if not point is Vector3 or not point.is_finite(): continue
		if viewer.distance_squared_to(point)>RADIUS*RADIUS or bool(record.get("taken",false)) or not bool(record.get("active",true)): continue
		nearby.append(record)
	nearby.sort_custom(func(a: Dictionary,b: Dictionary): return viewer.distance_squared_to(a.get("position",a.get("pos",Vector3.ZERO)))<viewer.distance_squared_to(b.get("position",b.get("pos",Vector3.ZERO))))
	# The visual budget applies to distant loot only. Never hide an item
	# within pickup reach, even in an unusually crowded death/loot pile.
	var pickup_count:=0
	for record: Dictionary in nearby:
		var p: Vector3=record.get("position",record.get("pos",Vector3.ZERO))
		if viewer.distance_squared_to(p)>9.0:break
		pickup_count+=1
	var keep: Dictionary={}
	for index in mini(maxi(LIMIT,pickup_count),nearby.size()):
		keep[int(nearby[index].get("id",-1))]=nearby[index]
	pending.clear()
	for id: int in active.keys():
		if not keep.has(id) or str(active[id].get_meta("loot_key",""))!=_key(keep[id]):
			_release(active[id]);active.erase(id)
	for id: int in keep:
		var record: Dictionary=keep[id]
		var node: Node3D=active.get(id)
		if not is_instance_valid(node): pending[id]=record;continue
		node.position=record.get("position",record.get("pos",Vector3.ZERO))+Vector3.UP*.025
		node.rotation.y=fmod(float(id)*2.39996,TAU)
		node.show()

func _acquire(key: String) -> Node3D:
	var available: Array=pools.get(key,[])
	if not available.is_empty():
		var saved: Node3D=available.pop_back();pools[key]=available;return saved
	var result:=Node3D.new();result.set_meta("loot_key",key);add_child(result)
	var model: Node3D
	if key.begins_with("weapon:"):
		var id:=str(key.split(":")[1])
		model=Node3D.new();var base:=_weapon(id);base.name="Imported_"+id;model.add_child(base)
		var manager:=GameAttachmentManager.new();manager.rebuild_visual(model,id,configurations.get(key,{}));model.set_meta("attachment_manager",manager)
		model.rotation.z=PI*.5;model.position.y=.08
	elif key.begins_with("attachment:"):
		var definition:=GameAttachmentRegistry.definition(str(module_ids.get(key,key.trim_prefix("attachment:"))))
		if definition and definition.scene_reference:model=definition.scene_reference.instantiate()
		else:model=AMMO.instantiate()
		model.position.y=.055
	elif key.begins_with("vest:") or key.begins_with("helmet:") or key.begins_with("pack:"):
		var parts:=key.split(":")
		model=load("res://modes/battle_royale/ui/equipment/%s_%s.tscn"%[parts[0],parts[1]]).instantiate()
		model.rotation.x=PI*.5;model.position.y=.12
	elif key=="binoculars":model=preload("res://modes/war/equipment/binoculars.tscn").instantiate()
	elif key=="grenade":
		model=Node3D.new();var body:=MeshInstance3D.new();var capsule:=CapsuleMesh.new();capsule.radius=.055;capsule.height=.14;body.mesh=capsule;body.material_override=EnvironmentKit.material("metal:4f5743");model.add_child(body);model.position.y=.08
	else:
		model=(HEAL if key in ["heal","medkit"] else (BAG if key in ["container","backpack"] else AMMO)).instantiate()
	result.add_child(model)
	_clean_visual(result)
	created+=1
	return result

func _release(node: Node3D) -> void:
	node.hide()
	var key:=str(node.get_meta("loot_key","ammo"))
	var available: Array=pools.get(key,[]);available.append(node);pools[key]=available

func _weapon(id: String) -> Node3D:
	if id in ["fal","glock","stinger","rpg"] and models.has(id): return (models[id] as PackedScene).instantiate()
	if id=="fal": return FALModel.create()
	if id=="glock": return GlockModel.create()
	if id in ["ak","sniper"]:
		if not models.has(id): models[id]=load("res://assets/weapons/%s.glb"%("ak_animated" if id=="ak" else id))
		var packed: PackedScene=models[id]
		if packed:
			var imported:=packed.instantiate() as Node3D
			imported.rotation.y=PI*.5;imported.scale=Vector3.ONE*(1.1 if id=="ak" else 1.25)
			return imported
	var fallback:=Node3D.new()
	var box:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=Vector3(.08,.1,.8);box.mesh=shape;box.material_override=EnvironmentKit.material("metal:4c5545");fallback.add_child(box)
	return fallback

func _clean_visual(node: Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	if node is GeometryInstance3D: node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is CollisionObject3D: node.collision_layer=0;node.collision_mask=0
	for child: Node in node.get_children(): _clean_visual(child)

func clear() -> void:
	pending.clear()
	for node: Node3D in active.values(): _release(node)
	active.clear()
