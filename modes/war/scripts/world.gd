extends RefCounted
class_name WarWorld
static var cloud_noise: ImageTexture

static func build(parent: Node3D,visuals: bool) -> void:
	parent.set_meta("sector_colliders",true)
	parent.set_meta("war_detail_lod",true)
	parent.set_meta("war_operation",WarRules.CURRENT_OPERATION)
	if WarRules.CURRENT_OPERATION==WarOperation.AFGHAN:
		_build_afghan(parent,visuals)
		return
	WarTerrain.build(parent,visuals)
	WarTerrain.horizon(parent,visuals)
	var k := EnvironmentKit.new(parent,visuals,90.0)
	var networks: Array = [WarTerrain.TRENCH]
	networks.append_array(WarTerrain.BRANCHES)
	for route: Array in networks:
		for i in route.size()-1: trench_segment(k,route[i],route[i+1])
	for team in 2: base(k,team)
	for side in [-1,1]:
		# Forward cover is close enough to frame deployment, with a route
		# through its breached walls toward the trench and village.
		house(k,Vector2(side*250,-135),true)
		house(k,Vector2(side*230,-205),true)
		for i in 8:
			var p:=WarTerrain.point(side*(277-i*5),-148-i%3*5)
			tree(k,p,.65+(i%4)*.13,false)
			if i%2==0: WarStructures.sandbags(k,p+Vector3(2,0,3),4,.35)
		for i in 10:
			var p:=WarTerrain.point(side*(210+i*6),-208)
			k.beam(p,p+Vector3(.2,1.1,.15),.10,.10,"wood:514c40",true)
			if i%3!=0: k.beam(p+Vector3(0,.7,0),p+Vector3(side*5.8,.25,.7),.08,.12,"wood:5e5848")
	for item in [[-66,82,false],[5,120,true],[64,88,false],[-45,150,true],[70,155,true],[10,45,true]]:
		house(k,Vector2(item[0],item[1]),item[2])
	barn(k,Vector2(-125,165))
	WarStructures.road(k)
	for side in [-1,1]:
		for i in 4:
			var p := WarTerrain.point(side*(85+i*34),195)
			WarStructures.fence(k,Vector2(p.x,p.z),Vector2(p.x+22,p.z))
	var rng := RandomNumberGenerator.new()
	rng.seed = 987214
	WarVegetation.populate(k)
	for i in 95:
		var p := WarTerrain.point(rng.randf_range(-570,570),rng.randf_range(-400,400))
		if WarTerrain.trench_distance(Vector2(p.x,p.z))<8: continue
		k.rock(p+Vector3(0,.3,0),Vector3(1.4,.9,1.2)*rng.randf_range(.5,1.8),i,true)
		if i%3==0: EnvironmentProps.grass(k,WarTerrain.point(p.x+2,p.z),1.6)
	for x in [-450,-350,350,450]:
		var p := WarTerrain.point(x,-220)
		EnvironmentProps.truck(k,p)
		for i in 6: k.box("WreckArmour",WarTerrain.point(p.x+(i-3)*.8,p.z-4-i*.4)+Vector3.UP*.06,Vector3(.8,.25,1.2),"steel:302e2b",true,Vector3(.2,.4*i,.1))
	for entry in [["abrams",-230,125],["bmp2",210,125],["t90",330,-200]]:
		var wreck:=WarVehicle.new()
		wreck.kind=str(entry[0]);wreck.vehicle_id="wreck_"+str(entry[0]);wreck.position=WarTerrain.point(entry[1],entry[2]);wreck.heading=.8;wreck.rotation=Vector3(.06,.8,.08)
		parent.add_child(wreck)
		wreck.destroyed=true;wreck.hp=0;wreck.set_meta("war_wreck",true)
		if visuals:
			for mesh: MeshInstance3D in wreck.find_children("*","MeshInstance3D",true,false): mesh.material_override=EnvironmentKit.material("steel:343a33")
	for id in WarRules.OBJECTIVES:
		var data: Dictionary = WarRules.OBJECTIVES[id]
		var p := WarTerrain.point(data.position.x,data.position.z)
		k.cylinder("ObjectivePole",p+Vector3(0,3,0),.045,6,"steel",false)
		if data.active: k.sign_text(id+" · "+str(data.name),p+Vector3(0,3.4,0),3)
	WarHarbors.build(k)
	WarOutskirts.build(k)
	WarDistricts.build(k)
	WarCityLife.build(k)
	WarRoads.build(k)
	k.flush()
	if not parent.get_meta("authoring_reference",false): WarMapContent.build(parent,visuals)
	objective_cover(parent,visuals)
	if visuals: atmosphere(parent)
	parent.set_meta("war_map_size",3500)

