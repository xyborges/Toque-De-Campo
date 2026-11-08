extends RefCounted
class_name WarPrefabFactory

# Authoring factory only. The shipped map loads ordinary PackedScenes with
# saved geometry/materials/collision; it never rebuilds these objects at spawn.
const PATH:="res://modes/war/library/"
const ITEMS:={"favela_degrau_beco":"Favela - degrau de beco","favela_lixeira_rua":"Favela - lixeira de rua","favela_pedras_entulho":"Favela - pedras e restos de obra","favela_caixa_fibra_optica":"Favela - caixa de fibra optica","favela_arbusto_encosta":"Favela - arbusto de mata","favela_rocha_encosta":"Favela - rocha de encosta","favela_nevoa_encosta":"Favela - nevoa na encosta","favela_canaleta_drenagem":"Favela · canaleta de drenagem","favela_muro_contencao":"Favela · muro de contenção","favela_corrimao_beco":"Favela · corrimão de beco","favela_tubulacao_externa":"Favela · tubulação externa","favela_antena_parabolica":"Favela · antena parabólica","favela_portao_grade":"Favela · portão de grade","favela_tanque_lavanderia":"Favela · tanque de lavanderia","favela_barraca_rua":"Favela · barraca de rua","favela_caixa_dagua":"Favela · caixa d’água", "favela_ar_condicionado":"Favela · ar-condicionado externo", "favela_varal":"Favela · varal de laje", "favela_kit_obra":"Favela · materiais de obra", "favela_caixa_eletrica":"Favela · caixa elétrica", "favela_toldo":"Favela · toldo de fachada", "favela_puxadinho_chapa":"Favela · puxadinho de chapa", "favela_janela_grade":"Favela · janela com grade", "favela_janela_madeira":"Favela · janela de madeira", "favela_porta_entrada":"Favela · porta e soleira", "favela_sacada":"Favela · sacada", "favela_laje_domestica":"Favela · laje doméstica", "favela_laje_obra":"Favela · obra na laje", "favela_escada_externa":"Favela · escada externa", "favela_carro_compacto":"Favela · carro compacto", "favela_pixacao":"Favela · pixação", "favela_lixo_calcada":"Favela · lixo de calçada","favela_comercio_fachada":"Favela · comércio", "favela_poste_cabos":"Favela · poste", "favela_rede_aerea":"Favela · rede aérea", "favela_moto_estacionada":"Favela · moto estacionada","favela_casa_laje":"Favela · casa com laje","favela_barricada_pneus":"Favela · barricada de pneus","caixa_municao":"Caixa de munição","pinheiro":"Pinheiro","arvore_queimada":"Árvore queimada","trincheira_6m":"Revestimento · 6 m","estrada_12m":"Estrada · 12 m","container_20ft":"Contêiner · 20 pés","cais_8m":"Cais · 8 m","barreira_concreto":"Barreira de concreto","escada_4m":"Escada · 4 m","casa_ruina":"Casa em ruínas","estrada_curva_90":"Estrada · curva 90°","estrada_cruzamento":"Estrada · cruzamento","estrada_entroncamento":"Estrada · entroncamento T","estrada_rampa_12m":"Estrada · rampa 12 m","cais_curva_90":"Cais · curva 90°","cais_rampa_8m":"Cais · rampa 8 m","trincheira_escavavel_6m":"Trincheira escavável · 6 m","fachada_atingida":"Fachada atingida","laje_desabada":"Laje desabada","carro_carbonizado":"Carro carbonizado","entulho_tijolos":"Entulho de tijolos","carga_portuaria":"Carga portuária","defensa_portuaria":"Defensa de cais","canaleta_danificada":"Canaleta danificada","cratera_impacto":"Cratera de impacto","grama_baixa_2m":"Grama baixa · 2 m"}

static func node(label: String,parent: Node3D) -> Node3D:
	var result:=Node3D.new();result.name=label;parent.add_child(result);return result

static func box(parent: Node3D,label: String,point: Vector3,size: Vector3,finish: String,solid:=false,rotation:=Vector3.ZERO,bevel:=false) -> MeshInstance3D:
	var shape: Mesh=WarBodyMesh.cushion(size) if bevel else BoxMesh.new()
	if shape is BoxMesh: shape.size=size
	var mesh:=WarArtStyle.mesh(parent,label,shape,finish,point,Basis.from_euler(rotation))
	if solid:
		var collision:=BoxShape3D.new();collision.size=size
		body(parent,label+"Collision",collision,mesh.transform,surface(finish))
	return mesh

