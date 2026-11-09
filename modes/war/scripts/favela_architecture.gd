extends RefCounted
## Modular Favela architecture. Scene parts are flattened into EnvironmentKit
## sector batches: high visual density without keeping one live scene per prop.
const MODULES := {
	"favela_degrau_beco": preload("res://modes/war/library/favela_degrau_beco.tscn"),
	"favela_z_stair_tread": preload("res://modes/war/library/favela_z_stair_tread.tscn"),
	"janela_grade": preload("res://modes/war/library/favela_janela_grade.tscn"),
	"janela_madeira": preload("res://modes/war/library/favela_janela_madeira.tscn"),
	"porta_entrada": preload("res://modes/war/library/favela_porta_entrada.tscn"),
	"sacada": preload("res://modes/war/library/favela_sacada.tscn"),
	"laje_domestica": preload("res://modes/war/library/favela_laje_domestica.tscn"),
	"laje_obra": preload("res://modes/war/library/favela_laje_obra.tscn"),
	"escada_externa": preload("res://modes/war/library/favela_escada_externa.tscn"),
	"puxadinho_chapa": preload("res://modes/war/library/favela_puxadinho_chapa.tscn"),
	"carro_compacto": preload("res://modes/war/library/favela_carro_compacto.tscn"),
	"favela_caixa_dagua": preload("res://modes/war/library/favela_caixa_dagua.tscn"),
	"favela_ar_condicionado": preload("res://modes/war/library/favela_ar_condicionado.tscn"),
	"favela_varal": preload("res://modes/war/library/favela_varal.tscn"),
	"favela_kit_obra": preload("res://modes/war/library/favela_kit_obra.tscn"),
	"favela_caixa_eletrica": preload("res://modes/war/library/favela_caixa_eletrica.tscn"),
	"favela_toldo": preload("res://modes/war/library/favela_toldo.tscn"),
	"favela_canaleta_drenagem": preload("res://modes/war/library/favela_canaleta_drenagem.tscn"),
	"favela_muro_contencao": preload("res://modes/war/library/favela_muro_contencao.tscn"),
	"favela_corrimao_beco": preload("res://modes/war/library/favela_corrimao_beco.tscn"),
	"favela_tubulacao_externa": preload("res://modes/war/library/favela_tubulacao_externa.tscn"),
	"favela_antena_parabolica": preload("res://modes/war/library/favela_antena_parabolica.tscn"),
	"favela_portao_grade": preload("res://modes/war/library/favela_portao_grade.tscn"),
	"favela_tanque_lavanderia": preload("res://modes/war/library/favela_tanque_lavanderia.tscn"),
	"favela_barraca_rua": preload("res://modes/war/library/favela_barraca_rua.tscn"),
	"favela_lixeira_rua": preload("res://modes/war/library/favela_lixeira_rua.tscn"),
	"favela_pedras_entulho": preload("res://modes/war/library/favela_pedras_entulho.tscn"),
	"favela_caixa_fibra_optica": preload("res://modes/war/library/favela_caixa_fibra_optica.tscn"),
}
const EDGE_MODULE_IDS := [
	"favela_canaleta_drenagem","favela_muro_contencao","favela_corrimao_beco",
	"favela_tubulacao_externa","favela_antena_parabolica","favela_portao_grade",
	"favela_tanque_lavanderia","favela_barraca_rua",
	"favela_lixeira_rua","favela_pedras_entulho","favela_caixa_fibra_optica"
]
static var modules: Dictionary={}

static func _cache(id: String) -> void:
	var scene: PackedScene=MODULES[id]
	var template:=scene.instantiate() as Node3D
	var parts: Array[Dictionary]=[]
	var part_index:=0
	for model: MeshInstance3D in template.find_children("*","MeshInstance3D",true,false):
		if model.mesh==null:continue
		var material: Material=model.material_override
		if material==null and model.mesh.get_surface_count()>0:
			material=model.mesh.surface_get_material(0)
		var material_key:="favela_module_"+id+"_"+str(part_index)
		EnvironmentKit.materials[material_key]=material if material!=null else EnvironmentKit.material("concrete")
		var distance:=model.visibility_range_end
		if distance<=0.0:distance=float(template.get_meta("lod_far",180.0))
		parts.append({
			"mesh":model.mesh,
			"pose":model.transform,
			"material":material_key,
			"distance":distance
		})
		part_index+=1
	var shapes: Array[Dictionary]=[]
	for node: CollisionShape3D in template.find_children("*","CollisionShape3D",true,false):
		shapes.append({"shape":node.shape,"pose":node.transform,"surface":node.get_meta("surface","")})
	modules[id]={"parts":parts,"shapes":shapes}
	template.free()