static func _build_afghan(parent: Node3D,visuals: bool) -> void:
	var map:=BRAfghanMap.new()
	map.name="AfeganistaoWar"
	map.render_visuals=visuals
	map.seed=712907
	parent.add_child(map)
	map.build()
	var k:=EnvironmentKit.new(parent,visuals,90.0)
	for team in 2:base(k,team)
	for id in WarRules.OBJECTIVES:
		var data: Dictionary=WarRules.OBJECTIVES[id]
		var p:=WarTerrain.point(data.position.x,data.position.z)
		k.cylinder("ObjectivePole",p+Vector3(0,3,0),.045,6,"steel",false)
		if data.active:k.sign_text(id+" · "+str(data.name),p+Vector3(0,3.4,0),3)
	k.flush()
	objective_cover(parent,visuals)
	if visuals:BRAfghanAtmosphere.install(parent)
	parent.set_meta("war_map_size",2000)
	parent.set_meta("afghan_war",true)

static func objective_cover(parent: Node3D,visuals: bool) -> void:
	# Reuse complete library scenes: the mesh, material and projectile/player
	# collision arrive together on clients and on the authority.
	for id in WarRules.OBJECTIVES:
		var point: Vector3=WarRules.OBJECTIVES[id].position
		for side in [-1.,1.]:
			var at:=WarTerrain.point(point.x+side*9,point.z+6)
			if WarRules.CURRENT_OPERATION==WarOperation.UKRAINE and id in ["D","E"]: at.y=4.0
			var piece:=WarMapContent.instantiate(parent,"res://modes/war/library/barreira_concreto.tscn",at,visuals)
			piece.name="CaptureCover_"+id+str(int(side))
			piece.rotation.y=PI*.5

static func trench_segment(k: EnvironmentKit,a: Vector2,b: Vector2) -> void:
	var tangent := (b-a).normalized()
	var side := Vector2(-tangent.y,tangent.x)
	var yaw := atan2(tangent.x,tangent.y)
	var count := int(a.distance_to(b)/2.4)
	for i in count:
		var p2 := a.lerp(b,(i+.5)/maxi(1,count))
		var floor := WarTerrain.point(p2.x,p2.y)
		var normal:=Vector3(WarTerrain.height_at(floor.x-.5,floor.z)-WarTerrain.height_at(floor.x+.5,floor.z),1,WarTerrain.height_at(floor.x,floor.z-.5)-WarTerrain.height_at(floor.x,floor.z+.5)).normalized()
		var board_basis:=Basis(Quaternion(Vector3.UP,normal))*Basis(Vector3.UP,yaw)
		k.box("Duckboard",floor+Vector3(0,.045,0),Vector3(2.4,.09,.3),"wood:827364",false,board_basis.get_euler())
		for sign_value in [-1,1]:
			var edge: Vector2 = p2+side*sign_value*2.7
			var p := WarTerrain.point(edge.x,edge.y)
			k.box("TrenchPost",Vector3(p.x,floor.y+.85,p.z),Vector3(.16,1.9,.16),"wood:4a4036",false)
			for y in [.3,.8,1.3]:
				k.box("TrenchRetainingBoard",Vector3(p.x,floor.y+y,p.z),Vector3(.1,.36,2.5),"wood:695848",false,Vector3(0,yaw,0))
		if i%9==4:
			WarStructures.shelter(k,floor,yaw)
	if count>8:
		var midpoint := a.lerp(b,.5)+side*5
		var p := WarTerrain.point(midpoint.x,midpoint.y)
		WarStructures.sandbags(k,p,5.0,yaw)

static func base(k: EnvironmentKit,team: int) -> void:
	var source: Vector3=WarRules.BASES[team]
	var centre: Vector3=WarTerrain.point(source.x,source.z)
	if WarRules.CURRENT_OPERATION==WarOperation.AFGHAN:
		_afghan_base(k,team,centre)
		return
	for x in [-52,52]:
		if (team==0 and x==52) or (team==1 and x==-52):
			for z in [-9.5,9.5]: EnvironmentProps.sandbags(k,centre+Vector3(x,0,z),8,PI*.5)
		else: EnvironmentProps.sandbags(k,centre+Vector3(x,0,0),28,PI*.5)
	for z in [-45,45]: EnvironmentProps.sandbags(k,centre+Vector3(0,0,z),45)
	EnvironmentProps.canopy(k,centre+Vector3(-25,0,-25),Vector2(16,12),4.5)
	if ResourceLoader.exists("res://modes/war/library/container_20ft.tscn"):
		WarMapContent.instantiate(k.root,"res://modes/war/library/container_20ft.tscn",centre+Vector3(29,0,20),k.visuals)
	else: EnvironmentProps.container(k,centre+Vector3(29,0,20),true)
	EnvironmentProps.generator(k,centre+Vector3(21,0,22))
	EnvironmentProps.tower(k,centre+Vector3(-38,0,25),14)
	k.sign_text("BASE "+WarRules.team_name(team).to_upper()+" / IMPLANTAÇÃO",centre+Vector3(0,3,-42),7)
	for x in [-10,0,10]:
		k.box("VehicleApron",centre+Vector3(x,-.02,-12),Vector3(8,.1,16),"concrete",false)
		for dx in [-3.8,3.8]: k.box("ApronMark",centre+Vector3(x+dx,.04,-12),Vector3(.12,.02,16),"plaster:babaa6")

