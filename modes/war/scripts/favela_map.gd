extends Node3D
class_name WarFavelaMap
## Favela ficticia 1.5 x 1.5 km. A mesma fonte deterministica de terreno,
## vias, lotes e coberturas alimenta cliente, servidor e testes.
## A arquitetura usa EnvironmentKit: MultiMesh em celulas e colisores setorizados.
const HALF := 750.0
const TILE := 100.0
const STEP := 5.0
const GRID := 21
const HALF_STEPS := 150
const SAMPLE_WIDTH := HALF_STEPS*2+1
const SEED := 241106
const AVENUE_WIDTH := 10.5
const CROSS_WIDTH := 6.8
const ALLEY_WIDTH := 3.8
const MINI_STREET_WIDTH := 2.8
const COMMERCE := preload("res://modes/war/library/favela_comercio_fachada.tscn")
const POLE := preload("res://modes/war/library/favela_poste_cabos.tscn")
const CABLE := preload("res://modes/war/library/favela_rede_aerea.tscn")
const ARCHITECTURE := preload("res://modes/war/scripts/favela_architecture.gd")
const LAYOUT := preload("res://modes/war/scripts/favela_layout.gd")
const STREET_ART := preload("res://modes/war/scripts/favela_street_art.gd")
const PARKED_BIKE := preload("res://modes/war/library/favela_moto_estacionada.tscn")
const PRIMARY := [
	Vector2(-470,600),Vector2(-460,490),Vector2(-395,420),
	Vector2(-285,330),Vector2(-225,245),Vector2(-170,140),
	Vector2(-95,35),Vector2(20,-80),Vector2(135,-200),
	Vector2(210,-325),Vector2(260,-440),Vector2(315,-570)
]
const CROSS_STREETS := [340.0,165.0,-15.0,-200.0,-395.0]
const VERTICAL_STREETS := [-520.0,-320.0,-105.0,105.0,355.0,560.0]
const MINI_STREETS := [
	[Vector2(-320,165),Vector2(-292,144),Vector2(-301,108),Vector2(-274,76),Vector2(-282,36),Vector2(-256,-15)],
	[Vector2(-105,-15),Vector2(-132,-46),Vector2(-139,-82),Vector2(-121,-122),Vector2(-140,-164),Vector2(-105,-200)],
	[Vector2(-520,165),Vector2(-482,137),Vector2(-491,96),Vector2(-466,69),Vector2(-462,33),Vector2(-431,-15)],
	[Vector2(105,-200),Vector2(139,-226),Vector2(135,-263),Vector2(172,-298),Vector2(163,-344),Vector2(182,-395)],
	[Vector2(355,-395),Vector2(398,-370),Vector2(417,-323),Vector2(407,-289),Vector2(443,-243),Vector2(453,-200)],
	[Vector2(105,165),Vector2(127,144),Vector2(114,111),Vector2(147,83),Vector2(134,35),Vector2(153,-15)]
]
const BASES_2D := [Vector2(-470,590),Vector2(280,-500)]
const OBJECTIVES_2D := [
	Vector2(-265,345),Vector2(-440,35),Vector2(-85,-20),
	Vector2(270,-205),Vector2(-290,-405)
]
var render_visuals := true
var build_metrics: Dictionary = {}
var street_fixtures: Node3D
var store_count:=0
var pole_count:=0
var cable_count:=0
var parked_bikes:=0
var tag_count:=0
var litter_count:=0
var shop_connections: Array[Vector3]=[]
var house_connections: Array[Vector3]=[]
var roof_paths: Array[PackedVector3Array]=[]
var parked_cars:=0
var service_drops:=0
var facade_modules:=0
var roof_modules:=0
var lean_tos:=0
var underpasses:=0

static var ground_material: StandardMaterial3D
static var terrain_samples := PackedFloat32Array()
static var housing_lots: Array[Dictionary]=[]

static func _landform(x: float,z: float) -> float:
	var north:=clampf((575.0-z)/1170.0,0.0,1.0)
	var height:=23.0+128.0*north
	height+=1.9*sin(x*.012)*sin(z*.010)+1.05*cos(x*.026+z*.014)
	var p:=Vector2(x,z)
	var grade:=smoothstep(7.5,32.0,primary_distance(p))
	for cross: float in CROSS_STREETS:
		grade=minf(grade,smoothstep(4.0,19.0,absf(z-cross)))
	for alley: float in VERTICAL_STREETS:
		grade=minf(grade,smoothstep(2.5,13.0,absf(x-alley)))
	grade=minf(grade,smoothstep(1.6,10.0,_mini_street_distance(p,10.0)))
	var urban_hill:=smoothstep(490.0,680.0,575.0-z)
	var ridges:=8.0*sin(x*.012+z*.009)+4.6*cos(z*.056+x*.018)
	height+=ridges*grade*(.4+.6*urban_hill)
	var woods:=1.0-smoothstep(-745.0,-565.0,z)
	height+=woods*(19.0+9.0*sin(x*.011))*grade
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