static func surface(finish: String) -> String:
	return {"bark":"wood","charcoal":"wood","wood":"wood","earth":"mud","asphalt":"asphalt","concrete":"concrete","plaster":"concrete","brick":"concrete","rubber":"concrete"}.get(finish,"metal")

static func body(parent: Node3D,label: String,shape: Shape3D,pose: Transform3D,contact: String) -> StaticBody3D:
	var value:=StaticBody3D.new();value.name=label;value.collision_layer=1;value.collision_mask=0;value.transform=pose;value.set_meta("surface",contact)
	var collision:=CollisionShape3D.new();collision.name="Shape";collision.shape=shape;value.add_child(collision);parent.add_child(value);return value

static func tube(parent: Node3D,label: String,a: Vector3,b: Vector3,radius: float,finish: String,solid:=false,top:=1.) -> MeshInstance3D:
	var shape:=CylinderMesh.new();shape.top_radius=radius*top;shape.bottom_radius=radius;shape.height=a.distance_to(b);shape.radial_segments=12;shape.rings=1
	var mesh:=WarArtStyle.mesh(parent,label,shape,finish,(a+b)*.5,Basis(Quaternion(Vector3.UP,(b-a).normalized())))
	if solid:
		var collision:=CylinderShape3D.new();collision.radius=radius;collision.height=shape.height
		body(parent,label+"Collision",collision,mesh.transform,surface(finish))
	return mesh

static func beam(parent: Node3D,label: String,a: Vector3,b: Vector3,width: float,finish: String,solid:=false) -> void:
	box(parent,label,(a+b)*.5,Vector3(width,a.distance_to(b),width),finish,solid,Basis(Quaternion(Vector3.UP,(b-a).normalized())).get_euler())

static func finish(root: Node3D,id: String) -> Node3D:
	root.set_meta("library_id",id);root.set_meta("asset_revision",188)
	root.set_meta("origin","ground");root.set_meta("forward","-Z")
	# Bake small rigid details by finish inside named groups. Geometry can
	# still be moved with its collider, and every instance shares resources.
	var groups: Array[Node]=[root]
	groups.append_array(root.find_children("*","Node3D",true,false))
	for parent in groups:
		if not is_instance_valid(parent): continue
		var ancestor: Node=parent;var instanced:=false
		while ancestor!=root:
			if not ancestor.scene_file_path.is_empty(): instanced=true;break
			ancestor=ancestor.get_parent()
		if instanced: continue
		if parent is MeshInstance3D or parent is CollisionObject3D: continue
		var pieces: Array[Node]=[]
		for child in parent.get_children():
			if child is MeshInstance3D: pieces.append(child)
		if pieces.size()>1: WarRenderBatch.merge(parent,"library188:"+id+":"+str(root.get_path_to(parent)),pieces)
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		mesh.remove_meta("uniform_attachment");mesh.visibility_range_end=1200
	return root

