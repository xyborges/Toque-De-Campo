extends RefCounted
class_name WarDistricts
const TOWNS:=WarUrbanLayout.CENTRES
const FIELDS:=[Vector2(-590,370),Vector2(540,-410)]
static var wheat_mesh: ArrayMesh
static func build(k: EnvironmentKit) -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=1722610
	for centre: Vector2 in TOWNS:
		for block in 6:
			var p:=centre+Vector2((block%3)*42-42,(block/3)*58-29)
			ruined_block(k,p,block)
		for index in 16:
			var a:=WarTerrain.point(centre.x-78+index*10,centre.y)
			var b:=WarTerrain.point(a.x+10,a.z)
			pass # Road network supplies the continuous street mesh.
			if index%4==0:
				var verge:=WarRoads.roadside(Vector2(a.x,a.z+8))
				var post:=WarTerrain.point(verge.x,verge.y)
				k.cylinder("BrokenStreetLamp",post+Vector3.UP*3,.10,6,"steel:424b48",true)
		for index in 160:
			var p:=WarTerrain.point(centre.x+rng.randf_range(-85,85),centre.y+rng.randf_range(-75,75))
			if WarRoads.distance(Vector2(p.x,p.z))<7: continue
			k.box("MasonryRubble",p+Vector3.UP*rng.randf_range(.08,.25),Vector3(rng.randf_range(.2,.8),.25,rng.randf_range(.25,.9)),"brick:79756b",false,Vector3(.1,rng.randf()*TAU,.18),true)
			if index%20==0: k.rock(p+Vector3.UP*.35,Vector3(1.8,.7,1.2),index,true)
	# Wheat is a single authored tuft mesh instanced in sectors, no per-stalk nodes.
	if k.visuals:
		if wheat_mesh==null:
			var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for stalk in 7:
				var angle:=stalk*2.399;var offset:=Vector3(cos(angle),0,sin(angle))*.11*stalk
				var height:=.72+stalk*.055;var side:=Vector3(cos(angle),0,sin(angle))*.025
				var tip:=offset+Vector3.UP*height
				var stem: Array[Vector3]=[offset-side,offset+side,tip+side,tip-side]
				var head: Array[Vector3]=[tip-side*2,tip+side*2,tip+Vector3.UP*.22+side*.6,tip+Vector3.UP*.22-side*.6]
				var leaf: Array[Vector3]=[offset+Vector3.UP*height*.35,offset+Vector3.UP*height*.6+side*7,offset+Vector3.UP*height*.65+side*6,offset+Vector3.UP*height*.4]
				for points: Array in [stem,head,leaf]:
					for index in [0,1,2,0,2,3]: surface.set_normal(Vector3.UP);surface.add_vertex(points[index])
			surface.index();wheat_mesh=surface.commit()

		var wheat_mat:=StandardMaterial3D.new();wheat_mat.albedo_color=Color("a79656");wheat_mat.roughness=1;wheat_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		EnvironmentKit.materials["wheat172"]=wheat_mat
		for centre: Vector2 in FIELDS:
			for index in 14000:
				var at:=centre+Vector2(rng.randf_range(-100,100),rng.randf_range(-65,65))
				if absf(at.y-centre.y)<2: continue
				var p:=WarTerrain.point(at.x,at.y)
				if p.y<5: continue
				k._instance(wheat_mesh,"wheat172",Transform3D(Basis(Vector3.UP,rng.randf()*TAU)*Basis.from_scale(Vector3.ONE*rng.randf_range(.75,1.15)),p),true)
	# Tall pine stands with open trunks, sparse high crowns and fallen timber.
	for centre: Vector2 in [Vector2(-650,850),Vector2(650,-850)]:
		for index in 180:
			var at:=centre+Vector2(rng.randf_range(-115,115),rng.randf_range(-105,105));var p:=WarTerrain.point(at.x,at.y)
			if not WarVegetation.clear_site(at): continue
			var height:=rng.randf_range(11,20)
			k.cylinder("PineTrunk",p+Vector3.UP*height*.5,.22,height,"wood:686958",true,.55)
			# Irregular exposed pine limbs, rather than stacked solid cones.
			for level in 6:
				var at_y:=height*(.48+level*.075)
				for limb in 4:
					var angle:=limb*PI*.5+level*.73+index*.21
					var reach:=rng.randf_range(1.1,2.9)*(1-level*.1)
					var end:=p+Vector3(cos(angle)*reach,at_y+rng.randf_range(-.7,.5),sin(angle)*reach)
					k.beam(p+Vector3.UP*at_y,end,.09,.09,"wood:595e50")
					if index%3!=0 and level>=2:
						var needle:=WarVegetation.tree_mesh(true,0,true)
						k._instance(needle,"fabric:354d38",Transform3D(Basis.from_scale(Vector3(.20,.15,.20)),end))

			if index%12==0:
				var end:=WarTerrain.point(p.x+9,p.z+5)
				k.beam(p+Vector3.UP*.25,end+Vector3.UP*.25,.42,.42,"wood:55584b",true)
				for limb in 3: k.beam(p.lerp(end,(limb+1)*.22)+Vector3.UP*.3,p.lerp(end,(limb+1)*.22)+Vector3(1.6,.9,-1.8),.10,.10,"wood:51564a")
	k.root.set_meta("war_coastal_towns",2);k.root.set_meta("war_wheat_fields",2);k.root.set_meta("war_pine_forests",2)