static func _height_sample(x: int,z: int) -> float:
	if absi(x)>HALF_STEPS or absi(z)>HALF_STEPS:return _natural(x*STEP,z*STEP)
	if terrain_samples.is_empty():
		terrain_samples.resize(SAMPLE_WIDTH*SAMPLE_WIDTH)
		for row in SAMPLE_WIDTH:
			for col in SAMPLE_WIDTH:
				terrain_samples[row*SAMPLE_WIDTH+col]=_natural(
					(col-HALF_STEPS)*STEP,(row-HALF_STEPS)*STEP)
	return terrain_samples[(z+HALF_STEPS)*SAMPLE_WIDTH+x+HALF_STEPS]

static func height_at(x: float,z: float) -> float:
	# Amostragem triangular igual aos vertices da malha fisica de 5 m.
	var ix:=floori(x/STEP);var iz:=floori(z/STEP)
	var u:=x/STEP-float(ix);var v:=z/STEP-float(iz)
	var a:=_height_sample(ix,iz)
	var b:=_height_sample(ix+1,iz)
	var c:=_height_sample(ix,iz+1)
	var e:=_height_sample(ix+1,iz+1)
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

static func _mini_street_distance(p: Vector2,limit: float) -> float:
	var result:=limit
	for route: Array in MINI_STREETS:
		if p.y<minf(route[0].y,route[-1].y)-limit or p.y>maxf(route[0].y,route[-1].y)+limit:
			continue
		for i in route.size()-1:
			var a: Vector2=route[i]
			var b: Vector2=route[i+1]
			if p.x<minf(a.x,b.x)-limit or p.x>maxf(a.x,b.x)+limit:continue
			result=minf(result,_segment_distance(p,a,b))
	return result

static func road_distance(p: Vector2) -> float:
	var result:=primary_distance(p)
	for z in CROSS_STREETS:result=minf(result,absf(p.y-z))
	for x in VERTICAL_STREETS:result=minf(result,absf(p.x-x))
	var mini:=_mini_street_distance(p,13.0)
	return minf(result,mini) if mini<13.0 else result

static func accessible(p: Vector3) -> bool:
	if absf(p.x)>HALF-20.0 or absf(p.z)>HALF-20.0:return false
	var sx:=(height_at(p.x+2.0,p.z)-height_at(p.x-2.0,p.z))*.25
	var sz:=(height_at(p.x,p.z+2.0)-height_at(p.x,p.z-2.0))*.25
	return Vector2(sx,sz).length()<.65

static func road_envelopes() -> Array[Dictionary]:
	var roads: Array[Dictionary]=[{"id":0,"points":PRIMARY,"width":AVENUE_WIDTH}]
	for z: float in CROSS_STREETS:
		roads.append({"id":roads.size(),"points":[Vector2(-640,z),Vector2(640,z)],"width":CROSS_WIDTH})
	for x: float in VERTICAL_STREETS:
		roads.append({"id":roads.size(),"points":[Vector2(x,-550),Vector2(x,500)],"width":ALLEY_WIDTH})
	for route: Array in MINI_STREETS:
		roads.append({"id":roads.size(),"points":route,"width":MINI_STREET_WIDTH})
	return roads

static func housing_plan() -> Array[Dictionary]:
	if housing_lots.is_empty():
		housing_lots=LAYOUT.generate(road_envelopes(),BASES_2D,OBJECTIVES_2D)
	return housing_lots

func build() -> void:
	var begun:=Time.get_ticks_msec()
	set_meta("sector_colliders",true)
	set_meta("war_detail_lod",true)
	set_meta("use_occluders",false)
	for iz in 15:
		for ix in 15:_terrain_tile(ix,iz)
	var kit:=EnvironmentKit.new(self,render_visuals,85.0)
	street_fixtures=Node3D.new()
	street_fixtures.name="InfraestruturaUrbana"
	add_child(street_fixtures)
	_roads(kit)
	_bases(kit)
	var neighborhood:=_neighborhoods(kit)
	_landmarks(kit)
	_street_wiring(kit)
	_vegetation(kit)
	kit.flush()
	if render_visuals:
		STREET_ART.paint_walls(self)
		WarSceneryBatch.build(street_fixtures)
		_atmosphere()
	build_metrics={"area_m":1500,"terrain_tiles":225,
		"collision_shapes":kit.collision_count,"visual_instances":kit.detail_count,
		"storefronts":store_count,"utility_poles":pole_count,"wire_spans":cable_count,
		"wall_tags":tag_count,"litter_clusters":litter_count,"parked_cars":parked_cars,
		"service_drops":service_drops,"facade_modules":facade_modules,"roof_modules":roof_modules,
		"covered_passages":underpasses,"roof_lean_tos":lean_tos,
		"parked_bikes":parked_bikes,"build_ms":Time.get_ticks_msec()-begun,"visuals":render_visuals}
	build_metrics.merge(neighborhood)
	set_meta("favela_build_metrics",build_metrics)

func _ground_color(x: float,z: float) -> Color:
	var mix:=.5+.5*sin(x*.073+z*.052)*cos(z*.019)
	var soil:=Color("827665").lerp(Color("9b856e"),mix)
	var urban:=1.0-smoothstep(530.0,665.0,absf(x))
	urban*=smoothstep(-570.0,-530.0,z)*(1.0-smoothstep(400.0,505.0,z))
	var paving:=Color("666b6e").lerp(Color("8a8e8d"),mix)
	if road_distance(Vector2(x,z))<7.0:paving=paving.darkened(.10)
	return soil.lerp(paving,urban).lerp(Color("59654a").lerp(Color("444a35"),mix),
		1.0-smoothstep(-620.0,-555.0,z))