static func create(id: String) -> Node3D:
	var root:=Node3D.new();root.name=id.to_pascal_case()
	if id in WarDevastationFactory.ITEMS:
		WarDevastationFactory.build(id,root);var low:=WarDevastationFactory.low_detail(root,id);finish(root,id);root.set_meta("asset_revision",190)
		for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
			if low.is_ancestor_of(mesh):
				mesh.visibility_range_begin=WarDevastationFactory.NEAR[id];mesh.visibility_range_end=1400 if id=="fachada_atingida" else (850 if id=="carro_carbonizado" else 500);mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else: mesh.visibility_range_end=WarDevastationFactory.NEAR[id]
		return root
	match id:
		"favela_degrau_beco","favela_lixeira_rua","favela_pedras_entulho","favela_caixa_fibra_optica","favela_arbusto_encosta","favela_rocha_encosta","favela_nevoa_encosta","favela_canaleta_drenagem","favela_muro_contencao","favela_corrimao_beco","favela_tubulacao_externa","favela_antena_parabolica","favela_portao_grade","favela_tanque_lavanderia","favela_barraca_rua","favela_caixa_dagua","favela_ar_condicionado","favela_varal","favela_kit_obra","favela_caixa_eletrica","favela_toldo","favela_puxadinho_chapa","favela_janela_grade","favela_janela_madeira","favela_porta_entrada","favela_sacada","favela_laje_domestica","favela_laje_obra","favela_escada_externa","favela_carro_compacto","favela_pixacao","favela_lixo_calcada","caixa_municao","grama_baixa_2m","favela_casa_laje","favela_barricada_pneus","favela_comercio_fachada","favela_poste_cabos","favela_rede_aerea","favela_moto_estacionada":
			root.free()
			return load(PATH+id+".tscn").instantiate() as Node3D
		"pinheiro","arvore_queimada": tree(root,id=="pinheiro")
		"container_20ft": container(root)
		"estrada_12m": road(root)
		"cais_8m": quay(root)
		"trincheira_6m": trench(root)
		"barreira_concreto": barrier(root)
		"escada_4m": stairs(root)
		"casa_ruina": ruin(root)
		_: WarInfrastructureFactory.build(id,root)
	finish(root,id)
	if id in WarInfrastructureFactory.ITEMS: root.set_meta("asset_revision",190)
	if id in ["pinheiro","arvore_queimada"]:
		for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false): mesh.visibility_range_end=110.
		var low:=Node3D.new();low.name="Distancia";root.add_child(low)
		var trunk:=WarBodyMesh.loft("tree188-low-trunk",[[0,.24,.24,0],[5,.10,.10,.03],[8.6,.01,.01,.08]],6,1.)
		WarArtStyle.mesh(low,"TroncoDistante",trunk,"bark" if id=="pinheiro" else "charcoal")
		if id=="pinheiro":
			var crown:=WarBodyMesh.loft("pine188-low-crown",[[2.5,.12,.12,0],[3.0,2.0,2.0,0],[3.9,1.60,1.60,0],[4.1,1.85,1.85,0],[5.0,1.23,1.23,0],[5.2,1.5,1.5,0],[6.1,.85,.85,0],[6.3,1.05,1.05,0],[7.3,.45,.45,0],[8.6,0,0,.08]],9,1.)
			WarArtStyle.mesh(low,"CopaDistante",crown,"leaf")
		for mesh: MeshInstance3D in low.get_children(): mesh.visibility_range_begin=110.;mesh.visibility_range_end=1400.;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

static func container(root: Node3D) -> void:
	var shell:=node("Estrutura",root)
	box(shell,"Roof",Vector3(0,2.55,0),Vector3(2.438,.08,6.058),"paint",true)
	box(shell,"Floor",Vector3(0,.10,0),Vector3(2.38,.20,6.0),"wood",true)
	for side in [-1,1]:
		box(shell,"CorrugatedWall",Vector3(side*1.19,1.32,0),Vector3(.06,2.46,5.98),"paint",true)
		for z in [-2.98,2.98]: box(shell,"CornerPost",Vector3(side*1.18,1.30,z),Vector3(.12,2.59,.12),"dark_paint",false,Vector3.ZERO,true)
		for y in [.08,2.50]: box(shell,"LongitudinalRail",Vector3(side*1.19,y,0),Vector3(.1,.14,6.03),"dark_paint")
		for i in 23: box(shell,"Corrugation",Vector3(side*1.228,1.33,-2.80+i*.255),Vector3(.025,2.26,.085),"paint",false,Vector3.ZERO,true)
		for z in [-2.87,2.87]: box(shell,"CornerCasting",Vector3(side*1.16,.13,z),Vector3(.20,.22,.22),"bare_metal",false,Vector3.ZERO,true)
	box(shell,"ClosedEnd",Vector3(0,1.31,-3.),Vector3(2.38,2.52,.065),"paint",true)
	for i in 9: box(shell,"EndRib",Vector3(-1.+i*.25,1.32,-3.04),Vector3(.08,2.26,.025),"paint",false,Vector3.ZERO,true)
	for side in [-1,1]:
		var door:=node("PortaEsquerda" if side<0 else "PortaDireita",root)
		box(door,"Door",Vector3(side*.59,1.31,3.01),Vector3(1.16,2.48,.08),"paint",true)
		for x in [side*.20,side*.95]:
			tube(door,"LockRod",Vector3(x,.22,3.09),Vector3(x,2.4,3.09),.018,"bare_metal")
			for y in [.40,1.30,2.20]: box(door,"LockBracket",Vector3(x,y,3.09),Vector3(.09,.055,.08),"dark_paint",false,Vector3.ZERO,true)
			tube(door,"Handle",Vector3(x,1.0,3.12),Vector3(x+side*.15,1.0,3.12),.012,"bare_metal")
		for y in [.35,1.32,2.26]: box(door,"Hinge",Vector3(side*1.13,y,3.07),Vector3(.18,.06,.10),"bare_metal")
		box(door,"DoorGasket",Vector3(side*.02,1.31,3.06),Vector3(.018,2.46,.015),"rubber")
		box(door,"IdentificationPlate",Vector3(side*.6,2.05,3.059),Vector3(.49,.22,.006),"marking")
	for i in 15: box(shell,"RoofRib",Vector3(0,2.60,-2.75+i*.39),Vector3(2.22,.024,.07),"paint",false,Vector3.ZERO,true)
	root.set_meta("footprint",Vector2(2.44,6.06))

