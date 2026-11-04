extends SceneTree
const DEST:="res://modes/war/scenes/infraestrutura_190.tscn"
var layout: Node3D
var count:=0
func _initialize() -> void: run.call_deferred()
func group(label: String,point: Vector3,parent: Node3D=null) -> Node3D:
	if parent==null: parent=layout
	var node:=Node3D.new();node.name=label;node.position=point;parent.add_child(node);return node
func piece(id: String,parent: Node3D,point: Vector3,rotation_y:=0.) -> Node3D:
	var node:=load(WarPrefabFactory.PATH+id+".tscn").instantiate() as Node3D
	node.name=id.to_pascal_case()+str(count);count+=1;node.position=point;node.rotation.y=rotation_y;parent.add_child(node);return node
func road(parent: Node3D,a: Vector3,b: Vector3,id:="estrada_12m") -> Node3D:
	var node:=piece(id,parent,(a+b)*.5)
	node.basis=Basis.looking_at((b-a).normalized(),Vector3.UP)*Basis.from_scale(Vector3(1,1,a.distance_to(b)/12.))
	return node
func road_zone(parent: Node3D,point: Vector3,size: Vector2) -> void:
	var zone:=group("TrechoSubstituido",point,parent);zone.set_meta("replace_road",size)
func bases() -> void:
	for team in 2:
		var base:=group("AcessosBase"+str(team+1),WarRules.BASES[team]+Vector3.UP*.07)
		if team==1: base.rotation.y=PI
		for x in [6.,18.,30.,54.]: piece("estrada_12m",base,Vector3(x,0,0),-PI*.5)
		piece("estrada_cruzamento",base,Vector3(42,0,0),-PI*.5)
		road_zone(base,Vector3(30,0,0),Vector2(60,9))
		piece("estrada_12m",base,Vector3(42,0,12),PI)
		piece("estrada_rampa_12m",base,Vector3(42,0,24),PI)
		piece("cais_8m",base,Vector3(42,1.5,34))
		piece("container_20ft",base,Vector3(42,1.5,35))
		piece("estrada_curva_90",base,Vector3(42,0,-6))
		piece("estrada_12m",base,Vector3(60,0,-18),-PI*.5)
		piece("container_20ft",base,Vector3(64,0,-27),-PI*.5)
		for offset in [Vector3(81,0,35),Vector3(81,0,41),Vector3(81,0,47)]:
			var world:=base.to_global(offset);var height:=WarTerrain._base(world.x,world.z)
			piece("trincheira_escavavel_6m",layout,Vector3(world.x,height,world.z),PI if team==1 else 0.)
func village() -> void:
	var town:=group("VilarejoOeste",Vector3.ZERO)
	for row in 2:
		for col in 4:
			var at:=Vector2(-610+col*39-58,610+row*65-32)
			var lot:=group("Lote%02d"%(row*4+col),WarTerrain.point(at.x,at.y),town);lot.set_meta("replace_lot",true)
			piece("casa_ruina",lot,Vector3.ZERO,PI if row==0 else 0.)
			piece("barreira_concreto",lot,Vector3(8,0,0),PI*.5)
			if col%2==0:
				var tree_at:=Vector2(at.x-11,at.y-7)
				piece("arvore_queimada",town,WarTerrain.point(tree_at.x,tree_at.y))
	for i in 12:
		var ax: float=-680+i*12;var bx:=ax+12
		road(town,WarTerrain.point(ax,610)+Vector3.UP*.07,WarTerrain.point(bx,610)+Vector3.UP*.07,"estrada_cruzamento" if i==5 else "estrada_12m")
	road_zone(town,Vector3(-608,0,610),Vector2(144,15))
	for sign_value in [-1.,1.]:
		for i in 2:
			var a:=Vector2(-614,610+sign_value*(6+i*12));var b:=a+Vector2(0,sign_value*12)
			road(town,WarTerrain.point(a.x,a.y)+Vector3.UP*.07,WarTerrain.point(b.x,b.y)+Vector3.UP*.07)
func ports() -> void:
	for team in 2:
		var at: Vector3=WarCoast.PORTS[team];var side:= -1. if team==0 else 1.
		var port:=group("CaisModular"+str(team+1),at)
		for i in 4: piece("cais_8m",port,Vector3(side*(45+i*8),0,0))
		piece("cais_curva_90",port,Vector3(side*73,0,0),PI*.5 if team==0 else -PI*.5)
		var z_side:= -1. if team==0 else 1.
		for i in 2: piece("cais_8m",port,Vector3(side*85,0,z_side*(16+i*8)))
		piece("cais_rampa_8m",port,Vector3(side*85,-1.2,z_side*32),PI if team==0 else 0.)
		piece("cais_8m",port,Vector3(side*85,-1.2,z_side*40))
		piece("container_20ft",port,Vector3(side*45,0,1.3))
func own(node: Node) -> void:
	for child in node.get_children():
		child.owner=layout
		if child.scene_file_path.is_empty(): own(child)
func run() -> void:
	if FileAccess.file_exists(DEST) and not "--replace-generated" in OS.get_cmdline_user_args(): print("PRESERVED_EXISTING_INFRASTRUCTURE");quit();return
	layout=Node3D.new();layout.name="InfraestruturaModular";root.add_child(layout)
	bases();village();ports();own(layout)
	var packed:=PackedScene.new();assert(packed.pack(layout)==OK);assert(ResourceSaver.save(packed,DEST)==OK)
	print("INFRASTRUCTURE_READY objects=",count)
	layout.queue_free();await process_frame;await process_frame;quit()
