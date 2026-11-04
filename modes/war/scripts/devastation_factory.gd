extends RefCounted
class_name WarDevastationFactory
const ITEMS:={"fachada_atingida":"Fachada atingida","laje_desabada":"Laje desabada","carro_carbonizado":"Carro carbonizado","entulho_tijolos":"Entulho de tijolos","carga_portuaria":"Carga portuária","defensa_portuaria":"Defensa de cais","canaleta_danificada":"Canaleta danificada","cratera_impacto":"Cratera de impacto"}
const NEAR:={"fachada_atingida":140.,"laje_desabada":90.,"carro_carbonizado":100.,"entulho_tijolos":65.,"carga_portuaria":110.,"defensa_portuaria":100.,"canaleta_danificada":70.,"cratera_impacto":90.}

static func low_detail(root: Node3D,id: String) -> Node3D:
	var low:=Node3D.new();low.name="Distancia";root.add_child(low)
	match id:
		"fachada_atingida":
			for floor_index in 3:
				var y:=floor_index*3.1
				box(low,"Laje",Vector3(-1,y+.1,1.3),Vector3(10,.2,5.2),"concrete")
				box(low,"Parede",Vector3(-5.55,y+1.5,1.9),Vector3(.35,2.8,4),"brick")
				for bay in (2 if floor_index==2 else 4):
					box(low,"Pilar",Vector3(-4.8+bay*2.8,y+1.5,0),Vector3(.65,2.8,.4),"plaster")
					box(low,"Peitoril",Vector3(-3.5+bay*2.8,y+.55,0),Vector3(1.95,.9,.4),"brick")
		"carro_carbonizado":
			box(low,"Carrocaria",Vector3(0,.55,0),Vector3(1.7,.5,3.9),"charcoal")
			for side in [-1.,1.]:
				for z in [-1.35,1.35]:
					var wheel:=CylinderMesh.new();wheel.radial_segments=6;wheel.rings=1;wheel.top_radius=.34;wheel.bottom_radius=.34;wheel.height=.20
					WarArtStyle.mesh(low,"Roda",wheel,"rubber",Vector3(side*.85,.35,z),Basis(Vector3.FORWARD,PI*.5))
		"entulho_tijolos": WarArtStyle.mesh(low,"Silhueta",WarBodyMesh.loft("rubble190-low",[[0,1.8,1.2,0],[.18,1.1,.8,.1],[.42,.08,.05,-.1]],6,1.),"earth")
		"laje_desabada":
			for i in 3: box(low,"Placa",Vector3((i-1)*1.15,.20+i*.12,(i%2)*.65),Vector3(2.3,.24,1.9),"concrete",false,Vector3(.13*i,.48*i,.16-i*.12))
		"carga_portuaria":
			box(low,"Palete",Vector3(0,.18,0),Vector3(2.5,.25,1.8),"wood")
			for i in 3:
				var drum:=CylinderMesh.new();drum.radial_segments=6;drum.rings=1;drum.top_radius=.31;drum.bottom_radius=.31;drum.height=.95
				WarArtStyle.mesh(low,"Tambor",drum,"rust",Vector3(i*.78-.8,.775,0))
		"canaleta_danificada":
			for side in [-1.,1.]: box(low,"MeioFio",Vector3(side*.58,.15,0),Vector3(.18,.30,4.4),"concrete")
		"defensa_portuaria":
			box(low,"Chapa",Vector3(0,.08,0),Vector3(2.4,.16,.8),"bare_metal")
			for x in [-.7,.7]: box(low,"Cabeco",Vector3(x,.42,0),Vector3(.35,.65,.35),"gunmetal")
	return low

static func box(root: Node3D,label: String,p: Vector3,size: Vector3,finish: String,solid:=false,rotation:=Vector3.ZERO) -> void:
	WarPrefabFactory.box(root,label,p,size,finish,solid,rotation)