static func road(root: Node3D) -> void:
	box(root,"Asfalto",Vector3(0,-.13,0),Vector3(7,.26,12),"asphalt",true)
	for side in [-1,1]:
		box(root,"Acostamento",Vector3(side*3.8,-.20,0),Vector3(.65,.20,12),"earth",true)
		box(root,"FaixaLateral",Vector3(side*3.14,.006,0),Vector3(.10,.012,12),"marking")
	for z in [-4.,2.]: box(root,"FaixaCentral",Vector3(0,.008,z),Vector3(.12,.016,3),"marking")
	root.set_meta("footprint",Vector2(8.25,12));root.set_meta("snap_grid",12.)

static func quay(root: Node3D) -> void:
	box(root,"Plataforma",Vector3(0,-.4,0),Vector3(8,.8,8),"concrete",true)
	for x in [-3.50,3.5]:
		for z in [-3.50,3.5]: tube(root,"Estaca",Vector3(x,-4,z),Vector3(x,-.65,z),.32,"concrete",true)
	for z in [-2.7,2.7]:
		var bollard:=node("Cabeco"+str(z),root)
		box(bollard,"Base",Vector3(3.1,.055,z),Vector3(.50,.11,.55),"bare_metal",true,Vector3.ZERO,true)
		tube(bollard,"Stem",Vector3(3.1,.08,z),Vector3(3.1,.47,z),.13,"dark_paint",true)
		tube(bollard,"Head",Vector3(2.86,.43,z),Vector3(3.34,.43,z),.12,"dark_paint",true)
	for z in [-3.,0.,3.]:
		tube(root,"DefensaBorracha",Vector3(4.025,-.55,z),Vector3(4.025,-.15,z),.23,"rubber",false,.9)
	for i in 12: box(root,"BordaPintada",Vector3(3.72,.006,-3.66+i*.666),Vector3(.40,.012,.30),"marking")
	for x in [-2.,2.]: box(root,"Junta",Vector3(x,.003,0),Vector3(.012,.006,7.98),"recess")
	root.set_meta("footprint",Vector2(8,8));root.set_meta("snap_grid",8.)

static func trench(root: Node3D) -> void:
	# Above-ground revetment module: the central floor starts at the origin.
	# It can extend an existing excavated trench or form a protected lane on
	# flat ground without silently changing the map's height function.
	for side in [-1,1]:
		var wall:=node("ParedeEsquerda" if side<0 else "ParedeDireita",root)
		for i in 15:
				box(wall,"Tabua",Vector3(side*1.15,.69,-2.82+i*.40),Vector3(.10,1.38,.37),"wood",false,Vector3(0,side*.025,0))
		for z in [-2.65,0.,2.65]: box(wall,"Estaca",Vector3(side*1.03,.68,z),Vector3(.13,1.50,.15),"wood")
		for y in [.25,.95]: box(wall,"Longarina",Vector3(side*1.04,y,0),Vector3(.12,.13,6),"wood")
		for row in 2:
				for i in 10: box(wall,"SacoDeAreia",Vector3(side*(1.30+row*.13),1.46+row*.20,-2.7+i*.60+row*.18),Vector3(.46,.25,.64),"earth",false,Vector3(0,side*.10,0),true)
		var shape:=BoxShape3D.new();shape.size=Vector3(.29,1.4,6.)
		body(wall,"ParedeCollision",shape,Transform3D(Basis.IDENTITY,Vector3(side*1.11,.70,0)),"wood")
		var cap:=BoxShape3D.new();cap.size=Vector3(.62,.46,6.1)
		body(wall,"SacosCollision",cap,Transform3D(Basis.IDENTITY,Vector3(side*1.38,1.55,0)),"mud")
	for z in range(13):
		box(root,"Passarela",Vector3(0,.055,-2.76+z*.46),Vector3(1.95,.11,.36),"wood")
	var floor:=BoxShape3D.new();floor.size=Vector3(1.95,.11,5.88)
	body(root,"PisoCollision",floor,Transform3D(Basis.IDENTITY,Vector3(0,.055,0)),"wood")
	root.set_meta("footprint",Vector2(3.4,6.));root.set_meta("snap_grid",6.)

