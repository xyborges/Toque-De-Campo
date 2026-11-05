extends Node3D
class_name WarFavelaMap
## Favela ficticia 1.5 x 1.5 km. A mesma fonte deterministica de terreno,
## vias, lotes e coberturas alimenta cliente, servidor e testes.
## A arquitetura usa EnvironmentKit: MultiMesh em celulas e colisores setorizados.
const HALF := 750.0
const TILE := 100.0
const STEP := 5.0
const GRID := 21
const SEED := 241106
const PRIMARY := [
	Vector2(-470,600),Vector2(-460,490),Vector2(-395,420),
	Vector2(-285,330),Vector2(-225,245),Vector2(-170,140),
	Vector2(-95,35),Vector2(20,-80),Vector2(135,-200),
	Vector2(210,-325),Vector2(260,-440),Vector2(315,-570)
]
const CROSS_STREETS := [340.0,165.0,-15.0,-200.0,-395.0]
const VERTICAL_STREETS := [-520.0,-320.0,-105.0,105.0,355.0,560.0]
const BASES_2D := [Vector2(-470,590),Vector2(280,-500)]
const OBJECTIVES_2D := [
	Vector2(-265,345),Vector2(-440,35),Vector2(-85,-20),
	Vector2(270,-205),Vector2(-290,-405)
]
var render_visuals := true
var build_metrics: Dictionary = {}
static var ground_material: StandardMaterial3D
static var asphalt_material: StandardMaterial3D

static func _landform(x: float,z: float) -> float:
	var north:=clampf((575.0-z)/1170.0,0.0,1.0)
	var height:=23.0+103.0*north
	height+=2.25*sin(x*.012)*sin(z*.010)+1.30*cos(x*.026+z*.014)
	# A encosta superior avanca para a mata, sem barrancos atravessando a avenida.
	var woods:=1.0-smoothstep(-740.0,-560.0,z)
	height+=woods*(12.0+5.0*sin(x*.009))
	return height

static func _natural(x: float,z: float) -> float:
	var h:=_landform(x,z)
	for base: Vector2 in BASES_2D:
		var distance:=Vector2(x,z).distance_to(base)
		if distance<66.0:
			h=lerpf(_landform(base.x,base.y),h,smoothstep(36.0,66.0,distance))
	for target: Vector2 in OBJECTIVES_2D:
		var distance:=Vector2(x,z).distance_to(target)
		if distance<38.0:
			h=lerpf(_landform(target.x,target.y),h,smoothstep(24.0,38.0,distance))
	return h

static func height_at(x: float,z: float) -> float:
	# Amostragem triangular igual aos vertices da malha fisica de 5 m.
	var ix:=floori(x/STEP);var iz:=floori(z/STEP)
	var u:=x/STEP-float(ix);var v:=z/STEP-float(iz)
	var a:=_natural(ix*STEP,iz*STEP)
	var b:=_natural((ix+1)*STEP,iz*STEP)
	var c:=_natural(ix*STEP,(iz+1)*STEP)
	var e:=_natural((ix+1)*STEP,(iz+1)*STEP)
	if u+v<=1.0:return a+u*(b-a)+v*(c-a)
	return e+(1.0-u)*(c-e)+(1.0-v)*(b-e)

static func point(x: float,z: float) -> Vector3:
	return Vector3(x,height_at(x,z),z)

static func _segment_distance(p: Vector2,a: Vector2,b: Vector2) -> float:
	var ab:=b-a
	var t:=clampf((p-a).dot(ab)/maxf(ab.length_squared(),.01),0.0,1.0)
	return p.distance_to(a+ab*t)

static func primary_distance(p: Vector2) -> float:
	var closest:=INF
	for i in PRIMARY.size()-1: closest=minf(closest,_segment_distance(p,PRIMARY[i],PRIMARY[i+1]))
	return closest

static func road_distance(p: Vector2) -> float:
	var result:=primary_distance(p)
	for z in CROSS_STREETS:result=minf(result,absf(p.y-z))
	for x in VERTICAL_STREETS:result=minf(result,absf(p.x-x))
	return result

static func accessible(p: Vector3) -> bool:
	if absf(p.x)>HALF-20.0 or absf(p.z)>HALF-20.0:return false
	var sx:=(height_at(p.x+2.0,p.z)-height_at(p.x-2.0,p.z))*.25
	var sz:=(height_at(p.x,p.z+2.0)-height_at(p.x,p.z-2.0))*.25
	return Vector2(sx,sz).length()<.65