func _terrain_tile(ix: int,iz: int) -> void:
	var corner:=Vector3(ix*TILE-HALF,0,iz*TILE-HALF)
	var verts:=PackedVector3Array();var normals:=PackedVector3Array()
	var colors:=PackedColorArray();var uvs:=PackedVector2Array()
	for z in GRID:
		for x in GRID:
			var wx:=corner.x+x*STEP;var wz:=corner.z+z*STEP
			verts.append(Vector3(x*STEP,height_at(wx,wz),z*STEP))
			if render_visuals:
				normals.append(Vector3(height_at(wx-2,wz)-height_at(wx+2,wz),4.0,
					height_at(wx,wz-2)-height_at(wx,wz+2)).normalized())
				colors.append(_ground_color(wx,wz))
				uvs.append(Vector2(wx,wz)*.23)
	var indices:=PackedInt32Array()
	var faces:=PackedVector3Array()
	for z in GRID-1:
		for x in GRID-1:
			var a:=z*GRID+x;var b:=a+1;var c:=a+GRID;var e:=c+1
			for i in [a,c,b,b,c,e]:faces.append(verts[i])
			# Godot renders clockwise front faces; keep the existing physics triangles.
			if render_visuals:indices.append_array(PackedInt32Array([a,b,c,b,e,c]))
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
		ground_material.vertex_color_is_srgb=true
		ground_material.albedo_texture=EnvironmentKit.material("concrete").albedo_texture
		ground_material.roughness=1.0
		ground_material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=verts
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var view:=MeshInstance3D.new();view.name="Surface";view.mesh=mesh
	view.material_override=ground_material
	view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(view)

func _road_strip(anchors: Array,width: float,verge: bool=false) -> void:
	if not render_visuals:return
	var verts:=PackedVector3Array();var indices:=PackedInt32Array()
	var normals:=PackedVector3Array();var uvs:=PackedVector2Array()
	var wear:=PackedColorArray()
	var edges: Array[Vector2]=[]
	var columns:=ceili(width/1.25)
	for i in anchors.size():
		var before: Vector2=(anchors[i]-anchors[maxi(i-1,0)]).normalized()
		var after: Vector2=(anchors[mini(i+1,anchors.size()-1)]-anchors[i]).normalized()
		var bisector: Vector2=(before+after).normalized()
		edges.append(-bisector.orthogonal()/maxf(.7,bisector.dot(after if after!=Vector2.ZERO else before)))
	for i in anchors.size()-1:
		var a: Vector2=anchors[i];var b: Vector2=anchors[i+1]
		var steps:=maxi(1,ceili(a.distance_to(b)/1.25))
		for row in range(0 if i==0 else 1,steps+1):
			var t:=float(row)/steps
			var center:=a.lerp(b,t)
			var side:=edges[i].lerp(edges[i+1],t)
			var rough_edge:=width+.42*sin(center.x*.22+center.y*.16)
			var start:=verts.size()
			for col in columns+1:
				var p:=center+side*rough_edge*(float(col)/columns-.5)
				verts.append(point(p.x,p.y)+Vector3.UP*.16)
				normals.append(Vector3.UP)
				uvs.append(p*.55)
				var patch:=sin(p.x*.65+p.y*.37)*cos(p.y*.51-p.x*.18)
				wear.append(Color("b6b0a6").lerp(Color("edebe2"),smoothstep(-.3,.65,patch)))
				if start>0 and col<columns:
					var near:=start+col
					var far:=near-columns-1
					indices.append_array(PackedInt32Array([far,near,far+1,
						far+1,near,near+1]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=verts;arrays[Mesh.ARRAY_INDEX]=indices
	arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_COLOR]=wear
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var view:=MeshInstance3D.new();view.name="Passagem" if verge else "Asfalto";view.mesh=mesh
	view.material_override=STREET_ART.paving(verge)
	view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)

func _roads(k: EnvironmentKit) -> void:
	_road_strip(PRIMARY,AVENUE_WIDTH)
	for z in CROSS_STREETS:_road_strip([Vector2(-640,z),Vector2(640,z)],CROSS_WIDTH)
	for x in VERTICAL_STREETS:_road_strip([Vector2(x,-550),Vector2(x,500)],ALLEY_WIDTH,true)
	for route: Array in MINI_STREETS:_road_strip(route,MINI_STREET_WIDTH)
	# A pintura gasta só aparece no acesso asfaltado, antes da encosta.
	for i in 2:
		var a: Vector2=PRIMARY[i];var b: Vector2=PRIMARY[i+1]
		var direction: Vector2=(b-a).normalized()
		for s in range(1,int(a.distance_to(b)/18.0)):
			var p:=a+direction*float(s*18)
			var tilt:=atan2(height_at(p.x-direction.x,p.y-direction.y)
				-height_at(p.x+direction.x,p.y+direction.y),2.0)
			k.box("FaixaGasta",point(p.x,p.y)+Vector3.UP*.19,
				Vector3(.12,.02,2.0),"plaster:a79670",false,
				Vector3(tilt,atan2(direction.x,direction.y),0),true)