static func barrier(root: Node3D) -> void:
	# Extruded Jersey profile, keeping the sloped sides as real geometry.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline: Array[Vector2]=[Vector2(-.35,0),Vector2(.35,0),Vector2(.35,.18),Vector2(.17,.62),Vector2(.12,1.0),Vector2(-.12,1.),Vector2(-.17,.62),Vector2(-.35,.18)]
	var shape:=PackedVector2Array(outline);var triangles:=Geometry2D.triangulate_polygon(shape)
	for i in outline.size():
		var j: int=(i+1)%outline.size()
		for p in [Vector3(outline[i].x,outline[i].y,-1.5),Vector3(outline[j].x,outline[j].y,1.5),Vector3(outline[j].x,outline[j].y,-1.5),Vector3(outline[i].x,outline[i].y,-1.5),Vector3(outline[i].x,outline[i].y,1.5),Vector3(outline[j].x,outline[j].y,1.5)]: st.add_vertex(p)
	for i in range(0,triangles.size(),3):
		for sign_value in [-1,1]:
			for k in ([2,1,0] if sign_value<0 else [0,1,2]):
				var p:=outline[triangles[i+k]];st.add_vertex(Vector3(p.x,p.y,sign_value*1.5))
	st.generate_normals();st.index();var barrier_mesh:=st.commit()
	WarArtStyle.mesh(root,"ConcretoMoldado",barrier_mesh,"concrete")
	var collision:=barrier_mesh.create_convex_shape();body(root,"Corpo",collision,Transform3D.IDENTITY,"concrete")
	for z in [-1.,1.]: tube(root,"Olhal",Vector3(-.08,1.03,z),Vector3(.08,1.03,z),.016,"rust")
	root.set_meta("footprint",Vector2(.7,3.))

static func stairs(root: Node3D) -> void:
	for i in 10:
		var height: float=(i+1)*.18
		box(root,"Degrau%02d"%i,Vector3(0,height*.5,1.8-i*.4),Vector3(2.4,height,.4),"concrete",true)
		box(root,"Quina",Vector3(0,height+.006,1.99-i*.4),Vector3(2.35,.012,.035),"marking")
	for side in [-1,1]:
		for i in [0,3,6,9]:
			var point:=Vector3(side*1.13,(i+1)*.18,1.8-i*.4)
			tube(root,"Montante",point,point+Vector3.UP*.95,.026,"dark_paint",true)
		tube(root,"Corrimao",Vector3(side*1.13,1.13,1.8),Vector3(side*1.13,2.75,-1.8),.03,"dark_paint",true)
	root.set_meta("footprint",Vector2(2.4,4));root.set_meta("step_height",.18)

