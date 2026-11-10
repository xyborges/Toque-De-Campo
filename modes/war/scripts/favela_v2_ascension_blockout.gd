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
const DETAILS=preload("res://modes/war/scripts/favela_v2_neighborhood_details.gd")
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

const MAX_MAIN_HOUSES:=390
const ROW_OFFSETS=[7.4,19.7,32.0]
const ALLEY_WIDTH:=2.65
const HOUSE_CLEARANCE:=11.4

static func _left_district(p:Vector2)->bool:
	# The 37 homes along the west stair network are owned by WEST.build.
	# The central plan cannot block those stair flights.
	return p.x<-102.0 and p.y<85.0 and p.y> -201.0

static func plan_alleys()->Array[Dictionary]:
	# Short perpendicular dead-end passages off the curved S/side streets.
	# These passages NEVER create a bot shortcut or a second west gateway.
	var result:Array[Dictionary]=[]
	for edge:Dictionary in TOPO.LINKS:
		if str(edge["id"]).begins_with("l"):continue
		if str(edge["id"]) in ["r03","r04","c08"]:continue
		var poly:=TOPO.polyline(edge)
		var width:float=float(edge["width"])
		for seg in poly.size()-1:
			var a:Vector2=poly[seg]
			var b:Vector2=poly[seg+1]
			var delta:=b-a
			var length:=delta.length()
			if length<24.0:continue
			var normal:=Vector2(-delta.y,delta.x)/length
			var repeats:=maxi(1,ceili(length/26.0))
			for i in repeats:
				var t:float=(float(i)+.5)/float(repeats)
				var middle:Vector2=a.lerp(b,t)
				for sign_side in [-1.0,1.0]:
					var v:Vector2=normal*float(sign_side)
					var from:Vector2=middle+v*(width*.5+1.1)
					var to:Vector2=middle+v*(width*.5+22.0)
					if not TOPO.BOUNDS.grow(-20).has_point(to):continue
					if _left_district(to) or WEST._near_cliff(to):continue
					if _distance_from_roads(to)<4.8:continue
					if absf(T.height_at(from.x,from.y)-T.height_at(to.x,to.y))>8.5:continue
					# Do not place a decorative "path" that cannot actually
					# be walked. Filter the sharp ground-to-terrace seams.
					var last_height:=T.height_at(from.x,from.y)
					var steepest:=0.0
					for sample in range(1,13):
						var point:=from.lerp(to,float(sample)/12.0)
						var height:=T.height_at(point.x,point.y)
						steepest=maxf(steepest,absf(height-last_height)/(from.distance_to(to)/12.0))
						last_height=height
					if steepest>.50:continue
					var overlaps:=false
					for existing:Dictionary in result:
						if to.distance_to(existing["to"])<14.0:overlaps=true
					if overlaps:continue
					result.append({"a":from,"to":to,"edge":str(edge["id"]),
						"width":ALLEY_WIDTH,"side":sign_side})
	return result

static func _safe_placement(p:Vector2,placed:Array[Dictionary],
		alleys:Array[Dictionary])->bool:
	if not TOPO.BOUNDS.grow(-15).has_point(p):return false
	if _left_district(p):return false
	if _distance_from_roads(p)<5.7:return false
	for id in ["base_sul","base_norte"]:
		if p.distance_to(TOPO.NODES[id]["p"])<37.0:return false
	if p.distance_to(TOPO.NODES["campinho"]["p"])<35.0:return false
	for id in ["praca","central_hub","mercadinho"]:
		if p.distance_to(TOPO.NODES[id]["p"])<15.5:return false
	if WEST._near_cliff(p) or WEST._house_slope(p)>2.75:return false
	for alley:Dictionary in alleys:
		var dist:=p.distance_to(Geometry2D.get_closest_point_to_segment(
			p,alley["a"],alley["to"]))
		if dist<5.7:return false
	for old:Dictionary in placed:
		if p.distance_squared_to(old["pos"])<HOUSE_CLEARANCE*HOUSE_CLEARANCE:
			return false
	return true