func _avenue_gate_offset(center: Vector2,wall_z: float) -> float:
	var z:=center.y+wall_z
	for i in PRIMARY.size()-1:
		var a: Vector2=PRIMARY[i]
		var b: Vector2=PRIMARY[i+1]
		if z<=a.y and z>=b.y:
			return lerpf(a.x,b.x,inverse_lerp(a.y,b.y,z))-center.x
	return 0.0

func _bases(k: EnvironmentKit) -> void:
	for team in 2:
		var c: Vector2=BASES_2D[team]
		var floor:=point(c.x,c.y)
		var finish: String="concrete:626e79" if team==0 else "brick:8f4f4b"
		k.box("PátioBase",floor+Vector3(0,.04,0),Vector3(66,.12,63),
			"concrete:8b8980",true)
		for side in [-1.0,1.0]:
			k.box("MuroBase",floor+Vector3(side*33,2,0),Vector3(.7,4,61),finish,true)
		for wall_z in [-31.0,31.0]:
			var gate:=_avenue_gate_offset(c,wall_z)
			for wall in [Vector2(-33,gate-12),Vector2(gate+12,33)]:
				k.box("MuroPortao",floor+Vector3((wall.x+wall.y)*.5,2,wall_z),
					Vector3(wall.y-wall.x,4,.7),finish,true)
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

func _neighborhoods(k: EnvironmentKit) -> Dictionary:
	var count:=0
	var stacked:=0
	var roofs:=0
	var bridges:=0
	var pulled:=0
	var compact:=0
	var forecourts:=0
	var previous_roof:=Vector3.INF
	var previous_roof_center:=Vector3.INF
	var previous_lot: Dictionary={}
	for lot: Dictionary in housing_plan():
		var p: Vector2=lot.position
		var size: Vector2=lot.size
		var half_lot:=size*.5
		var base:=point(p.x,p.y)
		var min_ground:=base.y
		var max_ground:=base.y
		for corner: Vector2 in [Vector2(-1,1),Vector2(1,1),Vector2(-1,-1),Vector2(1,-1)]:
			var at:=p+corner*half_lot
			var ground:=height_at(at.x,at.y)
			min_ground=minf(min_ground,ground)
			max_ground=maxf(max_ground,ground)
		var adjacent:=not previous_lot.is_empty() and int(previous_lot.row)==int(lot.row) and int(previous_lot.column)+1==int(lot.column)
		var roof_pair: bool=not lot.sparse and int(lot.row)%4==2 and int(lot.column)%6 in [2,3] and float(lot.edge.gap)>1.35
		var open_house: bool=lot.stair_clear and max_ground-min_ground<2.45 and (
			roof_pair or (int(lot.profile)==0 and count%5==0 and float(lot.edge.gap)>1.35))
		var storeys: int=lot.storeys
		var upper_storeys:=mini(storeys-1,2) if storeys>=2 and int(lot.profile)!=3 and not open_house else 0
		_house(k,base,size.x,size.y,storeys,lot.finish,count,open_house,base.y-min_ground+.35,upper_storeys,lot)
		var market:=absf(base.z+15)<25.0 and absf(base.x)<360.0
		var shop_interval:=2 if market else 4
		if not open_house and not lot.sparse and count%shop_interval==0:
			_commercial_front(k,base,half_lot,count,lot)
		if upper_storeys>0:stacked+=1
		if open_house:roofs+=1
		if lot.moved:pulled+=1
		if float(lot.edge.gap)<1.0:compact+=1
		if lot.pocket and float(lot.edge.gap)<3.0 and float(lot.edge.gap)>2.2:forecourts+=1
		if roof_pair and open_house:
			var roof_height:=base.y+3.01
			var roof_edge:=Vector3(base.x-size.x*.5,roof_height,base.z-size.y*.5+.46)
			var gap:=roof_edge.x-previous_roof.x
			if (adjacent and previous_roof.is_finite() and gap>.45 and gap<5.4
					and absf(previous_roof.y-roof_height)<gap*.42
					and absf(roof_edge.z-previous_roof.z)<1.45):
				_roof_bridge(k,previous_roof,roof_edge)
				roof_paths.append(PackedVector3Array([previous_roof_center,previous_roof,roof_edge,base+Vector3.UP*3.01]))
				bridges+=1
			previous_roof=Vector3(base.x+size.x*.5,roof_height,base.z-size.y*.5+.46)
			previous_roof_center=base+Vector3.UP*3.01
		else:previous_roof=Vector3.INF
		previous_lot=lot
		count+=1
	return {"houses":count,"stacked_houses":stacked,"walkable_roofs":roofs,"roof_bridges":bridges,
		"moved_frontages":pulled,"compact_frontages":compact,"open_forecourts":forecourts}

func _roof_bridge(k: EnvironmentKit,a: Vector3,b: Vector3) -> void:
	var horizontal:=Vector3(b.x-a.x,0,b.z-a.z).normalized()
	var side:=horizontal.cross(Vector3.UP)*.625
	var entry:=a-horizontal*.23
	var landing:=b+horizontal*.23
	var center:=(entry+landing)*.5
	var span:=landing-entry
	var yaw:=atan2(-span.z,span.x)
	var grade:=atan2(span.y,Vector2(span.x,span.z).length())
	k.box("PassarelaLajes",center-Vector3.UP*.08,Vector3(span.length(),.16,1.25),
		"wood:716251",false,Vector3(0,yaw,grade))
	# Vertical ends sit flush with both slabs, including when the deck slopes.
	var hull:=ConvexPolygonShape3D.new()
	var points:=PackedVector3Array()
	for end: Vector3 in [entry,landing]:
		for offset: Vector3 in [-side,side]:
			points.append(end+offset-center)
			points.append(end+offset-center-Vector3.UP*.16)
	hull.points=points
	k._collider("PassarelaLajes",hull,Transform3D(Basis.IDENTITY,center),"wood")