static func _afghan_base(k: EnvironmentKit,team: int,centre: Vector3) -> void:
	var ground:=func(offset: Vector3)->Vector3:return WarTerrain.point(centre.x+offset.x,centre.z+offset.z)
	for x in [-34.,34.]:
		for z in [-18.,0.,18.]:
			# The US camp's eastern access road crosses this exact wall
			# segment. Leave a gate without removing the base perimeter.
			if team==0 and x==34. and z==0.: continue
			EnvironmentProps.sandbags(k,ground.call(Vector3(x,0,z)),7,PI*.5)
	for z in [-29.,29.]:
		for x in [-18.,0.,18.]: EnvironmentProps.sandbags(k,ground.call(Vector3(x,0,z)),7)
	EnvironmentProps.canopy(k,ground.call(Vector3(-16,0,-13)),Vector2(12,9),4.0)
	# The Mujahideen mountain access road goes NE through the old
	# +X/+Z container apron. Keep its collision intact, but park cargo off
	# the graded lane instead of forcing motorcycles into a corrugated wall.
	var container_offset:=Vector3(17,0,-15) if team==1 else Vector3(17,0,15)
	var container_at: Vector3=ground.call(container_offset)
	if ResourceLoader.exists("res://modes/war/library/container_20ft.tscn"):
		WarMapContent.instantiate(k.root,"res://modes/war/library/container_20ft.tscn",container_at,k.visuals)
	else: EnvironmentProps.container(k,container_at,true)
	EnvironmentProps.generator(k,ground.call(Vector3(-10,0,18) if team==1 else Vector3(13,0,20)))
	EnvironmentProps.tower(k,ground.call(Vector3(-24,0,18)),11)
	var sign_at: Vector3=ground.call(Vector3(0,0,-27))+Vector3.UP*3.
	k.sign_text("BASE "+WarRules.team_name(team).to_upper()+" / IMPLANTAÇÃO",sign_at,6)

static func house(k: EnvironmentKit,p2: Vector2,ruined: bool) -> void: WarStructures.house(k,p2,ruined)
static func barn(k: EnvironmentKit,p2: Vector2) -> void: WarStructures.barn(k,p2)
static func tree(k: EnvironmentKit,p: Vector3,scale: float,green: bool) -> void: WarVegetation.tree(k,p,scale,green)

static func atmosphere(parent: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var env := Environment.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("5f6d75")
	sky.sky_horizon_color = Color("9ba5a3")
	sky.ground_horizon_color = Color("8b9491")
	sky.ground_bottom_color = Color("46483f")
	var resource := Sky.new()
	resource.sky_material = sky
	env.background_mode = Environment.BG_SKY
	env.sky = resource
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a9b3b8")
	env.ambient_light_energy = .34
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("8e999b")
	env.fog_density = .00045
	env.fog_sky_affect = .5
	world_environment.environment = env
	parent.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-30,0)
	sun.light_color = Color("d6d7c8")
	sun.light_energy = .68
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180
	parent.add_child(sun)
	var clouds:=MeshInstance3D.new()
	var plane:=PlaneMesh.new();plane.size=Vector2(9000,9000)
	clouds.mesh=plane;clouds.position.y=240;clouds.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cloud_mat:=ShaderMaterial.new();cloud_mat.shader=preload("res://modes/naval/shaders/clouds.gdshader")
	if cloud_noise==null:
		var noise:=FastNoiseLite.new();noise.seed=52904;noise.frequency=.018
		cloud_noise=ImageTexture.create_from_image(noise.get_seamless_image(256,256))
	cloud_mat.set_shader_parameter("cloud_noise",cloud_noise);cloud_mat.set_shader_parameter("daylight",.7)
	clouds.material_override=cloud_mat;parent.add_child(clouds)
	var cycle:=WarDayNight.new()
	cycle.name="WarDayNight";cycle.game=parent.get_parent()
	parent.add_child(cycle);cycle.configure(env,sun,clouds)
	# WarSoundscape supplies regional wind and environmental sources.