static func plan_houses(prepared_west:Array[Dictionary]=[],
		prepared_alleys:Array[Dictionary]=[])->Array[Dictionary]:
	# Precomputed inputs avoid reevaluating hill/road layouts several times
	# inside one build; this matters for the spawn-frame hitch.
	var alleys:Array[Dictionary]=prepared_alleys if not prepared_alleys.is_empty() else plan_alleys()
	var west:Array[Dictionary]=prepared_west if not prepared_west.is_empty() else WEST.plan_houses()
	var placed:Array[Dictionary]=west.duplicate()
	var output:Array[Dictionary]=[]
	for depth:float in ROW_OFFSETS:
		for edge:Dictionary in TOPO.LINKS:
			if str(edge["id"]).begins_with("l"):continue
			var poly:=TOPO.polyline(edge)
			var width:float=float(edge["width"])
			for j in poly.size()-1:
				var a:Vector2=poly[j]
				var b:Vector2=poly[j+1]
				var delta:=b-a
				var span:=delta.length()
				if span<7.0:continue
				var normal:=Vector2(-delta.y,delta.x)/span
				var n:=maxi(1,floori(span/10.7))
				for i in n:
					var fraction:float=(float(i)+.5)/float(n)
					# Stagger the rear lanes as on real steep favela terraces.
					if depth>10.0:fraction=clampf(fraction+.035,.06,.94)
					for sign_side in [-1.0,1.0]:
						var pos:Vector2=a.lerp(b,fraction)+normal*float(sign_side)*(width*.5+depth)
						if not _safe_placement(pos,placed,alleys):continue
						var toward:Vector2=-normal*float(sign_side)
						var yaw:=atan2(toward.x,toward.y)
						var variant:=int((i*7+j*5+output.size()*3)%9)
						var datum:Dictionary={"pos":pos,"height":T.height_at(pos.x,pos.y),
							"yaw":yaw,"edge":str(edge["id"]),"variant":variant,
							"row":int(ROW_OFFSETS.find(depth))+1}
						placed.append(datum)
						output.append(datum)
						if output.size()>=MAX_MAIN_HOUSES:return output
	return output

static func _build_houses(parent:Node3D,visuals:bool,houses:Array[Dictionary],
		alleys_count:int)->Dictionary:
	var holder:=Node3D.new()
	holder.name="CasasAoLongoDaSubida"
	parent.add_child(holder)
	var reused:=0
	for i in houses.size():
		var h:Dictionary=houses[i]
		var q:Vector2=h["pos"]
		var building:=HOUSE.instantiate() as Node3D
		building.name="CasaDaEncosta_%03d"%i
		building.position=Vector3(q.x,float(h["height"])-.32,q.y)
		building.rotation.y=float(h["yaw"])
		var variant:int=int(h["variant"])
		var width_scale:float=[.80,.91,1.0,.88,1.03,.77,.95,1.06,.84][variant]
		var height_scale:float=[.67,.88,1.16,.77,1.29,1.04,.74,1.34,.91][variant]
		var depth_scale:float=[.87,.93,1.06,.96,.80,1.12,1.02,.91,1.03][variant]
		building.scale=MAIN_HOUSE_SCALE*Vector3(width_scale,height_scale,depth_scale)
		holder.add_child(building)
		if visuals:
			reused+=WEST._decorate_house(building,int(h["variant"])+i*9)
		else:
			for view:MeshInstance3D in building.find_children("*","MeshInstance3D",true,false):
				view.visible=false
	return {"main_houses":houses.size(),"reused_modules":reused,"alleys":alleys_count,"variants":9}

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
	var west_plan:Array[Dictionary]=WEST.plan_houses()
	var alley_plan:Array[Dictionary]=plan_alleys()
	var main_plan:Array[Dictionary]=plan_houses(west_plan,alley_plan)
	var west_data:Dictionary=WEST.build(sector,visuals,true,west_plan)
	var middle_data:Dictionary=_build_houses(sector,visuals,main_plan,alley_plan.size())
	var field_count:=_build_campinho(sector,visuals)
	var all_houses:Array[Dictionary]=main_plan.duplicate()
	all_houses.append_array(west_plan)
	var detail_data:Dictionary=DETAILS.build(sector,visuals,alley_plan,all_houses)
	# Native culling is opt-in; same game physics in either branch of A/B.
	var occlusion_on:bool=visuals and VISUAL_POLICY.enabled_by_command_line()
	if visuals:sector.get_viewport().use_occlusion_culling=occlusion_on
	var visual_policy:Dictionary=VISUAL_POLICY.apply(sector,visuals,occlusion_on)
	return {
		"terrain":terrain_data,"west":west_data,
		"main":middle_data,"campinho":field_count,
		"alleys_and_details":detail_data,
		"visual_policy":visual_policy,
		"objectives_proposed":STAGE_NODES.size(),
		"police_height":T.NODE_HEIGHTS["base_sul"],
		"trafficker_height":T.NODE_HEIGHTS["base_norte"],
		"western_gateways":TOPO.left_gate_links().size()
	}