func _house(k: EnvironmentKit,ground: Vector3,w: float,d: float,
	storeys: int,finish: String,index: int,open_house: bool,foundation: float,
	upper_storeys: int,lot: Dictionary) -> void:
	const FLOOR := 2.85
	var roof_color: String="concrete:8f8577" if index%5!=0 else "concrete:706d64"
	var lower_storeys:=1 if open_house else storeys-upper_storeys
	var height:=float(lower_storeys)*FLOOR
	var profile: int=lot.profile
	var block: int=lot.block
	var street_side: Vector2=-Vector2(lot.edge.normal)
	var frontage:=Vector3(signf(street_side.x),0,0) if absf(street_side.x)>absf(street_side.y) else Vector3(0,0,signf(street_side.y))
	var upper_width: float=w*[.74,.67,.82,.70,.66][profile]
	var upper_depth: float=d*[.68,.79,.66,.69,.74][profile]
	var upper_offset:=Vector3((w-upper_width)*.37*(-1 if block%2 else 1),0,
		(d-upper_depth)*.38*(-1 if block<2 else 1))
	var facade_yaw:=atan2(frontage.x,frontage.z)
	var tangent:=Vector3(frontage.z,0,-frontage.x)
	var front_depth:=w if frontage.x!=0 else d
	var front_width:=d if frontage.x!=0 else w
	if open_house:
		var wall_height:=FLOOR+foundation
		var center_y:=(FLOOR-foundation)*.5
		for side in [-1.0,1.0]:
			k.box("CasaParedeLateral",ground+Vector3(side*w*.5,center_y,0),
				Vector3(.28,wall_height,d),finish,true)
			k.box("CasaParedeFrente",ground+Vector3(side*(w+2.2)*.25,center_y,d*.5),
				Vector3((w-2.2)*.5,wall_height,.28),finish,true)
		var through:=(profile in [0,2,4]
			and height_at(ground.x,ground.z-d*.5)<ground.y+.60
			and height_at(ground.x,ground.z+d*.5)<ground.y+.60)
		if through:
			for edge: float in [-1.0,1.0]:
				k.box("ParedePassagem",ground+Vector3(edge*(w+2.2)*.25,center_y,-d*.5),
					Vector3((w-2.2)*.5,wall_height,.3),finish,true)
			k.box("VergaPassagem",ground+Vector3(0,FLOOR-.18,-d*.5),
				Vector3(2.5,.36,.3),finish,true)
			underpasses+=1
		else:
			k.box("ParedeFundo",ground+Vector3(0,center_y,-d*.5),
				Vector3(w,wall_height,.3),finish,true)
		k.box("PortaVerga",ground+Vector3(0,FLOOR-.18,d*.5),
			Vector3(2.5,.36,.3),finish,true)
		k.box("LajeAcessivel",ground+Vector3(0,FLOOR,0),
			Vector3(w+.3,.28,d+.3),roof_color,true)
		var stair_x:=ground.x-w*.5-.64
		var stair_start_z:=ground.z+d*.5-1.0
		var stair_end_z:=ground.z-d*.5+2.45
		var stair_start_y:=height_at(stair_x,stair_start_z)+.11
		var landing_y:=ground.y+FLOOR+.14
		var run:=stair_start_z-stair_end_z
		var foot:=Vector3(stair_x,stair_start_y-.08,stair_start_z)
		var top:=Vector3(stair_x,landing_y,stair_end_z)
		var ramp_scale:=Vector3(1.0,(top.y-foot.y)/2.85,run/8.6)
		ARCHITECTURE.place(k,"escada_externa",Transform3D(Basis.from_scale(ramp_scale),foot),true)
		var landing:=Vector3(stair_x+.40,landing_y-.12,stair_end_z-.40)
		k.box("DesembarqueLaje",landing,Vector3(1.42,.24,1.0),roof_color,true)
		var approach:=point(foot.x,foot.z+.75)+Vector3.UP*.05
		var nav:=PackedVector3Array([approach,foot+Vector3.UP*.06])
		for step in range(1,5):
			nav.append(foot.lerp(top,step*.25)+Vector3.UP*.06)
		nav.append(landing+Vector3.UP*.18)
		nav.append(Vector3(ground.x-w*.5+.56,landing_y+.06,landing.z))
		nav.append(ground+Vector3.UP*3.01)
		roof_paths.append(nav)
	else:
		k.box("CasaFavela",ground+Vector3(0,(height-foundation)*.5,0),
			Vector3(w,height+foundation,d),finish,true)
		k.box("Laje",ground+Vector3(0,height-.07,0),
			Vector3(w+.46,.16,d+.46),roof_color,false)
	if upper_storeys>0:
		var added:=float(upper_storeys)*FLOOR
		var upper_finish: String="brick:985847" if index%3!=0 else finish
		k.box("Puxadinho",ground+upper_offset+Vector3(0,height+added*.5,0),
			Vector3(upper_width,added,upper_depth),upper_finish,true)
		k.box("LajeAlta",ground+upper_offset+Vector3(0,height+added-.06,0),
			Vector3(upper_width+.34,.18,upper_depth+.34),roof_color,false)
		if profile in [1,4] and not lot.sparse:
			var upper_face:=upper_width if frontage.x!=0 else upper_depth
			var balcony:=ground+upper_offset+Vector3.UP*(height+.11)+frontage*(upper_face*.5)+tangent*.85
			ARCHITECTURE.place(k,"sacada",Transform3D(Basis(Vector3.UP,facade_yaw),balcony),true)
			facade_modules+=1
	if not open_house:
		for side in [-1.0,1.0]:
			k.box("Platibanda",ground+Vector3(side*w*.5,height+.38,0),
				Vector3(.22,.7,d+.4),roof_color,false)
	if not open_house:
		var entrance:=ground+frontage*(front_depth*.5+.012)-tangent*front_width*.23
		entrance.y=height_at(entrance.x,entrance.z)
		if entrance.y+2.33<ground.y+height:
			ARCHITECTURE.place(k,"porta_entrada",Transform3D(Basis(Vector3.UP,facade_yaw),entrance))
			facade_modules+=1
	if not lot.sparse and float(lot.edge.gap)<4.0 and index%3==0:
		house_connections.append(ground+frontage*(front_depth*.5+.10)+tangent*.70+Vector3.UP*minf(height-.16,3.1))
	if not open_house and index%3==0:
		var side:=1.0 if index%2==0 else -1.0
		var wall:=ground+Vector3(side*(w*.5+.055),1.04,d*.24)
		wall.y=maxf(wall.y,height_at(wall.x,wall.z)+.5)
		if wall.y+1.25<ground.y+height:
			STREET_ART.tag(k,wall,side*PI*.5,index)
			tag_count+=1
		if index%12==0:
			_litter(Vector2(wall.x+side*.31,wall.z+.5),float(index)*.31)
	if index%9==0:
		var service_face:=ground+Vector3(w*.5+.055,0,d*.24)
		k.pipe(service_face+Vector3.UP*.18,service_face+Vector3.UP*(height-.1),
			.045,"steel:777870",false,false)
		k.box("Medidor",service_face+Vector3(0,1.55,.22),
			Vector3(.22,.30,.30),"steel:7e8278",false)
	for floor in (1 if open_house else storeys):
		var upper:=floor>=lower_storeys
		var origin:=ground+upper_offset if upper else ground
		var facade_width:=upper_width if upper else w
		var facade_depth:=upper_depth if upper else d
		var plane_depth:=facade_width if frontage.x!=0 else facade_depth
		var plane_width:=facade_depth if frontage.x!=0 else facade_width
		var y:=float(floor)*FLOOR+1.72
		var window_id: String="janela_madeira" if (profile+floor)%3==1 else "janela_grade"
		var position:=origin+Vector3.UP*y+frontage*(plane_depth*.5+.015)+tangent*plane_width*.23
		if not open_house or frontage!=Vector3(0,0,1):
			ARCHITECTURE.place(k,window_id,Transform3D(Basis(Vector3.UP,facade_yaw),position))
			facade_modules+=1
		if (profile+floor)%2==0 and not lot.sparse:
			var side_pos:=origin+Vector3.UP*y+tangent*(plane_width*.5+.015)-frontage*plane_depth*.22
			ARCHITECTURE.place(k,"janela_grade",Transform3D(Basis(Vector3.UP,facade_yaw+PI*.5),side_pos))
			facade_modules+=1
	var roof_y:=height+upper_storeys*FLOOR
	var roof_origin:=ground+(upper_offset if upper_storeys>0 else Vector3.ZERO)
	var shed: bool=not open_house and not lot.sparse and profile in [0,3] and (int(lot.row)+int(lot.column))%3==0
	if shed:
		var offset:=Vector3.UP*(roof_y+.02)+tangent*.85-frontage*.70
		ARCHITECTURE.place(k,"puxadinho_chapa",Transform3D(Basis(Vector3.UP,facade_yaw),roof_origin+offset),true)
		lean_tos+=1
	elif not lot.sparse and index%3==block%3:
		var scene: String="laje_obra" if profile in [1,2] else "laje_domestica"
		var offset:=Vector3(2.5,roof_y+.14,3.2) if open_house else Vector3.UP*(roof_y+.02)+tangent*1.6+frontage*.65
		var yaw:=0.0 if open_house else facade_yaw
		ARCHITECTURE.place(k,scene,Transform3D(Basis(Vector3.UP,yaw),roof_origin+offset),open_house)
		roof_modules+=1
	if not lot.sparse and index%9==0:
		var mast:=roof_origin+Vector3(w*.15,roof_y,-d*.18)
		k.beam(mast,mast+Vector3(.08,1.9,0),.047,.047,"steel:4b504c")
		for level in 3:
			k.box("Antena",mast+Vector3(.08,1.35+level*.20,0),
				Vector3(.95-level*.13,.036,.04),"steel:4b504c",false,Vector3(0,.4*index,0),true)

