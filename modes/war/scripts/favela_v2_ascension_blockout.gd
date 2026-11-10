extends RefCounted
## Real Godot 3D structure for user review, not a painted reference image.
## Main S-road climbs south->north. Western homes are one-gate cul-de-sac.
## The original game's house and field scenes are reused unchanged.
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
const T=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const WEST=preload("res://modes/war/scripts/favela_v2_west_hillside.gd")
const HOUSE=preload("res://modes/war/library/favela_casa_laje.tscn")
const FIELD=preload("res://modes/war/library/favela_campo_baile.tscn")
const VISUAL_POLICY=preload("res://modes/war/scripts/favela_v2_visual_optimization.gd")
const MAIN_HOUSE_SCALE:=Vector3(.70,.78,.70)
const STAGE_NODES=["curva_entrada","praca","central_hub","mercadinho","rua_norte"]
const STAGE_LETTERS=["A","B","C","D","E"]

static func _distance_from_roads(p: Vector2)->float:
	var best:=INF
	for edge: Dictionary in TOPO.LINKS:
		var poly:=TOPO.polyline(edge)
		for j in poly.size()-1:
			var q:=Geometry2D.get_closest_point_to_segment(p,poly[j],poly[j+1])
			best=minf(best,p.distance_to(q)-float(edge["width"])*.5)
	return best

static func _safe_placement(p: Vector2,placed: Array[Dictionary])->bool:
	if not TOPO.BOUNDS.grow(-14).has_point(p):return false
	if _distance_from_roads(p)<5.5:return false
	for id in ["base_sul","base_norte"]:
		if p.distance_to(TOPO.NODES[id]["p"])<37.0:return false
	if p.distance_to(TOPO.NODES["campinho"]["p"])<33.0:return false
	for id in ["praca","central_hub","mercadinho"]:
		if p.distance_to(TOPO.NODES[id]["p"])<14.0:return false
	if WEST._near_cliff(p):return false
	if WEST._house_slope(p)>2.75:return false
	for old: Dictionary in placed:
		if p.distance_squared_to(old["pos"])<120.0:return false
	return true

static func plan_houses()->Array[Dictionary]:
	# A compact urban mass along S bends instead of scattering thousands
	# of props across the old 1.5 km square. West houses remain separate.
	var placed: Array[Dictionary]=[]
	for old: Dictionary in WEST.plan_houses():
		placed.append(old)
	var output: Array[Dictionary]=[]
	for edge: Dictionary in TOPO.LINKS:
		if str(edge["id"]).begins_with("l"):continue
		var poly:=TOPO.polyline(edge)
		var width:float=float(edge["width"])
		for j in poly.size()-1:
			var a: Vector2=poly[j]
			var b: Vector2=poly[j+1]
			var direction: Vector2=(b-a).normalized()
			var normal:=Vector2(-direction.y,direction.x)
			var span:=a.distance_to(b)
			var n:=maxi(1,floori(span/12.8))
			for i in n:
				var t:float=(float(i)+.5)/float(n)
				for side in [-1.0,1.0]:
					var found:=false
					for depth in [7.2,10.5,13.3]:
						var offset:float=width*.5+float(depth)
						var p:Vector2=a.lerp(b,t)+normal*float(side)*offset
						if not _safe_placement(p,placed):continue
						var yaw:float=atan2(direction.x,direction.y)
						var data:Dictionary={
							"pos":p,"height":T.height_at(p.x,p.y),
							"yaw":yaw,"edge":str(edge["id"]),
							"variant":int((output.size()+i+j)%5)
						}
						placed.append(data)
						output.append(data)
						found=true
						break
					if found and output.size()>=160:return output
	return output

static func _build_houses(parent: Node3D,visuals: bool)->Dictionary:
	var holder:=Node3D.new()
	holder.name="CasasAoLongoDaSubida"
	parent.add_child(holder)
	var houses:=plan_houses()
	var reused:=0
	for i in houses.size():
		var h:Dictionary=houses[i]
		var q:Vector2=h["pos"]
		var building:=HOUSE.instantiate() as Node3D
		building.name="CasaDaEncosta_%03d"%i
		building.position=Vector3(q.x,float(h["height"])-.32,q.y)
		building.rotation.y=float(h["yaw"])
		building.scale=MAIN_HOUSE_SCALE*Vector3(1.0,1.0+.14*float(i%3),1.0)
		holder.add_child(building)
		if visuals:
			reused+=WEST._decorate_house(building,i+11)
		else:
			for view:MeshInstance3D in building.find_children("*","MeshInstance3D",true,false):
				view.visible=false
	return {"main_houses":houses.size(),"reused_modules":reused}

static func _build_campinho(parent: Node3D,visuals: bool)->int:
	# Reuse real field ground and its physical contact shape from the old
	# Favela. Only 48x30m; terrain pad is formed by the height generator.
	var node:=FIELD.instantiate() as Node3D
	node.name="CampinhoV2"
	var p:Vector2=TOPO.NODES["campinho"]["p"]
	node.position=Vector3(p.x,T.height_at(p.x,p.y)+.03,p.y)
	node.scale=Vector3(.58,1.0,.60)
	parent.add_child(node)
	if not visuals:
		for view:MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
			view.visible=false
	return 1

static func build(parent: Node3D,visuals: bool=true)->Dictionary:
	var sector:=Node3D.new()
	sector.name="FavelaV2EstruturaAscensao"
	parent.add_child(sector)
	var terrain_data:Dictionary=T.build(sector,visuals)
	var west_data:Dictionary=WEST.build(sector,visuals)
	var middle_data:Dictionary=_build_houses(sector,visuals)
	var field_count:=_build_campinho(sector,visuals)
	# Native culling is opt-in; same game physics in either branch of A/B.
	var occlusion_on:bool=visuals and VISUAL_POLICY.enabled_by_command_line()
	if visuals:sector.get_viewport().use_occlusion_culling=occlusion_on
	var visual_policy:Dictionary=VISUAL_POLICY.apply(sector,visuals,occlusion_on)
	return {
		"terrain":terrain_data,"west":west_data,
		"main":middle_data,"campinho":field_count,
		"visual_policy":visual_policy,
		"objectives_proposed":STAGE_NODES.size(),
		"police_height":T.NODE_HEIGHTS["base_sul"],
		"trafficker_height":T.NODE_HEIGHTS["base_norte"],
		"western_gateways":TOPO.left_gate_links().size()
	}