static func _variant(id: String,pose: Transform3D) -> int:
	var p:=pose.origin
	return absi(int(round(p.x*17.0+p.z*29.0+p.y*7.0))+id.length()*53)

static func _yaw(pose: Transform3D) -> float:
	return pose.basis.orthonormalized().get_euler().y

static func _water_tank(kit: EnvironmentKit,pose: Transform3D,local: Vector3) -> void:
	var at:=pose*local
	kit.cylinder("CaixaDagua",at+Vector3.UP*.46,.50,.92,"plaster:2b5868",false,.92)
	kit.cylinder("TampaCaixa",at+Vector3.UP*.97,.22,.10,"steel:30383a",false,.86)
	kit.pipe(at+Vector3(.34,.16,0),at+Vector3(.34,-.24,0),.020,"steel:65706d",false)

static func _laundry(kit: EnvironmentKit,pose: Transform3D,local: Vector3,scale:=1.0) -> void:
	var left:=pose*(local+Vector3(-1.0,0,0)*scale)
	var right:=pose*(local+Vector3(1.0,0,0)*scale)
	kit.pipe(left,left+Vector3.UP*(1.08*scale),.025,"steel:444a47",false)
	kit.pipe(right,right+Vector3.UP*(1.08*scale),.025,"steel:444a47",false)
	kit.pipe(left+Vector3.UP*(1.0*scale),right+Vector3.UP*(1.0*scale),.010,"steel:444a47",false)
	var yaw:=_yaw(pose)
	kit.box("RoupaVaral",pose*(local+Vector3(-.36,.71,.025)*scale),Vector3(.48,.58,.025)*scale,
		"fabric:b94a3b",false,Vector3(0,yaw,.06),true)
	kit.box("RoupaVaral",pose*(local+Vector3(.34,.73,-.02)*scale),Vector3(.42,.52,.025)*scale,
		"fabric:3b6f86",false,Vector3(0,yaw,-.05),true)

static func _construction_kit(kit: EnvironmentKit,pose: Transform3D,local: Vector3) -> void:
	var yaw:=_yaw(pose)
	for i in 5:
		var brick:=local+Vector3(-.68+(i%3)*.42,.11+(i/3)*.22,-.22)
		kit.box("TijolosLaje",pose*brick,Vector3(.38,.20,.20),"brick:8f4935",false,Vector3(0,yaw,0),true)
	for i in 2:
		var bag:=local+Vector3(.52+i*.09,.10+i*.18,.25-i*.06)
		kit.box("SacoCimento",pose*bag,Vector3(.56,.17,.33),"fabric:bdb39a",false,Vector3(0,yaw+(.13 if i==0 else -.09),0),true)
	for x in [-.88,-.66]:
		var base:=pose*(local+Vector3(x,0,.50))
		kit.pipe(base,base+Vector3.UP*1.55,.018,"steel:4b4d47",false)

static func _air_conditioner(kit: EnvironmentKit,pose: Transform3D,side: float) -> void:
	var yaw:=_yaw(pose)
	var center:=pose*Vector3(side*1.17,-.22,.24)
	kit.box("ArCondicionado",center,Vector3(.78,.48,.34),"plaster:c1c0b5",false,Vector3(0,yaw,0))
	kit.box("GradeAr",pose*Vector3(side*1.17,-.22,.425),Vector3(.62,.30,.025),
		"steel:343938",false,Vector3(0,yaw,0),true)
	kit.pipe(pose*Vector3(side*1.17,-.30,.20),pose*Vector3(side*1.18,-1.15,.14),
		.018,"steel:747974",false)

static func _meter(kit: EnvironmentKit,pose: Transform3D,side: float) -> void:
	var yaw:=_yaw(pose)
	kit.box("CaixaEletrica",pose*Vector3(side*.92,1.38,.12),Vector3(.34,.46,.16),
		"steel:646a65",false,Vector3(0,yaw,0))
	kit.box("MostradorEletrico",pose*Vector3(side*.92,1.43,.215),Vector3(.22,.14,.025),
		"steel:2a2e2d",false,Vector3(0,yaw,0),true)
	kit.pipe(pose*Vector3(side*.92,1.60,.08),pose*Vector3(side*.92,.12,.06),
		.021,"steel:575d59",false)