func _commercial_front(k: EnvironmentKit,ground: Vector3,half_lot: Vector2,index: int,lot: Dictionary) -> void:
	var center:=Vector2(ground.x,ground.z)
	var center_distance:=road_distance(center)
	if center_distance>16.0:return
	var best:=8.6
	var street_face:=Vector2.ZERO
	var edge:=center
	for direction: Vector2 in [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]:
		var candidate:=center+direction*half_lot.dot(direction.abs())
		var distance:=road_distance(candidate)
		if distance<2.35 or distance>=best or distance>center_distance-2.5:continue
		best=distance
		street_face=direction
		edge=candidate
	if street_face==Vector2.ZERO:return
	var door:=point(edge.x,edge.y)
	if door.y-ground.y>0.42 or door.y-ground.y< -2.1:return
	var shop:=WarMapContent.instantiate(street_fixtures,COMMERCE.resource_path,door,render_visuals)
	shop.rotation.y=atan2(street_face.x,street_face.y)
	store_count+=1
	var mark:=door-shop.basis.x*3.6+shop.basis.z*.065
	mark.y=maxf(door.y+1.08,ground.y+.7)
	STREET_ART.tag(k,mark,shop.rotation.y,index+store_count)
	tag_count+=1
	var trash:=door-shop.basis.x*2.55+shop.basis.z*.47
	_litter(Vector2(trash.x,trash.z),shop.rotation.y+.3)
	shop_connections.append(door+Vector3.UP*2.76)
	if render_visuals:
		var names:=["MERCEARIA","OFICINA DO BAIRRO","BAR DO ALTO","DEPÓSITO","ARMAZÉM","LANCHES"]
		var sign_node:=shop.get_node("Nome") as Label3D
		sign_node.text=names[store_count%names.size()]
		if sign_node.text.length()>13:sign_node.pixel_size=.0059
	if lot.pocket and float(lot.edge.gap)>2.65 and int(lot.edge.road)>0 and store_count%2==0:
		var parking:=edge+street_face*1.39-street_face.orthogonal()*3.35
		var curb_safe:=true
		for long: float in [-1.85,1.85]:
			for across: float in [-.98,.98]:
				if _on_paving(parking+street_face.orthogonal()*long+street_face*across):curb_safe=false
		if curb_safe:
			var at:=point(parking.x,parking.y)
			ARCHITECTURE.place(k,"carro_compacto",Transform3D(Basis(Vector3.UP,shop.rotation.y+PI*.5),at),true)
			parked_cars+=1
	if store_count%3==0 and best>3.35:
		var parking:=edge+street_face*.51+street_face.orthogonal()*2.97
		if road_distance(parking)<2.7:return
		var parked:=WarMapContent.instantiate(street_fixtures,PARKED_BIKE.resource_path,
			point(parking.x,parking.y)+Vector3.UP*.08,render_visuals)
		parked.rotation.y=shop.rotation.y+PI*.5
		for mesh: MeshInstance3D in parked.find_children("*","MeshInstance3D",true,false):
			mesh.visibility_range_end=120.0
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parked_bikes+=1

