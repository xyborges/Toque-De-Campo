extends SceneTree
## Physical walks through the authored doorway and up to interior loot.
## Uses the same capsule and motion controller as the actual player.
const MAP=preload("res://modes/battle_royale/map/afghan_map.gd")
const LIB:="res://modes/battle_royale/library/"
var world: Node3D
var failures: Array[String]=[]
var cases: Array[Dictionary]=[]

class Walker extends CharacterBody3D:
	var target:=Vector3.ZERO
	var walking:=false
	func _ready() -> void:
		floor_snap_length=.45;floor_constant_speed=true;floor_max_angle=deg_to_rad(45.)
		collision_layer=4;collision_mask=1
		var body:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.height=1.75;capsule.radius=.32
		body.shape=capsule;body.position.y=.875;add_child(body)
	func _physics_process(delta: float) -> void:
		var offset:=target-global_position;offset.y=0
		var wish:=offset.normalized() if walking and offset.length()>.13 else Vector3.ZERO
		velocity.x=wish.x*3.5;velocity.z=wish.z*3.5
		if not is_on_floor(): velocity.y-=9.81*delta
		GameStepMotion.move(self,delta)

func _initialize() -> void: run.call_deferred()

func walk(walker: Walker,target: Vector3,frames:=210,near:=.25) -> bool:
	walker.target=target;walker.walking=true
	for frame in frames:
		await physics_frame
		var offset:=walker.global_position-target
		if Vector2(offset.x,offset.z).length()<near and absf(offset.y)<.55:
			walker.walking=false;return true
	walker.walking=false;return false

func test_piece(piece: Node3D,id: String,descriptor: String) -> void:
	var door: Marker3D=piece.get_node("Entrance")
	var loot: Marker3D=piece.get_node("LootInterior")
	# Spawn outside with room for the capsule, cross the real front wall,
	# proceed through the courtyard for a qala, then approach interior loot.
	var before: Vector3=door.global_position+piece.global_basis.z.normalized()*2.0
	before.y=piece.global_position.y+.08
	var walker:=Walker.new();walker.position=before;world.add_child(walker)
	for frame in 4: await physics_frame
	var inner:=piece.to_global(Vector3(0,.20,0 if id!="qala_compound_v2" else 1.5))
	var interior_door:=piece.to_global(Vector3(0,.20,-4.1))
	var entry: bool=await walk(walker,inner)
	var inner_entry:=true
	if entry and id=="qala_compound_v2": inner_entry=await walk(walker,interior_door)
	var found: bool=await walk(walker,loot.global_position,210,.8) if entry and inner_entry else false
	var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(loot.global_position+Vector3.UP*.05,loot.global_position-Vector3.UP*.8,1))
	# The live authority validates eye-to-loot line of sight in addition to
	# range. Exercise the same collision mask and vertical offsets.
	var line:=PhysicsRayQueryParameters3D.create(walker.global_position+Vector3.UP*1.68,loot.global_position+Vector3.UP*.15,1,[walker.get_rid()])
	var occlusion:=world.get_world_3d().direct_space_state.intersect_ray(line)
	var row:={"scene":id,"placement":descriptor,"entrance":entry,"inner_entrance":inner_entry,"loot_reachable":found,"loot_has_floor":not hit.is_empty(),"line_clear":occlusion.is_empty(),"blocker":str(occlusion.get("collider","")),"loot":str(loot.global_position),"position":str(walker.global_position)}
	if not entry:
		row["local_stop"]=str(piece.to_local(walker.global_position))
		var collisions: Array=[]
		for i in walker.get_slide_collision_count():
			var collision:=walker.get_slide_collision(i);collisions.append({"body":str(collision.get_collider()),"normal":str(collision.get_normal())})
		row["collisions"]=collisions
		var body_query:=PhysicsShapeQueryParameters3D.new();var query_shape:=CapsuleShape3D.new();query_shape.height=1.75;query_shape.radius=.33
		body_query.shape=query_shape;body_query.transform.origin=walker.global_position+Vector3.UP*.9;body_query.collision_mask=1
		var blockers: Array=[]
		for contact: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(body_query,16):blockers.append(str(contact.collider))
		row["overlaps"]=blockers
	cases.append(row)
	if not entry or not inner_entry or not found or hit.is_empty() or not occlusion.is_empty(): failures.append(JSON.stringify(row))
	walker.free();await physics_frame

func run() -> void:
	world=Node3D.new();root.add_child(world)
	var ground:=StaticBody3D.new();ground.collision_layer=1;ground.collision_mask=0;world.add_child(ground)
	var floor_shape:=CollisionShape3D.new();var floor_box:=BoxShape3D.new();floor_box.size=Vector3(80,.2,80);floor_shape.shape=floor_box;floor_shape.position.y=1.9;ground.add_child(floor_shape)
	for id: String in MAP.BUILDINGS:
		for size: float in [.87,1.13]:
			var piece: Node3D=load(LIB+id+".tscn").instantiate();piece.position=Vector3(0,2,0);piece.rotation.y=.31;piece.scale=Vector3(size,1,size);world.add_child(piece)
			await physics_frame;await physics_frame
			await test_piece(piece,id,"prefab escala %.2f"%size)
			piece.free();await physics_frame
	ground.free();await physics_frame
	# Test each type at its actual procedural transform, sharing the same
	# colliders and terrain with server and visual clients.
	var map:=MAP.new();map.render_visuals=false;world.add_child(map);map.build()
	await physics_frame;await physics_frame
	var found_types: Dictionary={}
	for entry: Dictionary in MAP.building_layout():
		var id: String=MAP.BUILDINGS[int(entry.variant)]
		if found_types.has(id) and not "--all-houses" in OS.get_cmdline_user_args(): continue
		found_types[id]=true
		var closest: Node3D
		for child: Node in map.get_children():
			if child is Node3D and child.has_meta("library_id") and str(child.get_meta("library_id"))==id and child.position.distance_to(entry.position)<.1:
				closest=child;break
		if not closest:
			failures.append("Missing map instance "+id);continue
		await test_piece(closest,id,"mapa "+str(entry.position))
	var result:={"ok":failures.is_empty(),"cases":cases,"failures":failures,"all_map_houses":"--all-houses" in OS.get_cmdline_user_args(),"scope":"Five prefab types at two scales plus real map placements; --all-houses walks every placement. Physical capsule with GameStepMotion; doorway and reachability of LootInterior; no spawn correction or teleport."}
	NavalStorage.write_json("res://work/afghan-interiors-validation.json",result)
	print("AFGHAN_INTERIORS ",JSON.stringify(result))
	world.free();quit(0 if failures.is_empty() else 1)
