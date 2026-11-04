@tool
extends RefCounted
class_name WarTerrainEdits
const LAYOUT:="res://modes/war/scenes/map_additions.tscn"
static var prepared:=false
static var edits: Array[Dictionary]=[]
static var cells: Dictionary={}
static var active_tiles: Dictionary={}
static var road_zones: Array[Dictionary]=[]
static var replaced_lots: Array[Vector2]=[]
static var revision:=0

static func collect(node: Node,pose:=Transform3D.IDENTITY,result: Array[Dictionary]=[]) -> Array[Dictionary]:
	if node is Node3D: pose=pose*node.transform
	if node is WarTrenchModule and node.excavate:
		var cut:=descriptor(pose,Vector2(1.10,3),float(node.depth),.65,4.,"cut");cut.source="trench";result.append(cut)
	elif node.has_meta("library_id"):
		var id:=str(node.get_meta("library_id"))
		if id=="cratera_impacto":
			var crater:=descriptor(pose,Vector2(1.5,1.5),float(node.get_meta("crater_depth",.65)),1.25,1.25,"cut");crater.shape="radial";crater.source="crater";result.append(crater)
		elif (id.begins_with("estrada_") or id in ["casa_ruina","fachada_atingida","entulho_tijolos"]) and node.get_meta("terrain_grade",true):
			var size: Vector2=node.get_meta("footprint",Vector2(8.25,12))
			var centre: Vector2=node.get_meta("grade_centre",Vector2.ZERO)
			var surface:=pose*Transform3D(Basis.IDENTITY,Vector3(centre.x,0. if id in ["casa_ruina","fachada_atingida","entulho_tijolos"] else -.06,centre.y))
			if id=="estrada_rampa_12m": surface=pose*Transform3D(Basis(Vector3.RIGHT,atan2(1.5,12)),Vector3(0,.75-.06,0))
			result.append(descriptor(surface,size*.5,0,2.5,2.5,"grade"))
		elif id.begins_with("cais_"):
			# Recess land under a pier without raising the seabed under it.
			var size: Vector2=node.get_meta("footprint",Vector2(8,8))
			var centre: Vector2=node.get_meta("grade_centre",Vector2.ZERO)
			var surface:=pose*Transform3D(Basis.IDENTITY,Vector3(centre.x,0,centre.y))
			if id=="cais_rampa_8m": surface=pose*Transform3D(Basis(Vector3.RIGHT,atan2(1.2,8)),Vector3(0,.6,0))
			result.append(descriptor(surface,size*.5,.9,.8,.8,"cut"))
	if node.has_meta("replace_road"):
		result.append({"kind":"road_zone","pose":pose,"half":Vector2(node.get_meta("replace_road"))*.5})
	if node.has_meta("replace_lot"):
		result.append({"kind":"lot","position":Vector2(pose.origin.x,pose.origin.z)})
	for child in node.get_children(): collect(child,pose,result)
	return result

static func descriptor(pose: Transform3D,half: Vector2,depth: float,side_blend: float,end_blend: float,kind: String) -> Dictionary:
	var plane:=pose*Vector3(0,-depth,0)
	var normal: Vector3=(pose.basis.inverse().transposed()*Vector3.UP).normalized()
	var bounds:=Rect2(Vector2(pose.origin.x,pose.origin.z),Vector2.ZERO)
	for sx in [-1,1]:
		for sz in [-1,1]:
			var p:=pose*Vector3(sx*(half.x+side_blend),-depth,sz*(half.y+end_blend))
			bounds=bounds.expand(Vector2(p.x,p.z))
	return {"kind":kind,"pose":pose,"inverse":pose.affine_inverse(),"half":half,"plane":plane,"normal":normal,"side":side_blend,"end":end_blend,"bounds":bounds.grow(.6)}