func _on_paving(at: Vector2) -> bool:
	var edge_offset:=.21*sin(at.x*.22+at.y*.16)
	var on_paving:=primary_distance(at)<AVENUE_WIDTH*.5+edge_offset
	on_paving=on_paving or _mini_street_distance(at,2.0)<MINI_STREET_WIDTH*.5+edge_offset
	for z: float in CROSS_STREETS:
		on_paving=on_paving or (absf(at.x)<640.0 and absf(at.y-z)<CROSS_WIDTH*.5+edge_offset)
	for x: float in VERTICAL_STREETS:
		on_paving=on_paving or (at.y>-550.0 and at.y<500.0 and absf(at.x-x)<ALLEY_WIDTH*.5+edge_offset)
	return on_paving

func _litter(at: Vector2,yaw: float) -> void:
	litter_count+=1
	if not render_visuals:return
	var detail:=WarMapContent.instantiate(street_fixtures,STREET_ART.LITTER.resource_path,
		point(at.x,at.y)+Vector3.UP*(.175 if _on_paving(at) else .012),true)
	var normal:=Vector3(height_at(at.x-.3,at.y)-height_at(at.x+.3,at.y),.6,
		height_at(at.x,at.y-.3)-height_at(at.x,at.y+.3)).normalized()
	detail.basis=Basis(Quaternion(Vector3.UP,normal))*Basis(Vector3.UP,yaw)

func _cable_span(a: Vector3,b: Vector3,sag:=1.0) -> void:
	var delta:=b-a
	var sideways:=Vector3(-delta.z,0,delta.x)
	if sideways.length_squared()<9.0:return
	if render_visuals:
		var cables:=WarMapContent.instantiate(street_fixtures,CABLE.resource_path,a,true)
		cables.basis=Basis(delta/18.0,Vector3.UP*sag,sideways.normalized())
	cable_count+=1

func _service_wire(k: EnvironmentKit,a: Vector3,b: Vector3) -> void:
	if render_visuals:
		var previous:=a
		for step in range(1,6):
			var t:=float(step)*.2
			var at:=a.lerp(b,t)-Vector3.UP*sin(t*PI)*.62
			k.pipe(previous,at,.013,"steel:32372f")
			previous=at
	service_drops+=1