static func _awning(kit: EnvironmentKit,pose: Transform3D) -> void:
	var yaw:=_yaw(pose)
	var canopy:=pose*Vector3(0,2.36,.62)
	kit.box("Toldo",canopy,Vector3(2.25,.055,1.12),"fabric:8d3228",false,Vector3(-.12,yaw,0))
	for side in [-.96,.96]:
		kit.pipe(pose*Vector3(side,2.29,.10),pose*Vector3(side,2.22,1.08),.018,"steel:353936",false)

static func _decorate(kit: EnvironmentKit,id: String,pose: Transform3D) -> void:
	# Deterministic domestic/utility details based on real Favela references.
	# Runtime uses EnvironmentKit primitives so thousands of details collapse
	# into shared sector MultiMeshes instead of producing per-prefab draw calls.
	var variant:=_variant(id,pose)
	match id:
		"laje_domestica":
			if variant%3!=0:_water_tank(kit,pose,Vector3(.70,.03,-.18))
			if variant%2==0:_laundry(kit,pose,Vector3(-.35,.02,.24),.92)
		"laje_obra":
			_construction_kit(kit,pose,Vector3(.18,.02,.04))
			if variant%5==0:_water_tank(kit,pose,Vector3(-.82,.03,.34))
		"sacada":
			if variant%3==0:_laundry(kit,pose,Vector3(0,.45,.18),.72)
		"janela_grade","janela_madeira":
			if variant%9==0:_air_conditioner(kit,pose,1.0 if variant%2==0 else -1.0)
		"porta_entrada":
			if variant%3==0:_meter(kit,pose,1.0 if variant%2==0 else -1.0)
			if variant%5==0:_awning(kit,pose)
		"puxadinho_chapa":
			if variant%5==0:_water_tank(kit,pose,Vector3(.76,2.16,-.62))
			var gutter_a:=pose*Vector3(-1.72,1.72,1.70)
			var gutter_b:=pose*Vector3(1.72,1.72,1.70)
			kit.pipe(gutter_a,gutter_b,.025,"steel:585d58",false)
			if variant%2==0:kit.pipe(gutter_b,gutter_b+Vector3.DOWN*1.72,.027,"steel:585d58",false)

static func place(kit: EnvironmentKit,id: String,pose: Transform3D,solid:=false) -> void:
	if not solid and not kit.visuals:return
	if not MODULES.has(id):
		push_error("Unknown Favela architecture module: "+id)
		return
	if not modules.has(id):_cache(id)
	var module: Dictionary=modules[id]
	# Edge infrastructure repeats across the whole 1.5 km map. Larger sectors
	# reduce MultiMesh batch count while its short LOD ranges retain local culling.
	var sector_size:=160.0 if id in EDGE_MODULE_IDS else (100.0 if id=="carro_compacto" else (85.0 if id=="puxadinho_chapa" else 48.0))
	for part: Dictionary in module.parts:
		kit._instance(part.mesh,part.material,pose*part.pose,false,null,float(part.distance),
			{"shadows":false,"optional":not solid,"sector":sector_size})
	if solid:
		for shape: Dictionary in module.shapes:
			var transform: Transform3D=pose*shape.pose
			var resource: Shape3D=shape.shape
			if resource is ConvexPolygonShape3D:
				# Stair rise and run vary, but the sector collider stays unscaled.
				var points:=PackedVector3Array()
				for point: Vector3 in resource.points:
					var fitted_point:=transform.basis*point
					if id=="escada_externa" and point.z>-.01:
						# Carry the sloped collision under the ground at the first riser.
						fitted_point+=Vector3(0,-.13,.23)
					elif id=="escada_externa" and point.z< -8.59:
						fitted_point.z-=.15
					points.append(fitted_point)
				var fitted:=ConvexPolygonShape3D.new()
				fitted.points=points
				resource=fitted
				transform.basis=Basis.IDENTITY
			kit._collider("Favela_"+id,resource,transform,shape.surface)
	if kit.visuals and id in ["laje_domestica","laje_obra","sacada","janela_grade",
		"janela_madeira","porta_entrada","puxadinho_chapa"]:
		_decorate(kit,id,pose)