static func ruined_block(k: EnvironmentKit,at: Vector2,index: int) -> void:
	var p:=WarTerrain.point(at.x,at.y)
	WarHarbors.foundation(k,p+Vector3(0,-.15,0),Vector3(23,.6,18),"TownFoundation")
	var floors:=2+index%2
	var mild:=index%5==0
	for floor_index in floors:
		var y:=floor_index*3.3
		for side in [-1.,1.]:
			k.wall("DamagedFacade",p+Vector3(-11,y,side*8.5),p+Vector3(11,y,side*8.5),3.3,"plaster:aaa89d",[{"at":3.,"width":1.6,"sill":.85,"top":2.5},{"at":7.,"width":1.6,"sill":.85,"top":2.5},{"at":12.,"width":2.,"sill":.85,"top":2.5},{"at":17.,"width":1.6,"sill":.85,"top":2.5}])
		k.wall("ExposedEndWall",p+Vector3(-11,y,-8.5),p+Vector3(-11,y,8.5),3.3,"brick:827b70",[{"at":4.,"width":1.6,"sill":.8,"top":2.4},{"at":12.,"width":1.6,"sill":.8,"top":2.4}])
		# Partial slabs have visible supports and leave a full breached end.
		k.box("BrokenFloorSlab",p+Vector3(-3,y+.14,0),Vector3(16,.27,17),"concrete:777c77",floor_index==0)
		for z in [-7.,0.,7.]: k.beam(p+Vector3(4,y,z),p+Vector3(9,y+.8,z+.7),.16,.16,"steel:414d4a")
	if mild:
		k.wall("SurvivingEndWall",p+Vector3(11,0,-8.5),p+Vector3(11,0,8.5),floors*3.3,"brick:827b70",[{"at":8.,"width":2.,"top":2.4}])
	for z in [-8.,8.]: k.box("SurvivingColumn",p+Vector3(5,floors*1.65,z),Vector3(.5,floors*3.3,.5),"brick:766f62",true)
	# Collapsed pitched roof, with the ridge still supported at the rear.
	var eave:=floors*3.3
	if mild: k.box("StandingRoof",p+Vector3(0,eave+.1,0),Vector3(22,.20,17),"steel:656d60",false)
	k.beam(p+Vector3(-10,eave,-8),p+Vector3(-10,eave+3,0),.22,.22,"wood:625d4e")
	k.beam(p+Vector3(-10,eave+3,0),p+Vector3(-10,eave,8),.22,.22,"wood:625d4e")
	k.box("RemainingRoof",p+Vector3(-6,eave+1.5,-4),Vector3(9,.18,8.55),"steel:696c64",false,Vector3(-.36,0,0))