func _wire_route(k: EnvironmentKit,anchors: Array,width: float,interval: float) -> void:
	var previous:=Vector3.INF
	var number:=0
	for i in anchors.size()-1:
		var a: Vector2=anchors[i]
		var b: Vector2=anchors[i+1]
		var right:=-(b-a).normalized().orthogonal()
		var steps:=maxi(1,ceili(a.distance_to(b)/interval))
		for step in steps:
			var side:=1.0 if number%4<2 else -1.0
			var p:=a.lerp(b,(float(step)+.42)/steps)+right*side*(width*.5+.44)
			number+=1
			if primary_distance(p)<AVENUE_WIDTH*.5+.22:continue
			if _mini_street_distance(p,2.0)<MINI_STREET_WIDTH*.5+.22:continue
			var at:=point(p.x,p.y)
			var pole:=WarMapContent.instantiate(street_fixtures,POLE.resource_path,at,render_visuals)
			pole.rotation.y=atan2(-right.y,right.x)
			pole_count+=1
			if number%3==0:_litter(p+right*side*.28,float(number)*.73)
			var top:=at+Vector3.UP*7.71
			if previous.is_finite() and previous.distance_to(top)<interval*2.45:_cable_span(previous,top)
			previous=top
			if number%3!=0:continue
			var branch:=Vector3.INF
			var closest:=20.0
			for endpoint: Vector3 in shop_connections:
				var distance:=top.distance_to(endpoint)
				if distance>5.0 and distance<closest:
					branch=endpoint
					closest=distance
			if branch.is_finite():_service_wire(k,top-Vector3.UP*.6,branch)
			var home:=Vector3.INF
			var closest_home:=24.0
			for endpoint: Vector3 in house_connections:
				var distance:=top.distance_to(endpoint)
				if distance>6.0 and distance<closest_home:
					home=endpoint
					closest_home=distance
			if home.is_finite():_service_wire(k,top-Vector3.UP*.92,home)

func _street_wiring(k: EnvironmentKit) -> void:
	_wire_route(k,PRIMARY.slice(2),AVENUE_WIDTH,36.0)
	for z: float in CROSS_STREETS:
		_wire_route(k,[Vector2(-455,z),Vector2(455,z)],CROSS_WIDTH,39.0)
	for x: float in [-320.0,-105.0,105.0,355.0]:
		_wire_route(k,[Vector2(x,-490),Vector2(x,340)],ALLEY_WIDTH,33.0)
	for route: Array in MINI_STREETS:_wire_route(k,route,MINI_STREET_WIDTH,29.0)

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
		var offset:=Vector2(-6,-29) if i==2 else Vector2(32,19)
		var q: Vector2=OBJECTIVES_2D[i]+offset
		var housing:=WarMapContent.instantiate(self,
			"res://modes/war/library/favela_casa_laje.tscn",point(q.x,q.y),render_visuals)
		housing.name="CasaAutorada_"+str(i)
		var tyre: Vector2=OBJECTIVES_2D[i]+Vector2(-13.0,11.0)
		var barricade:=WarMapContent.instantiate(self,
			"res://modes/war/library/favela_barricada_pneus.tscn",
			point(tyre.x,tyre.y),render_visuals)
		barricade.name="PneusAutorados_"+str(i)
func _vegetation(k: EnvironmentKit) -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=SEED+91
	const FOLIAGE := "favela_foliage"
	if render_visuals and not EnvironmentKit.materials.has(FOLIAGE):
		var material:=StandardMaterial3D.new()
		material.vertex_color_use_as_albedo=true
		material.vertex_color_is_srgb=true
		material.roughness=1.0
		EnvironmentKit.materials[FOLIAGE]=material
	for i in 900:
		var x:=rng.randf_range(-715,715)
		var woods:=i<260 or i>=340
		var z:=rng.randf_range(-745,-585) if woods else rng.randf_range(-735,735)
		if not woods and absf(x)<650 and z>-555:continue
		if i>=340 and sin(x*.027)+cos(z*.06)<-.4:continue
		var p:=point(x,z)
		if primary_distance(Vector2(x,z))<13.0:continue
		var scale:=rng.randf_range(.6,1.4)
		if render_visuals:
			var variant:=i%3
			var basis:=Basis(Vector3.UP,float(i)*.37).scaled(Vector3.ONE*scale)
			k._instance(WarVegetation.tree_mesh(true,variant,false),FOLIAGE,
				Transform3D(basis,p),false,WarVegetation.tree_mesh(true,variant,true),
				850.0,{"shadows":false})
		if i%9==0:
			var trunk:=CylinderShape3D.new()
			trunk.radius=.25*scale
			trunk.height=5.3*scale
			k._collider("Tronco",trunk,Transform3D(Basis.IDENTITY,p+Vector3.UP*trunk.height*.5),"wood")

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
	env.ambient_light_color=Color("c7d0cb");env.ambient_light_energy=.44
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.fog_enabled=true;env.fog_light_color=Color("b7ae9e")
	env.fog_density=.00025;env.fog_sky_affect=.45
	world.environment=env;add_child(world)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-43,-28,0)
	sun.light_color=Color("f1e7d6")
	sun.light_energy=.77
	sun.shadow_enabled=true
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance=135
	add_child(sun)
