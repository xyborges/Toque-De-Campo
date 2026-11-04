extends SceneTree
## Uses the production stair controller with a player-sized capsule.
## No jump impulse, teleport correction, noclip or replacement ramp is used.
const LIB:="res://modes/battle_royale/library/"
var failures: Array[String]=[]
var cases: Array[Dictionary]=[]
var world: Node3D

class Walker extends CharacterBody3D:
	var target:=Vector3.ZERO
	var walking:=false
	var highest:=0.
	func _ready() -> void:
		floor_snap_length=.45;floor_constant_speed=true;floor_max_angle=deg_to_rad(45.)
		collision_layer=4;collision_mask=1
		var body:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.height=1.75;capsule.radius=.32
		body.shape=capsule;body.position.y=.875;add_child(body)
	func _physics_process(delta: float) -> void:
		var offset:=target-global_position;offset.y=0
		var wish:=offset.normalized() if walking and offset.length()>.08 else Vector3.ZERO
		velocity.x=wish.x*3.5;velocity.z=wish.z*3.5
		if not is_on_floor(): velocity.y-=9.81*delta
		GameStepMotion.move(self,delta)
		highest=maxf(highest,global_position.y)

func _initialize() -> void: run.call_deferred()

func walk(walker: Walker,target: Vector3,frames:=250) -> bool:
	walker.target=target;walker.walking=true
	for frame in frames:
		await physics_frame
		var offset:=walker.global_position-target
		if Vector2(offset.x,offset.z).length()<.18 and offset.y>=-.20:
			walker.walking=false;return true
	walker.walking=false;return false

func run() -> void:
	world=Node3D.new();root.add_child(world)
	var ground:=StaticBody3D.new();ground.collision_layer=1;ground.collision_mask=0;world.add_child(ground)
	var floor_shape:=CollisionShape3D.new();var floor_box:=BoxShape3D.new();floor_box.size=Vector3(80,.2,80);floor_shape.shape=floor_box;floor_shape.position.y=1.9;ground.add_child(floor_shape)
	for id in ["adobe_house_v2","farm_store_v2","qala_compound_v2","terrace_house_v2"]:
		if "--quick-stairs" in OS.get_cmdline_user_args() and id!="adobe_house_v2": continue
		for size: float in [.85,1.,1.15]:
			if "--quick-stairs" in OS.get_cmdline_user_args() and size!=1.: continue
			var building: Node3D=load(LIB+id+".tscn").instantiate();building.position=Vector3(0,2,0);building.scale=Vector3(size,1,size);world.add_child(building)
			await physics_frame;await physics_frame
			for prefix in ["Stair","UpperStair"]:
				if not building.get_node_or_null(prefix+"Foot"): continue
				var foot: Marker3D=building.get_node(prefix+"Foot")
				var turn: Marker3D=building.get_node(prefix+"Turn")
				var landing: Marker3D=building.get_node(prefix+"Landing")
				var walker:=Walker.new();walker.position=foot.global_position+Vector3.UP*.06;walker.highest=walker.position.y;world.add_child(walker)
				await physics_frame;await physics_frame;await physics_frame
				var ascent: bool=await walk(walker,turn.global_position)
				var arrival: bool=await walk(walker,landing.global_position,150) if ascent else false
				var entry:={"building":id,"scale_xz":size,"stair":prefix,"ascent":ascent,"arrival":arrival,"final":str(walker.global_position),"target":str(landing.global_position),"highest_y":walker.highest}
				cases.append(entry)
				if not ascent or not arrival: failures.append("%s %.2f %s %s"%[id,size,prefix,JSON.stringify(entry)])
				walker.free();await physics_frame
			building.free();await physics_frame
	var report:={"ok":failures.is_empty(),"cases":cases,"failures":failures,"controller":"GameStepMotion, speed3.5m/s, capsule1.75x.64m, no jump, xzscale.85/1/1.15"}
	NavalStorage.write_json("res://work/afghan-stair-validation.json",report);print("AFGHAN_STAIR_VALIDATION ",JSON.stringify(report))
	world.free();quit(0 if failures.is_empty() else 1)
