extends SceneTree
const DEST:="res://modes/war/scenes/detalhamento_190.tscn"
var layout: Node3D
var count:=0
func _initialize() -> void: run.call_deferred()
func piece(id: String,p: Vector3,yaw:=0.) -> Node3D:
	var node:=load(WarPrefabFactory.PATH+id+".tscn").instantiate() as Node3D
	node.name=id.to_pascal_case()+str(count);count+=1;node.position=p;node.rotation.y=yaw;layout.add_child(node);node.owner=layout;return node
func grounded(id: String,p: Vector2,yaw:=0.) -> Node3D: return piece(id,WarTerrain.point(p.x,p.y),yaw)
func ports() -> void:
	for team in 2:
		var port: Vector3=WarCoast.PORTS[team];var land:=1. if team==0 else -1.
		# Freight equipment stays on the apron, clear of access lanes and berths.
		for i in 8:
			piece("carga_portuaria",port+Vector3(land*24,0,-52+i*14),(.12 if i%2==0 else -.14))
		for i in 7: piece("defensa_portuaria",port+Vector3(-land*37,0,-91+i*29),PI*.5)
		for i in 5: piece("canaleta_danificada",port+Vector3(land*35,0,-80+i*34))
		for side in [-1.,1.]:
			for i in 4:
				var p:=Vector2(port.x+land*(68+i*21),port.z+side*(135+i%2*13))
				grounded("cratera_impacto",p)
				grounded("entulho_tijolos",p+Vector2(4,3),i*.71)
			for i in 3:
				var p:=Vector2(port.x+land*(88+i*33),port.z+side*170)
				grounded("fachada_atingida",p,0 if side>0 else PI)
				grounded("laje_desabada",p+Vector2(7,side*5),.6+i)
				grounded("carro_carbonizado",p+Vector2(-9,side*9),i*.45)
				grounded("entulho_tijolos",p+Vector2(-6,side*5),i)
func towns() -> void:
	for town: Vector2 in [Vector2(-610,610),Vector2(610,-610),WarUrbanLayout.CENTRES[0],WarUrbanLayout.CENTRES[1]]:
		for side in [-1.,1.]:
			var edge:=town+Vector2(side*118,side*83)
			grounded("fachada_atingida",edge,PI if side>0 else 0.)
			grounded("laje_desabada",edge+Vector2(8,5),side*.7)
			grounded("entulho_tijolos",edge+Vector2(-5,6),1.2)
			grounded("carro_carbonizado",town+Vector2(side*62,side*10),PI*.5+.12*side)
		for i in 6:
			var p:=town+Vector2(-76+i*29,10 if i%2==0 else -11)
			grounded("canaleta_danificada",p,PI*.5)
			if i%2==0: grounded("entulho_tijolos",p+Vector2(0,4))
		for i in 3: grounded("cratera_impacto",town+Vector2(-43+i*37,-54))
func run() -> void:
	if FileAccess.file_exists(DEST): print("PRESERVED_EXISTING_DEVASTATION");quit();return
	layout=Node3D.new();layout.name="DetalhamentoDeGuerra";root.add_child(layout)
	ports();towns()
	var packed:=PackedScene.new();assert(packed.pack(layout)==OK);assert(ResourceSaver.save(packed,DEST)==OK)
	print("DEVASTATION_READY objects=",count);layout.queue_free();await process_frame;await process_frame;quit()