static func site_clear(p: Vector2,margin:=0.0) -> bool:
	if p.x < -650.0 or p.x > 650.0 or p.y < -550.0 or p.y > 505.0:return false
	if p.x > 510.0 and p.y > 420.0:return false
	if primary_distance(p)<14.5+margin:return false
	for z in CROSS_STREETS:
		if absf(p.y-z)<7.0+margin:return false
	for x in VERTICAL_STREETS:
		if absf(p.x-x)<6.0+margin:return false
	for base in BASES_2D:
		if p.distance_to(base)<61.0+margin:return false
	for target in OBJECTIVES_2D:
		if p.distance_to(target)<33.0+margin:return false
	return true

func build() -> void:
	var begun:=Time.get_ticks_msec()
	set_meta("sector_colliders",true)
	set_meta("war_detail_lod",true)
	set_meta("use_occluders",false)
	for iz in 15:
		for ix in 15:_terrain_tile(ix,iz)
	var kit:=EnvironmentKit.new(self,render_visuals,85.0)
	_roads(kit)
	_bases(kit)
	var count:=_neighborhoods(kit)
	_landmarks(kit)
	_vegetation(kit)
	kit.flush()
	if render_visuals:_atmosphere()
	build_metrics={"area_m":1500,"terrain_tiles":225,"houses":count,
		"collision_shapes":kit.collision_count,"visual_instances":kit.detail_count,
		"build_ms":Time.get_ticks_msec()-begun,"visuals":render_visuals}
	set_meta("favela_build_metrics",build_metrics)

func _ground_color(x: float,z: float) -> Color:
	if z < -580.0:return Color("637b52")
	if z > 480.0:return Color("9a9688")
	if road_distance(Vector2(x,z))<9.0:return Color("817a70")
	return Color("9b8877") if posmod(int(floor(x/60.0)),3)==0 else Color("8e8175")

func _terrain_tile(ix: int,iz: int) -> void:
	var corner:=Vector3(ix*TILE-HALF,0,iz*TILE-HALF)
	var verts:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray()
	for z in GRID:
		for x in GRID:
			var wx:=corner.x+x*STEP;var wz:=corner.z+z*STEP
			verts.append(Vector3(x*STEP,height_at(wx,wz),z*STEP))
			if render_visuals:
				normals.append(Vector3(height_at(wx-2,wz)-height_at(wx+2,wz),4.0,
					height_at(wx,wz-2)-height_at(wx,wz+2)).normalized())
				colors.append(_ground_color(wx,wz))
	var indices:=PackedInt32Array()
	var faces:=PackedVector3Array()
	for z in GRID-1:
		for x in GRID-1:
			var a:=z*GRID+x;var b:=a+1;var c:=a+GRID;var e:=c+1
			for i in [a,c,b,b,c,e]:
				indices.append(i);faces.append(verts[i])
	var body:=StaticBody3D.new()
	body.name="FavelaTerrain_%02d_%02d"%[ix,iz];body.position=corner
	body.collision_layer=1;body.collision_mask=0;body.set_meta("surface","dirt")
	add_child(body)
	var shape:=ConcavePolygonShape3D.new();shape.set_faces(faces);shape.backface_collision=true
	var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
	if not render_visuals:return
	if ground_material==null:
		ground_material=StandardMaterial3D.new()
		ground_material.vertex_color_use_as_albedo=true
		ground_material.roughness=1.0
		ground_material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=verts
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var view:=MeshInstance3D.new();view.name="Surface";view.mesh=mesh
	view.material_override=ground_material
	view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(view)