static func configure(records: Array[Dictionary]) -> void:
	prepared=true;edits.clear();cells.clear();active_tiles.clear();road_zones.clear();replaced_lots.clear();revision+=1
	for entry in records:
		if entry.kind=="road_zone": road_zones.append(entry);continue
		if entry.kind=="lot": replaced_lots.append(entry.position);continue
		if absf(Vector3(entry.normal).y)<.7: continue
		edits.append(entry)
		var rect: Rect2=entry.bounds
		var tile_low:=Vector2i(floori((rect.position.x+1750)/100),floori((rect.position.y+1750)/100))
		var tile_high:=Vector2i(floori((rect.end.x+1750)/100),floori((rect.end.y+1750)/100))
		for z in range(tile_low.y,tile_high.y+1):
			for x in range(tile_low.x,tile_high.x+1): active_tiles[Vector2i(x,z)]=true
		var low:=Vector2i(floori(rect.position.x/100),floori(rect.position.y/100))
		var high:=Vector2i(floori(rect.end.x/100),floori(rect.end.y/100))
		for z in range(low.y,high.y+1):
			for x in range(low.x,high.x+1):
				var key:=Vector2i(x,z)
				if not cells.has(key): cells[key]=[]
				cells[key].append(entry)
	WarTerrain.reset_cache()

static func prepare() -> void:
	if prepared: return
	var result: Array[Dictionary]=[]
	for source in [[LAYOUT,Vector3.ZERO],["res://modes/war/scenes/east_port.tscn",Vector3(1190,4,470)]]:
		if not ResourceLoader.exists(source[0]): continue
		var scene:=load(source[0]).instantiate() as Node3D
		collect(scene,Transform3D(Basis.IDENTITY,source[1]),result);scene.free()
	configure(result)

static func apply_height(x: float,z: float,height: float) -> float:
	var nearby: Array=cells.get(Vector2i(floori(x/100),floori(z/100)),[])
	if nearby.is_empty(): return height
	# Pads first, excavation second: a neighbouring surface cannot refill a trench.
	for kind in ["grade","cut"]:
		for entry: Dictionary in nearby:
			if entry.kind!=kind or not Rect2(entry.bounds).has_point(Vector2(x,z)): continue
			var n: Vector3=entry.normal;var plane: Vector3=entry.plane
			var y: float=(n.dot(plane)-n.x*x-n.z*z)/n.y
			var local: Vector3=Transform3D(entry.inverse)*Vector3(x,y,z)
			var half: Vector2=entry.half
			var weight: float=(1.-smoothstep(half.x,half.x+float(entry.side),absf(local.x)))*(1.-smoothstep(half.y,half.y+float(entry.end),absf(local.z)))
			if entry.get("shape","")=="radial": weight=1.-smoothstep(.45,half.x+float(entry.side),Vector2(local.x,local.z).length())
			if kind=="cut": height=minf(height,lerpf(height,y,weight))
			elif height>-.6: height=lerpf(height,y,weight)
	return height

static func affects(rect: Rect2) -> bool:
	var low:=Vector2i(floori(rect.position.x/100),floori(rect.position.y/100));var high:=Vector2i(floori(rect.end.x/100),floori(rect.end.y/100))
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			for edit: Dictionary in cells.get(Vector2i(x,z),[]):
				if Rect2(edit.bounds).grow(1.0).intersects(rect,true): return true
	return false

static func replaces_road(point: Vector2) -> bool:
	for zone in road_zones:
		var p: Vector3=Transform3D(zone.pose).affine_inverse()*Vector3(point.x,zone.pose.origin.y,point.y)
		if absf(p.x)<=float(zone.half.x) and absf(p.z)<=float(zone.half.y): return true
	return false

static func replaces_lot(point: Vector2) -> bool:
	for p in replaced_lots:
		if point.distance_squared_to(p)<.01: return true
	return false

static func remaining_road(a: Vector2,b: Vector2) -> Array[Vector2]:
	var spans: Array[Vector2]=[Vector2(0,1)]
	for zone in road_zones:
		var inverse:=Transform3D(zone.pose).affine_inverse()
		var p:=inverse*Vector3(a.x,zone.pose.origin.y,a.y);var q:=inverse*Vector3(b.x,zone.pose.origin.y,b.y);var d:=q-p
		var low:=0.;var high:=1.;var hit:=true
		for axis in [0,2]:
			var half: float=zone.half.x if axis==0 else zone.half.y
			if absf(d[axis])<.00001:
				if absf(p[axis])>half: hit=false;break
				continue
			var first: float=(-half-p[axis])/d[axis];var second: float=(half-p[axis])/d[axis]
			low=maxf(low,minf(first,second));high=minf(high,maxf(first,second))
			if low>=high: hit=false;break
		if not hit: continue
		var next: Array[Vector2]=[]
		for span in spans:
			if high<=span.x or low>=span.y: next.append(span);continue
			if low>span.x: next.append(Vector2(span.x,low))
			if high<span.y: next.append(Vector2(high,span.y))
		spans=next
	return spans