static func tree(root: Node3D,green: bool) -> void:
	var leaf_material:=WarArtStyle.material("leaf").duplicate() as StandardMaterial3D;leaf_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var trunk:=WarBodyMesh.loft("pine-trunk188",[[0,.28,.25,0],[.5,.23,.22,.02],[2.5,.16,.15,-.04],[5.,.095,.09,.05],[8.5,.025,.025,.08]],12,1)
	WarArtStyle.mesh(root,"Tronco",trunk,"bark" if green else "charcoal")
	var shape:=CylinderShape3D.new();shape.radius=.23;shape.height=7.
	body(root,"ColisaoTronco",shape,Transform3D(Basis.IDENTITY,Vector3(0,3.5,0)),"wood")
	for level in (8 if green else 5):
		var y: float=2.6+level*.65
		for branch in (5 if green else 3):
			var angle: float=level*1.7+branch*2.4
			var length: float=(2.35-level*.20) if green else (1.2+branch*.19)
			var end:=Vector3(sin(angle)*length,y-.25,cos(angle)*length)
			tube(root,"Galho",Vector3(0,y,0),end,.055 if level<4 else .035,"bark" if green else "charcoal",false,.18)
			if green:
				var direction:=Vector3(sin(angle),0,cos(angle))
				var lateral:=Vector3(cos(angle),0,-sin(angle))
				var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
				for twig in 9:
					var along:=.18+twig*.085
					var middle:=Vector3(0,y,0).lerp(end,along)
					var span: float=(.65*(1-along)+.17)*(1+sin(twig*3.4+level)*.15)
					for side in [-1,1]:
						var tip: Vector3=middle+lateral*side*span-direction*.22+Vector3.UP*(.15+twig%3*.06)
						var tail:=middle-direction*.30+Vector3.DOWN*.08
						for face in [[middle+direction*.13,tip,tail],[middle+Vector3.UP*.13,tip,tail+Vector3.DOWN*.12],[middle+Vector3.DOWN*.10,tail,tip]]:
							for index in [0,2,1]: st.add_vertex(face[index])
				st.generate_normals();st.index()
				var foliage:=MeshInstance3D.new();foliage.name="Agulhas";foliage.mesh=st.commit();foliage.material_override=leaf_material;root.add_child(foliage)
	if green:
		for i in 4:
			var tip:=CylinderMesh.new();tip.top_radius=0;tip.bottom_radius=.32-i*.065;tip.height=.65;tip.radial_segments=7
			WarArtStyle.mesh(root,"Ponteiro",tip,"leaf",Vector3(0,7.55+i*.22,.08))
	root.set_meta("footprint",Vector2(4.6,4.6))

static func ruin(root: Node3D) -> void:
	box(root,"Fundacao",Vector3(0,.12,0),Vector3(9,.24,7),"concrete",true)
	for side in [-1,1]:
		for z in [-2.2,2.2]: box(root,"ParedeLateral",Vector3(side*4.3,1.6,z),Vector3(.28,2.95,2.3),"plaster",true)
		box(root,"ParedeSobJanela",Vector3(side*4.3,.59,0),Vector3(.28,.70,2.1),"plaster",true)
		box(root,"ParedeSobreJanela",Vector3(side*4.3,2.74,0),Vector3(.28,.67,2.1),"plaster",true)
		box(root,"Peitoril",Vector3(side*4.3,.98,0),Vector3(.38,.12,2.25),"concrete",true)
		for z in [-1.,1.]: box(root,"Caixilho",Vector3(side*4.3,1.68,z),Vector3(.33,1.40,.075),"wood")
		for x in [-3.,3.]: box(root,"Frente",Vector3(x,1.6,side*3.35),Vector3(2.6,2.95,.28),"plaster",true)
		box(root,"Verga",Vector3(0,2.94,side*3.35),Vector3(3.3,.28,.32),"wood",true)
		for row in 4:
			for column in 5:
				if row+column>6: continue
				box(root,"AlvenariaExposta",Vector3(-3.90+column*.22+row%2*.10,.36+row*.10,side*3.501),Vector3(.20,.08,.018),"brick")
		for z in [-2.8,0.,2.8]: box(root,"Pilar",Vector3(side*4.1,1.65,z),Vector3(.18,3.,.20),"wood")
	for z in [-2.9,0.,2.9]:
		beam(root,"VigaTelhado",Vector3(-4.3,3.1,z),Vector3(0,4.6,z),.16,"wood",true)
		if z<1: beam(root,"VigaQuebrada",Vector3(0,4.6,z),Vector3(2.0,3.90,z),.16,"wood",true)
	beam(root,"Cumeeira",Vector3(0,4.6,-3.35),Vector3(0,4.6,3.35),.19,"wood",true)
	beam(root,"Terca",Vector3(-2.15,3.86,-3.35),Vector3(-2.15,3.86,3.35),.15,"wood",true)
	box(root,"CoberturaRestante",Vector3(-2.15,3.83,0),Vector3(4.58,.09,6.8),"dark_paint",true,Vector3(0,0,.336))
	for i in 10:
		var angle:=i*2.39
		box(root,"Escombro",Vector3(sin(angle)*2.5,.22,cos(angle)*2.2),Vector3(.45,.30,.8),"concrete",true,Vector3(.12,angle,.1),true)
	root.set_meta("footprint",Vector2(9,7))