func _road_strip(anchors: Array,width: float) -> void:
	if not render_visuals:return
	var verts:=PackedVector3Array();var indices:=PackedInt32Array()
	for i in anchors.size()-1:
		var a: Vector2=anchors[i];var b: Vector2=anchors[i+1]
		var dir: Vector2=(b-a).normalized();var side:=Vector2(-dir.y,dir.x)
		var length:=a.distance_to(b);var steps:=maxi(1,ceili(length/5.0))
		for s in steps:
			var p0:=a.lerp(b,float(s)/float(steps))
			var p1:=a.lerp(b,float(s+1)/float(steps))
			var start:=verts.size()
			for point2 in [p0-side*width*.5,p0+side*width*.5,
					p1-side*width*.5,p1+side*width*.5]:
				verts.append(point(point2.x,point2.y)+Vector3.UP*.09)
			indices.append_array(PackedInt32Array([start,start+1,start+2,
				start+1,start+3,start+2]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=verts;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	if asphalt_material==null:
		asphalt_material=StandardMaterial3D.new()
		asphalt_material.albedo_color=Color("555451")
		asphalt_material.roughness=1.0
		asphalt_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var view:=MeshInstance3D.new();view.name="AsfaltoPrincipal";view.mesh=mesh
	view.material_override=asphalt_material;view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)

func _roads(k: EnvironmentKit) -> void:
	_road_strip(PRIMARY,12.0)
	for z in CROSS_STREETS:_road_strip([Vector2(-640,z),Vector2(640,z)],8.0)
	for x in VERTICAL_STREETS:_road_strip([Vector2(x,-550),Vector2(x,500)],6.0)
	# Linhas centrais descontínuas, totalmente cosméticas e sem sombra.
	for i in PRIMARY.size()-1:
		var a: Vector2=PRIMARY[i];var b: Vector2=PRIMARY[i+1]
		var delta:=b-a;var distance:=delta.length()
		for s in range(1,int(distance/16.0)):
			var p:=a+delta.normalized()*float(s*16)
			var yaw:=atan2(delta.x,delta.y)
			k.box("FaixaPrincipal",point(p.x,p.y)+Vector3.UP*.115,
				Vector3(.14,.025,6),"plaster:dad0a0",false,Vector3(0,yaw,0),true)

func _bases(k: EnvironmentKit) -> void:
	for team in 2:
		var c: Vector2=BASES_2D[team]
		var floor:=point(c.x,c.y)
		var finish: String="concrete:626e79" if team==0 else "brick:8f4f4b"
		k.box("PátioBase",floor+Vector3(0,.04,0),Vector3(66,.12,63),
			"concrete:8b8980",true)
		for side in [-1.0,1.0]:
			k.box("MuroBase",floor+Vector3(side*33,2,0),Vector3(.7,4,61),finish,true)
		k.box("FundoBase",floor+Vector3(0,2,-31),Vector3(65,4,.7),finish,true)
		for side in [-1.0,1.0]:
			k.box("PortãoLateral",floor+Vector3(side*23,2,31),
				Vector3(20,4,.65),finish,true)
		k.box("SalaOperacional",floor+Vector3(-18,3,-17),
			Vector3(17,6,12),finish,true)
		k.box("CoberturaBase",floor+Vector3(-18,6.05,-17),
			Vector3(18,.24,13),"concrete:ccc2ad",true)
		k.sign_text("BASE POLÍCIA" if team==0 else "BASE VERMELHA",
			floor+Vector3(0,4,29),6,0.0)
		if team==0:
			for x in [1.0,16.0]:
				k.box("VagaGuarani",floor+Vector3(x,.14,0),Vector3(8,.025,16),
					"asphalt:777c80",false)

func _neighborhoods(k: EnvironmentKit) -> int:
	var rng:=RandomNumberGenerator.new();rng.seed=SEED
	var count:=0
	for rz in 61:
		var z: float=-535.0+float(rz)*17.15
		for cx in 75:
			var x: float=-638.0+float(cx)*17.2
			var p:=Vector2(x+rng.randf_range(-1.3,1.3),
				z+rng.randf_range(-1.1,1.1))
			var width:=rng.randf_range(10.0,14.6)
			var depth:=rng.randf_range(9.4,14.3)
			if not site_clear(p,maxf(width,depth)*.46):continue
			var roll:=rng.randf()
			var storeys:=1+int(rng.randi_range(0,3))
			if roll<.07:storeys=5
			if z>420:storeys=mini(storeys,2)
			var base:=point(p.x,p.y)
			var palette:=["plaster:c9b29a","plaster:a9a39a","brick:a66b55",
				"plaster:d0baa0","plaster:beb4a5","concrete:928d84",
				"plaster:a7b3ae","brick:965e50"]
			var finish: String=palette[int(rng.randi_range(0,palette.size()-1))]
			var open_house:=count%39==0 and storeys<=2
			_house(k,base,width,depth,storeys,finish,count,open_house)
			count+=1
	return count

func _house(k: EnvironmentKit,ground: Vector3,w: float,d: float,
	storeys: int,finish: String,index: int,open_house: bool) -> void:
	var height: float=float(storeys)*3.15
	var roof_color: String="concrete:a29c90"
	if open_house:
		# Acesso verdadeiro: entrada aberta, paredes, teto e laje com colisão.
		var wall_height:=3.1
		for side in [-1.0,1.0]:
			k.box("CasaParedeLateral",ground+Vector3(side*w*.5,wall_height*.5,0),
				Vector3(.28,wall_height,d),finish,true)
			k.box("CasaParedeFrente",ground+Vector3(side*(w+2.2)*.25,wall_height*.5,d*.5),
				Vector3((w-2.2)*.5,wall_height,.28),finish,true)
		k.box("ParedeFundo",ground+Vector3(0,wall_height*.5,-d*.5),
			Vector3(w,wall_height,.3),finish,true)
		k.box("PortaVerga",ground+Vector3(0,2.76,d*.5),
			Vector3(2.5,.6,.3),finish,true)
		k.box("LajeAcessivel",ground+Vector3(0,3.15,0),
			Vector3(w+.3,.28,d+.3),roof_color,true)
		for step in 13:
			var t:=float(step)/12.0
			k.box("EscadaLaje",ground+Vector3(-w*.5-1.35,0.15+float(step)*.24,
				d*.5-2.0-t*(d-3.5)),Vector3(1.1,.3, .80),
				"concrete:928b80",true)
		height=3.15
	else:
		# Massa fechada: a colisão tem a mesma extensão da fachada.
		k.box("CasaFavela",ground+Vector3(0,height*.5-.65,0),
			Vector3(w,height+1.3,d),finish,true)
		k.box("Laje",ground+Vector3(0,height+.07,0),
			Vector3(w+.6,.16,d+.6),roof_color,false)
	for side in [-1.0,1.0]:
		k.box("Platibanda",ground+Vector3(side*w*.5,height+.38,0),
			Vector3(.22,.7,d+.4),"concrete:9b9387",false)
	if index%3!=0:
		k.box("Portão",ground+Vector3(-w*.16,1.35,d*.5+.04),
			Vector3(2.15,2.65,.055),"steel:484942",false)
	if index%5==0:
		k.box("TijoloExposto",ground+Vector3(w*.28,height*.65,d*.5+.045),
			Vector3(w*.28,height*.35,.035),"brick:92594b",false)
	for floor in storeys:
		if floor==0 and open_house:continue
		var y:=float(floor)*3.15+1.85
		k.box("JanelaFrente",ground+Vector3(w*.21,y,d*.5+.06),
			Vector3(1.05,1.12,.035),"steel:343c3f",false)
		if floor%2==0:
			k.box("JanelaLateral",ground+Vector3(w*.5+.06,y,-d*.2),
				Vector3(.045,1.0,1.05),"steel:454c4c",false)
	if index%7==0:
		k.cylinder("CaixaAgua",ground+Vector3(-w*.22,height+1.04,-d*.25),
			.67,1.60,"steel:386c92",false)
	if index%13==0:
		for post in [-1.0,1.0]:
			k.box("ColunaObra",ground+Vector3(post*w*.37,height+.65,-d*.33),
				Vector3(.3,1.3,.3),"concrete:adaba2",false)
	if index%17==0:
		k.box("Varal",ground+Vector3(0,height+1.0,d*.05),
			Vector3(w*.55,.025,.035),"steel:727470",false)
		for n in 3:
			k.box("Roupa",ground+Vector3(-1.7+n*1.6,height+.62,d*.05),
				Vector3(.65,.78,.04),"fabric:9e554b" if n%2==0 else "fabric:5779a0",false)

func _landmarks(k: EnvironmentKit) -> void:
	for i in OBJECTIVES_2D.size():
		var p: Vector2=OBJECTIVES_2D[i]
		var anchor:=point(p.x,p.y)
		k.box("PisoPonto",anchor+Vector3(0,.05,0),Vector3(28,.12,23),
			"concrete:999389",true)
		k.cylinder("MastroObjetivo",anchor+Vector3(0,2.3,0),.07,4.6,
			"steel:5d6162",false)
		k.sign_text(str(["A","B","C","D","E"][i])+" · "+
			str(["ENTRADA","ESCADARIA","PRAÇA","LAJES","RESERVATÓRIO"][i]),
			anchor+Vector3(0,4.7,0),3.5)
		for side in [-1.0,1.0]:
			k.box("CoberturaObjetivo",anchor+Vector3(side*11,0.8,8),
				Vector3(3.5,1.6,1.4),"brick:956455",true)
		if i==2:
			k.box("QuadraPiso",anchor+Vector3(9,.045,-18),
				Vector3(22,.1,16),"concrete:8c9382",false)
		if i==4:
			k.cylinder("Reservatorio",anchor+Vector3(17,5,-12),5,10,
				"concrete:a7aaa2",true)
	# Contexto de combate: carros carbonizados, pneus, cimento e barricadas.
	for i in 36:
		var p: Vector2
		if i%3==0:
			p=PRIMARY[mini(int(i/3),PRIMARY.size()-1)]+Vector2(8,7)
		else:
			p=OBJECTIVES_2D[i%5]+Vector2(float((i*11)%31-15),float((i*7)%33-16))
		var pos:=point(p.x,p.y)
		if i%4==0:
			k.box("CarroQueimado",pos+Vector3(0,.65,0),Vector3(3.7,1.3,1.8),
				"steel:33302c",true,Vector3(0,float(i)*.4,0))
			k.box("CarroTeto",pos+Vector3(.1,1.46,0),Vector3(1.8,.5,1.5),
				"steel:2a2927",false,Vector3(0,float(i)*.4,0))
		else:
			for stack in 3:
				k.cylinder("BarricadaPneus",pos+Vector3((stack%2)*1.0,0.24+stack*.46,0),
					.7,.45,"steel:252626",true)
		if i%6==0:
			for j in 8:
				k.box("TijolosEntulho",pos+Vector3(3.0+(j%4)*.3,.15+(j/4)*.24,1.5),
					Vector3(.30,.22,.18),"brick:9b6353",false)
	# Assets autorais reutilizaveis, integrados sem tocar no mapa da Ucrania.
	for i in 5:
		var q: Vector2=OBJECTIVES_2D[i]+Vector2(32.0,19.0)
		var housing:=WarMapContent.instantiate(self,
			"res://modes/war/library/favela_casa_laje.tscn",point(q.x,q.y),render_visuals)
		housing.name="CasaAutorada_"+str(i)
		var tyre: Vector2=OBJECTIVES_2D[i]+Vector2(-13.0,11.0)
		var barricade:=WarMapContent.instantiate(self,
			"res://modes/war/library/favela_barricada_pneus.tscn",
			point(tyre.x,tyre.y),render_visuals)
		barricade.name="PneusAutorados_"+str(i)
	for i in 35:
		var z:=420.0-float(i)*27.0
		var x:=530.0 if i%2==0 else -560.0
		var p:=point(x,z)
		k.cylinder("Poste",p+Vector3.UP*4.4,.11,8.8,"steel:686864",false)
		k.box("Transformador",p+Vector3.UP*7.4,Vector3(.55,.5,.45),
			"steel:878780",false)

func _vegetation(k: EnvironmentKit) -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=SEED+91
	for i in 340:
		var x:=rng.randf_range(-715,715)
		var z:=rng.randf_range(-745,-585) if i<260 else rng.randf_range(-735,735)
		if i>=260 and absf(x)<650 and z>-555:continue
		var p:=point(x,z)
		if primary_distance(Vector2(x,z))<13.0:continue
		var size:=rng.randf_range(3.0,8.5)
		k.cylinder("Tronco",p+Vector3.UP*size*.36,.19,size*.72,
			"wood:584f3d",i%9==0)
		for level in 3:
			k.box("Copa",p+Vector3(0,size*.72+level*.68,0),
				Vector3(size*.68-level*.6,1.4,size*.65-level*.55),
				"fabric:48734c" if i%3!=0 else "fabric:628352",false,
				Vector3(0,float(i)*.25,0),true)

func _atmosphere() -> void:
	var world:=WorldEnvironment.new()
	var env:=Environment.new()
	var sky_mat:=ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("5889ad")
	sky_mat.sky_horizon_color=Color("d5b69c")
	sky_mat.ground_horizon_color=Color("9d988a")
	sky_mat.ground_bottom_color=Color("454c3a")
	var sky:=Sky.new();sky.sky_material=sky_mat
	env.background_mode=Environment.BG_SKY;env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("d8c6aa");env.ambient_light_energy=.49
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.fog_enabled=true;env.fog_light_color=Color("b7ae9e")
	env.fog_density=.00025;env.fog_sky_affect=.45
	world.environment=env;add_child(world)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-43,-28,0)
	sun.light_color=Color("ffe3b9")
	sun.light_energy=.86
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=190
	add_child(sun)