static func debris(root: Node3D,seed_value: int,count: int,radius: float,brick:=false,min_radius:=0.) -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	for i in count:
		var angle:=rng.randf()*TAU;var r:=sqrt(rng.randf_range(pow(min_radius/radius,2),1))*radius
		var size:=Vector3(rng.randf_range(.12,.45),rng.randf_range(.07,.22),rng.randf_range(.14,.50))
		box(root,"Fragmento",Vector3(cos(angle)*r,size.y*.5,sin(angle)*r),size,"brick" if brick and i%3!=0 else "concrete",false,Vector3(rng.randf_range(-.2,.2),angle,rng.randf_range(-.2,.2)))

static func facade(root: Node3D) -> void:
	for floor_index in 3:
		var floor:=Node3D.new();floor.name="Pavimento"+str(floor_index+1);root.add_child(floor)
		var y:=floor_index*3.1
		box(floor,"Laje",Vector3(-1,y+.10,1.3),Vector3(10,.2,5.2),"concrete",true)
		for bay in 4:
			var x: float=-4.8+bay*2.8
			if floor_index==2 and bay>=2: continue
			box(floor,"Alvenaria",Vector3(x,y+1.5,0),Vector3(.65,2.8,.40),"plaster",true)
			box(floor,"Peitoril",Vector3(x+1.3,y+.55,0),Vector3(1.95,.9,.40),"brick",true)
			box(floor,"Verga",Vector3(x+1.3,y+2.65,0),Vector3(1.95,.35,.40),"plaster",true)
			for side in [-1.,1.]: box(floor,"JanelaQuebrada",Vector3(x+1.3+side*.76,y+1.75,-.23),Vector3(.06,1.55,.06),"wood")
			box(floor,"Caixilho",Vector3(x+1.3,y+2.47,-.23),Vector3(1.6,.06,.06),"wood")
			box(floor,"Fuligem",Vector3(x+.37,y+1.2,-.212),Vector3(.14,1.7,.015),"charcoal")
		box(floor,"ParedeLateral",Vector3(-5.55,y+1.5,1.9),Vector3(.35,2.8,4),"brick",true)
		if floor_index<2:
			box(floor,"Sacada",Vector3(-1.8,y+.28,-1.05),Vector3(3.0,.16,1.8),"concrete",true)
			for x in [-3.,-2.4,-1.8,-1.2,-.6]: WarPrefabFactory.beam(floor,"Grade",Vector3(x,y+.35,-1.9),Vector3(x+.12,y+1.18,-1.9),.045,"rust")
		for i in 6: WarPrefabFactory.beam(floor,"Vergalhao",Vector3(2.4+i*.33,y+.18,1.1),Vector3(3.5+i*.27,y+.35,2.4),.024,"rust")
	debris(root,19031,42,5.,true)
	root.set_meta("footprint",Vector2(13,8));root.set_meta("terrain_grade",true)

static func car(root: Node3D) -> void:
	# Open window frames and missing roof expose the burnt cabin.
	for side in [-1.,1.]:
		box(root,"Soleira",Vector3(side*.81,.48,0),Vector3(.15,.28,3.9),"rust",true)
		box(root,"PortaQueimada",Vector3(side*.80,.85,.12),Vector3(.10,.50,1.8),"charcoal",true)
		for z in [-1.05,1.]: WarPrefabFactory.beam(root,"Coluna",Vector3(side*.75,1.,z),Vector3(side*.62,1.55,z*.75),.07,"bare_metal")
		for z in [-1.35,1.35]: WarPrefabFactory.tube(root,"Pneu",Vector3(side*.73,.35,z),Vector3(side*.95,.35,z),.34,"rubber",true)
	box(root,"Assoalho",Vector3(0,.45,0),Vector3(1.6,.12,3.8),"gunmetal",true)
	box(root,"CapoAmassado",Vector3(0,.90,-1.45),Vector3(1.55,.12,1.0),"rust",true,Vector3(.17,.04,.07))
	box(root,"PortaMalas",Vector3(0,.91,1.48),Vector3(1.55,.13,.9),"charcoal",true,Vector3(-.08,.02,-.05))
	for x in [-.4,.4]: box(root,"BancoCarbonizado",Vector3(x,.88,.3),Vector3(.57,.65,.44),"charcoal")
	for z in [-1.95,1.95]: box(root,"ParaChoque",Vector3(0,.50,z),Vector3(1.7,.16,.18),"gunmetal")
	root.set_meta("footprint",Vector2(2.1,4.4))

static func build(id: String,root: Node3D) -> void:
	match id:
		"fachada_atingida": facade(root)
		"carro_carbonizado": car(root)
		"laje_desabada":
			for i in 3:
				box(root,"PlacaPartida",Vector3((i-1)*1.15,.20+i*.12,(i%2)*.65),Vector3(2.3,.24,1.9),"concrete",true,Vector3(.13*i,.48*i,.16-i*.12))
				for j in 5: WarPrefabFactory.beam(root,"Vergalhao",Vector3((i-1)*1.15+j*.15,.35+i*.12,.5),Vector3((i-1)*1.15+j*.15+.3,.45+i*.12,1.8),.025,"rust")
			debris(root,19032,24,3.2);root.set_meta("footprint",Vector2(6,5))
		"entulho_tijolos":
			debris(root,19033,65,2.4,true)
			var mound:=WarBodyMesh.loft("rubble190-high",[[0,1.8,1.2,0],[.12,1.5,1.05,.08],[.28,.9,.65,-.12],[.42,.08,.05,.06]],9,1.);WarArtStyle.mesh(root,"MioloDeEntulho",mound,"earth")
			var hull:=ConvexPolygonShape3D.new();hull.points=PackedVector3Array([Vector3(-1.8,0,-1.25),Vector3(1.8,0,-1.25),Vector3(1.8,0,1.25),Vector3(-1.8,0,1.25),Vector3(0,.45,0)])
			WarPrefabFactory.body(root,"Contato",hull,Transform3D.IDENTITY,"concrete");root.set_meta("footprint",Vector2(5,5));root.set_meta("terrain_grade",true)
		"carga_portuaria":
			for z in [-.7,0.,.7]: box(root,"Longarina",Vector3(0,.12,z),Vector3(2.5,.18,.15),"wood",true)
			for i in 8: box(root,"Tabua",Vector3(i*.32-1.1,.25,0),Vector3(.23,.10,1.8),"wood")
			for i in 3:
				var x: float=i*.78-.8
				WarPrefabFactory.tube(root,"Tambor",Vector3(x,.30,0),Vector3(x,1.25,0),.31,"rust",true)
				for y in [.4,1.1]: WarPrefabFactory.tube(root,"Aro",Vector3(x,y,0),Vector3(x,y+.045,0),.33,"bare_metal")
			box(root,"CargaAmarrada",Vector3(0,.8,.65),Vector3(1.85,1.0,.5),"wood",true)
			root.set_meta("footprint",Vector2(3,2.2))
		"defensa_portuaria":
			box(root,"Chapa",Vector3(0,.08,0),Vector3(2.4,.16,.8),"bare_metal",true)
			for x in [-.7,.7]:
				WarPrefabFactory.tube(root,"Cabeco",Vector3(x,.10,0),Vector3(x,.75,0),.16,"gunmetal",true)
				WarPrefabFactory.tube(root,"Travessa",Vector3(x-.3,.70,0),Vector3(x+.3,.70,0),.13,"gunmetal",true)
			for z in [.55,.70]: WarPrefabFactory.tube(root,"Corda",Vector3(-1.0,.18,z),Vector3(1.0,.18,z),.045,"webbing")
			root.set_meta("footprint",Vector2(3,2))
		"canaleta_danificada":
			for side in [-1.,1.]:
				for i in 5:
					if side<0 and i==2: continue
					box(root,"MeioFio",Vector3(side*.58,.15,i*.8-1.6),Vector3(.18,.30,.73),"concrete",true,Vector3(0,.02*i,.015*i))
			box(root,"Fundo",Vector3(0,.025,0),Vector3(1.2,.05,4.4),"earth")
			for i in 7: box(root,"Grelha",Vector3(0,.14,i*.10-1.7),Vector3(.9,.025,.035),"rust")
			root.set_meta("footprint",Vector2(1.8,4.5))
		"cratera_impacto":
			debris(root,19034,38,3.,false,2.75);root.set_meta("footprint",Vector2(6,6));root.set_meta("crater_depth",.65)
